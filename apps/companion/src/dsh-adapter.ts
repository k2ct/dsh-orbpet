import { invoke } from "@tauri-apps/api/core";
import { listen, type UnlistenFn } from "@tauri-apps/api/event";
import type { DshEvent, NormalizedDshState, PromptInput } from "@dsh-companion/protocol";

export type DshConnectionStatus = "disconnected" | "connecting" | "connected" | "degraded";

export interface AcpHandshake {
  agentName: string;
  agentVersion: string;
  protocolVersion: number;
  sessionId: string;
  resumed: boolean;
  ignoredStdoutLines: string[];
}

interface AcpPromptResult {
  sessionId: string;
  text: string;
  stopReason?: string;
}

type AcpWireEvent =
  | { type: "status"; state: string }
  | { type: "textDelta"; text: string }
  | { type: "completed"; sessionId: string; stopReason?: string }
  | { type: "error"; message: string; recoverable: boolean };

export interface DshAdapter {
  connect(workingDirectory?: string): Promise<void>;
  prompt(input: PromptInput): AsyncIterable<DshEvent>;
  cancel(): Promise<void>;
  status(): DshConnectionStatus;
  close(): Promise<void>;
  handshake(): AcpHandshake | undefined;
}

export type InvokeCommand = typeof invoke;
export type ListenCommand = typeof listen;

function defaultWorkingDirectory(): string {
  return "C:\\DSHCompanion";
}

export class TauriDshAdapter implements DshAdapter {
  #status: DshConnectionStatus = "disconnected";
  #handshake?: AcpHandshake;
  #workingDirectory = defaultWorkingDirectory();

  constructor(
    private readonly invokeCommand: InvokeCommand = invoke,
    private readonly listenCommand: ListenCommand = listen,
  ) {}

  async connect(workingDirectory = defaultWorkingDirectory()): Promise<void> {
    this.#status = "connecting";
    this.#workingDirectory = workingDirectory;
    try {
      this.#handshake = await this.invokeCommand<AcpHandshake>("acp_handshake", { workingDirectory });
      this.#status = "connected";
    } catch (error) {
      this.#status = "degraded";
      throw error;
    }
  }

  async *prompt(input: PromptInput): AsyncIterable<DshEvent> {
    if (this.#status !== "connected") {
      try {
        await this.connect(input.workingDirectory ?? this.#workingDirectory);
      } catch (error) {
        yield { type: "error", message: normalizeError(error), recoverable: true };
        return;
      }
    }

    const requestId = crypto.randomUUID();
    const queue: DshEvent[] = [];
    let wake: (() => void) | undefined;
    let finished = false;
    let invokeError: unknown;
    const push = (event: DshEvent) => {
      queue.push(event);
      wake?.();
      wake = undefined;
    };

    let unlisten: UnlistenFn | undefined;
    try {
      unlisten = await this.listenCommand<AcpWireEvent>(`acp-stream-${requestId}`, ({ payload }) => {
        const event = fromWireEvent(payload);
        if (event) push(event);
      });

      void this.invokeCommand<AcpPromptResult>("acp_prompt_stream", {
        requestId,
        text: input.text,
      }).catch((error) => {
        invokeError = error;
      }).finally(() => {
        finished = true;
        wake?.();
      });

      while (!finished || queue.length > 0) {
        if (queue.length === 0) await new Promise<void>((resolve) => { wake = resolve; });
        while (queue.length > 0) yield queue.shift()!;
      }
      if (invokeError) {
        this.#status = "degraded";
        yield { type: "status", state: "error" };
        yield { type: "error", message: normalizeError(invokeError), recoverable: true };
      }
    } finally {
      unlisten?.();
    }
  }

  async cancel(): Promise<void> {
    await this.invokeCommand("acp_cancel");
  }

  status(): DshConnectionStatus {
    return this.#status;
  }

  handshake(): AcpHandshake | undefined {
    return this.#handshake;
  }

  async close(): Promise<void> {
    try {
      await this.invokeCommand("acp_disconnect");
    } finally {
      this.#status = "disconnected";
      this.#handshake = undefined;
    }
  }
}

export function fromWireEvent(event: AcpWireEvent): DshEvent | undefined {
  if (event.type === "status") return { type: "status", state: event.state as NormalizedDshState };
  if (event.type === "textDelta") return { type: "text-delta", text: event.text };
  if (event.type === "completed") return { type: "completed", sessionId: event.sessionId };
  if (event.type === "error") return { type: "error", message: event.message, recoverable: event.recoverable };
  return undefined;
}

export function normalizeError(error: unknown): string {
  if (error instanceof Error) return error.message;
  if (typeof error === "string") return error;
  try {
    return JSON.stringify(error);
  } catch {
    return "Unknown DSH error";
  }
}
