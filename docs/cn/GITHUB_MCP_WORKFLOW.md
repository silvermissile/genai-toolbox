# GitHub MCP Server 工作流程指南

## 在别人的项目中创建 Issue、解决并提交 PR 的完整流程（本地开发场景）

本文档说明如何使用 GitHub MCP Server 的工具在别人的项目中创建 issue、在本地 IDE 中开发并提交 PR。

## GitHub Token 权限配置

在使用 GitHub MCP Server 之前，你需要创建一个 Personal Access Token (PAT) 并配置正确的权限。

### 创建 Token 步骤

1. 访问 GitHub Settings → Developer settings → Personal access tokens → **Fine-grained tokens** (推荐) 或 **Tokens (classic)**
2. 点击 "Generate new token"
3. 选择以下权限

### 所需权限清单

#### Fine-grained tokens (推荐使用)

| 权限类别 | 访问级别 | 说明 | 对应工具 |
|---------|---------|------|---------|
| **Issues** | Read and write | 创建、编辑、评论 issue | `create_issue`, `add_issue_comment`, `update_issue` |
| **Pull requests** | Read and write | 创建、编辑 PR | `create_pull_request`, `update_pull_request` |
| **Contents** | Read-only | 读取仓库内容和信息 | `get_repository`, `get_file_contents` |
| **Metadata** | Read-only | 读取仓库元数据（自动包含） | 所有工具 |

**注意**：Fork 操作通常需要账户级别的权限，Fine-grained token 可能需要额外配置。

#### Classic tokens (传统方式)

如果使用 Classic token，至少需要以下 scopes：

```
✅ repo (完整仓库访问权限)
   ├── repo:status          - 访问提交状态
   ├── repo_deployment      - 访问部署状态
   ├── public_repo          - 访问公共仓库（如果只操作公共仓库）
   └── repo:invite          - 访问仓库邀请
   
推荐选择整个 repo scope 以确保所有功能正常工作
```

**最小权限配置**（仅用于公共仓库）：
```
✅ public_repo  - 访问公共仓库
```

### 权限与操作对应表

| MCP 工具 | 所需权限 (Fine-grained) | 所需权限 (Classic) |
|---------|----------------------|------------------|
| `create_issue` | Issues: Read and write | `public_repo` 或 `repo` |
| `fork_repository` | 账户级别权限 | `repo` |
| `create_pull_request` | Pull requests: Read and write | `public_repo` 或 `repo` |
| `add_issue_comment` | Issues: Read and write | `public_repo` 或 `repo` |
| `get_repository` | Metadata: Read-only | `public_repo` 或 `repo` |
| `update_issue` | Issues: Read and write | `public_repo` 或 `repo` |
| `update_pull_request` | Pull requests: Read and write | `public_repo` 或 `repo` |

### Token 配置建议

**场景 1：仅操作公共仓库**
- Classic Token: 选择 `public_repo`
- Fine-grained Token: 配置 Issues 和 Pull requests 为 Read and write

**场景 2：需要操作私有仓库**
- Classic Token: 选择完整的 `repo` scope
- Fine-grained Token: 配置相应私有仓库的访问权限

**场景 3：最大兼容性（推荐）**
- Classic Token: 选择完整的 `repo` scope
- 这样可以确保所有功能（包括 fork）都能正常工作

### 配置 GitHub MCP Server

创建 token 后，在 MCP 配置文件中设置：

```json
{
  "mcpServers": {
    "github": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-e",
        "GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here",
        "ghcr.io/github/github-mcp-server"
      ]
    }
  }
}
```

或者设置环境变量：
```bash
export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here
```

---

## 核心工具清单（仅需 4-5 个 MCP 工具）

**必需的 GitHub MCP 工具**：
1. `create_issue` - 创建 issue
2. `fork_repository` - Fork 仓库
3. `create_pull_request` - 创建 PR

**可选的 GitHub MCP 工具**：
4. `add_issue_comment` - 在 issue 中添加评论
5. `get_repository` - 获取仓库信息

