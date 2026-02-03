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
  addLog: (t: string, level?: "info" | "warn" | "error") => void;
  setError: (t: string | null) => void;
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
  ui.addLog("widget initialized");
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
    ui.addLog("connecting to voice server");
    ws = new WebSocket(url);
    ws.onopen = () => {
      ui.setState("connected");
      ui.setAsrStatus("ready");
      ui.setLlmStatus("ready");
      ui.addLog("connected");
    };
    ws.onclose = () => {
      ui.setState("idle");
      ui.setAsrStatus("idle");
      ui.setLlmStatus("idle");
      ui.addLog("disconnected", "warn");
    };
    ws.onerror = () => {
      ui.setState("error");
      ui.setAsrStatus("error");
      ui.setLlmStatus("error");
      ui.addLog("connection error", "error");
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
        if (msg.health) {
          const state = msg.health.state || "ready";
          const message = msg.health.message ? `: ${msg.health.message}` : "";
          ui.addLog(`health ${state}${message}`, state === "error" ? "error" : "info");
          if (state === "error") {
            ui.setError(msg.health.message || "voice server error");
          } else if (state === "ready") {
            ui.setError(null);
          }
        }
      } catch (err) {
        console.warn("[voice-widget] bad message", err);
        ui.addLog("bad message", "warn");
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
          ui.addLog("end of utterance");
        }
      },
      (level) => ui.setLevel(level),
    );
    ui.setState("listening");
    ui.setAsrStatus("listening");
    ui.setLlmStatus("idle");
    ui.addLog("mic started");
  };

  ui.onStop = async () => {
    mic.stop();
    ui.setState("connected");
    ui.setLevel(0);
    ui.setAsrStatus("idle");
    ui.setLlmStatus("idle");
    ui.addLog("mic stopped");
  };

  ui.onApproval = (id, decision) => {
    if (!ws || ws.readyState !== WebSocket.OPEN) return;
    ws.send(JSON.stringify({ approval: { id, decision } }));
    ui.addLog(`approval sent (${decision})`);
  };

  return { stop: () => ui.teardown() };
}

type ActionItem = { id: string; title?: string; status?: string; risk?: string; approval?: boolean };

