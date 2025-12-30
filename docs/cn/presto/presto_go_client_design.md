<!--
- Licensed to the Apache Software Foundation (ASF) under one or more
- contributor license agreements.  See the NOTICE file distributed with
- this work for additional information regarding copyright ownership.
- The ASF licenses this file to You under the Apache License, Version 2.0
- (the "License"); you may not use this file except in compliance with
- the License.  You may obtain a copy of the License at
-
-   http://www.apache.org/licenses/LICENSE-2.0
-
- Unless required by applicable law or agreed to in writing, software
- distributed under the License is distributed on an "AS IS" BASIS,
- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
- See the License for the specific language governing permissions and
- limitations under the License.
-->

# Presto Go 客户端技术方案

## 1. 项目背景

### 1.1 原始需求

为 **[genai-toolbox](https://github.com/googleapis/genai-toolbox)** 项目添加 Presto (PrestoDB) 数据源支持，使 AI Agent 能够通过自然语言查询 Presto 中的数据。

### 1.2 genai-toolbox 简介

- Google 开源的 MCP (Model Context Protocol) Toolbox 项目
- 用 **Go 语言**开发
- 为 LLM/AI Agent 提供数据库工具集成
- 已支持：MySQL, PostgreSQL, MongoDB, Redis, BigQuery, Spanner, **Trino**, Kyuubi 等
- 项目地址：https://github.com/googleapis/genai-toolbox

### 1.3 核心问题

项目已经实现了 **Trino** 数据源支持，而 Presto 和 Trino 有着密切的历史关系。本文档的核心任务是：

1. **分析** Presto 和 Trino 的关系及兼容性
2. **评估** 是否可以复用现有的 Trino 方案
3. **给出** 最优的技术方案选型

## 2. Presto 与 Trino 的关系

### 2.1 历史背景

```
2012: Facebook 创建 Presto 项目
         ↓
2019: Presto 核心开发者离开 Facebook，创建 PrestoSQL 基金会
         ↓
2020.12: PrestoSQL 更名为 Trino（因商标争议）
         ↓
现在: 两个独立项目并行发展
      ├── PrestoDB (Facebook/Meta 维护)
      └── Trino (原创团队维护)
```

### 2.2 核心差异

| 对比项 | PrestoDB | Trino |
|--------|----------|-------|
| **维护方** | Facebook/Meta | Trino 社区（原 Presto 创始团队）|
| **GitHub** | github.com/prestodb/presto | github.com/trinodb/trino |
| **协议版本** | Presto Protocol | Trino Protocol |
| **默认端口** | 8080 | 8080 |
| **Go 客户端** | `prestodb/presto-go-client` | `trinodb/trino-go-client` |
| **活跃度** | 中等 | 高 |
| **社区支持** | Facebook 主导 | 社区主导 |

### 2.3 协议兼容性分析

#### 2.3.1 相似点

- 都使用 HTTP REST API
- 基本的 SQL 语法兼容
- 查询执行流程相似
- 都支持 `database/sql` 标准接口

#### 2.3.2 关键差异

| 差异项 | PrestoDB | Trino | 影响 |
|--------|----------|-------|------|
| **HTTP Header** | `X-Presto-*` | `X-Trino-*` | ⚠️ **不兼容** |
| **会话属性** | `X-Presto-Session` | `X-Trino-Session` | ⚠️ **不兼容** |
| **Catalog 声明** | `X-Presto-Catalog` | `X-Trino-Catalog` | ⚠️ **不兼容** |
| **Schema 声明** | `X-Presto-Schema` | `X-Trino-Schema` | ⚠️ **不兼容** |
| **用户声明** | `X-Presto-User` | `X-Trino-User` | ⚠️ **不兼容** |
| **错误格式** | Presto 格式 | Trino 格式 | 部分不兼容 |
| **新特性** | 较保守 | 更激进 | 功能差异 |

**结论**: HTTP Header 的命名差异导致 **Trino Go 客户端无法直接连接 PrestoDB 服务器**。

## 3. 现有 Trino 实现分析

### 3.1 项目中的 Trino 实现

genai-toolbox 项目已完整实现 Trino 支持：

**数据源**: `internal/sources/trino/trino.go`

```go
package trino

import (
    "database/sql"
    _ "github.com/trinodb/trino-go-client/trino"  // Trino 官方 Go 客户端
)

type Source struct {
    Config
    Pool *sql.DB
}

func (s *Source) TrinoDB() *sql.DB {
    return s.Pool
}
```

**工具**:
- `internal/tools/trino/trinosql/trinosql.go` - 预定义 SQL 查询
- `internal/tools/trino/trinoexecutesql/trinoexecutesql.go` - 执行任意 SQL

**依赖**: `github.com/trinodb/trino-go-client v0.330.0`

### 3.2 复用 Trino 方案的可行性

#### ❌ 直接复用：不可行

由于 HTTP Header 命名差异，**Trino Go 客户端无法连接 PrestoDB 服务器**：

```
Trino 客户端发送: X-Trino-User, X-Trino-Catalog, X-Trino-Schema
PrestoDB 期望:    X-Presto-User, X-Presto-Catalog, X-Presto-Schema
```

#### ✅ 代码结构复用：可行

虽然不能直接复用 Trino 客户端，但可以复用：
- 数据源架构模式
- 工具实现模式
- 配置结构
- 测试框架

## 4. 技术方案选型

### 4.1 方案概览

| 方案 | 说明 | 推荐度 |
|------|------|--------|
| **方案一** | 使用 PrestoDB 官方 Go 客户端 | ⭐⭐⭐⭐⭐ |
| **方案二** | Fork Trino 客户端修改 Header | ⭐⭐ |
| **方案三** | 从头实现 Presto 客户端 | ⭐ |

---

### 4.2 方案一：使用 PrestoDB 官方 Go 客户端（推荐 ⭐⭐⭐⭐⭐）

**技术栈**:
```
genai-toolbox (Go)
    ↓
github.com/prestodb/presto-go-client
    ↓
database/sql 标准接口
    ↓
PrestoDB Server (HTTP REST API)
```

**核心依赖**:
- `github.com/prestodb/presto-go-client` - PrestoDB 官方 Go 客户端

**优势**:
- ✅ **官方支持**: PrestoDB 官方维护的 Go 客户端
- ✅ **标准接口**: 实现 `database/sql` 标准接口
- ✅ **协议正确**: 使用正确的 `X-Presto-*` Header
- ✅ **架构一致**: 与 Trino 实现保持相同的架构模式
- ✅ **开发快速**: 1-2 周可完成
- ✅ **维护成本低**: 由官方维护

**劣势**:
- ❌ **需要新依赖**: 引入新的第三方库
- ❌ **代码重复**: 与 Trino 实现有部分代码重复

**实现示例**:

```go
package presto

import (
    "context"
    "database/sql"
    "fmt"
    "time"

    "github.com/goccy/go-yaml"
    "github.com/googleapis/genai-toolbox/internal/sources"
    _ "github.com/prestodb/presto-go-client/presto"  // PrestoDB 官方客户端
    "go.opentelemetry.io/otel/trace"
)

const SourceKind string = "presto"

// Config Presto 数据源配置
type Config struct {
    Name            string `yaml:"name" validate:"required"`
    Kind            string `yaml:"kind" validate:"required"`
    Host            string `yaml:"host" validate:"required"`
    Port            string `yaml:"port" validate:"required"`
    User            string `yaml:"user"`
    Password        string `yaml:"password"`
    Catalog         string `yaml:"catalog" validate:"required"`
    Schema          string `yaml:"schema" validate:"required"`
    QueryTimeout    string `yaml:"queryTimeout"`
    SSLEnabled      bool   `yaml:"sslEnabled"`
    SSLVerify       bool   `yaml:"sslVerify"`
}

// Source Presto 数据源
type Source struct {
    Config
    Pool *sql.DB
}

// PrestoDB 返回 Presto 数据库连接池
func (s *Source) PrestoDB() *sql.DB {
    return s.Pool
}

func (r Config) Initialize(ctx context.Context, tracer trace.Tracer) (sources.Source, error) {
    // 构建 DSN
    dsn := buildPrestoDSN(r)
    
    // 使用 presto-go-client 连接
    db, err := sql.Open("presto", dsn)
    if err != nil {
        return nil, fmt.Errorf("failed to open connection: %w", err)
    }

    // 配置连接池
    db.SetMaxOpenConns(10)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(time.Hour)

    // 验证连接
    if err := db.PingContext(ctx); err != nil {
        return nil, fmt.Errorf("unable to connect successfully: %w", err)
    }

    return &Source{Config: r, Pool: db}, nil
}

// buildPrestoDSN 构建 Presto DSN
// 格式: http://user@host:port/catalog/schema
func buildPrestoDSN(config Config) string {
    scheme := "http"
    if config.SSLEnabled {
        scheme = "https"
    }
    
    dsn := fmt.Sprintf("%s://%s@%s:%s/%s/%s",
        scheme,
        config.User,
        config.Host,
        config.Port,
        config.Catalog,
        config.Schema,
    )
    
    return dsn
}
```

---

### 4.3 方案二：Fork Trino 客户端修改 Header（不推荐 ⭐⭐）

**思路**: Fork `trinodb/trino-go-client`，将所有 `X-Trino-*` 替换为 `X-Presto-*`

**优势**:
- ✅ 代码改动小

**劣势**:
- ❌ **维护成本高**: 需要持续同步上游更新
- ❌ **不符合最佳实践**: 维护 Fork 是技术债务
- ❌ **无官方支持**: 出问题无法获得官方帮助
- ❌ **重复造轮子**: PrestoDB 已有官方 Go 客户端

**结论**: **不推荐**，因为 PrestoDB 已经有官方 Go 客户端。

---

### 4.4 方案三：从头实现（不推荐 ⭐）

**劣势**:
- ❌ 开发周期长（2-3 个月）
- ❌ 维护成本高
- ❌ 重复造轮子

**结论**: **不推荐**，没有必要。

## 5. 推荐方案详解

### 5.1 方案选择：使用 PrestoDB 官方 Go 客户端

**推荐理由**:

| 评估维度 | 评分 | 说明 |
|---------|------|------|
| **开发速度** | ⭐⭐⭐⭐⭐ | 1-2 周完成 |
| **维护成本** | ⭐⭐⭐⭐⭐ | 官方维护，零成本 |
| **功能完整性** | ⭐⭐⭐⭐⭐ | 官方客户端，功能完整 |
| **风险** | ⭐⭐⭐⭐⭐ | 低风险，成熟方案 |
| **架构一致性** | ⭐⭐⭐⭐⭐ | 与 Trino 实现保持一致 |

### 5.2 与 Trino 实现的关系

```
genai-toolbox
├── internal/sources/
│   ├── trino/
│   │   └── trino.go          # 使用 trinodb/trino-go-client
│   └── presto/
│       └── presto.go         # 使用 prestodb/presto-go-client
│
├── internal/tools/
│   ├── trino/
│   │   ├── trinosql/         # Trino SQL 工具
│   │   └── trinoexecutesql/  # Trino Execute SQL 工具
│   └── presto/
│       ├── prestosql/        # Presto SQL 工具（结构复用 Trino）
│       └── prestoexecutesql/ # Presto Execute SQL 工具（结构复用 Trino）
```

**代码复用策略**:
- ✅ **架构复用**: 数据源和工具的整体架构与 Trino 完全一致
- ✅ **模式复用**: 配置结构、接口定义、测试模式复用
- ❌ **客户端复用**: 不能复用，需要使用 PrestoDB 官方客户端

### 5.3 项目文件结构

```
genai-toolbox/
├── internal/
│   ├── sources/
│   │   └── presto/
│   │       ├── presto.go          # Presto 数据源实现
│   │       └── presto_test.go     # 单元测试
│   └── tools/
│       └── presto/
│           ├── prestosql/
│           │   ├── prestosql.go       # 预定义 SQL 查询工具
│           │   └── prestosql_test.go
│           └── prestoexecutesql/
│               ├── prestoexecutesql.go    # 执行任意 SQL 工具
│               └── prestoexecutesql_test.go
├── tests/
│   └── presto/
│       └── presto_integration_test.go  # 集成测试
├── docs/
│   └── cn/
│       └── presto/
│           └── presto_go_client_design.md  # 本文档
└── go.mod                              # 添加 presto-go-client 依赖
```

### 5.4 配置示例

```yaml
# tools.yaml
sources:
  # Presto 数据源
  my-presto:
    kind: presto
    host: presto-server.example.com
    port: 8080
    user: ${PRESTO_USER}
    catalog: hive
    schema: default
    queryTimeout: 5m
    sslEnabled: false

  # Trino 数据源（对比）
  my-trino:
    kind: trino
    host: trino-server.example.com
    port: 8080
    user: ${TRINO_USER}
    catalog: hive
    schema: default
    queryTimeout: 5m
    sslEnabled: false

tools:
  # Presto SQL 工具
  query-presto-data:
    kind: presto-sql
    source: my-presto
    description: 查询 Presto 数据
    statement: |
      SELECT * FROM {{.table_name}} 
      WHERE date >= '{{.start_date}}'
      LIMIT {{.limit}}
    templateParameters:
      - name: table_name
        type: string
        required: true
      - name: start_date
        type: string
        required: true
      - name: limit
        type: integer
        required: true

  # Presto Execute SQL 工具
  execute-presto-query:
    kind: presto-execute-sql
    source: my-presto
    description: 执行任意 Presto SQL 查询
```

## 6. 实施路线图

### 6.1 开发计划

| 阶段 | 时间 | 任务 | 交付物 |
|------|------|------|--------|
| **第一阶段** | 2-3 天 | 数据源实现 | `internal/sources/presto/` |
| **第二阶段** | 2-3 天 | 工具实现 | `internal/tools/presto/` |
| **第三阶段** | 2-3 天 | 测试 & 文档 | 测试用例、使用文档 |

**总计**: 1-2 周

### 6.2 第一阶段：数据源实现

```bash
# 1. 添加依赖
go get github.com/prestodb/presto-go-client

# 2. 创建数据源文件
internal/sources/presto/presto.go

# 3. 注册数据源
cmd/root.go
```

**核心代码** (`internal/sources/presto/presto.go`):

```go
package presto

import (
    "context"
    "database/sql"
    "fmt"
    "net/url"
    "time"

    "github.com/goccy/go-yaml"
    "github.com/googleapis/genai-toolbox/internal/sources"
    _ "github.com/prestodb/presto-go-client/presto"
    "go.opentelemetry.io/otel/trace"
)

const SourceKind string = "presto"

func init() {
    if !sources.Register(SourceKind, newConfig) {
        panic(fmt.Sprintf("source kind %q already registered", SourceKind))
    }
}

func newConfig(ctx context.Context, name string, decoder *yaml.Decoder) (sources.SourceConfig, error) {
    actual := Config{Name: name}
    if err := decoder.DecodeContext(ctx, &actual); err != nil {
        return nil, err
    }
    return actual, nil
}

// Config Presto 数据源配置
type Config struct {
    Name         string `yaml:"name" validate:"required"`
    Kind         string `yaml:"kind" validate:"required"`
    Host         string `yaml:"host" validate:"required"`
    Port         string `yaml:"port" validate:"required"`
    User         string `yaml:"user"`
    Password     string `yaml:"password"`
    Catalog      string `yaml:"catalog" validate:"required"`
    Schema       string `yaml:"schema" validate:"required"`
    QueryTimeout string `yaml:"queryTimeout"`
    SSLEnabled   bool   `yaml:"sslEnabled"`
    SSLVerify    bool   `yaml:"sslVerify"`
}

func (r Config) SourceConfigKind() string {
    return SourceKind
}

func (r Config) Initialize(ctx context.Context, tracer trace.Tracer) (sources.Source, error) {
    pool, err := initPrestoConnectionPool(ctx, tracer, r)
    if err != nil {
        return nil, fmt.Errorf("unable to create pool: %w", err)
    }

    err = pool.PingContext(ctx)
    if err != nil {
        return nil, fmt.Errorf("unable to connect successfully: %w", err)
    }

    return &Source{Config: r, Pool: pool}, nil
}

var _ sources.Source = &Source{}

// Source Presto 数据源
type Source struct {
    Config
    Pool *sql.DB
}

func (s *Source) SourceKind() string {
    return SourceKind
}

func (s *Source) ToConfig() sources.SourceConfig {
    return s.Config
}

// PrestoDB 返回 Presto 数据库连接池
func (s *Source) PrestoDB() *sql.DB {
    return s.Pool
}

func initPrestoConnectionPool(ctx context.Context, tracer trace.Tracer, config Config) (*sql.DB, error) {
    ctx, span := sources.InitConnectionSpan(ctx, tracer, SourceKind, config.Name)
    defer span.End()

    // 构建 Presto DSN
    dsn := buildPrestoDSN(config)

    db, err := sql.Open("presto", dsn)
    if err != nil {
        return nil, fmt.Errorf("failed to open connection: %w", err)
    }

    // 配置连接池
    db.SetMaxOpenConns(10)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(time.Hour)

    return db, nil
}

// buildPrestoDSN 构建 Presto DSN
// 格式: http://user@host:port/catalog/schema?query_params
func buildPrestoDSN(config Config) string {
    scheme := "http"
    if config.SSLEnabled {
        scheme = "https"
    }

    // 构建 URL
    u := &url.URL{
        Scheme: scheme,
        Host:   fmt.Sprintf("%s:%s", config.Host, config.Port),
        Path:   fmt.Sprintf("/%s/%s", config.Catalog, config.Schema),
    }

    // 设置用户
    if config.User != "" {
        u.User = url.User(config.User)
    }

    // 构建查询参数
    query := url.Values{}
    if config.SSLEnabled && !config.SSLVerify {
        query.Set("SSLVerification", "NONE")
    }
    if len(query) > 0 {
        u.RawQuery = query.Encode()
    }

    return u.String()
}
```

### 6.3 第二阶段：工具实现

**presto-sql 工具** (`internal/tools/presto/prestosql/prestosql.go`):

```go
package prestosql

import (
    "context"
    "database/sql"
    "fmt"

    yaml "github.com/goccy/go-yaml"
    "github.com/googleapis/genai-toolbox/internal/sources"
    "github.com/googleapis/genai-toolbox/internal/tools"
    "github.com/googleapis/genai-toolbox/internal/util/parameters"
)

const kind string = "presto-sql"

func init() {
    if !tools.Register(kind, newConfig) {
        panic(fmt.Sprintf("tool kind %q already registered", kind))
    }
}

// compatibleSource 定义兼容的数据源接口
type compatibleSource interface {
    PrestoDB() *sql.DB
}

type Config struct {
    Name               string                `yaml:"name" validate:"required"`
    Kind               string                `yaml:"kind" validate:"required"`
    Source             string                `yaml:"source" validate:"required"`
    Description        string                `yaml:"description" validate:"required"`
    Statement          string                `yaml:"statement" validate:"required"`
    AuthRequired       []string              `yaml:"authRequired"`
    Parameters         parameters.Parameters `yaml:"parameters"`
    TemplateParameters parameters.Parameters `yaml:"templateParameters"`
}

// ... 其余实现与 trinosql 类似，只需将 TrinoDB() 改为 PrestoDB()
```

### 6.4 第三阶段：测试 & 文档

**集成测试** (`tests/presto/presto_integration_test.go`):

```go
package presto_test

import (
    "context"
    "database/sql"
    "testing"
    "time"

    _ "github.com/prestodb/presto-go-client/presto"
)

func TestPrestoConnection(t *testing.T) {
    // 跳过集成测试（如果没有 Presto 服务器）
    if testing.Short() {
        t.Skip("Skipping integration test")
    }

    dsn := "http://test@localhost:8080/hive/default"
    db, err := sql.Open("presto", dsn)
    if err != nil {
        t.Fatalf("Failed to open connection: %v", err)
    }
    defer db.Close()

    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    // 测试简单查询
    rows, err := db.QueryContext(ctx, "SELECT 1")
    if err != nil {
        t.Fatalf("Failed to execute query: %v", err)
    }
    defer rows.Close()

    if !rows.Next() {
        t.Fatal("Expected at least one row")
    }

    var result int
    if err := rows.Scan(&result); err != nil {
        t.Fatalf("Failed to scan result: %v", err)
    }

    if result != 1 {
        t.Errorf("Expected 1, got %d", result)
    }
}
```

## 7. Presto vs Trino：选择指南

### 7.1 什么时候用 Presto？

- ✅ 公司已部署 PrestoDB
- ✅ 使用 Facebook/Meta 生态
- ✅ 需要与 PrestoDB 特定功能集成

### 7.2 什么时候用 Trino？

- ✅ 新项目或迁移项目
- ✅ 需要更活跃的社区支持
- ✅ 需要最新特性

### 7.3 genai-toolbox 的建议

| 场景 | 推荐 | 原因 |
|------|------|------|
| 已有 PrestoDB 集群 | **使用 Presto 数据源** | 协议兼容 |
| 已有 Trino 集群 | **使用 Trino 数据源** | 协议兼容 |
| 新建查询引擎 | **推荐 Trino** | 社区更活跃 |

## 8. 总结

### 8.1 核心结论

| 问题 | 答案 |
|------|------|
| **能否复用 Trino 客户端连接 Presto?** | ❌ 不能，HTTP Header 不兼容 |
| **能否复用 Trino 代码架构?** | ✅ 可以，架构模式完全可复用 |
| **推荐方案** | 使用 PrestoDB 官方 Go 客户端 |
| **开发周期** | 1-2 周 |
| **风险等级** | 低 |

### 8.2 方案对比总结

| 方案 | 可行性 | 开发时间 | 维护成本 | 推荐度 |
|------|--------|----------|----------|--------|
| **PrestoDB 官方客户端** | ✅ | 1-2 周 | 低 | ⭐⭐⭐⭐⭐ |
| Fork Trino 客户端 | ✅ | 1 周 | 高 | ⭐⭐ |
| 从头实现 | ✅ | 2-3 月 | 高 | ⭐ |

### 8.3 行动建议

1. **立即开始**: 使用 `prestodb/presto-go-client` 实现 Presto 数据源
2. **复用架构**: 参考 Trino 实现的架构模式
3. **独立维护**: Presto 和 Trino 作为两个独立的数据源维护
4. **文档完善**: 在文档中说明两者的区别和选择指南

## 9. 参考资源

### 9.1 官方文档

- [PrestoDB 官方文档](https://prestodb.io/docs/current/)
- [Trino 官方文档](https://trino.io/docs/current/)
- [PrestoDB Go 客户端](https://github.com/prestodb/presto-go-client)
- [Trino Go 客户端](https://github.com/trinodb/trino-go-client)

### 9.2 项目参考

- [genai-toolbox Trino 实现](https://github.com/googleapis/genai-toolbox)
- [Kyuubi Go 客户端技术方案](../kyuubi_go_client_design.md)

---

**文档版本**: v1.0  
**最后更新**: 2024-12-30  
**作者**: genai-toolbox Development Team

