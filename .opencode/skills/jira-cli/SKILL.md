---
name: jira-cli
description: |
  在 westwell-lab 的 Jira Data Center (8.17.1) 上使用 `jira-cli` 完成
  任务查询、搜索、创建、状态流转等操作。覆盖以下场景时必须使用此 skill：
  - 用户提到 "查 Jira" / "看 jira 任务" / "列一下我的 issue"
  - 用户提到 "jira" 配合 "westwell" / "公司" / "IN" / "HKAA" 等项目名
  - 用户要求用 jira-cli 操作 Jira
  - 用户要创建/更新/转换 issue、添加评论
  - 用户要执行 JQL 搜索
  - 用户要安装或配置 jira-cli
  即使用户只是说"帮我看看 jira 里有啥"，也应该触发此 skill。
---

# jira-cli Skill

在 westwell-lab 内部使用 `jira-cli` 操作 Jira Data Center 8.17.1。
此 skill 提供安装、配置和使用指导，以及 DC 8.x 特有的注意事项。

## 环境假设

- Jira 服务：`https://jira.westwell-lab.com`（Data Center 8.17.1，REST API v2）
- 认证方式：PAT (Personal Access Token) Bearer 认证
- 用户名：`zihao.liu`（项目成员根据实际情况替换）
- 工具二进制：`jira-cli`（上游 `jira-cli-for-agents`（原 `jcfa`）不支持 DC，**必须使用本 fork**）
- Fork 仓库：`git@github.com:ltinyho/jira-cli-for-agents.git`

## 快速开始

先检查环境是否就绪：

```bash
which jira-cli          # 是否安装
test -f ~/.jira-cli/config.yaml && echo "config exists"  # 是否配置
```

