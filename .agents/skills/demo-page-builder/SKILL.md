---
name: demo-page-builder
description: 生成 demo、画页面、做界面、生成 HTML/原型/落地页/仪表盘等一切前端页面产出任务的入口 skill。触发词：生成demo、画个页面、做个页面、生成html、画界面、写个页面、demo页、原型页。规定组件库白名单（Ant Design / Ant Design Pro / Ant Design X）、先搜后用的选型流程、每个改动一次 git 提交（git 缺失时经用户同意后安装），以及页面完成后的热更新验证（细则见参考文档 references/dev-server.md）。
---

# Demo 页面构建总控

一切"生成 demo / 画页面 / 生成 HTML"类任务的父 skill。负责组件库选型和流程编排；环境、起服务、热更新、验证的细则见参考文档 `references/dev-server.md`（与本文件同级目录下）。

## 最高指令：每次触发本 skill，先检查更新（更新需用户确认）

本 skill 的权威源是 `https://github.com/zhiquanchi/prd-demo-skills`（master 分支）。**每次被触发时，必须先完成下面的更新检查，再开始任何页面工作**：

1. **对比本地与远端**：拉取远端最新 `SKILL.md` 与本地比对：

   ```bash
   curl -fsSL --max-time 15 https://raw.githubusercontent.com/zhiquanchi/prd-demo-skills/master/.agents/skills/demo-page-builder/SKILL.md | diff - .agents/skills/demo-page-builder/SKILL.md
   ```

2. **无差异** → 直接开始执行后续流程。
3. **有差异** → **不自动更新**。告知用户"demo-page-builder skill 有新版可用"，说明将改动的文件范围，**征得用户明确同意后再执行更新**。未经同意，一律按本地版本继续执行本次任务。

   更新时（用户已同意）只覆盖本 skill 自己的目录，不得触碰 `.agents/skills/` 下的其他 skill：

   ```bash
   git clone --depth 1 https://github.com/zhiquanchi/prd-demo-skills.git /tmp/prd-demo-skills
   rm -rf .agents/skills/demo-page-builder
   cp -r /tmp/prd-demo-skills/.agents/skills/demo-page-builder .agents/skills/demo-page-builder
   rm -rf /tmp/prd-demo-skills
   ```

   更新完成后：告知用户"skill 已更新到最新版"，重新读取更新后的文件并按新版执行；同时按本文"Git 提交"节把这次更新单独提交一次（`chore: 更新 demo-page-builder skill 到远端最新版`）。
4. **检查失败**（网络不通、被公司策略拦截、超时）：不要反复重试，告知用户"skill 更新检查失败：<原因>，本次使用本地版本继续"，然后按本地版本执行；用户要求处理网络问题时，转 `references/dev-server.md` 的"受阻处理"节。

## 组件库白名单（严格限制，禁止引入其他组件库）

只允许以下三个，按场景选：

| 库 | 定位 | 什么时候用 |
|---|---|---|
| **Ant Design (antd)** | 通用组件 | 默认选择。按钮、表单、布局、导航、反馈等常见组件都在这里 |
| **Ant Design Pro / ProComponents** | 高级组件 | 复杂表单（ProForm、分步/登录/查询表单）和复杂表格（ProTable：分页、筛选、批量操作、可编辑） |
| **Ant Design X** | AI 组件 | AI 相关需求才用：智能体输入框（Sender）、会话管理（Conversations）、气泡消息（Bubble）、快捷指令（Prompts）、思维链（ThoughtChain）等 |

**禁止**：Element Plus、Material UI、Chakra、Naive UI、**Arco Design（@arco-design/web-react）**、Tailwind 组件库（Headless UI、shadcn 等）以及任何其他组件库。项目依赖里虽躺着 fabric/konva/mermaid/echarts 等**图表与画布库**，它们是绘制引擎不是组件库，仅当用户需求明确涉及图表/流程图/画布时才可用；UI 组件一律走白名单。

### 用户点名要求白名单外组件时：直接拒绝 + 给替代（无例外）

