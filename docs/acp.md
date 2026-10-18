# DSH ACP integration

DSH `0.2.1-rc.2` exposes Agent Client Protocol v1 over stdio.

## Transport

- JSON-RPC 2.0
- one JSON object per line (NDJSON)
- no `Content-Length` framing
- stdout should contain protocol frames, but the client defensively ignores non-JSON diagnostic lines because the current DSH model provider can emit one during session creation

## Supported flow

1. `initialize`
2. `session/new`, or `session/resume` for a persisted DSH session
3. `session/prompt`
4. collect `session/update` notifications
5. wait for the original prompt response and its `stopReason`
6. optionally call `session/close`, then close stdin

DSH `0.2.1-rc.2` does not advertise or register `session/load`; use `session/resume` instead.

### Initialize

```json
{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{},"clientInfo":{"name":"dsh-desktop-companion","version":"0.1.0"}}}
```

### New session

```json
{"jsonrpc":"2.0","id":2,"method":"session/new","params":{"cwd":"C:\\absolute\\workspace","mcpServers":[]}}
```

### Prompt

```json
{"jsonrpc":"2.0","id":3,"method":"session/prompt","params":{"sessionId":"...","prompt":[{"type":"text","text":"Hello"}]}}
```

Text arrives through `session/update`, usually with `update.sessionUpdate = agent_message_chunk` and `update.content.text`. The final response is similar to:

```json
{"jsonrpc":"2.0","id":3,"result":{"stopReason":"end_turn"}}
```

### Cancel

Preferred turn cancellation is a notification without an id:

```json
{"jsonrpc":"2.0","method":"session/cancel","params":{"sessionId":"..."}}
```

The M1 Rust bridge keeps one ACP child process and session for the lifetime of the Companion connection. Prompt updates are emitted to the Tauri window as request-scoped native events, so the chat panel renders text chunks as they arrive. `session/cancel` is implemented and exposed through the UI. Before a graceful disconnect, the client calls `session/close`, then closes stdin. The session id is persisted under the current user's local application data and supplied to `session/resume` on the next launch; if resume fails, the client creates and persists a replacement session. A transport failure invalidates the in-memory client so the next UI request reconnects instead of reusing a dead process.

Public protocol references:

- https://agentclientprotocol.com/protocol/v1/initialization
- https://agentclientprotocol.com/protocol/v1/session-setup
- https://agentclientprotocol.com/protocol/v1/prompt-turn
- https://agentclientprotocol.com/protocol/v1/cancellation
- https://agentclientprotocol.com/protocol/v1/transports
