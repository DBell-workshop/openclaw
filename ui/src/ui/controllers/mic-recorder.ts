// Minimal microphone recorder that captures mono PCM16 at target sample rate (default 16k).
// Uses ScriptProcessorNode; suitable for prototyping. Not for production latency-critical use.

const TARGET_SR = 16000;

export class MicRecorder {
  private ctx: AudioContext | null = null;
  private processor: ScriptProcessorNode | null = null;
  private stream: MediaStream | null = null;
  private samples: Float32Array[] = [];
  private recording = false;

  async start() {
    if (this.recording) return;
    this.stream = await navigator.mediaDevices.getUserMedia({ audio: true, video: false });
    this.ctx = new AudioContext({ sampleRate: 48000 });
    const src = this.ctx.createMediaStreamSource(this.stream);
    this.processor = this.ctx.createScriptProcessor(4096, 1, 1);
    src.connect(this.processor);
    this.processor.connect(this.ctx.destination);
    this.processor.onaudioprocess = (e) => {
      if (!this.recording) return;
      const input = e.inputBuffer.getChannelData(0);
      this.samples.push(new Float32Array(input));
    };
    this.samples = [];
    this.recording = true;
  }

  async stop(): Promise<{ pcm: ArrayBuffer; sampleRate: number }> {
    this.recording = false;
    this.processor?.disconnect();
    this.stream?.getTracks().forEach((t) => t.stop());
    await this.ctx?.close();

    const concatenated = concatFloat32(this.samples);
    const down = downsample(concatenated, this.ctx?.sampleRate ?? TARGET_SR, TARGET_SR);
    const pcm = floatTo16le(down);
    return { pcm, sampleRate: TARGET_SR };
  }
}

function concatFloat32(chunks: Float32Array[]): Float32Array {
  const len = chunks.reduce((s, c) => s + c.length, 0);
  const out = new Float32Array(len);
  let offset = 0;
  for (const c of chunks) {
    out.set(c, offset);
    offset += c.length;
  }
  return out;
}

function downsample(data: Float32Array, fromSr: number, toSr: number): Float32Array {
  if (fromSr === toSr) return data;
  const ratio = fromSr / toSr;
  const outLen = Math.floor(data.length / ratio);
  const out = new Float32Array(outLen);
  for (let i = 0; i < outLen; i++) {
    const idx = Math.floor(i * ratio);
    out[i] = data[idx];
  }
  return out;
}

function floatTo16le(data: Float32Array): ArrayBuffer {
  const out = new Int16Array(data.length);
  for (let i = 0; i < data.length; i++) {
    const v = Math.max(-1, Math.min(1, data[i]));
    out[i] = v < 0 ? v * 0x8000 : v * 0x7fff;
  }
  return out.buffer;
}
