use keyring_core::{Entry, Error as KeyringError};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    keyring_core::set_default_store(windows_native_keyring_store::Store::new()?);
    let entry = Entry::new("dev.dsh.companion.probe", "roundtrip")?;
    entry.set_password("temporary-probe-value")?;
    let read_back = entry.get_password()?;
    if read_back != "temporary-probe-value" {
        return Err("credential roundtrip mismatch".into());
    }
    match entry.delete_credential() {
        Ok(()) | Err(KeyringError::NoEntry) => {}
        Err(error) => return Err(error.into()),
    }
    println!("windows_credential_manager_roundtrip=true; deleted=true");
    Ok(())
}