**本地使用 Git 命令**：代码修改、分支创建、提交、推送等都在本地完成

---

## 详细工具说明

### 第一阶段：创建 Issue

1. **`create_issue`** - 创建 issue
   - 参数：
     - `owner`: 仓库所有者（必需）
     - `repo`: 仓库名称（必需）
     - `title`: Issue 标题（必需）
     - `body`: Issue 描述（可选）
     - `labels`: 标签列表（可选）
     - `assignees`: 分配人员列表（可选）

### 第二阶段：Fork 仓库

2. **`fork_repository`** - Fork 仓库到你的账户
   - 参数：
     - `owner`: 原始仓库所有者（必需）
     - `repo`: 仓库名称（必需）
     - `organization`: 如果要 fork 到组织（可选）

3. **`get_repository`** - 获取仓库信息（可选）
   - 参数：
     - `owner`: 仓库所有者（必需）
     - `repo`: 仓库名称（必需）
   - 用途：了解仓库的默认分支等信息

### 第三阶段：本地开发（使用 Git 命令，不需要 MCP 工具）

**在本地 Cursor IDE 中完成所有代码开发工作**：

| Git 操作 | 命令示例 | 说明 |
|---------|---------|------|
| Clone 仓库 | `git clone https://github.com/your-username/repo-name.git` | 将你 fork 的仓库克隆到本地 |
| 添加上游仓库 | `git remote add upstream https://github.com/original-owner/repo-name.git` | 便于后续同步原始仓库 |
| 创建分支 | `git checkout -b fix-xxx-issue` | 基于当前分支创建新分支 |
| 修改代码 | 在 Cursor IDE 中编辑 | 使用 IDE 的所有功能 |
| 查看状态 | `git status` | 查看哪些文件被修改 |
| 添加更改 | `git add .` 或 `git add <file>` | 暂存要提交的更改 |
| 提交更改 | `git commit -m "描述信息"` | 提交到本地仓库 |
| 推送分支 | `git push origin fix-xxx-issue` | 推送到你的 GitHub fork 仓库 |

> **为什么本地开发不用 MCP 工具？**
> - 本地 Git 命令更快、更灵活
> - IDE 提供了丰富的代码编辑功能
> - 可以进行本地测试和调试
> - GitHub MCP 的文件操作需要 base64 编码，不如本地直接编辑方便

### 第四阶段：创建 Pull Request

4. **`create_pull_request`** - 创建 Pull Request
   - 参数：
     - `owner`: 仓库所有者（必需）
     - `repo`: 仓库名称（必需）
     - `title`: PR 标题（必需）
     - `head`: 源分支（你的 fork 的分支，格式：`your-username:branch-name`）（必需）
     - `base`: 目标分支（原始仓库的分支，通常是 `main` 或 `master`）（必需）
     - `body`: PR 描述（可选）
     - `draft`: 是否为草稿 PR（可选）
     - `maintainer_can_modify`: 维护者是否可以修改（可选）

5. **`update_pull_request`** - 更新 Pull Request（如果需要修改 PR 信息）
   - 参数：
     - `owner`: 仓库所有者（必需）
     - `repo`: 仓库名称（必需）
     - `pull_number`: PR 编号（必需）
     - `title`: 新标题（可选）
     - `body`: 新描述（可选）
     - `state`: 状态（`open` 或 `closed`）（可选）
     - `base`: 新目标分支（可选）

### 第五阶段：关联和管理 Issue

6. **`add_issue_comment`** - 在 Issue 中添加评论
   - 参数：
     - `owner`: 仓库所有者（必需）
     - `repo`: 仓库名称（必需）
     - `issue_number`: Issue 编号（必需）
     - `body`: 评论内容（必需）
   - 用途：在 PR 创建后，可以在 issue 中评论说明已创建 PR

7. **`update_issue`** - 更新 Issue
   - 参数：
     - `owner`: 仓库所有者（必需）
     - `repo`: 仓库名称（必需）
     - `issue_number`: Issue 编号（必需）
     - `state`: 状态（`open` 或 `closed`）（可选）
     - `labels`: 标签列表（可选）
   - 用途：在 PR 合并后，可以关闭 issue

