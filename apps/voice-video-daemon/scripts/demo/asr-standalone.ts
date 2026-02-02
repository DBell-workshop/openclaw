// Simple standalone ASR demo: feeds a WAV/PCM file to whisper CLI and prints text.
// Usage: pnpm --filter @mycat/voice-video-daemon run asr --file path/to/audio.wav

import { transcribePcm } from "../src/whisper";
import path from "path";
import fs from "fs";

async function main() {
  const file = process.env.FILE || process.argv.find((a) => a.startsWith("--file="))?.split("=")[1];
  if (!file) {
    console.error("Usage: FILE=xxx.wav pnpm --filter @mycat/voice-video-daemon run asr");
    process.exit(1);
  }
  if (!fs.existsSync(file)) {
    console.error("file not found", file);
    process.exit(1);
  }
  await transcribePcm(path.resolve(file), { model: process.env.WHISPER_MODEL || "base" }, (chunk) => {
    console.info(`[ASR] ${chunk.text}`);
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
