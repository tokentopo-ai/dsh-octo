#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$ROOT/install.sh"
BASE="$(mktemp -d /tmp/dsh-octo-check.XXXXXX)"
trap 'rm -rf "$BASE"' EXIT

PASS=0
FAIL=0

ok() { PASS=$((PASS+1)); printf '  [PASS] %s\n' "$1"; }
ko() { FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$1"; }

assert_rc() {
  if [ "$3" = "$2" ]; then ok "$1 (rc=$3)"; else ko "$1（期望 rc=$2，实际 rc=$3）"; fi
}

assert_grep() {
  if grep -q -- "$2" "$3"; then ok "$1"; else ko "$1（输出未匹配 $2）"; fi
}

assert_count() {
  count="$(grep -c -- "$2" "$3" 2>/dev/null || true)"
  if [ "$count" = "$4" ]; then ok "$1"; else ko "$1（期望 $4，实际 $count）"; fi
}

run() {
  out="$1"
  dir="$2"
  shift 2
  (cd "$ROOT" && AGENTS_SKILLS_DIR="$dir" bash "$INSTALL" "$@" >"$out" 2>&1)
  return $?
}

echo "== install.sh Agents-link regression =="

skills="$BASE/s1"
mkdir -p "$skills"
before="$(find "$skills" -mindepth 1 | wc -l | tr -d ' ')"
run "$BASE/s1.out" "$skills" --check
rc=$?
after="$(find "$skills" -mindepth 1 | wc -l | tr -d ' ')"
assert_rc "S1 未安装 check 失败" 1 "$rc"
assert_count "S1 四项失败" '\[FAIL\]' "$BASE/s1.out" 4
if [ "$before" = "$after" ]; then ok "S1 check 只读"; else ko "S1 check 写入了目录"; fi

skills="$BASE/s2"
mkdir -p "$skills"
run "$BASE/s2.install" "$skills"
assert_rc "S2 默认安装" 0 "$?"
run "$BASE/s2.check" "$skills" --check
assert_rc "S2 安装后 check" 0 "$?"
assert_count "S2 四项通过" '\[PASS\]' "$BASE/s2.check" 4
run "$BASE/s2.repeat" "$skills" --agents-only
assert_rc "S2 重复安装幂等" 0 "$?"
assert_grep "S2 重复安装输出 skip" '\[skip\]' "$BASE/s2.repeat"

skills="$BASE/s3"
other="$BASE/other"
mkdir -p "$skills" "$other"
ln -s "$other" "$skills/dsh-octo"
run "$BASE/s3.out" "$skills" --check
assert_rc "S3 错误目标 check 失败" 1 "$?"
assert_grep "S3 报告错误指向" '\[FAIL\].*指向' "$BASE/s3.out"

skills="$BASE/s4"
mkdir -p "$skills/dsh-octo"
run "$BASE/s4.out" "$skills" --check
assert_rc "S4 非链接 check 失败" 1 "$?"
assert_grep "S4 报告非链接" '不是符号链接' "$BASE/s4.out"

skills="$BASE/s5"
mkdir -p "$skills"
ln -s "$BASE/missing" "$skills/dsh-octo"
run "$BASE/s5.out" "$skills" --check
assert_rc "S5 悬空链接 check 失败" 1 "$?"
assert_grep "S5 报告链接损坏" '链接损坏' "$BASE/s5.out"

skills="$BASE/s6"
mkdir -p "$skills"
ln -s "$ROOT" "$skills/dsh-octo"
run "$BASE/s6.out" "$skills" --check
assert_rc "S6 正确绝对链接" 0 "$?"
run "$BASE/s6.uninstall" "$skills" --uninstall
assert_rc "S6 卸载自己的链接" 0 "$?"
if [ ! -e "$skills/dsh-octo" ] && [ ! -L "$skills/dsh-octo" ]; then ok "S6 链接已移除"; else ko "S6 链接仍存在"; fi
run "$BASE/s6.uninstall-again" "$skills" --uninstall
assert_rc "S6 重复卸载幂等" 0 "$?"

skills="$BASE/s7"
repo="$BASE/incomplete"
mkdir -p "$skills" "$repo"
touch "$repo/SKILL.md"
ln -s "$repo" "$skills/dsh-octo"
run "$BASE/s7.out" "$skills" --check
assert_rc "S7 缺 docs check 失败" 1 "$?"
assert_grep "S7 报告缺 docs" '缺少 docs/' "$BASE/s7.out"

skills="$BASE/s8"
mkdir -p "$skills"
run "$BASE/s8.out" "$skills" --dsh-only
assert_rc "S8 拒绝旧 dsh-only" 2 "$?"
assert_grep "S8 指向 bundle 文档" 'docs/deployment.md' "$BASE/s8.out"

skills="$BASE/s9"
mkdir -p "$skills"
run "$BASE/s9a.out" "$skills" --check --uninstall
rc_a=$?
run "$BASE/s9b.out" "$skills" --uninstall --check
rc_b=$?
if [ "$rc_a" -ne 0 ] && [ "$rc_b" -ne 0 ]; then ok "S9 check/uninstall 双向互斥"; else ko "S9 互斥参数未拒绝"; fi

repo="$BASE/incomplete-checkout"
skills="$BASE/s10"
mkdir -p "$repo" "$skills"
cp "$INSTALL" "$repo/install.sh"
(cd "$repo" && AGENTS_SKILLS_DIR="$skills" bash install.sh --check >"$BASE/s10.out" 2>&1)
rc=$?
assert_rc "S10 不完整 checkout 仍输出 check 诊断" 1 "$rc"
assert_count "S10 输出四项失败" '\[FAIL\]' "$BASE/s10.out" 4
assert_grep "S10 包含目标缺 SKILL.md" '目标根缺少 SKILL.md' "$BASE/s10.out"

printf '[summary] PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then exit 1; fi
