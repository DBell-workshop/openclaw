// Push-to-talk demo: send a PCM/WAV file to the WS server and print ASR replies.
// Usage:
//   FILE=sample.wav pnpm --filter @mycat/voice-video-daemon run demo:ptt
//   pnpm --filter @mycat/voice-video-daemon run demo:ptt --file sample.wav

import fs from "fs";
import { readFile } from "fs/promises";
import WebSocket from "ws";
import path from "path";

const url = process.env.MYCAT_VOICE_URL ?? "ws://localhost:8799/voice";
const fileArg = process.env.FILE || process.argv.find((a) => a.startsWith("--file="))?.split("=")[1];

async function main() {
  if (!fileArg) {
    console.error("Usage: FILE=sample.wav pnpm --filter @mycat/voice-video-daemon run demo:ptt");
    process.exit(1);
  }
  const filePath = path.resolve(fileArg);
  if (!fs.existsSync(filePath)) {
    console.error("File not found:", filePath);
    process.exit(1);
  }
  const audio = await readFile(filePath);
  const ws = new WebSocket(url);

  ws.on("open", () => {
    console.info("[demo] connected", url);
    ws.send(
      JSON.stringify({
        audio: {
          data: audio.toString("base64"),
          sample_rate: 16000,
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
