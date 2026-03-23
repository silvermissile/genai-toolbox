# MCP Toolbox Kubernetes 部署指南

本目录包含在 Kubernetes (K3s) 环境中部署 MCP Toolbox 的配置文件和脚本。

## 🚀 快速导航

| 目标 | 文档 | 命令 |
|------|------|------|
| **5 分钟部署 BasicAuth** | [QUICKSTART.md](QUICKSTART.md) | `cd ingress/basic-auth && ./deploy-basic-auth.sh` |
| **了解架构设计** | [ARCHITECTURE.md](ARCHITECTURE.md) | - |
| **BasicAuth 详细配置** | [ingress/basic-auth/README.md](ingress/basic-auth/README.md) | - |
| **客户端示例代码** | [examples/README.md](examples/README.md) | `cd examples && ./test-auth.sh` |
| **完整部署向导** | 使用脚本 | `cd scripts && ./deploy-all.sh` |

## 目录结构

```
k8s/
├── README.md                          # 本文件
├── base/                              # 基础配置
│   ├── namespace.yaml                 # 命名空间
│   ├── configmap.yaml                 # ConfigMap (tools.yaml)
│   ├── secret.yaml.example            # Secret 模板
│   ├── deployment.yaml                # Toolbox Deployment
│   └── service.yaml                   # Service
├── ingress/                           # Ingress 配置
│   ├── basic-auth/                    # Traefik BasicAuth 方案
│   │   ├── README.md                  # BasicAuth 部署指南
│   │   ├── middleware.yaml            # Traefik Middleware
│   │   └── ingress.yaml               # Ingress 配置
│   ├── oauth2-proxy/                  # OAuth2 Proxy 方案
│   │   └── README.md                  # OAuth2 Proxy 指南
│   └── network-policy/                # NetworkPolicy 方案
│       └── network-policy.yaml        # 网络策略
├── security/                          # 安全配置
│   ├── cert-manager.yaml              # Let's Encrypt 证书
│   └── pod-security.yaml              # Pod 安全策略
└── scripts/                           # 部署脚本
    ├── deploy.sh                      # 一键部署脚本
    ├── setup-auth.sh                  # 配置认证脚本
    └── cleanup.sh                     # 清理脚本
```

## 快速开始

### 前置要求

- K3s/K8s 集群已运行
- kubectl 已配置
- 有域名指向集群（如使用 Ingress）

### 方案 A：Traefik BasicAuth（推荐个人使用）

**5 分钟完成部署**

```bash
# 1. 进入 basic-auth 目录
cd k8s/ingress/basic-auth/

# 2. 使用自动化脚本部署
./deploy-basic-auth.sh

# 或手动执行以下步骤：
# 详见 k8s/ingress/basic-auth/README.md
```

### 方案 B：OAuth2 Proxy

```bash
cd k8s/ingress/oauth2-proxy/
# 详见该目录下的 README.md
```

### 方案 C：NetworkPolicy（仅内部访问）

```bash
cd k8s/ingress/network-policy/
kubectl apply -f network-policy.yaml
```

## 部署选项对比

| 方案 | 适用场景 | 复杂度 | 安全性 | 部署时间 |
|------|----------|--------|--------|----------|
| BasicAuth | 个人/小团队 | 低 | 中 | 5 分钟 |
| OAuth2 Proxy | 需要 Google 登录 | 中 | 高 | 15 分钟 |
| NetworkPolicy | 仅集群内访问 | 低 | 中 | 3 分钟 |

## 常见问题

### Q: 我已经有 Toolbox 部署，如何添加认证？

只需要：
1. 创建 BasicAuth Secret
2. 创建 Traefik Middleware
3. 更新现有 Ingress 添加 annotation

详见 `ingress/basic-auth/README.md` 的"添加到现有部署"章节。

### Q: 如何添加/删除用户？

```bash
# 添加新用户
htpasswd -nbB newuser newpassword >> auth
kubectl delete secret toolbox-basic-auth -n default
kubectl create secret generic toolbox-basic-auth --from-file=users=auth -n default

# 删除用户：编辑 auth 文件，移除对应行，然后重新创建 Secret
```

### Q: 如何查看访问日志？

```bash
# 查看 Traefik 日志
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=100

# 查看 Toolbox 日志
kubectl logs -l app=toolbox -n default --tail=100 -f
```

### Q: 忘记密码怎么办？

```bash
# 重新生成 auth 文件
htpasswd -nbB admin new-password > auth

# 更新 Secret
kubectl delete secret toolbox-basic-auth -n default
kubectl create secret generic toolbox-basic-auth --from-file=users=auth -n default
```

## 安全建议

1. ✅ **必须使用 HTTPS** - 配置 cert-manager 自动管理证书
2. ✅ **使用强密码** - 至少 16 位，包含大小写字母、数字和特殊字符
3. ✅ **定期更新密码** - 建议每 90 天更新一次
4. ✅ **限制访问源** - 使用 Ingress annotations 限制 IP
5. ✅ **启用日志审计** - 记录所有访问尝试
6. ✅ **备份配置** - 定期备份 Secrets 和 ConfigMaps

## 故障排除

### Traefik Middleware 不生效

```bash
# 检查 Middleware 是否创建
kubectl get middleware -n default

# 检查 Ingress annotation 格式
kubectl get ingress toolbox-ingress -n default -o yaml | grep middleware

# 正确格式应该是：
# traefik.ingress.kubernetes.io/router.middlewares: default-toolbox-basic-auth@kubernetescrd
```

### 认证总是失败

```bash
# 检查 Secret 内容
kubectl get secret toolbox-basic-auth -n default -o jsonpath='{.data.users}' | base64 -d

# 验证密码格式（应该是 bcrypt）
# 正确格式: username:$2y$05$...
```

### 无法访问服务

```bash
# 检查 Pod 状态
kubectl get pods -l app=toolbox -n default

# 检查 Service
kubectl get svc toolbox -n default

# 检查 Ingress
kubectl get ingress -n default

# 测试集群内访问
kubectl run test-pod --rm -it --image=curlimages/curl -- \
  curl http://toolbox.default.svc.cluster.local:5000/health
```

## 下一步

- 配置监控和告警
- 设置自动备份
- 实施日志聚合
- 配置高可用（多副本）

## 相关文档

- **认证调研报告**: [../MCP_认证功能调研报告.md](../MCP_认证功能调研报告.md) - 完整的认证功能调研
- **架构设计**: [ARCHITECTURE.md](ARCHITECTURE.md) - 详细的架构分析和方案对比
- **快速开始**: [QUICKSTART.md](QUICKSTART.md) - 5 分钟快速部署指南
- **BasicAuth 详细配置**: [ingress/basic-auth/README.md](ingress/basic-auth/README.md)
- **客户端示例**: [examples/README.md](examples/README.md)

### 外部链接

- [Traefik 中间件文档](https://doc.traefik.io/traefik/middlewares/overview/)
- [K3s Ingress 文档](https://docs.k3s.io/networking#traefik-ingress-controller)
- [MCP Toolbox 官方文档](https://googleapis.github.io/genai-toolbox/)
