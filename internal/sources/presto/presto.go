// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Presto 数据源实现
// 使用 PrestoDB 官方 Go 客户端 (github.com/prestodb/presto-go-client)
// 通过 database/sql 标准接口连接 PrestoDB 服务器
package presto

import (
	"context"
	"database/sql"
	"fmt"
	"net/url"
	"time"

	"github.com/goccy/go-yaml"
	"github.com/googleapis/genai-toolbox/internal/sources"
	_ "github.com/prestodb/presto-go-client/presto" // PrestoDB 官方 Go 客户端
	"go.opentelemetry.io/otel/trace"
)

const SourceKind string = "presto"

// validate interface
var _ sources.SourceConfig = Config{}

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
	Name            string `yaml:"name" validate:"required"`
	Kind            string `yaml:"kind" validate:"required"`
	Host            string `yaml:"host" validate:"required"`    // Presto 服务器地址
	Port            string `yaml:"port" validate:"required"`    // Presto 服务器端口（默认 8080）
	User            string `yaml:"user"`                        // 用户名
	Password        string `yaml:"password"`                    // 密码（可选，用于基础认证）
	Catalog         string `yaml:"catalog" validate:"required"` // Catalog 名称
	Schema          string `yaml:"schema" validate:"required"`  // Schema 名称
	QueryTimeout    string `yaml:"queryTimeout"`                // 查询超时时间
	SSLEnabled      bool   `yaml:"sslEnabled"`                  // 是否启用 SSL
	SSLVerify       bool   `yaml:"sslVerify"`                   // 是否验证 SSL 证书
	KerberosEnabled bool   `yaml:"kerberosEnabled"`             // 是否启用 Kerberos 认证
	Source          string `yaml:"source"`                      // 查询来源标识（可选）
	SessionProps    string `yaml:"sessionProps"`                // 会话属性（逗号分隔的 key=value）
	ExtraCredential string `yaml:"extraCredential"`             // 额外凭证
}

func (r Config) SourceConfigKind() string {
	return SourceKind
}

func (r Config) Initialize(ctx context.Context, tracer trace.Tracer) (sources.Source, error) {
	pool, err := initPrestoConnectionPool(ctx, tracer, r.Name, r)
	if err != nil {
		return nil, fmt.Errorf("unable to create pool: %w", err)
	}

	err = pool.PingContext(ctx)
	if err != nil {
		return nil, fmt.Errorf("unable to connect successfully: %w", err)
	}

	s := &Source{
		Config: r,
		Pool:   pool,
	}
	return s, nil
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

// initPrestoConnectionPool 初始化 Presto 连接池
func initPrestoConnectionPool(ctx context.Context, tracer trace.Tracer, name string, config Config) (*sql.DB, error) {
	//nolint:all // Reassigned ctx
	ctx, span := sources.InitConnectionSpan(ctx, tracer, SourceKind, name)
	defer span.End()

	// 构建 Presto DSN
	dsn, err := buildPrestoDSN(config)
	if err != nil {
		return nil, fmt.Errorf("failed to build DSN: %w", err)
	}

	db, err := sql.Open("presto", dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to open connection: %w", err)
	}

	// 配置连接池
	// Presto 是无状态查询引擎，连接开销相对较小
	db.SetMaxOpenConns(10)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(time.Hour)

	return db, nil
}

// buildPrestoDSN 构建 Presto DSN
// DSN 格式: http://user@host:port/catalog/schema?query_params
// 或 https://user:password@host:port/catalog/schema?query_params
func buildPrestoDSN(config Config) (string, error) {
	// 构建查询参数
	query := url.Values{}

	// 查询超时
	if config.QueryTimeout != "" {
		query.Set("query_timeout", config.QueryTimeout)
	}

	// SSL 验证
	if config.SSLEnabled && !config.SSLVerify {
		query.Set("SSL_verification", "NONE")
	}

	// Kerberos 认证
	if config.KerberosEnabled {
		query.Set("kerberos_enabled", "true")
	}

	// 查询来源标识
	if config.Source != "" {
		query.Set("source", config.Source)
	}

	// 会话属性
	if config.SessionProps != "" {
		query.Set("session_properties", config.SessionProps)
	}

	// 额外凭证
	if config.ExtraCredential != "" {
		query.Set("extra_credentials", config.ExtraCredential)
	}

	// 构建 URL
	scheme := "http"
	if config.SSLEnabled {
		scheme = "https"
	}

	u := &url.URL{
		Scheme:   scheme,
		Host:     fmt.Sprintf("%s:%s", config.Host, config.Port),
		Path:     fmt.Sprintf("/%s/%s", config.Catalog, config.Schema),
		RawQuery: query.Encode(),
	}

	// 设置用户和密码
	if config.User != "" && config.Password != "" {
		u.User = url.UserPassword(config.User, config.Password)
	} else if config.User != "" {
		u.User = url.User(config.User)
	}

	return u.String(), nil
}
