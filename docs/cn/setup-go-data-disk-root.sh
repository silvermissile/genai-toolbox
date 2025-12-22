#!/bin/bash
# Go 开发环境配置脚本 - Root 用户版本
# 适用于 Ubuntu 24.04 LTS
# 用途：为 root 用户将 Go 工作目录配置到 /data 数据盘
# 警告：不推荐以 root 用户进行日常开发

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then 
    print_error "此脚本需要 root 权限运行"
    echo "请使用: sudo bash $0 或以 root 用户运行"
    exit 1
fi

echo "=========================================="
echo "  Go 开发环境配置 - Root 用户版本"
echo "=========================================="
echo ""
print_warning "检测到您正在使用 root 用户"
print_warning "出于安全考虑，不推荐使用 root 进行日常开发"
echo ""
echo "建议："
echo "1. 创建普通用户进行开发"
echo "2. 使用普通用户版本的配置脚本"
echo ""
read -p "是否继续使用 root 配置？(y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "已取消配置"
    echo ""
    echo "创建普通用户的方法："
    echo "  bash /tmp/create_dev_user.sh"
    exit 0
fi

# 1. 检查 /data 目录是否存在
print_info "检查 /data 目录..."
if [ ! -d "/data" ]; then
    print_error "/data 目录不存在！"
    echo "请先挂载数据盘到 /data 或选择其他目录"
    exit 1
fi
print_success "/data 目录存在"

# 2. 检查 /data 磁盘空间
print_info "检查 /data 磁盘空间..."
available_space=$(df -BG /data | tail -1 | awk '{print $4}' | sed 's/G//')
if [ "$available_space" -lt 5 ]; then
    print_warning "/data 可用空间仅有 ${available_space}GB，建议至少 5GB"
    read -p "是否继续？(y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    print_success "/data 可用空间: ${available_space}GB"
fi

# 3. 创建 Go 目录结构
print_info "创建 Go 目录结构..."
mkdir -p /data/go/{bin,pkg,src,cache}
chmod 755 /data/go
print_success "目录创建完成: /data/go"

# 4. 配置文件路径
shell_rc="/root/.bashrc"
print_info "使用配置文件: $shell_rc"

# 5. 备份原配置文件
if [ -f "$shell_rc" ]; then
    backup_file="${shell_rc}.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$shell_rc" "$backup_file"
    print_success "已备份配置文件到: $backup_file"
fi

# 6. 检查是否已存在 Go 配置
if grep -q "export GOPATH" "$shell_rc" 2>/dev/null; then
    print_warning "检测到已有 Go 配置"
    echo "现有配置："
    grep "GOPATH\|GOMODCACHE\|GOCACHE" "$shell_rc" || true
    echo ""
    read -p "是否覆盖现有配置？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 删除旧的 Go 配置
        sed -i '/# Go 环境配置/,+10d' "$shell_rc"
        print_info "已删除旧配置"
    else
        print_info "保持现有配置不变"
        exit 0
    fi
fi

# 7. 添加新配置
print_info "添加 Go 环境配置..."
cat >> "$shell_rc" << 'EOF'

# Go 环境配置（数据盘方案 - Root 用户）
# 由 setup-go-data-disk-root.sh 自动添加
export PATH=$PATH:/usr/local/go/bin
export GOPATH=/data/go
export GOMODCACHE=/data/go/pkg/mod
export GOCACHE=/data/go/cache
export PATH=$PATH:$GOPATH/bin

# Go 模块代理（加速中国大陆下载）
export GOPROXY=https://goproxy.cn,direct
EOF

print_success "配置已添加到 $shell_rc"

# 8. 迁移已有的 Go 缓存（如果存在）
if [ -d "/root/go" ] && [ "/root/go" != "/data/go" ]; then
    print_warning "检测到已有 Go 目录: /root/go"
    old_size=$(du -sh "/root/go" 2>/dev/null | cut -f1)
    echo "目录大小: $old_size"
    read -p "是否迁移到 /data/go？(y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "迁移中，请稍候..."
        # 使用 rsync 保留权限迁移
        if command -v rsync &> /dev/null; then
            rsync -av "/root/go/" /data/go/
        else
            cp -r "/root/go/"* /data/go/ 2>/dev/null || true
        fi
        print_success "迁移完成"
        
        read -p "是否删除旧目录 /root/go？(y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "/root/go"
            print_success "已删除旧目录"
        else
            print_info "保留旧目录，建议手动删除: rm -rf /root/go"
        fi
    fi
fi

# 9. 完成提示
echo ""
echo "=========================================="
print_success "配置完成！"
echo "=========================================="
echo ""
print_warning "重要安全提示："
echo "  - root 用户拥有系统最高权限"
echo "  - 建议仅用 root 进行系统配置"
echo "  - 日常开发应使用普通用户"
echo ""
echo "下一步操作："
echo ""
echo "1. 使配置生效："
echo "   ${YELLOW}source $shell_rc${NC}"
echo ""
echo "2. 验证配置："
echo "   ${YELLOW}go env GOPATH GOMODCACHE GOCACHE${NC}"
echo ""
echo "3. 查看目录："
echo "   ${YELLOW}ls -la /data/go${NC}"
echo ""
echo "4. 进入项目目录执行："
echo "   ${YELLOW}cd /data/github/genai-toolbox${NC}"
echo "   ${YELLOW}go mod download${NC}"
echo ""
print_info "配置文件备份位置: $backup_file"
echo ""

# 10. 询问是否立即生效
read -p "是否立即在当前 shell 中生效配置？(Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    # shellcheck source=/dev/null
    source "$shell_rc"
    print_success "配置已在当前 shell 中生效"
    
    # 显示当前配置
    if command -v go &> /dev/null; then
        echo ""
        echo "当前 Go 环境："
        echo "  GOPATH:     $(go env GOPATH)"
        echo "  GOMODCACHE: $(go env GOMODCACHE)"
        echo "  GOCACHE:    $(go env GOCACHE)"
    fi
fi

echo ""
print_success "所有步骤完成！"
echo ""
print_warning "再次提醒：建议创建普通用户进行开发"
echo "创建普通用户："
echo "  ${YELLOW}bash /tmp/create_dev_user.sh${NC}"

