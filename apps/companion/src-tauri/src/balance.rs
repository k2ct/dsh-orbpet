use keyring_core::{Entry, Error as KeyringError};
use serde::{Deserialize, Serialize};
use std::sync::Once;
use thiserror::Error;

const SERVICE: &str = "dev.dsh.companion";
const USER: &str = "deepseek-api-key";
const BALANCE_URL: &str = "https://api.deepseek.com/user/balance";
static INIT_STORE: Once = Once::new();

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BalanceInfo {
    pub currency: String,
    pub total_balance: String,
    pub granted_balance: String,
    pub topped_up_balance: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct BalanceResponse {
    pub is_available: bool,
    pub balance_infos: Vec<BalanceInfo>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct CredentialStatus {
    pub configured: bool,
    pub storage: &'static str,
}

#[derive(Debug, Error)]
pub enum BalanceError {
    #[error("DeepSeek API key is not configured")]
    MissingCredential,
    #[error("Windows Credential Manager error: {0}")]
    Credential(String),
    #[error("DeepSeek balance request failed: {0}")]
    Network(#[from] reqwest::Error),
    #[error("DeepSeek balance request returned HTTP {status}: {body}")]
    Http { status: u16, body: String },
    #[error("DeepSeek returned invalid balance JSON: {0}")]
    Json(#[from] serde_json::Error),
}

fn initialize_store() {
    INIT_STORE.call_once(|| {
        let store = windows_native_keyring_store::Store::new()
            .expect("Windows Credential Manager must be available");
        keyring_core::set_default_store(store);
    });
}

fn entry() -> Result<Entry, BalanceError> {
    initialize_store();
    Entry::new(SERVICE, USER).map_err(|error| BalanceError::Credential(error.to_string()))
}

fn read_key() -> Result<String, BalanceError> {
    match entry()?.get_password() {
        Ok(value) if !value.trim().is_empty() => Ok(value),
        Ok(_) | Err(KeyringError::NoEntry) => Err(BalanceError::MissingCredential),
        Err(error) => Err(BalanceError::Credential(error.to_string())),
    }
}

pub fn credential_status() -> Result<CredentialStatus, BalanceError> {
    let configured = match read_key() {
        Ok(_) => true,
        Err(BalanceError::MissingCredential) => false,
        Err(error) => return Err(error),
    };
    Ok(CredentialStatus {
        configured,
        storage: "windows-credential-manager",
    })
}

pub fn save_key(api_key: &str) -> Result<CredentialStatus, BalanceError> {
    let api_key = api_key.trim();
    if api_key.is_empty() {
        return Err(BalanceError::MissingCredential);
    }
    entry()?
        .set_password(api_key)
        .map_err(|error| BalanceError::Credential(error.to_string()))?;
    Ok(CredentialStatus {
        configured: true,
        storage: "windows-credential-manager",
    })
}

pub fn delete_key() -> Result<CredentialStatus, BalanceError> {
    match entry()?.delete_credential() {
        Ok(()) | Err(KeyringError::NoEntry) => Ok(CredentialStatus {
            configured: false,
            storage: "windows-credential-manager",
        }),
        Err(error) => Err(BalanceError::Credential(error.to_string())),
    }
}

pub async fn fetch_balance() -> Result<BalanceResponse, BalanceError> {
    let api_key = read_key()?;
    let response = reqwest::Client::new()
        .get(BALANCE_URL)
        .bearer_auth(api_key)
        .header(reqwest::header::ACCEPT, "application/json")
        .send()
        .await?;
    let status = response.status();
    let body = response.bytes().await?;
    if !status.is_success() {
        let text = String::from_utf8_lossy(&body);
        let body = text.chars().take(300).collect::<String>();
        return Err(BalanceError::Http {
            status: status.as_u16(),
            body,
        });
    }
    Ok(serde_json::from_slice(&body)?)
}

#[tauri::command]
pub async fn deepseek_credential_status() -> Result<CredentialStatus, String> {
    credential_status().map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn save_deepseek_api_key(api_key: String) -> Result<CredentialStatus, String> {
    save_key(&api_key).map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn delete_deepseek_api_key() -> Result<CredentialStatus, String> {
    delete_key().map_err(|error| error.to_string())
}

#[tauri::command]
pub async fn get_deepseek_balance() -> Result<BalanceResponse, String> {
    fetch_balance().await.map_err(|error| error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_official_balance_shape_without_float_conversion() {
        let json = r#"{
          "is_available": true,
          "balance_infos": [
            {"currency":"CNY","total_balance":"12.34","granted_balance":"2.34","topped_up_balance":"10.00"},
            {"currency":"USD","total_balance":"1.50","granted_balance":"0.00","topped_up_balance":"1.50"}
          ]
        }"#;
        let balance: BalanceResponse = serde_json::from_str(json).unwrap();
        assert!(balance.is_available);
        assert_eq!(balance.balance_infos[0].total_balance, "12.34");
        assert_eq!(balance.balance_infos[1].currency, "USD");
    }
}