## 完整工作流程示例

### 步骤 1: 使用 GitHub MCP - 创建 Issue
```
使用 MCP 工具: create_issue
- owner: "original-owner"
- repo: "repo-name"
- title: "修复 XXX 问题"
- body: "详细描述问题..."
```

### 步骤 2: 使用 GitHub MCP - Fork 仓库
```
使用 MCP 工具: fork_repository
- owner: "original-owner"
- repo: "repo-name"
```

### 步骤 3: 本地开发 - Clone 和创建分支
```bash
# Clone 你 fork 的仓库
git clone https://github.com/your-username/repo-name.git
cd repo-name

# 添加原始仓库为 upstream（便于后续同步）
git remote add upstream https://github.com/original-owner/repo-name.git

# 创建新分支
git checkout -b fix-xxx-issue
```

### 步骤 4: 本地开发 - 修改代码
在 Cursor IDE 中修改代码，解决 issue 中提到的问题。

### 步骤 5: 本地开发 - 提交和推送
```bash
# 查看修改
git status

# 添加更改
git add .

# 提交更改
git commit -m "修复 XXX 问题"

# 推送到你的 fork 仓库
git push origin fix-xxx-issue
```

### 步骤 6: 使用 GitHub MCP - 创建 Pull Request
```
使用 MCP 工具: create_pull_request
- owner: "original-owner"
- repo: "repo-name"
- title: "修复 XXX 问题"
- head: "your-username:fix-xxx-issue"
- base: "main"
- body: "此 PR 修复了 #<issue_number> 中提到的问题\n\n主要更改：\n- 修复了 xxx\n- 添加了 yyy"
```

### 步骤 7: 使用 GitHub MCP - 在 Issue 中添加评论（可选）
```
使用 MCP 工具: add_issue_comment
- owner: "original-owner"
- repo: "repo-name"
- issue_number: <issue编号>
- body: "已创建 PR #<pr_number> 来解决此问题"
```

## 注意事项

1. **Token 安全**：
   - ⚠️ **永远不要**将 token 提交到代码仓库
   - 使用环境变量或配置文件存储 token
   - 定期轮换（更换）你的 token
   - 如果 token 泄露，立即在 GitHub 删除并重新生成
   - 为 token 设置合理的过期时间

2. **权限要求**：
   - 创建 issue：需要 Issues 读写权限
   - Fork 仓库：需要账户级别的 repo 权限
   - 本地开发：需要 Git 环境和 SSH/HTTPS 认证
   - 创建 PR：需要 Pull requests 读写权限
   - 推送代码：需要对你的 fork 仓库有写入权限（通过 Git 认证）

3. **分支命名**：
   - 建议使用描述性的分支名称，如 `fix-xxx-issue` 或 `feature-xxx`
   - 遵循项目的分支命名规范（如果有）

4. **PR 描述最佳实践**：
   - 在 PR 描述中使用 `Fixes #<issue_number>` 或 `Closes #<issue_number>` 可以自动关联 issue
   - 当 PR 合并时，关联的 issue 会自动关闭
   - 清晰描述你做了什么更改，为什么这样更改
   - 如果有测试，说明如何测试

5. **PR head 参数格式**：
   - 格式必须是：`your-username:branch-name`
   - `your-username` 是你的 GitHub 用户名
   - `branch-name` 是你推送代码的分支名

6. **保持同步**：
   - 在开始开发前，确保 fork 的仓库与原始仓库同步
   - 可以使用以下命令同步：
     ```bash
     git fetch upstream
     git merge upstream/main
     ```

7. **本地 Git 认证**：
   - 推送代码到 GitHub 需要配置 Git 认证（SSH 密钥或 HTTPS token）
   - GitHub MCP Server 的 token 用于 MCP 工具调用
   - Git push 操作使用的是你本地配置的 Git 凭据（可以是同一个 token，但配置方式不同）

