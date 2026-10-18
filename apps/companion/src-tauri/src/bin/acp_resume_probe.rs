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
    let cwd = env::current_dir()?;
    let first = AcpClient::connect(&dsh, &cwd, None).await?;
    let session_id = first.handshake().session_id;
    first.close().await;

    let resumed = AcpClient::connect(&dsh, &cwd, Some(&session_id)).await?;
    let handshake = resumed.handshake();
    if !handshake.resumed || handshake.session_id != session_id {
        return Err("ACP session was not resumed".into());
    }
    println!(
        "session_resume=true; session_id_preserved=true; protocol={}",
        handshake.protocol_version
    );
    resumed.close().await;
    Ok(())
}
