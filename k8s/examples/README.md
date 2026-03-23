# MCP Toolbox 客户端示例

本目录包含使用 BasicAuth 连接到 K8s 部署的 MCP Toolbox 的客户端示例代码。

## 文件列表

- `python-client-basicauth.py` - Python 客户端示例
- `go-client-basicauth.go` - Go 客户端示例
- `test-auth.sh` - 认证测试脚本
- `.env.example` - 环境变量模板

## 快速开始

### 1. 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件
nano .env

# 或直接导出环境变量
export TOOLBOX_URL=https://toolbox.example.com
export TOOLBOX_USER=admin
export TOOLBOX_PASSWORD=your-secure-password
```

### 2. 测试认证

```bash
# 运行测试脚本
./test-auth.sh

# 或手动测试
curl -u admin:password https://toolbox.example.com/health
```

### 3. 运行客户端示例

#### Python 示例

```bash
# 安装依赖
pip install toolbox-core python-dotenv

# 运行示例
python3 python-client-basicauth.py
```

#### Go 示例

```bash
# 安装依赖
go get github.com/googleapis/mcp-toolbox-sdk-go/core

# 运行示例
go run go-client-basicauth.go
```

## 示例说明

### Python 客户端功能

- **示例 1**: 基本连接和加载工具
- **示例 2**: 调用特定工具
- **示例 3**: 带参数调用工具
- **示例 4**: 错误处理
- **示例 5**: 封装可复用的客户端类

### Go 客户端功能

- **示例 1**: 基本连接和加载工具
- **示例 2**: 调用特定工具
- **示例 3**: 带参数调用工具
- **示例 4**: 错误处理
- **示例 5**: 封装可复用的客户端类

### 测试脚本功能

- **测试 1**: 验证无认证访问被拒绝
- **测试 2**: 验证正确认证可以访问
- **测试 3**: 验证错误密码被拒绝
- **测试 4**: 测试加载工具集
- **测试 5**: 测试 MCP 端点

## 在 IDE 中使用

### Claude Desktop / Cursor

修改 MCP 配置文件:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`  
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`

```json
{
  "mcpServers": {
    "toolbox": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-fetch",
        "https://admin:password@toolbox.example.com"
      ]
    }
  }
}
```

**注意**: 
- URL 中包含认证信息仅适用于个人使用
- 确保配置文件权限正确 (chmod 600)
- 考虑使用环境变量存储密码

### Cline / Continue

在扩展设置中添加 MCP 服务器，配置方式类似。

## 安全提示

1. ✅ **不要在代码中硬编码密码**
2. ✅ **使用环境变量或 .env 文件**
3. ✅ **将 .env 添加到 .gitignore**
4. ✅ **使用强密码（至少 16 位）**
5. ✅ **定期轮换密码**
6. ✅ **在生产环境使用 HTTPS**

## 故障排除

### 问题: 连接被拒绝

```bash
# 检查服务是否运行
kubectl get pods -l app=toolbox -n mcp-toolbox

# 检查 Service
kubectl get svc toolbox -n mcp-toolbox

# 检查 Ingress
kubectl get ingress -n mcp-toolbox
```

### 问题: 认证失败

```bash
# 验证 Secret 存在
kubectl get secret toolbox-basic-auth -n mcp-toolbox

# 查看 Secret 内容（验证格式）
kubectl get secret toolbox-basic-auth -n mcp-toolbox -o jsonpath='{.data.users}' | base64 -d

# 应该看到类似: admin:$2y$05$...
```

### 问题: HTTPS 证书错误

```bash
# 临时跳过证书验证（仅测试用）
curl -k -u admin:password https://toolbox.example.com/health

# Python 中跳过验证
import ssl
ssl._create_default_https_context = ssl._create_unverified_context
```

## 相关文档

### 项目文档

- [K8s 部署总览](../README.md)
- [5 分钟快速开始](../QUICKSTART.md)
- [BasicAuth 部署指南](../ingress/basic-auth/README.md)
- [认证调研报告](../../MCP_认证功能调研报告.md)

### 外部资源

- [Python SDK 文档](https://github.com/googleapis/mcp-toolbox-sdk-python)
- [Go SDK 文档](https://github.com/googleapis/mcp-toolbox-sdk-go)
- [MCP Toolbox 官方文档](https://googleapis.github.io/genai-toolbox/)
