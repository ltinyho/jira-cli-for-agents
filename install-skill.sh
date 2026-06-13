#!/usr/bin/env bash
#
# install-skill.sh — 把 jira-cli skill 安装到 OpenCode / Claude Code 的 skills 目录
#
# 用法:
#   # 一行命令（从 GitHub 自动 clone + 安装）
#   curl -fsSL https://raw.githubusercontent.com/ltinyho/jira-cli-for-agents/main/install-skill.sh | bash
#
#   # 或者本地仓库内
#   ./install-skill.sh
#
#   # 自定义目标目录
#   ./install-skill.sh --skills-dir ~/.config/opencode/skills
#
#   # 软链接模式（fork 更新后自动生效）
#   ./install-skill.sh --link
#
#   # 卸载
#   ./install-skill.sh --uninstall
#
# 支持的目标位置（默认按顺序探测，--skills-dir 强制指定）:
#   1. $XDG_CONFIG_HOME/opencode/skills     (OpenCode 官方)
#   2. ~/.config/opencode/skills             (Linux/macOS 默认)
#   3. ~/.agents/skills                      (通用)
#   4. ./.opencode/skills                    (项目内)

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}ℹ${NC}  $*"; }
log_ok()    { echo -e "${GREEN}✓${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}⚠${NC}  $*"; }
log_error() { echo -e "${RED}✗${NC}  $*" >&2; }

usage() {
    sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

# 默认参数
SKILL_NAME="jira-cli"
SKILLS_DIR=""
USE_LINK=0
DO_UNINSTALL=0
REPO_URL="git@github.com:ltinyho/jira-cli-for-agents.git"
TEMP_DIR=""

cleanup() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}
trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skills-dir)
            SKILLS_DIR="$2"
            shift 2
            ;;
        --link)
            USE_LINK=1
            shift
            ;;
        --uninstall)
            DO_UNINSTALL=1
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "未知参数: $1"
            usage
            ;;
    esac
done

# 探测默认 skills 目录
detect_skills_dir() {
    local candidates=(
        "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills"
        "$HOME/.agents/skills"
    )
    for dir in "${candidates[@]}"; do
        if [[ -d "$dir" ]]; then
            echo "$dir"
            return
        fi
    done
    # 都不存在，返回第一个（自动创建）
    echo "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills"
}

# 定位 skill 源
locate_skill_source() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # 1. 脚本所在目录就是 skill 源（本地仓库场景）
    if [[ -f "$script_dir/.opencode/skills/$SKILL_NAME/SKILL.md" ]]; then
        echo "$script_dir/.opencode/skills/$SKILL_NAME"
        return
    fi
    if [[ -f "$script_dir/SKILL.md" && "$(basename "$script_dir")" == "$SKILL_NAME" ]]; then
        echo "$script_dir"
        return
    fi

    # 2. 当前工作目录是仓库根
    if [[ -f "./.opencode/skills/$SKILL_NAME/SKILL.md" ]]; then
        echo "./.opencode/skills/$SKILL_NAME"
        return
    fi

    # 3. 从 GitHub clone
    log_info "本地未找到 skill 源，从 GitHub clone..."
    TEMP_DIR=$(mktemp -d)
    if command -v git >/dev/null 2>&1; then
        git clone --depth 1 "$REPO_URL" "$TEMP_DIR/repo" 2>/dev/null || {
            log_error "git clone 失败，请检查网络或 SSH key"
            exit 1
        }
        echo "$TEMP_DIR/repo/.opencode/skills/$SKILL_NAME"
        return
    fi

    log_error "未找到 skill 源，且无法从 GitHub clone"
    exit 1
}

# 卸载
if [[ $DO_UNINSTALL -eq 1 ]]; then
    if [[ -z "$SKILLS_DIR" ]]; then
        SKILLS_DIR=$(detect_skills_dir)
    fi
    target="$SKILLS_DIR/$SKILL_NAME"
    if [[ -L "$target" ]]; then
        rm "$target"
        log_ok "已删除 symlink: $target"
    elif [[ -d "$target" ]]; then
        rm -rf "$target"
        log_ok "已删除目录: $target"
    else
        log_warn "未找到: $target"
    fi
    exit 0
fi

# 安装
if [[ -z "$SKILLS_DIR" ]]; then
    SKILLS_DIR=$(detect_skills_dir)
    log_info "自动选择 skills 目录: $SKILLS_DIR"
fi

# 确保目标目录存在
if [[ ! -d "$SKILLS_DIR" ]]; then
    log_info "目标不存在，创建: $SKILLS_DIR"
    mkdir -p "$SKILLS_DIR"
fi

# 定位源
SOURCE=$(locate_skill_source)
log_info "skill 源: $SOURCE"
log_info "目标:     $SKILLS_DIR/$SKILL_NAME"

TARGET="$SKILLS_DIR/$SKILL_NAME"

# 检查目标是否已存在
if [[ -e "$TARGET" ]]; then
    log_warn "目标已存在: $TARGET"
    if [[ -L "$TARGET" ]]; then
        log_info "移除旧 symlink"
        rm "$TARGET"
    else
        read -p "  覆盖? [y/N] " ans
        if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
            log_info "已取消"
            exit 0
        fi
        rm -rf "$TARGET"
    fi
fi

# 安装
if [[ $USE_LINK -eq 1 ]]; then
    ln -s "$SOURCE" "$TARGET"
    log_ok "已创建 symlink: $TARGET -> $SOURCE"
    log_info "  fork 更新后会自动生效"
else
    cp -r "$SOURCE" "$TARGET"
    log_ok "已复制到: $TARGET"
    log_info "  后续需要重新运行本脚本以更新"
fi

# 显示验证
echo
log_ok "安装完成！skill 路径: $TARGET"
echo
echo "  验证："
echo "    ls -la $TARGET"
echo "    cat $TARGET/SKILL.md | head -20"
echo
echo "  在 OpenCode / Claude Code 中，触发方式："
echo "    \"帮我看看 jira 里有啥\""
echo "    \"查一下 IN 项目的任务\""
