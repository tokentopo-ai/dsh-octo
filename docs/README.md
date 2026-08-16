# dsh-octo 文档

这里存放当前有效、面向使用者、安装者和维护者的公开文档，并随 npm package 发布。

- [部署与迁移](deployment.md)：安装 bundle、清理旧配置、验证与回滚。
- [Agent 调用手册](agent-call-manual.md)：委派工具、prompt、并行与失败处理。
- [产物交接规则](artifact-handoff.md)：目录、命名、最小读取与 worktree 边界。
- [配置与敏感信息边界](config-and-secrets.md)：认证来源、模型路由和 CLI 兜底红线。
- [验收清单](acceptance-checklist.md)：安装、流程、安全和清理检查。

调研、计划、实验经过、决策记录和历史版本属于本地开发资料，保存在被 Git 忽略的
`local_docs/`，不进入 GitHub 或 npm package。
