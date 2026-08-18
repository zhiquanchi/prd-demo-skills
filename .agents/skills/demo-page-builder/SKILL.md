---
name: demo-page-builder
description: 生成 demo、画页面、做界面、生成 HTML/原型/落地页/仪表盘等一切前端页面产出任务的入口 skill。触发词：生成demo、画个页面、做个页面、生成html、画界面、写个页面、demo页、原型页、复刻页面、还原原型、照这个做。技术栈：Umi Max 4 + antd 5 + React 18，组件库白名单见 references/whitelist.md，细则分散在 references/ 各文档中。
---

# Demo 页面构建总控

一切"生成 demo / 画页面 / 生成 HTML"类任务的父 skill。负责组件库选型和流程编排；细则分多份参考文档（与本文件同级 `references/` 目录下）：**组件库白名单与清单外拒绝流程见 `references/whitelist.md`**，环境准备（node runtime、依赖安装）见 `references/environment.md`，起服务与页面生效验证（启动前检查 8000 端口被本任务旧进程占用则 kill 复用，再判断环境：WSL 用生产构建+静态服务，其他环境用 dev server 热更新；服务优先用后台任务启动，若无后台任务功能则用 subagent 后台运行；服务管理规则见同文件）见 `references/dev-server.md`，路由路径命名（kebab-case + REST 风格）与结构规范、首页跳转与左侧导航绑定见 `references/routes.md`，用户提供了 HTML/截图/原型需要复刻时见 `references/replicate.md`，**生成/复刻时的示例数据一律用 Umi mock、写入 `mock/` 目录而不放 UI 组件里见 `references/mock.md`**，侧边栏等跨页面布局组件的公共组件规则见 `references/common-components.md`，**Umi Max 全局布局模式与 `<Outlet/>` 正确用法见 `references/layout-patterns.md`**，Git 操作全套规则（预检/提交/白名单/权限）见 `references/git.md`，用户确认满意后打 git tag 与生成交接文档见 `references/handover.md`，为页面/功能编写业务说明（用例，正常流程+异常流程+业务规则）见 `references/use-cases.md`，生成 Mermaid 图（交接文档流程图、用户流程等）见 `references/mermaid.md`，**新项目与新增功能的目录组织以 Umi 官方目录结构为准、按需创建见 `references/directory-structure.md`**。

## 项目定位（第一优先级，先于一切流程）

- **项目根 = 用户会话的当前工作目录**（pwd）。所有文件写入、依赖安装、dev server、git 操作都只在当前工作目录下进行。
- **严禁把 skill 自身所在目录当作项目根**：本 skill 可能安装在 `~/.agents/skills/` 或某个分发仓库（如 `prd-demo-skills`）里，那些位置不是用户的项目。绝不向 skill 目录写页面、装依赖、起服务或提交 git。
- **当前目录不是前端工程时先就地初始化**：当前目录没有 `package.json`（或不是 Umi Max 工程）时，在当前目录原地初始化，而不是换到别的目录：
  1. 按 `references/environment.md` 探测 node（POSIX 环境运行本 skill 的 `scripts/posix/check-environment.sh`；Windows 在 PowerShell 里用 `scripts/windows/check-environment.ps1`），然后运行本 skill 的 `scripts/posix/init-project.sh <当前目录>` 完成初始化：从 `assets/project-template/` 复制 `package.json`、`package-lock.json`、`scripts/serve-dist.js` 与 `scripts/validate-handover.mjs`，把 `name` 改成当前目录名，并写好白名单模式 `.gitignore`（`/*` 默认忽略一切，只放行必要文件/目录——`package.json`、`package-lock.json`、`README.md`、`.umirc.ts`、`plugin.ts`、`config/`、`docs/`、`mock/`、`public/`、`scripts/`、`src/`；目录内 `node_modules/`、`dist/`、`.runtime/`、`src/.umi*/` 仍忽略，`.env` 有意不放行防误提交敏感信息，**`src/pages` 在白名单内页面文件必须能被 git 提交**）；Windows 环境（无 bash）运行 `scripts/windows/init-project.ps1 <当前目录>`（PowerShell）完成初始化（不提供 cmd `.bat` 版本，cmd 环境请改用 PowerShell）
  2. 执行 `npm ci --legacy-peer-deps --no-audit --no-fund`（lock 文件缺失时才退回 `npm install --legacy-peer-deps --no-audit --no-fund`）
  3. Umi Max 约定式路由零配置即可跑，不需要额外配置文件
  4. 后续目录（`src/pages/`、`mock/`、`src/layouts/` 等）按 `references/directory-structure.md` 的按需创建规则，随首个对应文件一起创建，不预建空目录
