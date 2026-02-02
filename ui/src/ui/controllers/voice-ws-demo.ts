import { TtsPlayback } from "./tts-playback";

// Simple optional voice WS consumer for demo/prototyping.
// Enabled when VITE_ENABLE_VOICE_DEMO="true" (see src/main.ts).
// Connects to ws://localhost:8799/voice by default (override VITE_VOICE_WS_URL).

const DEFAULT_URL = import.meta.env.VITE_VOICE_WS_URL || "ws://localhost:8799/voice";

export function startVoiceWsDemo(url: string = DEFAULT_URL) {
  const ws = new WebSocket(url);
  const player = new TtsPlayback();
  ws.onopen = () => console.info("[voice-demo] connected", url);
  ws.onclose = () => console.info("[voice-demo] closed");
  ws.onerror = (e) => console.warn("[voice-demo] error", e);
  ws.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      if (msg.tts) player.enqueue(msg.tts);
      if (msg.asr?.text) console.info("[voice-demo][asr]", msg.asr.text);
      if (msg.llm?.partial_text) console.info("[voice-demo][llm]", msg.llm.partial_text);
    } catch (err) {
      console.warn("[voice-demo] bad message", err);
    }
  };
  return ws;
}
