# 部署：为 dsh profile 启用官方 subagent backend 工具

dsh-octo 通过 dsh 官方 subagent backend 调用外部 agent，涉及 4 个委派工具：

| 工具 | backend | 依赖 |
| --- | --- | --- |
| `subagent_claude_code` | `claude-code` | `@deepseek-ai/dsh-subagent-claude-code` |
| `subagent_codex` | `codex` | `@deepseek-ai/dsh-subagent-codex` |
| `subagent_deepseek_v4_pro` | `spawn` + `agentOptions` | 内置（`deepseek-official`，主 agent 同源） |
| `subagent_deepseek_v4_flash` | 同上 | 内置 |

这些工具在 standard preset 中默认 disabled，需要在本机 dsh profile 启用。以下以 web profile（`~/.dsh/profiles/web`）为例。

## 步骤

### 1. 安装 product provider 包（版本与 dsh 本体一致）

dsh 版本检查：`node ~/.dsh/profiles/node_modules/@deepseek-ai/dsh/lib/bin.js --version`。

```bash
DSH_BIN="$HOME/.dsh/profiles/node_modules/@deepseek-ai/dsh/lib/bin.js"
node "$DSH_BIN" plugin --profile web add \
  @deepseek-ai/dsh-subagent-codex@0.1.0-rc.6 \
  @deepseek-ai/dsh-subagent-claude-code@0.1.0-rc.6 \
  @deepseek-ai/dsh-sdk-protocol@^0.1.0-rc.6
```

> 版本号以 npm 为准：`npm view @deepseek-ai/dsh-subagent-codex dist-tags --json`（`next` 与 rc 系列对齐）。若已通过其他方式安装可跳过。

> ⚠️ profile 的 `pnpm-workspace.yaml` 设了 `autoInstallPeers: false`，provider 包的
> `@deepseek-ai/*` peer 依赖（如 `dsh-sdk-protocol`）不会自动安装，必须**显式 add**；
> 漏装会报 `Cannot find package '@deepseek-ai/dsh-sdk-protocol'`。装完后可用
> `cd ~/.dsh/profiles/web && node --input-type=module -e "await import('@deepseek-ai/dsh-subagent-codex')"` 验证。

### 2. 合并工具行补丁

把 `deploy/web.cordis.patch.yml` 的内容合并进 `~/.dsh/profiles/web/cordis.patch.yml`（保留原有条目；改前先备份）。

### 3. 校验组合树

```bash
node "$DSH_BIN" --profile web --dump-config | grep -A8 'tool-subagent-codex'
```

应能看到 `subagent_codex` / `subagent_claude_code` / `subagent_deepseek_v4_pro` / `subagent_deepseek_v4_flash` 四个工具行。

### 4. 重启并验证

重启 dsh web 并开新会话，工具目录中应出现 4 个委派工具（`<available_tools>` 或工具列表）。验收见 `local_docs/acceptance-checklist.md` §A4。

## 前置条件

- dsh ≥ 0.1.0-rc.6（含 product provider 包的能力）。
- 本机有 `claude`（官方登录态）与 `codex` 可执行文件。
- fable 模型与 xhigh effort 由部署层 Claude 设置固定（`~/.claude/settings.json` 的 `model` / `effortLevel`；改它影响所有 Claude 会话，或用 claude-code provider 的 `env` overlay 只对 dsh 生效）。

## 回滚

```bash
node "$DSH_BIN" plugin --profile web remove @deepseek-ai/dsh-subagent-codex @deepseek-ai/dsh-subagent-claude-code
# 并还原 cordis.patch.yml 备份
```
