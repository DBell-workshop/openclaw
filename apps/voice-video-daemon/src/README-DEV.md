# 开发备忘（voice-video-daemon）

## 启动形态
- dev：`bun run src/server.ts`（当前 WS 支持 audio.base64 + end_of_utterance，落盘→whisper）。
- 提供 gRPC + WS；WS 作为前端/Electron 直连，gRPC 供 Gateway/CLI。
- Proto 生成：`pnpm --filter @mycat/voice-video-daemon run proto:fetch && pnpm --filter @mycat/voice-video-daemon run proto:gen`
  - 生成产物：`src/gen/voice.ts`
  - 下载的 `protoc` 位于 `.tools/`，已在 .gitignore；需要时可手动删除。
- ASR/TTS：`src/whisper.ts`（whisper.cpp CLI）；`src/tts-macos.ts`（macOS `say`）。TTS 开关：`MYCAT_TTS=1`；流式：`MYCAT_TTS_STREAM=1`；`MYCAT_TTS_ENGINE=mac|edge|styletts2|matcha`。
- Python TTS（StyleTTS2/Matcha）：需 python3；自动检查/安装缺失包：`MYCAT_TTS_PIP_AUTO=1`，或手动 `python3 -m pip install styletts2 matcha-tts`。可指定 `MYCAT_PYTHON`、`MYCAT_TTS_MODEL`（huggingface repo/name）。

## 集成计划
- ASR：通过 spawn Whisper.cpp（Metal），流式切片；增加重用模型缓存。
- TTS：macOS AVSpeechSynthesizer via objc bridge 或 `say` CLI（先用简版，后续换流式）。
- VAD：silero-vad wasm/node binding，前置于 ASR；标记 `end_of_utterance`。
- 健康检查：ASR/TTS 子进程心跳 + 最近延迟/丢包指标。

## 临时调试
- `scripts/demo/push-to-talk.ts`：读取 WAV/PCM，base64 发送到 WS，打印 ASR/LLM 回显。
- `scripts/demo/mic-ptt.ts`：用 sox/ffmpeg 录制 4s 麦克风音频并发送到 WS。
- `scripts/demo/loopback.ts`：回声测试（当前为占位，等待真实流接入）。
- `scripts/demo/ws-loop-client.ts`：连本地 WS，发送文本/控制并查看回显。

## 对接 orchestrator
- 在 ActionEvent 里携带 `risk_level`、`approval_required`，由上层 UI 决定审批流；此守护进程只负责透传事件。
