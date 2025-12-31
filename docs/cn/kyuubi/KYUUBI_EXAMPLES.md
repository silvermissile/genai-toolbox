# Kyuubi 使用示例

本文档提供 Kyuubi 数据源在 genai-toolbox 中的实际使用示例。

## 📋 目录

- [基础查询](#基础查询)
- [数据分析](#数据分析)
- [表管理](#表管理)
- [高级用法](#高级用法)

## 基础查询

### 示例 1: 简单查询

**配置文件** (`tools.yaml`):

```yaml
sources:
  my-kyuubi:
    kind: kyuubi
    host: localhost
    port: 10009
    database: default
    authType: NONE

tools:
  list-databases:
    kind: kyuubi-execute-sql
    source: my-kyuubi
    description: 列出所有数据库
```

**使用**:

```
用户: 列出所有数据库

AI Agent:
调用工具: list-databases
参数: {"sql": "SHOW DATABASES"}

返回:
[
  {"database": "default"},
  {"database": "sales"},
  {"database": "analytics"}
]
```

### 示例 2: 查询表数据

```yaml
tools:
  query-users:
    kind: kyuubi-sql
    source: my-kyuubi
    description: 查询用户表
    statement: |
      SELECT id, name, email, created_at
      FROM users
      LIMIT {{.limit}}
    templateParameters:
      - name: limit
        type: integer
        description: 返回记录数
        required: true
```

**使用**:

```
用户: 查询前 10 个用户

AI Agent:
调用工具: query-users
参数: {"limit": 10}

返回:
[
  {"id": 1, "name": "Alice", "email": "alice@example.com", "created_at": "2024-01-01"},
  {"id": 2, "name": "Bob", "email": "bob@example.com", "created_at": "2024-01-02"},
  ...
]
```

## 数据分析

### 示例 3: 销售数据分析

```yaml
tools:
  sales-by-date:
    kind: kyuubi-sql
    source: my-kyuubi
    description: 按日期统计销售数据
    statement: |
      SELECT 
        DATE(order_date) as date,
        COUNT(*) as order_count,
        SUM(amount) as total_amount,
        AVG(amount) as avg_amount
      FROM orders
      WHERE order_date BETWEEN '{{.start_date}}' AND '{{.end_date}}'
      GROUP BY DATE(order_date)
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

**使用**:

```
用户: 分析 2024 年 1 月的销售数据

AI Agent:
调用工具: sales-by-date
参数: {
  "start_date": "2024-01-01",
  "end_date": "2024-01-31"
}

返回:
[
  {
    "date": "2024-01-01",
    "order_count": 120,
    "total_amount": 15000.00,
    "avg_amount": 125.00
  },
  {
    "date": "2024-01-02",
    "order_count": 145,
    "total_amount": 18000.00,
    "avg_amount": 124.14
  },
  ...
]
```

### 示例 4: 用户行为分析

```yaml
tools:
  user-activity:
    kind: kyuubi-sql
    source: my-kyuubi
    description: 分析用户活动
    statement: |
      SELECT 
        user_id,
        COUNT(*) as event_count,
        COUNT(DISTINCT session_id) as session_count,
        MIN(timestamp) as first_event,
        MAX(timestamp) as last_event
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

**使用**:

```
用户: 分析用户 123 最近 30 天的活动

AI Agent:
调用工具: user-activity
参数: {
  "user_id": 123,
  "start_date": "2024-01-01"
}

返回:
[
  {
    "user_id": 123,
    "event_count": 456,
    "session_count": 23,
    "first_event": "2024-01-01 08:30:00",
    "last_event": "2024-01-30 22:15:00"
  }
]
```

## 表管理

### 示例 5: 创建表

```yaml
tools:
  manage-tables:
    kind: kyuubi-execute-sql
    source: my-kyuubi
    description: 管理数据库表
```

**使用**:

```
用户: 创建一个新表 test_table

AI Agent:
调用工具: manage-tables
参数: {
  "sql": "CREATE TABLE test_table (
    id INT,
    name STRING,
    created_at TIMESTAMP
  ) USING parquet"
}

返回: []
```

### 示例 6: 查看表结构

```
用户: 查看 users 表的结构

AI Agent:
调用工具: manage-tables
参数: {"sql": "DESCRIBE users"}

返回:
[
  {"col_name": "id", "data_type": "int", "comment": ""},
  {"col_name": "name", "data_type": "string", "comment": ""},
  {"col_name": "email", "data_type": "string", "comment": ""},
  {"col_name": "created_at", "data_type": "timestamp", "comment": ""}
]
```

### 示例 7: 插入数据

```
用户: 向 test_table 插入一条记录

AI Agent:
调用工具: manage-tables
参数: {
  "sql": "INSERT INTO test_table VALUES (1, 'Alice', current_timestamp())"
}

返回: []
```

## 高级用法

### 示例 8: 复杂聚合查询

```yaml
tools:
  product-sales-analysis:
    kind: kyuubi-sql
    source: my-kyuubi
    description: 产品销售分析（按类别）
    statement: |
      SELECT 
        p.category,
        COUNT(DISTINCT o.order_id) as order_count,
        COUNT(DISTINCT o.user_id) as customer_count,
        SUM(o.quantity) as total_quantity,
        SUM(o.amount) as total_revenue,
        AVG(o.amount) as avg_order_value
      FROM orders o
      JOIN products p ON o.product_id = p.id
      WHERE o.order_date >= '{{.start_date}}'
      GROUP BY p.category
      ORDER BY total_revenue DESC
    templateParameters:
      - name: start_date
        type: string
        description: 开始日期
        required: true
```

**使用**:

```
用户: 分析各类别产品的销售情况

AI Agent:
调用工具: product-sales-analysis
参数: {"start_date": "2024-01-01"}

返回:
[
  {
    "category": "Electronics",
    "order_count": 1250,
    "customer_count": 890,
    "total_quantity": 3200,
    "total_revenue": 450000.00,
    "avg_order_value": 360.00
  },
  {
    "category": "Clothing",
    "order_count": 2100,
    "customer_count": 1450,
    "total_quantity": 5800,
    "total_revenue": 280000.00,
    "avg_order_value": 133.33
  },
  ...
]
```

### 示例 9: 窗口函数

```yaml
tools:
  sales-ranking:
    kind: kyuubi-sql
    source: my-kyuubi
    description: 销售排名（使用窗口函数）
    statement: |
      SELECT 
        product_id,
        product_name,
        total_sales,
        RANK() OVER (ORDER BY total_sales DESC) as sales_rank,
        PERCENT_RANK() OVER (ORDER BY total_sales DESC) as percentile
      FROM (
        SELECT 
          p.id as product_id,
          p.name as product_name,
          SUM(o.amount) as total_sales
        FROM orders o
        JOIN products p ON o.product_id = p.id
        WHERE o.order_date >= '{{.start_date}}'
        GROUP BY p.id, p.name
      )
      ORDER BY sales_rank
      LIMIT {{.limit}}
    templateParameters:
      - name: start_date
        type: string
        description: 开始日期
        required: true
      - name: limit
        type: integer
        description: 返回记录数
        required: true
```

### 示例 10: 使用 Spark SQL 特性

```yaml
tools:
  analyze-json-data:
    kind: kyuubi-sql
    source: my-kyuubi
    description: 分析 JSON 数据
    statement: |
      SELECT 
        user_id,
        get_json_object(event_data, '$.event_type') as event_type,
        get_json_object(event_data, '$.page') as page,
        COUNT(*) as event_count
      FROM user_events
      WHERE date = '{{.date}}'
      GROUP BY 
        user_id,
        get_json_object(event_data, '$.event_type'),
        get_json_object(event_data, '$.page')
    templateParameters:
      - name: date
        type: string
        description: 日期 (YYYY-MM-DD)
        required: true
```

## 🔧 配置模板

### 完整配置示例

```yaml
# tools.yaml
sources:
  # 开发环境
  dev-kyuubi:
    kind: kyuubi
    host: localhost
    port: 10009
    database: default
    authType: NONE
    queryTimeout: 2m
  
  # 生产环境
  prod-kyuubi:
    kind: kyuubi
    host: kyuubi.prod.example.com
    port: 10009
    username: ${KYUUBI_USER}
    password: ${KYUUBI_PASSWORD}
    database: analytics
    authType: NONE    # 支持: NOSASL, NONE, LDAP, KERBEROS
    queryTimeout: 5m
    sessionConf:
      kyuubi.engine.share.level: USER
      spark.executor.memory: 2g
      spark.sql.adaptive.enabled: true

tools:
  # 通用查询工具
  execute-query:
    kind: kyuubi-execute-sql
    source: prod-kyuubi
    description: 执行任意 SQL 查询
  
  # 数据探索
  explore-table:
    kind: kyuubi-sql
    source: prod-kyuubi
    description: 探索表数据
    statement: |
      SELECT * FROM {{.table_name}} LIMIT {{.limit}}
    templateParameters:
      - name: table_name
        type: string
        description: 表名
        required: true
      - name: limit
        type: integer
        description: 返回记录数
        required: true
  
  # 业务查询
  daily-report:
    kind: kyuubi-sql
    source: prod-kyuubi
    description: 生成每日报告
    statement: |
      SELECT 
        DATE(timestamp) as date,
        metric_name,
        SUM(value) as total_value,
        AVG(value) as avg_value,
        MAX(value) as max_value,
        MIN(value) as min_value
      FROM metrics
      WHERE DATE(timestamp) = '{{.date}}'
      GROUP BY DATE(timestamp), metric_name
      ORDER BY metric_name
    templateParameters:
      - name: date
        type: string
        description: 日期 (YYYY-MM-DD)
        required: true
```

## 💡 最佳实践

### 1. 参数验证

```yaml
# 使用 required 确保必要参数
templateParameters:
  - name: user_id
    type: integer
    description: 用户 ID
    required: true  # ✅ 必填参数
```

### 2. 限制返回数据量

```yaml
# 始终使用 LIMIT
statement: |
  SELECT * FROM large_table
  LIMIT {{.limit}}  # ✅ 防止返回过多数据
```

### 3. 使用模板参数

```yaml
# ✅ 推荐：使用模板参数
statement: "SELECT * FROM {{.table}} WHERE id = {{.id}}"

# ❌ 不推荐：硬编码
statement: "SELECT * FROM users WHERE id = 123"
```

### 4. 添加超时控制

```yaml
sources:
  my-kyuubi:
    queryTimeout: 5m  # ✅ 设置合理的超时时间
```

### 5. 优化 Spark 配置

```yaml
sessionConf:
  spark.sql.adaptive.enabled: true           # ✅ 启用自适应查询
  spark.sql.shuffle.partitions: 200          # ✅ 合理的分区数
  spark.sql.autoBroadcastJoinThreshold: 10MB # ✅ 广播 join 阈值
```

## 📚 更多资源

- [Kyuubi 集成指南](./KYUUBI_README.md)
- [技术方案文档](./kyuubi_go_client_design.md)
- [Spark SQL 函数参考](https://spark.apache.org/docs/latest/sql-ref-functions.html)

