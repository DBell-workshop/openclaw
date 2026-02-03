// Streaming microphone recorder using MediaRecorder for low-latency chunks.
// Emits base64 audio/webm(opus) chunks every CHUNK_MS; caller sends to WS.

const TARGET_SR = 16000;
const CHUNK_MS = 200;

export type MicChunkListener = (payload: { base64: string; sampleRate: number; end: boolean }) => void;
export type MicLevelListener = (level: number) => void;

export class MicRecorder {
  private stream: MediaStream | null = null;
  private mediaRecorder: MediaRecorder | null = null;
  private listener: MicChunkListener | null = null;
  private levelListener: MicLevelListener | null = null;
  private ctx: AudioContext | null = null;
  private analyser: AnalyserNode | null = null;
  private rafId: number | null = null;

  async start(listener: MicChunkListener, levelListener?: MicLevelListener) {
    if (this.mediaRecorder) return;
    this.listener = listener;
    this.levelListener = levelListener ?? null;
    this.stream = await navigator.mediaDevices.getUserMedia({ audio: { sampleRate: TARGET_SR, channelCount: 1 }, video: false });
    this.mediaRecorder = new MediaRecorder(this.stream, { mimeType: "audio/webm;codecs=opus", audioBitsPerSecond: 32000 });
    this.mediaRecorder.ondataavailable = (e) => this.handleChunk(e.data, false);
    this.mediaRecorder.onstop = () => this.handleChunk(undefined, true);
    this.mediaRecorder.start(CHUNK_MS);
    this.startLevelMeter();
  }

  stop() {
    if (!this.mediaRecorder) return;
    this.mediaRecorder.stop();
    this.stream?.getTracks().forEach((t) => t.stop());
    this.mediaRecorder = null;
    this.stream = null;
    this.stopLevelMeter();
  }

  private async handleChunk(data: Blob | undefined, end: boolean) {
    if (!this.listener) return;
    if (data && data.size > 0) {
      const buffer = await data.arrayBuffer();
      const base64 = arrayBufferToBase64(buffer);
      this.listener({ base64, sampleRate: TARGET_SR, end: false });
    }
    if (end) this.listener({ base64: "", sampleRate: TARGET_SR, end: true });
  }

  private startLevelMeter() {
    if (!this.stream || !this.levelListener) return;
    this.ctx = new AudioContext();
    const source = this.ctx.createMediaStreamSource(this.stream);
    this.analyser = this.ctx.createAnalyser();
    this.analyser.fftSize = 1024;
    source.connect(this.analyser);
    const buffer = new Float32Array(this.analyser.fftSize);
    const tick = () => {
      if (!this.analyser) return;
      this.analyser.getFloatTimeDomainData(buffer);
      let sum = 0;
      for (let i = 0; i < buffer.length; i++) sum += buffer[i] * buffer[i];
      const rms = Math.sqrt(sum / buffer.length);
      const level = Math.min(1, rms * 3.5);
      this.levelListener?.(level);
      this.rafId = requestAnimationFrame(tick);
    };
    tick();
  }

  private stopLevelMeter() {
    if (this.rafId != null) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
    this.analyser?.disconnect();
    this.analyser = null;
    this.ctx?.close();
    this.ctx = null;
  }
}

function arrayBufferToBase64(ab: ArrayBuffer): string {
  const bytes = new Uint8Array(ab);
  let bin = "";
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}
