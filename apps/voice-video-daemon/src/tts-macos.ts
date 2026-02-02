import { spawn } from "child_process";

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
