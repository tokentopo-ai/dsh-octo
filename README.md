# dsh-octo

<p align="center">
  <img src="assets/icon.png" alt="dsh-octo" width="360">
</p>

<p align="center">
  English | <a href="README_zh.md">简体中文</a>
</p>

`dsh-octo` is a heterogeneous-agent orchestration skill for dsh, distributed as a static
Cordis bundle.

- `SKILL.md` owns complexity triage, the Plan / Code / Review / Experiment stages, role
  assignment, artifact handoff, and fallback behavior. It is the sole orchestration contract.
- The bundle installs provider dependencies, registers the packaged skill, and enables four
  fixed subagent tools. It does not execute tasks, create worktrees, or implement a workflow
  runtime.

## Structure

```text
dsh-octo/
├── package.json             # npm package and dsh.bundle manifest
├── cordis.patch.yml         # Skill provider, 2 product providers, and 4 tool rows
├── index.js                 # Packaged skill provider
├── SKILL.md                 # Prompt-only orchestration contract
├── docs/                    # Public documentation, runtime manuals, and deployment guide
├── test-bundle.sh           # Bundle integration smoke test with an isolated DSH_HOME
└── tests/                   # Provider and bundle configuration unit tests
```

See [`docs/README.md`](docs/README.md) for the documentation index. `local_docs/` stores
research, plans, and development records. It and the runtime-generated `artifacts/` directory
are excluded from Git and the npm package.

## Install in dsh

The bundle is pinned for compatibility with dsh `0.1.0-rc.6`. See
[`docs/deployment.md`](docs/deployment.md) for the complete procedure.

Install it from the registry, or build a tarball from a local checkout first:

```bash
npm pack
dsh plugin --profile web add ./dsh-octo-0.1.0.tgz
```

The `link:` form produced by `dsh plugin add .` is not supported. It does not expose the
bundle dependencies to the profile and makes the packaged skill resource root cover the entire
checkout, including private development files. Registry and tarball installations expose only
the publish allowlist in `package.json`.

After installation, remove any legacy manual patch and `~/.dsh/skills/dsh-octo` link before
restarting the profile. A filesystem skill has higher discovery priority and would shadow the
packaged skill.

## Usage

Start a complex task in a dsh session where the bundle is installed. The skill organizes the
external agents into these stages:

1. One fable plan, four parallel deepseek-v4-pro plans, and a deepseek-v4-flash synthesis.
2. For Git projects, four independent worktree implementations followed by a final integration
   in the main worktree by gpt-5.6-sol.
3. Specification challenge, code review, and testing by gpt-5.6-sol.
4. Experiments executed by the main agent and analyzed by fable when needed.

Simple tasks do not trigger this workflow. All cross-agent information is handed off through
files under `artifacts/`.

## Verification

```bash
npm test
npm run pack:check
npm run test:bundle
```

`test:bundle` creates an isolated `DSH_HOME`, installs a local tarball, verifies the packaged
skill, three providers, and four tools, then removes the temporary environment. It does not
modify the real `~/.dsh` or invoke any model.

## Prerequisites

- dsh `0.1.0-rc.6`. When upgrading dsh, update and retest every pinned `@deepseek-ai/*` version.
- Host installations of Claude Code and Codex with their native authentication configured.
- A `deepseek-official` provider configured for the main dsh model.
- Node.js, npm, and a pnpm environment available to `dsh plugin`.
