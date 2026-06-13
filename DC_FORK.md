# jira-cli-for-agents (Data Center fork)

> 在 [sanisideup/jira-cli-for-agents](https://github.com/sanisideup/jira-cli-for-agents) 基础上增加对 **Jira Data Center (8.x/9.x)** 的兼容性支持。

## 与上游的差异

| 改动 | 上游 (Cloud) | 本 fork (Data Center) |
|---|---|---|
| API 版本 | `/rest/api/3` | `/rest/api/2` |
| Search 端点 | `POST /search/jql` | `POST /search`（DC 8.x 不支持 `/search/jql`） |
| 用户标识 | `accountId` | `name`（DC 用 username） |
| Assignee 字段 | `accountId` | `name` |
| 认证 | Basic `email:api_token` | Basic `username:api_token` **或** Bearer (PAT) |

## 新增配置项

```yaml
domain: jira.example.com      # 不带 https://
email: zihao.liu              # 必填：在 Cloud 下用邮箱；在 DC 下用用户名
api_token: "xxx"              # 必填：Cloud 用 API token；DC 用 PAT
auth_type: bearer             # 可选：basic (默认) 或 bearer
```

### 认证方式选择

- **Cloud**: 默认 basic，`email` 填邮箱
- **Data Center + PAT (推荐)**: 设 `auth_type: bearer`，`email` 填用户名
- **Data Center + 密码**: 默认 basic，`email` 填用户名，`api_token` 填密码

## 已知问题

Jira 8.x DC 的 JQL 解析比 Cloud 严格，关键字必须加引号：

```bash
# Cloud 写法
jcfa search "project = IN AND type = Bug"

# DC 写法（IN 等关键字加引号）
jcfa search "project = \"IN\" AND type = Bug"
```

## 构建

```bash
go build -o jira-cli-for-agents \
  -ldflags="-X 'github.com/sanisideup/jira-cli-for-agents/cmd.Version=1.4.0-dc'"
```
