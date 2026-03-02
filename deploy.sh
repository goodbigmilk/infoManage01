#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  infoManage 一键部署脚本
#  支持 macOS / Linux，自动检测并安装 Docker
# ============================================================

APP_NAME="infoManage"
APP_PORT="${APP_PORT:-9901}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-rootmysql}"
MYSQL_DATABASE="${MYSQL_DATABASE:-infoManage}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[信息]${NC} $*"; }
success() { echo -e "${GREEN}[成功]${NC} $*"; }
warn()    { echo -e "${YELLOW}[警告]${NC} $*"; }
error()   { echo -e "${RED}[错误]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# -------------------- 系统检测 --------------------
detect_os() {
    case "$(uname -s)" in
        Linux*)  OS="linux" ;;
        Darwin*) OS="macos" ;;
        *)       error "不支持的操作系统: $(uname -s)，仅支持 Linux 和 macOS" ;;
    esac
    info "检测到操作系统: $OS"
}

detect_arch() {
    case "$(uname -m)" in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *)             error "不支持的架构: $(uname -m)" ;;
    esac
    info "检测到系统架构: $ARCH"
}

# -------------------- Docker 安装 --------------------
check_docker() {
    if command -v docker &>/dev/null; then
        DOCKER_VERSION=$(docker --version 2>/dev/null || true)
        success "Docker 已安装: $DOCKER_VERSION"
        return 0
    fi
    return 1
}

check_docker_compose() {
    if docker compose version &>/dev/null 2>&1; then
        success "Docker Compose (V2 插件) 可用"
        COMPOSE_CMD="docker compose"
        return 0
    elif command -v docker-compose &>/dev/null; then
        success "Docker Compose (独立版) 可用"
        COMPOSE_CMD="docker-compose"
        return 0
    fi
    return 1
}

install_docker_linux() {
    info "正在安装 Docker..."

    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y -qq ca-certificates curl gnupg lsb-release

        DISTRO=$(lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "ubuntu")
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL "https://download.docker.com/linux/${DISTRO}/gpg" | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${DISTRO} $(lsb_release -cs) stable" | \
            sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

        sudo apt-get update -qq
        sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin

    elif command -v yum &>/dev/null; then
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    elif command -v dnf &>/dev/null; then
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

    else
        warn "无法识别包管理器，尝试使用官方安装脚本..."
        curl -fsSL https://get.docker.com | sudo sh
    fi

    sudo systemctl enable docker
    sudo systemctl start docker

    if ! groups "$USER" | grep -q docker; then
        sudo usermod -aG docker "$USER"
        warn "已将当前用户加入 docker 组，如遇到权限问题请重新登录或运行: newgrp docker"
    fi

    success "Docker 安装完成"
}

install_docker_macos() {
    if command -v brew &>/dev/null; then
        info "通过 Homebrew 安装 Docker Desktop..."
        brew install --cask docker
        info "请手动启动 Docker Desktop 应用，等待其完全启动后重新运行此脚本"
        open -a Docker 2>/dev/null || true
        exit 0
    else
        echo ""
        error "请先安装 Docker Desktop for Mac:
    1. 访问 https://www.docker.com/products/docker-desktop/
    2. 下载并安装 Docker Desktop
    3. 启动 Docker Desktop
    4. 重新运行此脚本"
    fi
}

ensure_docker() {
    if ! check_docker; then
        warn "Docker 未安装，即将自动安装..."
        echo ""
        case "$OS" in
            linux) install_docker_linux ;;
            macos) install_docker_macos ;;
        esac

        check_docker || error "Docker 安装失败，请手动安装后重试"
    fi

    if ! docker info &>/dev/null 2>&1; then
        if [ "$OS" = "linux" ]; then
            sudo systemctl start docker 2>/dev/null || true
            sleep 2
        fi
        docker info &>/dev/null 2>&1 || error "Docker 未运行，请先启动 Docker 服务"
    fi

    if ! check_docker_compose; then
        error "Docker Compose 不可用，请安装 Docker Compose 插件"
    fi
}

# -------------------- 部署操作 --------------------
check_port() {
    local port=$1
    if command -v lsof &>/dev/null; then
        if lsof -i ":$port" &>/dev/null; then
            return 1
        fi
    elif command -v ss &>/dev/null; then
        if ss -tlnp | grep -q ":$port "; then
            return 1
        fi
    fi
    return 0
}

