# dsh-octo

<p align="center">
  <img src="assets/icon.png" alt="dsh-octo" width="360">
</p>

<p align="center">
  <a href="README.md">English</a> | 简体中文
</p>

<p align="center">
  <a href="#前置条件">前置条件</a> ·
  <a href="#安装">安装</a> ·
  <a href="#能做什么">能做什么</a> ·
  <a href="#工作原理">工作原理</a> ·
  <a href="#文档">文档</a> ·
  <a href="#license">License</a>
</p>

Deepseek Harness 内建支持以无头方式调用 Claude Code 和 Codex 作为 subagents，即
built-in subagent backends，并且这些 subagents 可以复用本地的账号登录状态和账号自带的
coding plan，例如，如果你有 Claude Code 的 max plan，就可以让 dsh 调用 Fable-5 作为
subagent。

受此启发，我设计了这一专门面向 dsh 的 skill，设计想法是：

- 尽可能使用内建特性，以最无缝的方式实现异构 subagents 调用
- 让 dsh 能够意识到它能够调用 subagents，能够利用 multi-agents 聚合形成更高的智能
- 针对计划、编码、验收等不同阶段，设计专门的 multi-agents 工作流，实现高质量协作

## 前置条件

- dsh `0.1.0-rc.6`。
- dsh 主模型已配置 `deepseek-official` provider。
- 已安装 Node.js、npm，以及可供 `dsh plugin` 使用的 pnpm 环境。
- 本机已安装并登录 Claude Code 与 Codex，且对应账号已订阅有效的 coding plan。

## 安装

dsh-octo 当前面向 dsh `0.1.0-rc.6`。请通过本地 tarball 安装，让 dsh 能正确解析 bundle
及其全部依赖：

```bash
git clone https://github.com/tokentopo-ai/dsh-octo.git
cd dsh-octo
npm pack
dsh plugin --profile web add ./dsh-octo-0.1.0.tgz
```

请把 `web` 替换为实际使用的 profile，然后重启该 profile。

安装完成后，像平常一样与 dsh 正常对话并描述任务即可，不需要触发短语、手动选择
subagent，也不需要逐阶段发出命令。skill 只会在确有必要时发起 multi-agent 协作。

## 能做什么

dsh-octo 是一份**纯文字编排契约**，而非 orchestration 引擎：不带 workflow runtime，也不依赖
ultracode 或 dsh Dynamic Workflow 能力。bundle 只负责安装依赖、注册 skill、启用委派工具；
所有路由和阶段决策都由主线 agent 按 skill 的文字指令逐步执行。

它只在真正需要多阶段协作时才会启用自己：

- **启用**：任务需要「计划 → 编码 → 审核」的完整流程（可选实验阶段），或需要方案选型、
  多实现对比、独立评审。
- **不启用**：单点修改、明确的小修、直接问答，这类任务不需要决策，继续走主线 agent 的
  常规路径，没有额外开销。

一旦启用，主线 agent 会把不同阶段委派给一组固定的官方 dsh subagent backend：

| Agent | 组合 | 委派工具 |
| --- | --- | --- |
| `fable` | Claude Code + Fable（xhigh） | `subagent_claude_code` |
| `gpt-5.6-sol` | Codex + gpt-5.6-sol（xhigh） | `subagent_codex` |
| `deepseek-v4-pro` | DSH child + deepseek-v4-pro | `subagent_deepseek_v4_pro` |
| `deepseek-v4-flash` | DSH child + deepseek-v4-flash | `subagent_deepseek_v4_flash` |

一次典型的协作流程：

1. **计划**：`fable` 先写一份初稿；4 个 `deepseek-v4-pro` 并行从不同视角（架构选型、
   实现路径、风险与测试、资源与成本）各写一份；`deepseek-v4-flash` 综合全部 5 份，产出
   最终计划。
2. **编码**：在 Git 项目中，4 个 `deepseek-v4-pro` 在各自独立的 `git worktree` 里并行实现；
   `gpt-5.6-sol` 阅读全部 4 份实现与 diff，在主 worktree 合并出最终变更。
3. **审核**：`gpt-5.6-sol` 以原始任务（而非仅计划）为基准做规格核对，跑测试，修复发现的
   bug，并对每条「已修复/已变更」声明附可执行验证命令后才放行。
4. **实验**（按需）：主线 agent 亲自执行实验，再交给 `fable` 分析结果。

agent 之间互不共享对话上下文，每一步交接都落盘为 `artifacts/`（`input/`、`plan/`、`impl/`、
`review/`、`experiments/`）下的文件。任意一步 subagent 掉线、超时或被拒绝，主线 agent 会
接管该步骤自行完成，不阻塞任务，交接记录也会如实登记这次接管，保证协作过程事后可查。

## 工作原理

dsh-octo 以静态 Cordis bundle 安装：一个 packaged skill provider，加上官方 `codex`、
`claude-code` product providers 及其四个 `subagent_*` 工具，直接加入指定 dsh profile。
这里选择用 tarball 安装（而不是 `dsh plugin add .` 或直接 Git checkout）是有意为之——
只有这样才能让 package 的 `files` allowlist 生效，使 skill 的资源根只暴露 `index.js`、
`cordis.patch.yml`、`SKILL.md`、`assets/`、`docs/` 与两份 README，本仓库内部的开发资料
（`artifacts/`、`AGENTS.md`、`local_docs/`）不会泄漏进去。完整的安装/迁移/回滚流程见
[部署与迁移](docs/deployment.md)。

认证始终不会复制到本项目中：Claude Code 与 Codex 继续使用各自本地的登录态和 coding plan
权益，dsh-octo 只是调用已经拥有这些认证的官方 backend。

## 文档

以下文档随 npm package 一同发布，覆盖安装、委派契约与本 README 之外的运行细节：

- [部署与迁移](docs/deployment.md)：安装 bundle、清理旧配置、验证与回滚。
- [Agent 调用手册](docs/agent-call-manual.md)：委派工具契约、prompt 结构、并行与重试策略。
- [产物交接规则](docs/artifact-handoff.md)：目录结构、命名规则、agent 间的最小读取与
  worktree 边界。
- [配置与敏感信息边界](docs/config-and-secrets.md)：认证来源、模型路由和 CLI 兜底红线。
- [验收清单](docs/acceptance-checklist.md)：安装、流程、安全和清理检查。

## License

本项目当前以 `UNLICENSED` 状态分发，尚未授予开源许可证。