- 用户明确指定了其他目录时，以用户指定为准。

## 开工前置：工具检测与任务清单（强制）

进入任何业务动作（含 Git 预检）之前，先完成本节两步；本节不因环境工具名称不同而豁免（与「Subagent 并行开发」的术语约定同一原则：按当前环境实际可用的工具名执行，工具名不同不构成豁免）。

### 工具检测（开工第一步，只读）

1. **盘点当前环境可用工具**，逐项确认并记录（探测方式：环境自带的工具枚举，或只读命令如 `command -v git node npm`；不装任何东西）：
   - 终端执行工具（本 skill 语境统称 `shell`：VS Code Copilot / Codex 的 `run_in_terminal`、Claude Code 的 `Bash` 等）——缺失时初始化/构建/起服务/验证流程不可执行，先向用户说明缺口再继续
   - git 是否可用：`command -v git`
   - 文件编辑工具（统称 `apply_patch` 系列）
   - subagent 派发工具（统称 `spawn_agent` 系列）
   - 任务清单工具（统称 `todo_tool`：VS Code Copilot 的 `manage_todo_list`、Codex 的 `todo-list`、Claude Code 的 `TODO` 等）
   - 浏览器/页面验证工具（截图、无头浏览器、HTTP 断言等，用于生效验证）
   - 本 skill 自带脚本是否齐全：`scripts/posix/`（或 `scripts/windows/`）下的 `check-environment`、`init-project`、`verify-page`、`git-checkpoint`，以及 `scripts/serve-dist.js`、`scripts/validate-handover.mjs`
2. **探测结果写进本轮第一条进度消息**（例如「工具检查：shell ✓ / git ✓ / apply_patch ✓ / spawn_agent ✓ / todo_tool ✓ / 浏览器 ✓」），按「进度上报」节格式输出，不额外刷屏。

### 任务清单生成（开工第二步，强制）

工具检测完成后、任何写入或 git 操作前，必须用当前环境的 `todo_tool` 创建任务清单（该工具缺失时用进度消息中的文字清单替代并注明）。清单必须包含以下条目，可再细化但**不得删减 git 相关项**：

1. Git 预检与仓库初始化（按 `references/git.md`）
2. 环境探测与项目初始化（`check-environment` + 需要时 `init-project` + `npm ci`；已是 Umi 工程则跳过此项）
3. 任务拆分与 subagent 派发（存在多个独立单元时必须先派发 `spawn_agent`，见「Subagent 并行开发」）
4. 页面实现（**每个业务改动拆成一个「实现 + git 提交」条目**：实现 → 跑「Git 检查点钩子」→ 提交 → 才允许标记该条 completed）
5. 生效与验证（build / dev server / 静态服务 + `verify-page`，见 `references/dev-server.md`）
6. 下发访问地址并等待用户确认（确认前不把本条标记完成，也不得进入交付步骤）
7. 打 tag + 生成交接文档 + `validate-handover.mjs` 自检全 `[PASS]`（见「交付与确认」）

规则：

- **git 提交内嵌在清单里**：条目 4 默认已包含提交动作，禁止出现「实现完成但未提交」的 completed 项；也禁止把全部提交推迟到用户确认后
- 每完成一项立即用 `todo_tool` 更新状态，并照「进度上报」报一行进度；条目 6、7 在用户确认前保持 not-started / in-progress，不提前标记完成

## 目录结构（Umi 官方约定，按需创建）

