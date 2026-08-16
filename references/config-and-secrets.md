# 配置与敏感信息边界

本文件只说明配置来源和安全边界，不包含任何凭据值或本机已配置状态。

## 1. 官方 backend

| Backend | 配置来源 |
| --- | --- |
| `claude-code` | 宿主机 Claude Code 的原生认证与部署层模型设置 |
| `codex` | 宿主机 Codex 原生认证；默认配置根通常为 `~/.codex` |
| `deepseek-official` | dsh 原生 provider 配置；API key 由 dsh 指定的环境变量读取 |

SKILL、prompt、bundle patch 和产物都不得注入或复制凭据。provider 进程继承什么环境，
由 dsh profile 与宿主进程负责。

## 2. 模型路由

- `subagent_claude_code` 的模型与 effort 由 Claude Code 部署层固定。
- `subagent_codex` 使用官方 Codex 配置根，模型与 reasoning effort 由其原生配置固定。
- 两个 DeepSeek 工具通过 tool row 的 `agentOptions.provider` / `model` 固定，不在 prompt
  中传凭据或切换 backend。

## 3. 直接 CLI 兜底

直接 CLI 不是正常路径。使用前必须在降级台账记录官方工具不可用的具体原因。

- Claude：只使用 `claude-official` wrapper；wrapper 应在 exec 前剥离会改变官方路由的
  `ANTHROPIC_*` 与 `CLAUDE_CODE_*` 注入变量。
- Codex：官方配置与替代 provider 配置必须使用不同的 `CODEX_HOME`；命令前缀显式指定，
  不依赖当前 shell 的偶然环境。
- 任何自检只判断命令或环境变量是否存在，不打印值。

## 4. 红线

- 不把 token、API key、cookie、账号凭据或认证文件写入仓库、package、artifacts 或 prompt。
- 不从宿主配置读取凭据后转写到其他文件。
- 不在错误日志中输出完整环境变量或认证响应。
- bundle 只声明 provider package 与工具配置，不管理登录态。