deploy() {
    info "检查端口占用..."
    if ! check_port "$APP_PORT"; then
        warn "端口 $APP_PORT 已被占用"
        read -rp "是否使用其他端口？(输入新端口号或按回车跳过): " new_port
        if [ -n "$new_port" ]; then
            APP_PORT="$new_port"
        fi
    fi
    if ! check_port "$MYSQL_PORT"; then
        warn "MySQL 端口 $MYSQL_PORT 已被占用，将不映射到宿主机"
        MYSQL_PORT="0"
    fi

    info "生成环境配置..."
    cat > .env <<EOF
APP_PORT=${APP_PORT}
MYSQL_PORT=${MYSQL_PORT}
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_DATABASE=${MYSQL_DATABASE}
EOF
    success "配置文件 .env 已生成"

    info "构建并启动服务..."
    $COMPOSE_CMD up -d --build

    info "等待服务启动..."
    local retries=0
    local max_retries=60
    while [ $retries -lt $max_retries ]; do
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:${APP_PORT}/" 2>/dev/null | grep -q "200"; then
            break
        fi
        retries=$((retries + 1))
        sleep 2
    done

    if [ $retries -ge $max_retries ]; then
        warn "服务启动超时，请检查日志: $COMPOSE_CMD logs"
    else
        echo ""
        success "========================================="
        success "  ${APP_NAME} 部署成功！"
        success "========================================="
        echo ""
        info "访问地址:  http://localhost:${APP_PORT}"
        info "MySQL 端口: ${MYSQL_PORT}"
        echo ""
        info "常用命令:"
        echo "  查看日志:     $COMPOSE_CMD logs -f"
        echo "  停止服务:     $COMPOSE_CMD down"
        echo "  重启服务:     $COMPOSE_CMD restart"
        echo "  查看状态:     $COMPOSE_CMD ps"
        echo "  清除数据重建: $COMPOSE_CMD down -v && $COMPOSE_CMD up -d --build"
        echo ""
    fi
}

stop() {
    info "停止服务..."
    $COMPOSE_CMD down
    success "服务已停止"
}

restart() {
    info "重启服务..."
    $COMPOSE_CMD restart
    success "服务已重启"
}

status() {
    $COMPOSE_CMD ps
}

logs() {
    $COMPOSE_CMD logs -f --tail=100
}

clean() {
    warn "即将删除所有容器和数据卷（数据库数据将丢失）！"
    read -rp "确认删除？(y/N): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        $COMPOSE_CMD down -v --remove-orphans
        docker rmi "${APP_NAME}-app" 2>/dev/null || true
        rm -f .env
        success "清理完成"
    else
        info "已取消"
    fi
}

show_help() {
    echo ""
    echo "用法: $0 [命令]"
    echo ""
    echo "命令:"
    echo "  deploy    部署/更新服务（默认）"
    echo "  stop      停止服务"
    echo "  restart   重启服务"
    echo "  status    查看服务状态"
    echo "  logs      查看服务日志"
    echo "  clean     清除所有容器和数据"
    echo "  help      显示帮助信息"
    echo ""
    echo "环境变量:"
    echo "  APP_PORT              应用端口（默认: 9901）"
    echo "  MYSQL_PORT            MySQL 端口（默认: 3306）"
    echo "  MYSQL_ROOT_PASSWORD   MySQL root 密码（默认: rootmysql）"
    echo "  MYSQL_DATABASE        数据库名称（默认: infoManage）"
    echo ""
    echo "示例:"
    echo "  ./deploy.sh                          # 一键部署"
    echo "  APP_PORT=8080 ./deploy.sh deploy     # 指定端口部署"
    echo "  ./deploy.sh logs                     # 查看日志"
    echo "  ./deploy.sh clean                    # 清除所有数据"
    echo ""
}

# -------------------- 主入口 --------------------
main() {
    echo ""
    echo "============================================"
    echo "    ${APP_NAME} 一键部署工具"
    echo "============================================"
    echo ""

    detect_os
    detect_arch
    ensure_docker

    local cmd="${1:-deploy}"
    case "$cmd" in
        deploy)  deploy ;;
        stop)    stop ;;
        restart) restart ;;
        status)  status ;;
        logs)    logs ;;
        clean)   clean ;;
        help|-h|--help) show_help ;;
        *)       error "未知命令: $cmd（使用 help 查看帮助）" ;;
    esac
}

main "$@"
