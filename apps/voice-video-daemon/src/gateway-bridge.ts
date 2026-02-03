import { randomUUID } from "node:crypto";

import { GatewayClient } from "../../../src/gateway/client.js";
import { PROTOCOL_VERSION, type EventFrame } from "../../../src/gateway/protocol/index.js";
import { GATEWAY_CLIENT_MODES, GATEWAY_CLIENT_NAMES } from "../../../src/utils/message-channel.js";
import type { ActionEvent } from "./types";

type ChatEventPayload = {
  runId?: string;
  sessionKey?: string;
  state?: string;
  message?: unknown;
  errorMessage?: string;
};

type AgentEventPayload = {
  runId?: string;
  sessionKey?: string;
  stream?: string;
  data?: Record<string, unknown>;
};

type RunContext = {
  ws: Bun.WebSocket;
  voiceSessionId: string;
  gatewaySessionKey: string;
  buffer: string;
};

type SessionLink = {
  ws: Bun.WebSocket;
  voiceSessionId: string;
};

type GatewayVoiceClientOptions = {
  url: string;
  token?: string;
  password?: string;
  sessionKey: string;
  thinking?: string;
  timeoutMs?: number;
  onLlmUpdate: (payload: {
    ws: Bun.WebSocket;
    voiceSessionId: string;
    runId: string;
    text: string;
    isFinal: boolean;
  }) => void;
  onAction: (payload: {
    ws: Bun.WebSocket;
    voiceSessionId: string;
    runId: string;
    action: ActionEvent;
  }) => void;
  onError: (payload: {
    ws?: Bun.WebSocket;
    voiceSessionId?: string;
    runId?: string;
    message: string;
  }) => void;
};

const DEFAULT_READY_TIMEOUT_MS = 8000;

export class GatewayVoiceClient {
  private client: GatewayClient;
  private opts: GatewayVoiceClientOptions;
  private runMap = new Map<string, RunContext>();
  private sessionMap = new Map<string, SessionLink>();
  private readyPromise: Promise<void>;
  private resolveReady?: () => void;
  private readyAtMs: number | null = null;

  constructor(opts: GatewayVoiceClientOptions) {
    this.opts = opts;
    this.readyPromise = new Promise((resolve) => {
      this.resolveReady = resolve;
    });
    this.client = new GatewayClient({
      url: opts.url,
      token: opts.token,
      password: opts.password,
      clientName: GATEWAY_CLIENT_NAMES.GATEWAY_CLIENT,
      clientDisplayName: "mycat-voice",
      clientVersion: "dev",
      platform: process.platform,
      mode: GATEWAY_CLIENT_MODES.BACKEND,
      minProtocol: PROTOCOL_VERSION,
      maxProtocol: PROTOCOL_VERSION,
      onHelloOk: () => this.markReady(),
      onEvent: (evt) => this.handleEvent(evt),
      onConnectError: (err) => {
        this.opts.onError({ message: err.message || String(err) });
      },
      onClose: (code, reason) => {
        this.handleDisconnect(`gateway closed (${code}): ${reason}`);
      },
    });
  }

  start() {
    this.client.start();
  }

  stop() {
    this.client.stop();
  }

  async sendChat(params: { ws: Bun.WebSocket; voiceSessionId: string; text: string }) {
    const text = params.text.trim();
    if (!text) return null;
    try {
      await this.waitForReady();
    } catch (err) {
      this.opts.onError({
        ws: params.ws,
        voiceSessionId: params.voiceSessionId,
        message: err instanceof Error ? err.message : String(err),
      });
      return null;
    }
    const runId = randomUUID();
    this.runMap.set(runId, {
      ws: params.ws,
      voiceSessionId: params.voiceSessionId,
      gatewaySessionKey: this.opts.sessionKey,
      buffer: "",
    });
    this.sessionMap.set(this.opts.sessionKey, {
      ws: params.ws,
      voiceSessionId: params.voiceSessionId,
    });
    try {
      await this.client.request("chat.send", {
        sessionKey: this.opts.sessionKey,
        message: text,
        thinking: this.opts.thinking,
        timeoutMs: this.opts.timeoutMs,
        deliver: false,
        idempotencyKey: runId,
      });
      return runId;
    } catch (err) {
      this.runMap.delete(runId);
      this.opts.onError({
        ws: params.ws,
        voiceSessionId: params.voiceSessionId,
        runId,
        message: err instanceof Error ? err.message : String(err),
      });
      return null;
    }
  }

  dropSocket(ws: Bun.WebSocket) {
    for (const [runId, entry] of this.runMap) {
      if (entry.ws === ws) this.runMap.delete(runId);
    }
    for (const [sessionKey, entry] of this.sessionMap) {
      if (entry.ws === ws) this.sessionMap.delete(sessionKey);
    }
  }

  private markReady() {
    this.readyAtMs = Date.now();
    this.resolveReady?.();
  }

  private handleDisconnect(message: string) {
    this.resetReady();
    for (const [runId, ctx] of this.runMap) {
      this.opts.onError({
        ws: ctx.ws,
        voiceSessionId: ctx.voiceSessionId,
        runId,
        message,
      });
    }
    this.runMap.clear();
    this.opts.onError({ message });
  }