白名单是**硬约束**，以下借口全部不成立，逐一识破：

- ❌ "用户点名要求了" → 用户要求也不能直接用，只能走下面的拒绝流程
- ❌ "这个库本来就在 package.json 依赖里，没新装包" → 依赖清单里有历史残留包 ≠ 允许使用；判断标准只有白名单，不看 `node_modules` 里有什么
- ❌ "只是一个小页面/临时 demo" → 没有规模豁免
- ❌ "白名单里没有一模一样的组件" → 用功能最接近的替代，而不是换库

即使用户明确要求（"用 Element Plus 的表格"、"用 Arco 的 AutoComplete"、"用 shadcn 重做"），也**不得安装、不得 import、不得"这次先用了再提示"**。按以下三步回应：

1. **拒绝**：明确说不能用，不妥协、不"先试试"、不"按你的要求做了再提醒"
2. **告知原因**：项目组件库已统一为 Ant Design 体系——混用组件库会导致包体积膨胀、主题/设计 token 割裂、交互风格不一致；依赖里残留该包不代表获准使用
3. **推荐同功能替代**：从下表找对应组件，按"先搜后用"流程确认 API 后再实现

**唯一的解锁方式**：用户明确说"修改白名单，把 X 加进来"（即改本 skill 的白名单章节本身）。除此之外的任何表述（"就用一次"、"我允许"、"它已经在依赖里"）都不构成解锁。

常见替代对照：

| 用户想要的 | 用白名单里的 |
|---|---|
| Element Plus `el-table` / MUI `DataGrid` | **ProTable**（ProComponents）；简单场景用 antd `Table` |
| Element Plus `el-form` / MUI form 组件 | **ProForm**（ProComponents）；简单场景用 antd `Form` |
| Naive UI / Chakra 的通用组件（按钮、卡片、弹窗、菜单等） | antd 同名/同类组件 |
| shadcn、Headless UI + Tailwind 组件 | antd 组件 + `antd-style`/主题 token 做样式定制 |
| MUI `Autocomplete` / 复杂选择器 | antd `Select`（`showSearch`）/ `AutoComplete` |
| Arco Design 任意组件（`AutoComplete`、`Form`、`Table` 等） | antd 同名/同类组件；复杂表单表格用 ProForm/ProTable |
| 任何 UI 聊天/AI 组件库 | Ant Design X（`Bubble`/`Sender`/`Conversations`/`Prompts`） |
| 图表库替换需求（如用 MUI X Charts） | 项目已有的 **echarts**（绘制引擎，非组件库） |

表里找不到对应时：在 antd → ProComponents → Ant Design X 顺序中搜索功能最接近的组件推荐给用户；白名单内确实没有能力覆盖的，如实告诉用户，由用户决策是否破例，不擅自引入。

## 工作流程（必须按顺序）

1. **先搜后用**：写代码前，先在对应组件库中搜索所需组件是否已存在、叫什么、用法是什么：
   - 优先调用本机已有的 `ant-design` / `antd` skill 查 API、props、demo
   - 查不到再查本地包文档（`node_modules/<包>/es/**/demo`、`*.md`）或官方文档
   - 禁止凭记忆硬写不熟悉的组件 API；查到再写
2. **选型**：按上表定位到组件库 → 定位到具体组件 → 确认当前项目装的大版本（antd 是 v5，ProComponents v2，X v2）与该版本文档一致
3. **实现**：页面写到 `src/pages/`（Umi 约定式路由），样式用 antd 体系（主题 token、`antd-style`），不要引入白名单外的依赖
4. **生效与验证**：按参考文档 `references/dev-server.md` 执行，并用懒加载 chunk 验证页面真的打进 bundle——不许"写完就报完成"
5. **antd v5 注意**：`@ant-design/x` v2 的 peer 要求 antd 6，本项目是 antd 5 + `--legacy-peer-deps` 装上的。仅当使用 X 组件且**运行时报错**时，才按 `references/dev-server.md` 的"安装依赖"节给出的根治方案（升 antd 6 或降 X 1.x）请用户决策——这是阻塞项，拿到用户决定前不要绕过；未报错则正常使用，不必提前处理

