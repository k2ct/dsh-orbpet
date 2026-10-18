# M0 status

## Completed in the initial scaffold

- Independent GitHub-ready repository rooted at the project directory.
- Tauri 2 configuration for a transparent, frameless, always-on-top window.
- TypeScript pet/orb UI probe and display-mode switching.
- Rust command boundary for click-through and DSH environment probing.
- Single-instance plugin registration in the Tauri builder.
- ACP liveness probe design: spawn the `acp` profile, close stdin, wait for clean exit.
- Headless fallback smoke script.
- DSH host-plugin lifecycle probe.
- Versioned protocol types and stable pet-state reducer.
- Security and third-party notice documents.

## Verified local environment

- DSH: `0.2.1-rc.2`
- Git: available
- Bundled Node: available
- Bundled pnpm: available
- Rust/cargo: `1.99.1`, stable `x86_64-pc-windows-msvc`
- Visual Studio Build Tools: 2022 `17.14.42`, including the C++ desktop workload

## Verification results

- `pnpm install`: passed after explicitly approving the `esbuild` install script.
- `pnpm check`: passed; TypeScript checks and the Vite production build completed.
- `pnpm test`: passed; 2 pet-state reducer tests passed.
- ACP liveness: passed; the `acp` profile started and exited with code 0 after stdin EOF.
- Headless smoke: command path works but the model request is currently blocked by missing `DEEPSEEK_API_KEY`; no credential was created or copied into this repository.

- `cargo check`: passed with the Visual C++ x64 build environment.
- Native debug build: passed; executable generated at `apps/companion/src-tauri/target/debug/dsh-companion.exe`.
- Native tray/click-through self-test: passed; tray initialized, click-through enabled, then interaction restored.
- Hidden lifecycle smoke: passed for 20 iterations; single-instance behavior held and no process remained.
- Plugin supervisor unit tests: 2 passed.
- Plugin-to-native lifecycle smoke: passed; the plugin started the real executable and stopped it on `dispose`.

## M1 chat UI evidence

- Added a chat display mode with message history, Enter-to-send, Shift+Enter newline, busy state, connection status and friendly missing-credential guidance.
- The TypeScript adapter now calls the real Tauri `acp_handshake` and `acp_prompt` commands instead of returning a stub error.
- Adapter unit tests cover handshake state, normalized prompt events and recoverable invoke failures: 4 passed.
- The native application was rebuilt with the chat UI; tray/click-through self-test and a five-cycle hidden lifecycle regression both passed.
- ACP responses are currently returned after the Rust prompt command completes; truly live per-token rendering requires the planned persistent process and Tauri event stream.

## M1 balance and credential evidence

- Added native commands to save, inspect and delete a DeepSeek API key without returning it to the WebView.
- The selected MIT/Apache-2.0 keyring backend uses Windows Credential Manager Generic Credentials.
- A real temporary credential write/read/delete probe passed and removed its probe credential.
- Added official `GET https://api.deepseek.com/user/balance` integration with Bearer authentication, string-preserving monetary fields, tolerant non-JSON error handling and truncated error bodies.
- The public endpoint returned the expected HTTP 401 boundary without a credential.
- The orb and panel now display CNY/USD balance rows, refresh state, availability and credential setup controls.
- A real balance value still requires the user to enter their own DeepSeek official API key; no test key is committed or requested from DSH internals.

## M1 persistent ACP streaming evidence

- Replaced per-prompt ACP child processes with one Rust-managed ACP process and reusable session.
- Added request-scoped Tauri events for status, text chunks, completion and errors.
- The chat panel updates the active assistant message as each native text chunk arrives.
- Added a cancel button backed by the DSH-supported `session/cancel` notification.
- A native persistent probe confirmed protocol v1 and reuse of the same session id without opening a DSH web profile or browser.
- Streaming adapter tests cover ordered chunks and cancellation; 4 tests passed.
- The rebuilt desktop binary passed tray/click-through self-test and five hidden lifecycle iterations with no remaining process.

## M1 session recovery evidence

- The ACP session id is persisted under `%LOCALAPPDATA%\\DSH Companion\\acp-session-id`; no chat content or credential is stored there.
- A later Companion launch attempts DSH `session/resume`; on failure it falls back to `session/new` and replaces the persisted id.
- Graceful shutdown sends `session/close` before stdin EOF, which is required for the current DSH implementation to make the session resumable across ACP processes.
- A native two-process probe created, closed and resumed the same session id successfully without starting a web profile or browser.
- Prompt transport failure invalidates the managed ACP client; the following UI request performs a fresh handshake and resume/new flow.

## Remaining M0/M1 verification

1. Re-run the headless and ACP prompt smoke tests after the user configures a DSH model credential.
2. Manually inspect the visible pet and tray interaction at multiple DPI values; automated native API checks pass, but visual layout still needs human inspection.
3. Build a release bundle that includes the companion executable before testing the active desktop profile.

## Isolated DSH profile result

- Created `companion-test` from the `web` default profile; the active `desktop` profile was not modified.
- Installed the local plugin bundle with `dsh plugin --profile companion-test add file:C:/DSHCompanion/plugins/dsh-companion`.
- `plugin why` and `--dump-config` confirmed the bundle and patch entry.
- Added a test-profile-only absolute executable override.
- Booting the isolated profile started the real companion process; stopping the profile left zero companion processes.
- The bundle structure is valid, but a distributable release must package `bin/dsh-companion.exe`; the development override must not be required by end users.

No claim of a compiled or fully working desktop binary is made until these checks pass.
