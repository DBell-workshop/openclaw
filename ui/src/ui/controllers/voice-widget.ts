import { TtsPlayback } from "./tts-playback";
import { MicRecorder } from "./mic-recorder";

const DEFAULT_URL = import.meta.env.VITE_VOICE_WS_URL || "ws://localhost:8799/voice";
const LANG_STORAGE_KEY = "mycat.voice.lang";
const URL_LANG = new URLSearchParams(window.location.search).get("lang");

type Lang = "en" | "zh";
type StatusKey =
  | "idle"
  | "connecting"
  | "ready"
  | "listening"
  | "transcribing"
  | "queued"
  | "thinking"
  | "streaming"
  | "speaking"
  | "partial"
  | "final"
  | "done"
  | "error";

type WidgetState = "idle" | "connecting" | "connected" | "listening" | "thinking" | "playing" | "error";

type Overlay = {
  setState: (s: WidgetState) => void;
  setAsr: (t: string) => void;
  setLlm: (t: string) => void;
  setAsrStatus: (t: StatusKey) => void;
  setLlmStatus: (t: StatusKey) => void;
  setLevel: (level: number) => void;
  teardown: () => void;
  setUrl: (t: string) => void;
};

export function startVoiceWidget(url: string = DEFAULT_URL) {
  const ui = createWidget();
  ui.setUrl(url);
  ui.setAsr("—");
  ui.setLlm("—");
  ui.setAsrStatus("idle");
  ui.setLlmStatus("idle");
  let ws: WebSocket | null = null;
  const mic = new MicRecorder();

  const player = new TtsPlayback({
    onStart: () => {
      ui.setState("playing");
      ui.setLlmStatus("speaking");
    },
    onEnd: () => {
      ui.setState("connected");
      ui.setLlmStatus("done");
    },
  });

  async function ensureConnection() {
    if (ws && ws.readyState === WebSocket.OPEN) return;
    ui.setState("connecting");
    ui.setAsrStatus("connecting");
    ui.setLlmStatus("connecting");
    ws = new WebSocket(url);
    ws.onopen = () => {
      ui.setState("connected");
      ui.setAsrStatus("ready");
      ui.setLlmStatus("ready");
    };
    ws.onclose = () => {
      ui.setState("idle");
      ui.setAsrStatus("idle");
      ui.setLlmStatus("idle");
    };
    ws.onerror = () => {
      ui.setState("error");
      ui.setAsrStatus("error");
      ui.setLlmStatus("error");
    };
    ws.onmessage = (ev) => {
      try {
        const msg = JSON.parse(ev.data);
        if (msg.tts) player.enqueue(msg.tts);
        if (msg.asr?.text) {
          ui.setAsr(msg.asr.text);
          ui.setState("listening");
          ui.setAsrStatus(msg.asr.is_final ? "final" : "partial");
        }
        if (msg.llm?.partial_text) {
          ui.setLlm(msg.llm.partial_text);
          ui.setState("thinking");
          ui.setLlmStatus(msg.llm.is_final ? "done" : "streaming");
        }
        if (msg.action) {
          ui.pushAction(msg.action);
        }
      } catch (err) {
        console.warn("[voice-widget] bad message", err);
      }
    };
  }

  ui.setState("idle");
  ui.onStart = async () => {
    await ensureConnection();
    await mic.start(
      ({ base64, sampleRate, end }) => {
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
        if (end) {
          ui.setState("thinking");
          ui.setAsrStatus("transcribing");
          ui.setLlmStatus("queued");
        }
      },
      (level) => ui.setLevel(level),
    );
    ui.setState("listening");
    ui.setAsrStatus("listening");
    ui.setLlmStatus("idle");
  };

  ui.onStop = async () => {
    mic.stop();
    ui.setState("connected");
    ui.setLevel(0);
    ui.setAsrStatus("idle");
    ui.setLlmStatus("idle");
  };

  return { stop: () => ui.teardown() };
}

type ActionItem = { id: string; title?: string; status?: string; risk?: string; approval?: boolean };

