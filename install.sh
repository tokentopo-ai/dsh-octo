#!/usr/bin/env bash
set -euo pipefail

# dsh-octo 安装脚本：把本仓库（skill bundle 根）符号链接到 dsh / agents 的 skill 发现目录。
# 符号链接保证单一事实来源：改仓库文件即生效，无需复制。
# 用法见 usage()（./install.sh -h）。

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAME="$(basename "$REPO_DIR")"

DSH_SKILLS_DIR="${DSH_SKILLS_DIR:-$HOME/.dsh/skills}"
AGENTS_SKILLS_DIR="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"

MODE="install"
DSH_TARGET=1
AGENTS_TARGET=1

usage() {
  cat <<'EOF'
dsh-octo 安装脚本：把本仓库（skill bundle 根）符号链接到 dsh / agents 的 skill 发现目录。
符号链接保证单一事实来源：改仓库文件即生效，无需复制。

用法:
  ./install.sh               # 安装到 ~/.dsh/skills 与 ~/.agents/skills
  ./install.sh --dsh-only    # 只装 ~/.dsh/skills
  ./install.sh --agents-only # 只装 ~/.agents/skills
  ./install.sh --uninstall   # 移除已安装的链接
  ./install.sh --check       # 检查安装状态并输出诊断
EOF
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dsh-only)    DSH_TARGET=1; AGENTS_TARGET=0 ;;
    --agents-only) DSH_TARGET=0; AGENTS_TARGET=1 ;;
    --uninstall)   [ "$MODE" = "check" ] && { echo "错误：--uninstall 与 --check 互斥" >&2; usage 1; }; MODE="uninstall" ;;
    --check)       [ "$MODE" = "uninstall" ] && { echo "错误：--uninstall 与 --check 互斥" >&2; usage 1; }; MODE="check" ;;
    -h|--help)     usage 0 ;;
    *) echo "未知参数: $1" >&2; usage 1 ;;
  esac
  shift
done

if [ "$MODE" != "check" ]; then
  if ! [[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo "错误：仓库名 $NAME 不是 kebab-case，dsh 无法发现该 skill" >&2
    exit 1
  fi

  if [ ! -f "$REPO_DIR/SKILL.md" ]; then
    echo "错误：$REPO_DIR/SKILL.md 不存在，仓库根必须即 skill bundle 根" >&2
    exit 1
  fi
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

# --check 只读诊断：逐项检查两侧 skill 链接状态，每项一行 [PASS]/[FAIL]，末尾 [summary]。
# 只读铁律：不创建/删除任何文件或链接；判定全部放在 if 条件上下文，计数用 $((...))，绝不中途 exit。
run_check() {
  local FAIL=0
  local TOTAL=0
  local repo_phys
  repo_phys="$(cd -P "$REPO_DIR" 2>/dev/null && pwd -P 2>/dev/null || true)"

  emit() {
    local tag="$1" path="$2" detail="$3"
    printf '[%s] %s: %s\n' "$tag" "$path" "$detail"
  }

  check_target() {
    local dir="$1"
    local link="$dir/$NAME"
    local is_link=0
    local is_dangling=0

    # 1) 存在性
    TOTAL=$((TOTAL+1))
    if [ -L "$link" ]; then
      is_link=1
      emit PASS "$link" "已安装（符号链接）"
      if [ ! -e "$link" ]; then
        is_dangling=1
      fi
    elif [ -e "$link" ]; then
      emit FAIL "$link" "已存在但不是符号链接"
      FAIL=$((FAIL+1))
    else
      emit FAIL "$link" "未安装（不存在）"
      FAIL=$((FAIL+1))
    fi

    # 2) 指向本仓库（符号链接才判定；悬空/非链接计失败）
    TOTAL=$((TOTAL+1))
    if [ "$is_link" -eq 0 ]; then
      # 与第 1) 项保持一致语义：路径存在但非链接 vs 路径不存在，输出不同诊断
      if [ -e "$link" ]; then
        emit FAIL "$link" "非符号链接，无法判定指向"
      else
        emit FAIL "$link" "不存在，无法判定指向"
      fi
      FAIL=$((FAIL+1))
    elif [ "$is_dangling" -eq 1 ]; then
      emit FAIL "$link" "链接损坏（目标不存在）"
      FAIL=$((FAIL+1))
    else
      local raw resolved
      raw="$(readlink "$link")"
      resolved=""
      if [ "$raw" = "$REPO_DIR" ]; then
        emit PASS "$link" "指向本仓库"
      else
        # 兜底：相对链接或 macOS /tmp -> /private/tmp 等软链，用物理路径规范化比对
        if [ -d "$link" ]; then
          resolved="$(cd "$link" && pwd -P 2>/dev/null || true)"
        fi
        if [ -n "$resolved" ] && [ -n "$repo_phys" ] && [ "$resolved" = "$repo_phys" ]; then
          emit PASS "$link" "指向本仓库"
        else
          emit FAIL "$link" "指向 $raw"
          FAIL=$((FAIL+1))
        fi
      fi
    fi

    # 3) 目标根含 SKILL.md
    TOTAL=$((TOTAL+1))
    if [ -f "$link/SKILL.md" ]; then
      emit PASS "$link" "目标根含 SKILL.md"
    else
      emit FAIL "$link" "目标根缺少 SKILL.md"
      FAIL=$((FAIL+1))
    fi

    # 4) 目标根含 local_docs/
    TOTAL=$((TOTAL+1))
    if [ -d "$link/local_docs" ]; then
      emit PASS "$link" "目标根含 local_docs/"
    else
      emit FAIL "$link" "目标根缺少 local_docs/"
      FAIL=$((FAIL+1))
    fi
  }

  if [ "$DSH_TARGET" -eq 1 ]; then
    check_target "$DSH_SKILLS_DIR"
  fi
  if [ "$AGENTS_TARGET" -eq 1 ]; then
    check_target "$AGENTS_SKILLS_DIR"
  fi

  if [ "$FAIL" -eq 0 ]; then
    printf '[summary] 全部通过 %s/%s（退出码 0）\n' "$TOTAL" "$TOTAL"
    exit 0
  else
    local PASS
    PASS=$((TOTAL-FAIL))
    printf '[summary] 失败：通过 %s / 失败 %s（退出码 1）\n' "$PASS" "$FAIL"
    exit 1
  fi
}

if [ "$MODE" = "check" ]; then
  run_check
fi

if [ "$DSH_TARGET" -eq 1 ]; then
  ensure_link "$DSH_SKILLS_DIR"
fi
if [ "$AGENTS_TARGET" -eq 1 ]; then
  ensure_link "$AGENTS_SKILLS_DIR"
fi

if [ "$MODE" = "install" ]; then
  echo "完成。重开 dsh 会话后即可发现 skill：$NAME"
fi
