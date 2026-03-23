#!/bin/bash
# MCP Toolbox 完整部署脚本
# 用于一键部署所有必要的 Kubernetes 资源

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K8S_DIR="$(dirname "$SCRIPT_DIR")"

echo ""
print_info "=========================================="
print_info "MCP Toolbox 完整部署向导"
print_info "=========================================="
echo ""

# 步骤 1: 检查依赖
print_info "步骤 1/6: 检查依赖"
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl 未安装"
    exit 1
fi
print_info "依赖检查通过 ✓"
echo ""

# 步骤 2: 创建命名空间
print_info "步骤 2/6: 创建命名空间"
kubectl apply -f "$K8S_DIR/base/namespace.yaml"
echo ""

# 步骤 3: 配置 Secret
print_info "步骤 3/6: 配置 Secret"
echo ""
if [ ! -f "$K8S_DIR/base/secret.yaml" ]; then
    print_warn "未找到 secret.yaml 文件"
    echo "请执行以下步骤:"
    echo "  1. cd $K8S_DIR/base/"
    echo "  2. cp secret.yaml.example secret.yaml"
    echo "  3. 编辑 secret.yaml，填入实际的数据库凭据"
    echo "  4. kubectl apply -f secret.yaml"
    echo ""
    read -p "是否已完成 Secret 配置？(y/N): " SECRET_READY
    if [[ ! $SECRET_READY =~ ^[Yy]$ ]]; then
        print_warn "请先配置 Secret 后重新运行此脚本"
        exit 0
    fi
else
    kubectl apply -f "$K8S_DIR/base/secret.yaml"
fi
echo ""

# 步骤 4: 部署 Toolbox
print_info "步骤 4/6: 部署 Toolbox"
kubectl apply -f "$K8S_DIR/base/configmap.yaml"
kubectl apply -f "$K8S_DIR/base/deployment.yaml"
kubectl apply -f "$K8S_DIR/base/service.yaml"

print_info "等待 Pod 启动..."
kubectl wait --for=condition=Ready pod -l app=toolbox -n mcp-toolbox --timeout=120s

print_info "Toolbox 部署成功 ✓"
echo ""

# 步骤 5: 配置认证
print_info "步骤 5/6: 配置认证"
echo ""
echo "请选择认证方案:"
echo "  1) Traefik BasicAuth (推荐个人使用)"
echo "  2) NetworkPolicy (仅集群内访问)"
echo "  3) 跳过认证配置"
echo ""
read -p "请选择 [1-3]: " AUTH_CHOICE

case $AUTH_CHOICE in
    1)
        print_info "配置 BasicAuth..."
        cd "$K8S_DIR/ingress/basic-auth/"
        ./deploy-basic-auth.sh
        ;;
    2)
        print_info "配置 NetworkPolicy..."
        kubectl apply -f "$K8S_DIR/ingress/network-policy/network-policy.yaml"
        print_info "NetworkPolicy 已应用 ✓"
        ;;
    3)
        print_warn "跳过认证配置"
        print_warn "警告：你的 Toolbox 将无认证保护！"
        ;;
    *)
        print_warn "无效选择，跳过认证配置"
        ;;
esac
echo ""

# 步骤 6: 显示部署信息
print_info "步骤 6/6: 部署完成"
echo ""
print_info "=========================================="
print_info "部署成功！"
print_info "=========================================="
echo ""

print_info "查看部署状态:"
echo "  kubectl get all -n mcp-toolbox"
echo ""

print_info "查看 Pod 日志:"
echo "  kubectl logs -l app=toolbox -n mcp-toolbox -f"
echo ""

print_info "测试服务（集群内）:"
echo "  kubectl run test-pod --rm -it --image=curlimages/curl -n mcp-toolbox -- \\"
echo "    curl http://toolbox:5000/health"
echo ""

if [ "$AUTH_CHOICE" == "1" ]; then
    print_info "通过浏览器访问:"
    echo "  https://$DOMAIN"
    echo "  (使用配置的用户名密码登录)"
fi

echo ""
print_info "完整文档请参考: $K8S_DIR/README.md"
echo ""
