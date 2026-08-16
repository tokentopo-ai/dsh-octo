# dsh-octo

<p align="center">
  <img src="assets/icon.png" alt="dsh-octo" width="360">
</p>

<p align="center">
  English | <a href="README_zh.md">简体中文</a>
</p>

`dsh-octo` brings structured multi-agent collaboration to dsh through its official heterogeneous
subagent backends, including Claude Code, Codex, and dsh-native DeepSeek agents. The Claude Code
and Codex backends reuse the host's existing local authentication, so advanced models such as
Fable-5 can participate as specialized subagents without copying credentials into the project.

Everyday requests continue through dsh normally. When a task benefits from broader reasoning or
independent validation, dsh-octo coordinates multi-agent collaboration across planning, coding,
review, and optional experimentation automatically.

## Install

dsh-octo currently targets dsh `0.1.0-rc.6`. Install it from a local tarball so dsh can resolve
the bundle and all of its dependencies:

```bash
git clone https://github.com/tokentopo-ai/dsh-octo.git
cd dsh-octo
npm pack
dsh plugin --profile web add ./dsh-octo-0.1.0.tgz
```

Replace `web` with the profile you use, then restart that profile. Do not use `dsh plugin add .`:
its `link:` installation does not expose the bundle dependencies correctly. For migration,
verification, and rollback instructions, see [`docs/deployment.md`](docs/deployment.md).

Once installed, use dsh exactly as usual: describe your task in normal conversation. No trigger
phrase, subagent selection, or stage-by-stage command is required. The skill starts multi-agent
collaboration only when it is useful.

## How It Works

dsh-octo is installed as a static Cordis bundle. The bundle adds the packaged skill and the
official heterogeneous subagent integrations to the selected dsh profile, while the skill decides
when collaboration is appropriate and guides the main agent through it. There is no separate
workflow engine for users to configure or operate.

For complex tasks, the main agent coordinates specialized subagents across the relevant stages
and records their handoffs in project files so the work remains inspectable. Simple tasks stay on
the main path, and unavailable subagents fall back to the main agent instead of blocking the task.
Authentication remains owned by each official backend and is never copied into this project.

## Prerequisites

- dsh `0.1.0-rc.6`.
- Host installations of Claude Code and Codex with their native authentication configured.
- A `deepseek-official` provider configured for the main dsh model.
- Node.js, npm, and a pnpm environment available to `dsh plugin`.
