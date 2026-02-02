import { spawn } from "child_process";
import path from "path";
import { promises as fs } from "fs";

export type WhisperModel = "tiny" | "base" | "small" | "medium" | "large" | string;

export interface WhisperOptions {
  model: WhisperModel;
  binaryPath?: string; // optional override for whisper.cpp binary
  modelDir?: string; // optional dir to cache models
  language?: string;
  translate?: boolean;
}

export interface WhisperChunk {
  text: string;
  start: number;
  end: number;
  isFinal: boolean;
}

export async function transcribePcm(
  pcmFile: string,
  opts: WhisperOptions,
  onChunk: (chunk: WhisperChunk) => void,
): Promise<void> {
  const whisperBin = opts.binaryPath ?? "whisper";
  const args = ["--output-json", "--print-progress", "--no-timestamps", "--model", opts.model, pcmFile];
  if (opts.language) args.push("--language", opts.language);
  if (opts.translate) args.push("--translate");
  if (opts.modelDir) args.push("--model-dir", opts.modelDir);

  await fs.access(pcmFile);

  const child = spawn(whisperBin, args, { stdio: ["ignore", "pipe", "pipe"] });

  child.stdout.on("data", (buf) => {
    const text = buf.toString();
    // whisper.cpp json lines contain segments; here we treat each line as a chunk for now.
    for (const line of text.split(/\n+/).filter(Boolean)) {
      try {
        const obj = JSON.parse(line);
        if (Array.isArray(obj) && obj.length > 0) {
          for (const seg of obj) {
            onChunk({ text: seg.text?.trim?.() ?? "", start: seg.t0 ?? 0, end: seg.t1 ?? 0, isFinal: true });
          }
        }
      } catch {
        // ignore non-JSON lines
      }
    }
  });

  const stderr: Buffer[] = [];
  child.stderr.on("data", (d) => stderr.push(Buffer.from(d)));

  await new Promise<void>((resolve, reject) => {
    child.on("error", reject);
    child.on("exit", (code) => {
      if (code === 0) return resolve();
      reject(new Error(`whisper exited ${code}: ${Buffer.concat(stderr).toString()}`));
    });
  });
}
