# Security model

## Trust boundaries

- DSH and its approval/sandbox mechanisms remain authoritative for tool execution.
- The companion is a user interface and transport client, not an approval bypass.
- Provider credentials belong to the native backend credential vault.
- The WebView is treated as untrusted for long-lived credentials.

## Implemented rules

- DeepSeek balance uses only the official `GET https://api.deepseek.com/user/balance` endpoint.
- No browser cookie or private DeepSeek endpoint is used.
- The API key is stored as a Generic Credential in Windows Credential Manager through the MIT/Apache-2.0 `keyring-core` and `windows-native-keyring-store` crates.
- The key is read only in Rust, used to construct the HTTPS Authorization header, and is never returned by a Tauri command.
- The WebView may submit a key once to the narrow `save_deepseek_api_key` command; after storage it receives only `{ configured, storage }` status.
- Neither the key nor Authorization header is logged, serialized into settings, committed to Git, or included in balance errors.
- Non-success balance bodies are truncated before presentation and are not assumed to be JSON.
- No server listens on a non-loopback interface.
- No plugin-to-companion command permits arbitrary shell execution.

## Residual risks

- Windows Credential Manager protects at the current Windows user boundary; malware already running as that user may be able to read Generic Credentials.
- Generic Credential access does not require Windows Hello confirmation on every read.
- A temporary API key `String` exists in native process memory while saving or making a request. It is not intentionally cached.
- The UI currently uses a browser prompt for initial entry. A dedicated masked native settings form should replace it before release.
- DSH approval and sandbox decisions remain outside the balance subsystem and cannot be bypassed by the companion.
