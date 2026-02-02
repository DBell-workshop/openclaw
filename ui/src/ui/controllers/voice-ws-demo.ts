import { TtsPlayback } from "./tts-playback";

// Simple optional voice WS consumer for demo/prototyping.
// Enabled when VITE_ENABLE_VOICE_DEMO="true" (see src/main.ts).
// Connects to ws://localhost:8799/voice by default (override VITE_VOICE_WS_URL).

const DEFAULT_URL = import.meta.env.VITE_VOICE_WS_URL || "ws://localhost:8799/voice";

export function startVoiceWsDemo(url: string = DEFAULT_URL) {
  const ws = new WebSocket(url);
  const player = new TtsPlayback();
  const ui = createOverlay();

  ws.onopen = () => {
    ui.setStatus("connected");
    console.info("[voice-demo] connected", url);
  };
  ws.onclose = () => {
    ui.setStatus("closed");
    console.info("[voice-demo] closed");
  };
  ws.onerror = (e) => {
    ui.setStatus("error");
    console.warn("[voice-demo] error", e);
  };
  ws.onmessage = (ev) => {
    try {
      const msg = JSON.parse(ev.data);
      if (msg.tts) player.enqueue(msg.tts);
      if (msg.asr?.text) {
        ui.setAsr(msg.asr.text);
        console.info("[voice-demo][asr]", msg.asr.text);
      }
      if (msg.llm?.partial_text) {
        ui.setLlm(msg.llm.partial_text);
        console.info("[voice-demo][llm]", msg.llm.partial_text);
      }
    } catch (err) {
      console.warn("[voice-demo] bad message", err);
    }
  };
  return ws;
}

type Overlay = {
  setStatus: (s: "connecting" | "connected" | "closed" | "error") => void;
  setAsr: (t: string) => void;
  setLlm: (t: string) => void;
};

function createOverlay(): Overlay {
  const root = document.createElement("div");
  root.className = "voice-demo";
  root.innerHTML = `
    <div class="voice-demo__status">connecting...</div>
    <div class="voice-demo__asr"></div>
    <div class="voice-demo__llm"></div>
  `;
  document.body.appendChild(root);
  const statusEl = root.querySelector(".voice-demo__status") as HTMLDivElement;
  const asrEl = root.querySelector(".voice-demo__asr") as HTMLDivElement;
  const llmEl = root.querySelector(".voice-demo__llm") as HTMLDivElement;

  return {
    setStatus: (s) => {
      statusEl.textContent = s;
      root.dataset.state = s;
    },
    setAsr: (t) => {
      asrEl.textContent = `ASR: ${t}`;
      root.dataset.state = "asr";
    },
    setLlm: (t) => {
      llmEl.textContent = `LLM: ${t}`;
      root.dataset.state = "llm";
    },
  };
}
