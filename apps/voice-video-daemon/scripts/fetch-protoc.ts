import { createWriteStream, promises as fs } from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { pipeline } from "stream/promises";
import os from "os";
import https from "https";
import { spawn } from "child_process";

const version = process.env.PROTOC_VERSION || "25.1";
const platform = os.platform();
const arch = os.arch();

function resolveArtifact(): { url: string; bin: string } {
  if (platform === "darwin" && arch === "arm64") {
    return {
      url: `https://github.com/protocolbuffers/protobuf/releases/download/v${version}/protoc-${version}-osx-aarch_64.zip`,
      bin: "bin/protoc",
    };
  }
  if (platform === "darwin" && arch === "x64") {
    return {
      url: `https://github.com/protocolbuffers/protobuf/releases/download/v${version}/protoc-${version}-osx-x86_64.zip`,
      bin: "bin/protoc",
    };
  }
  throw new Error(`Unsupported platform ${platform}/${arch} (add a case).`);
}

async function download(url: string, dest: string, redirects = 3) {
  await fs.mkdir(path.dirname(dest), { recursive: true });
  return new Promise<void>((resolve, reject) => {
    const handler = (currentUrl: string, remaining: number) => {
      https
        .get(currentUrl, (res) => {
          if (res.statusCode && res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
            if (remaining <= 0) return reject(new Error("Too many redirects"));
            handler(res.headers.location, remaining - 1);
            return;
          }
          if (res.statusCode && res.statusCode >= 400) {
            reject(new Error(`HTTP ${res.statusCode} for ${currentUrl}`));
            return;
          }
          const file = createWriteStream(dest);
          res.pipe(file);
          file.on("finish", () => file.close(() => resolve()));
        })
        .on("error", reject);
    };
    handler(url, redirects);
  });
}

async function extractZip(zipPath: string, outDir: string) {
  await fs.mkdir(outDir, { recursive: true });
  await new Promise<void>((resolve, reject) => {
    const p = spawn("unzip", ["-o", zipPath, "-d", outDir], { stdio: "inherit" });
    p.on("exit", (code) => (code === 0 ? resolve() : reject(new Error(`unzip exited ${code}`))));
    p.on("error", reject);
  });
}

async function main() {
  const { url, bin } = resolveArtifact();
  const __dirname = fileURLToPath(new URL(".", import.meta.url));
  const toolsDir = path.resolve(__dirname, "../.tools");
  const zipPath = path.join(toolsDir, "protoc.zip");
  const out = path.join(toolsDir, "protoc");
  await download(url, zipPath);
  await extractZip(zipPath, out);
  const binPath = path.join(out, bin);
  await fs.chmod(binPath, 0o755);
  console.info(binPath);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
