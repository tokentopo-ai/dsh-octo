---
name: dsh-octo
description: 用于多阶段复杂任务（计划→编码→审核，按需实验）的外部异构 Agent 编排：当任务需要方案选型、多实现对比或独立评审时，主线 agent 按阶段调用 dsh 官方 subagent backend（subagent_claude_code / subagent_codex / subagent_deepseek_v4_pro / subagent_deepseek_v4_flash）协作，以产物文件交接。简单任务、单点修改、直接问答不使用本 skill。
user-invocable: false
---

# dsh-octo：多阶段复杂任务的外部 Agent 编排契约

本 skill 是**纯文字契约（prompt）**，不是程序：不写 orchestration 脚本、不依赖 workflow runtime（不引入 ultracode / dsh Dynamic Workflow 能力）。所有路由与聚合只通过本文件与 `local_docs/` 的文字指令实现，由主线 agent 逐步执行。异构 agent 之间不共享对话上下文，只通过产物文件交接。

外部 agent 一律通过 **dsh 官方 subagent backend 的委派工具**调用（`ctx.subagents`，不经 shell）。这些工具默认未启用，使用前须按 `deploy/README.md` 完成 profile 部署并重开会话；工具缺失时按 §4.5 容错，主线 agent 接管前不擅自降级为直接 CLI。

## 1. 难度判断（先判断，默认不启用）

收到用户请求后，主线 agent 先做**保守**判断：

- **启用**：任务需要「计划 → 编码 → 审核」（甚至实验）多阶段才能完成，或需要方案选型、多实现对比、独立评审。
- **不启用**：单点修改、明确的小修、直接问答、无需方案选型。主线 agent 照常处理。

## 2. 初始化

1. 确定 `PROJECT_ROOT`（目标项目根）并进入该目录。
2. 创建产物目录：`artifacts/input/`、`artifacts/plan/`、`artifacts/impl/`、`artifacts/review/`、`artifacts/experiments/`（及可选的 `artifacts/logs/`）。
3. 把用户任务原样写入 `artifacts/input/task.md`（含约束与验收标准；涉敏内容只写“如何处理”，不写值）。
4. 判断是否 Git 项目：`git rev-parse --is-inside-work-tree`。

## 3. Agent 池与调用速查

| Agent | 组合 | 委派工具（官方 backend） |
| --- | --- | --- |
| `fable` | Claude Code + Fable（xhigh） | `subagent_claude_code`（claude-code backend，前台等待） |
| `gpt-5.6-sol` | Codex + gpt-5.6-sol（xhigh） | `subagent_codex`（codex backend，官方 `~/.codex`，前台等待） |
| `deepseek-v4-pro` | DSH child + deepseek-v4-pro | `subagent_deepseek_v4_pro`（spawn + `agentOptions` deepseek-official，默认后台） |
| `deepseek-v4-flash` | DSH child + deepseek-v4-flash | `subagent_deepseek_v4_flash`（同上，默认后台） |

要点：

- 工具参数统一为 `{ description, prompt }`：`description` 是 3-5 词的任务标签；`prompt` 必须**自包含**（任务说明 + 输入文件路径 + 输出文件路径 + 约束）。
- product 工具（`subagent_claude_code` / `subagent_codex`）不支持 `run_in_background`，**前台等待结果**；deepseek 工具支持 `run_in_background`（默认 true，返回 durable id，完成后收到通知）。
- 结果契约：前台返回 `{ kind: 'foreground', runId, output }`，`stopReason` 非 `completed` 视为失败（可能带 partial output）；后台返回 `{ kind: 'background', jobId }`，以完成通知 + 产物文件为准。
- 每个工具调用前，把完整 prompt 先写入 `artifacts/logs/prompt-<阶段>-<agent>.txt`（审计与重放），再以文件内容作为 `prompt` 传入。
- 并行（如 4 份 deepseek-v4-pro 计划）：先后台发起全部调用，再逐个等待完成通知并检查产物文件。失败先重试一次，仍失败按 §4.5 容错。
- 敏感值（`DEEPSEEK_API_KEY` 等）由 DSH 原生凭据管理，工具调用与 prompt 中**不出现、不注入**任何密钥。

## 4. 阶段流程

### 4.1 计划（Plan）

1. 调用 `subagent_claude_code` 让 `fable` 写 1 份计划 → `artifacts/plan/plan-01-fable.md`（前台等待）。
2. 调用 `subagent_deepseek_v4_pro` ×4（后台并行，同一输入 `artifacts/input/task.md`，不同视角）→ `plan-02/03/04/05-deepseek-v4-pro.md`：
   - `plan-02` 架构与方案选型：模块边界、技术选型、接口设计；
   - `plan-03` 实现路径：步骤拆解、依赖顺序、工作量估计、提交粒度；
   - `plan-04` 风险与验证：风险清单、测试策略、验收标准、回退方案；
   - `plan-05` 资源与成本：agent/工具复用、时间与 token 预算、并行度、失败兜底。
