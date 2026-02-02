// Lightweight WebSocket loopback server for early RTT testing on macOS.
// Acts as a stand-in until full gRPC/WS based on voice.proto is wired.
// Usage: `bun run src/server.ts` then connect WS to ws://localhost:8799/voice

import { promises as fs } from "fs";
import os from "os";
import path from "path";
import { type ClientMessage, type ServerMessage } from "./types";
import { transcribePcm } from "./whisper";

type ServerState = {
  startMs: number;
  buffers: Record<string, Buffer[]>; // session -> audio buffers
};

const PORT = Number(process.env.MYCAT_VOICE_PORT ?? 8799);
const TMP_ROOT = process.env.MYCAT_TMP ?? path.join(os.tmpdir(), "mycat-voice");
const ECHO_LLM = process.env.MYCAT_ECHO_LLM === "1";

function buildHealth(): ServerMessage {
  return {
    session_id: "loopback",
    health: {
      state: "ready",
      message: "loopback placeholder",
    },
  };
}

function buildAsrEcho(text: string): ServerMessage {
  return {
    session_id: "loopback",
    asr: {
      text,
      is_final: true,
      latency_ms: Date.now(),
    },
  };
}

function parseClientMessage(data: unknown): ClientMessage | null {
  try {
    const obj = typeof data === "string" ? JSON.parse(data) : JSON.parse(Buffer.from(data as ArrayBuffer).toString("utf8"));
    if (obj.audio) return { audio: obj.audio };
    if (obj.control) return { control: obj.control };
  } catch {
    return null;
  }
  return null;
}

export async function startServer() {
  const state: ServerState = { startMs: Date.now(), buffers: {} };

  const server = Bun.serve({
    port: PORT,
    fetch(req, server) {
      const { pathname } = new URL(req.url);
      if (pathname !== "/voice") {
        return new Response("not found", { status: 404 });
      }
      if (server.upgrade(req, { data: { state } })) {
        return; // upgrade handled
      }
      return new Response("upgrade failed", { status: 400 });
    },
    websocket: {
      open(ws) {
        ws.send(JSON.stringify(buildHealth()));
      },
      message(ws, raw) {
        const msg = parseClientMessage(raw);
        if (!msg) {
          ws.send(JSON.stringify({ session_id: "loopback", health: { state: "error", message: "bad message" } }));
          return;
        }
        if ("control" in msg && msg.control?.stop) {
          ws.close();
          return;
        }
        if ("audio" in msg && msg.audio) {
          handleAudio(ws, state, msg.audio).catch((err) => {
            ws.send(
              JSON.stringify({
                session_id: "loopback",
                health: { state: "error", message: `asr failed: ${err.message}` },
              }),
            );
          });
          return;
        }
        // text fallthrough (debug)
        const str = typeof raw === "string" ? raw : Buffer.from(raw as ArrayBuffer).toString("utf8");
        ws.send(JSON.stringify(buildAsrEcho(str)));
      },
    },
  });

  console.info(`[mycat] loopback WS listening on ws://localhost:${server.port}/voice`);
  console.info(`[mycat] uptime counter started at ${new Date(state.startMs).toISOString()}`);
}

if (import.meta.main) {
  startServer().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}

async function handleAudio(ws: Bun.WebSocket, state: ServerState, audio: any) {
  const session = "default"; // TODO: derive from auth/session payload
  if (!state.buffers[session]) state.buffers[session] = [];
  // Accept base64 string or Uint8Array
  let buf: Buffer;
  if (typeof audio.data === "string") {
    buf = Buffer.from(audio.data, "base64");
  } else if (audio.data) {
    buf = Buffer.from(audio.data);
  } else {
    ws.send(JSON.stringify({ session_id: session, health: { state: "error", message: "missing audio.data" } }));
    return;
  }
  state.buffers[session].push(buf);
  if (!audio.end_of_utterance) return;

  const tmpDir = path.join(TMP_ROOT, session);
  await fs.mkdir(tmpDir, { recursive: true });
  const file = path.join(tmpDir, `utterance-${Date.now()}.pcm`);
  await fs.writeFile(file, Buffer.concat(state.buffers[session]));
  state.buffers[session] = [];

  // Fire-and-forget ASR
  transcribePcm(
    file,
    { model: process.env.WHISPER_MODEL || "base", binaryPath: process.env.WHISPER_BIN, modelDir: process.env.WHISPER_MODELDIR },
    (chunk) => {
      const payload: ServerMessage = {
        session_id: session,
        asr: { text: chunk.text, is_final: chunk.isFinal, latency_ms: chunk.end },
      };
      ws.send(JSON.stringify(payload));
      if (chunk.isFinal && ECHO_LLM) {
        // Minimal echo LLM/TTS placeholder
        ws.send(
          JSON.stringify({
            session_id: session,
            llm: { partial_text: chunk.text, is_final: true },
          }),
        );
      }
    },
  ).catch((err) => {
    ws.send(JSON.stringify({ session_id: session, health: { state: "error", message: err.message } }));
  });
}
