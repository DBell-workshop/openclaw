// Simple WS client to test loopback server.
// Run server: `bun run src/server.ts`
// Run client: `bun run scripts/demo/ws-loop-client.ts`

import WebSocket from "ws";

const url = process.env.MYCAT_VOICE_URL ?? "ws://localhost:8799/voice";

const ws = new WebSocket(url);

ws.on("open", () => {
  console.info(`[demo] connected to ${url}`);
  ws.send(JSON.stringify({ control: { session_id: "demo" } }));
  ws.send(JSON.stringify({ text: "hello mycat" }));
  setTimeout(() => ws.send(JSON.stringify({ control: { stop: true } })), 500);
});

ws.on("message", (data) => {
  console.info("[demo] recv:", data.toString());
});

ws.on("close", () => {
  console.info("[demo] closed");
});

ws.on("error", (err) => {
  console.error("[demo] error", err);
});
