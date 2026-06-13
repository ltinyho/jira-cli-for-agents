#!/usr/bin/env bash
#
# install.sh — 构建并安装 jira-cli (DC fork) 到指定目录
#
# 用法:
#   ./scripts/install.sh                          # 默认安装到 ~/.local/bin
#   ./scripts/install.sh --bin-dir /usr/local/bin
#   ./scripts/install.sh --bin-dir /opt/bin
#   ./scripts/install.sh --help
#
# 行为:
#   1. 检查 Go 工具链
#   2. 在脚本所在仓库根目录构建二进制
#   3. 复制到 --bin-dir (默认 ~/.local/bin)
#   4. 提示 PATH 配置（如果目标目录不在 PATH 中）

set -euo pipefail

# 颜色输出
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
    sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

# 默认值
BIN_DIR="${HOME}/.local/bin"
BIN_NAME="jira-cli"

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --bin-dir)
            BIN_DIR="$2"
            shift 2
            ;;
        --bin-name)
            BIN_NAME="$2"
            shift 2
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

# 定位仓库根目录（脚本在 .opencode/skills/jira-cli/scripts/install.sh）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

log_info "仓库根目录: $REPO_ROOT"
log_info "目标目录:   $BIN_DIR"
log_info "二进制名:   $BIN_NAME"

# 1. 检查 Go
if ! command -v go >/dev/null 2>&1; then
    log_error "未找到 go 命令，请先安装 Go 1.21+"
    exit 1
fi

GO_VERSION=$(go version | awk '{print $3}')
log_ok "检测到 Go $GO_VERSION"

# 2. 验证仓库结构
if [[ ! -f "$REPO_ROOT/go.mod" ]]; then
    log_error "在 $REPO_ROOT 未找到 go.mod，这不是 jira-cli 仓库"
    exit 1
fi

# 3. 确保目标目录存在
if [[ ! -d "$BIN_DIR" ]]; then
    log_info "目标目录不存在，创建: $BIN_DIR"
    mkdir -p "$BIN_DIR"
fi

# 4. 构建
VERSION="1.4.0-dc"
LDFLAGS="-X 'github.com/sanisideup/jira-cli/cmd.Version=$VERSION'"

log_info "开始构建..."
cd "$REPO_ROOT"
go build -o "$BIN_DIR/$BIN_NAME" -ldflags="$LDFLAGS"

# 5. 验证
if [[ ! -x "$BIN_DIR/$BIN_NAME" ]]; then
    log_error "构建后未找到可执行文件: $BIN_DIR/$BIN_NAME"
    exit 1
fi

INSTALLED_VERSION=$("$BIN_DIR/$BIN_NAME" version 2>&1 | head -1 || echo "unknown")
log_ok "安装成功: $INSTALLED_VERSION"

# 6. PATH 检查
if ! command -v "$BIN_NAME" >/dev/null 2>&1; then
    log_warn "$BIN_DIR 不在 PATH 中"
    echo
    echo "  临时生效:"
    echo "    export PATH=\"$BIN_DIR:\$PATH\""
    echo
    echo "  永久生效 (zsh):"
    echo "    echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
    echo
    echo "  永久生效 (bash):"
    echo "    echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
fi

# 7. 配置提示
if [[ ! -f "$HOME/.jira-cli/config.yaml" ]]; then
    log_warn "未找到配置文件: ~/.jira-cli/config.yaml"
    echo
    echo "  请参考 SKILL.md 中的'配置'章节创建配置文件"
    echo "  最小化配置示例:"
    cat <<'EOF'

    domain: jira.westwell-lab.com
    email: zihao.liu
    auth_type: bearer
    api_token: "<YOUR_PAT_TOKEN>"
    default_project: IN
    field_mappings: {}

EOF
fi

log_ok "完成"