如果任一缺失，参见 [安装](#安装) 和 [配置](#配置) 章节。

## 安装

工具二进制从本 fork 构建（上游 jira-cli-for-agents 不支持 DC）。运行 `scripts/install.sh`：

```bash
# 默认安装到 ~/.local/bin（推荐）
./scripts/install.sh

# 安装到其他目录
./scripts/install.sh --bin-dir /usr/local/bin
./scripts/install.sh --bin-dir /opt/bin

# 从 GitHub 克隆后安装
git clone git@github.com:ltinyho/jira-cli-for-agents.git /tmp/jira-cli-for-agents-fork
cd /tmp/jira-cli-for-agents-fork
./scripts/install.sh
```

`install.sh` 接受 `--bin-dir <path>` 参数指定安装位置。安装完成后确保该目录在 `PATH` 中。

## 配置

配置文件位置：`~/.jira-cli/config.yaml`（权限 0600）

完整内容：

```yaml
domain: jira.westwell-lab.com
email: zihao.liu                      # DC 下用 username，不是邮箱
auth_type: bearer                     # 必须 bearer，DC 不接受 basic auth + token
api_token: "<PAT_TOKEN>"              # 替换为实际 PAT
default_project: IN
field_mappings: {}
```

> **注意**：上游 jira-cli-for-agents 的 basic auth (`email:api_token`) 在 DC 8.x 上不工作，因为 DC 的 basic
> auth 需要真实密码，而 PAT 只能用于 Bearer。务必设置 `auth_type: bearer`。

### 生成 PAT

在 Jira → 头像 → Profile → Personal Access Tokens → Create token。

### 验证配置

```bash
jira-cli list --limit 1                   # 应能列出至少一个 issue
```

如果返回 `failed to validate credentials` 或 `401`，检查 `auth_type` 和 `api_token`。

## 常用命令

### 列表与查看

```bash
# 列出默认项目（IN）的最近 issue
jira-cli list --limit 10

# 查看单个 issue 详情
jira-cli get IN-10514

# 查看 issue 的子任务和评论
jira-cli get IN-10514 --subtasks --comments

# 用 JSON 输出（AI agent 友好）
jira-cli list --limit 5 --json
jira-cli get IN-10514 --json
```

### 搜索（JQL）

```bash
# 我的待办
jira-cli search "assignee = currentUser() AND status != Done" --limit 20

# 项目内某类型的 issue
jira-cli search "project = \"IN\" AND type = Bug" --limit 20

# 按更新时间倒序
jira-cli search "project = \"IN\" ORDER BY updated DESC" --limit 20
```

> **DC 8.x JQL 关键字必须加引号**：`project = "IN"` 而不是 `project = IN`。
> 这是 DC 8.x 解析器的特殊行为，Cloud 没有此限制。

### 创建/更新

```bash
# 创建一个 Bug（从 JSON 模板）
jira-cli create --template bug --data bug.json

# 批量创建（sprint planning 等场景）
jira-cli batch create issues.json

# 更新字段
jira-cli update IN-10514 --field priority=High
jira-cli update IN-10514 --field summary="新标题"

# 状态流转
jira-cli transition IN-10514 "In Progress"
jira-cli transition IN-10514 "Done"
```

### 评论与链接

```bash
# 添加评论（简单模式）
jira-cli comment IN-10514 "排查完成，根因是配置项 X"

# 链接两个 issue
jira-cli link create IN-1001 IN-1002 --type Blocks
```

### 评论管理（comments 子命令）

`comment` 是简易别名；完整能力在 `comments` 子命令下：

```bash
# 列出 issue 的所有评论
jira-cli comments list IN-10514

# 限制数量 + 倒序（最新在前）
jira-cli comments list IN-10514 --limit 10 --order -created

# JSON 输出（AI agent 友好）
jira-cli comments list IN-10514 --json

# 添加评论（推荐，明确语义）
jira-cli comments add IN-10514 "已修复，根因是配置项 X"

# 获取单个评论（按 ID）
jira-cli comments get IN-10514 10001

# 更新自己发的评论
jira-cli comments update IN-10514 10001 "更新后的内容"

# 删除评论（必须 --confirm 防误删）
jira-cli comments delete IN-10514 10001 --confirm
```

> 注意：只有评论作者本人或管理员可以 update/delete。

### 附件管理（attachment）

```bash
# 列出 issue 的所有附件
jira-cli attachment list IN-10514
jira-cli attachment list IN-10514 --json   # JSON 输出

# 上传单个/多个文件
jira-cli attachment upload IN-10514 design.pdf
jira-cli attachment upload IN-10514 file1.pdf file2.png file3.docx

# 大文件（>1MB）自动显示进度条；--no-progress 关闭（适合 CI）
jira-cli attachment upload IN-10514 large.zip --no-progress

# 按文件名下载（默认当前目录）
jira-cli attachment download IN-10514 design.pdf

# 按 ID 下载
jira-cli attachment download IN-10514 10001

# 下载到指定目录 / 自定义文件名
jira-cli attachment download IN-10514 design.pdf --output ./downloads/
jira-cli attachment download IN-10514 design.pdf --output custom-name.pdf

# 删除附件（按 ID，需 --confirm）
jira-cli attachment delete 10001 --confirm
```

### 沙箱与权限（allowlist）

为 AI agent 或 CI 脚本提供只读 / 受限模式：

```bash
# 查看当前沙箱状态
jira-cli allowlist status
jira-cli allowlist status --json

# 列出所有命令的读/写分类
jira-cli allowlist commands
jira-cli allowlist commands --json

# 检查某个命令是否被允许（退出码 0=允许，1=拒绝）
jira-cli allowlist check get          # OK
jira-cli allowlist check create       # 失败（写命令）

# 在脚本中使用
if jira-cli allowlist check create; then
    jira-cli create --template story --data story.json
else
    echo "create command is blocked by sandbox"
fi

# 启用只读模式的说明
jira-cli allowlist enable
```

**启用方式**（通过环境变量）：

```bash
# 1. 只读模式：仅允许 list/get/search/fields/version/help 等读命令
export JIRA_READONLY=1
jira-cli get IN-10514         # OK
jira-cli create ...            # 拒绝

# 2. 显式白名单：只允许指定的命令
export JIRA_COMMAND_ALLOWLIST="get,search,list,fields"
jira-cli get IN-10514         # OK
jira-cli create ...            # 拒绝
jira-cli list ...              # 拒绝（不在白名单）

# 3. 取消所有限制
unset JIRA_READONLY JIRA_COMMAND_ALLOWLIST
```

**读/写命令分类**：

| 类别 | 命令 |
|---|---|
| 📖 读（允许 read-only 模式） | `get`, `search`, `list`, `fields`, `version`, `help`, `attachment list`, `comments list/get`, `link list/types` |
| ✏️ 写（read-only 模式拒绝） | `create`, `update`, `transition`, `batch`, `comment(s) add/update/delete`, `link create/delete`, `attachment upload/delete`, `configure`, `template` |

## AI Agent 工作流推荐

jira-cli 的 `--json` 输出专为 AI agent 设计。建议的组合模式：

1. **检索 → 摘要**：用 `--json` 拿数据，模型总结
2. **会议纪要 → issue**：解析纪要后用 `batch create` 批量生成
3. **dry-run 验证**：写操作前加 `--dry-run` 校验（batch 等子命令支持）

读取模式示例（AI 友好）：

```bash
# 把 JSON 解析为结构化数据
jira-cli list --limit 3 --json | python3 -c "
import sys, json
data = json.load(sys.stdin)
for i in data['issues']:
    print(f\"{i['key']}: {i['fields']['summary']}\")
"
```

## 已知差异（与上游 jira-cli-for-agents 比较）

| 特性 | 上游 jira-cli-for-agents (Cloud) | 本 fork (DC 8.x) |
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
| `unknown flag: --limit` (fields list) | 上游命令参数不一致 | 用 `jira-cli fields list --project IN` 不带 limit |
| `command not found: jira-cli` | 路径未配置 | `export PATH="$HOME/.local/bin:$PATH"` |

## 安全提示

- `~/.jira-cli/config.yaml` 必须保持权限 `0600`（脚本会自动设置）
- 切勿把 PAT 提交到 git
- 在共享/CI 环境中使用 `JIRA_READONLY=1` 限制 AI agent 只读

## 相关命令参考

```bash
# 查看所有命令
jira-cli --help
jira-cli list --help
jira-cli search --help
jira-cli create --help

# 详细子命令
jira-cli comments --help            # 评论管理
jira-cli attachment --help          # 附件管理
jira-cli allowlist --help           # 沙箱管理

# 查看命令分类（read-only / write）
jira-cli allowlist commands
jira-cli allowlist status           # 显示当前 sandbox 状态
```