初始化项目与后续新增功能时的目录组织，**以 Umi 官方目录结构（https://umijs.org/docs/guides/directory-structure）为准**，完整对照表与创建时机见 `references/directory-structure.md`。核心原则：

- **按需创建，不需要的目录不要新建**：空目录不预建、不提交 git，用到该类文件时才连文件一起创建目录（如写第一个页面才建 `src/pages/`，需要示例数据才建 `mock/`）
- `dist/`、`src/.umi/`、`src/.umi-production/` 是构建/临时产物，**永不手动创建**，已被 `.gitignore` 忽略
- 本项目约定式路由零配置即可跑，`.umirc.ts` / `config/config.ts` 默认都不建，需要配置时优先 `.umirc.ts`

## 组件库白名单（严格限制，禁止引入其他组件库）

完整规则见 `references/whitelist.md`——依赖总闸、清单速查表、用户点名要求清单外组件时的拒绝流程，全部以该文件为准。写代码前必须确保所有用到的库都在 `assets/project-template/package.json` 的依赖清单（`dependencies` + `devDependencies`）内，**禁止安装任何新依赖**。

## 参考原型复刻（用户提供了 demo / 原型时，先于常规流程）

用户提供了参考物（HTML 文件或代码片段、页面截图、设计稿、线上页面 URL 等）并要求"照这个做 / 复刻 / 还原"时，**不要直接进入常规工作流程**，先按 `references/replicate.md` 执行：

1. **先理解原稿**：拆解参考物，产出复刻清单（区块划分、精确配色、字体间距、交互、文案）
2. **组件映射**：原稿元素全部映射到白名单组件，清单外一律禁止
3. **一比一复刻**：布局、配色（精确色值）、文案逐字还原，样式用 antd-style
4. **对比验证**：截图与原稿并排核对，不像就改到用户确认像为止

复刻场景的其余规则（白名单、git 提交、交付确认）与常规任务完全一致——用户确认满意后同样打 git tag 并生成交接文档，交接文档要求（使用说明 + 用户操作流程图 + DOM 树与组件说明 + 设计与用户体验 + 功能说明 + 对话过程摘要）与新增页面一视同仁。

## 工作流程（必须按顺序）

进入下列步骤前，先完成上方「开工前置」节（工具检测 + 任务清单）与下方「Git 预检」节：项目一开始（最迟第一个页面动工前）就完成 git 检查与仓库初始化，**不拖到打 tag / 生成交接文档时才 `git init`**；此后每个阶段结束运行「Git 检查点钩子」（见「Git 规则」节），`checkpoint` 非 `clean` 时先提交再继续。

1. **先搜后用**：写代码前，先在对应组件库中搜索所需组件是否已存在、叫什么、用法是什么：
   - 优先调用本机已有的 `ant-design` / `antd` skill 查 API、props、demo
   - 查不到再查本地包文档（`node_modules/<包>/es/**/demo`、`*.md`）或官方文档
   - 禁止凭记忆硬写不熟悉的组件 API；查到再写
2. **选型**：按上表定位到组件库 → 定位到具体组件 → 确认当前项目装的大版本（antd 是 v5，ProComponents v2，X v2）与该版本文档一致
3. **实现**：先执行「Subagent 并行开发」的编辑前硬门禁；门禁完成前禁止编辑业务代码。页面写到 `src/pages/`（Umi 约定式路由，路径命名用 kebab-case + REST 风格、按 `references/routes.md` 的「路径命名与结构规范」执行），样式用 antd 体系（主题 token、`antd-style`），不要引入白名单外的依赖；首页空白跳转、新增页面的导航绑定按 `references/routes.md` 执行，**页面所需示例数据一律用 Umi mock、写入 `mock/` 目录，不放 UI 组件里，按 `references/mock.md` 执行**；编码环节能并行拆分的按下方「Subagent 并行开发」用多个 subagent 并行实现
4. **生效与验证**：按参考文档 `references/dev-server.md` 执行（先判断环境：WSL 用生产构建+静态服务，其他环境用 dev server 热更新），并用懒加载 chunk 验证页面真的打进产物，页面用到 mock 接口时用 `--api` 逐个断言返回合法 JSON（静态模式下尤其必要，防止 SPA fallback 把 `/api/*` 当页面返回 `index.html` 导致白屏）——不许"写完就报完成"
5. **antd v5 注意**：`@ant-design/x` v2 的 peer 要求 antd 6，本项目是 antd 5 + `--legacy-peer-deps` 装上的。仅当使用 X 组件且**运行时报错**时，才按 `references/environment.md` 的"安装依赖"节给出的根治方案（升 antd 6 或降 X 1.x）请用户决策——这是阻塞项，拿到用户决定前不要绕过；未报错则正常使用，不必提前处理

