---
name: demo-page-builder
description: 生成 demo、画页面、做界面、生成 HTML/原型/落地页/仪表盘等一切前端页面产出任务的入口 skill。触发词：生成demo、画个页面、做个页面、生成html、画界面、写个页面、demo页、原型页、复刻页面、还原原型、照这个做。规定组件库白名单（Ant Design / Ant Design Pro / Ant Design X）、先搜后用的选型流程、长耗时环节定时上报任务进度（防止用户误以为卡死）、每个改动一次 git 提交并推送（git 缺失时经用户同意后安装，push 已获长期授权），以及页面完成后的热更新验证（环境细则见 references/environment.md，起服务与验证见 references/dev-server.md，首页空白自动跳转与左侧导航绑定见 references/routes.md，用户提供了 HTML/截图/原型要复刻时见 references/replicate.md，用户确认满意后打 git tag 并生成同名交接文档见 references/handover.md）。
---

# Demo 页面构建总控

一切"生成 demo / 画页面 / 生成 HTML"类任务的父 skill。负责组件库选型和流程编排；细则分五份参考文档（与本文件同级 `references/` 目录下）：环境准备（node runtime、依赖安装）见 `references/environment.md`，起服务、热更新、验证见 `references/dev-server.md`，路由、首页跳转与左侧导航绑定见 `references/routes.md`，用户提供了 HTML/截图/原型需要复刻时见 `references/replicate.md`，用户确认满意后打 git tag 与生成交接文档见 `references/handover.md`。

## 参考原型复刻（用户提供了 demo / 原型时，先于常规流程）

用户提供了参考物（HTML 文件或代码片段、页面截图、设计稿、线上页面 URL 等）并要求"照这个做 / 复刻 / 还原"时，**不要直接进入常规工作流程**，先按 `references/replicate.md` 执行：

1. **先理解原稿**：拆解参考物，产出复刻清单（区块划分、精确配色、字体间距、交互、文案）
2. **组件映射**：原稿元素全部映射到白名单组件，清单外一律禁止
3. **一比一复刻**：布局、配色（精确色值）、文案逐字还原，样式用 antd-style
4. **对比验证**：截图与原稿并排核对，不像就改到用户确认像为止

复刻场景的其余规则（白名单、git 提交、交付确认）与常规任务完全一致。

## 项目定位（第一优先级，先于一切流程）

- **项目根 = 用户会话的当前工作目录**（pwd）。所有文件写入、依赖安装、dev server、git 操作都只在当前工作目录下进行。
- **严禁把 skill 自身所在目录当作项目根**：本 skill 可能安装在 `~/.agents/skills/` 或某个分发仓库（如 `prd-demo-skills`）里，那些位置不是用户的项目。绝不向 skill 目录写页面、装依赖、起服务或提交 git。
- **当前目录不是前端工程时先就地初始化**：当前目录没有 `package.json`（或不是 Umi Max 工程）时，在当前目录原地初始化，而不是换到别的目录：
  1. 复制 `references/package.json` 为当前目录的 `package.json`，把 `name` 改成当前目录名
  2. 写 `.gitignore`：`node_modules/`、`.runtime/`、`src/.umi/`、`src/.umi-production/`、`dist/`——**绝不要忽略 `src/pages`**，页面文件必须能被 git 提交
  3. 按 `references/environment.md` 探测 node 后执行 `npm install --legacy-peer-deps --no-audit --no-fund`
  4. Umi Max 约定式路由零配置即可跑，不需要额外配置文件
- 用户明确指定了其他目录时，以用户指定为准。

## 组件库白名单（严格限制，禁止引入其他组件库）

**依赖总闸**：所有可用的库以 `references/package.json` 的依赖清单为准——只允许 import 清单里已有的包，**禁止安装任何新依赖**（`npm install <pkg>` 一律不行）。清单里没有的能力，用清单内已有的库实现，或如实告诉用户做不了，不擅自引入。

**唯一标准**：只允许使用 `references/package.json` 的 `dependencies` 清单里已有的包和其中的组件。判断依据只有这一份清单——不看 `node_modules` 里实际装了什么，不看历史代码里 import 过什么。**绝不允许引入清单之外的任何新组件、新库、新依赖**（`npm install <pkg>` 一律不行，手写/vendored 复制外部组件代码也不行）。

清单内主要能力速查（以 `references/package.json` 实际内容为准）：

