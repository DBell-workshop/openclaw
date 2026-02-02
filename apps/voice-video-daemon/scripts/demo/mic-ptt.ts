// Microphone push-to-talk demo for macOS.
// Records a short clip via sox/ffmpeg (whichever is available), sends to WS server, prints ASR/LLM replies.
// Usage: pnpm --filter @mycat/voice-video-daemon run demo:mic-ptt

import { spawnSync } from "child_process";
import fs from "fs";
import { readFile } from "fs/promises";
import os from "os";
import path from "path";
import WebSocket from "ws";

const url = process.env.MYCAT_VOICE_URL ?? "ws://localhost:8799/voice";
const duration = Number(process.env.DURATION_SEC ?? 4);
const sampleRate = 16000;

function hasBinary(bin: string): boolean {
  const res = spawnSync("which", [bin]);
  return res.status === 0;
}

function record(tmpWav: string) {
  if (hasBinary("sox")) {
    // sox -d -c 1 -r 16000 -b 16 <file> trim 0 <dur>
    const res = spawnSync("sox", ["-d", "-c", "1", "-r", String(sampleRate), "-b", "16", tmpWav, "trim", "0", String(duration)], {
      stdio: "inherit",
    });
    if (res.status === 0) return;
  }
  if (hasBinary("ffmpeg")) {
    const res = spawnSync(
      "ffmpeg",
      ["-y", "-f", "avfoundation", "-i", ":0", "-t", String(duration), "-ac", "1", "-ar", String(sampleRate), tmpWav],
      { stdio: "inherit" },
    );
    if (res.status === 0) return;
  }
  console.error("Neither sox nor ffmpeg found; please install one of them (brew install sox / ffmpeg)." );
  process.exit(1);
}

async function main() {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "mycat-mic-"));
  const wav = path.join(tmpDir, "clip.wav");

  console.info(`Recording ${duration}s... (Ctrl+C to abort)`);
  record(wav);

  const audio = await readFile(wav);
  const ws = new WebSocket(url);

  ws.on("open", () => {
    console.info("[demo] connected", url);
    ws.send(
      JSON.stringify({
        audio: {
          data: audio.toString("base64"),
          sample_rate: sampleRate,
          is_opus: false,
          end_of_utterance: true,
        },
      }),
    );
  });

  ws.on("message", (data) => {
    console.info("[demo] <-", data.toString());
  });

  ws.on("close", () => {
    console.info("[demo] closed");
  });

  ws.on("error", (err) => {
    console.error("[demo] error", err);
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
