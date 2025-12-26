# Kyuubi 数据源集成指南

## 📖 简介

本文档介绍如何在 genai-toolbox 项目中使用 Kyuubi 数据源，通过 AI Agent 查询 Kyuubi/Spark SQL 数据。

## 🎯 什么是 Kyuubi?

[Apache Kyuubi](https://kyuubi.apache.org/) 是一个分布式多租户网关，为数据仓库和数据湖提供 Serverless SQL 能力。Kyuubi 支持：

- **多引擎**: Spark SQL, Flink SQL, Hive, Trino 等
- **多租户**: 用户级别的引擎隔离
- **高可用**: 支持 ZooKeeper 服务发现
- **认证**: NONE, PLAIN, LDAP, KERBEROS
- **协议**: HiveServer2 Thrift 协议

## 🚀 快速开始

### 1. 配置数据源

在 `tools.yaml` 中添加 Kyuubi 数据源配置：

```yaml
sources:
  my-kyuubi:
    kind: kyuubi
    host: kyuubi-server.example.com
    port: 10009                    # Kyuubi 默认端口
    username: ${KYUUBI_USER}       # 从环境变量读取
    password: ${KYUUBI_PASSWORD}
    database: default              # 默认数据库
    authType: NONE                 # 认证类型 (NOSASL/NONE/LDAP/CUSTOM/KERBEROS)
    queryTimeout: 5m               # 查询超时时间
    sessionConf:                   # Kyuubi/Spark 会话配置
      kyuubi.engine.share.level: USER
      spark.sql.shuffle.partitions: "200"
```

### 2. 创建 SQL 工具

#### 方式一：使用 kyuubi-sql（推荐）

适用于预定义的 SQL 查询：

```yaml
tools:
  query-sales-data:
    kind: kyuubi-sql
    source: my-kyuubi
    description: 查询销售数据
    statement: |
      SELECT 
        date,
        SUM(amount) as total_sales,
        COUNT(*) as transaction_count
      FROM sales
      WHERE date BETWEEN '{{.start_date}}' AND '{{.end_date}}'
      GROUP BY date
      ORDER BY date
    templateParameters:
      - name: start_date
        type: string
        description: 开始日期 (YYYY-MM-DD)
        required: true
      - name: end_date
        type: string
        description: 结束日期 (YYYY-MM-DD)
        required: true
```

#### 方式二：使用 kyuubi-execute-sql

适用于执行任意 SQL 语句：

```yaml
tools:
  execute-kyuubi-query:
    kind: kyuubi-execute-sql
    source: my-kyuubi
    description: 执行任意 Kyuubi SQL 查询
```

### 3. 使用示例

#### 使用 MCP 客户端

```json
{
  "mcpServers": {
    "genai-toolbox": {
      "command": "genai-toolbox",
      "args": ["server", "--config", "tools.yaml"]
    }
  }
}
```

#### 在 AI Agent 中使用

```
用户: 查询 2024 年 1 月的销售数据

AI Agent 调用:
- Tool: query-sales-data
- Parameters:
  - start_date: "2024-01-01"
  - end_date: "2024-01-31"

返回结果:
[
  {"date": "2024-01-01", "total_sales": 15000, "transaction_count": 120},
  {"date": "2024-01-02", "total_sales": 18000, "transaction_count": 145},
  ...
]
```

## 🔧 配置详解

### 数据源配置项

| 配置项 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `kind` | string | ✅ | - | 固定为 `kyuubi` |
| `host` | string | ✅ | - | Kyuubi 服务器地址 |
| `port` | int | ✅ | 10009 | Kyuubi 服务器端口 |
| `username` | string | ❌ | - | 用户名 |
| `password` | string | ❌ | - | 密码 |
| `database` | string | ❌ | default | 默认数据库 |
| `authType` | string | ❌ | NONE | 认证类型 |
| `queryTimeout` | string | ❌ | - | 查询超时（如 `5m`, `30s`） |
| `sessionConf` | map | ❌ | - | Kyuubi/Spark 会话配置 |
| `transportMode` | string | ❌ | binary | 传输模式（`binary` 或 `http`） |

### 认证类型

#### NONE（无认证）

适用于开发测试环境：

```yaml
sources:
  dev-kyuubi:
    kind: kyuubi
    host: localhost
    port: 10009
    authType: NONE
```

#### PLAIN（用户名/密码）

适用于基础认证：

```yaml
sources:
  prod-kyuubi:
    kind: kyuubi
    host: kyuubi.example.com
    port: 10009
    username: ${KYUUBI_USER}
    password: ${KYUUBI_PASSWORD}
    authType: NONE    # 支持: NOSASL, NONE, LDAP, KERBEROS
```

#### KERBEROS

适用于企业安全环境：

```yaml
sources:
  secure-kyuubi:
    kind: kyuubi
    host: kyuubi.example.com
    port: 10009
    authType: KERBEROS
    sessionConf:
      kyuubi.frontend.protocols: THRIFT_BINARY
```

**注意**：Kerberos 认证需要配置 Kerberos 客户端环境。

### 会话配置

可以通过 `sessionConf` 配置 Kyuubi 和 Spark 参数：

```yaml
sessionConf:
  # Kyuubi 引擎配置
  kyuubi.engine.share.level: USER        # 引擎共享级别
  kyuubi.engine.type: SPARK_SQL          # 引擎类型
  
  # Spark 配置
  spark.executor.memory: 2g              # Executor 内存
  spark.executor.cores: 2                # Executor 核心数
  spark.sql.shuffle.partitions: 200      # Shuffle 分区数
  spark.sql.adaptive.enabled: true       # 启用自适应查询执行
```

## 🔍 工具类型

### kyuubi-sql

**用途**: 预定义的参数化 SQL 查询

**特点**:
- ✅ 支持模板参数（`{{.param}}`）
- ✅ 参数类型验证
- ✅ 安全的参数替换
- ✅ 适合重复使用的查询

**配置示例**:

```yaml
tools:
  user-activity-report:
    kind: kyuubi-sql
    source: my-kyuubi
    description: 生成用户活动报告
    statement: |
      SELECT 
        user_id,
        COUNT(*) as activity_count,
        MAX(timestamp) as last_activity
      FROM user_events
      WHERE user_id = {{.user_id}}
        AND timestamp >= '{{.start_date}}'
      GROUP BY user_id
    templateParameters:
      - name: user_id
        type: integer
        description: 用户 ID
        required: true
      - name: start_date
        type: string
        description: 开始日期
        required: true
```

### kyuubi-execute-sql

**用途**: 执行任意 SQL 语句

**特点**:
- ✅ 灵活执行任意 SQL
- ✅ 支持 DDL, DML, DQL
- ✅ 适合动态查询场景

**配置示例**:

```yaml
tools:
  run-kyuubi-query:
    kind: kyuubi-execute-sql
    source: my-kyuubi
    description: 执行任意 Kyuubi SQL 查询
```

**使用示例**:

```
用户: 创建一个新表 test_table

AI Agent 调用:
- Tool: run-kyuubi-query
- Parameters:
  - sql: "CREATE TABLE test_table (id INT, name STRING)"
```

## 📊 数据类型支持

Kyuubi/Spark SQL 支持的数据类型会自动映射到 Go 类型：

| Spark SQL 类型 | Go 类型 | 说明 |
|----------------|---------|------|
| BOOLEAN | bool | 布尔值 |
| TINYINT, SMALLINT, INT | int | 整数 |
| BIGINT | int64 | 长整数 |
| FLOAT, DOUBLE | float64 | 浮点数 |
| STRING | string | 字符串 |
| DATE | string | 日期（ISO 格式） |
| TIMESTAMP | string | 时间戳（ISO 格式） |
| BINARY | []byte | 二进制数据 |
| DECIMAL | string | 十进制数（字符串表示） |
| ARRAY | []any | 数组 |
| MAP | map[string]any | 映射 |
| STRUCT | map[string]any | 结构体 |

## ⚙️ 连接池配置

Kyuubi 数据源使用连接池来管理数据库连接：

```go
// 默认连接池配置
MaxOpenConns: 5              // 最大打开连接数（Kyuubi 连接成本高）
MaxIdleConns: 2              // 最大空闲连接数
ConnMaxLifetime: 30分钟      // 连接最大生命周期
```

**为什么连接数较少？**

- Kyuubi 连接启动慢（需要启动 Spark 引擎，10-30 秒）
- 每个连接消耗大量资源（关联一个 Spark 应用）
- 连接复用能显著提升性能

## 🔒 安全最佳实践

### 1. 使用环境变量

不要在配置文件中硬编码密码：

```yaml
# ❌ 不推荐
password: mypassword123

# ✅ 推荐
password: ${KYUUBI_PASSWORD}
```

### 2. 限制查询权限

使用专用的只读账户：

```yaml
sources:
  readonly-kyuubi:
    kind: kyuubi
    host: kyuubi.example.com
    username: ${READONLY_USER}
    password: ${READONLY_PASSWORD}
    # 该用户只有 SELECT 权限
```

### 3. 设置查询超时

防止长时间运行的查询：

```yaml
sources:
  my-kyuubi:
    kind: kyuubi
    queryTimeout: 5m  # 5 分钟超时
```

### 4. 使用认证

生产环境应启用认证：

```yaml
# 开发环境
authType: NONE

# 生产环境
authType: NONE    # 支持: NOSASL, NONE, LDAP, KERBEROS  # 或 KERBEROS, LDAP
```

## 🐛 故障排查

### 连接失败

**症状**: `unable to connect successfully`

**可能原因**:
1. Kyuubi 服务未启动
2. 网络不通
3. 端口错误
4. 认证失败

**解决方法**:
```bash
# 检查 Kyuubi 服务状态
curl http://kyuubi-server:10009

# 测试网络连接
telnet kyuubi-server 10009

# 检查认证配置
# 确保 username/password 正确
```

### 查询超时

**症状**: `query timeout`

**可能原因**:
1. 查询数据量太大
2. Spark 引擎资源不足
3. 超时时间设置过短

**解决方法**:
```yaml
# 增加超时时间
queryTimeout: 10m

# 优化 Spark 配置
sessionConf:
  spark.sql.adaptive.enabled: true
  spark.sql.shuffle.partitions: 200
```

### 引擎启动慢

**症状**: 第一次查询很慢（10-30 秒）

**原因**: Kyuubi 需要启动 Spark 引擎

**解决方法**:
```yaml
# 使用引擎共享
sessionConf:
  kyuubi.engine.share.level: USER  # 用户级别共享
  # 或
  kyuubi.engine.share.level: CONNECTION  # 连接级别共享
```

### 内存不足

**症状**: `OutOfMemoryError`

**解决方法**:
```yaml
sessionConf:
  spark.executor.memory: 4g      # 增加 Executor 内存
  spark.driver.memory: 2g        # 增加 Driver 内存
  spark.sql.shuffle.partitions: 400  # 增加分区数
```

## 🏗️ 技术架构

### 为什么大数据系统也使用 database/sql？

虽然 Kyuubi/Hive/Presto/Spark SQL 等大数据系统**不支持事务**，但本项目仍然使用 Go 的 `database/sql` 标准接口，原因如下：

#### 1. 连接池管理 - 最重要

大数据系统的连接建立成本极高（通常需要 1-5 秒），连接池能：
- ✅ 复用连接，避免频繁创建/销毁
- ✅ 控制并发连接数，防止资源耗尽
- ✅ 在 AI Agent 场景下显著提升性能

```go
// 自动连接池配置
db.SetMaxOpenConns(5)              // 最多 5 个连接
db.SetMaxIdleConns(2)              // 保持 2 个空闲连接
db.SetConnMaxLifetime(30*time.Minute)  // 30 分钟后回收
```

#### 2. 超时控制

AI Agent 可能生成失控的查询（如笛卡尔积），必须有超时保护：

```go
// 自动超时控制
ctx, cancel := context.WithTimeout(ctx, 5*time.Minute)
rows, err := db.QueryContext(ctx, sql)  // 5 分钟后自动取消
```

#### 3. 统一 API

genai-toolbox 支持 20+ 种数据源，使用 `database/sql` 可以：
- ✅ 所有 SQL 数据源使用相同接口
- ✅ 工具代码跨数据源复用
- ✅ 降低维护成本

#### 4. 安全性

通过参数化查询防止 SQL 注入：

```go
// ✅ 安全：自动转义参数
db.QueryContext(ctx, "SELECT * FROM users WHERE name = ?", userInput)

// ❌ 危险：字符串拼接
sql := fmt.Sprintf("SELECT * FROM users WHERE name = '%s'", userInput)
```

#### 项目中的证据

在 genai-toolbox 中，所有不支持事务的大数据系统都使用 `database/sql`：

| 数据源 | 支持事务 | 使用 database/sql | 主要原因 |
|--------|---------|-------------------|----------|
| Trino | ❌ | ✅ | 连接池 + 超时控制 |
| ClickHouse | ❌ | ✅ | 连接池 + 统一 API |
| Kyuubi | ❌ | ✅ | 连接池 + 统一 API |

**详细技术分析请参考**: [实现总结文档](./KYUUBI_IMPLEMENTATION_SUMMARY.md#为什么大数据系统也需要-databasesql)

## 📚 参考资料

### 官方文档

- [Kyuubi 官方文档](https://kyuubi.readthedocs.io/)
- [Kyuubi GitHub](https://github.com/apache/kyuubi)
- [Spark SQL 文档](https://spark.apache.org/sql/)

### 相关项目

- [gohive v1.8.1](https://github.com/beltran/gohive) - Go HiveServer2 客户端
- [genai-toolbox](https://github.com/googleapis/genai-toolbox) - MCP Toolbox

### 技术方案

详细的技术设计和方案对比，请参考：
- [Kyuubi Go 客户端技术方案](./kyuubi_go_client_design.md)

## 🤝 贡献

欢迎贡献代码和文档！

## 📄 许可证

Apache License 2.0