## GitHub MCP 工具 vs 本地 Git 命令对比

| 操作 | GitHub MCP 工具 | 本地 Git 命令 |
|------|----------------|--------------|
| 创建 Issue | `create_issue` | ❌ 必须用 MCP 或网页 |
| Fork 仓库 | `fork_repository` | ❌ 必须用 MCP 或网页 |
| 创建分支 | `create_branch` | ✅ `git checkout -b` |
| 修改代码 | `update_file` | ✅ 本地编辑器 |
| 提交代码 | ❌ 不支持 | ✅ `git commit` & `git push` |
| 创建 PR | `create_pull_request` | ❌ 必须用 MCP 或网页 |
| 评论 Issue | `add_issue_comment` | ❌ 必须用 MCP 或网页 |

**总结**：GitHub MCP 主要用于 GitHub 平台操作，本地代码开发用 Git 命令更方便。

## 快速参考：完整流程清单

```
✅ 1. GitHub MCP: create_issue          → 创建 issue
✅ 2. GitHub MCP: fork_repository       → Fork 仓库
✅ 3. 本地 Git: git clone               → 克隆到本地
✅ 4. 本地 Git: git checkout -b         → 创建新分支
✅ 5. 本地 IDE: 修改代码                 → 在 Cursor 中开发
✅ 6. 本地 Git: git add & git commit    → 提交更改
✅ 7. 本地 Git: git push                → 推送到 GitHub
✅ 8. GitHub MCP: create_pull_request   → 创建 PR
✅ 9. GitHub MCP: add_issue_comment     → 关联 issue（可选）
```

## 快速配置指南

### 第一步：创建 GitHub Token

1. 访问：https://github.com/settings/tokens
2. 选择 "Generate new token" → "Generate new token (classic)"
3. 配置 token：
   - **Note**: 填写描述，如 "MCP Server Token"
   - **Expiration**: 选择过期时间（建议 90 天）
   - **Scopes**: 勾选 `repo`（完整仓库权限）
4. 点击 "Generate token"
5. **立即复制 token**（只显示一次！）

### 第二步：配置本地 Git 认证

**选项 A：使用 SSH（推荐）**
```bash
# 生成 SSH 密钥
ssh-keygen -t ed25519 -C "your_email@example.com"

# 添加到 ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# 复制公钥并添加到 GitHub
cat ~/.ssh/id_ed25519.pub
# 访问 https://github.com/settings/keys 添加公钥

# 测试连接
ssh -T git@github.com
```

**选项 B：使用 HTTPS + Token**
```bash
# 配置 Git 使用 token 作为密码
git config --global credential.helper store

# 第一次 push 时输入：
# Username: your-github-username
# Password: ghp_your_token_here (使用 token 而不是密码)
```

### 第三步：配置 GitHub MCP Server

在 Cursor 或其他 IDE 的 MCP 配置文件中添加：

```json
{
  "mcpServers": {
    "github": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-e",
        "GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here",
        "ghcr.io/github/github-mcp-server"
      ]
    }
  }
}
```

或者使用环境变量：
```bash
# 在 ~/.bashrc 或 ~/.zshrc 中添加
export GITHUB_PERSONAL_ACCESS_TOKEN=ghp_your_token_here
```

### 验证配置

1. **验证 MCP Server**：在 IDE 中尝试调用 GitHub MCP 工具
2. **验证 Git 认证**：
   ```bash
   # 测试 SSH
   ssh -T git@github.com
   
   # 或测试 HTTPS
   git ls-remote https://github.com/your-username/test-repo.git
   ```

## 常见问题

### Q1: MCP 工具调用失败，提示权限不足？
**A**: 检查 GitHub token 的权限配置，确保包含了 `repo` scope（Classic token）或相应的 Fine-grained 权限。

### Q2: git push 失败，提示认证失败？
**A**: Git push 使用的是本地 Git 认证，与 MCP token 是分开配置的。请配置 SSH 密钥或 Git credential helper。

### Q3: fork_repository 调用失败？
**A**: Fork 操作需要完整的 `repo` scope。如果使用 Fine-grained token，可能需要账户级别的权限。

