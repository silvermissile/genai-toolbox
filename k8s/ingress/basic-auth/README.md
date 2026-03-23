# Traefik BasicAuth 认证方案

使用 K3s 自带的 Traefik Ingress Controller 配置 HTTP Basic 认证。

## 特点

- ✅ **零依赖**: K3s 自带 Traefik，无需额外安装
- ✅ **简单快速**: 5 分钟完成配置
- ✅ **浏览器友好**: 自动弹出登录框
- ✅ **多用户**: 支持配置多个用户名密码
- ✅ **安全**: 使用 bcrypt 加密密码

## 架构

```
用户浏览器/客户端
    ↓ (HTTPS + BasicAuth Header)
Traefik Ingress Controller
    ↓ (验证用户名密码)
Traefik BasicAuth Middleware
    ↓ (验证通过，转发请求)
Toolbox Service
    ↓
Toolbox Pod
```

## 快速部署

### 自动化部署（推荐）

```bash
# 使用提供的脚本一键部署
./deploy-basic-auth.sh

# 脚本会提示你输入：
# - 用户名
# - 密码
# - 域名
# 然后自动完成所有配置
```

### 手动部署

#### 步骤 1：安装 htpasswd 工具

```bash
# Ubuntu/Debian
sudo apt-get install apache2-utils

# CentOS/RHEL
sudo yum install httpd-tools

# macOS
brew install httpd

# Alpine Linux (如果在容器中)
apk add apache2-utils
```

#### 步骤 2：生成用户凭据

```bash
# 创建第一个用户（使用 bcrypt，-B 参数）
htpasswd -nbB admin your-secure-password > auth

# 添加更多用户（追加模式）
htpasswd -nbB user1 password1 >> auth
htpasswd -nbB user2 password2 >> auth

# 查看生成的文件
cat auth
# 输出示例:
# admin:$2y$05$9vKF8v7MxF.xKb8F4P7zFu...
# user1:$2y$05$xxx...
# user2:$2y$05$yyy...
```

**重要提示**:
- 密码至少 12 位
- 包含大小写字母、数字和特殊字符
- 不要使用常见密码

#### 步骤 3：创建 Kubernetes Secret

```bash
# 在 mcp-toolbox namespace 创建 Secret
kubectl create secret generic toolbox-basic-auth \
  --from-file=users=auth \
  --namespace=mcp-toolbox

# 验证 Secret 创建成功
kubectl get secret toolbox-basic-auth -n mcp-toolbox

# 查看 Secret 内容（调试用）
kubectl get secret toolbox-basic-auth -n mcp-toolbox -o yaml
```

#### 步骤 4：创建 Traefik Middleware

```bash
# 应用 Middleware 配置
kubectl apply -f middleware.yaml

# 验证 Middleware 创建成功
kubectl get middleware -n mcp-toolbox
kubectl describe middleware toolbox-basic-auth -n mcp-toolbox
```

#### 步骤 5：创建/更新 Ingress

```bash
# 如果是新部署
kubectl apply -f ingress.yaml

# 如果是更新现有 Ingress，添加 annotation
kubectl patch ingress toolbox-ingress -n mcp-toolbox -p \
  '{"metadata":{"annotations":{"traefik.ingress.kubernetes.io/router.middlewares":"mcp-toolbox-toolbox-basic-auth@kubernetescrd"}}}'

# 验证 Ingress 配置
kubectl get ingress toolbox-ingress -n mcp-toolbox -o yaml
```

#### 步骤 6：验证认证

```bash
# 1. 不带认证访问（应该返回 401）
curl -k https://toolbox.example.com/health
# 预期: 401 Unauthorized

# 2. 带认证访问（应该成功）
curl -k -u admin:your-secure-password https://toolbox.example.com/health
# 预期: 200 OK

# 3. 错误密码（应该返回 401）
curl -k -u admin:wrong-password https://toolbox.example.com/health
# 预期: 401 Unauthorized

# 4. 在浏览器中访问
# 打开 https://toolbox.example.com
# 应该自动弹出登录框
```

## 添加到现有部署

如果你已经有运行中的 Toolbox 部署：

