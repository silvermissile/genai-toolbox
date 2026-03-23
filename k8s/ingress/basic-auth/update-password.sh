#!/bin/bash
# 密码更新脚本
# 用于快速更新 BasicAuth 密码

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

NAMESPACE=${1:-mcp-toolbox}

echo ""
print_info "MCP Toolbox 密码更新工具"
echo "================================"
echo "命名空间: $NAMESPACE"
echo ""

# 检查 htpasswd
if ! command -v htpasswd &> /dev/null; then
    echo "错误: htpasswd 未安装"
    echo "Ubuntu/Debian: sudo apt-get install apache2-utils"
    exit 1
fi

# 获取当前用户列表
print_info "获取当前用户列表..."
if kubectl get secret toolbox-basic-auth -n $NAMESPACE &> /dev/null; then
    echo "当前用户:"
    kubectl get secret toolbox-basic-auth -n $NAMESPACE -o jsonpath='{.data.users}' | \
        base64 -d | cut -d: -f1 | sed 's/^/  - /'
    echo ""
else
    print_warn "未找到现有的认证 Secret"
fi

# 选择操作
echo "请选择操作:"
echo "  1) 更新现有用户密码"
echo "  2) 添加新用户"
echo "  3) 删除用户"
echo "  4) 重新生成所有用户"
echo ""
read -p "请选择 [1-4]: " CHOICE

case $CHOICE in
    1)
        # 更新密码
        read -p "请输入用户名: " USERNAME
        read -s -p "请输入新密码: " PASSWORD
        echo ""
        
        # 获取现有用户（除了要更新的）
        if kubectl get secret toolbox-basic-auth -n $NAMESPACE &> /dev/null; then
            kubectl get secret toolbox-basic-auth -n $NAMESPACE -o jsonpath='{.data.users}' | \
                base64 -d | grep -v "^$USERNAME:" > auth || true
        else
            touch auth
        fi
        
        # 添加新密码
        htpasswd -nbB "$USERNAME" "$PASSWORD" >> auth
        
        print_info "密码已更新"
        ;;
        
    2)
        # 添加新用户
        read -p "请输入新用户名: " USERNAME
        read -s -p "请输入密码: " PASSWORD
        echo ""
        
        # 获取现有用户
        if kubectl get secret toolbox-basic-auth -n $NAMESPACE &> /dev/null; then
            kubectl get secret toolbox-basic-auth -n $NAMESPACE -o jsonpath='{.data.users}' | \
                base64 -d > auth
        else
            touch auth
        fi
        
        # 添加新用户
        htpasswd -nbB "$USERNAME" "$PASSWORD" >> auth
        
        print_info "用户已添加"
        ;;
        
    3)
        # 删除用户
        read -p "请输入要删除的用户名: " USERNAME
        
        if ! kubectl get secret toolbox-basic-auth -n $NAMESPACE &> /dev/null; then
            print_warn "未找到认证 Secret"
            exit 1
        fi
        
        kubectl get secret toolbox-basic-auth -n $NAMESPACE -o jsonpath='{.data.users}' | \
            base64 -d | grep -v "^$USERNAME:" > auth
        
        print_info "用户已删除"
        ;;
        
    4)
        # 重新生成
        print_warn "将删除所有现有用户！"
        read -p "确认继续？(y/N): " CONFIRM
        if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
            exit 0
        fi
        
        # 清空文件
        > auth
        
        # 添加用户
        while true; do
            read -p "请输入用户名（留空结束）: " USERNAME
            if [ -z "$USERNAME" ]; then
                break
            fi
            
            read -s -p "请输入密码: " PASSWORD
            echo ""
            
            htpasswd -nbB "$USERNAME" "$PASSWORD" >> auth
            print_info "已添加用户: $USERNAME"
        done
        ;;
        
    *)
        echo "无效选择"
        exit 1
        ;;
esac

# 更新 Secret
print_info "更新 Kubernetes Secret..."

kubectl delete secret toolbox-basic-auth -n $NAMESPACE --ignore-not-found=true
kubectl create secret generic toolbox-basic-auth \
    --from-file=users=auth \
    --namespace=$NAMESPACE

# 清理本地文件
rm -f auth

echo ""
print_info "=========================================="
print_info "更新完成！"
print_info "=========================================="
echo ""
echo "新配置将在下次请求时生效（无需重启 Pod）"
echo ""
echo "测试命令:"
echo "  curl -u username:password -k https://your-domain/health"
echo ""