## Subagent 并行开发（编辑前硬门禁，强制）

本节不是建议。只要存在可并行的编码单元，主会话必须调用多个 `spawn_agent`；不得直接自行开始页面文件编辑。

术语约定（跨工具兼容）：本文的 `spawn_agent` 指代当前环境的子代理派发工具——Codex 的 `spawn_agent`、Claude Code 的 `Task`、VS Code Copilot 的 `runSubagent`、Cursor / Gemini CLI / OpenCode 等框架的同类工具；`apply_patch` 同理指代文件编辑工具（Codex 的 `apply_patch`、Claude Code 的 `Edit`/`Write`、VS Code 的 `create_file`/`replace_string_in_file`/`insert_edit_into_file` 等）。门禁按当前环境实际可用的工具名执行，工具名不同不构成豁免；支持同消息并行调用的环境（如 Claude Code 的多 `Task` 同发）应一次性同发，不支持的按顺序连续派发。

### 派发门禁

在首次执行 `apply_patch`、创建/删除/修改业务代码文件前，主会话必须依次完成：

1. 列出本轮将修改或新增的业务文件。
2. 按“两个任务不会写同一文件”的原则划分独立单元，并标明依赖关系。
3. 只要存在 2 个或以上独立单元，必须在首次业务代码编辑前连续调用至少 2 次 `spawn_agent`，同层任务同时派发。
4. 每个 subagent 任务必须明确：唯一负责的文件路径、使用的白名单组件、mock 接口路径与返回字段、禁止修改的文件。
5. 主会话仅负责：任务拆分、共享数据契约、存在写入冲突的公共文件、结果验收、集成与验证。

禁止以“任务较小”“先写骨架”“先处理一个页面”“后面再拆”为由跳过派发门禁。

### 默认拆分规则

以下组合默认可并行，除非主会话明确说明文件级依赖：

- 公共布局/导航 与 页面业务区
- 页面骨架 与 `mock/<domain>.json`、`mock/<domain>.ts`
- 列表页 与 详情页
- 多个互不修改同一文件的页面
- 独立页面区块，各自落在不同组件文件中

共享布局、路由入口或公共类型由一个指定单元负责；其他 subagent 不得编辑这些文件。

### 不可并行的例外

只有同时满足以下条件，才可以不派发多个 subagent：

- 本轮仅修改一个业务文件；
- 没有独立 mock、页面、组件、样式或测试文件可分配；
- 将原因写入本轮进度消息。

“主会话认为改起来很快”不是例外理由。

### 派发要求与验收

- 编码 subagent 使用当前可用的最快模型与最低 reasoning。
- subagent 被阻塞时立即返回错误原文、已尝试动作和怀疑原因，不得自行扩展范围或反复试错。
- subagent 完成后，主会话必须检查文件边界、白名单、mock 契约和构建结果。
- 任一 subagent 不合格时，主会话必须修复或重新派发，不能直接报告完成。

## 示例数据用 Umi Mock（强制）

生成 demo 和复刻原型时，页面需要展示/操作的**示例数据一律使用 Umi 的 mock 功能**（官方文档：https://umijs.org/docs/guides/mock），**写入项目根 `mock/` 目录，不写进 UI 组件**。细则见 `references/mock.md`。