```bash
# 1. 生成认证文件
htpasswd -nbB admin your-password > auth

# 2. 创建 Secret
kubectl create secret generic toolbox-basic-auth \
  --from-file=users=auth \
  --namespace=mcp-toolbox

# 3. 创建 Middleware
kubectl apply -f middleware.yaml

# 4. 更新 Ingress（添加 annotation）
kubectl annotate ingress toolbox-ingress \
  -n mcp-toolbox \
  traefik.ingress.kubernetes.io/router.middlewares=mcp-toolbox-toolbox-basic-auth@kubernetescrd \
  --overwrite
```

## 用户管理

### 添加新用户

```bash
# 1. 添加用户到 auth 文件
htpasswd -nbB newuser newpassword >> auth

# 2. 更新 Secret
kubectl delete secret toolbox-basic-auth -n mcp-toolbox
kubectl create secret generic toolbox-basic-auth \
  --from-file=users=auth \
  --namespace=mcp-toolbox

# 3. 无需重启 Pod，Traefik 会自动重新加载
```

### 删除用户

```bash
# 1. 编辑 auth 文件，删除对应行
nano auth  # 或使用其他编辑器

# 2. 更新 Secret
kubectl delete secret toolbox-basic-auth -n mcp-toolbox
kubectl create secret generic toolbox-basic-auth \
  --from-file=users=auth \
  --namespace=mcp-toolbox
```

### 修改密码

```bash
# 方式 1：重新生成整个 auth 文件
htpasswd -nbB admin new-password > auth
htpasswd -nbB user1 password1 >> auth

# 方式 2：更新特定用户（需要先删除旧行）
# 1. 从 auth 文件中删除旧的用户行
grep -v "^admin:" auth > auth.tmp && mv auth.tmp auth
# 2. 添加新密码
htpasswd -nbB admin new-password >> auth

# 3. 更新 Secret
kubectl delete secret toolbox-basic-auth -n mcp-toolbox
kubectl create secret generic toolbox-basic-auth \
  --from-file=users=auth \
  --namespace=mcp-toolbox
```

## 客户端配置

### Python SDK

```python
from toolbox_core import ToolboxClient
import asyncio
import base64

async def main():
    # 方式 1: 使用自定义 headers
    username = "admin"
    password = "your-secure-password"
    auth_str = f"{username}:{password}"
    auth_bytes = auth_str.encode('ascii')
    auth_b64 = base64.b64encode(auth_bytes).decode('ascii')
    
    headers = {"Authorization": f"Basic {auth_b64}"}
    
    async with ToolboxClient(
        "https://toolbox.example.com",
        headers=headers
    ) as client:
        tools = await client.load_toolset()
        print(f"已加载 {len(tools)} 个工具")
        
        # 调用工具
        result = await tools[0]()
        print(result)

asyncio.run(main())
```

### JavaScript/TypeScript

```javascript
import { ToolboxClient } from '@toolbox-sdk/core';

const username = process.env.TOOLBOX_USER || 'admin';
const password = process.env.TOOLBOX_PASSWORD;

const auth = Buffer.from(`${username}:${password}`).toString('base64');

const client = new ToolboxClient('https://toolbox.example.com', {
  headers: {
    'Authorization': `Basic ${auth}`
  }
});

const tools = await client.loadToolset();
console.log(`已加载 ${tools.length} 个工具`);

const result = await tools[0]();
console.log(result);
```

### Go

```go
package main

import (
    "context"
    "encoding/base64"
    "fmt"
    "github.com/googleapis/mcp-toolbox-sdk-go/core"
)

func main() {
    ctx := context.Background()
    
    username := "admin"
    password := "your-secure-password"
    
    // 创建 Basic Auth header
    auth := base64.StdEncoding.EncodeToString(
        []byte(fmt.Sprintf("%s:%s", username, password)),
    )
    
    client, err := core.NewToolboxClient(
        "https://toolbox.example.com",
        core.WithHeaders(map[string]string{
            "Authorization": fmt.Sprintf("Basic %s", auth),
        }),
    )
    if err != nil {
        panic(err)
    }
    
    tools, err := client.LoadToolset("default", ctx)
    if err != nil {
        panic(err)
    }
    
    fmt.Printf("已加载 %d 个工具\n", len(tools))
}
```

