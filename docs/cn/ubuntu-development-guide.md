# Ubuntu 系统 Go 开发完整指南

本文档为 Ubuntu 24.04 LTS 系统上开发 MCP Toolbox for Databases 项目提供从零开始的完整指南。

---

## 🔑 关键信息速查

<details open>
<summary><b>Go 依赖管理机制（点击展开/收起）</b></summary>

### Go vs Python 依赖管理

| 问题 | Python | Go |
|------|--------|-----|
| **需要虚拟环境吗？** | ✅ 需要 (venv/virtualenv) | ❌ 不需要 |
| **依赖存储方式** | 每个项目独立副本 | **全局共享缓存** |
| **版本隔离方式** | 通过虚拟环境目录隔离 | 通过 go.mod 文件锁定版本 |
| **多项目同时开发** | 每个项目激活对应的 venv | 直接切换目录即可 |
| **版本冲突处理** | 虚拟环境隔离 | 同一包不同版本可共存于缓存 |
| **磁盘占用** | 重复存储，占用大 | 共享存储，占用小 |

### Go 依赖存储路径（重要！）

```bash
# 默认路径
GOPATH        → $HOME/go              # Go 工作区根目录
GOMODCACHE    → $HOME/go/pkg/mod     # 依赖包缓存（最重要，占用最大）
GOCACHE       → $HOME/.cache/go-build # 构建缓存

# 数据盘配置（推荐用于 /data）
GOPATH        → /data/go
GOMODCACHE    → /data/go/pkg/mod
GOCACHE       → /data/go/cache
```

### 如何设置到 /data 数据盘

在 `~/.bashrc` 中添加：
```bash
export GOPATH=/data/go
export GOMODCACHE=/data/go/pkg/mod
export GOCACHE=/data/go/cache
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin
export GOPROXY=https://goproxy.cn,direct
```

然后创建目录：
```bash
sudo mkdir -p /data/go/{bin,pkg,src,cache}
sudo chown -R $USER:$USER /data/go
```

</details>

---

## 📋 目录

