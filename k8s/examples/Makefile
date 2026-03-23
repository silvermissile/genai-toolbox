# Makefile for MCP Toolbox 客户端示例

.PHONY: help test-auth run-python run-go setup clean

# 默认目标
help:
	@echo "MCP Toolbox 客户端示例"
	@echo "======================"
	@echo ""
	@echo "可用命令:"
	@echo "  make setup       - 安装依赖和配置环境"
	@echo "  make test-auth   - 测试认证是否工作"
	@echo "  make run-python  - 运行 Python 示例"
	@echo "  make run-go      - 运行 Go 示例"
	@echo "  make clean       - 清理临时文件"
	@echo ""
	@echo "使用前请配置环境变量:"
	@echo "  cp .env.example .env"
	@echo "  nano .env  # 编辑配置"

# 设置环境
setup:
	@echo "安装 Python 依赖..."
	pip install toolbox-core python-dotenv
	@echo "检查 Go 依赖..."
	go mod tidy || true
	@echo "复制环境变量模板..."
	test -f .env || cp .env.example .env
	@echo ""
	@echo "✓ 设置完成！"
	@echo "请编辑 .env 文件配置实际的连接信息"

# 测试认证
test-auth:
	@echo "测试 Toolbox 认证..."
	@bash ./test-auth.sh

# 运行 Python 示例
run-python:
	@echo "运行 Python 客户端示例..."
	python3 python-client-basicauth.py

# 运行 Go 示例
run-go:
	@echo "运行 Go 客户端示例..."
	go run go-client-basicauth.go

# 清理
clean:
	@echo "清理临时文件..."
	rm -f *.tmp *.log
	@echo "✓ 清理完成"
