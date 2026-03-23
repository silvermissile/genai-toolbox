# K8s 部署快速开始

最快 5 分钟完成 MCP Toolbox 的 K8s 部署和认证配置。

## 前置条件

- K3s/K8s 集群运行中
- kubectl 已配置
- 有域名指向集群（使用 Ingress 时）

## 方案选择

### 方案 A：Traefik BasicAuth（推荐）

**优点**: 最简单，K3s 自带 Traefik  
**适合**: 个人使用、小团队

```bash
cd k8s/ingress/basic-auth/
./deploy-basic-auth.sh
```

### 方案 B：NetworkPolicy

**优点**: 零配置，仅网络隔离  
**适合**: 仅集群内部访问

```bash
kubectl apply -f k8s/ingress/network-policy/network-policy.yaml
```

### 方案 C：OAuth2 Proxy

**优点**: Google 登录体验好  
**适合**: 需要 Google SSO

详见 `ingress/oauth2-proxy/README.md`

## 完整部署流程

如果是全新部署（包括 Toolbox 本身）：

```bash
# 1. 配置数据库凭据
cd k8s/base/
cp secret.yaml.example secret.yaml
nano secret.yaml  # 修改数据库配置

# 2. 执行完整部署
cd ..
./scripts/deploy-all.sh

# 脚本会引导你完成所有配置
```

## 验证部署

```bash
# 查看所有资源
kubectl get all,middleware,ingress -n mcp-toolbox

# 查看 Pod 日志
kubectl logs -l app=toolbox -n mcp-toolbox -f

# 测试认证（BasicAuth）
curl -u admin:password https://your-domain/health
```

## 常见问题

**Q: 认证不生效？**
```bash
# 检查 Middleware
kubectl get middleware -n mcp-toolbox

# 检查 Ingress annotation
kubectl describe ingress toolbox-ingress -n mcp-toolbox | grep middleware
```

**Q: 如何添加用户？**
```bash
htpasswd -nbB newuser newpass >> auth
kubectl delete secret toolbox-basic-auth -n mcp-toolbox
kubectl create secret generic toolbox-basic-auth --from-file=users=auth -n mcp-toolbox
```

**Q: 如何查看日志？**
```bash
# Toolbox 日志
kubectl logs -l app=toolbox -n mcp-toolbox

# Traefik 日志
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik
```

## 清理部署

```bash
cd k8s/scripts/
./cleanup.sh
```

## 更多信息

- **K8s 部署总览**: [README.md](README.md)
- **架构设计**: [ARCHITECTURE.md](ARCHITECTURE.md)
- **认证调研报告**: [../MCP_认证功能调研报告.md](../MCP_认证功能调研报告.md)
- **BasicAuth 详细指南**: [ingress/basic-auth/README.md](ingress/basic-auth/README.md)
- **客户端示例**: [examples/README.md](examples/README.md)