- [🚀 快速开始](#-快速开始)
- [系统环境](#系统环境)
- [第一步：安装 Go 语言](#第一步安装-go-语言)
- [第二步：配置 Go 环境](#第二步配置-go-环境)
- [第三步：安装开发工具](#第三步安装开发工具)
- [第四步：获取项目依赖](#第四步获取项目依赖)
- [第五步：运行项目](#第五步运行项目)
- [第六步：开发工作流](#第六步开发工作流)
- [常见问题解决](#常见问题解决)
- [Cursor IDE 使用技巧](#cursor-ide-使用技巧)

---

## 🚀 快速开始

如果你想快速配置 Go 环境到 `/data` 数据盘，可以使用我们提供的自动配置脚本：

```bash
# 第一步：下载并安装 Go（需要手动执行）
cd /tmp
wget https://go.dev/dl/go1.25.5.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go1.25.5.linux-amd64.tar.gz

# 第二步：运行自动配置脚本（一键配置到数据盘）
bash /data/github/genai-toolbox/docs/cn/setup-go-data-disk.sh

# 第三步：使配置生效
source ~/.bashrc

# 第四步：验证安装
go version
go env GOPATH

# 第五步：下载项目依赖
cd /data/github/genai-toolbox
go mod download
```

详细说明请继续阅读下面的章节。

---

## 系统环境

**操作系统**: Ubuntu 24.04.3 LTS (Noble Numbat)  
**项目要求**: Go 1.24.7+ (推荐使用 Go 1.25.5)  
**已安装工具**: Docker, curl

---

## 第一步：安装 Go 语言

### 方法一：使用官方二进制安装（推荐）

这个方法可以安装最新版本的 Go，适合本项目需要的 Go 1.24.7+。

```bash
# 1. 下载 Go 1.25.5（或更新版本）
cd /tmp
wget https://go.dev/dl/go1.25.5.linux-amd64.tar.gz

# 2. 删除旧版本（如果存在）
sudo rm -rf /usr/local/go

# 3. 解压到 /usr/local
sudo tar -C /usr/local -xzf go1.25.5.linux-amd64.tar.gz

# 4. 验证安装
/usr/local/go/bin/go version
```

**预期输出**:
```
go version go1.25.5 linux/amd64
```

### 方法二：使用 APT 安装（不推荐，版本较旧）

Ubuntu 24.04 的 APT 仓库只提供 Go 1.21，**不满足项目要求**，不推荐使用。

```bash
# 仅供参考，不推荐
sudo apt update
sudo apt install golang-go
```

---

## 第二步：配置 Go 环境

### 1. 理解 Go 的依赖管理机制

在配置之前，先了解 Go 与 Python 的区别：

**Python vs Go 依赖管理对比**:

| 特性 | Python (venv) | Go (Go Modules) |
|------|---------------|-----------------|
| 隔离方式 | 虚拟环境，每个项目独立副本 | 全局缓存，所有项目共享依赖 |
| 版本管理 | requirements.txt | go.mod (自动版本锁定) |
| 存储位置 | 项目目录下的 venv/ | 全局 GOMODCACHE 目录 |
| 磁盘占用 | 重复存储，占用大 | 共享存储，占用小 |
| 版本冲突 | 通过隔离避免 | 同一包不同版本可共存 |

**Go 的三个重要路径**:

1. **GOPATH** (默认: `$HOME/go`)
   - Go 工作区根目录
   - 包含 `bin/`（可执行文件）、`pkg/`（编译缓存和模块）

2. **GOMODCACHE** (默认: `$GOPATH/pkg/mod`)
   - **最重要**：存储所有下载的依赖包
   - 所有项目共享此缓存
   - 占用空间最大

3. **GOCACHE** (默认: `$HOME/.cache/go-build`)
   - 构建缓存，加速编译

### 2. 配置环境变量

#### 方案一：使用数据盘 /data（推荐用于生产环境）

如果 `/data` 是你的数据盘，建议将 Go 的工作目录设置在此。

##### 🚀 快速配置（推荐）

我们提供了一键配置脚本，自动完成所有设置：

```bash
# 运行自动配置脚本
bash /data/github/genai-toolbox/docs/cn/setup-go-data-disk.sh
```

脚本会自动：
- ✅ 检查 /data 目录和磁盘空间
- ✅ 创建 Go 工作目录结构
- ✅ 备份原有配置文件
- ✅ 添加环境变量配置
- ✅ 可选：迁移已有的 Go 缓存
- ✅ 验证配置

##### 📝 手动配置

如果你想手动配置，按以下步骤操作：

**1. 编辑 shell 配置文件：**

```bash
# 如果使用 bash（Ubuntu 默认）
nano ~/.bashrc

# 如果使用 zsh
nano ~/.zshrc
```

**2. 在文件末尾添加以下内容：**

```bash
# Go 环境配置（数据盘方案）
export PATH=$PATH:/usr/local/go/bin

# 设置 GOPATH 到数据盘
export GOPATH=/data/go

# 设置模块缓存到数据盘（可选，默认在 GOPATH/pkg/mod）
export GOMODCACHE=/data/go/pkg/mod

# 设置构建缓存到数据盘（可选）
export GOCACHE=/data/go/cache

# 添加 Go 可执行文件路径
export PATH=$PATH:$GOPATH/bin

# Go 模块代理（可选，加速中国大陆下载）
export GOPROXY=https://goproxy.cn,direct
```

**3. 创建必要的目录：**

```bash
# 创建 Go 工作目录
sudo mkdir -p /data/go/{bin,pkg,src,cache}

# 设置所有权为当前用户
sudo chown -R $USER:$USER /data/go

# 验证目录权限
ls -la /data/go
```

#### 方案二：使用默认 HOME 目录（适合开发环境）

如果磁盘空间充足，可以使用默认配置：

```bash
# Go 环境配置（默认方案）
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin

# Go 模块代理（可选，加速中国大陆下载）
export GOPROXY=https://goproxy.cn,direct
```

### 3. 使配置生效

```bash
# 如果使用 bash
source ~/.bashrc

# 如果使用 zsh
source ~/.zshrc
```

### 4. 验证配置

```bash
# 检查 Go 版本
go version

# 查看所有 Go 环境变量
go env

# 验证关键路径配置
echo "GOPATH: $GOPATH"
go env GOPATH

echo "GOMODCACHE: $(go env GOMODCACHE)"
echo "GOCACHE: $(go env GOCACHE)"

# 检查目录是否存在
ls -la $GOPATH
```

**预期输出示例（数据盘方案）**:
```
GOPATH: /data/go
/data/go
GOMODCACHE: /data/go/pkg/mod
GOCACHE: /data/go/cache
```

### 5. 查看依赖存储空间使用情况

随着项目开发，依赖会逐渐增多，可以用以下命令查看占用空间：

```bash
# 查看 GOMODCACHE 大小（依赖包）
du -sh $(go env GOMODCACHE)

# 查看 GOCACHE 大小（构建缓存）
du -sh $(go env GOCACHE)

# 查看整个 GOPATH 大小
du -sh $GOPATH

# 详细查看各个子目录
du -h --max-depth=1 $GOPATH
```

### 6. 清理依赖缓存（如果需要）

如果需要清理缓存释放空间：

```bash
# 清理模块缓存（会删除所有下载的依赖）
go clean -modcache

# 清理构建缓存
go clean -cache

# 清理所有缓存
go clean -modcache -cache -testcache

# 之后需要重新下载依赖
cd /data/github/genai-toolbox
go mod download
```

---

## 第三步：安装开发工具

### 1. 安装 golangci-lint（代码检查工具）

```bash
# 使用官方安装脚本
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.62.2

# 验证安装
golangci-lint --version
```

### 2. 安装 Git（如果未安装）

```bash
# 检查是否已安装
git --version

# 如果未安装，执行以下命令
sudo apt update
sudo apt install git -y
```

### 3. 安装其他有用的工具

```bash
# 安装 make（可选，用于构建脚本）
sudo apt install build-essential -y

# 安装 jq（可选，用于处理 JSON）
sudo apt install jq -y
```

---

## 第四步：获取项目依赖

### 1. 理解 Go Modules 工作原理

本项目使用 **Go Modules** 进行依赖管理：

- **go.mod**: 定义项目依赖和版本要求
- **go.sum**: 记录依赖的校验和（类似 Python 的 lock 文件）
- 依赖下载到 **GOMODCACHE**（全局共享）
- 不同项目如果使用相同版本的依赖，**只下载一次**

### 2. 下载项目依赖

进入项目目录并下载所有依赖：

```bash
# 1. 进入项目根目录
cd /data/github/genai-toolbox

# 2. 查看项目需要的 Go 版本
head -n 5 go.mod

# 3. 下载所有依赖包（推荐先用这个）
go mod download

# 4. 或者使用 go get（会自动下载并更新）
go get -d ./...

# 5. 整理依赖（移除未使用的，添加缺失的）
go mod tidy

# 6. 验证依赖
go mod verify
```

**命令说明**:
- `go mod download`: 只下载依赖，不修改 go.mod
- `go get -d ./...`: 下载当前模块所需的所有依赖
- `go mod tidy`: 清理和更新依赖关系，移除未使用的包
- `go mod verify`: 验证依赖包的完整性和校验和

**预期输出**:
```
go: downloading github.com/spf13/cobra v1.10.1
go: downloading cloud.google.com/go/bigquery v1.72.0
go: downloading google.golang.org/api v0.256.0
...
all modules verified
```

### 3. 查看依赖信息

```bash
# 查看所有直接依赖
go list -m all

# 查看依赖树
go mod graph

# 查看特定包的信息
go list -m github.com/spf13/cobra

# 查看依赖包存储位置
go list -m -f '{{.Dir}}' github.com/spf13/cobra

# 查看项目的依赖统计
go list -m all | wc -l
```

### 4. 查看依赖占用空间

下载完依赖后，可以查看占用的磁盘空间：

```bash
# 查看模块缓存大小（这个项目依赖较多，可能有几百MB）
du -sh $(go env GOMODCACHE)

# 查看详细的依赖包
ls -lh $(go env GOMODCACHE)

# 列出最大的依赖包
du -sh $(go env GOMODCACHE)/* | sort -rh | head -10
```

本项目依赖包较多（包括 Google Cloud SDK、数据库驱动等），预计模块缓存大小约 **500MB-1GB**。

### 5. 依赖下载问题排查

如果下载缓慢或失败：

```bash
# 检查代理设置
go env GOPROXY

# 使用中国镜像加速
export GOPROXY=https://goproxy.cn,direct
go mod download

# 查看下载详细日志
go mod download -x

# 清理缓存后重新下载
go clean -modcache
go mod download
```

---

## 第五步：运行项目

### 1. 查看可用命令

```bash
# 查看所有命令行参数和帮助信息
go run . --help
```

### 2. 创建配置文件（可选）

根据你的需求创建 `tools.yaml` 配置文件。示例：

```bash
# 创建一个基本的配置文件
cat > tools.yaml << 'EOF'
# MCP Toolbox 配置示例
sources:
  # 在这里配置你的数据源
  
tools:
  # 在这里配置你的工具

EOF
```

详细配置请参考 [README.md](../../README.md#configuration)。

### 3. 启动开发服务器

```bash
# 启动服务器（默认监听 5000 端口）
go run .
```

**预期输出**:
```
INFO: Starting MCP Toolbox server on :5000
...
```

### 4. 测试服务器

在另一个终端窗口中：

```bash
# 测试服务器是否正常运行
curl http://127.0.0.1:5000

# 或者测试健康检查端点
curl http://127.0.0.1:5000/health
```

### 5. 停止服务器

在运行服务器的终端按 `Ctrl+C` 停止。

---

## 第六步：开发工作流

### 日常开发流程

```bash
# 1. 进入项目目录
cd /data/github/genai-toolbox

# 2. 拉取最新代码（如果是团队开发）
git pull

# 3. 更新依赖
go mod tidy

# 4. 修改代码...

# 5. 运行代码检查
golangci-lint run --fix

# 6. 运行单元测试
go test -race -v ./cmd/... ./internal/...

# 7. 本地运行测试
go run .

# 8. 构建二进制文件
go build -o toolbox

# 9. 运行构建的二进制
./toolbox
```

### 代码检查和测试

```bash
# 运行代码检查（自动修复问题）
golangci-lint run --fix

# 运行所有单元测试
go test -v ./...

# 运行单元测试（带竞态检测）
go test -race -v ./cmd/... ./internal/...

# 运行特定包的测试
go test -v ./internal/log/...

# 运行测试并显示覆盖率
go test -cover ./...

# 生成测试覆盖率报告
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html
```

### 构建项目

```bash
# 构建当前平台的二进制文件
go build -o toolbox

# 构建并指定输出路径
go build -o bin/toolbox

# 交叉编译（构建其他平台的二进制）
# Linux AMD64
GOOS=linux GOARCH=amd64 go build -o toolbox-linux-amd64

# macOS ARM64 (Apple Silicon)
GOOS=darwin GOARCH=arm64 go build -o toolbox-darwin-arm64

# Windows AMD64
GOOS=windows GOARCH=amd64 go build -o toolbox-windows-amd64.exe
```

### 使用 Docker

```bash
# 构建 Docker 镜像
docker build -t toolbox:dev .

# 查看构建的镜像
docker images | grep toolbox

# 运行容器
docker run -d -p 5000:5000 toolbox:dev

# 查看运行中的容器
docker ps

# 查看容器日志
docker logs <container_id>

# 停止容器
docker stop <container_id>
```

---

## 常见问题解决

### 问题 1: `go: command not found`

**原因**: Go 未正确安装或环境变量未配置。

**解决方案**:
```bash
# 检查 Go 是否安装
ls -la /usr/local/go/bin/go

# 如果存在，检查 PATH
echo $PATH | grep go

# 如果 PATH 中没有 Go，重新配置环境变量
export PATH=$PATH:/usr/local/go/bin
source ~/.bashrc
```

### 问题 2: 依赖下载失败或超时

**原因**: 网络问题或 Go 模块代理配置问题。

**解决方案**:
```bash
# 使用中国大陆镜像加速
export GOPROXY=https://goproxy.cn,direct

# 或使用其他镜像
export GOPROXY=https://goproxy.io,direct

# 重新下载依赖
go mod download

# 如果还有问题，清理缓存后重试
go clean -modcache
go mod download
```

### 问题 3: `permission denied` 错误

**原因**: 文件权限问题。

**解决方案**:
```bash
# 修改项目目录权限
sudo chown -R $USER:$USER /data/github/genai-toolbox

# 或者修改 GOPATH 权限
sudo chown -R $USER:$USER $HOME/go
```

### 问题 4: 端口 5000 已被占用

**原因**: 端口被其他程序占用。

**解决方案**:
```bash
# 查看占用端口的进程
sudo lsof -i :5000

# 或使用 ss 命令
ss -tulpn | grep 5000

# 杀死占用端口的进程
sudo kill -9 <PID>

# 或者使用不同的端口运行
go run . --port 8080
```

### 问题 5: 测试失败

**原因**: 可能需要特定的环境变量或数据库配置。

**解决方案**:
```bash
# 只运行单元测试，跳过集成测试
go test -short -v ./...

# 查看测试详细输出
go test -v -count=1 ./...

# 运行特定的测试函数
go test -v -run TestFunctionName ./...
```

### 问题 6: golangci-lint 安装失败

**原因**: 网络问题或权限问题。

**解决方案**:
```bash
# 方法一：使用 go install
go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# 方法二：手动下载二进制
cd /tmp
wget https://github.com/golangci/golangci-lint/releases/download/v1.62.2/golangci-lint-1.62.2-linux-amd64.tar.gz
tar -xzf golangci-lint-1.62.2-linux-amd64.tar.gz
sudo mv golangci-lint-1.62.2-linux-amd64/golangci-lint /usr/local/bin/
```

### 问题 7: 如何迁移已有的 Go 依赖到 /data 盘

**场景**: 已经在 `$HOME/go` 下载了依赖，想迁移到 `/data/go`。

**解决方案**:
```bash
# 1. 查看当前 GOPATH
echo $GOPATH

# 2. 如果已有 $HOME/go，可以直接移动
sudo mv $HOME/go /data/go

# 3. 设置所有权
sudo chown -R $USER:$USER /data/go

# 4. 更新环境变量（编辑 ~/.bashrc）
nano ~/.bashrc
# 添加：export GOPATH=/data/go

# 5. 使配置生效
source ~/.bashrc

# 6. 验证
go env GOPATH
```

### 问题 8: 不同项目需要不同版本的依赖怎么办

**解答**: Go Modules 自动处理版本隔离。

虽然所有项目共享 GOMODCACHE，但 Go 会：
- 在缓存中保存同一包的多个版本（如 `v1.2.3` 和 `v1.3.0`）
- 每个项目通过 `go.mod` 指定使用的版本
- 构建时自动使用正确的版本

**示例**:
```bash
# 项目 A 使用 cobra v1.8.0
# 项目 B 使用 cobra v1.10.1
# 两个版本都会存在于 GOMODCACHE 中：
# /data/go/pkg/mod/github.com/spf13/cobra@v1.8.0
# /data/go/pkg/mod/github.com/spf13/cobra@v1.10.1

# 查看缓存中的包版本
ls $(go env GOMODCACHE)/github.com/spf13/
```

### 问题 9: 如何查看和管理磁盘空间

**场景**: /data 盘空间有限，需要监控和清理。

**解决方案**:
```bash
# 查看 /data 磁盘使用情况
df -h /data

# 查看 Go 各部分占用空间
echo "=== Go 目录空间占用 ==="
du -sh $GOPATH
du -sh $(go env GOMODCACHE)
du -sh $(go env GOCACHE)

# 查看最大的模块包（前 20）
du -sh $(go env GOMODCACHE)/* 2>/dev/null | sort -rh | head -20

# 清理不需要的缓存
go clean -cache        # 清理构建缓存
go clean -modcache     # 清理所有模块（慎用）

# 只清理某个项目的依赖（不推荐，因为其他项目可能也用）
# rm -rf $(go env GOMODCACHE)/github.com/某个包
```

---

## Cursor IDE 使用技巧

### 1. Go 语言支持

Cursor 内置了 Go 语言支持（通过 `gopls`），提供以下功能：

- **智能代码补全**: 输入时自动提示
- **跳转到定义**: `F12` 或 `Ctrl+点击`
- **查找引用**: `Shift+F12`
- **重命名符号**: `F2`
- **格式化代码**: `Shift+Alt+F`

### 2. 集成终端

在 Cursor 中打开终端：

- **快捷键**: `` Ctrl+` `` (反引号)
- **菜单**: View → Terminal

在终端中可以直接运行 Go 命令：

```bash
go run .
go test ./...
go build
```

### 3. 调试配置

创建 `.vscode/launch.json` 文件用于调试：

```json
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "启动 Toolbox",
            "type": "go",
            "request": "launch",
            "mode": "auto",
            "program": "${workspaceFolder}",
            "args": [],
            "env": {},
            "showLog": true
        },
        {
            "name": "调试当前测试",
            "type": "go",
            "request": "launch",
            "mode": "test",
            "program": "${workspaceFolder}",
            "args": [
                "-test.v",
                "-test.run",
                "^${selectedText}$"
            ]
        }
    ]
}
```

### 4. 任务配置

创建 `.vscode/tasks.json` 文件用于快速执行常用命令：

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "运行项目",
            "type": "shell",
            "command": "go run .",
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "problemMatcher": ["$go"]
        },
        {
            "label": "运行测试",
            "type": "shell",
            "command": "go test -v ./...",
            "group": "test",
            "problemMatcher": ["$go"]
        },
        {
            "label": "代码检查",
            "type": "shell",
            "command": "golangci-lint run --fix",
            "problemMatcher": []
        },
        {
            "label": "构建项目",
            "type": "shell",
            "command": "go build -o toolbox",
            "group": "build",
            "problemMatcher": ["$go"]
        }
    ]
}
```

### 5. 推荐的 Cursor 扩展

虽然 Cursor 内置了 Go 支持，但以下扩展可以增强开发体验：

- **Go** (golang.go): 官方 Go 扩展
- **Go Test Explorer**: 可视化测试运行器
- **Error Lens**: 行内显示错误和警告
- **Better Comments**: 增强注释显示

### 6. AI 辅助开发技巧

利用 Cursor 的 AI 功能：

- **代码解释**: 选中代码，按 `Ctrl+L`，询问"解释这段代码"
- **生成测试**: 选中函数，询问"为这个函数生成单元测试"
- **代码重构**: 询问"如何优化这段代码的性能"
- **错误修复**: 选中错误代码，询问"这个错误如何修复"
- **文档生成**: 选中函数，询问"为这个函数生成中文注释"

### 7. 快捷键速查

| 功能 | 快捷键 |
|------|--------|
| 打开命令面板 | `Ctrl+Shift+P` |
| 快速打开文件 | `Ctrl+P` |
| 跳转到定义 | `F12` |
| 查找引用 | `Shift+F12` |
| 重命名符号 | `F2` |
| 格式化代码 | `Shift+Alt+F` |
| 打开终端 | `` Ctrl+` `` |
| AI 聊天 | `Ctrl+L` |
| 多光标编辑 | `Alt+点击` |
| 查找文件中的符号 | `Ctrl+Shift+O` |

### 8. 工作区设置

创建 `.vscode/settings.json` 文件优化 Go 开发体验：

```json
{
    "go.useLanguageServer": true,
    "go.lintTool": "golangci-lint",
    "go.lintOnSave": "workspace",
    "go.formatTool": "goimports",
    "editor.formatOnSave": true,
    "go.testFlags": ["-v", "-race"],
    "go.coverOnSave": false,
    "go.testTimeout": "30s",
    "[go]": {
        "editor.codeActionsOnSave": {
            "source.organizeImports": true
        }
    }
}
```

---

## 项目特定配置

### 配置文件位置

本项目需要一个 `tools.yaml` 配置文件，通常放在项目根目录：

```bash
/data/github/genai-toolbox/tools.yaml
```

### 环境变量

根据你使用的数据源，可能需要设置以下环境变量：

```bash
# Google Cloud 认证
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"

# 项目 ID
export GCP_PROJECT_ID="your-project-id"

# 其他数据库连接信息
export DATABASE_URL="postgresql://user:password@localhost:5432/dbname"
```

可以创建一个 `.env` 文件（不要提交到 Git）：

```bash
# 创建 .env 文件
cat > .env << 'EOF'
GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
GCP_PROJECT_ID=your-project-id
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
EOF

# 加载环境变量
source .env
```

---

## 下一步

1. ✅ 完成 Go 环境安装和配置
2. ✅ 熟悉基本的开发工作流
3. 📖 阅读 [项目 README](../../README.md) 了解项目架构
4. 📖 阅读 [DEVELOPER.md](../../DEVELOPER.md) 了解详细开发指南
5. 🔧 根据需求配置 `tools.yaml`
6. 🚀 开始开发！

---

## 参考资源

- [Go 官方文档](https://go.dev/doc/)
- [Go 语言之旅](https://go.dev/tour/)
- [Effective Go](https://go.dev/doc/effective_go)
- [MCP Toolbox 文档](https://googleapis.github.io/genai-toolbox/)
- [项目 GitHub 仓库](https://github.com/googleapis/genai-toolbox)

---

## 获取帮助

如果遇到问题：

1. 查看本文档的 [常见问题解决](#常见问题解决) 部分
2. 查看项目的 [GitHub Issues](https://github.com/googleapis/genai-toolbox/issues)
3. 加入 [Discord 社区](https://discord.gg/Dmm69peqjh)
4. 阅读 [Medium 博客](https://medium.com/@mcp_toolbox)

---

**文档版本**: 1.0  
**最后更新**: 2025-12-22  
**适用系统**: Ubuntu 24.04 LTS  
**适用项目版本**: MCP Toolbox for Databases (所有版本)