- **数据放哪**：示例数据（列表、表格、卡片、图表、表单回填、详情等）统一放 `mock/<domain>.json`（数据本体、唯一数据源）+ `mock/<domain>.ts`（导入 JSON 导出 Umi Mock 接口）；**禁止把数据硬编码在 `src/pages/**`、`src/components/**` 里**（页面里写 `const data = [...]`、或 import 一个放在 `src/` 下的数据文件都不行），也禁止在静态服务脚本里重复硬编码
- **页面怎么取数**：用 Umi Max 内置的 `request`（从 `@umijs/max` 导入，零配置免装依赖）异步请求 mock 接口；`mock/` 里的接口路径与页面 `request` 的路径必须一致；**取数必须带运行时格式校验与 `.catch()` 兜底**——接口失败或响应格式不符时保留安全初始状态（列表初始 `[]`）并显示可理解的错误提示，**不得把 `undefined` 写进后续会 `.filter()`/`.map()` 的 state 导致白屏**
- **生产静态服务（WSL 模式 A）必须提供等价 API 路由**：Umi Mock 只在 dev 模式生效，静态服务 `scripts/serve-dist.js` 会自动把 `mock/<name>.json` 注册为 `GET /api/<name>`，未注册的 `/api/*` 一律 404 JSON、绝不 SPA fallback 返回 `index.html`（否则页面把 HTML 当 JSON 解析即白屏）；新增 mock JSON 文件后需重启服务，重启前先检测端口占用、停掉本项目旧进程，重启后用 `--api` 重新断言返回的是新数据 JSON。静态模式白屏（构建、静态服务、首屏、mock API 成功返回、接口异常兜底）是必测回归场景，细则见 `references/mock.md` 与 `references/dev-server.md`
- **mock 的是数据来源，不是功能**：交互逻辑（增删改、搜索、筛选、排序、分页、表单校验）仍真实实现、真实生效，只是数据来自 mock 接口，不能因为 mock 就跳过功能
- **批量/随机数据**：可用项目模板 `package.json` 里已有的 `mockjs` 生成，不额外装包
- **复刻场景**：原稿里的真实文案/数据可直接作为 mock 返回值，规则同样适用（见 `references/replicate.md`）

## 业务说明（用例）（按需）

当用户要求为登录、评论、下单等业务功能编写**用例**（业务说明），或在 PRD/交接文档中需补齐用例章节时，按 `references/use-cases.md` 撰写完整用例（用户确认满意后，用例随交接文档写入 `references/handover.md` 的「功能说明」一节）：

- **每个用例四要素**：用例概述（名称/编号/参与者/优先级/前置/后置条件/触发事件）→ 正常流程（分步）→ 异常流程（表格：编号/触发操作/系统表现/处理结果）→ 业务规则
- **异常流程要穷举**：输入校验、格式/长度限制、网络异常、重复提交、敏感词脱敏、权限不足等场景逐条列出
- **涉及产品决策但未确认的**（如失败锁定策略、排序方向）如实标注「需产品确认」，不擅自假定
- 用例描述的校验/交互逻辑若落为 demo 页，示例数据仍走 Umi mock，逻辑真实实现

## 交付与确认（强制）

起服务、热更新/重启、重新构建等服务管理操作见 `references/dev-server.md`，它们只是让改动生效的手段，不算交付物。以下是业务改动（页面、功能、样式）的交付规则。

### 业务改动（交付物，需用户确认）