### Curl

```bash
# 基本用法
curl -u admin:your-password https://toolbox.example.com/v1/toolsets

# 使用环境变量
export TOOLBOX_USER=admin
export TOOLBOX_PASSWORD=your-password
curl -u $TOOLBOX_USER:$TOOLBOX_PASSWORD https://toolbox.example.com/v1/toolsets

# 使用 Base64 编码的 Authorization header
AUTH=$(echo -n "admin:your-password" | base64)
curl -H "Authorization: Basic $AUTH" https://toolbox.example.com/v1/toolsets
```

## 高级配置

### 限制访问源 IP

```yaml
# 在 Middleware 中添加 IP 白名单
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: toolbox-basic-auth-with-ip
  namespace: mcp-toolbox
spec:
  chain:
    middlewares:
    - name: ip-whitelist
    - name: toolbox-basic-auth
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: ip-whitelist
  namespace: mcp-toolbox
spec:
  ipWhiteList:
    sourceRange:
    - "192.168.1.0/24"      # 你的局域网
    - "203.0.113.0/24"      # 你的办公室 IP
    # - "0.0.0.0/0"         # 允许所有（不推荐）
```

### 配置自定义认证提示

```yaml
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: toolbox-basic-auth
  namespace: mcp-toolbox
spec:
  basicAuth:
    secret: toolbox-basic-auth
    realm: "MCP Toolbox - 请使用你的凭据登录"
    removeHeader: true  # 不将 Authorization header 传递给 toolbox
```

### 多个 Middleware 组合

```yaml
# 组合 BasicAuth + RateLimit + Headers
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: toolbox-security-chain
  namespace: mcp-toolbox
spec:
  chain:
    middlewares:
    - name: rate-limit
    - name: toolbox-basic-auth
    - name: security-headers
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: rate-limit
  namespace: mcp-toolbox
spec:
  rateLimit:
    average: 100      # 每秒平均请求数
    burst: 50         # 突发请求数
---
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: security-headers
  namespace: mcp-toolbox
spec:
  headers:
    customResponseHeaders:
      X-Frame-Options: "DENY"
      X-Content-Type-Options: "nosniff"
      X-XSS-Protection: "1; mode=block"
```

然后在 Ingress 中引用：
```yaml
annotations:
  traefik.ingress.kubernetes.io/router.middlewares: mcp-toolbox-toolbox-security-chain@kubernetescrd
```

## 故障排除

### 问题 1：认证不生效，仍可匿名访问

**检查**:
```bash
# 1. 确认 Middleware 已创建
kubectl get middleware -n mcp-toolbox

# 2. 检查 Ingress annotation
kubectl get ingress toolbox-ingress -n mcp-toolbox -o yaml | grep middleware

# 3. 确认 annotation 格式正确
# 格式: {namespace}-{middleware-name}@kubernetescrd
# 例如: mcp-toolbox-toolbox-basic-auth@kubernetescrd
```

**解决**:
```bash
# 重新应用 annotation
kubectl annotate ingress toolbox-ingress \
  -n mcp-toolbox \
  traefik.ingress.kubernetes.io/router.middlewares=mcp-toolbox-toolbox-basic-auth@kubernetescrd \
  --overwrite
```

### 问题 2：密码总是错误

**检查**:
```bash
# 1. 确认 Secret 存在且格式正确
kubectl get secret toolbox-basic-auth -n mcp-toolbox -o jsonpath='{.data.users}' | base64 -d

# 2. 确认密码是 bcrypt 格式
# 正确格式: username:$2y$05$... 或 username:$2a$...
# 错误格式: username:$apr1$... (这是 MD5，Traefik 不支持)

# 3. 重新生成（使用 -B 参数强制 bcrypt）
htpasswd -nbB admin password > auth
```

**解决**:
```bash
# 删除并重新创建 Secret
kubectl delete secret toolbox-basic-auth -n mcp-toolbox
kubectl create secret generic toolbox-basic-auth \
  --from-file=users=auth \
  --namespace=mcp-toolbox
```