function createWidget(): Overlay & { onStart?: () => void; onStop?: () => void; pushAction: (a: any) => void } {
  const root = document.createElement("div");
  root.className = "voice-widget";
  root.innerHTML = `
    <div class="voice-widget__header">
      <span class="dot"></span>
      <span class="title">mycat voice</span>
      <span class="url"></span>
      <button class="lang" title="Language">EN</button>
    </div>
    <div class="voice-widget__wave">
      <span></span><span></span><span></span><span></span><span></span>
    </div>
    <div class="voice-widget__status">
      <span class="status asr" data-state="idle">ASR idle</span>
      <span class="status llm" data-state="idle">LLM idle</span>
    </div>
    <div class="voice-widget__text asr">ASR: --</div>
    <div class="voice-widget__text llm">LLM: --</div>
    <div class="voice-widget__actions-list"></div>
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
  const asrStatusEl = root.querySelector(".status.asr") as HTMLSpanElement;
  const llmStatusEl = root.querySelector(".status.llm") as HTMLSpanElement;
  const langBtn = root.querySelector(".lang") as HTMLButtonElement;
  const actionList = root.querySelector(".voice-widget__actions-list") as HTMLDivElement;
  const actions: ActionItem[] = [];
  const startBtn = root.querySelector(".start") as HTMLButtonElement;
  const stopBtn = root.querySelector(".stop") as HTMLButtonElement;
  let asrValue = "—";
  let llmValue = "—";
  let asrStatus: StatusKey = "idle";
  let llmStatus: StatusKey = "idle";
  let lang: Lang = resolveLang();

  const STRINGS: Record<Lang, Record<string, string>> = {
    en: {
      start: "Start",
      stop: "Stop",
      asrPrefix: "ASR:",
      llmPrefix: "LLM:",
      idle: "idle",
      connecting: "connecting",
      ready: "ready",
      listening: "listening",
      transcribing: "transcribing",
      queued: "queued",
      thinking: "thinking",
      streaming: "streaming",
      speaking: "speaking",
      partial: "partial",
      final: "final",
      done: "done",
      error: "error",
    },
    zh: {
      start: "开始",
      stop: "停止",
      asrPrefix: "ASR：",
      llmPrefix: "LLM：",
      idle: "空闲",
      connecting: "连接中",
      ready: "就绪",
      listening: "监听中",
      transcribing: "转写中",
      queued: "排队中",
      thinking: "思考中",
      streaming: "流式中",
      speaking: "播报中",
      partial: "部分结果",
      final: "最终结果",
      done: "完成",
      error: "错误",
    },
  };

  function resolveLang(): Lang {
    if (URL_LANG === "zh" || URL_LANG === "en") return URL_LANG;
    try {
      const saved = localStorage.getItem(LANG_STORAGE_KEY);
      if (saved === "zh" || saved === "en") return saved;
    } catch {
      // ignore storage errors
    }
    return "en";
  }

  function setLang(next: Lang) {
    lang = next;
    try {
      localStorage.setItem(LANG_STORAGE_KEY, next);
    } catch {
      // ignore storage errors
    }
    renderLabels();
  }

  function renderLabels() {
    const strings = STRINGS[lang];
    startBtn.textContent = strings.start;
    stopBtn.textContent = strings.stop;
    asrEl.textContent = `${strings.asrPrefix} ${asrValue}`;
    llmEl.textContent = `${strings.llmPrefix} ${llmValue}`;
    asrStatusEl.textContent = `ASR ${strings[asrStatus] ?? asrStatus}`;
    llmStatusEl.textContent = `LLM ${strings[llmStatus] ?? llmStatus}`;
    langBtn.textContent = lang === "en" ? "EN" : "中文";
  }

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
      asrValue = t;
      renderLabels();
    },
    setLlm: (t: string) => {
      llmValue = t;
      renderLabels();
    },
    setAsrStatus: (t: StatusKey) => {
      asrStatus = t;
      asrStatusEl.dataset.state = t;
      renderLabels();
    },
    setLlmStatus: (t: StatusKey) => {
      llmStatus = t;
      llmStatusEl.dataset.state = t;
      renderLabels();
    },
    setLevel: (level: number) => {
      const clamped = Math.max(0, Math.min(1, level));
      root.style.setProperty("--voice-level", clamped.toString());
    },
    pushAction: (a: any) => {
      actions.unshift({
        id: a.id || String(Date.now()),
        title: a.title || a.type || "action",
        status: a.status || "planned",
        risk: a.risk_level,
        approval: !!a.approval_required,
      });
      renderActions(actions, actionList);
    },
    teardown: () => root.remove(),
  };

  startBtn.onclick = () => controller.onStart?.();
  stopBtn.onclick = () => controller.onStop?.();
  langBtn.onclick = () => setLang(lang === "en" ? "zh" : "en");
  renderLabels();

  return controller;
}
function renderActions(items: ActionItem[], container: HTMLElement) {
  container.innerHTML = items
    .slice(0, 5)
    .map((a) => {
      const riskBadge = a.risk ? `<span class="badge badge--${a.risk}">${a.risk}</span>` : "";
      const approval = a.approval ? '<span class="badge badge--approval">need approval</span>' : "";
      return `<div class="action-item" data-status="${a.status}">
        <div class="title">${a.title}</div>
        <div class="meta">${a.status}${riskBadge ? " • " + riskBadge : ""}${approval ? " • " + approval : ""}</div>
      </div>`;
    })
    .join("");
}