| 需求场景 | 用清单里的 |
|---|---|
| 通用 UI 组件（按钮、表单、布局、导航、反馈等） | **antd**（默认选择） |
| 复杂表单/复杂表格（ProForm、ProTable） | **@ant-design/pro-components** |
| AI 组件（Sender、Bubble、Conversations、Prompts、ThoughtChain 等） | **@ant-design/x** / `@ant-design/x-sdk` |
| 图标 | **@ant-design/icons** |
| 图表 | **echarts** + `echarts-for-react` |
| 流程图/画布 | **@xyflow/react**、`dagre`、`fabric`、`konva`/`react-konva`、`react-sketch-canvas` |
| 文本流程图/结构图渲染 | **mermaid** |
| 富文本/Markdown 编辑 | **@tinymce/tinymce-react**、`@uiw/react-md-editor`、`react-markdown` + `remark-gfm` |
| 样式定制 | **antd-style**、`classnames`/`clsx`/`tailwind-merge` |
| 工具库 | `lodash`、`dayjs`、`rc-virtual-list`、`react-fast-marquee` 等清单内其余包 |

### 用户点名要求清单外组件时：直接拒绝 + 给替代（无例外）

这是**硬约束**，以下借口全部不成立，逐一识破：

- ❌ "用户点名要求了" → 用户要求也不能直接用，只能走下面的拒绝流程
- ❌ "这个库本来就在 node_modules 里，没新装包" → 判断标准只有 `references/package.json` 清单，不看 `node_modules` 里有什么
- ❌ "只是一个小页面/临时 demo" → 没有规模豁免
- ❌ "清单里没有一模一样的组件" → 用清单内功能最接近的替代，而不是引入新组件
- ❌ "我自己手写一个/抄一段源码进来" → 这也算引入新组件，同样禁止

即使用户明确要求（"用 Element Plus 的表格"、"用 Arco 的 AutoComplete"、"用 shadcn 重做"），也**不得安装、不得 import、不得"这次先用了再提示"**。按以下三步回应：

1. **拒绝**：明确说不能用，不妥协、不"先试试"、不"按你的要求做了再提醒"
2. **告知原因**：项目可用组件以 `references/package.json` 清单为唯一标准，清单外一律禁用——混用外部组件库会导致包体积膨胀、主题/设计 token 割裂、交互风格不一致
3. **推荐同功能替代**：先在上面速查表找，找不到就按"先搜后用"流程在清单内的库（antd → ProComponents → Ant Design X → 其余清单内包）中搜索功能最接近的组件推荐给用户

清单内确实没有能力覆盖的，如实告诉用户做不了，由用户决策是否破例，**不擅自引入**。

## 工作流程（必须按顺序）

1. **先搜后用**：写代码前，先在对应组件库中搜索所需组件是否已存在、叫什么、用法是什么：
   - 优先调用本机已有的 `ant-design` / `antd` skill 查 API、props、demo
   - 查不到再查本地包文档（`node_modules/<包>/es/**/demo`、`*.md`）或官方文档
   - 禁止凭记忆硬写不熟悉的组件 API；查到再写
2. **选型**：按上表定位到组件库 → 定位到具体组件 → 确认当前项目装的大版本（antd 是 v5，ProComponents v2，X v2）与该版本文档一致
3. **实现**：页面写到 `src/pages/`（Umi 约定式路由），样式用 antd 体系（主题 token、`antd-style`），不要引入白名单外的依赖；首页空白跳转、新增页面的导航绑定按 `references/routes.md` 执行
4. **生效与验证**：按参考文档 `references/dev-server.md` 执行，并用懒加载 chunk 验证页面真的打进 bundle——不许"写完就报完成"
5. **antd v5 注意**：`@ant-design/x` v2 的 peer 要求 antd 6，本项目是 antd 5 + `--legacy-peer-deps` 装上的。仅当使用 X 组件且**运行时报错**时，才按 `references/environment.md` 的"安装依赖"节给出的根治方案（升 antd 6 或降 X 1.x）请用户决策——这是阻塞项，拿到用户决定前不要绕过；未报错则正常使用，不必提前处理

## 交付与确认（强制）

本节区分两件事：**服务管理**是环境操作（起服务、热更新、重启），本身不是交付物；**业务改动**（页面、功能、样式）才是交付物，必须经用户确认。

### 服务管理（环境操作，不算交付）

- **服务保持可用**：按 `references/dev-server.md` 启动 dev server（没在跑就启动，已在跑就复用），保证地址（默认 http://localhost:8000/<路由>）始终可访问
- 起服务、热更新、重启只是让改动生效的手段，**不单独向用户邀功、不单独提交 git**；只有业务改动才走下面的交付与提交流程
- 新建目录/新路由后页面没变化：按 skill 规则先重启 server，不做无效排查；重启一次后仍无变化再回头排查代码

### 业务改动（交付物，需用户确认）

- **每一个业务改动（页面、小功能、样式调整）完成后**，先通过热更新或重启服务让新 bundle 生效，再把地址发给用户确认效果；没经过用户在浏览器里确认前，不把任务标记为完成
- 用户反馈不满意 → 改 → 再热更新/重启 → 再请用户确认，循环直到用户认可
- **用户明确认可后（"可以了/满意/就这样"），打 git tag 并生成与 tag 同名的交接文档**（`docs/handover/<tag名>.md`，总结本次对话内容），完整流程见 `references/handover.md`；这是交付的收尾动作，不可省略

