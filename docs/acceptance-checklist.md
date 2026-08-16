# 验收清单

## A. Bundle 安装

- [ ] dsh 版本与 `package.json` 固定的 `@deepseek-ai/*` dependencies 兼容。
- [ ] 目标 profile 的 dependencies 含 `dsh-octo`；不是只创建
  `~/.dsh/skills/dsh-octo` 链接。
- [ ] `dsh --profile <name> --dump-config` 出现 `# == dsh-octo` layer。
- [ ] 组合树只有一组 dsh-octo provider/tool rows，没有遗留手工 patch 重复项。
- [ ] skill 目录只出现一个 `dsh-octo`；旧 user-dsh 链接已移除或确认不遮蔽 packaged skill。
- [ ] `skill({ name: "dsh-octo" })` 能读取正文，并能访问 `docs/` 相对资源。
- [ ] 工具目录出现 `subagent_claude_code`、`subagent_codex`、
  `subagent_deepseek_v4_pro`、`subagent_deepseek_v4_flash`。
- [ ] provider package imports 成功；不能只凭 config dump 判定运行时已激活。
- [ ] 本机 Claude Code、Codex 与 dsh 主模型 provider 分别通过各自原生自检。

## B. 流程运行

- [ ] 复杂任务触发；简单单点任务不触发。
- [ ] `artifacts/input/task.md` 与所需目录已建立。
- [ ] 计划阶段产生 1 份 fable、4 份 deepseek-v4-pro 和 1 份最终计划。
- [ ] Git 项目的四个实现 worktree 基于同一 commit，互不串改。
- [ ] 最终实现说明列出取舍、变更和可执行验证命令。
- [ ] 独立审核先做规格对抗，再复跑每条实现声明的验证命令。
- [ ] 外部 agent 失败时记录具体错误、接管者和独立性变化。
- [ ] 主线接管的实现由未参与实现的 agent 审核。
- [ ] 实验由主线执行，结果由 fable 分析。

## C. 安全与清理

- [ ] package、仓库、prompt 与 artifacts 中没有真实凭据。
- [ ] 没有打印认证环境变量值。
- [ ] 临时 profile 使用隔离 `DSH_HOME`，测试后可完整删除。
- [ ] worktree 已按用户决定保留或清理。
- [ ] Git diff 只包含目标实现文件，没有生成物或 tarball。
