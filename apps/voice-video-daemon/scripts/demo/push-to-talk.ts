// Push-to-talk demo placeholder.
// Goal: record short PCM/Opus clip, send via WS/gRPC, and print ASR text.
// Implementation will follow once audio pipeline is wired.

async function main() {
  console.info("[demo] push-to-talk placeholder; audio pipeline not yet connected.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
