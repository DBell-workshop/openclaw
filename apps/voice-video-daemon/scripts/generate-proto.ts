import { spawn } from "child_process";
import { promises as fs } from "fs";
import path from "path";
import { fileURLToPath } from "url";

// Generates src/gen/voice.ts using ts-proto and a locally downloaded protoc.
// Usage: pnpm --filter @mycat/voice-video-daemon run proto:gen

const __dirname = fileURLToPath(new URL(".", import.meta.url));
const ROOT = path.resolve(__dirname, ".."); // package root
const protoDir = path.resolve(ROOT, "proto");
const outDir = path.resolve(ROOT, "src/gen");
const toolsDir = path.resolve(ROOT, ".tools/protoc");

async function run(cmd: string, args: string[]) {
  await new Promise<void>((resolve, reject) => {
    const p = spawn(cmd, args, { cwd: ROOT, stdio: "inherit" });
    p.on("exit", (code) => (code === 0 ? resolve() : reject(new Error(`${cmd} exited ${code}`))));
    p.on("error", reject);
  });
}

async function main() {
  const protocBin = process.env.PROTOC_BIN || path.join(toolsDir, "bin/protoc");
  const plugin = path.join(ROOT, "node_modules/.bin/protoc-gen-ts_proto");
  const proto = path.join(protoDir, "voice.proto");
  await fs.mkdir(outDir, { recursive: true });

  await run(protocBin, [
    `--plugin=protoc-gen-ts_proto=${plugin}`,
    `--ts_proto_out=${outDir}`,
    "--ts_proto_opt=esModuleInterop=true,forceLong=string,useOptionals=messages",
    `-I${protoDir}`,
    proto,
  ]);

  console.info("ts-proto generation done ->", path.relative(ROOT, path.join(outDir, "voice.ts")));
}

main().catch((err) => {
  console.error("proto generation failed", err);
  process.exit(1);
});
