use serde_json::json;
use std::{env, path::PathBuf, process::Stdio, time::Duration};
use tokio::{
    io::{AsyncBufReadExt, AsyncWriteExt, BufReader},
    process::Command,
    time::timeout,
};

const DSH_RELATIVE_PATH: &str = r"Programs\DeepSeek Harness\resources\runtime\cli\bin\dsh.cmd";

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let dsh = env::var_os("DSH_CLI_PATH")
        .map(PathBuf::from)
        .or_else(|| {
            env::var_os("LOCALAPPDATA")
                .map(PathBuf::from)
                .map(|p| p.join(DSH_RELATIVE_PATH))
        })
        .ok_or("DSH launcher not found")?;
    let cwd = env::current_dir()?;
    let mut child = Command::new(&dsh)
        .args(["--profile", "acp"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()?;
    let mut stdin = child.stdin.take().ok_or("missing stdin")?;
    let mut lines = BufReader::new(child.stdout.take().ok_or("missing stdout")?).lines();

    for (id, method, params) in [
        (
            1,
            "initialize",
            json!({"protocolVersion":1,"clientCapabilities":{},"clientInfo":{"name":"dsh-companion-probe","version":"0.1.0"}}),
        ),
        (
            2,
            "session/new",
            json!({"cwd":cwd.display().to_string(),"mcpServers":[]}),
        ),
    ] {
        let frame = json!({"jsonrpc":"2.0","id":id,"method":method,"params":params});
        stdin
            .write_all(serde_json::to_string(&frame)?.as_bytes())
            .await?;
        stdin.write_all(b"\n").await?;
        stdin.flush().await?;
        loop {
            let line = timeout(Duration::from_secs(30), lines.next_line())
                .await??
                .ok_or("stdout closed")?;
            let Ok(value) = serde_json::from_str::<serde_json::Value>(&line) else {
                continue;
            };
            if value.get("id").and_then(|v| v.as_u64()) == Some(id) {
                println!("{}", serde_json::to_string(&value)?);
                break;
            }
        }
    }
    stdin.shutdown().await?;
    let _ = timeout(Duration::from_secs(5), child.wait()).await;
    Ok(())
}