- **每一个业务改动（页面、小功能、样式调整）完成后**，先让新改动生效（dev 模式等热更新或重启，WSL 静态模式重新 `npm run build`），**改动生效后的第一条消息就把访问地址（默认 http://localhost:8000/<路由>）发给用户确认效果**；没经过用户在浏览器里确认前，不把任务标记为完成
- **硬性顺序：地址下发优先于内部验证**——生效后的第一条消息就发地址，**不允许先做内部验证（verify-page、无头浏览器、构建产物检查、跑测试等）再发地址**；验证是后台动作，可在发地址后并行进行，不能替代用户确认，也不能成为延迟发地址的理由
- 用户反馈不满意 → 改 → 再生效 → **再第一时间把地址/效果发给用户** → 再确认，循环直到用户认可
- **用户明确认可后（"可以了/满意/就这样"），打 git tag 并生成与 tag 同名的交接文档**（`docs/handover/<tag名>.md`，**新增页面与复刻 demo 均适用**），完整流程见 `references/handover.md`；这是交付的收尾动作，不可省略；**一轮认可覆盖多个页面时按页面拆分：每个页面一个 tag + 一份同名交接文档**，禁止把多个页面塞进同一份文档（拆分细则见 `references/handover.md` 的「多页面交付：按页面拆分」）

### 已交付页面的后续修改（交付修订，强制）

- **任何已打 `deliver-*` tag 的页面，只要后续发生业务代码、布局、样式、交互、mock 数据契约或公共组件改动，都视为新的交付修订**；不得因“只是样式调整”而跳过交接文档。
- 修改前先用 `git log --oneline --all -- <页面路径> <相关公共组件路径>` 和 `git tag -l 'deliver-*'` 定位该页面最近的交付 tag 与对应的 `docs/handover/<tag名>.md`；布局/公共组件变更必须列出所有受影响页面。
- 新改动生效后，仍按本节先下发访问地址并等待用户确认。确认前只提交业务改动，**禁止修改交接文档内容**。
- 用户确认后，在原有 `docs/handover/<tag名>.md` 上**就地更新**——以当前代码为准只更新需要更新的部分（章节、功能用例、用户流程），不重写整个文档；功能有增改就同步增补/更新对应功能用例与**一一对应的用户流程（3.2 每功能一条）**，未改动的部分保留不动。自检全 `[PASS]` 后必须 `git add -A && git commit`（提交信息 `docs: 更新 <tag名> 交接文档`），再打一个新的 `deliver-*` tag 标记本次修订代码的版本——**有改动就有提交，文档与代码改动都不允许停留在未提交状态**。
- 在原有文档的「五、对话过程摘要」中**追加**一条修订记录（格式同下），排在已有摘要的最后。旧 tag 保留为历史快照；"最新交接文档"定义为该页面最近一次 `deliver-*` tag 对应的文档。详细步骤与核对规则见 `references/handover.md` 的「已交付页面的后续修改」。

### 交接文档生成（硬性闭环，先模板后校验）

交接文档的详细规则、tag 命名、写作要求见 `references/handover.md`。这里强调硬性闭环：任何人生成交接文档都必须按三步走，任一检查项不通过都不得向用户报告完成。

1. **生成前必读（缺一不可）**：`references/handover.md`、`references/handover.template.md`、`references/mermaid.md`
2. **生成前存量核对（硬性）**：先在 git 中确认交付涉及页面与历史交付页面是否已有对应交接文档（`git tag -l 'deliver-*'` + `git log --oneline --all -- docs/handover/`），缺失的一并补全、tag 在但文档丢的先用 `git show` 找回，细则见 `references/handover.md` 的「存量核对与补全」
3. **识别交付修订（硬性）**：本次若修改了已交付页面，先定位上一交付 tag；已有对应交接文档则就地更新原文件，没有则新建——基于当前代码完整重写五个章节、全部功能用例与**每功能一条的用户流程（3.2）**，并在「对话过程摘要」中追加修订记录
4. **按模板生成**：以 `handover.template.md` 为骨架，保持五个一级章节不变，每个功能填全 0–8 用例字段，**3.2 用户流程按功能逐条写（功能有几个写几条，标题带用例编号）**；**一份文档只写一个页面**——多页面交付按页面拆成多份、逐份生成逐份校验
5. **生成后自检（硬性）**：运行 `node scripts/validate-handover.mjs docs/handover/<tag名>.md`，全部 `[PASS]` 才能继续提交、打 tag、推 tag；校验不通过时不得跳过；项目 `scripts/` 缺该脚本时先从 skill `scripts/` 复制进来再跑，**禁止以"脚本不存在"为由退化为手工检查**

