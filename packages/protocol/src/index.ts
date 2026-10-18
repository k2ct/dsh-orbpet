export const PROTOCOL_VERSION = 1 as const;

export type DisplayMode =
  | "pet"
  | "orb"
  | "chat"
  | "approval"
  | "offline"
  | "hidden";

export type NormalizedDshState =
  | "offline"
  | "idle"
  | "thinking"
  | "working"
  | "waiting_approval"
  | "error"
  | "completed";

export type PluginToCompanion =
  | { type: "hello"; protocolVersion: typeof PROTOCOL_VERSION; dshPid: number }
  | { type: "dsh-state"; state: NormalizedDshState }
  | { type: "show"; mode: DisplayMode }
  | { type: "shutdown"; reason: string };

export type CompanionToPlugin =
  | { type: "ready"; protocolVersion: typeof PROTOCOL_VERSION }
  | { type: "heartbeat" }
  | { type: "diagnostic"; level: "info" | "warning" | "error"; message: string }
  | { type: "request-open-dsh" };

export interface PromptInput {
  text: string;
  sessionId?: string;
  workingDirectory?: string;
}

export type DshEvent =
  | { type: "status"; state: NormalizedDshState }
  | { type: "text-delta"; text: string }
  | { type: "completed"; sessionId?: string }
  | { type: "error"; message: string; recoverable: boolean };