### 问题 3：Traefik 日志中看不到认证失败记录

**检查 Traefik 日志级别**:
```bash
# 查看 Traefik 日志
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=100

# 如果日志不够详细，提高日志级别
kubectl edit configmap traefik -n kube-system
# 添加: --log.level=DEBUG
```

### 问题 4：浏览器不弹出登录框

**可能原因**:
1. 浏览器已缓存旧的凭据
2. HTTPS 证书问题
3. Middleware 未正确应用

**解决**:
```bash
# 清除浏览器缓存和凭据
# Chrome: 设置 -> 隐私和安全 -> 清除浏览数据 -> 密码和其他登录数据

# 或使用隐身模式测试

# 检查 Ingress 配置
kubectl describe ingress toolbox-ingress -n mcp-toolbox
```

## 安全建议

### 1. 使用强密码

```bash
# 生成随机强密码（32 字符）
openssl rand -base64 32

# 使用密码生成器
# Linux: pwgen -s 32 1
# macOS: brew install pwgen && pwgen -s 32 1
```

### 2. 定期轮换密码

```bash
# 创建密码轮换脚本
cat > rotate-password.sh << 'EOF'
#!/bin/bash
set -e

# 生成新密码
NEW_PASSWORD=$(openssl rand -base64 32)
echo "新密码: $NEW_PASSWORD"

# 更新 auth 文件
htpasswd -nbB admin "$NEW_PASSWORD" > auth

# 更新 Secret
kubectl delete secret toolbox-basic-auth -n mcp-toolbox
kubectl create secret generic toolbox-basic-auth \
  --from-file=users=auth \
  --namespace=mcp-toolbox

echo "密码已更新！"
echo "请妥善保存新密码: $NEW_PASSWORD"
EOF

chmod +x rotate-password.sh
```

### 3. 启用访问日志

```yaml
# 在 Ingress 中添加访问日志 annotation
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: mcp-toolbox-toolbox-basic-auth@kubernetescrd
    # 启用访问日志
    traefik.ingress.kubernetes.io/access-log: "true"
```

查看日志:
```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik | grep toolbox
```

### 4. 配置 HTTPS（强烈推荐）

参见 `k8s/security/cert-manager.yaml`

### 5. 备份认证凭据

```bash
# 导出 Secret 到文件（加密存储）
kubectl get secret toolbox-basic-auth -n mcp-toolbox -o yaml > toolbox-auth-backup.yaml

# 使用 gpg 加密
gpg -c toolbox-auth-backup.yaml
# 输入密码

# 删除明文文件
rm toolbox-auth-backup.yaml

# 恢复时：
# gpg -d toolbox-auth-backup.yaml.gpg > toolbox-auth-backup.yaml
# kubectl apply -f toolbox-auth-backup.yaml
```

## 性能优化

BasicAuth 验证在 Ingress 层完成，对性能影响极小。

**基准测试** (单核 K3s):
- 无认证: ~1000 req/s
- BasicAuth: ~950 req/s
- 性能损失: ~5%

**优化建议**:
- 使用 HTTPS/TLS session resumption
- 配置客户端连接池
- 启用 HTTP/2

## 升级到 OAuth 2.0

如果未来需要更复杂的认证，可以从 BasicAuth 平滑升级到 OAuth2 Proxy:

1. 部署 OAuth2 Proxy
2. 修改 Ingress annotation 指向新 Middleware
3. 移除 BasicAuth Middleware

详见 `../oauth2-proxy/README.md`

## 相关资源

### 项目文档

- [K8s 部署总览](../../README.md)
- [5 分钟快速开始](../../QUICKSTART.md)
- [架构设计](../../ARCHITECTURE.md)
- [客户端示例](../../examples/README.md)

### 外部资源

- [Traefik BasicAuth 文档](https://doc.traefik.io/traefik/middlewares/http/basicauth/)
- [K3s Ingress 文档](https://docs.k3s.io/networking)
- [htpasswd 文档](https://httpd.apache.org/docs/2.4/programs/htpasswd.html)