function createWidget(): Overlay & {
  onStart?: () => void;
  onStop?: () => void;
  onApproval?: (id: string, decision: "allow-once" | "deny") => void;
  pushAction: (a: any) => void;
} {
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
    <div class="voice-widget__log">
      <div class="log-header">
        <span class="label">Logs</span>
        <button class="clear">Clear</button>
      </div>
      <div class="log-error"></div>
      <div class="log-lines"></div>
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
  const logLabelEl = root.querySelector(".log-header .label") as HTMLSpanElement;
  const logClearBtn = root.querySelector(".log-header .clear") as HTMLButtonElement;
  const logErrorEl = root.querySelector(".log-error") as HTMLDivElement;
  const logLinesEl = root.querySelector(".log-lines") as HTMLDivElement;
  const langBtn = root.querySelector(".lang") as HTMLButtonElement;
  const actionList = root.querySelector(".voice-widget__actions-list") as HTMLDivElement;
  const actions: ActionItem[] = [];
  const startBtn = root.querySelector(".start") as HTMLButtonElement;
  const stopBtn = root.querySelector(".stop") as HTMLButtonElement;
  const logs: Array<{ ts: number; text: string; level: "info" | "warn" | "error" }> = [];
  let errorText: string | null = null;
  let asrValue = "—";
  let llmValue = "—";
  let asrStatus: StatusKey = "idle";
  let llmStatus: StatusKey = "idle";
  let lang: Lang = resolveLang();

  const STRINGS: Record<Lang, Record<string, string>> = {
    en: {
      start: "Start",
      stop: "Stop",
      approve: "Approve",
      reject: "Reject",
      needApproval: "need approval",
      logs: "Logs",
      clear: "Clear",
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
      planned: "planned",
      running: "running",
      approved: "approved",
      rejected: "rejected",
      error: "error",
    },
    zh: {
      start: "开始",
      stop: "停止",
      approve: "同意",
      reject: "拒绝",
      needApproval: "需要审批",
      logs: "日志",
      clear: "清空",
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
      planned: "待审批",
      running: "执行中",
      approved: "已批准",
      rejected: "已拒绝",
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
    logLabelEl.textContent = strings.logs;
    logClearBtn.textContent = strings.clear;
    renderActions(actions, actionList, strings);
    renderLogs(strings);
  }

  function renderLogs(strings: Record<string, string>) {
    logErrorEl.textContent = errorText ? `${strings.error}: ${errorText}` : "";
    logErrorEl.style.display = errorText ? "block" : "none";
    logLinesEl.innerHTML = logs
      .slice(-6)
      .map((entry) => {
        const time = new Date(entry.ts).toLocaleTimeString();
        return `<div class="log-line log-${entry.level}">[${time}] ${entry.text}</div>`;
      })
      .join("");
  }

  const controller = {
    onStart: undefined as (() => void) | undefined,
    onStop: undefined as (() => void) | undefined,
    onApproval: undefined as ((id: string, decision: "allow-once" | "deny") => void) | undefined,
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
    addLog: (t: string, level: "info" | "warn" | "error" = "info") => {
      logs.push({ ts: Date.now(), text: t, level });
      renderLogs(STRINGS[lang]);
    },
    setError: (t: string | null) => {
      errorText = t;
      renderLogs(STRINGS[lang]);
    },
    pushAction: (a: any) => {
      const id = a.id || String(Date.now());
      const next = {
        id,
        title: a.title || a.type || "action",
        status: a.status || "planned",
        risk: a.risk_level,
        approval: !!a.approval_required,
      };
      const existing = actions.find((item) => item.id === id);
      if (existing) {
        Object.assign(existing, next);
      } else {
        actions.unshift(next);
      }
      renderActions(actions, actionList, STRINGS[lang]);
    },
    teardown: () => root.remove(),
  };

  startBtn.onclick = () => controller.onStart?.();
  stopBtn.onclick = () => controller.onStop?.();
  langBtn.onclick = () => setLang(lang === "en" ? "zh" : "en");
  logClearBtn.onclick = () => {
    logs.splice(0, logs.length);
    errorText = null;
    renderLogs(STRINGS[lang]);
  };
  actionList.addEventListener("click", (event) => {
    const target = event.target as HTMLElement | null;
    const button = target?.closest("button[data-action]") as HTMLButtonElement | null;
    if (!button) return;
    const action = button.dataset.action;
    const item = button.closest(".action-item") as HTMLElement | null;
    const id = item?.dataset.id;
    if (!id || (action !== "approve" && action !== "deny")) return;
    const entry = actions.find((row) => row.id === id);
    if (entry) {
      entry.status = action === "approve" ? "approved" : "rejected";
      renderActions(actions, actionList, STRINGS[lang]);
    }
    controller.onApproval?.(id, action === "approve" ? "allow-once" : "deny");
  });
  const externalLogHandler = (event: Event) => {
    const detail = (event as CustomEvent).detail as
      | { text?: string; level?: "info" | "warn" | "error"; error?: string | null }
      | undefined;
    if (!detail) return;
    if (detail.text) {
      controller.addLog(detail.text, detail.level ?? "info");
    }
    if ("error" in detail) {
      controller.setError(detail.error ?? null);
    }
  };
  window.addEventListener("mycat-voice-log", externalLogHandler);
  controller.teardown = () => {
    window.removeEventListener("mycat-voice-log", externalLogHandler);
    root.remove();
  };
  renderLabels();

  return controller;
}
function renderActions(items: ActionItem[], container: HTMLElement, strings: Record<string, string>) {
  container.innerHTML = items
    .slice(0, 5)
    .map((a) => {
      const riskBadge = a.risk ? `<span class="badge badge--${a.risk}">${a.risk}</span>` : "";
      const approval = a.approval ? `<span class="badge badge--approval">${strings.needApproval}</span>` : "";
      const needsDecision =
        a.approval && !["approved", "rejected", "done", "error"].includes(a.status || "");
      const controls = needsDecision
        ? `<div class="action-controls">
            <button data-action="approve">${strings.approve}</button>
            <button data-action="deny">${strings.reject}</button>
          </div>`
        : "";
      const statusLabel = strings[a.status || ""] ?? a.status ?? "";
      return `<div class="action-item" data-status="${a.status}" data-id="${a.id}">
        <div class="title">${a.title}</div>
        <div class="meta">${statusLabel}${riskBadge ? " • " + riskBadge : ""}${approval ? " • " + approval : ""}</div>
        ${controls}
      </div>`;
    })
    .join("");
}
