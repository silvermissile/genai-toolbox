# Kyuubi 快速开始

5 分钟快速上手 Kyuubi 数据源！

## ⚡ 快速开始

### 步骤 1: 配置数据源

创建 `tools.yaml` 文件：

```yaml
sources:
  my-kyuubi:
    kind: kyuubi
    host: localhost              # 你的 Kyuubi 服务器地址
    port: 10009                  # Kyuubi 端口
    database: default            # 数据库名
    authType: NONE               # 认证类型（开发环境）
```

### 步骤 2: 创建工具

在同一个 `tools.yaml` 文件中添加：

```yaml
tools:
  # 执行任意 SQL
  run-query:
    kind: kyuubi-execute-sql
    source: my-kyuubi
    description: 执行 SQL 查询
```

### 步骤 3: 启动服务

```bash
genai-toolbox server --config tools.yaml
```

### 步骤 4: 在 AI Agent 中使用

```
用户: 列出所有数据库

AI Agent:
调用工具: run-query
参数: {"sql": "SHOW DATABASES"}

返回:
[
  {"database": "default"},
  {"database": "sales"},
  {"database": "analytics"}
]
```

## 🎯 常用场景

### 场景 1: 查询表数据

```yaml
tools:
  query-users:
    kind: kyuubi-sql
    source: my-kyuubi
    description: 查询用户表
    statement: |
      SELECT * FROM users LIMIT {{.limit}}
    templateParameters:
      - name: limit
        type: integer
        required: true
```

**使用**:
```
用户: 查询前 10 个用户
AI: 调用 query-users，参数 {"limit": 10}
```

### 场景 2: 数据统计

```yaml
tools:
  sales-summary:
    kind: kyuubi-sql
    source: my-kyuubi
    description: 销售数据统计
    statement: |
      SELECT 
        DATE(order_date) as date,
        COUNT(*) as orders,
        SUM(amount) as revenue
      FROM orders
      WHERE order_date >= '{{.start_date}}'
      GROUP BY DATE(order_date)
    templateParameters:
      - name: start_date
        type: string
        required: true
```

**使用**:
```
用户: 统计最近 7 天的销售数据
AI: 调用 sales-summary，参数 {"start_date": "2024-01-01"}
```

## 🔐 生产环境配置

### 使用认证

```yaml
sources:
  prod-kyuubi:
    kind: kyuubi
    host: kyuubi.prod.example.com
    port: 10009
    username: ${KYUUBI_USER}      # ✅ 从环境变量读取
    password: ${KYUUBI_PASSWORD}  # ✅ 不要硬编码密码
    database: production
    authType: NONE                # 使用用户名/密码认证 (或 LDAP)
    queryTimeout: 5m              # 设置查询超时
```

### 优化配置

```yaml
sources:
  prod-kyuubi:
    kind: kyuubi
    host: kyuubi.prod.example.com
    port: 10009
    username: ${KYUUBI_USER}
    password: ${KYUUBI_PASSWORD}
    authType: NONE    # 支持: NOSASL, NONE, LDAP, KERBEROS
    queryTimeout: 5m
    sessionConf:
      # Kyuubi 引擎配置
      kyuubi.engine.share.level: USER
      # Spark 优化配置
      spark.sql.adaptive.enabled: true
      spark.sql.shuffle.partitions: 200
```

## 📚 下一步

- 📖 阅读[完整集成指南](./KYUUBI_README.md)了解所有配置选项
- 💡 查看[使用示例](./KYUUBI_EXAMPLES.md)学习更多场景
- 🔧 参考[配置示例](./kyuubi-example-tools.yaml)获取完整配置

## 🆘 遇到问题？

### 连接失败

```bash
# 检查 Kyuubi 服务是否运行
curl http://kyuubi-server:10009

# 检查网络连接
telnet kyuubi-server 10009
```

### 查询超时

```yaml
# 增加超时时间
sources:
  my-kyuubi:
    queryTimeout: 10m  # 从 5m 增加到 10m
```

### 认证失败

```yaml
# 检查认证配置
sources:
  my-kyuubi:
    authType: NONE    # 支持: NOSASL, NONE, LDAP, KERBEROS           # 确保类型正确
    username: correct-user    # 检查用户名
    password: correct-pass    # 检查密码
```

## 📞 获取帮助

- 📖 [完整文档](./KYUUBI_README.md)
- 💬 [GitHub Issues](https://github.com/googleapis/genai-toolbox/issues)
- 🌐 [Kyuubi 官方文档](https://kyuubi.readthedocs.io/)

