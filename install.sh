#!/usr/bin/env bash
set -euo pipefail

# Non-dsh consumers discover dsh-octo through the shared Agents skill directory.
# dsh itself installs this repository as a bundle; see deploy/README.md.

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="$(basename "$REPO_DIR")"
AGENTS_SKILLS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"

MODE="install"

usage() {
  cat <<'EOF'
dsh-octo Agents skill link installer.

Usage:
  ./install.sh                # install ~/.agents/skills/dsh-octo
  ./install.sh --agents-only  # explicit alias for the default
  ./install.sh --check        # read-only link diagnostics
  ./install.sh --uninstall    # remove this repository's Agents link

dsh installation uses the package bundle, not ~/.dsh/skills. See deploy/README.md.
EOF
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --agents-only) ;;
    --dsh-only)
      echo "错误：dsh 侧不再使用 skill 符号链接；请按 deploy/README.md 安装 bundle" >&2
      exit 2
      ;;
    --uninstall)
      [ "$MODE" = "check" ] && { echo "错误：--uninstall 与 --check 互斥" >&2; usage 1; }
      MODE="uninstall"
      ;;
    --check)
      [ "$MODE" = "uninstall" ] && { echo "错误：--uninstall 与 --check 互斥" >&2; usage 1; }
      MODE="check"
      ;;
    -h|--help) usage 0 ;;
    *) echo "未知参数: $1" >&2; usage 1 ;;
  esac
  shift
done

if [ "$MODE" != "check" ]; then
  if ! [[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "错误：仓库名 $NAME 不是 kebab-case，skill 无法被发现" >&2
    exit 1
  fi

  if [ ! -f "$REPO_DIR/SKILL.md" ] || [ ! -d "$REPO_DIR/references" ]; then
    echo "错误：仓库根必须包含 SKILL.md 与 references/" >&2
    exit 1
  fi
fi

target="$AGENTS_SKILLS_DIR/$NAME"

if [ "$MODE" = "uninstall" ]; then
  if [ -L "$target" ]; then
    raw="$(readlink "$target")"
    resolved="$(cd "$target" 2>/dev/null && pwd -P 2>/dev/null || true)"
    repo_phys="$(cd -P "$REPO_DIR" && pwd -P)"
    if [ "$raw" = "$REPO_DIR" ] || [ "$resolved" = "$repo_phys" ]; then
      rm "$target"
      echo "[uninstall] 已移除 $target"
    else
      echo "[skip] $target 指向其他位置，不自动移除" >&2
    fi
  elif [ -e "$target" ]; then
    echo "[skip] $target 不是符号链接，不自动移除" >&2
  else
    echo "[skip] $target 未安装"
  fi
  exit 0
fi

if [ "$MODE" = "check" ]; then
  fail=0
  total=0
  repo_phys="$(cd -P "$REPO_DIR" && pwd -P)"

  emit() {
    printf '[%s] %s: %s\n' "$1" "$2" "$3"
  }

  total=$((total+1))
  if [ -L "$target" ]; then
    emit PASS "$target" "已安装（符号链接）"
  elif [ -e "$target" ]; then
    emit FAIL "$target" "已存在但不是符号链接"
    fail=$((fail+1))
  else
    emit FAIL "$target" "未安装（不存在）"
    fail=$((fail+1))
  fi

  total=$((total+1))
  if [ -L "$target" ] && [ -e "$target" ]; then
    raw="$(readlink "$target")"
    resolved="$(cd "$target" 2>/dev/null && pwd -P 2>/dev/null || true)"
    if [ "$raw" = "$REPO_DIR" ] || [ "$resolved" = "$repo_phys" ]; then
      emit PASS "$target" "指向本仓库"
    else
      emit FAIL "$target" "指向 $raw"
      fail=$((fail+1))
    fi
  elif [ -L "$target" ]; then
    emit FAIL "$target" "链接损坏（目标不存在）"
    fail=$((fail+1))
  else
    emit FAIL "$target" "无法判定指向"
    fail=$((fail+1))
  fi

  total=$((total+1))
  if [ -f "$target/SKILL.md" ]; then
    emit PASS "$target" "目标根含 SKILL.md"
  else
    emit FAIL "$target" "目标根缺少 SKILL.md"
    fail=$((fail+1))
  fi

  total=$((total+1))
  if [ -d "$target/references" ]; then
    emit PASS "$target" "目标根含 references/"
  else
    emit FAIL "$target" "目标根缺少 references/"
    fail=$((fail+1))
  fi

  if [ "$fail" -eq 0 ]; then
    printf '[summary] 全部通过 %s/%s（退出码 0）\n' "$total" "$total"
    exit 0
  fi
  pass=$((total-fail))
  printf '[summary] 失败：通过 %s / 失败 %s（退出码 1）\n' "$pass" "$fail"
  exit 1
fi

mkdir -p "$AGENTS_SKILLS_DIR"
if [ -L "$target" ]; then
  raw="$(readlink "$target")"
  resolved="$(cd "$target" 2>/dev/null && pwd -P 2>/dev/null || true)"
  repo_phys="$(cd -P "$REPO_DIR" && pwd -P)"
  if [ "$raw" = "$REPO_DIR" ] || [ "$resolved" = "$repo_phys" ]; then
    echo "[skip] $target 已指向本仓库"
  else
    rm "$target"
    ln -s "$REPO_DIR" "$target"
    echo "[relink] $target -> $REPO_DIR"
  fi
elif [ -e "$target" ]; then
  echo "[错误] $target 已存在且不是符号链接；请手动处理后再运行" >&2
  exit 1
else
  ln -s "$REPO_DIR" "$target"
  echo "[install] $target -> $REPO_DIR"
fi

echo "完成。Agents/Codex 将从共享 skill 目录发现 ${NAME}；dsh 请安装 bundle。"
