#!/bin/bash
# Presto MCP 服务测试脚本

set -e

BASE_URL="${BASE_URL:-http://localhost:5000}"
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=================================="
echo "Presto MCP 服务测试"
echo "=================================="
echo "服务地址: $BASE_URL"
echo ""

# 测试 1: 检查服务健康
echo -e "${YELLOW}[测试 1]${NC} 检查服务健康..."
response=$(curl -s "${BASE_URL}/api/tool/run-presto-query")
if echo "$response" | grep -q "run-presto-query"; then
    echo -e "${GREEN}✅ 服务正常运行${NC}"
else
    echo -e "${RED}❌ 服务异常${NC}"
    exit 1
fi
echo ""

# 测试 2: SHOW CATALOGS
echo -e "${YELLOW}[测试 2]${NC} SHOW CATALOGS..."
response=$(curl -s -X POST "${BASE_URL}/api/tool/run-presto-query/invoke" \
    -H "Content-Type: application/json" \
    -d '{"sql": "SHOW CATALOGS"}')
if echo "$response" | grep -q "result"; then
    catalog_count=$(echo "$response" | grep -o "Catalog" | wc -l)
    echo -e "${GREEN}✅ 查询成功，返回 $catalog_count 个 catalogs${NC}"
    echo "   注意: 响应数据包含 catalog 名称，建议不要记录到日志"
else
    echo -e "${RED}❌ 查询失败${NC}"
    echo "$response"
    exit 1
fi
echo ""

# 测试 3: SELECT 查询
echo -e "${YELLOW}[测试 3]${NC} SELECT 基础查询..."
response=$(curl -s -X POST "${BASE_URL}/api/tool/run-presto-query/invoke" \
    -H "Content-Type: application/json" \
    -d '{"sql": "SELECT 1 AS test_number, '\''hello'\'' AS test_string"}')
if echo "$response" | grep -q "test_number"; then
    echo -e "${GREEN}✅ SELECT 查询成功${NC}"
else
    echo -e "${RED}❌ SELECT 查询失败${NC}"
    echo "$response"
    exit 1
fi
echo ""

# 测试 4: 系统函数
echo -e "${YELLOW}[测试 4]${NC} 系统函数查询..."
response=$(curl -s -X POST "${BASE_URL}/api/tool/run-presto-query/invoke" \
    -H "Content-Type: application/json" \
    -d '{"sql": "SELECT current_timestamp AS now, current_user AS user"}')
if echo "$response" | grep -q "now"; then
    echo -e "${GREEN}✅ 系统函数查询成功${NC}"
    echo "   注意: 响应包含当前用户名，不要记录敏感信息"
else
    echo -e "${RED}❌ 系统函数查询失败${NC}"
    echo "$response"
    exit 1
fi
echo ""

# 测试 5: 错误处理
echo -e "${YELLOW}[测试 5]${NC} 错误处理测试..."
response=$(curl -s -X POST "${BASE_URL}/api/tool/run-presto-query/invoke" \
    -H "Content-Type: application/json" \
    -d '{"sql": "SELECT * FROM non_existent_table"}')
if echo "$response" | grep -q "error"; then
    echo -e "${GREEN}✅ 错误处理正常${NC}"
else
    echo -e "${YELLOW}⚠️  无错误或错误格式异常${NC}"
fi
echo ""

echo "=================================="
echo -e "${GREEN}✅ 所有测试完成！${NC}"
echo "=================================="
echo ""
echo "⚠️  安全提醒："
echo "   - 不要将测试响应数据提交到公开仓库"
echo "   - catalog 名称、schema 名称、IP 地址等都属于敏感信息"
echo "   - 生产环境测试结果应保存在内部系统"
