import { spawn } from "child_process";
import os from "os";
import path from "path";
import { promises as fs } from "fs";

export interface TtsOptions {
  voice?: string; // macOS voice id, e.g., "Samantha"
  rate?: number; // words per minute
}

export function speak(text: string, opts: TtsOptions = {}): Promise<void> {
  const args = [text];
  if (opts.voice) args.unshift("-v", opts.voice);
  if (opts.rate) args.unshift("-r", String(opts.rate));

  return new Promise((resolve, reject) => {
    const child = spawn("say", args, { stdio: "ignore" });
    child.on("error", reject);
    child.on("exit", (code) => (code === 0 ? resolve() : reject(new Error(`say exited ${code}`))));
  });
}

export async function synthesizeToPcmWave(
  text: string,
  opts: TtsOptions = {},
  sampleRate = 16000,
): Promise<{ pcm: Buffer; sampleRate: number }> {
  const tmp = await fs.mkdtemp(path.join(os.tmpdir(), "mycat-tts-"));
  const aiff = path.join(tmp, "out.aiff");
  const wav = path.join(tmp, "out.wav");

  const sayArgs = ["-o", aiff, text];
  if (opts.voice) sayArgs.unshift("-v", opts.voice);
  if (opts.rate) sayArgs.unshift("-r", String(opts.rate));

  await run("say", sayArgs);
  // afconvert -f WAVE -d LEI16@16000 in.aiff out.wav
  await run("afconvert", ["-f", "WAVE", "-d", `LEI16@${sampleRate}`, aiff, wav]);

  const pcm = await fs.readFile(wav);
  // cleanup best-effort
  fs.rm(tmp, { recursive: true, force: true }).catch(() => {});
  return { pcm, sampleRate };
}

async function run(bin: string, args: string[]) {
  await new Promise<void>((resolve, reject) => {
    const p = spawn(bin, args, { stdio: "ignore" });
    p.on("exit", (code) => (code === 0 ? resolve() : reject(new Error(`${bin} exited ${code}`))));
    p.on("error", reject);
  });
}
