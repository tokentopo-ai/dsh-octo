#!/usr/bin/env bash
# install.sh --check 的回归自测：把 plan-final §5 的 S1–S13 场景矩阵固化为可重复脚本。
# 全部场景在临时目录中构造，不触碰真实 ~/.dsh / ~/.agents 环境；失败时退出码非 0。
# 用法：bash test-check.sh
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL="$ROOT/install.sh"

PASS=0
FAIL=0

ok() { PASS=$((PASS+1)); printf '  [PASS] %s\n' "$1"; }
ko() { FAIL=$((FAIL+1)); printf '  [FAIL] %s\n' "$1"; }

assert_rc() { # desc expect actual
  if [ "$3" = "$2" ]; then ok "$1 (rc=$3)"; else ko "$1（期望 rc=$2，实际 rc=$3）"; fi
}
assert_grep() { # desc pattern file
  if grep -q -- "$2" "$3" 2>/dev/null; then ok "$1"; else ko "$1（输出无“$2”）"; fi
}
assert_nogrep() { # desc pattern file
  if grep -q -- "$2" "$3" 2>/dev/null; then ko "$1（输出含“$2”）"; else ok "$1"; fi
}
assert_count() { # desc pattern file expect_count
  local n
  n="$(grep -c -- "$2" "$3" 2>/dev/null || true)"
  n="${n:-0}"
  if [ "$n" = "$4" ]; then ok "$1（$n 处）"; else ko "$1（期望 $4 处，实际 $n 处）"; fi
}
assert_eq() { # desc expect actual
  if [ "$3" = "$2" ]; then ok "$1"; else ko "$1（期望 '$2'，实际 '$3'）"; fi
}

# 相对路径：从目录 $1 到目录 $2（两者须已存在）；用于 S6 构造相对链接。
relpath() {
  local from to from_parts to_parts i j ups rest
  from="$(cd "$1" && pwd -P)"
  to="$(cd "$2" && pwd -P)"
  IFS='/' read -r -a from_parts <<< "${from#/}"
  IFS='/' read -r -a to_parts <<< "${to#/}"
  i=0
  while [ "$i" -lt "${#from_parts[@]}" ] && [ "$i" -lt "${#to_parts[@]}" ] \
        && [ "${from_parts[$i]}" = "${to_parts[$i]}" ]; do
    i=$((i+1))
  done
  ups=""
  j=$i
  while [ "$j" -lt "${#from_parts[@]}" ]; do
    ups="${ups}../"
    j=$((j+1))
  done
  rest=""
  j=$i
  while [ "$j" -lt "${#to_parts[@]}" ]; do
    rest="${rest}${to_parts[$j]}"
    [ $((j+1)) -lt "${#to_parts[@]}" ] && rest="${rest}/"
    j=$((j+1))
  done
  printf '%s%s\n' "$ups" "$rest"
}

echo "== test-check.sh：install.sh --check 回归自测（$(date '+%Y-%m-%d %H:%M')）=="
echo "仓库根：$ROOT"

# ---------- S1 未安装：空目录，无任何链接 ----------
T=$(mktemp -d /tmp/dsh-octo-s1.XXXXXX)
OUT="$T.out"
mkdir -p "$T/dsh" "$T/agents"
before="$(find "$T" -mindepth 1 | wc -l | tr -d ' ')"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/dsh" AGENTS_SKILLS_DIR="$T/agents" bash "$INSTALL" --check >"$OUT" 2>&1)
rc=$?
after="$(find "$T" -mindepth 1 | wc -l | tr -d ' ')"
printf '## S1 未安装\n'
assert_rc "S1 期望 exit 1" 1 "$rc"
assert_count "S1 8 行 [FAIL]" '\[FAIL\]' "$OUT" 8
assert_grep "S1 含“未安装（不存在）”" '未安装（不存在）' "$OUT"
assert_eq "S1 只读：无写入（${before} → ${after}）" "$before" "$after"
rm -rf "$T" "$OUT"

# ---------- S2 正确链接（两侧都指向本仓库）→ 全 PASS ----------
T=$(mktemp -d /tmp/dsh-octo-s2.XXXXXX)
mkdir -p "$T/dsh" "$T/agents"
ln -s "$ROOT" "$T/dsh/dsh-octo"
ln -s "$ROOT" "$T/agents/dsh-octo"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/dsh" AGENTS_SKILLS_DIR="$T/agents" bash "$INSTALL" --check >"$T/out" 2>&1)
rc=$?
printf '## S2 正确链接\n'
assert_rc "S2 期望 exit 0" 0 "$rc"
assert_count "S2 8 行 [PASS]" '\[PASS\]' "$T/out" 8
assert_grep "S2 summary 全部通过" '\[summary\] 全部通过' "$T/out"
rm -rf "$T"

