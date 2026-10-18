use crate::acp;
use serde::Serialize;
use std::{env, path::PathBuf, process::Stdio, time::Duration};
use tauri::{command, Emitter, State, WebviewWindow};
use thiserror::Error;
use tokio::{io::AsyncWriteExt, process::Command, time::timeout};

const DSH_RELATIVE_PATH: &str = r"Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd";

#[derive(Debug, Error)]
pub enum DshProbeError {
    #[error("DSH launcher was not found at {0}")]
    MissingLauncher(String),
    #[error("failed to start DSH: {0}")]
    Spawn(#[from] std::io::Error),
    #[error("DSH version probe timed out")]
    Timeout,
    #[error("DSH exited unsuccessfully: {0}")]
    Exit(String),
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct DshEnvironment {
    launcher: String,
    version: String,
    acp_probe_started: bool,
}

fn dsh_launcher() -> PathBuf {
    if let Some(explicit) = env::var_os("DSH_CLI_PATH") {
        return PathBuf::from(explicit);
    }

    env::var_os("LOCALAPPDATA")
        .map(PathBuf::from)
        .map(|base| base.join(DSH_RELATIVE_PATH))
        .unwrap_or_else(|| PathBuf::from("dsh.cmd"))
}

async fn dsh_version(path: &PathBuf) -> Result<String, DshProbeError> {
    if !path.is_file() {
        return Err(DshProbeError::MissingLauncher(path.display().to_string()));
    }

    let output = timeout(
        Duration::from_secs(10),
        Command::new("cmd.exe")
            .args(["/d", "/s", "/c"])
            .arg(format!("\"{}\" --version", path.display()))
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .output(),
    )
    .await
    .map_err(|_| DshProbeError::Timeout)??;

    if !output.status.success() {
        return Err(DshProbeError::Exit(
            String::from_utf8_lossy(&output.stderr).trim().to_owned(),
        ));
    }

    Ok(String::from_utf8_lossy(&output.stdout).trim().to_owned())
}

/// M0 liveness probe only. It verifies that the ACP profile can be spawned and
/// accepts a stdio pipe, then immediately closes stdin so DSH can exit cleanly.
async fn acp_liveness(path: &PathBuf) -> Result<bool, DshProbeError> {
    let mut child = Command::new("cmd.exe")
        .args(["/d", "/s", "/c"])
        .arg(format!("\"{}\" --profile acp", path.display()))
        .stdin(Stdio::piped())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()?;

    if let Some(mut stdin) = child.stdin.take() {
        stdin.shutdown().await?;
    }

    let _ = timeout(Duration::from_secs(10), child.wait())
        .await
        .map_err(|_| DshProbeError::Timeout)??;
    Ok(true)
}

#[command]
pub async fn probe_dsh_environment() -> Result<DshEnvironment, String> {
    let launcher = dsh_launcher();
    let version = dsh_version(&launcher).await.map_err(|e| e.to_string())?;
    let acp_probe_started = acp_liveness(&launcher).await.map_err(|e| e.to_string())?;

    Ok(DshEnvironment {
        launcher: launcher.display().to_string(),
        version,
        acp_probe_started,
    })
}

#[command]
pub async fn acp_handshake(
    working_directory: String,
    manager: State<'_, acp::AcpManager>,
) -> Result<acp::AcpHandshake, String> {
    manager
        .connect(&dsh_launcher(), &PathBuf::from(working_directory))
        .await
        .map_err(|error| error.to_string())
}

#[command]
pub async fn acp_prompt_stream(
    window: WebviewWindow,
    manager: State<'_, acp::AcpManager>,
    request_id: String,
    text: String,
) -> Result<acp::AcpPromptResult, String> {
    let client = manager.client().await.map_err(|error| error.to_string())?;
    let event_name = format!("acp-stream-{request_id}");
    let result = client
        .prompt(&text, |event| {
            let _ = window.emit(&event_name, event);
        })
        .await;
    if let Err(error) = &result {
        let _ = window.emit(
            &event_name,
            acp::AcpStreamEvent::Error {
                message: error.to_string(),
                recoverable: true,
            },
        );
        manager.invalidate().await;
    }
    result.map_err(|error| error.to_string())
}

#[command]
pub async fn acp_cancel(manager: State<'_, acp::AcpManager>) -> Result<(), String> {
    manager
        .client()
        .await
        .map_err(|error| error.to_string())?
        .cancel()
        .await
        .map_err(|error| error.to_string())
}

#[command]
pub async fn acp_disconnect(manager: State<'_, acp::AcpManager>) -> Result<(), String> {
    manager.disconnect().await;
    Ok(())
}
