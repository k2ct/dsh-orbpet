import assert from "node:assert/strict";
import test from "node:test";
import { TauriDshAdapter, fromWireEvent, normalizeError } from "../src/dsh-adapter";

const handshake = {
  agentName: "deepseek-harness-acp",
  agentVersion: "0.0.1",
  protocolVersion: 1,
  sessionId: "session-1",
  resumed: false,
  ignoredStdoutLines: [],
};

test("connect records ACP handshake", async () => {
  const calls: Array<{ command: string; args: unknown }> = [];
  const adapter = new TauriDshAdapter(async (command, args) => {
    calls.push({ command, args });
    return handshake as never;
  });
  await adapter.connect("C:\\workspace");
  assert.equal(adapter.status(), "connected");
  assert.equal(adapter.handshake()?.protocolVersion, 1);
  assert.deepEqual(calls, [{ command: "acp_handshake", args: { workingDirectory: "C:\\workspace" } }]);
});

test("prompt yields native stream events in order", async () => {
  let listener: ((event: { payload: never }) => void) | undefined;
  const listen = async (_name: string, handler: typeof listener) => {
    listener = handler;
    return () => {};
  };
  const adapter = new TauriDshAdapter(async (command) => {
    if (command === "acp_handshake") return handshake as never;
    listener?.({ payload: { type: "status", state: "thinking" } as never });
    listener?.({ payload: { type: "textDelta", text: "hel" } as never });
    listener?.({ payload: { type: "textDelta", text: "lo" } as never });
    listener?.({ payload: { type: "completed", sessionId: "session-1", stopReason: "end_turn" } as never });
    return { sessionId: "session-1", text: "hello", stopReason: "end_turn" } as never;
  }, listen as never);

  const events = [];
  for await (const event of adapter.prompt({ text: "hi" })) events.push(event);
  assert.deepEqual(events, [
    { type: "status", state: "thinking" },
    { type: "text-delta", text: "hel" },
    { type: "text-delta", text: "lo" },
    { type: "completed", sessionId: "session-1" },
  ]);
});

test("connect exposes resumed session state", async () => {
  const adapter = new TauriDshAdapter(async () => ({ ...handshake, resumed: true }) as never);
  await adapter.connect();
  assert.equal(adapter.handshake()?.resumed, true);
});

test("cancel invokes ACP session cancellation", async () => {
  const commands: string[] = [];
  const adapter = new TauriDshAdapter(async (command) => {
    commands.push(command);
    return undefined as never;
  });
  await adapter.cancel();
  assert.deepEqual(commands, ["acp_cancel"]);
});

test("maps wire events and normalizes failures", () => {
  assert.deepEqual(fromWireEvent({ type: "textDelta", text: "x" }), { type: "text-delta", text: "x" });
  assert.equal(normalizeError("failed"), "failed");
  assert.equal(normalizeError({ code: 1 }), '{"code":1}');
});
