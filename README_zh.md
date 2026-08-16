# dsh-octo

<p align="center">
  <img src="assets/icon.png" alt="dsh-octo" width="360">
</p>

<p align="center">
  <a href="README.md">English</a> | 简体中文
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

## License

本项目当前以 `UNLICENSED` 状态分发，尚未授予开源许可证。
