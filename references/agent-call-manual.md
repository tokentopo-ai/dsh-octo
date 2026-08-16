# Agent 调用手册

本文件定义 dsh-octo 各阶段的委派细节。主路径一律使用 dsh bundle 注册的官方
subagent 工具，不经 shell。

## 1. 工具与结果

| Agent | 工具 | 调度与结果 |
| --- | --- | --- |
| `fable` | `subagent_claude_code` | 前台；成功结果的 `stopReason` 必须为 `completed` |
| `gpt-5.6-sol` | `subagent_codex` | 前台；成功结果的 `stopReason` 必须为 `completed` |
| `deepseek-v4-pro` | `subagent_deepseek_v4_pro` | continuable，默认后台 |
| `deepseek-v4-flash` | `subagent_deepseek_v4_flash` | continuable，默认后台 |

通用调用形态：

```text
subagent_<name>({
  description: "<3-5 词任务标签>",
  prompt: "<完整自包含任务文本>",
  run_in_background?: boolean
})
```

`run_in_background` 只用于两个 DeepSeek 工具。前台结果形态为
`{ kind: 'foreground', runId, output }`；后台结果形态为
`{ kind: 'background', jobId }`，以完成通知与产物文件为准。

## 2. Prompt 与审计

每次调用前，把即将传入的完整 prompt 写入
`artifacts/logs/prompt-<阶段>-<序号>-<agent>.txt`，然后直接读取该文件作为工具参数，
避免日志和实际调用漂移。prompt 必须包含：

1. 角色与单一目标；
2. 允许读取的输入文件；
3. 唯一输出路径；
4. 工作目录与读写边界；
5. 验收格式和失败条件；
6. 不写凭据、不修改无关文件等禁止事项。

计划 prompt 最小骨架：

```text
你是 <agent>，负责从 <视角> 为目标任务写实施计划。
读取 artifacts/input/task.md 与明确列出的项目文件。
把结果写入 <输出路径>，包含目标、决策、步骤、风险与验收。
只写计划，不改代码，不写任何凭据。完成后只回复输出路径。
```

实现 prompt 最小骨架：

```text
你是 <agent>，依据 artifacts/plan/plan-final.md 实现目标任务。
工作目录是 <WORKTREE_ABSOLUTE_PATH>；只在该 worktree 修改。
把实现说明写入 <输出路径>，列出变更、决策和验证命令。
不要提交，不要修改其他 worktree，不写任何凭据。
```

审核 prompt 最小骨架：

```text
你是独立审核者。以 artifacts/input/task.md 为唯一规格基准，
先找规格偏离，再评审实现并运行声明中的验证命令。
把结论、findings、测试结果、修复记录和遗留风险写入 <输出路径>。
```

## 3. 并行与失败

1. 并行任务先写全部带序号的 prompt 日志，再发起全部后台调用。
2. 等待完成通知；需要时用 dsh 提供的 agent 控制工具查询、追问或中止。
3. 每个结果都检查 `stopReason`、目标文件存在性与内容契约。
4. 失败先通过官方工具重试一次；仍失败才由主线接管并登记降级台账。
5. 主线接管实现后，不得同时作为该实现的唯一审核者。

## 4. CLI 兜底

直接 CLI 只在主线已接管且官方工具仍不可用时使用：

```bash
claude-official -p "$(cat "$PROMPT_FILE")" --model fable --effort xhigh
codex exec -C "$PROJECT_ROOT" "$(cat "$PROMPT_FILE")"
CODEX_HOME="$ALTERNATE_CODEX_HOME" codex exec -C "$PROJECT_ROOT" \
  -m "$ALTERNATE_CODEX_MODEL" "$(cat "$PROMPT_FILE")"
```

Claude 兜底必须使用会剥离上层 `ANTHROPIC_*` 注入变量的 `claude-official` wrapper；
Codex 后端必须显式区分官方与替代 `CODEX_HOME`；替代配置根与模型名由本机部署层提供，
不得把具体路径或凭据写入 prompt。详细安全边界见
`references/config-and-secrets.md`。
