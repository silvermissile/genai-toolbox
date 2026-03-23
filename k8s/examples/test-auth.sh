#!/bin/bash
# 测试 BasicAuth 认证的脚本
# 用于验证部署是否正常工作

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 从环境变量或参数获取配置
URL=${TOOLBOX_URL:-$1}
USER=${TOOLBOX_USER:-admin}
PASS=${TOOLBOX_PASSWORD:-$2}

if [ -z "$URL" ] || [ -z "$PASS" ]; then
    echo "用法: $0 <URL> <PASSWORD>"
    echo "或设置环境变量:"
    echo "  export TOOLBOX_URL=https://toolbox.example.com"
    echo "  export TOOLBOX_USER=admin"
    echo "  export TOOLBOX_PASSWORD=your-password"
    exit 1
fi

echo "测试 MCP Toolbox BasicAuth 认证"
echo "================================"
echo "URL: $URL"
echo "用户: $USER"
echo ""

# 测试 1: 无认证访问（应该失败）
echo -n "测试 1: 无认证访问... "
if curl -s -o /dev/null -w "%{http_code}" -k "$URL/health" | grep -q "401"; then
    echo -e "${GREEN}✓ 通过${NC} (正确返回 401)"
else
    echo -e "${RED}✗ 失败${NC} (应该返回 401 但没有)"
fi

# 测试 2: 正确的认证（应该成功）
echo -n "测试 2: 正确的认证... "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -k -u "$USER:$PASS" "$URL/health")
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✓ 通过${NC} (返回 200)"
else
    echo -e "${RED}✗ 失败${NC} (返回 $HTTP_CODE)"
fi

# 测试 3: 错误的密码（应该失败）
echo -n "测试 3: 错误的密码... "
if curl -s -o /dev/null -w "%{http_code}" -k -u "$USER:wrong-password" "$URL/health" | grep -q "401"; then
    echo -e "${GREEN}✓ 通过${NC} (正确返回 401)"
else
    echo -e "${RED}✗ 失败${NC} (应该返回 401 但没有)"
fi

# 测试 4: 加载工具集
echo -n "测试 4: 加载工具集... "
RESPONSE=$(curl -s -k -u "$USER:$PASS" "$URL/v1/toolsets" 2>&1)
if echo "$RESPONSE" | grep -q "tools\|toolsets"; then
    echo -e "${GREEN}✓ 通过${NC}"
    echo "  工具数量: $(echo "$RESPONSE" | grep -o '"name"' | wc -l)"
else
    echo -e "${RED}✗ 失败${NC}"
    echo "  响应: $RESPONSE"
fi

# 测试 5: MCP 协议测试（如果支持）
echo -n "测试 5: MCP 端点... "
RESPONSE=$(curl -s -k -u "$USER:$PASS" "$URL/mcp" 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ 通过${NC}"
else
    echo -e "${YELLOW}⊘ 跳过${NC} (可能未启用 MCP)"
fi

echo ""
echo "================================"
echo "测试完成！"
echo ""
echo "下一步:"
echo "  1. 在浏览器访问: $URL"
echo "  2. 使用 SDK 集成（参见 python-client-basicauth.py）"
echo "  3. 查看日志: kubectl logs -l app=toolbox -n mcp-toolbox"
echo ""
