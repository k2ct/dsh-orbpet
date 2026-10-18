use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{
    path::{Path, PathBuf},
    process::Stdio,
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc,
    },
    time::Duration,
};
use thiserror::Error;
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader, Lines},
    process::{Child, ChildStdin, ChildStdout, Command},
    sync::Mutex,
    time::timeout,
};

#[derive(Debug, Error)]
pub enum AcpError {
    #[error("failed to start or communicate with ACP: {0}")]
    Io(#[from] std::io::Error),
    #[error("ACP request timed out")]
    Timeout,
    #[error("ACP stdout closed before the response arrived")]
    Closed,
    #[error("ACP returned an error: {0}")]
    Remote(String),
    #[error("ACP returned an invalid response: {0}")]
    Invalid(String),
    #[error("ACP client is not connected")]
    NotConnected,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AcpHandshake {
    pub agent_name: String,
    pub agent_version: String,
    pub protocol_version: u64,
    pub session_id: String,
    pub resumed: bool,
    pub ignored_stdout_lines: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AcpPromptResult {
    pub session_id: String,
    pub text: String,
    pub stop_reason: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase", tag = "type")]
pub enum AcpStreamEvent {
    Status {
        state: String,
    },
    TextDelta {
        text: String,
    },
    Completed {
        session_id: String,
        stop_reason: Option<String>,
    },
    Error {
        message: String,
        recoverable: bool,
    },
}

pub struct AcpClient {
    child: Mutex<Child>,
    stdin: Mutex<ChildStdin>,
    lines: Mutex<Lines<BufReader<ChildStdout>>>,
    request_lock: Mutex<()>,
    next_id: AtomicU64,
    session_id: String,
    handshake: AcpHandshake,
}

impl AcpClient {
    pub async fn connect(
        dsh: &Path,
        cwd: &Path,
        persisted_session_id: Option<&str>,
    ) -> Result<Arc<Self>, AcpError> {
        let mut child = Command::new(dsh)
            .args(["--profile", "acp"])
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()?;
        let stdin = child
            .stdin
            .take()
            .ok_or_else(|| AcpError::Invalid("missing stdin".into()))?;
        let stdout = child
            .stdout
            .take()
            .ok_or_else(|| AcpError::Invalid("missing stdout".into()))?;
        let client = Arc::new(Self {
            child: Mutex::new(child),
            stdin: Mutex::new(stdin),
            lines: Mutex::new(BufReader::new(stdout).lines()),
            request_lock: Mutex::new(()),
            next_id: AtomicU64::new(1),
            session_id: String::new(),
            handshake: AcpHandshake {
                agent_name: String::new(),
                agent_version: String::new(),
                protocol_version: 0,
                session_id: String::new(),
                resumed: false,
                ignored_stdout_lines: Vec::new(),
            },
        });

        let (initialized, ignored) = client
            .request(
                "initialize",
                json!({
                    "protocolVersion":1,
                    "clientCapabilities":{},
                    "clientInfo":{"name":"dsh-desktop-companion","version":env!("CARGO_PKG_VERSION")}
                }),
                |_| {},
            )
            .await?;
        let (session, mut session_ignored, resumed) = if let Some(session_id) = persisted_session_id
        {
            match client
                .request(
                    "session/resume",
                    json!({"sessionId":session_id,"cwd":cwd.display().to_string(),"mcpServers":[]}),
                    |_| {},
                )
                .await
            {
                Ok((result, ignored)) => (result, ignored, true),
                Err(_) => {
                    let (result, ignored) = client
                        .request(
                            "session/new",
                            json!({"cwd":cwd.display().to_string(),"mcpServers":[]}),
                            |_| {},
                        )
                        .await?;
                    (result, ignored, false)
                }
            }
        } else {
            let (result, ignored) = client
                .request(
                    "session/new",
                    json!({"cwd":cwd.display().to_string(),"mcpServers":[]}),
                    |_| {},
                )
                .await?;
            (result, ignored, false)
        };
        let session_id = if resumed {
            persisted_session_id.unwrap_or_default().to_owned()
        } else {
            session
                .get("sessionId")
                .and_then(Value::as_str)
                .ok_or_else(|| AcpError::Invalid(session.to_string()))?
                .to_owned()
        };
        let mut ignored_lines = ignored;
        ignored_lines.append(&mut session_ignored);

        let connected = Arc::try_unwrap(client)
            .map_err(|_| AcpError::Invalid("ACP initialization reference leak".into()))?;
        Ok(Arc::new(Self {
            session_id: session_id.clone(),
            handshake: AcpHandshake {
                agent_name: initialized
                    .pointer("/agentInfo/name")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown")
                    .to_owned(),
                agent_version: initialized
                    .pointer("/agentInfo/version")
                    .and_then(Value::as_str)
                    .unwrap_or("unknown")
                    .to_owned(),
                protocol_version: initialized
                    .get("protocolVersion")
                    .and_then(Value::as_u64)
                    .unwrap_or(0),
                session_id,
                resumed,
                ignored_stdout_lines: ignored_lines,
            },
            ..connected
        }))
    }

    pub fn handshake(&self) -> AcpHandshake {
        self.handshake.clone()
    }

    async fn write_frame(&self, frame: &Value) -> Result<(), AcpError> {
        let mut stdin = self.stdin.lock().await;
        stdin
            .write_all(
                serde_json::to_string(frame)
                    .map_err(|e| AcpError::Invalid(e.to_string()))?
                    .as_bytes(),
            )
            .await?;
        stdin.write_all(b"\n").await?;
        stdin.flush().await?;
        Ok(())
    }

    async fn request<F>(
        &self,
        method: &str,
        params: Value,
        mut notification: F,
    ) -> Result<(Value, Vec<String>), AcpError>
    where
        F: FnMut(Value),
    {
        let _guard = self.request_lock.lock().await;
        let id = self.next_id.fetch_add(1, Ordering::Relaxed);
        self.write_frame(&json!({"jsonrpc":"2.0","id":id,"method":method,"params":params}))
            .await?;
        let mut ignored = Vec::new();
        let result = timeout(Duration::from_secs(300), async {
            let mut lines = self.lines.lock().await;
            loop {
                let line = lines.next_line().await?.ok_or(AcpError::Closed)?;
                let parsed: Value = match serde_json::from_str(&line) {
                    Ok(value) => value,
                    Err(_) => {
                        ignored.push(line);
                        continue;
                    }
                };
                if parsed.get("id").and_then(Value::as_u64) == Some(id) {
                    if let Some(error) = parsed.get("error") {
                        return Err(AcpError::Remote(
                            error
                                .get("message")
                                .and_then(Value::as_str)
                                .unwrap_or("unknown ACP error")
                                .to_owned(),
                        ));
                    }
                    return parsed
                        .get("result")
                        .cloned()
                        .ok_or_else(|| AcpError::Invalid(parsed.to_string()));
                }
                if parsed.get("method").is_some() {
                    notification(parsed);
                }
            }
        })
        .await
        .map_err(|_| AcpError::Timeout)??;
        Ok((result, ignored))
    }

    pub async fn prompt<F>(&self, text: &str, mut on_event: F) -> Result<AcpPromptResult, AcpError>
    where
        F: FnMut(AcpStreamEvent),
    {
        on_event(AcpStreamEvent::Status {
            state: "thinking".into(),
        });
        let mut output = String::new();
        let (result, _) = self
            .request(
                "session/prompt",
                json!({"sessionId":self.session_id,"prompt":[{"type":"text","text":text}]}),
                |frame| {
                    if frame.get("method").and_then(Value::as_str) == Some("session/update") {
                        if let Some(text) = frame
                            .pointer("/params/update/content/text")
                            .and_then(Value::as_str)
                        {
                            output.push_str(text);
                            on_event(AcpStreamEvent::TextDelta {
                                text: text.to_owned(),
                            });
                        }
                    }
                },
            )
            .await?;
        let stop_reason = result
            .get("stopReason")
            .and_then(Value::as_str)
            .map(str::to_owned);
        on_event(AcpStreamEvent::Completed {
            session_id: self.session_id.clone(),
            stop_reason: stop_reason.clone(),
        });
        Ok(AcpPromptResult {
            session_id: self.session_id.clone(),
            text: output,
            stop_reason,
        })
    }

    pub async fn cancel(&self) -> Result<(), AcpError> {
        self.write_frame(&json!({"jsonrpc":"2.0","method":"session/cancel","params":{"sessionId":self.session_id}})).await
    }

    pub async fn close(&self) {
        let _ = self.write_frame(&json!({"jsonrpc":"2.0","method":"session/cancel","params":{"sessionId":self.session_id}})).await;
        let _ = self
            .request(
                "session/close",
                json!({"sessionId":self.session_id}),
                |_| {},
            )
            .await;
        let _ = self.stdin.lock().await.shutdown().await;
        let mut child = self.child.lock().await;
        if timeout(Duration::from_secs(5), child.wait()).await.is_err() {
            let _ = child.kill().await;
        }
    }
}

pub struct AcpManager {
    client: Mutex<Option<Arc<AcpClient>>>,
    session_file: PathBuf,
}

impl AcpManager {
    pub fn new(session_file: PathBuf) -> Self {
        Self {
            client: Mutex::new(None),
            session_file,
        }
    }

    fn persisted_session_id(&self) -> Option<String> {
        std::fs::read_to_string(&self.session_file)
            .ok()
            .map(|value| value.trim().to_owned())
            .filter(|value| !value.is_empty())
    }

    fn persist_session_id(&self, session_id: &str) -> Result<(), AcpError> {
        if let Some(parent) = self.session_file.parent() {
            std::fs::create_dir_all(parent)?;
        }
        std::fs::write(&self.session_file, session_id)?;
        Ok(())
    }

    pub async fn connect(&self, dsh: &Path, cwd: &Path) -> Result<AcpHandshake, AcpError> {
        let mut slot = self.client.lock().await;
        if let Some(client) = slot.as_ref() {
            return Ok(client.handshake());
        }
        let persisted = self.persisted_session_id();
        let client = AcpClient::connect(dsh, cwd, persisted.as_deref()).await?;
        let handshake = client.handshake();
        self.persist_session_id(&handshake.session_id)?;
        *slot = Some(client);
        Ok(handshake)
    }

    pub async fn client(&self) -> Result<Arc<AcpClient>, AcpError> {
        self.client
            .lock()
            .await
            .clone()
            .ok_or(AcpError::NotConnected)
    }

    pub async fn invalidate(&self) {
        if let Some(client) = self.client.lock().await.take() {
            client.close().await;
        }
    }

    pub async fn disconnect(&self) {
        self.invalidate().await;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn extracts_agent_message_text_from_update_shape() {
        let frame = json!({"jsonrpc":"2.0","method":"session/update","params":{"update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"hello"}}}});
        assert_eq!(
            frame
                .pointer("/params/update/content/text")
                .and_then(Value::as_str),
            Some("hello")
        );
    }

    #[test]
    fn cancel_frame_uses_dsh_supported_session_cancel_notification() {
        let frame = json!({"jsonrpc":"2.0","method":"session/cancel","params":{"sessionId":"abc"}});
        assert_eq!(frame.get("id"), None);
        assert_eq!(
            frame.get("method").and_then(Value::as_str),
            Some("session/cancel")
        );
    }
}
