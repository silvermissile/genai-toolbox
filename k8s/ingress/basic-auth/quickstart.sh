#!/bin/bash
# 快速部署脚本（最小化步骤）
# 适用于已有 Toolbox 部署的情况

set -e

echo "MCP Toolbox BasicAuth 快速配置"
echo "================================"
echo ""

# 检查 htpasswd
if ! command -v htpasswd &> /dev/null; then
    echo "错误: htpasswd 未安装"
    echo "Ubuntu/Debian: sudo apt-get install apache2-utils"
    exit 1
fi

# 获取输入
read -p "用户名 [admin]: " USERNAME
USERNAME=${USERNAME:-admin}

read -s -p "密码: " PASSWORD
echo ""

read -p "命名空间 [mcp-toolbox]: " NAMESPACE
NAMESPACE=${NAMESPACE:-mcp-toolbox}

# 生成并创建
echo "正在配置..."
htpasswd -nbB "$USERNAME" "$PASSWORD" | \
  kubectl create secret generic toolbox-basic-auth \
  --from-file=/dev/stdin \
  --dry-run=client -o yaml | \
  kubectl apply -n $NAMESPACE -f -

# 应用 Middleware
kubectl apply -f middleware.yaml

# 更新 Ingress
kubectl patch ingress toolbox-ingress -n $NAMESPACE -p \
  '{"metadata":{"annotations":{"traefik.ingress.kubernetes.io/router.middlewares":"'$NAMESPACE'-toolbox-basic-auth@kubernetescrd"}}}'

echo ""
echo "✓ 配置完成！"
echo ""
echo "测试: curl -u $USERNAME:YOUR_PASSWORD https://your-domain/health"