  private resetReady() {
    this.readyAtMs = null;
    this.readyPromise = new Promise((resolve) => {
      this.resolveReady = resolve;
    });
  }

  private async waitForReady(timeoutMs = DEFAULT_READY_TIMEOUT_MS) {
    if (this.readyAtMs) return;
    await Promise.race([
      this.readyPromise,
      new Promise<void>((_resolve, reject) =>
        setTimeout(() => reject(new Error("gateway connect timeout")), timeoutMs),
      ),
    ]);
  }

  private handleEvent(evt: EventFrame) {
    if (evt.event === "chat") {
      this.handleChatEvent(evt.payload as ChatEventPayload | undefined);
      return;
    }
    if (evt.event === "agent") {
      this.handleAgentEvent(evt.payload as AgentEventPayload | undefined);
    }
  }

  private handleChatEvent(payload?: ChatEventPayload) {
    if (!payload) return;
    const runId = typeof payload.runId === "string" ? payload.runId : "";
    if (!runId) return;
    const ctx = this.runMap.get(runId);
    if (!ctx) return;
    const state = typeof payload.state === "string" ? payload.state : "";
    if (state === "error") {
      this.opts.onError({
        ws: ctx.ws,
        voiceSessionId: ctx.voiceSessionId,
        runId,
        message: payload.errorMessage || "gateway chat error",
      });
      this.runMap.delete(runId);
      return;
    }
    if (state === "aborted") {
      this.runMap.delete(runId);
      return;
    }

    const text = extractChatText(payload.message);
    if (state === "delta") {
      if (text) ctx.buffer = text;
      this.opts.onLlmUpdate({
        ws: ctx.ws,
        voiceSessionId: ctx.voiceSessionId,
        runId,
        text,
        isFinal: false,
      });
      return;
    }

    if (state === "final") {
      const finalText = text || ctx.buffer;
      this.opts.onLlmUpdate({
        ws: ctx.ws,
        voiceSessionId: ctx.voiceSessionId,
        runId,
        text: finalText,
        isFinal: true,
      });
      this.runMap.delete(runId);
    }
  }

  private handleAgentEvent(payload?: AgentEventPayload) {
    if (!payload) return;
    if (payload.stream !== "tool") return;
    const runId = typeof payload.runId === "string" ? payload.runId : "";
    if (!runId) return;
    const data = payload.data ?? {};
    const action = buildActionEvent(data);
    if (!action) return;
    const ctx =
      this.runMap.get(runId) ||
      (typeof payload.sessionKey === "string" ? this.sessionMap.get(payload.sessionKey) : undefined);
    if (!ctx) return;
    this.opts.onAction({
      ws: ctx.ws,
      voiceSessionId: ctx.voiceSessionId,
      runId,
      action,
    });
  }
}

function extractChatText(message: unknown): string {
  if (typeof message === "string") return message;
  if (!message || typeof message !== "object") return "";
  const record = message as Record<string, unknown>;
  if (typeof record.text === "string") return record.text;
  const content = record.content;
  if (!Array.isArray(content)) return "";
  const parts = content
    .map((item) => {
      if (!item || typeof item !== "object") return null;
      const entry = item as Record<string, unknown>;
      if (entry.type === "text" && typeof entry.text === "string") return entry.text;
      return null;
    })
    .filter((part): part is string => Boolean(part));
  return parts.join("");
}

function buildActionEvent(data: Record<string, unknown>): ActionEvent | null {
  const toolCallId = typeof data.toolCallId === "string" ? data.toolCallId : "";
  if (!toolCallId) return null;
  const name = typeof data.name === "string" ? data.name : "tool";
  const phase = typeof data.phase === "string" ? data.phase : "";
  if (phase === "update") return null;
  const isError = data.isError === true;
  let status: ActionEvent["status"] = "running";
  if (phase === "result") {
    status = isError ? "error" : "done";
  }
  const meta = typeof data.meta === "string" ? data.meta : "";
  const detail = formatPreview(phase === "start" ? data.args : data.result);
  const normalized = name.toLowerCase();
  const type: ActionEvent["type"] =
    normalized.includes("browser") || normalized.includes("web") ? "browser" : "desktop";
  const approvalRequired = meta.includes("elevated");
  const risk_level: ActionEvent["risk_level"] = approvalRequired ? "high" : "low";
  return {
    id: toolCallId,
    type,
    title: meta ? `${name} · ${meta}` : name,
    detail,
    status,
    risk_level,
    approval_required: approvalRequired || undefined,
  };
}

function formatPreview(value: unknown, maxLen = 180): string | undefined {
  if (value === null || value === undefined) return undefined;
  let text: string;
  if (typeof value === "string") {
    text = value;
  } else {
    try {
      text = JSON.stringify(value, null, 2);
    } catch {
      text = String(value);
    }
  }
  const trimmed = text.trim();
  if (trimmed.length <= maxLen) return trimmed;
  return `${trimmed.slice(0, maxLen)}…`;
}
