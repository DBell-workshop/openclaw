# voice-video-daemon (macOS-first)

目的：提供低延迟音频/视频通道，负责 VAD、ASR、TTS，并通过 gRPC/WebSocket 暴露给 OpenClaw Gateway 和前端。

## 计划功能
- WebRTC/Opus 输入输出；备用纯 WS PCM 通道。
- 本地 ASR：Whisper.cpp (Metal)，可切换云端 ASR。
- TTS：macOS AVSpeechSynthesizer 默认；可插拔远端/本地合成。
- 守护进程：支持自启动、重连、健康检查。
- 安全：显式授权麦克风/摄像头；日志脱敏。

## 待办 (MVP)
- [ ] gRPC/WS 协议草案与 proto 定义
- [ ] 集成 Whisper.cpp CLI 适配层
- [ ] 流式 TTS 输出
- [ ] 健康检查与指标（延迟/丢包）

详见 `docs/specs/mvp-macos-voice-ops.md`。
