#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_ROOT="$(mktemp -d /tmp/dsh-octo-bundle.XXXXXX)"
SMOKE_PID=""

cleanup() {
  if [ -n "$SMOKE_PID" ] && kill -0 "$SMOKE_PID" 2>/dev/null; then
    kill -INT "$SMOKE_PID" 2>/dev/null || true
    wait "$SMOKE_PID" 2>/dev/null || true
  fi
  case "$TEMP_ROOT" in
    /tmp/dsh-octo-bundle.*) rm -rf -- "$TEMP_ROOT" ;;
    *) echo "refusing to remove unexpected temp path: $TEMP_ROOT" >&2 ;;
  esac
}
trap cleanup EXIT INT TERM

for command in diff dsh npm node rg sort tar; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "missing required command: $command" >&2
    exit 1
  }
done

DSH_TEST_HOME="$TEMP_ROOT/dsh-home"
AGENTS_TEST_HOME="$TEMP_ROOT/agents-home"
mkdir -p "$AGENTS_TEST_HOME"

echo "[1/5] pack bundle"
TARBALL_NAME="$(npm pack --pack-destination "$TEMP_ROOT" --silent)"
TARBALL="$TEMP_ROOT/$TARBALL_NAME"
test -f "$TARBALL"

tar -tzf "$TARBALL" >"$TEMP_ROOT/package-files.txt"
cat >"$TEMP_ROOT/expected-package-files.txt" <<'EOF'
package/README.md
package/SKILL.md
package/assets/icon.png
package/cordis.patch.yml
package/deploy/README.md
package/index.js
package/package.json
package/references/acceptance-checklist.md
package/references/agent-call-manual.md
package/references/artifact-handoff.md
package/references/config-and-secrets.md
EOF
sort -o "$TEMP_ROOT/package-files.txt" "$TEMP_ROOT/package-files.txt"
if ! diff -u "$TEMP_ROOT/expected-package-files.txt" "$TEMP_ROOT/package-files.txt"; then
  echo "tarball contents differ from the package allowlist" >&2
  exit 1
fi

echo "[2/5] install tarball into isolated profile"
DSH_HOME="$DSH_TEST_HOME" DSH_AGENTS_HOME="$AGENTS_TEST_HOME" \
  dsh plugin --profile smoke add "$TARBALL"

echo "[3/5] inspect composed config"
DSH_HOME="$DSH_TEST_HOME" DSH_AGENTS_HOME="$AGENTS_TEST_HOME" \
  dsh --profile smoke --dump-config >"$TEMP_ROOT/dump.yml"
rg -q '^# == dsh-octo$' "$TEMP_ROOT/dump.yml"
for tool in subagent_codex subagent_claude_code subagent_deepseek_v4_pro subagent_deepseek_v4_flash; do
  count="$(rg -c "toolName: $tool$" "$TEMP_ROOT/dump.yml" || true)"
  count="${count:-0}"
  if [ "$count" -ne 1 ]; then
    echo "expected one $tool row, found $count" >&2
    exit 1
  fi
done

PROFILE="$DSH_TEST_HOME/profiles/smoke"
(cd "$PROFILE" && node --input-type=module -e \
  "await import('@deepseek-ai/dsh-subagent-codex'); await import('@deepseek-ai/dsh-subagent-claude-code')")

echo "[4/5] boot and verify runtime registrations"
cat >"$TEMP_ROOT/verifier.mjs" <<'EOF'
import { access } from 'node:fs/promises'
import { join } from 'node:path'

export const name = 'dsh-octo-smoke-verifier'
export const inject = ['skills', 'subagents', 'tools']

const providerNames = ['codex', 'claude-code', 'spawn']
const toolNames = [
  'subagent_codex',
  'subagent_claude_code',
  'subagent_deepseek_v4_pro',
  'subagent_deepseek_v4_flash',
]

export async function apply(ctx) {
  let missingProviders = providerNames
  let missingTools = toolNames
  let skill
  for (let attempt = 0; attempt < 100; attempt += 1) {
    missingProviders = providerNames.filter(name => ctx.subagents.getProvider(name) === undefined)
    missingTools = toolNames.filter(name => ctx.tools.get(name) === undefined)
    skill = await ctx.skills.get('dsh-octo')
    if (missingProviders.length === 0 && missingTools.length === 0 && skill !== undefined) break
    await new Promise(resolve => setTimeout(resolve, 100))
  }
  if (missingProviders.length > 0 || missingTools.length > 0 || skill === undefined) {
    throw new Error(`missing providers=${missingProviders.join(',')}; tools=${missingTools.join(',')}; skill=${skill === undefined}`)
  }
  if (!skill.content.startsWith('# dsh-octo：多阶段复杂任务的外部 Agent 编排契约')) {
    throw new Error('packaged skill body was not loaded correctly')
  }
  if (skill.resourceBase?.kind !== 'directory') {
    throw new Error('packaged skill resourceBase is missing')
  }
  for (const path of [
    'references/agent-call-manual.md',
    'references/config-and-secrets.md',
    'references/artifact-handoff.md',
    'references/acceptance-checklist.md',
    'deploy/README.md',
  ]) {
    await access(join(skill.resourceBase.path, path))
  }
  console.log('dsh-octo bundle smoke: skill=1 providers=3 tools=4')
}
EOF

cat >"$PROFILE/cordis.patch.yml" <<EOF
- insert:
    - id: dsh-octo-smoke-verifier
      name: '$TEMP_ROOT/verifier.mjs'
EOF

DSH_HOME="$DSH_TEST_HOME" DSH_AGENTS_HOME="$AGENTS_TEST_HOME" \
  dsh --profile smoke </dev/null >"$TEMP_ROOT/boot.log" 2>&1 &
SMOKE_PID=$!

verified=0
for _ in $(seq 1 100); do
  if rg -q '^dsh-octo bundle smoke: skill=1 providers=3 tools=4$' "$TEMP_ROOT/boot.log"; then
    verified=1
    break
  fi
  if ! kill -0 "$SMOKE_PID" 2>/dev/null; then break; fi
  sleep 0.1
done

if [ "$verified" -ne 1 ]; then
  echo "bundle runtime verification failed" >&2
  sed -n '1,240p' "$TEMP_ROOT/boot.log" >&2
  exit 1
fi

kill -INT "$SMOKE_PID" 2>/dev/null || true
wait "$SMOKE_PID" 2>/dev/null || true
SMOKE_PID=""

echo "[5/5] PASS: packaged skill, 3 providers, and 4 tools activated"
