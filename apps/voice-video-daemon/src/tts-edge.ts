# Edge TTS streaming helper (networked).
# Requires internet and uses the Microsoft Edge TTS service.
# Environment:
#   EDGE_TTS_VOICE (default en-US-JennyNeural)
#   EDGE_TTS_FORMAT (default audio-16khz-32kbitrate-mono-mp3)

import { generate } from "edge-tts";

export interface EdgeTtsOptions {
  voice?: string;
  format?: string; // e.g., 'audio-16khz-32kbitrate-mono-mp3'
}

export interface TtsStreamChunk {
  audio: Uint8Array;
  isFinal: boolean;
  sampleRate?: number; // inferred best-effort
}

const DEFAULT_VOICE = process.env.EDGE_TTS_VOICE || "en-US-JennyNeural";
const DEFAULT_FORMAT = process.env.EDGE_TTS_FORMAT || "audio-16khz-32kbitrate-mono-mp3";

export async function* streamEdgeTts(text: string, opts: EdgeTtsOptions = {}): AsyncGenerator<TtsStreamChunk> {
  const voice = opts.voice || DEFAULT_VOICE;
  const format = opts.format || DEFAULT_FORMAT;
  const stream = await generate({ text, voice, format });
  const sr = inferSampleRate(format);
  for await (const chunk of stream) {
    yield { audio: new Uint8Array(chunk), isFinal: false, sampleRate: sr };
  }
  yield { audio: new Uint8Array(), isFinal: true, sampleRate: sr };
}

function inferSampleRate(format: string | undefined): number | undefined {
  if (!format) return undefined;
  const match = format.match(/(\\d+)khz/i);
  if (match) return Number(match[1]) * 1000;
  return undefined;
}
