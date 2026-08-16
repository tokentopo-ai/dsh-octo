#!/usr/bin/env bash
set -euo pipefail

# dsh-octo 安装脚本：把本仓库（skill bundle 根）符号链接到 dsh / agents 的 skill 发现目录。
# 符号链接保证单一事实来源：改仓库文件即生效，无需复制。
#
# 用法:
#   ./install.sh               # 安装到 ~/.dsh/skills 与 ~/.agents/skills
#   ./install.sh --dsh-only    # 只装 ~/.dsh/skills
#   ./install.sh --agents-only # 只装 ~/.agents/skills
#   ./install.sh --uninstall   # 移除已安装的链接

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="$(basename "$REPO_DIR")"

DSH_SKILLS_DIR="${DSH_SKILLS_DIR:-$HOME/.dsh/skills}"
AGENTS_SKILLS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"

MODE="install"
DSH_TARGET=1
AGENTS_TARGET=1

usage() {
  sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dsh-only)    DSH_TARGET=1; AGENTS_TARGET=0 ;;
    --agents-only) DSH_TARGET=0; AGENTS_TARGET=1 ;;
    --uninstall)   MODE="uninstall" ;;
    -h|--help)     usage 0 ;;
    *) echo "未知参数: $1" >&2; usage 1 ;;
  esac
  shift
done

if ! [[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "错误：仓库名 $NAME 不是 kebab-case，dsh 无法发现该 skill" >&2
  exit 1
fi

if [ ! -f "$REPO_DIR/SKILL.md" ]; then
  echo "错误：$REPO_DIR/SKILL.md 不存在，仓库根必须即 skill bundle 根" >&2
  exit 1
fi

ensure_link() {
  local dir="$1"
  local link="$dir/$NAME"
  if [ "$MODE" = "uninstall" ]; then
    if [ -L "$link" ]; then
      rm "$link"
      echo "[uninstall] 已移除 $link"
    fi
    return
  fi
  mkdir -p "$dir"
  if [ -L "$link" ]; then
    local cur
    cur="$(readlink "$link")"
    if [ "$cur" = "$REPO_DIR" ]; then
      echo "[skip] $link 已指向本仓库"
    else
      rm "$link"
      ln -s "$REPO_DIR" "$link"
      echo "[relink] $link -> $REPO_DIR"
    fi
  elif [ -e "$link" ]; then
    echo "[错误] $link 已存在且不是符号链接；请手动处理后再运行" >&2
    exit 1
  else
    ln -s "$REPO_DIR" "$link"
    echo "[install] $link -> $REPO_DIR"
  fi
}

if [ "$DSH_TARGET" -eq 1 ]; then
  ensure_link "$DSH_SKILLS_DIR"
fi
if [ "$AGENTS_TARGET" -eq 1 ]; then
  ensure_link "$AGENTS_SKILLS_DIR"
fi

if [ "$MODE" = "install" ]; then
  echo "完成。重开 dsh 会话后即可发现 skill：$NAME"
fi
