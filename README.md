# dsh-octo

<p align="center">
  <img src="assets/icon.png" alt="dsh-octo" width="360">
</p>

<p align="center">
  English | <a href="README_zh.md">简体中文</a>
</p>

<p align="center">
  <a href="#prerequisites">Prerequisites</a> ·
  <a href="#install">Install</a> ·
  <a href="#what-it-does">What It Does</a> ·
  <a href="#how-it-works">How It Works</a> ·
  <a href="#documentation">Documentation</a> ·
  <a href="#license">License</a>
</p>

Deepseek Harness (dsh) natively supports headless invocation of Claude Code and Codex as
subagents through its built-in subagent backends, and these subagents can reuse the local account
login state and the coding plans that come with the accounts. For example, if you have a Claude
Code Max plan, you can have dsh call Fable-5 as a subagent.

Inspired by this, I designed this skill specifically for dsh, with these ideas in mind:

- Use built-in capabilities wherever possible for the most seamless invocation of heterogeneous
  subagents.
- Make dsh aware that it can call subagents, so it can aggregate multiple agents into greater
  intelligence.
- Design dedicated multi-agent workflows for different stages—such as planning, coding, and
  acceptance—to achieve high-quality collaboration.

## Prerequisites

- dsh `0.1.0-rc.6`.
- A `deepseek-official` provider configured for the main dsh model.
- Node.js, npm, and a pnpm environment available to `dsh plugin`.
- Claude Code and Codex installed and signed in locally, with active coding-plan subscriptions
  on the corresponding accounts.

## Install

dsh-octo currently targets dsh `0.1.0-rc.6`. Install it from a local tarball so dsh can resolve
the bundle and all of its dependencies:

```bash
git clone https://github.com/tokentopo-ai/dsh-octo.git
cd dsh-octo
npm pack
dsh plugin --profile web add ./dsh-octo-0.1.0.tgz
```

Replace `web` with the profile you use, then restart it.

Once installed, use dsh exactly as usual: describe your task in normal conversation. No trigger
phrase, subagent selection, or stage-by-stage command is required. The skill starts multi-agent
collaboration only when it is useful.

## What It Does

dsh-octo is a **prompt-only orchestration contract**, not an orchestration engine: it ships no
workflow runtime and does not depend on ultracode or dsh Dynamic Workflow capabilities. The
bundle only installs dependencies, registers the skill, and enables the delegation tools; every
routing and stage decision is made by the main agent as it follows the skill's written
instructions.

It only activates itself for tasks that genuinely need multi-stage collaboration:

- **Activates** — tasks that need a plan → code → review pipeline (with optional experiments),
  or that benefit from comparing multiple solutions or an independent review pass.
- **Stays out of the way** — single-point fixes, direct Q&A, and small changes that don't need a
  design decision. These continue on the main agent's usual path, with no overhead.

When it does activate, the main agent delegates to a fixed pool of official dsh subagent
backends, one per stage:

| Agent | Composition | Delegated tool |
| --- | --- | --- |
| `fable` | Claude Code + Fable (xhigh) | `subagent_claude_code` |
| `gpt-5.6-sol` | Codex + gpt-5.6-sol (xhigh) | `subagent_codex` |
| `deepseek-v4-pro` | DSH child + deepseek-v4-pro | `subagent_deepseek_v4_pro` |
| `deepseek-v4-flash` | DSH child + deepseek-v4-flash | `subagent_deepseek_v4_flash` |

A typical run walks through:

1. **Plan** — `fable` drafts an initial plan; four `deepseek-v4-pro` subagents draft it again in
   parallel from different angles (architecture, implementation path, risk/testing, resources);
   `deepseek-v4-flash` synthesizes all five into a final plan.
2. **Code** — for a Git project, four `deepseek-v4-pro` subagents implement the plan in parallel,
   isolated `git worktree`s; `gpt-5.6-sol` reads all four implementations and diffs, then merges
   them into the final change in the main worktree.
3. **Review** — `gpt-5.6-sol` checks the implementation against the original task (not just
   against the plan), runs tests, fixes any bugs it finds, and verifies every "fixed/changed"
   claim with an executable command before signing off.
4. **Experiment** (only when needed) — the main agent runs the experiment itself and hands the
   results to `fable` for analysis.

Every handoff between agents is written to a file under `artifacts/` (`input/`, `plan/`, `impl/`,
`review/`, `experiments/`) rather than passed through shared conversation context, since
heterogeneous agents don't share context with each other. If a subagent is unavailable, times
out, or is rejected, the main agent takes over that step itself instead of blocking the task, and
the handoff records this so the collaboration stays inspectable after the fact.

## How It Works

dsh-octo is installed as a static Cordis bundle: a packaged skill provider plus the official
`codex` and `claude-code` product providers and their four `subagent_*` tools, added directly to
the selected dsh profile. Installing from the tarball (rather than `dsh plugin add .` or a plain
Git checkout) matters here — it is what keeps the package's `files` allowlist in effect, so only
`index.js`, `cordis.patch.yml`, `SKILL.md`, `assets/`, `docs/`, and the READMEs are exposed as the
skill's resource base, and none of this repository's private development material (`artifacts/`,
`AGENTS.md`, `local_docs/`) leaks into it. See [Deployment](docs/deployment.md) for the full
install/migrate/rollback procedure.

Authentication is never copied into this project: Claude Code and Codex keep using their own
local login state and coding-plan entitlements, and dsh-octo only calls the official backends
that already own that authentication.

## Documentation

The following documents ship with the package and cover installation, the delegation contract,
and operational detail beyond this README:

- [Deployment](docs/deployment.md) — installing the bundle, cleaning up old configuration,
  verification, and rollback.
- [Agent call manual](docs/agent-call-manual.md) — delegation tool contracts, prompt structure,
  parallelism, and retry policy.
- [Artifact handoff](docs/artifact-handoff.md) — directory layout, naming, and the
  minimal-read/worktree boundaries between agents.
- [Config and secrets](docs/config-and-secrets.md) — credential sources, model routing, and the
  boundaries for CLI fallback.
- [Acceptance checklist](docs/acceptance-checklist.md) — installation, workflow, security, and
  cleanup checks.

## License

This project is currently distributed as `UNLICENSED`; no open-source license is granted.
