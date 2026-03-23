# MCP Toolbox K8s 架构设计

本文档详细说明 MCP Toolbox 在 Kubernetes 环境中的部署架构和认证方案。

## 目录

1. [基础架构](#1-基础架构)
2. [认证方案对比](#2-认证方案对比)
3. [推荐架构](#3-推荐架构)
4. [高可用架构](#4-高可用架构)
5. [安全最佳实践](#5-安全最佳实践)

---

## 1. 基础架构

### 1.1 最小化部署

```mermaid
graph TB
    subgraph K3s_Cluster["K3s 集群"]
        subgraph Namespace["mcp-toolbox namespace"]
            CM[ConfigMap<br/>tools.yaml]
            Secret[Secret<br/>数据库凭据]
            Deploy[Deployment<br/>toolbox]
            Pod[Pod<br/>toolbox]
            Svc[Service<br/>ClusterIP]
            
            CM -.->|挂载| Pod
            Secret -.->|环境变量| Pod
            Deploy -->|管理| Pod
            Svc -->|路由| Pod
        end
    end
    
    User[用户] -->|kubectl port-forward| Svc
    Pod -->|连接| DB[(外部数据库)]
    
    style User fill:#e1f5ff
    style Pod fill:#fff4e1
    style DB fill:#ffe1e1
    style CM fill:#f0f0f0
    style Secret fill:#f0f0f0
```

**适用场景**: 
- 本地开发
- 内网测试
- 无需外部访问

**部署命令**:
```bash
kubectl apply -f k8s/base/
kubectl port-forward svc/toolbox 5000:5000 -n mcp-toolbox
```

---

### 1.2 标准部署（带 Ingress）

```mermaid
graph TB
    subgraph Internet["公网"]
        User[用户]
    end
    
    subgraph K3s["K3s 集群"]
        Traefik[Traefik<br/>Ingress Controller]
        
        subgraph NS["mcp-toolbox namespace"]
            Ingress[Ingress<br/>toolbox.example.com]
            Svc[Service]
            Pod[Toolbox Pod]
        end
    end
    
    User -->|HTTPS| Traefik
    Traefik -->|路由| Ingress
    Ingress -->|转发| Svc
    Svc -->|负载均衡| Pod
    Pod -->|连接| DB[(Database)]
    
    style User fill:#e1f5ff
    style Traefik fill:#e1ffe1
    style Pod fill:#fff4e1
    style DB fill:#ffe1e1
```

**适用场景**: 
- 需要外部访问
- 有域名
- 基础部署

---

## 2. 认证方案对比

### 2.1 Traefik BasicAuth（推荐）

```mermaid
sequenceDiagram
    participant U as 用户
    participant T as Traefik
    participant M as BasicAuth Middleware
    participant TB as Toolbox
    participant DB as Database
    
    U->>T: GET /v1/toolsets
    T->>M: 检查认证
    M->>M: 验证 Authorization header
    alt 认证成功
        M->>TB: 转发请求
        TB->>DB: 查询数据
        DB-->>TB: 返回结果
        TB-->>M: 返回响应
        M-->>T: 返回响应
        T-->>U: 200 OK + 数据
    else 认证失败
        M-->>T: 401 Unauthorized
        T-->>U: 401 Unauthorized
    end
```

**认证流程**:
1. 用户请求带 `Authorization: Basic <base64(user:pass)>` header
2. Traefik 接收请求
3. BasicAuth Middleware 从 Secret 读取 htpasswd
4. 验证用户名和密码
5. 验证通过则转发，失败则返回 401

**配置复杂度**: ⭐ (最简单)

---

### 2.2 OAuth2 Proxy

```mermaid
sequenceDiagram
    participant U as 用户
    participant T as Traefik
    participant O as OAuth2 Proxy
    participant G as Google
    participant TB as Toolbox
    
    U->>T: 访问 /
    T->>O: 转发请求
    O->>O: 检查 session cookie
    alt 未登录
        O-->>U: 302 重定向到 Google
        U->>G: 登录
        G-->>U: 返回 code
        U->>O: /oauth2/callback?code=...
        O->>G: 验证 code
        G-->>O: 返回 ID token
        O->>O: 设置 session cookie
        O-->>U: 302 重定向到原始页面
    end
    U->>O: 请求（带 cookie）
    O->>TB: 转发请求
    TB-->>O: 返回数据
    O-->>U: 返回数据
```

**认证流程**:
1. 用户首次访问被重定向到 Google 登录
2. 登录成功后 OAuth2 Proxy 设置 session cookie
3. 后续请求通过 cookie 验证
4. Token 自动刷新

**配置复杂度**: ⭐⭐ (中等)

---

### 2.3 Toolbox 内置认证

```mermaid
sequenceDiagram
    participant U as 用户
    participant T as Traefik
    participant TB as Toolbox
    participant A as AuthService
    participant G as Google API
    participant DB as Database
    
    U->>T: POST /v1/tools/my-tool/invoke<br/>Header: my-auth_token=<ID_TOKEN>
    T->>TB: 转发请求（带 token）
    TB->>A: 获取 AuthService
    A->>G: 验证 ID Token
    G-->>A: 返回 Claims
    A-->>TB: 返回 Claims
    TB->>TB: 检查工具的 authRequired
    alt 授权通过
        TB->>TB: 解析参数（从 claims 提取）
        TB->>DB: 执行查询
        DB-->>TB: 返回结果
        TB-->>U: 200 OK + 结果
    else 授权失败
        TB-->>U: 401 Unauthorized
    end
```

**认证流程**:
1. 用户请求带 `{authService}_token: <ID_TOKEN>` header
2. Toolbox 使用 Google API 验证 token
3. 提取 claims (email, sub, etc.)
4. 检查工具的 `authRequired` 配置
5. 自动填充带 `authServices` 的参数
6. 执行工具

**配置复杂度**: ⭐⭐⭐ (较复杂)

---

### 2.4 NetworkPolicy

```mermaid
graph LR
    subgraph Allowed["允许的来源"]
        FrontendPod[Frontend Pod]
        BackendPod[Backend Pod]
    end
    
    subgraph Blocked["被阻止的来源"]
        UnknownPod[未知 Pod]
        External[外部请求]
    end
    
    FrontendPod -->|✓ 允许| Toolbox[Toolbox Pod]
    BackendPod -->|✓ 允许| Toolbox
    UnknownPod -.->|✗ 拒绝| Toolbox
    External -.->|✗ 拒绝| Toolbox
    
    NetworkPolicy[NetworkPolicy] -.->|配置规则| Toolbox
    
    style FrontendPod fill:#e1ffe1
    style BackendPod fill:#e1ffe1
    style UnknownPod fill:#ffe1e1
    style External fill:#ffe1e1
    style Toolbox fill:#fff4e1
```

**工作原理**:
- Kubernetes 网络层面的访问控制
- 基于 namespace、Pod label 或 IP 范围
- 不验证用户身份，只控制网络连接

**配置复杂度**: ⭐ (最简单，但功能有限)

---

## 3. 推荐架构

### 3.1 个人使用 - Traefik BasicAuth

```mermaid
graph TB
    subgraph Internet["互联网"]
        User[用户<br/>你自己]
    end
    
    subgraph K3s["K3s 集群"]
        LB[LoadBalancer<br/>或 NodePort]
        
        subgraph IngressNS["kube-system"]
            Traefik[Traefik<br/>Ingress Controller]
        end
        
        subgraph ToolboxNS["mcp-toolbox namespace"]
            Ingress[Ingress<br/>+ BasicAuth annotation]
            Middleware[BasicAuth<br/>Middleware]
            Secret[Secret<br/>htpasswd]
            Svc[Service]
            Pod[Toolbox Pod]
            CM[ConfigMap<br/>tools.yaml]
        end
    end
    
    subgraph External["外部服务"]
        DB[(PostgreSQL<br/>数据库)]
        CertMgr[Let's Encrypt<br/>证书]
    end
    
    User -->|HTTPS<br/>username:password| LB
    LB --> Traefik
    Traefik --> Ingress
    Ingress --> Middleware
    Secret -.->|提供凭据| Middleware
    Middleware -->|验证通过| Svc
    Svc --> Pod
    CM -.->|配置| Pod
    Pod --> DB
    CertMgr -.->|TLS 证书| Traefik
    
    style User fill:#e1f5ff
    style Traefik fill:#e1ffe1
    style Middleware fill:#e1ffe1
    style Pod fill:#fff4e1
    style DB fill:#ffe1e1
    style Secret fill:#f0f0f0
    style CM fill:#f0f0f0
```

**特点**:
- 简单可靠
- 性能优秀
- 易于维护

**一键部署**:
```bash
cd k8s/ingress/basic-auth/ && ./deploy-basic-auth.sh
```

---

### 3.2 团队使用 - OAuth2 Proxy

```mermaid
graph TB
    subgraph Users["用户"]
        User1[用户 A]
        User2[用户 B]
        User3[用户 C]
    end
    
    subgraph K3s["K3s 集群"]
        Ingress[Ingress]
        
        subgraph OAuth2NS["mcp-toolbox"]
            OAuth2[OAuth2 Proxy]
            OAuth2Svc[OAuth2 Service]
            ToolboxSvc[Toolbox Service]
            Pod[Toolbox Pod]
        end
    end
    
    subgraph External["外部"]
        Google[Google Sign-In]
        DB[(Database)]
    end
    
    User1 & User2 & User3 -->|HTTPS| Ingress
    Ingress --> OAuth2Svc
    OAuth2Svc --> OAuth2
    OAuth2 <-.->|OAuth 2.0 流程| Google
    OAuth2 -->|已认证| ToolboxSvc
    ToolboxSvc --> Pod
    Pod --> DB
    
    style User1 fill:#e1f5ff
    style User2 fill:#e1f5ff
    style User3 fill:#e1f5ff
    style OAuth2 fill:#e1ffe1
    style Pod fill:#fff4e1
    style Google fill:#e1f5ff
    style DB fill:#ffe1e1
```

**特点**:
- Google 账号管理
- 用户体验好
- 适合团队协作

---

### 3.3 企业使用 - 组合方案

```mermaid
graph TB
    subgraph Users["用户"]
        WebApp[Web 应用]
        MobileApp[移动应用]
        InternalSvc[内部服务]
    end
    
    subgraph K3s["K3s 集群"]
        subgraph IngressLayer["Ingress 层"]
            Traefik[Traefik]
            OAuth2[OAuth2 Proxy]
        end
        
        subgraph AppLayer["应用层"]
            Toolbox[Toolbox<br/>内置认证]
            AuthSvc[AuthService<br/>Google/Azure]
        end
        
        subgraph DataLayer["数据层"]
            DB[(Database)]
        end
        
        NP[NetworkPolicy<br/>网络隔离]
    end
    
    WebApp -->|OAuth 2.0| OAuth2
    MobileApp -->|OAuth 2.0| OAuth2
    InternalSvc -->|内部调用| Traefik
    
    OAuth2 --> Toolbox
    Traefik --> Toolbox
    
    Toolbox --> AuthSvc
    AuthSvc -.->|验证| External[Google/Azure AD]
    
    Toolbox --> DB
    NP -.->|限制| DB
    
    style WebApp fill:#e1f5ff
    style MobileApp fill:#e1f5ff
    style InternalSvc fill:#e1ffe1
    style Toolbox fill:#fff4e1
    style AuthSvc fill:#e1ffe1
    style DB fill:#ffe1e1
```

**特点**:
- 多层认证
- 细粒度权限
- 网络隔离

---

## 4. 高可用架构

### 4.1 多副本 + 负载均衡

```yaml
# 高可用 Deployment 配置
apiVersion: apps/v1
kind: Deployment
metadata:
  name: toolbox
  namespace: mcp-toolbox
spec:
  replicas: 3  # 多副本
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: toolbox
  template:
    metadata:
      labels:
        app: toolbox
    spec:
      # Pod 反亲和性（分散到不同节点）
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: toolbox
              topologyKey: kubernetes.io/hostname
      
      containers:
      - name: toolbox
        image: toolbox:0.30.0
        # ... 其他配置
```

### 4.2 水平自动扩缩容（HPA）

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: toolbox-hpa
  namespace: mcp-toolbox
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: toolbox
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

### 4.3 持久化和备份

```yaml
# PVC for configuration backups
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: toolbox-config-backup
  namespace: mcp-toolbox
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
# CronJob for periodic backups
apiVersion: batch/v1
kind: CronJob
metadata:
  name: toolbox-config-backup
  namespace: mcp-toolbox
spec:
  schedule: "0 2 * * *"  # 每天凌晨 2 点
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              kubectl get configmap toolbox-config -n mcp-toolbox -o yaml > /backup/config-$(date +%Y%m%d).yaml
              kubectl get secret toolbox-secrets -n mcp-toolbox -o yaml > /backup/secret-$(date +%Y%m%d).yaml
              # 保留最近 7 天的备份
              find /backup -mtime +7 -delete
            volumeMounts:
            - name: backup
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: toolbox-config-backup
```

---

## 5. 安全最佳实践

### 5.1 纵深防御架构

```mermaid
graph TB
    subgraph Layer1["第 1 层: 网络层"]
        FW[防火墙]
        LB[LoadBalancer]
    end
    
    subgraph Layer2["第 2 层: Ingress 层"]
        Traefik[Traefik Ingress]
        TLS[TLS 终止]
        WAF[WAF<br/>可选]
    end
    
    subgraph Layer3["第 3 层: 认证层"]
        BasicAuth[BasicAuth<br/>或 OAuth2]
        RateLimit[限流]
    end
    
    subgraph Layer4["第 4 层: 应用层"]
        Toolbox[Toolbox]
        AppAuth[内置认证<br/>可选]
    end
    
    subgraph Layer5["第 5 层: 网络策略层"]
        NetPolicy[NetworkPolicy]
    end
    
    subgraph Layer6["第 6 层: 数据层"]
        DB[(Database<br/>加密连接)]
    end
    
    Internet[互联网] --> FW
    FW --> LB
    LB --> TLS
    TLS --> WAF
    WAF --> Traefik
    Traefik --> BasicAuth
    BasicAuth --> RateLimit
    RateLimit --> Toolbox
    Toolbox --> AppAuth
    AppAuth --> NetPolicy
    NetPolicy --> DB
    
    style Internet fill:#ffe1e1
    style FW fill:#e1ffe1
    style TLS fill:#e1ffe1
    style BasicAuth fill:#e1ffe1
    style AppAuth fill:#e1ffe1
    style NetPolicy fill:#e1ffe1
    style DB fill:#ffe1e1
```

### 5.2 安全检查清单

#### 网络安全
- [ ] 启用 HTTPS/TLS
- [ ] 使用有效的 TLS 证书（Let's Encrypt）
- [ ] 配置 HTTPS 重定向
- [ ] 限制访问源 IP（如适用）
- [ ] 启用 NetworkPolicy

#### 认证和授权
- [ ] 启用认证（BasicAuth 或 OAuth2）
- [ ] 使用强密码（至少 16 位）
- [ ] 定期轮换密码（建议 90 天）
- [ ] 限制用户数量（最小权限原则）
- [ ] 启用审计日志

#### 应用安全
- [ ] 使用非 root 用户运行容器
- [ ] 启用 Pod Security Standards
- [ ] 配置资源限制
- [ ] 使用只读根文件系统（如可能）
- [ ] 禁用特权提升

#### 数据安全
- [ ] 使用 Secrets 存储敏感信息
- [ ] 启用数据库加密连接
- [ ] 定期备份配置
- [ ] 加密存储敏感数据
- [ ] 配置数据保留策略

#### 监控和响应
- [ ] 启用访问日志
- [ ] 配置告警规则
- [ ] 监控异常访问
- [ ] 制定事件响应计划
- [ ] 定期安全审计

---

## 6. 部署架构选择指南

### 场景 1: 个人开发者

**需求**: 
- 1 个用户
- 偶尔访问
- 成本敏感

**推荐架构**:
```
用户 → Traefik BasicAuth → Toolbox (1 replica) → Database
```

**部署**: `k8s/ingress/basic-auth/`

---

### 场景 2: 小团队（2-10 人）

**需求**:
- 多个用户
- 日常使用
- 需要基本安全

**推荐架构**:
```
团队成员 → OAuth2 Proxy (Google SSO) → Toolbox (2 replicas) → Database
```

**部署**: `k8s/ingress/oauth2-proxy/`

---

### 场景 3: 中型团队（10-50 人）

**需求**:
- 多团队
- 不同权限需求
- 需要审计

**推荐架构**:
```
用户 → API Gateway → Toolbox 内置认证 (多 authServices) → Database
      → BasicAuth   → (工具级 + 参数级授权)
```

**部署**: 组合 `ingress/basic-auth/` + Toolbox authServices

---

### 场景 4: 大型组织/企业

**需求**:
- 大规模用户
- 细粒度权限
- 合规要求
- 高可用

**推荐架构**:
```
用户 → API Gateway (Kong) → Service Mesh (Istio/mTLS) → Toolbox (HA) → Database (HA)
      → SSO (Okta/Azure AD)   → NetworkPolicy             → 多副本        → 主从复制
      → WAF                   → 监控和日志                → HPA
```

---

## 7. 成本和性能对比

| 方案 | CPU 开销 | 内存开销 | 延迟增加 | 运维成本 | 年度成本估算* |
|------|---------|----------|----------|----------|--------------|
| **无认证** | 0 | 0 | 0 ms | 低 | $0 |
| **BasicAuth** | <1% | ~10 MB | <1 ms | 低 | $0 |
| **OAuth2 Proxy** | ~5% | ~50 MB | ~10 ms | 中 | ~$50 |
| **Toolbox 内置** | ~3% | ~20 MB | ~20 ms | 中 | $0-100 (Google API 调用) |
| **Service Mesh** | ~15% | ~200 MB | ~5 ms | 高 | ~$500 |

*基于单节点 K3s，中等负载

---

## 8. 迁移路径

### 从无认证迁移到 BasicAuth

**停机时间**: 0 分钟

```bash
# 1. 创建认证配置（不影响现有服务）
kubectl apply -f k8s/ingress/basic-auth/middleware.yaml

# 2. 更新 Ingress（立即生效）
kubectl patch ingress toolbox-ingress -n mcp-toolbox -p \
  '{"metadata":{"annotations":{"traefik.ingress.kubernetes.io/router.middlewares":"mcp-toolbox-toolbox-basic-auth@kubernetescrd"}}}'

# 3. 更新客户端（添加认证 header）
# 4. 完成
```

### 从 BasicAuth 迁移到 OAuth2 Proxy

**停机时间**: ~5 分钟

```bash
# 1. 部署 OAuth2 Proxy
kubectl apply -f k8s/ingress/oauth2-proxy/

# 2. 更新 Ingress backend（指向 OAuth2 Proxy）
# 3. 测试
# 4. 删除 BasicAuth 配置
```

### 从 OAuth2 Proxy 迁移到 Toolbox 内置认证

**停机时间**: ~10 分钟

```bash
# 1. 配置 authServices 在 tools.yaml
# 2. 更新 Toolbox Deployment
# 3. 更新客户端（添加 ID token header）
# 4. 删除 OAuth2 Proxy
```

---

## 9. 参考资料

### 项目文档

- [K8s 部署总览](README.md)
- [5 分钟快速开始](QUICKSTART.md)
- [认证功能调研报告](../MCP_认证功能调研报告.md)
- [BasicAuth 详细指南](ingress/basic-auth/README.md)
- [客户端示例](examples/README.md)

### 外部资源

- [K3s 官方文档](https://docs.k3s.io/)
- [Traefik 文档](https://doc.traefik.io/traefik/)
- [OAuth2 Proxy 文档](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Istio 安全](https://istio.io/latest/docs/concepts/security/)

---

**文档版本**: 1.0  
**最后更新**: 2026-03-20  
**维护者**: MCP Toolbox Community
