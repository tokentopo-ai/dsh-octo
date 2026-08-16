# dsh-octo

面向 dsh 的 skill：让主线 agent 有意识、有组织地使用 dsh 官方 subagent backend 能力，按阶段聚合外部 agent（Claude Code / Codex / DSH 进程内 child）完成多阶段复杂任务。纯 prompt 契约，无 orchestration 脚本、不依赖 workflow runtime。

## 结构

```text
dsh-octo/
├── SKILL.md                    # skill 契约（dsh 以 <name>/SKILL.md 发现）
├── local_docs/                 # 开发过程参考/记录文档（本地，不入库）
│   ├── agent-call-manual.md    # 委派工具契约、prompt 骨架、并行/重试/兜底
│   ├── config-and-secrets.md   # 凭据来源与敏感信息读取（无明文密钥）
│   ├── artifact-handoff.md     # 产物目录、命名、读写矩阵
│   ├── acceptance-checklist.md # 安装验收 + 端到端运行验收清单
│   └── dsh-interface-notes.md  # dsh 接口调研摘要
├── deploy/
│   ├── README.md               # profile 启用官方 backend 工具的部署步骤
│   └── web.cordis.patch.yml    # 4 个委派工具的 cordis 补丁
├── install.sh                  # 安装到 dsh / agents skill 发现目录（符号链接）
├── AGENTS.md                   # 本仓库契约源（已 gitignore，不入库）
└── .gitignore
```

## 安装

两步：

1. 安装 skill 本身：
   ```bash
   ./install.sh              # 符号链接到 ~/.dsh/skills/dsh-octo 与 ~/.agents/skills/dsh-octo
   ./install.sh --dsh-only   # 只装 ~/.dsh/skills
   ./install.sh --uninstall  # 卸载
   ```
2. 启用官方 subagent backend 工具（一次性部署）：按 `deploy/README.md` 给 dsh profile 装 provider 包 + 合并 `deploy/web.cordis.patch.yml`。

安装后重启/重开 dsh 会话即可发现（`~/.dsh/skills` 是 rank 400 的用户级发现根）。完整验收按 `local_docs/acceptance-checklist.md` 执行。

## 使用

在 dsh 会话中发起复杂任务即可：难度判断 → 计划（fable 1 份 + deepseek-v4-pro 4 份并行 + deepseek-v4-flash 综合）→ 编码（Git 项目 4 worktree 并行 + gpt-5.6-sol 合并）→ 审核（gpt-5.6-sol）→ 按需实验。全部经官方委派工具：`subagent_claude_code` / `subagent_codex` / `subagent_deepseek_v4_pro` / `subagent_deepseek_v4_flash`。简单任务不会触发本 skill。

## 前置依赖

- dsh ≥ 0.1.0-rc.6，profile 已启用 4 个委派工具（见 `deploy/README.md`）。
- 本机 `claude`（官方登录态，fable 模型由部署层设置）与 `codex`（官方 `~/.codex`：gpt-5.6-sol/xhigh）。
- DSH 原生 DeepSeek 凭据（`DEEPSEEK_API_KEY`，主 agent 同源）；仓库不含任何密钥。

## 维护

- `AGENTS.md` 是契约源；SKILL.md 与 local_docs 不得与之冲突。
- 改 SKILL.md / local_docs 后无需重装（符号链接实时生效）；dsh 目录缓存按需重开会话。
