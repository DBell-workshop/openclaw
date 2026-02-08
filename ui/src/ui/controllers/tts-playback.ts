/**
 * Lightweight TTS playback helper for WS `tts` messages from voice-video-daemon.
 *
 * Usage:
 *   const player = new TtsPlayback();
 *   ws.onmessage = (ev) => {
 *     const msg = JSON.parse(ev.data);
 *     if (msg.tts) player.enqueue(msg.tts);
 *   };
 */

type TtsMessage = {
  audio_base64?: string;
  audio?: number[] | Uint8Array;
  is_final?: boolean;
  sample_rate?: number;
  codec?: string; // e.g., "mp3"
};

type PlaybackEvents = {
  onStart?: () => void;
  onEnd?: () => void;
};

export class TtsPlayback {
  private ctx = new AudioContext();
  private queue: ArrayBuffer[] = [];
  private playing = false;
  private events: PlaybackEvents;

  constructor(events: PlaybackEvents = {}) {
    this.events = events;
  }

  enqueue(tts: TtsMessage) {
    const buf = this.toArrayBuffer(tts);
    if (buf) {
      this.queue.push(buf);
      if (!this.playing) void this.flush();
    }
  }

  private toArrayBuffer(tts: TtsMessage): ArrayBuffer | null {
    if (tts.audio_base64) {
      return Uint8Array.from(atob(tts.audio_base64), (c) => c.charCodeAt(0)).buffer;
    }
    if (tts.audio instanceof Uint8Array) return new Uint8Array(tts.audio).buffer;
    if (Array.isArray(tts.audio)) return new Uint8Array(tts.audio).buffer;
    return null;
  }

  private async flush() {
    this.playing = true;
    this.events.onStart?.();
    while (this.queue.length > 0) {
      const data = this.queue.shift()!;
      if (data.byteLength === 0) continue;
      try {
        const buffer =
          // If codec hints mp3, let decodeAudioData parse it; else treat as PCM16 mono.
          (await this.tryDecode(data)) ?? this.pcmToAudioBuffer(data, /*sampleRate*/ 16000);
        const src = this.ctx.createBufferSource();
        src.buffer = buffer;
        src.connect(this.ctx.destination);
        src.start();
        await this.waitBuffer(buffer);
      } catch (err) {
        console.error("TTS playback error", err);
      }
    }
    this.playing = false;
    this.events.onEnd?.();
  }

  private tryDecode(data: ArrayBuffer): Promise<AudioBuffer | null> {
    return new Promise((resolve) => {
      this.ctx.decodeAudioData(
        data.slice(0),
        (buf) => resolve(buf),
        () => resolve(null),
      );
    });
  }

  private pcmToAudioBuffer(data: ArrayBuffer, sampleRate: number) {
    const int16 = new Int16Array(data);
    const audioBuf = this.ctx.createBuffer(1, int16.length, sampleRate);
    const chan = audioBuf.getChannelData(0);
    for (let i = 0; i < int16.length; i++) {
      chan[i] = int16[i] / 0x7fff;
    }
    return audioBuf;
  }

  private waitBuffer(buffer: AudioBuffer): Promise<void> {
    const seconds = buffer.length / buffer.sampleRate;
    return new Promise((res) => setTimeout(res, seconds * 1000));
  }
}
