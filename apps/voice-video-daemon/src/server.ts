// Lightweight WebSocket loopback server for early RTT testing on macOS.
// Acts as a stand-in until full gRPC/WS based on voice.proto is wired.
// Usage: `bun run src/server.ts` then connect WS to ws://localhost:8799/voice

import { promises as fs } from "fs";
import os from "os";
import path from "path";
import { type ClientMessage, type ServerMessage } from "./types";
import { transcribePcm } from "./whisper";
import { speak, synthesizeToPcmWave } from "./tts-macos";
import { OpusDecoder } from "@discordjs/opus";
import { streamEdgeTts } from "./tts-edge";
import { spawn, execFile } from "child_process";
import { GatewayVoiceClient } from "./gateway-bridge";

type ServerState = {
  startMs: number;
  buffers: Record<string, Buffer[]>; // session -> audio buffers
};

const PORT = Number(process.env.MYCAT_VOICE_PORT ?? 8799);
const TMP_ROOT = process.env.MYCAT_TMP ?? path.join(os.tmpdir(), "mycat-voice");
const ECHO_LLM = process.env.MYCAT_ECHO_LLM === "1";
const USE_GATEWAY = process.env.MYCAT_USE_GATEWAY !== "0" && !ECHO_LLM;
const TTS_ENABLED = process.env.MYCAT_TTS === "1";
const TTS_STREAM = process.env.MYCAT_TTS_STREAM === "1";
const TTS_CHUNK_MS = Number(process.env.MYCAT_TTS_CHUNK_MS ?? 40); // 40ms chunks by default
const TTS_ENGINE = process.env.MYCAT_TTS_ENGINE || "mac"; // mac|edge|styletts2|matcha
const OPUS_DECODER = new OpusDecoder(16000, 1);
const PYTHON_BIN = process.env.MYCAT_PYTHON || "python3";
const PY_TTS_WORKER = path.resolve(new URL(".", import.meta.url).pathname, "../python/tts_worker.py");
const AUTO_PIP = process.env.MYCAT_TTS_PIP_AUTO === "1";
const ACTION_DEMO = process.env.MYCAT_ACTION_DEMO === "1";
const GATEWAY_URL = process.env.MYCAT_GATEWAY_URL || "ws://127.0.0.1:18789";
const GATEWAY_TOKEN = process.env.MYCAT_GATEWAY_TOKEN || process.env.OPENCLAW_GATEWAY_TOKEN;
const GATEWAY_PASSWORD = process.env.MYCAT_GATEWAY_PASSWORD || process.env.OPENCLAW_GATEWAY_PASSWORD;
const GATEWAY_SESSION = process.env.MYCAT_GATEWAY_SESSION || "voice";
const GATEWAY_THINKING = process.env.MYCAT_GATEWAY_THINKING;
const GATEWAY_TIMEOUT_MS = Number(process.env.MYCAT_GATEWAY_TIMEOUT_MS ?? 0) || undefined;
let gatewayClient: GatewayVoiceClient | null = null;

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
  gatewayClient = USE_GATEWAY
    ? new GatewayVoiceClient({
        url: GATEWAY_URL,
        token: GATEWAY_TOKEN,
        password: GATEWAY_PASSWORD,
        sessionKey: GATEWAY_SESSION,
        thinking: GATEWAY_THINKING,
        timeoutMs: GATEWAY_TIMEOUT_MS,
        onLlmUpdate: ({ ws, voiceSessionId, text, isFinal }) => {
          if (!text && !isFinal) return;
          ws.send(
            JSON.stringify({
              session_id: voiceSessionId,
              llm: { partial_text: text, is_final: isFinal },
            }),
          );
          if (isFinal && TTS_ENABLED && text) {
            runTts(ws, voiceSessionId, text).catch((err) =>
              ws.send(
                JSON.stringify({
                  session_id: voiceSessionId,
                  health: { state: "error", message: `tts: ${err.message}` },
                }),
              ),
            );
          }
        },
        onAction: ({ ws, voiceSessionId, action }) => {
          ws.send(JSON.stringify({ session_id: voiceSessionId, action }));
        },
        onError: ({ ws, voiceSessionId, message }) => {
          if (!ws) return;
          ws.send(
            JSON.stringify({
              session_id: voiceSessionId ?? "default",
              health: { state: "error", message },
            }),
          );
        },
      })
    : null;
  gatewayClient?.start();

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
      close(ws) {
        gatewayClient?.dropSocket(ws);
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
  if (USE_GATEWAY) {
    console.info(`[mycat] gateway LLM enabled: ${GATEWAY_URL} (session=${GATEWAY_SESSION})`);
  }
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
  // Accept base64 string or Uint8Array, optionally opus
  let buf: Buffer;
  if (typeof audio.data === "string") {
    buf = Buffer.from(audio.data, "base64");
  } else if (audio.data) {
    buf = Buffer.from(audio.data);
  } else {
    ws.send(JSON.stringify({ session_id: session, health: { state: "error", message: "missing audio.data" } }));
    return;
  }
  if (audio.is_opus) {
    try {
      const pcm = Buffer.from(OPUS_DECODER.decode(buf));
      state.buffers[session].push(pcm);
    } catch (err) {
      ws.send(JSON.stringify({ session_id: session, health: { state: "error", message: `opus decode: ${err}` } }));
    }
  } else {
    state.buffers[session].push(buf);
  }
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
        const text = chunk.text.trim();
        if (ACTION_DEMO && text) {
          emitActionDemo(ws, session, text);
        }
        ws.send(JSON.stringify({ session_id: session, llm: { partial_text: text, is_final: true } }));
        if (TTS_ENABLED && text) {
          runTts(ws, session, text).catch((err) =>
            ws.send(JSON.stringify({ session_id: session, health: { state: "error", message: `tts: ${err.message}` } })),
          );
        }
      } else if (chunk.isFinal && USE_GATEWAY) {
        const text = chunk.text.trim();
        if (!text) return;
        gatewayClient?.sendChat({ ws, voiceSessionId: session, text });
      }
    },
  ).catch((err) => {
    ws.send(JSON.stringify({ session_id: session, health: { state: "error", message: err.message } }));
  });
}

