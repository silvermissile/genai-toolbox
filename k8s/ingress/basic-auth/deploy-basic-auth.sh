#!/bin/bash
# Traefik BasicAuth 自动化部署脚本
# 用于快速配置 MCP Toolbox 的 BasicAuth 认证

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 辅助函数
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查依赖
check_dependencies() {
    print_info "检查依赖工具..."
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl 未安装，请先安装 kubectl"
        exit 1
    fi
    
    if ! command -v htpasswd &> /dev/null; then
        print_error "htpasswd 未安装"
        echo "请安装 apache2-utils:"
        echo "  Ubuntu/Debian: sudo apt-get install apache2-utils"
        echo "  CentOS/RHEL:   sudo yum install httpd-tools"
        echo "  macOS:         brew install httpd"
        exit 1
    fi
    
    print_info "依赖检查通过 ✓"
}

# 检查 K8s 集群连接
check_cluster() {
    print_info "检查 Kubernetes 集群连接..."
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "无法连接到 Kubernetes 集群"
        echo "请确保 kubectl 已正确配置"
        exit 1
    fi
    
    print_info "集群连接正常 ✓"
}

# 获取用户输入
get_user_input() {
    print_info "配置认证信息"
    echo ""
    
    # 命名空间
    read -p "请输入命名空间 [mcp-toolbox]: " NAMESPACE
    NAMESPACE=${NAMESPACE:-mcp-toolbox}
    
    # 用户名
    read -p "请输入用户名 [admin]: " USERNAME
    USERNAME=${USERNAME:-admin}
    
    # 密码（隐藏输入）
    while true; do
        read -s -p "请输入密码（至少 12 位）: " PASSWORD
        echo ""
        read -s -p "请再次输入密码: " PASSWORD_CONFIRM
        echo ""
        
        if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
            print_error "两次密码输入不一致，请重试"
            continue
        fi
        
        if [ ${#PASSWORD} -lt 12 ]; then
            print_error "密码长度不足 12 位，请使用更强的密码"
            continue
        fi
        
        break
    done
    
    # 域名
    read -p "请输入域名（如 toolbox.example.com）: " DOMAIN
    if [ -z "$DOMAIN" ]; then
        print_error "域名不能为空"
        exit 1
    fi
    
    # 确认信息
    echo ""
    print_info "配置信息确认:"
    echo "  命名空间: $NAMESPACE"
    echo "  用户名:   $USERNAME"
    echo "  密码:     ******** (已隐藏)"
    echo "  域名:     $DOMAIN"
    echo ""
    
    read -p "确认以上信息正确？(y/N): " CONFIRM
    if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
        print_warn "已取消部署"
        exit 0
    fi
}

# 创建命名空间
create_namespace() {
    print_info "创建命名空间 $NAMESPACE..."
    
    if kubectl get namespace $NAMESPACE &> /dev/null; then
        print_warn "命名空间 $NAMESPACE 已存在，跳过创建"
    else
        kubectl create namespace $NAMESPACE
        print_info "命名空间创建成功 ✓"
    fi
}

# 生成认证文件
generate_auth_file() {
    print_info "生成认证凭据..."
    
    # 生成 htpasswd 文件
    htpasswd -nbB "$USERNAME" "$PASSWORD" > auth
    
    if [ ! -f auth ]; then
        print_error "认证文件生成失败"
        exit 1
    fi
    
    print_info "认证凭据生成成功 ✓"
}

# 创建 Secret
create_secret() {
    print_info "创建 Kubernetes Secret..."
    
    # 删除旧的 Secret（如果存在）
    if kubectl get secret toolbox-basic-auth -n $NAMESPACE &> /dev/null; then
        print_warn "删除旧的 Secret..."
        kubectl delete secret toolbox-basic-auth -n $NAMESPACE
    fi
    
    # 创建新 Secret
    kubectl create secret generic toolbox-basic-auth \
        --from-file=users=auth \
        --namespace=$NAMESPACE
    
    print_info "Secret 创建成功 ✓"
    
    # 清理本地认证文件（安全考虑）
    rm -f auth
    print_info "已清理本地认证文件"
}

# 部署 Middleware
deploy_middleware() {
    print_info "部署 Traefik Middleware..."
    
    kubectl apply -f middleware.yaml
    
    # 等待 Middleware 创建完成
    sleep 2
    
    if kubectl get middleware toolbox-basic-auth -n $NAMESPACE &> /dev/null; then
        print_info "Middleware 部署成功 ✓"
    else
        print_error "Middleware 部署失败"
        exit 1
    fi
}

# 部署/更新 Ingress
deploy_ingress() {
    print_info "配置 Ingress..."
    
    # 创建临时 Ingress 文件（替换域名）
    cat ingress.yaml | sed "s/toolbox.example.com/$DOMAIN/g" > ingress-temp.yaml
    
    kubectl apply -f ingress-temp.yaml
    
    # 清理临时文件
    rm -f ingress-temp.yaml
    
    print_info "Ingress 配置成功 ✓"
}

# 验证部署
verify_deployment() {
    print_info "验证部署..."
    echo ""
    
    # 检查 Secret
    if kubectl get secret toolbox-basic-auth -n $NAMESPACE &> /dev/null; then
        echo "  ✓ Secret 已创建"
    else
        echo "  ✗ Secret 未找到"
        return 1
    fi
    
    # 检查 Middleware
    if kubectl get middleware toolbox-basic-auth -n $NAMESPACE &> /dev/null; then
        echo "  ✓ Middleware 已创建"
    else
        echo "  ✗ Middleware 未找到"
        return 1
    fi
    
    # 检查 Ingress
    if kubectl get ingress toolbox-ingress -n $NAMESPACE &> /dev/null; then
        echo "  ✓ Ingress 已创建"
    else
        echo "  ✗ Ingress 未找到"
        return 1
    fi
    
    echo ""
    print_info "所有资源部署成功 ✓"
}

# 显示测试命令
show_test_commands() {
    echo ""
    print_info "=========================================="
    print_info "部署完成！"
    print_info "=========================================="
    echo ""
    echo "访问地址: https://$DOMAIN"
    echo "用户名:   $USERNAME"
    echo "密码:     ******** (请查看终端输出或记录)"
    echo ""
    print_info "测试命令:"
    echo ""
    echo "1. 测试认证（应该返回 401）:"
    echo "   curl -k https://$DOMAIN/health"
    echo ""
    echo "2. 使用认证访问（应该成功）:"
    echo "   curl -k -u $USERNAME:YOUR_PASSWORD https://$DOMAIN/health"
    echo ""
    echo "3. 在浏览器中访问:"
    echo "   https://$DOMAIN"
    echo "   (会自动弹出登录框)"
    echo ""
    print_info "查看资源状态:"
    echo "   kubectl get all,middleware,ingress -n $NAMESPACE"
    echo ""
    print_info "查看 Traefik 日志:"
    echo "   kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50"
    echo ""
}

# 主函数
main() {
    echo ""
    print_info "=========================================="
    print_info "MCP Toolbox BasicAuth 部署脚本"
    print_info "=========================================="
    echo ""
    
    # 执行部署步骤
    check_dependencies
    check_cluster
    get_user_input
    create_namespace
    generate_auth_file
    create_secret
    deploy_middleware
    deploy_ingress
    verify_deployment
    show_test_commands
    
    echo ""
    print_info "部署完成！请保存好你的登录凭据。"
    echo ""
}

# 执行主函数
main
