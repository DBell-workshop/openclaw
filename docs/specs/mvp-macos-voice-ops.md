# macOS 优先语音/视频 AI 助理 MVP 规格（Draft）

## 目标与成功定义
- 交付一个在 macOS 上运行的持续语音会话体验：用户按住说话/唤醒词 → 本地 ASR → LLM → TTS 语音回复，端到端中位延迟 < 5s。
- 支持最小可用的电脑/网页代操作：打开页面、搜索、填表/发送草稿（需审批）、动作可视化。
- 模型/路由可视化：本地 GGUF + 云端模型切换，展示最近调用延迟与成本估计。

## 范围（MVP）
- 平台：macOS 优先；不阻塞跨平台扩展。
- 交互：按住说话模式（第 2 迭代加入唤醒词）；字幕/指令时间线。
- 工具：Playwright 浏览器控制；AppleScript/快捷键封装的桌面操作；危险动作需审批。
- 音频链路：WebRTC/Opus → VAD（silero-vad）→ Whisper.cpp (Metal) → LLM → TTS (macOS AVSpeechSynthesizer)。
- 日志/审计：本地 SQLite + 文件日志；记录时间戳、操作者、模型、工具输入输出（脱敏）。

## 非目标（本期不做）
- iOS/Android 客户端、跨设备同步。
- 远程协同多人会话/路由。
- 模型训练/微调；只做推理与路由。
- 深度文件系统操作（删除/移动大量文件）；仅演示级别示例并需审批。

## 关键用例（验收以这些为准）
1) **网页搜索并朗读**：用户口述“打开 apple.com 搜索 macOS Sonoma 新特性”，系统自动浏览并语音总结结果，动作时间线可回看。
2) **邮件草稿**：口述“给产品组写一封更新邮件……”→ 浏览器 Gmail 填写主题/正文，不自动发送；需审批按钮确认；拒绝则无副作用。
3) **模型切换**：在模型面板从“Whisper.cpp + GPT-4o”切换到“Whisper.cpp + Claude”，UI 展示最近 10 次延迟与预估成本。
4) **高危拦截**：口述“删除下载文件夹”被标记高危，弹审批并默认拒绝；日志记录。

## 度量与预算
- 语音交互延迟：p50 < 5s，p95 < 9s（按住说话→播报）。
- 成功率：用例 1/2 成功率 ≥ 90%（人工验收 20 次样本）。
- 误触发/误执行：高危动作未经审批执行率为 0；误拦截率可接受 <10%。
- 成本：云端模型每次调用成本在 UI 可见；本地模型优先。

## 技术方案概览
- **音频/视频守护进程** (`apps/voice-video-daemon`)：WebRTC + VAD + Whisper.cpp 适配层 + TTS；暴露 gRPC/WebSocket 给 Gateway。
- **意图到动作**：LLM 解析 → Lobster 流程（节点含 Playwright/AppleScript 执行）→ 审批节点 → 执行。
- **前端控制台**：Electron/menubar + Next.js；模块：通话控制、字幕/动作时间线、模型卡片、审批列表、日志查看。
- **权限与安全**：工具权限声明（只读/网络/文件/输入设备）；高危标签 + 审批；日志脱敏。

## 接口与契约（MVP 粗版）
- `POST /voice/session`：开启会话，返回 WebRTC SDP/WS 地址。
- `WS /voice/stream`：客户端推送 PCM/Opus，服务端流式返回 ASR 文本、LLM 草稿、TTS 音频块、动作事件。
- 动作节点 schema（Lobster）：`{id, type(browser|desktop), inputs, estimated_risk, approval_required, status}`。
- 审批 API：`POST /actions/:id/approve|reject`；默认高危需审批。

## 风险与缓解
- 延迟过高：本地 ASR/TTS 优先，LLM 走最近可用路由；并行转录与规划；缓存常用指令。
- 误操作：强制审批、高危黑名单、可撤销（跳过执行）。
- 稳定性：音频链路掉线时自动重连并提示；失败可回退到文本聊天。
- 隐私：密钥放 env/钥匙串，日志脱敏；屏幕/摄像头采集需显式授权开关。

## 里程碑（建议 3 周）
- **第 1 周**：音频闭环（Whisper.cpp + 系统 TTS），按住说话 UI，SQLite 日志落地。
- **第 2 周**：Playwright + AppleScript 工具层，用例 1/2 跑通；审批节点接入；动作时间线展示。
- **第 3 周**：模型面板 v0（本地/云 Key、路由策略切换、延迟/成本统计），高危拦截用例 4，打磨稳定性。

## 开发与测试要点
- Bun/Node 兼容；首选 Bun 运行 TS 脚本。
- 测试：为守护进程写集成测试（音频→文本→TTS 流程）；工具层写 Playwright/mock 测试。
- 安全：默认最小权限，所有副作用动作记录审计。

（草稿，可随进展迭代）

## 品牌与体验（mycat/Jarvis 感）
- 名称：mycat，定位为个人“Jarvis”式助理。
- 形象：macOS 桌面常驻波形小组件（参考 ChatGPT 客户端和 Apple Intelligence），语音时呈现动态波纹。
- 默认交互：menubar + 可选浮动波形窗；按住说话，状态色反馈 listening/thinking/acting。
- 语音播报风格：简洁、主动汇报关键步骤；遇高危动作先口头确认。

## 卸载与清理（macOS）
- 关闭后台：`launchctl list | grep mycat`；如有：`launchctl remove com.mycat.voice-daemon`（实际 label 以发布时为准）。
- 删除应用/产物：`/Applications/mycat.app`（若存在）；源码形态删构建输出目录。
- 删除配置/缓存/日志/凭据（统一前缀 mycat）：\
  `~/Library/Application Support/mycat/`、`~/Library/Preferences/com.mycat.agent.plist`、`~/Library/Logs/mycat/`、`~/Library/Caches/mycat/`、`~/Library/mycat/credentials/`
- 删除守护/登录项：`~/Library/LaunchAgents/com.mycat.voice-daemon.plist`
- 撤销权限：系统设置 > 隐私与安全，关闭麦克风/屏幕录制/摄像头权限。
- 若通过 Homebrew/cask 安装：`brew uninstall mycat`（发布时提供 cask 名）。