async function runTts(ws: Bun.WebSocket, session: string, text: string) {
  if (!TTS_STREAM) {
    await speak(text);
    ws.send(JSON.stringify({ session_id: session, tts: { audio: new Uint8Array(), is_final: true } }));
    return;
  }

  if (TTS_ENGINE === "edge") {
    for await (const chunk of streamEdgeTts(text)) {
      ws.send(
        JSON.stringify({
          session_id: session,
          tts: {
            audio_base64: Buffer.from(chunk.audio).toString("base64"),
            codec: "mp3",
            is_opus: false,
            is_final: chunk.isFinal,
            sample_rate: chunk.sampleRate,
          },
        }),
      );
    }
    return;
  }

  if (TTS_ENGINE === "styletts2" || TTS_ENGINE === "matcha") {
    await ensurePythonDeps(TTS_ENGINE);
    await streamPythonTts(ws, session, text);
    return;
  }

  // default macOS synth to wav then chunk
  const { pcm, sampleRate } = await synthesizeToPcmWave(text);
  streamPcmChunks(ws, session, pcm, sampleRate, TTS_CHUNK_MS);
}

function streamPcmChunks(ws: Bun.WebSocket, session: string, pcm: Buffer, sampleRate: number, chunkMs: number) {
  const bytesPerSample = 2; // 16-bit LE mono
  const bytesPerChunk = Math.max(1, Math.floor((sampleRate * bytesPerSample * chunkMs) / 1000));
  for (let offset = 0; offset < pcm.length; offset += bytesPerChunk) {
    const end = Math.min(offset + bytesPerChunk, pcm.length);
    const slice = pcm.subarray(offset, end);
    const is_final = end >= pcm.length;
    ws.send(
      JSON.stringify({
        session_id: session,
        tts: {
          audio_base64: slice.toString("base64"),
          is_opus: false,
          is_final,
          sample_rate: sampleRate,
        },
      }),
    );
  }
}

function emitActionDemo(ws: Bun.WebSocket, session: string, text: string) {
  const id = `demo-${Date.now()}`;
  const risk =
    /delete|remove|erase|drop|rm|trash|危险|删除|清空/i.test(text) ? "high" : /pay|send|purchase|转账|付款/i.test(text) ? "medium" : "low";
  const approval_required = risk !== "low";

  const base = {
    session_id: session,
    action: {
      id,
      type: "browser",
      title: `Plan: ${text.slice(0, 24)}`,
      detail: text,
      risk_level: risk,
      approval_required,
    },
  };

  ws.send(JSON.stringify({ ...base, action: { ...base.action, status: "planned" } }));
  setTimeout(() => ws.send(JSON.stringify({ ...base, action: { ...base.action, status: "running" } })), 400);
  setTimeout(() => ws.send(JSON.stringify({ ...base, action: { ...base.action, status: "done" } })), 1000);
}

async function streamPythonTts(ws: Bun.WebSocket, session: string, text: string) {
  return new Promise<void>((resolve, reject) => {
    const child = spawn(PYTHON_BIN, [PY_TTS_WORKER], { stdio: ["pipe", "pipe", "inherit"] });
    child.stdin.write(text + "\n");
    child.stdin.end();

    let buffer = Buffer.alloc(0);
    child.stdout.on("data", (chunk) => {
      buffer = Buffer.concat([buffer, chunk]);
      while (buffer.length >= 4) {
        const len = buffer.readUInt32LE(0);
        if (buffer.length < 4 + len) break;
        const audio = buffer.subarray(4, 4 + len);
        buffer = buffer.subarray(4 + len);
        const is_final = len === 0;
        ws.send(
          JSON.stringify({
            session_id: session,
            tts: {
              audio_base64: audio.length ? audio.toString("base64") : undefined,
              codec: "pcm16",
              is_opus: false,
              is_final,
              sample_rate: 24000,
            },
          }),
        );
        if (is_final) resolve();
      }
    });
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) return;
      reject(new Error(`python tts exited ${code}`));
    });
  });
}

async function ensurePythonDeps(engine: string) {
  const moduleName = engine === "styletts2" ? "styletts2" : "matcha_tts";
  try {
    await execFileAsync(PYTHON_BIN, ["-c", `import ${moduleName}`]);
    return;
  } catch (err: any) {
    if (!AUTO_PIP) {
      throw new Error(
        `Python module '${moduleName}' missing. Install with: ${PYTHON_BIN} -m pip install styletts2 matcha-tts (or set MYCAT_TTS_PIP_AUTO=1 to auto-install)`,
      );
    }
    const pkg = engine === "styletts2" ? "styletts2" : "matcha-tts";
    await execFileAsync(PYTHON_BIN, ["-m", "pip", "install", pkg]);
  }
}

function execFileAsync(cmd: string, args: string[]) {
  return new Promise<void>((resolve, reject) => {
    execFile(cmd, args, (err) => {
      if (err) return reject(err);
      resolve();
    });
  });
}
