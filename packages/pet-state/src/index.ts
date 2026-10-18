import type { NormalizedDshState } from "@dsh-companion/protocol";

export type RawDshSignal =
  | { kind: "connected" }
  | { kind: "disconnected" }
  | { kind: "assistant-thinking" }
  | { kind: "tool-started" }
  | { kind: "approval-required" }
  | { kind: "turn-completed" }
  | { kind: "failure" };

export function reduceDshSignal(signal: RawDshSignal): NormalizedDshState {
  switch (signal.kind) {
    case "connected":
      return "idle";
    case "disconnected":
      return "offline";
    case "assistant-thinking":
      return "thinking";
    case "tool-started":
      return "working";
    case "approval-required":
      return "waiting_approval";
    case "turn-completed":
      return "completed";
    case "failure":
      return "error";
  }
}