## 进度上报（强制，防止用户误以为卡死）

长耗时环节必须持续向用户输出进度，**不允许长时间静默执行**：

- **每个阶段开始时先报一行**：说明当前在做什么、预计耗时，例如「正在安装依赖（约 1-2 分钟）…」「正在启动 dev server…」「正在分析原稿并生成复刻清单…」
- **阶段之间必须有过渡提示**：进入下一阶段前用一句话交代上一阶段结果和下一步动作，例如「依赖安装完成，开始写页面代码」
- **长等待中要间断性报进度**：`npm install`、dev server 首次编译、大文件写入等超过约 30 秒的操作，等待期间穿插进度说明（已完成的子步骤、当前在等的具体事项），不要一次性闷头跑完
- **复刻/多页面等大任务**：按复刻清单或页面清单逐项报进度（「第 2/5 个区块：导航栏已完成」），让用户能看到推进
- **卡顿时如实说**：某步超过预期仍未完成，直接说明「XX 比平时慢，仍在进行 / 可能受阻，正在排查」，而不是沉默
- **不要刷屏**：进度一行一条、只在阶段切换或长等待时输出，不逐条播报每个工具调用；同一阶段内没有实质进展不重复报

## Git 提交（强制）

- **git 不存在先安装**：开始工作前执行 `command -v git`（Windows cmd/PowerShell 用 `where git`）检查；不存在时，**先征得用户同意再安装**（与 `references/environment.md` 的"系统级安装需用户同意"规则一致），用户同意后按对应平台安装：
  - Debian/Ubuntu：`apt-get install -y git`
  - CentOS/RHEL：`yum install -y git`
  - Alpine：`apk add git`
  - macOS：`brew install git`
  - Windows：优先 `winget install --id Git.Git -e --source winget`；没有 winget 时用 `choco install git -y`；两者都没有则从 https://git-scm.com/download/win 下载安装包静默安装。Windows 上装完后新开 shell 或把 `C:\Program Files\Git\cmd` 加入 PATH 再验证 `git --version`
- **不是 git 仓库先初始化**：项目根目录下没有 `.git` 时执行 `git init`；提交前检查 `user.name`，未配置时只需向用户索取名字并执行 `git config user.name "<名字>"`，`user.email` 不需要用户提供，自动生成一个占位邮箱即可，如 `git config user.email "<名字>@demo.local"`（未配置会导致提交失败）
- **每完成一个任务或一个改动就提交一次并推送**：一个页面、一个小功能、一次样式调整，各自对应一次 `git add -A && git commit && git push`，不要把多个改动攒成一个提交。**push 已获用户长期授权：每个任务完成后直接推送到远端，无需逐次再确认**；push 失败（如远端有新提交）时如实报告，不擅自用禁止命令强行处理
- **提交信息用中文**：遵循 `类型: 简述` 格式，类型从 `feat`（新页面/新功能）、`fix`（修复）、`style`（样式调整）、`chore`（依赖/配置）中选
- **简述必须是详细的功能描述，且从用户的原始输入中提取**：把用户这次要求的具体功能点写清楚——做了什么页面/功能、包含哪些关键要素（核心组件、交互、数据来源等），让不看代码的人仅凭提交信息就能知道这次改了什么。禁止 `feat: 新增页面`、`fix: 修改问题` 这类空泛描述
  - 用户说「做一个用户管理页，要有搜索、分页和批量删除」→ `feat: 新增用户管理列表页，支持关键字搜索、分页浏览和批量删除`
  - 用户说「把表格改成斑马纹，操作列固定到右侧」→ `style: 用户列表表格增加斑马纹样式，操作列固定到右侧`
  - 用户输入很简短时，结合实现内容补全成完整描述，但不得编造用户没要求的功能
- **git 操作白名单**：只允许 `git init`、`git add`、`git commit`、`git push`、`git pull`、`git merge`、`git tag` 七个写命令（含状态确认用的 `git status` / `git log` / `git diff` / `git tag -l` 等只读查询）。其中 `git push` 按上条规则在每个任务提交后直接执行；`git tag` 仅在用户确认满意后按 `references/handover.md` 流程使用（含删除后重打的 `git tag -d` / `git push origin :refs/tags/<tag>` 场景）；`git pull` / `git merge` **无冲突或冲突可自动合并时直接自动处理，无需逐次确认**，仅当产生 git 无法自动解决的冲突时，如实报告给用户，由用户决定处理方式，不擅自用禁止命令解决；其余一切 git 操作（`reset`、`rebase`、`checkout`/`switch`、`stash`、`clean`、`branch -D`、`push --force`、`merge --abort` 等）全部禁止，无论任何理由都不得执行

## 产出要求

- 页面要能直接打开看到效果，不留 TODO/占位
- demo 数据就地 mock（可用项目已有的 mockjs），不接真实后端
- 完成后告知用户访问地址（默认 http://localhost:8000/<路由>）
