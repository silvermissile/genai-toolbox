# OAuth2 Proxy 认证方案

使用 OAuth2 Proxy 提供完整的 Google Sign-In 体验。

## 特点

- ✅ **完整 OAuth 2.0 流程**: 支持 Google 登录页面
- ✅ **用户体验好**: 与 Google 账号无缝集成
- ✅ **支持多提供商**: Google, GitHub, Azure AD, Okta 等
- ✅ **会话管理**: 自动管理 token 刷新

## 架构

```
用户 → Google Sign-In → OAuth2 Proxy → Toolbox
```

## 部署步骤

### 步骤 1: 注册 Google OAuth 应用

1. 访问 [Google Cloud Console](https://console.cloud.google.com/)
2. 创建项目（或使用现有项目）
3. 进入 "APIs & Services" → "Credentials"
4. 创建 "OAuth 2.0 Client ID"
   - 应用类型: Web application
   - 授权重定向 URI: `https://your-domain/oauth2/callback`
5. 记录 Client ID 和 Client Secret

### 步骤 2: 生成 Cookie Secret

```bash
# 生成随机 cookie secret（32 字节）
python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())'
# 或使用 OpenSSL
openssl rand -base64 32 | tr -d '\n' ; echo
```

### 步骤 3: 创建 Secret

```bash
kubectl create secret generic oauth2-proxy \
  --from-literal=client-id=YOUR_CLIENT_ID \
  --from-literal=client-secret=YOUR_CLIENT_SECRET \
  --from-literal=cookie-secret=YOUR_COOKIE_SECRET \
  --namespace=mcp-toolbox
```

### 步骤 4: 部署 OAuth2 Proxy

创建 `oauth2-proxy-deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: mcp-toolbox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
    spec:
      containers:
      - name: oauth2-proxy
        image: quay.io/oauth2-proxy/oauth2-proxy:latest
        args:
        - --provider=google
        - --email-domain=*  # 允许任何 Google 账号，或改为 example.com 限制域名
        - --upstream=http://toolbox:5000
        - --http-address=0.0.0.0:4180
        - --cookie-secure=true
        - --cookie-domain=.example.com  # 修改为你的域名
        - --whitelist-domain=.example.com
        env:
        - name: OAUTH2_PROXY_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy
              key: client-id
        - name: OAUTH2_PROXY_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy
              key: client-secret
        - name: OAUTH2_PROXY_COOKIE_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy
              key: cookie-secret
        ports:
        - containerPort: 4180
          name: http
---
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy
  namespace: mcp-toolbox
spec:
  selector:
    app: oauth2-proxy
  ports:
  - port: 4180
    targetPort: http
```

### 步骤 5: 创建 Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: toolbox-oauth2-ingress
  namespace: mcp-toolbox
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - toolbox.example.com
    secretName: toolbox-oauth2-tls
  rules:
  - host: toolbox.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: oauth2-proxy  # 注意：指向 oauth2-proxy，不是 toolbox
            port:
              number: 4180
```

### 步骤 6: 验证

访问 `https://toolbox.example.com`，应该会跳转到 Google 登录页面。

## 与 BasicAuth 对比

| 特性 | BasicAuth | OAuth2 Proxy |
|------|-----------|--------------|
| 部署复杂度 | 低 | 中 |
| 用户体验 | 中（浏览器弹框） | 高（Google 登录页） |
| 安全性 | 中 | 高 |
| 用户管理 | 手动 | Google 管理 |
| 适用场景 | 个人/小团队 | 团队/企业 |

## 相关资源

### 项目文档

- [K8s 部署总览](../../README.md)
- [架构设计](../../ARCHITECTURE.md)
- [BasicAuth 方案对比](../basic-auth/README.md)

### 外部资源

- [OAuth2 Proxy 文档](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Google Sign-In 设置](https://developers.google.com/identity/protocols/oauth2)
