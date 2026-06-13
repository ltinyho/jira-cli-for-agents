---
name: jira-cli
description: |
  在 westwell-lab 的 Jira Data Center (8.17.1) 上使用 jira-cli-for-agents (jcfa) 完成
  任务查询、搜索、创建、状态流转等操作。覆盖以下场景时必须使用此 skill：
  - 用户提到 "查 Jira" / "看 jira 任务" / "列一下我的 issue"
  - 用户提到 "jira" 配合 "westwell" / "公司" / "IN" / "HKAA" 等项目名
  - 用户要求用 jcfa / jira-cli-for-agents 操作 Jira
  - 用户要创建/更新/转换 issue、添加评论
  - 用户要执行 JQL 搜索
  - 用户要安装或配置 jcfa
  即使用户只是说"帮我看看 jira 里有啥"，也应该触发此 skill。
---

# jira-cli Skill

在 westwell-lab 内部使用 `jira-cli-for-agents` (jcfa) 操作 Jira Data Center 8.17.1。
此 skill 提供安装、配置和使用指导，以及 DC 8.x 特有的注意事项。

## 环境假设

- Jira 服务：`https://jira.westwell-lab.com`（Data Center 8.17.1，REST API v2）
- 认证方式：PAT (Personal Access Token) Bearer 认证
- 用户名：`zihao.liu`（项目成员根据实际情况替换）
- 工具二进制：`jira-cli-for-agents`（上游 jcfa 不支持 DC，**必须使用本 fork**）
- Fork 仓库：`git@github.com:ltinyho/jira-cli-for-agents.git`

## 快速开始

先检查环境是否就绪：

```bash
which jira-cli-for-agents          # 是否安装
test -f ~/.jcfa/config.yaml && echo "config exists"  # 是否配置
```

如果任一缺失，参见 [安装](#安装) 和 [配置](#配置) 章节。

## 安装

工具二进制从本 fork 构建（上游 jcfa 不兼容 DC）。运行 `scripts/install.sh`：

```bash
# 默认安装到 ~/.local/bin（推荐）
./scripts/install.sh

# 安装到其他目录
./scripts/install.sh --bin-dir /usr/local/bin
./scripts/install.sh --bin-dir /opt/bin

# 从 GitHub 克隆后安装
git clone git@github.com:ltinyho/jira-cli-for-agents.git /tmp/jcfa-fork
cd /tmp/jcfa-fork
./scripts/install.sh
```

`install.sh` 接受 `--bin-dir <path>` 参数指定安装位置。安装完成后确保该目录在 `PATH` 中。

## 配置

配置文件位置：`~/.jcfa/config.yaml`（权限 0600）

完整内容：

```yaml
domain: jira.westwell-lab.com
email: zihao.liu                      # DC 下用 username，不是邮箱
auth_type: bearer                     # 必须 bearer，DC 不接受 basic auth + token
api_token: "<PAT_TOKEN>"              # 替换为实际 PAT
default_project: IN
field_mappings: {}
```

> **注意**：上游 jcfa 的 basic auth (`email:api_token`) 在 DC 8.x 上不工作，因为 DC 的 basic
> auth 需要真实密码，而 PAT 只能用于 Bearer。务必设置 `auth_type: bearer`。

### 生成 PAT

在 Jira → 头像 → Profile → Personal Access Tokens → Create token。

### 验证配置

```bash
jcfa list --limit 1                   # 应能列出至少一个 issue
```

如果返回 `failed to validate credentials` 或 `401`，检查 `auth_type` 和 `api_token`。

## 常用命令

### 列表与查看

```bash
# 列出默认项目（IN）的最近 issue
jcfa list --limit 10

# 查看单个 issue 详情
jcfa get IN-10514

# 查看 issue 的子任务和评论
jcfa get IN-10514 --subtasks --comments

# 用 JSON 输出（AI agent 友好）
jcfa list --limit 5 --json
jcfa get IN-10514 --json
```

### 搜索（JQL）

```bash
# 我的待办
jcfa search "assignee = currentUser() AND status != Done" --limit 20

# 项目内某类型的 issue
jcfa search "project = \"IN\" AND type = Bug" --limit 20

# 按更新时间倒序
jcfa search "project = \"IN\" ORDER BY updated DESC" --limit 20
```

> **DC 8.x JQL 关键字必须加引号**：`project = "IN"` 而不是 `project = IN`。
> 这是 DC 8.x 解析器的特殊行为，Cloud 没有此限制。

### 创建/更新

```bash
# 创建一个 Bug（从 JSON 模板）
jcfa create --template bug --data bug.json

# 批量创建（sprint planning 等场景）
jcfa batch create issues.json

# 更新字段
jcfa update IN-10514 --field priority=High
jcfa update IN-10514 --field summary="新标题"

# 状态流转
jcfa transition IN-10514 "In Progress"
jcfa transition IN-10514 "Done"
```

### 评论与链接

```bash
# 添加评论
jcfa comment IN-10514 "排查完成，根因是配置项 X"

# 链接两个 issue
jcfa link create IN-1001 IN-1002 --type Blocks
```

## AI Agent 工作流推荐

jcfa 的 `--json` 输出专为 AI agent 设计。建议的组合模式：

1. **检索 → 摘要**：用 `--json` 拿数据，模型总结
2. **会议纪要 → issue**：解析纪要后用 `batch create` 批量生成
3. **dry-run 验证**：写操作前加 `--dry-run` 校验（batch 等子命令支持）

读取模式示例（AI 友好）：

```bash
# 把 JSON 解析为结构化数据
jcfa list --limit 3 --json | python3 -c "
import sys, json
data = json.load(sys.stdin)
for i in data['issues']:
    print(f\"{i['key']}: {i['fields']['summary']}\")
"
```

## 已知差异（与上游 jcfa 比较）

| 特性 | 上游 jcfa (Cloud) | 本 fork (DC 8.x) |
|---|---|---|
| API 版本 | `/rest/api/3` | `/rest/api/2` |
| Search 端点 | `POST /search/jql` | `POST /search` |
| 认证 | Basic `email:api_token` | Bearer `<PAT>` |
| 用户标识 | `accountId` | `name` (username) |
| JQL 关键字 | 可不加引号 | **必须加引号** |

## 故障排查

| 症状 | 原因 | 解决 |
|---|---|---|
| `401 Unauthorized` | basic auth + token 错配 | 设置 `auth_type: bearer` |
| `404 Not Found` on search | 用了 `/search/jql` | 重新安装 fork 版本 |
| `JQL: Expecting either a value, list or function but got 'IN'` | DC 8.x 关键字需要引号 | 改用 `project = "IN"` |
| `unknown flag: --limit` (fields list) | 上游命令参数不一致 | 用 `jcfa fields list --project IN` 不带 limit |
| `command not found: jcfa` | 路径未配置 | `export PATH="$HOME/.local/bin:$PATH"` |

## 安全提示

- `~/.jcfa/config.yaml` 必须保持权限 `0600`（脚本会自动设置）
- 切勿把 PAT 提交到 git
- 在共享/CI 环境中使用 `JIRA_READONLY=1` 限制 AI agent 只读

## 相关命令参考

```bash
# 查看所有命令
jcfa --help
jcfa list --help
jcfa search --help
jcfa create --help

# 查看命令分类（read-only / write）
jcfa allowlist commands
jcfa allowlist status           # 显示当前 sandbox 状态
```
