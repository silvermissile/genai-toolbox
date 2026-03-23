#!/bin/bash
# 清理脚本
# 用于完全删除 MCP Toolbox 部署

set -e

RED='\033[0;31m'
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
print_warn "=========================================="
print_warn "警告：即将删除所有 Toolbox 资源"
print_warn "=========================================="
echo ""
echo "命名空间: $NAMESPACE"
echo ""
echo "将删除:"
echo "  - Namespace: $NAMESPACE"
echo "  - 所有 Deployments"
echo "  - 所有 Services"
echo "  - 所有 Ingresses"
echo "  - 所有 Middlewares"
echo "  - 所有 Secrets 和 ConfigMaps"
echo ""

read -p "确认删除？输入 'yes' 继续: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    print_info "已取消删除"
    exit 0
fi

echo ""
print_info "开始清理..."

# 删除 Ingress
print_info "删除 Ingress..."
kubectl delete ingress --all -n $NAMESPACE --ignore-not-found=true

# 删除 Middleware
print_info "删除 Middleware..."
kubectl delete middleware --all -n $NAMESPACE --ignore-not-found=true

# 删除 Service
print_info "删除 Service..."
kubectl delete service --all -n $NAMESPACE --ignore-not-found=true

# 删除 Deployment
print_info "删除 Deployment..."
kubectl delete deployment --all -n $NAMESPACE --ignore-not-found=true

# 删除 ConfigMap
print_info "删除 ConfigMap..."
kubectl delete configmap --all -n $NAMESPACE --ignore-not-found=true

# 删除 Secret
print_info "删除 Secret..."
kubectl delete secret --all -n $NAMESPACE --ignore-not-found=true

# 删除 NetworkPolicy（如果有）
print_info "删除 NetworkPolicy..."
kubectl delete networkpolicy --all -n $NAMESPACE --ignore-not-found=true

# 最后删除命名空间
print_info "删除 Namespace..."
kubectl delete namespace $NAMESPACE --ignore-not-found=true

echo ""
print_info "清理完成 ✓"
echo ""
print_info "验证删除:"
echo "  kubectl get namespace $NAMESPACE"
echo "  (应该显示: NotFound)"
echo ""
