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

package kyuubi

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	// 导入 gohive v2 驱动（使用修复后的 fork）
	// See: https://github.com/beltran/gohive/pull/259
	_ "github.com/beltran/gohive/v2"
	"github.com/goccy/go-yaml"
	"github.com/googleapis/genai-toolbox/internal/sources"
	"github.com/googleapis/genai-toolbox/internal/util"
	"go.opentelemetry.io/otel/trace"
)

const SourceKind string = "kyuubi"

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

// Config Kyuubi 数据源配置
type Config struct {
	Name          string            `yaml:"name" validate:"required"`
	Kind          string            `yaml:"kind" validate:"required"`
	Host          string            `yaml:"host" validate:"required"`
	Port          int               `yaml:"port" validate:"required"` // Kyuubi 默认端口 10009
	Username      string            `yaml:"username"`                 // 用户名
	Password      string            `yaml:"password"`                 // 密码
	Database      string            `yaml:"database"`                 // 默认数据库
	AuthType      string            `yaml:"authType"`                 // 认证类型: NONE, PLAIN, KERBEROS, LDAP
	QueryTimeout  string            `yaml:"queryTimeout"`             // 查询超时时间
	SessionConf   map[string]string `yaml:"sessionConf"`              // Kyuubi/Spark 会话配置
	TransportMode string            `yaml:"transportMode"`            // binary 或 http，默认 binary
}

func (r Config) SourceConfigKind() string {
	return SourceKind
}

func (r Config) Initialize(ctx context.Context, tracer trace.Tracer) (sources.Source, error) {
	// 初始化 Kyuubi 连接池
	pool, err := initKyuubiConnectionPool(ctx, tracer, r)
	if err != nil {
		return nil, fmt.Errorf("unable to create pool: %w", err)
	}

	// 验证连接
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

// Source Kyuubi 数据源
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

// KyuubiPool 返回 Kyuubi 数据库连接池
func (s *Source) KyuubiPool() *sql.DB {
	return s.Pool
}

// initKyuubiConnectionPool 初始化 Kyuubi 连接池
func initKyuubiConnectionPool(ctx context.Context, tracer trace.Tracer, config Config) (*sql.DB, error) {
	//nolint:all // Reassigned ctx
	ctx, span := sources.InitConnectionSpan(ctx, tracer, SourceKind, config.Name)
	defer span.End()

	// 设置默认值
	if config.Port == 0 {
		config.Port = 10009 // Kyuubi 默认端口
	}
	if config.Database == "" {
		config.Database = "default"
	}
	if config.AuthType == "" {
		config.AuthType = "NONE" // 支持: NOSASL, NONE, LDAP, CUSTOM, KERBEROS, DIGEST-MD5
	}
	if config.TransportMode == "" {
		config.TransportMode = "binary"
	}

	// 构建 DSN (Data Source Name)
	// 会话配置通过 DSN 传递给 gohive，gohive 会在打开会话时将其发送给 Kyuubi
	dsn := buildKyuubiDSN(config)

	// 使用 gohive v2 驱动打开连接
	// 注意: 使用修复后的 fork (silvermissile/gohive)，已修复 HiveConfiguration 传递问题
	// See: https://github.com/beltran/gohive/pull/259
	db, err := sql.Open("hive", dsn)
	if err != nil {
		return nil, fmt.Errorf("sql.Open: %w", err)
	}

	// 配置连接池
	// Kyuubi 连接启动慢，成本高，所以连接数不要太多
	db.SetMaxOpenConns(5)                   // 最大打开连接数
	db.SetMaxIdleConns(2)                   // 最大空闲连接数
	db.SetConnMaxLifetime(30 * time.Minute) // 连接最大生命周期

	// 验证连接
	if err := db.PingContext(ctx); err != nil {
		db.Close()
		return nil, fmt.Errorf("unable to connect successfully: %w", err)
	}

	// 日志记录会话配置
	if len(config.SessionConf) > 0 {
		logger, logErr := util.LoggerFromContext(ctx)
		if logErr == nil {
			logger.InfoContext(ctx, fmt.Sprintf("Kyuubi session config applied: %v", config.SessionConf))
		}
	}

	return db, nil
}

// buildKyuubiDSN 构建 Kyuubi DSN 字符串
// DSN 格式: hive://username:password@host:port/database?auth=AUTHTYPE&transport=MODE&key1=value1&key2=value2
// 会话配置（如 spark.executor.memory）通过 DSN 参数传递给 Kyuubi
// 参考: https://kyuubi.readthedocs.io/en/master/configuration/settings.html
func buildKyuubiDSN(config Config) string {
	// 基本格式: hive://username:password@host:port/database
	dsn := fmt.Sprintf("hive://%s:%s@%s:%d/%s",
		config.Username,
		config.Password,
		config.Host,
		config.Port,
		config.Database,
	)

	// 添加查询参数
	params := make([]string, 0)

	// 认证类型
	if config.AuthType != "" {
		params = append(params, fmt.Sprintf("auth=%s", config.AuthType))
	}

	// 传输模式 (gohive v2 使用 "transport" 参数名)
	if config.TransportMode != "" {
		params = append(params, fmt.Sprintf("transport=%s", config.TransportMode))
	}

	// 会话配置 - 包含 Kyuubi/Spark 配置参数
	// 这些配置会被 Kyuubi 用于启动 Spark 引擎
	for key, value := range config.SessionConf {
		params = append(params, fmt.Sprintf("%s=%s", key, value))
	}

	// 查询超时
	if config.QueryTimeout != "" {
		params = append(params, fmt.Sprintf("timeout=%s", config.QueryTimeout))
	}

	// 拼接参数
	if len(params) > 0 {
		dsn += "?"
		for i, param := range params {
			if i > 0 {
				dsn += "&"
			}
			dsn += param
		}
	}

	return dsn
}