# ---------- S3 指向他处 ----------
T=$(mktemp -d /tmp/dsh-octo-s3.XXXXXX)
mkdir -p "$T/skills" "$T/other"
ln -s "$T/other" "$T/skills/dsh-octo"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/skills" AGENTS_SKILLS_DIR="$T/empty" bash "$INSTALL" --check --dsh-only >"$T/out" 2>&1)
rc=$?
printf '## S3 指向他处\n'
assert_rc "S3 期望 exit 1" 1 "$rc"
assert_grep "S3 含“指向”失败行" '\[FAIL\].*指向' "$T/out"
rm -rf "$T"

# ---------- S4 普通文件占位（非链接） ----------
T=$(mktemp -d /tmp/dsh-octo-s4.XXXXXX)
mkdir -p "$T/skills"
touch "$T/skills/dsh-octo"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/skills" AGENTS_SKILLS_DIR="$T/empty" bash "$INSTALL" --check --dsh-only >"$T/out" 2>&1)
rc=$?
printf '## S4 普通文件占位\n'
assert_rc "S4 期望 exit 1" 1 "$rc"
assert_grep "S4 含“已存在但不是符号链接”" '已存在但不是符号链接' "$T/out"
assert_grep "S4 第 2 项按情况诊断（非符号链接）" '非符号链接，无法判定指向' "$T/out"
assert_nogrep "S4 第 2 项不输出矛盾行（未安装）" '不存在，无法判定指向' "$T/out"
rm -rf "$T"

# ---------- S5 悬空链接 ----------
T=$(mktemp -d /tmp/dsh-octo-s5.XXXXXX)
mkdir -p "$T/skills"
ln -s /nonexistent-dsh-octo-target "$T/skills/dsh-octo"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/skills" AGENTS_SKILLS_DIR="$T/empty" bash "$INSTALL" --check --dsh-only >"$T/out" 2>&1)
rc=$?
printf '## S5 悬空链接\n'
assert_rc "S5 期望 exit 1" 1 "$rc"
assert_count "S5 输出完整（第 2/3/4 项 FAIL）" '\[FAIL\]' "$T/out" 3
assert_count "S5 第 1 项仍 PASS（已安装）" '\[PASS\]' "$T/out" 1
assert_grep "S5 含“链接损坏”" '链接损坏' "$T/out"
rm -rf "$T"

# ---------- S6 相对链接指向本仓库（pwd -P 规范化兜底） ----------
T=$(mktemp -d /tmp/dsh-octo-s6.XXXXXX)
mkdir -p "$T/skills"
rel="$(relpath "$T/skills" "$ROOT")"
ln -s "$rel" "$T/skills/dsh-octo"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/skills" AGENTS_SKILLS_DIR="$T/empty" bash "$INSTALL" --check --dsh-only >"$T/out" 2>&1)
rc=$?
printf '## S6 相对链接指向本仓库\n'
assert_rc "S6 期望 exit 0" 0 "$rc"
assert_count "S6 4 行 [PASS]" '\[PASS\]' "$T/out" 4
assert_grep "S6 第 2 项指向本仓库" '指向本仓库' "$T/out"
rm -rf "$T"

# ---------- S7 链接目标缺 SKILL.md ----------
T=$(mktemp -d /tmp/dsh-octo-s7.XXXXXX)
mkdir -p "$T/repo" "$T/skills"
mkdir -p "$T/repo/local_docs"
ln -s "$T/repo" "$T/skills/dsh-octo"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/skills" AGENTS_SKILLS_DIR="$T/empty" bash "$INSTALL" --check --dsh-only >"$T/out" 2>&1)
rc=$?
printf '## S7 目标缺 SKILL.md\n'
assert_rc "S7 期望 exit 1" 1 "$rc"
assert_grep "S7 含“目标根缺少 SKILL.md”" '目标根缺少 SKILL.md' "$T/out"
rm -rf "$T"

# ---------- S8 链接目标缺 local_docs/ ----------
T=$(mktemp -d /tmp/dsh-octo-s8.XXXXXX)
mkdir -p "$T/repo" "$T/skills"
touch "$T/repo/SKILL.md"
ln -s "$T/repo" "$T/skills/dsh-octo"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/skills" AGENTS_SKILLS_DIR="$T/empty" bash "$INSTALL" --check --dsh-only >"$T/out" 2>&1)
rc=$?
printf '## S8 目标缺 local_docs/\n'
assert_rc "S8 期望 exit 1" 1 "$rc"
assert_grep "S8 含“目标根缺少 local_docs/”" '目标根缺少 local_docs/' "$T/out"
rm -rf "$T"

