import { TtsPlayback } from "./tts-playback";
import { MicRecorder } from "./mic-recorder";

const DEFAULT_URL = import.meta.env.VITE_VOICE_WS_URL || "ws://localhost:8799/voice";

type WidgetState = "idle" | "connecting" | "connected" | "listening" | "thinking" | "playing" | "error";

type Overlay = {
  setState: (s: WidgetState) => void;
  setAsr: (t: string) => void;
  setLlm: (t: string) => void;
  teardown: () => void;
  setUrl: (t: string) => void;
};

export function startVoiceWidget(url: string = DEFAULT_URL) {
  const ui = createWidget();
  ui.setUrl(url);
  let ws: WebSocket | null = null;
  const mic = new MicRecorder();

  const player = new TtsPlayback({
    onStart: () => ui.setState("playing"),
    onEnd: () => ui.setState("connected"),
  });

  async function ensureConnection() {
    if (ws && ws.readyState === WebSocket.OPEN) return;
    ui.setState("connecting");
    ws = new WebSocket(url);
    ws.onopen = () => ui.setState("connected");
    ws.onclose = () => ui.setState("idle");
    ws.onerror = () => ui.setState("error");
    ws.onmessage = (ev) => {
      try {
        const msg = JSON.parse(ev.data);
        if (msg.tts) player.enqueue(msg.tts);
        if (msg.asr?.text) {
          ui.setAsr(msg.asr.text);
          ui.setState("listening");
        }
        if (msg.llm?.partial_text) {
          ui.setLlm(msg.llm.partial_text);
          ui.setState("thinking");
        }
      } catch (err) {
        console.warn("[voice-widget] bad message", err);
      }
    };
  }

  ui.setState("idle");
  ui.onStart = async () => {
    await ensureConnection();
    await mic.start(({ base64, sampleRate, end }) => {
      if (!ws || ws.readyState !== WebSocket.OPEN) return;
      ws.send(
        JSON.stringify({
          audio: {
            data: base64,
            sample_rate: sampleRate,
            is_opus: true,
            end_of_utterance: end,
          },
        }),
      );
      if (end) ui.setState("thinking");
    });
    ui.setState("listening");
  };

  ui.onStop = async () => {
    mic.stop();
    ui.setState("connected");
  };

  return { stop: () => ui.teardown() };
}

function createWidget(): Overlay & { onStart?: () => void; onStop?: () => void } {
  const root = document.createElement("div");
  root.className = "voice-widget";
  root.innerHTML = `
    <div class="voice-widget__header">
      <span class="dot"></span>
      <span class="title">mycat voice</span>
      <span class="url"></span>
    </div>
    <div class="voice-widget__wave">
      <span></span><span></span><span></span><span></span><span></span>
    </div>
    <div class="voice-widget__text asr">ASR: --</div>
    <div class="voice-widget__text llm">LLM: --</div>
    <div class="voice-widget__actions">
      <button class="start">Start</button>
      <button class="stop" disabled>Stop</button>
    </div>
  `;
  document.body.appendChild(root);
  const dot = root.querySelector(".dot") as HTMLSpanElement;
  const urlEl = root.querySelector(".url") as HTMLSpanElement;
  const asrEl = root.querySelector(".asr") as HTMLDivElement;
  const llmEl = root.querySelector(".llm") as HTMLDivElement;
  const startBtn = root.querySelector(".start") as HTMLButtonElement;
  const stopBtn = root.querySelector(".stop") as HTMLButtonElement;

  const controller = {
    onStart: undefined as (() => void) | undefined,
    onStop: undefined as (() => void) | undefined,
    setUrl: (t: string) => {
      urlEl.textContent = t.replace(/^ws:\/\//, "");
    },
    setState: (s: WidgetState) => {
      root.dataset.state = s;
      dot.dataset.state = s;
      if (s === "idle" || s === "error") {
        startBtn.disabled = false;
        stopBtn.disabled = true;
      } else {
        startBtn.disabled = true;
        stopBtn.disabled = false;
      }
    },
    setAsr: (t: string) => {
      asrEl.textContent = `ASR: ${t}`;
    },
    setLlm: (t: string) => {
      llmEl.textContent = `LLM: ${t}`;
    },
    teardown: () => root.remove(),
  };

  startBtn.onclick = () => controller.onStart?.();
  stopBtn.onclick = () => controller.onStop?.();

  return controller;
}
