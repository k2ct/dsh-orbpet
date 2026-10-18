# Architecture

The DSH Desktop Companion is a DSH-managed native companion, not an in-page-only widget.

## Process model

- The DSH host plugin supervises the companion executable.
- The Tauri/Rust process owns native windows, tray, credentials and DSH child processes.
- The WebView receives only presentation-safe state and never receives provider API keys.
- ACP stdio is the preferred DSH conversation channel.
- Headless CLI is a clearly labelled degraded single-turn fallback.

## Stable boundaries

1. `protocol`: versioned plugin/companion messages.
2. `pet-state`: converts volatile DSH events into stable visual states.
3. `DshAdapter`: isolates ACP and headless transports from the UI.
4. `BalanceProvider`: will expose balance data without exposing credentials.
5. `WindowHost`: Tauri-native window, tray, DPI and click-through behavior.

The project must not depend on the currently running DSH GUI's random localhost port or private Electron IPC channels.
