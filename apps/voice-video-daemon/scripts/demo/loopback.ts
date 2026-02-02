// Loopback demo: simulates client/server roundtrip to measure base latency.
// TODO: wire to the real gRPC/WS stream once implemented.

async function main() {
  const start = Date.now();
  // Placeholder: in real impl, send an AudioChunk and await echo.
  await new Promise((res) => setTimeout(res, 50));
  const rtt = Date.now() - start;
  console.info(`[demo] loopback simulated RTT: ${rtt} ms (placeholder)`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