## 进度上报（强制，防止用户误以为卡死）

长耗时环节必须持续向用户输出进度，**不允许长时间静默执行**：

- **每个阶段开始时先报一行**：说明当前在做什么、预计耗时，例如「正在安装依赖（约 1-2 分钟）…」「正在启动 dev server…」「正在分析原稿并生成复刻清单…」
- **服务就绪即报地址（第一条输出）**：dev server 编译完成（模式 B）或生产构建+静态服务就绪（模式 A）后，**第一条消息就是「已就绪 + 访问地址」**，再进入验证；修复 bug 后重新生效同样立即把地址/效果告知用户，**不许先静默验证再一次性汇报**
- **阶段之间必须有过渡提示**：进入下一阶段前用一句话交代上一阶段结果和下一步动作，例如「依赖安装完成，开始写页面代码」
- **长等待中要间断性报进度**：`npm install`、dev server 首次编译、大文件写入等超过约 30 秒的操作，等待期间穿插进度说明（已完成的子步骤、当前在等的具体事项），不要一次性闷头跑完
- **复刻/多页面等大任务**：按复刻清单或页面清单逐项报进度（「第 2/5 个区块：导航栏已完成」），让用户能看到推进
- **卡顿时如实说**：某步超过预期仍未完成，直接说明「XX 比平时慢，仍在进行 / 可能受阻，正在排查」，而不是沉默
- **不要刷屏**：进度一行一条、只在阶段切换或长等待时输出，不逐条播报每个工具调用；同一阶段内没有实质进展不重复报

## Git 规则（强制）

完整规则见 `references/git.md`——Git 预检（项目一开始执行）、安装、初始化、提交频率与推送、操作白名单、环境权限申请，全部以该文件为准。核心要点：项目一开始就完成 git 初始化与配置，每个业务改动单独提交并推送，提交信息用中文 `类型: 简述` 格式，仅使用白名单内的 git 命令。

### Git 检查点钩子（阶段强制）

每个阶段结束时（项目初始化完成、每个业务改动生效、每个 subagent 单元验收、下发地址后、生成交接文档前）必须运行本 skill 的检查点钩子脚本，检查当前项目目录的 git 提交状态：

- **运行方式**：`bash scripts/posix/git-checkpoint.sh <项目目录>`（POSIX）；Windows 用 `scripts/windows/git-checkpoint.ps1`（PowerShell；不提供 cmd `.bat` 版本，cmd 的代码页机制无法可靠解析脚本内中文提示，Windows 环境一律用 PowerShell 版）
- **退出码语义**：`0`=`checkpoint=clean`（全部已提交，PASS）；`1`=`checkpoint=dirty`（有未提交改动，FAIL）；`20`=git 缺失；`21`=尚未 `git init`
- **`dirty`（退出码 1）**：先 `git add -A && git commit`（提交信息 `类型: 简述`）再继续，不许带着未提交改动进入下一阶段，也不许以「待用户确认后一起提交」为由跳过
- **`20` / `21`**：Git 预检完成后的任何阶段出现即 FAIL——`20` 按 `references/git.md` 安装 git（唯一征询点）；`21` 立即补做预检初始化与首次提交
- **检查点不过时**：不得把对应 `todo_tool` 条目标记为 completed，不得向用户报告完成

## 产出要求

- **任何新增页面必须有可点击入口（全局强制）**：页面必须能通过点击按钮/菜单进入（主功能页补侧栏/顶部菜单项，工具页/详情页在来源页面提供按钮/链接），**不允许只能通过输入路由 URL 访问**；细则见 `references/routes.md`
- 页面要能直接打开看到效果，不留 TODO/占位
- 示例数据一律用 Umi mock（写入 `mock/` 目录，页面用 `request` 取数），不放 UI 组件里，不接真实后端；细则见 `references/mock.md`
- **页面生效后第一时间告知用户访问地址（默认 http://localhost:8000/<路由>）**：顺序必须是「先发地址 → 后台验证 → 用户浏览器确认」，而不是等任务收尾（提交/总结时）才告知地址
