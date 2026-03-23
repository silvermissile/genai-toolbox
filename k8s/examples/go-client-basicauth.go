package main

// MCP Toolbox Go 客户端示例
// 使用 BasicAuth 连接到 K8s 部署的 Toolbox 服务
//
// 依赖安装:
//   go get github.com/googleapis/mcp-toolbox-sdk-go/core

import (
	"context"
	"encoding/base64"
	"fmt"
	"log"
	"os"

	"github.com/googleapis/mcp-toolbox-sdk-go/core"
)

// createBasicAuthHeader 创建 HTTP Basic Auth header
func createBasicAuthHeader(username, password string) map[string]string {
	auth := base64.StdEncoding.EncodeToString(
		[]byte(fmt.Sprintf("%s:%s", username, password)),
	)
	return map[string]string{
		"Authorization": fmt.Sprintf("Basic %s", auth),
	}
}

// example1BasicUsage 示例 1: 基本使用
func example1BasicUsage(ctx context.Context, url, username, password string) error {
	fmt.Println("\n=== 示例 1: 基本使用 ===")

	// 创建认证 header
	headers := createBasicAuthHeader(username, password)

	// 创建客户端
	client, err := core.NewToolboxClient(url, core.WithHeaders(headers))
	if err != nil {
		return fmt.Errorf("创建客户端失败: %w", err)
	}

	// 加载所有工具
	tools, err := client.LoadToolset("", ctx)
	if err != nil {
		return fmt.Errorf("加载工具失败: %w", err)
	}

	fmt.Printf("已加载 %d 个工具\n", len(tools))
	for _, tool := range tools {
		fmt.Printf("  - %s: %s\n", tool.Name(), tool.Description())
	}

	return nil
}

// example2InvokeTool 示例 2: 调用特定工具
func example2InvokeTool(ctx context.Context, url, username, password string) error {
	fmt.Println("\n=== 示例 2: 调用工具 ===")

	headers := createBasicAuthHeader(username, password)
	client, err := core.NewToolboxClient(url, core.WithHeaders(headers))
	if err != nil {
		return err
	}

	// 加载特定工具
	tool, err := client.LoadTool("list-tables", ctx)
	if err != nil {
		return fmt.Errorf("加载工具失败: %w", err)
	}

	// 调用工具
	result, err := tool.Invoke(ctx, nil)
	if err != nil {
		return fmt.Errorf("调用工具失败: %w", err)
	}

	fmt.Printf("查询结果: %v\n", result)
	return nil
}

// example3WithParameters 示例 3: 带参数调用工具
func example3WithParameters(ctx context.Context, url, username, password string) error {
	fmt.Println("\n=== 示例 3: 带参数调用 ===")

	headers := createBasicAuthHeader(username, password)
	client, err := core.NewToolboxClient(url, core.WithHeaders(headers))
	if err != nil {
		return err
	}

	// 加载需要参数的工具
	tool, err := client.LoadTool("query-data", ctx)
	if err != nil {
		return fmt.Errorf("加载工具失败: %w", err)
	}

	// 调用工具并传递参数
	params := map[string]any{
		"table_name": "users",
		"limit":      10,
	}
	result, err := tool.Invoke(ctx, params)
	if err != nil {
		return fmt.Errorf("调用工具失败: %w", err)
	}

	fmt.Printf("查询结果: %v\n", result)
	return nil
}

// example4ErrorHandling 示例 4: 错误处理
func example4ErrorHandling(ctx context.Context, url, username string) error {
	fmt.Println("\n=== 示例 4: 错误处理 ===")

	// 使用错误的密码
	headers := createBasicAuthHeader(username, "wrong-password")
	client, err := core.NewToolboxClient(url, core.WithHeaders(headers))
	if err != nil {
		return err
	}

	// 尝试加载工具（应该失败）
	_, err = client.LoadToolset("", ctx)
	if err != nil {
		fmt.Printf("预期的错误: %v\n", err)
		fmt.Println("这是正常的 - 密码错误应该被拒绝")
		return nil
	}

	return fmt.Errorf("应该认证失败但却成功了")
}

// ToolboxClient 封装了认证的客户端
type ToolboxClient struct {
	client *core.ToolboxClient
}

// NewToolboxClient 创建认证客户端
func NewToolboxClient(url, username, password string) (*ToolboxClient, error) {
	headers := createBasicAuthHeader(username, password)
	client, err := core.NewToolboxClient(url, core.WithHeaders(headers))
	if err != nil {
		return nil, err
	}
	return &ToolboxClient{client: client}, nil
}

// GetTool 获取特定工具
func (tc *ToolboxClient) GetTool(ctx context.Context, name string) (*core.Tool, error) {
	return tc.client.LoadTool(name, ctx)
}

// ListTools 列出所有工具
func (tc *ToolboxClient) ListTools(ctx context.Context) ([]*core.Tool, error) {
	return tc.client.LoadToolset("", ctx)
}

// example5ReusableClient 示例 5: 可复用的客户端类
func example5ReusableClient(ctx context.Context, url, username, password string) error {
	fmt.Println("\n=== 示例 5: 封装客户端类 ===")

	// 创建客户端
	client, err := NewToolboxClient(url, username, password)
	if err != nil {
		return err
	}

	// 使用客户端
	tools, err := client.ListTools(ctx)
	if err != nil {
		return err
	}

	fmt.Printf("通过封装客户端加载了 %d 个工具\n", len(tools))
	return nil
}

func main() {
	fmt.Println("MCP Toolbox Go 客户端示例")
	fmt.Println("================================")

	// 从环境变量读取配置
	url := os.Getenv("TOOLBOX_URL")
	username := os.Getenv("TOOLBOX_USER")
	password := os.Getenv("TOOLBOX_PASSWORD")

	// 检查环境变量
	if url == "" || username == "" || password == "" {
		fmt.Println("\n错误: 请设置环境变量")
		fmt.Println("  export TOOLBOX_URL=https://toolbox.example.com")
		fmt.Println("  export TOOLBOX_USER=admin")
		fmt.Println("  export TOOLBOX_PASSWORD=your-password")
		fmt.Println("\n或在命令行设置:")
		fmt.Println("  TOOLBOX_URL=https://toolbox.example.com \\")
		fmt.Println("  TOOLBOX_USER=admin \\")
		fmt.Println("  TOOLBOX_PASSWORD=your-password \\")
		fmt.Println("  go run go-client-basicauth.go")
		os.Exit(1)
	}

	ctx := context.Background()

	// 运行示例
	if err := example1BasicUsage(ctx, url, username, password); err != nil {
		log.Printf("示例 1 失败: %v", err)
	}

	// 取消注释运行其他示例
	// if err := example2InvokeTool(ctx, url, username, password); err != nil {
	// 	log.Printf("示例 2 失败: %v", err)
	// }

	// if err := example3WithParameters(ctx, url, username, password); err != nil {
	// 	log.Printf("示例 3 失败: %v", err)
	// }

	// if err := example4ErrorHandling(ctx, url, username); err != nil {
	// 	log.Printf("示例 4 失败: %v", err)
	// }

	// if err := example5ReusableClient(ctx, url, username, password); err != nil {
	// 	log.Printf("示例 5 失败: %v", err)
	// }

	fmt.Println("\n完成!")
}
