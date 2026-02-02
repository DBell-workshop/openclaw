# GPT.md — Guardrails for Product & Code Work

Purpose: keep answers grounded,代码安全、上下文完整，帮助在 OpenClaw 及其衍生项目中高质量交付。

## 使用方式
- 开工前：用 3 分钟写迷你 Spec（见下方模板），贴在 PR/Issue/笔记里。
- 进行中：维护决策日志（关键选择、假设、阻塞）；切换上下文时更新。
- 完成后：按验收项勾选，记录残余风险，列出改动的文件路径。

## 工作姿态
- 输出简洁高信噪：“查了什么→结论/改动→验证”。
- 先问缺失信息，不猜测；不知道就说明并给验证计划。
- 论据基于代码/文档行号或权威外部来源；偏好可回滚的改动与特性开关。

## 防幻觉规则
- 不杜撰 API/配置键；先在代码或文档确认再引用。
- 精确引用错误/配置时先验证；架构/流程说明附上路径 `src/...`、`docs/...`。
- 置信度 <0.8 时先澄清或提供验证步骤。
- 维护“事实清单”，新证据冲突时及时更正。

## 上下文卫生
- 回显任务目标与验收标准后再写代码。
- 方向改变时总结：已做/未做/待做，防止上下文漂移。
- 报告结果时注明：分支、HEAD、相关运行环境（Node/Bun 版本等）。
- 记录外部依赖（模型端点、密钥、OS 特性）及配置位置。

## 迷你 Spec 模板（Spec Coding）
- Problem/Goal：业务影响+成功判定
- Users/Scenarios：谁在何种情景下使用
- Inputs/Outputs & contracts：类型、错误、超时、幂等
- Non-goals/Boundaries：本次不做什么
- Acceptance checks：可执行或可验证的通过标准
- Risks/Unknowns + mitigations：最高风险与验证手段
- Metrics/Budgets：延迟/成本/内存/准确度阈值及测量方式

## 代码质量纪律（OpenClaw 习惯）
- TypeScript 严格，避免 `any`，文件尽量 <~700 LOC，优先抽助手而非复制 V2。
- 测试：就近 `*.test.ts`；落地前跑 `pnpm test`（或 scoped）。
- 规范：`pnpm lint`（oxlint）+`pnpm format`（oxfmt）必须干净。
- 工具：TS 脚本/开发用 Bun，发布产物用 Node；锁文件以 `pnpm-lock.yaml` 为准。
- 不擅自 patch 依赖；扩展 runtime deps 禁止 `workspace:*`。
- 可观测性：增加有价值的日志/指标，脱敏处理，避免泄露密钥/PII。
- 有副作用的动作/自动化：默认最小权限，必要时审批；记录时间戳+操作者+参数（脱敏）。

## 协作与沟通
- 每个重要改动提供文件路径定位（如 `src/foo.ts:123`）。
- 先总结后细节；开放问题单列。
- 阻塞 >30 分钟：同步已尝试方案和下一步实验。

## 链接与参考
- 仓库总规则：见 `AGENTS.md`。
- Docs 链接优先绝对地址 `https://docs.openclaw.ai/...`。

本文件供 ChatGPT/工程师在本仓库执行任务时作为默认行为准则。