# ---------- S9 一侧好一侧坏 ----------
T=$(mktemp -d /tmp/dsh-octo-s9.XXXXXX)
mkdir -p "$T/dsh" "$T/agents"
ln -s "$ROOT" "$T/dsh/dsh-octo"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/dsh" AGENTS_SKILLS_DIR="$T/agents" bash "$INSTALL" --check >"$T/out" 2>&1)
rc=$?
printf '## S9 一侧好一侧坏\n'
assert_rc "S9 期望 exit 1" 1 "$rc"
assert_count "S9 dsh 侧 4 行 [PASS]" '\[PASS\]' "$T/out" 4
assert_count "S9 agents 侧 4 行 [FAIL]" '\[FAIL\]' "$T/out" 4
rm -rf "$T"

# ---------- S10 --dsh-only 只输出 dsh 侧 ----------
T=$(mktemp -d /tmp/dsh-octo-s10.XXXXXX)
mkdir -p "$T/dsh" "$T/agents"
ln -s "$ROOT" "$T/dsh/dsh-octo"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/dsh" AGENTS_SKILLS_DIR="$T/agents" bash "$INSTALL" --check --dsh-only >"$T/out" 2>&1)
rc=$?
printf '## S10 --dsh-only\n'
assert_rc "S10 期望 exit 0" 0 "$rc"
assert_nogrep "S10 输出不含 agents 侧路径" "$T/agents" "$T/out"
rm -rf "$T"

# ---------- S11 --agents-only 只输出 agents 侧 ----------
T=$(mktemp -d /tmp/dsh-octo-s11.XXXXXX)
mkdir -p "$T/dsh" "$T/agents"
ln -s "$ROOT" "$T/agents/dsh-octo"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/dsh" AGENTS_SKILLS_DIR="$T/agents" bash "$INSTALL" --check --agents-only >"$T/out" 2>&1)
rc=$?
printf '## S11 --agents-only\n'
assert_rc "S11 期望 exit 0" 0 "$rc"
assert_nogrep "S11 输出不含 dsh 侧路径" "$T/dsh" "$T/out"
rm -rf "$T"

# ---------- S12 互斥（--check 与 --uninstall）----------
T=$(mktemp -d /tmp/dsh-octo-s12.XXXXXX)
mkdir -p "$T/dsh" "$T/agents"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/dsh" AGENTS_SKILLS_DIR="$T/agents" bash "$INSTALL" --check --uninstall >"$T/out" 2>&1)
rc=$?
printf '## S12 互斥\n'
if [ "$rc" -ne 0 ]; then ok "S12a --check --uninstall 期望非 0，实际 rc=$rc"; else ko "S12a 期望非 0，实际 rc=$rc"; fi
assert_grep "S12a 含“互斥”" '互斥' "$T/out"
(cd "$ROOT" && DSH_SKILLS_DIR="$T/dsh" AGENTS_SKILLS_DIR="$T/agents" bash "$INSTALL" --uninstall --check >"$T/out" 2>&1)
rc=$?
if [ "$rc" -ne 0 ]; then ok "S12b --uninstall --check 期望非 0，实际 rc=$rc"; else ko "S12b 期望非 0，实际 rc=$rc"; fi
assert_grep "S12b 含“互斥”" '互斥' "$T/out"
# 回归：同参数重复不误报互斥（P0-1 恢复的幂等语义）
(cd "$ROOT" && DSH_SKILLS_DIR="$T/dsh" AGENTS_SKILLS_DIR="$T/agents" bash "$INSTALL" --uninstall --uninstall >"$T/out" 2>&1)
rc=$?
assert_rc "S12c --uninstall --uninstall 幂等（期望 exit 0）" 0 "$rc"
assert_nogrep "S12c 不报互斥" '互斥' "$T/out"
rm -rf "$T"

# ---------- S13 仓库根缺 SKILL.md：--check 不被前置门抢先 exit ----------
T=$(mktemp -d /tmp/dsh-octo-s13.XXXXXX)
mkdir -p "$T/repo" "$T/skills"
cp "$INSTALL" "$T/repo/install.sh"
(cd "$T/repo" && DSH_SKILLS_DIR="$T/skills" AGENTS_SKILLS_DIR="$T/empty" bash install.sh --check >"$T/out" 2>&1)
rc=$?
printf '## S13 仓库根缺 SKILL.md\n'
assert_rc "S13 期望 exit 1" 1 "$rc"
assert_count "S13 输出完整（8 行明细，未被前置门拦截）" '\[FAIL\]' "$T/out" 8
assert_grep "S13 含“目标根缺少 SKILL.md”" '目标根缺少 SKILL.md' "$T/out"
rm -rf "$T"

echo ""
echo "== 汇总：通过 $PASS / 失败 $FAIL =="
if [ "$FAIL" -eq 0 ]; then
  echo "全部场景通过。"
  exit 0
fi
exit 1
