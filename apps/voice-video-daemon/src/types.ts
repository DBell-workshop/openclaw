// Lightweight TypeScript representations of voice.proto for early wiring.
// Proto reference: apps/voice-video-daemon/proto/voice.proto

export type SessionId = string;

export type ClientMessage =
  | { audio: AudioChunk; control?: undefined }
  | { control: Control; audio?: undefined };

export interface AudioChunk {
  data: Uint8Array; // PCM16LE or Opus
  sample_rate: number;
  is_opus: boolean;
  end_of_utterance?: boolean;
}

export interface Control {
  session_id?: string;
  push_to_talk?: boolean;
  stop?: boolean;
}

export interface ServerMessage {
  session_id: SessionId;
  asr?: AsrResult;
  llm?: LlmUpdate;
  action?: ActionEvent;
  tts?: TtsChunk;
  health?: Health;
}

export interface AsrResult {
  text: string;
  is_final: boolean;
  latency_ms?: number;
}

export interface LlmUpdate {
  partial_text: string;
  is_final?: boolean;
}

export interface ActionEvent {
  id: string;
  type: "browser" | "desktop" | "approval";
  title?: string;
  detail?: string;
  risk_level?: "low" | "medium" | "high";
  approval_required?: boolean;
  status?: "planned" | "approved" | "rejected" | "running" | "done" | "error";
}

export interface TtsChunk {
  audio: Uint8Array;
  audio_base64?: string;
  is_opus?: boolean;
  is_final?: boolean;
  sample_rate?: number;
  codec?: string;
}

export interface Health {
  state: "ready" | "degraded" | "error";
  message?: string;
}
