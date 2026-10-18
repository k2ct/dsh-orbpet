use dsh_companion_lib::acp::AcpClient;
use std::{env, path::PathBuf};

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
    let client = AcpClient::connect(&dsh, &env::current_dir()?, None).await?;
    let first = client.handshake();
    let second = client.handshake();
    if first.session_id != second.session_id {
        return Err("persistent client changed session id".into());
    }
    println!(
        "persistent_acp=true; protocol={}; session_reused=true; agent={}",
        first.protocol_version, first.agent_name
    );
    client.close().await;
    Ok(())
}
