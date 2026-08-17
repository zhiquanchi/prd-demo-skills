# Git 操作规则（demo-page-builder 的参考文档）

> 本文件是 `demo-page-builder` skill 的 additional material，不是独立 skill。涉及 git 初始化、提交、tag 等操作时，由 SKILL.md 的流程引导到这里执行。

## Git 预检（项目一开始执行，强制）

Git 预检在项目一开始（最迟第一个页面动工前）执行，**不要拖到打 tag / 生成交接文档时才初始化**。立即检查以下四项并就地处理，不先以文字询问并停止：

1. **检查**：`command -v git`（git 是否可用）、项目根是否存在 `.git`、`git config user.name` 是否有值、`git remote -v` 是否有远端。
2. **没有 `.git`**：立即通过运行环境的权限申请机制请求 `git init` 授权（受控环境对 `.git` 的写入需要一次运行时权限提升，SKILL 文本不能替代该机制）；请求获批后立即初始化，不再以对话方式重复询问、不停下来等待。
3. **缺少 `user.name`**：使用项目约定默认身份直接配置，不向用户索取、不阻塞交付：
   ```
   git config user.name "Codex"
   git config user.email "codex@demo.local"
   ```
   用户已提供身份信息时以用户提供为准。
4. **没有远端**：仅完成本地 `git commit` 和 `git tag`，并在结果中说明「未推送（无远端）」；不得因缺少远端阻塞交付。

git 本体不存在时，按下方「安装规则」征得用户同意后安装——这是 Git 预检中唯一的征询点。

## Git 提交（强制）

### git 不存在先安装

开始工作前执行 `command -v git`（Windows cmd/PowerShell 用 `where git`）检查；不存在时，**先征得用户同意再安装**（与 `environment.md` 的"系统级安装需用户同意"规则一致），用户同意后按对应平台安装：

- Debian/Ubuntu：`apt-get install -y git`
- CentOS/RHEL：`yum install -y git`
- Alpine：`apk add git`
- macOS：`brew install git`
- Windows：优先 `winget install --id Git.Git -e --source winget`；没有 winget 时用 `choco install git -y`；两者都没有则从 https://git-scm.com/download/win 下载安装包静默安装。Windows 上装完后新开 shell 或把 `C:\Program Files\Git\cmd` 加入 PATH 再验证 `git --version`

### 初始化 Git 走运行环境权限申请机制（硬性）

项目根目录下没有 `.git` 时，先通过运行环境的权限申请机制请求 `git init` 授权（受控环境对 `.git` 的写入需要一次运行时权限提升，写在 SKILL 里不能替代该机制）；请求获批后**立即初始化，无需额外等待用户在对话中重复确认**。初始化时机按上方「Git 预检」节在项目一开始执行，不拖到交接文档阶段。提交前检查 `user.name`，未配置时按「Git 预检」节的默认身份（`Codex` / `codex@demo.local`）直接配置，不向用户索取、不因此阻塞提交；用户已提供身份信息时以用户提供为准（未配置会导致提交失败）

### 提交频率与推送

- **每完成一个任务或一个改动就提交一次并推送**：一个页面、一个小功能、一次样式调整，各自对应一次 `git add -A && git commit && git push`，不要把多个改动攒成一个提交。**push 已获用户长期授权：每个任务完成后直接推送到远端，无需逐次再确认**；push 失败（如远端有新提交）时如实报告，不擅自用禁止命令强行处理
- **提交信息用中文**：遵循 `类型: 简述` 格式，类型从 `feat`（新页面/新功能）、`fix`（修复）、`style`（样式调整）、`chore`（依赖/配置）中选
- **简述必须是详细的功能描述，且从用户的原始输入中提取**：把用户这次要求的具体功能点写清楚——做了什么页面/功能、包含哪些关键要素（核心组件、交互、数据来源等），让不看代码的人仅凭提交信息就能知道这次改了什么。禁止 `feat: 新增页面`、`fix: 修改问题` 这类空泛描述
  - 用户说「做一个用户管理页，要有搜索、分页和批量删除」→ `feat: 新增用户管理列表页，支持关键字搜索、分页浏览和批量删除`
  - 用户说「把表格改成斑马纹，操作列固定到右侧」→ `style: 用户列表表格增加斑马纹样式，操作列固定到右侧`
  - 用户输入很简短时，结合实现内容补全成完整描述，但不得编造用户没要求的功能

### git 操作白名单

只允许以下写命令（含状态确认用的 `git status` / `git log` / `git diff` / `git tag -l` 等只读查询）：

`git init`、`git add`、`git commit`、`git push`、`git pull`、`git merge`、`git tag`、`git tag -d`、`git push origin :refs/tags/<tag>`（后两条仅用于删除后重打 tag 的场景）

- `git push`：每个任务提交后直接执行
- `git tag` / `git tag -d` / `git push origin :refs/tags/<tag>`：仅在用户确认满意后按 `handover.md` 流程使用；`git tag -d` 与远端 tag 删除仅用于需要重打 tag 时，不得用于其他目的
- `git pull` / `git merge`：**无冲突或冲突可自动合并时直接自动处理，无需逐次确认**，仅当产生 git 无法自动解决的冲突时，如实报告给用户，由用户决定处理方式，不擅自用禁止命令解决
- 其余一切 git 操作（`reset`、`rebase`、`checkout`/`switch`、`stash`、`clean`、`branch -D`、`push --force`、`merge --abort` 等）全部禁止，无论任何理由都不得执行

### 环境禁止 git 时先申请权限（硬性，不可绕过）

若当前环境禁止或不允许执行 git 操作（如受控环境、沙箱、CI 只读、权限受限等导致 `git` 命令不可用或被拦截），**严禁绕过、不得想办法强行执行**，必须先向 agent 或用户申请权限，得到明确授权后方可进行 git 操作。此规则为强制约束：无论任务进度如何、是否紧急，均不得以任何方式规避环境限制或用替代手段达成 git 目的（如改写路径、伪装命令、换 shell、直接改远端等）；申请被拒绝时如实停止并汇报，不做二次绕过尝试
