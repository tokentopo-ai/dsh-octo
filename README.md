# dsh-octo

<p align="center">
  <img src="assets/icon.png" alt="dsh-octo" width="360">
</p>

`dsh-octo` 是一个面向 dsh 的异构 agent 编排 skill，并以静态 Cordis bundle 分发。

- `SKILL.md` 负责难度判断、Plan / Code / Review / Experiment 阶段、角色分工、产物交接与
  容错；它是唯一编排契约。
- bundle 负责安装 provider dependencies、注册 packaged skill，并启用 4 个固定 subagent
  工具；它不执行任务、不创建 worktree，也不实现 workflow runtime。

## 结构

```text
dsh-octo/
├── package.json             # npm package + dsh.bundle manifest
├── cordis.patch.yml         # skill provider、2 个 product provider、4 个 tool rows
├── index.js                 # packaged skill provider
├── SKILL.md                 # 纯 prompt 编排契约
├── docs/                    # 公开文档、运行时手册与部署指南
├── install.sh               # 非 dsh Agents/Codex 的 skill 链接安装器
├── test-check.sh            # install.sh 临时目录回归测试
├── test-bundle.sh           # 隔离 DSH_HOME 的 bundle 集成烟测
└── tests/                   # provider 与 bundle 配置单测
```

公开文档索引见 [`docs/README.md`](docs/README.md)。`local_docs/` 保存调研、计划和开发过程
记录；它与运行产物 `artifacts/` 均不进入 Git，也不进入 npm package。

## dsh 安装

当前 bundle 固定兼容 dsh `0.1.0-rc.6`。完整步骤见
[`docs/deployment.md`](docs/deployment.md)。

从 registry 安装，或在本地 checkout 先生成 tarball 再安装：

```bash
npm pack
dsh plugin --profile web add ./dsh-octo-0.1.0.tgz
```

不支持 `dsh plugin add .` 的 `link:` 安装：它既不能向 profile 暴露 bundle dependencies，
也会让 packaged skill 的资源根落在含私有开发文件的整个 checkout。tarball/registry 安装
只暴露 `package.json` 的发布 allowlist。

安装后先处理旧手工 patch 与 `~/.dsh/skills/dsh-octo` 链接，再重启 profile。不能让旧
filesystem skill 长期共存：它会以更高优先级遮蔽 packaged skill。

## Agents/Codex 安装

非 dsh 的共享 skill 发现仍使用仓库链接：

```bash
./install.sh
./install.sh --check
./install.sh --uninstall
```

脚本只管理 `~/.agents/skills/dsh-octo`，不会修改 dsh profile 或 `~/.dsh/skills`。

## 使用

在安装了 bundle 的 dsh 会话中发起复杂任务。skill 会按以下阶段组织外部 agent：

1. fable 计划 + 4 个 deepseek-v4-pro 并行计划 + deepseek-v4-flash 综合；
2. Git 项目使用 4 个独立 worktree 实现，由 gpt-5.6-sol 在主 worktree 汇总；
3. gpt-5.6-sol 做规格对抗、代码评审与测试；
4. 正式实验由主线执行，fable 分析结果。

简单任务不会触发该流程。全部跨 agent 信息通过 `artifacts/` 文件交接。

## 验证

```bash
npm test
npm run pack:check
npm run test:bundle
```

`test:bundle` 会创建隔离 `DSH_HOME`、安装本地 tarball、验证 packaged skill、3 个 provider
与 4 个工具，然后清理临时目录；不会修改真实 `~/.dsh`，也不会发起模型调用。

## 前置条件

- dsh `0.1.0-rc.6`；升级 dsh 时先更新并复测全部 `@deepseek-ai/*` 固定版本。
- 宿主机 Claude Code 与 Codex 可执行文件及各自原生认证。
- dsh 主模型侧已配置 `deepseek-official` provider。
- Node.js、npm，以及 `dsh plugin` 可调用的 pnpm 环境。