### Q4: 能否用同一个 token？
**A**: 可以！同一个 GitHub token 可以同时用于：
- GitHub MCP Server（环境变量配置）
- Git HTTPS 认证（作为密码使用）

但配置方式不同，需要分别设置。

### Q5: token 泄露了怎么办？
**A**: 
1. 立即访问 https://github.com/settings/tokens
2. 找到泄露的 token 并点击 "Delete"
3. 生成新的 token 并更新配置
4. 检查是否有异常的仓库活动

---

## 实战案例：修复 gohive v2 的 HiveConfiguration 传递 Bug

本案例展示了如何使用 GitHub MCP 工具发现、报告并修复第三方开源库的 bug，全程通过远程 API 操作完成。

### 背景

在为 genai-toolbox 项目实现 Kyuubi 数据源支持时，发现 [gohive](https://github.com/beltran/gohive) v2 库存在一个 bug：`OpenConnector` 函数没有将 `dsn.HiveConfiguration` 传递给 `config.HiveConfiguration`，导致通过 DSN 传递的会话配置（如 Spark 参数）无法生效。

### 步骤 1: 搜索现有 Issue

首先检查是否已有人报告过这个问题：

```
使用 MCP 工具: list_issues
- owner: "beltran"
- repo: "gohive"
- state: "OPEN"
- perPage: 20

使用 MCP 工具: search_issues
- query: "HiveConfiguration OpenConnector"
- owner: "beltran"
- repo: "gohive"

结果: 没有找到相关 issue
```

### 步骤 2: 创建 Issue

```
使用 MCP 工具: issue_write
- method: "create"
- owner: "beltran"
- repo: "gohive"
- title: "[v2 Bug] OpenConnector does not pass HiveConfiguration to connectConfiguration"
- body: |
    ## Bug Description
    
    In gohive v2, the `OpenConnector` function in `v2/driver.go` does not pass 
    `dsn.HiveConfiguration` to `config.HiveConfiguration`, which causes session 
    configuration parameters (like Spark configs) to not be sent to Hive/Kyuubi server.
    
    ## Location
    
    **File**: `v2/driver.go`, function `OpenConnector` (around line 37-38)
    
    ## Suggested Fix
    
    Simply add one line in `OpenConnector`:
    
    ```diff
    config.Service = dsn.Service
    + config.HiveConfiguration = dsn.HiveConfiguration
    ```
- labels: ["bug"]

结果: 创建成功，Issue #258
链接: https://github.com/beltran/gohive/issues/258
```

### 步骤 3: Fork 仓库

```
使用 MCP 工具: fork_repository
- owner: "beltran"
- repo: "gohive"

结果: Fork 成功到 silvermissile/gohive
```

### 步骤 4: 创建修复分支

```
使用 MCP 工具: create_branch
- owner: "silvermissile"
- repo: "gohive"
- branch: "fix/v2-hive-configuration-missing"
- from_branch: "master"

结果: 分支创建成功
```

### 步骤 5: 直接通过 MCP 修改代码并提交

**关键点**: 这里展示了如何通过 GitHub MCP 工具直接在远程仓库修改代码，无需本地 clone。

```
使用 MCP 工具: get_file_contents
- owner: "silvermissile"
- repo: "gohive"
- path: "v2/driver.go"
- ref: "refs/heads/fix/v2-hive-configuration-missing"

结果: 获取文件内容和 SHA

使用 MCP 工具: create_or_update_file
- owner: "silvermissile"
- repo: "gohive"
- path: "v2/driver.go"
- content: <修改后的文件内容，添加了一行代码>
- message: |
    fix: pass HiveConfiguration from DSN to connectConfiguration in OpenConnector
    
    This fixes a bug where session configuration parameters (like Spark configs)
    passed through the DSN were not being sent to the Hive/Kyuubi server.
    
    Fixes #258
- branch: "fix/v2-hive-configuration-missing"
- sha: <原文件的 SHA>

结果: 文件更新成功
```

**修复内容**（只需添加 1 行代码）：

```diff
  config.Username = dsn.Username
  config.Password = dsn.Password
  config.Database = dsn.Database
  config.TransportMode = dsn.TransportMode
  config.Service = dsn.Service
+ config.HiveConfiguration = dsn.HiveConfiguration
```

### 步骤 6: 创建 Pull Request 到原始仓库

```
使用 MCP 工具: create_pull_request
- owner: "beltran"
- repo: "gohive"
- title: "fix: pass HiveConfiguration from DSN to connectConfiguration in OpenConnector"
- head: "silvermissile:fix/v2-hive-configuration-missing"
- base: "master"
- body: |
    ## Summary
    
    This PR fixes a bug in gohive v2 where session configuration parameters 
    passed through the DSN were not being sent to the Hive/Kyuubi server.
    
    ## Problem
    
    In `v2/driver.go`, the `OpenConnector` function creates a `connectConfiguration` 
    but does not pass the `HiveConfiguration` from the parsed DSN.
    
    ## Solution
    
    Simply add one line to pass the `HiveConfiguration`:
    
    ```go
    config.HiveConfiguration = dsn.HiveConfiguration
    ```
    
    Fixes #258

结果: PR 创建成功，PR #259
链接: https://github.com/beltran/gohive/pull/259
```

### 步骤 7: 在自己的 Fork 中合并修复（不等待官方合并）

为了在等待官方合并期间能够使用修复，可以将修复合并到自己 fork 的 master 分支：

```
使用 MCP 工具: create_pull_request
- owner: "silvermissile"
- repo: "gohive"
- title: "fix: pass HiveConfiguration from DSN to connectConfiguration"
- head: "fix/v2-hive-configuration-missing"
- base: "master"
- body: "Merge the fix into master branch for use in genai-toolbox project."

结果: PR 创建成功，PR #1

使用 MCP 工具: merge_pull_request
- owner: "silvermissile"
- repo: "gohive"
- pullNumber: 1
- merge_method: "merge"

结果: 合并成功
```

### 步骤 8: 在自己的项目中使用修复后的 Fork

在 `go.mod` 中添加 `replace` 指令：

```go
// Use forked gohive with HiveConfiguration fix (one line fix in v2/driver.go)
// See: https://github.com/beltran/gohive/pull/259
// Remove this replace directive once the fix is merged upstream
replace github.com/beltran/gohive/v2 => github.com/silvermissile/gohive/v2 v2.0.0-20251226093343-357f1af3885e
```

然后运行：

```bash
go mod tidy
go build .
```

### 结果

| 项目 | 链接 |
|------|------|
| **Issue** | https://github.com/beltran/gohive/issues/258 |
| **PR (官方)** | https://github.com/beltran/gohive/pull/259 |
| **Fork** | https://github.com/silvermissile/gohive |

### 案例总结

这个案例展示了 GitHub MCP 工具的强大功能：

1. **全程远程操作**: 无需本地 clone，直接通过 API 完成代码修改
2. **完整工作流**: 搜索 Issue → 创建 Issue → Fork → 修改代码 → 创建 PR
3. **实用技巧**: 在等待官方合并时，使用自己的 fork 继续开发
4. **最小改动**: 只需 1 行代码就修复了影响所有用户的 bug

**使用的 MCP 工具清单**：
- `list_issues` - 查看现有 issue
- `search_issues` - 搜索相关 issue
- `issue_write` (method: create) - 创建 issue
- `fork_repository` - Fork 仓库
- `create_branch` - 创建分支
- `get_file_contents` - 获取文件内容
- `create_or_update_file` - 修改文件
- `create_pull_request` - 创建 PR
- `merge_pull_request` - 合并 PR

---

## 相关工具参考

- [GitHub MCP Server 官方文档](https://github.com/github/github-mcp-server)
- [GitHub Personal Access Tokens 文档](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
- [GitHub SSH 密钥配置](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
- [Git Credential Helper 文档](https://git-scm.com/docs/gitcredentials)

