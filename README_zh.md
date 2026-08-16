# dsh-octo

<p align="center">
  <img src="assets/icon.png" alt="dsh-octo" width="360">
</p>

<p align="center">
  <a href="README.md">English</a> | 简体中文
</p>

`dsh-octo` 基于 dsh 官方的异构 subagent backend，为 dsh 提供结构化的 multi-agent
协作能力，可统一调度 Claude Code、Codex 和 dsh 原生 DeepSeek agent。Claude Code 与
Codex backend 会复用宿主机已有的本地登录凭证，无需把凭据复制到项目中，因此可以让
Fable-5 等先进模型作为专门的 subagent 参与任务。

日常请求仍由 dsh 正常处理。当任务需要更充分的推理或独立验证时，dsh-octo 会自动组织
覆盖计划、编码、审核和按需实验的 multi-agent 协作。

## 安装

dsh-octo 当前面向 dsh `0.1.0-rc.6`。请通过本地 tarball 安装，让 dsh 能正确解析 bundle
及其全部依赖：

```bash
git clone https://github.com/tokentopo-ai/dsh-octo.git
cd dsh-octo
npm pack
dsh plugin --profile web add ./dsh-octo-0.1.0.tgz
```

请把 `web` 替换为实际使用的 profile，然后重启该 profile。不要使用
`dsh plugin add .`：它产生的 `link:` 安装无法正确暴露 bundle dependencies。迁移、
验证与回滚步骤见 [`docs/deployment.md`](docs/deployment.md)。

安装完成后，像平常一样与 dsh 正常对话并描述任务即可，不需要触发短语、手动选择
subagent，也不需要逐阶段发出命令。skill 只会在确有必要时发起 multi-agent 协作。

## 工作原理

dsh-octo 以静态 Cordis bundle 安装。bundle 将 packaged skill 和官方异构 subagent
集成加入指定 dsh profile，skill 则负责判断何时需要协作并引导主线 agent 完成任务。
用户不需要配置或操作额外的 workflow engine。

面对复杂任务时，主线 agent 会在相关阶段组织专门的 subagent，并通过项目文件完成交接，
使过程可检查；简单任务继续走主线路径，subagent 不可用时也会由主线 agent 接管，而不
阻塞任务。认证始终由各官方 backend 管理，不会复制到本项目中。

## 前置条件

- dsh `0.1.0-rc.6`。
- 宿主机已安装 Claude Code 与 Codex，并完成各自原生认证。
- dsh 主模型已配置 `deepseek-official` provider。
- 已安装 Node.js、npm，以及可供 `dsh plugin` 使用的 pnpm 环境。