3. 5 份计划齐备后，调用 `subagent_deepseek_v4_flash` 让 `deepseek-v4-flash` 阅读全部 5 份，综合产出**最终计划** → `artifacts/plan/plan-final.md`。最终计划须决策完整：目标、成功标准、实现步骤、验收方式、风险与假设。

### 4.2 编码（Code）

- **非 Git 项目**：调用 `subagent_codex` 让 `gpt-5.6-sol` 依据 `plan-final.md` 直接在 `PROJECT_ROOT` 编码（前台等待）。
- **Git 项目**：
  1. 主线 agent 基于当前基准创建 4 个 sibling worktree：`<parent>/<basename>-dsh-octo-wt-01..04`（`git worktree add`；本机 dsh 为全访问沙箱，workspace 外路径可写）。
  2. 调用 `subagent_deepseek_v4_pro` ×4（后台并行），各 agent 在**自己的 worktree** 内实现（prompt 显式给出 worktree 绝对路径，子 agent 先 `cd` 到该目录再工作），互不干扰；完成后各自在**自己的 worktree 内**写实现说明 `artifacts/impl/impl-0<n>-deepseek-v4-pro.md`（变更清单、关键决策、如何验证）。
  3. 4 份完成后，调用 `subagent_codex` 让 `gpt-5.6-sol` 阅读 4 份实现说明与对应 diff，在**主 worktree** 写出最终实现，并写 `artifacts/impl/impl-final-gpt-5.6-sol.md`（合并取舍与最终变更清单）。

### 4.3 审核（Review）

- 调用 `subagent_codex` 让 `gpt-5.6-sol` 负责：阅读最终实现与 4 份实现说明 → 代码评审 → 跑单元测试/烟测 → 写 `artifacts/review/review-gpt-5.6-sol.md`（评审结论、测试结果、bug 记录）。
- 评审或测试中发现 bug：由 `gpt-5.6-sol` 直接修复，修复结果回写报告。

### 4.4 实验（Experiment，按需）

- 正式实验过程：**主线 agent** 亲自执行，记录 `artifacts/experiments/experiment-<序号>-<主题>.md`。
- 实验结果分析：调用 `subagent_claude_code` 让 `fable` 分析 → `artifacts/experiments/experiment-analysis-fable.md`。

### 4.5 容错

- 任何一步外部 agent 掉线/超时/不可用：**主线 agent 接管该步骤**，自行完成并落盘，流程继续、不阻塞。
- 工具缺失（profile 未启用）：按 `deploy/README.md` 启用并重开会话；会话内不可用时主线 agent 接管。
- 接管时先用官方工具重试一次；仍失败由主线 agent 自行完成，必要时才用直接 CLI 兜底（`claude-official` / `codex exec`，注意点见 `local_docs/config-and-secrets.md`）。
- 接管时沿用产物交接规则，保证后续步骤可读。

## 5. 产物交接规则

- 所有中间产物必须落盘为文件；这是“纯 prompt 契约”跨 agent 交接的基础。
- 命名：`<阶段>-<序号>-<agent>.<ext>`；每个 agent **只读取**自己需要的上一阶段产物与输入，不读取无关上下文。
- 详细目录结构、读写矩阵与最小读取原则见 `local_docs/artifact-handoff.md`。

## 6. 敏感信息铁律

- 真实 token / 密钥 / 账号凭证**不得**写入本仓库或任何产物文件（AGENTS.md / SKILL.md / local_docs / 产物一律如此）。
- 官方 backend 的凭据由 DSH 原生管理（Claude Code 登录态 / `deepseek-official` 的 `DEEPSEEK_API_KEY`），SKILL.md 与 prompt 不注入任何密钥。
- 直接 CLI 兜底时：Claude 官方登录态走 `claude-official`（剥离 `ANTHROPIC_*` 注入变量）；Codex 双套 `CODEX_HOME` 显式指定。细节见 `local_docs/config-and-secrets.md`。

## 7. 详细手册

- 委派工具调用契约、prompt 骨架、并行与重试策略 → `local_docs/agent-call-manual.md`
- 配置与敏感信息读取 → `local_docs/config-and-secrets.md`
- 产物目录、命名、读写矩阵 → `local_docs/artifact-handoff.md`
- 安装/端到端验收清单 → `local_docs/acceptance-checklist.md`
- dsh 接口调研摘要 → `local_docs/dsh-interface-notes.md`
- profile 启用方案（依赖 + cordis 补丁）→ `deploy/README.md`