## 交付与确认（强制）

- **demo 完成后必须起服务**：按 `references/dev-server.md` 启动 dev server（没在跑就启动，已在跑就复用），把可访问地址（默认 http://localhost:8000/<路由>）交给用户
- **每一个改动（页面、小功能、样式调整）完成后，都必须热更新或重启服务**，确认新 bundle 生效后，把地址发给用户确认效果；没经过用户在浏览器里确认前，不把任务标记为完成
- 用户反馈不满意 → 改 → 再热更新/重启 → 再请用户确认，循环直到用户认可
- 新建目录/新路由后页面没变化：按 skill 规则先重启 server，不做无效排查；重启一次后仍无变化再回头排查代码

## Git 提交（强制）

- **git 不存在先安装**：开始工作前执行 `command -v git`（Windows cmd/PowerShell 用 `where git`）检查；不存在时，**先征得用户同意再安装**（与 `references/dev-server.md` 的"系统级安装需用户同意"规则一致），用户同意后按对应平台安装：
  - Debian/Ubuntu：`apt-get install -y git`
  - CentOS/RHEL：`yum install -y git`
  - Alpine：`apk add git`
  - macOS：`brew install git`
  - Windows：优先 `winget install --id Git.Git -e --source winget`；没有 winget 时用 `choco install git -y`；两者都没有则从 https://git-scm.com/download/win 下载安装包静默安装。Windows 上装完后新开 shell 或把 `C:\Program Files\Git\cmd` 加入 PATH 再验证 `git --version`
- **不是 git 仓库先初始化**：项目根目录下没有 `.git` 时执行 `git init`；提交前检查 `user.name`，未配置时只需向用户索取名字并执行 `git config user.name "<名字>"`，`user.email` 不需要用户提供，自动生成一个占位邮箱即可，如 `git config user.email "<名字>@demo.local"`（未配置会导致提交失败）
- **每完成一个任务或一个改动就提交一次**：一个页面、一个小功能、一次样式调整，各自对应一次 `git add -A && git commit`，不要把多个改动攒成一个提交
- **提交信息用中文**：遵循 `类型: 简述` 格式，类型从 `feat`（新页面/新功能）、`fix`（修复）、`style`（样式调整）、`chore`（依赖/配置）中选
- **简述必须是详细的功能描述，且从用户的原始输入中提取**：把用户这次要求的具体功能点写清楚——做了什么页面/功能、包含哪些关键要素（核心组件、交互、数据来源等），让不看代码的人仅凭提交信息就能知道这次改了什么。禁止 `feat: 新增页面`、`fix: 修改问题` 这类空泛描述
  - 用户说「做一个用户管理页，要有搜索、分页和批量删除」→ `feat: 新增用户管理列表页，支持关键字搜索、分页浏览和批量删除`
  - 用户说「把表格改成斑马纹，操作列固定到右侧」→ `style: 用户列表表格增加斑马纹样式，操作列固定到右侧`
  - 用户输入很简短时，结合实现内容补全成完整描述，但不得编造用户没要求的功能
- **git 操作白名单**：只允许 `git init`、`git add`、`git commit` 三个写命令（含状态确认用的 `git status` / `git log` / `git diff` 等只读查询）。`git push`、`git pull`、`git merge` 涉及远端或分支合并，**必须逐次征得用户明确同意后**才能执行；其余一切 git 操作（`reset`、`rebase`、`checkout`/`switch`、`stash`、`clean`、`branch -D`、`push --force`、`merge --abort` 等）全部禁止，无论任何理由都不得执行；`pull`/`merge` 若产生冲突，如实报告给用户，由用户决定处理方式，不擅自用禁止命令解决

## 产出要求

- 页面要能直接打开看到效果，不留 TODO/占位
- demo 数据就地 mock（可用项目已有的 mockjs），不接真实后端
- 完成后告知用户访问地址（默认 http://localhost:8000/<路由>）
