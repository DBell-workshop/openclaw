// Lightweight WebSocket loopback server for early RTT testing on macOS.
// Acts as a stand-in until full gRPC/WS based on voice.proto is wired.
// Usage: `bun run src/server.ts` then connect WS to ws://localhost:8799/voice

import { type ClientMessage, type ServerMessage } from "./types";

type ServerState = {
  startMs: number;
};

const PORT = Number(process.env.MYCAT_VOICE_PORT ?? 8799);

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
  const state: ServerState = { startMs: Date.now() };

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
          // For now just echo text placeholder; real ASR will decode audio.
          ws.send(JSON.stringify(buildAsrEcho("[audio]")));
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
