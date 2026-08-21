# prd-demo-skills

React demo 页面构建的 agent skills，适用于 Umi Max + Ant Design 技术栈。目录结构遵循 [Agent Skills 开放标准](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)：每个 skill 一个扁平目录，目录名即 skill 名，`SKILL.md` 为入口，支撑材料放同级并由 SKILL.md 引用。

不会写代码、第一次用？直接看 [小白使用文档](docs/小白使用文档.md)。

## 安装方式一：让 agent 自动安装（推荐）

在支持 skills 的 agent 会话中，直接对 agent 说：

```
 把 https://github.com/zhiquanchi/prd-demo-skills 仓库里的 skills 安装好
 ```

**不需要指定目录**——agent 自动检测自己是哪种客户端，按下表选择安装位置（项目级优先；项目不是 git 仓库或客户端只扫用户级时，装用户级）：

| 客户端 | 项目级（随项目走） | 用户级（所有项目共享） |
|---|---|---|
| Kimi Code CLI | `<项目根>/.agents/skills/` 或 `.kimi-code/skills/` ⚠️见下 | `~/.agents/skills/` 或 `~/.kimi-code/skills/` |
| Claude Code | `<项目根>/.claude/skills/` | `~/.claude/skills/` |
| OpenAI Codex CLI | `<项目根>/.agents/skills/`（还会向上扫描父目录） | `~/.agents/skills/`（或 `~/.codex/skills/`） |
| Gemini CLI | `<项目根>/.gemini/skills/` | `~/.gemini/skills/` |
| Antigravity | `<项目根>/.agents/skills/` | 其全局 skill 目录 |
| opencode | `<项目根>/.agents/skills/` | `~/.config/opencode/skills/` |
| Cursor | `<项目根>/.cursor/skills/` | — |
| 其他兼容 Agent Skills 标准的客户端 | 优先 `.agents/skills/`（跨工具通用约定），装完用 `/skills` 类命令确认真的被列出 | 同左 |

**⚠️ Kimi Code 的重要前提**：项目级扫描以"向上查找最近的 `.git` 目录"定位项目根——**项目不是 git 仓库时项目级 skills 不会被加载**，必须装到用户级 `~/.agents/skills/`（Windows 即 `C:\Users\<你>\.agents\skills\`）。装完新开一个会话，确认 skill 列表里出现 `demo-page-builder` 再用。

检测依据：agent 当前会话已加载的 skill 列表来自哪个目录、项目里已存在哪个配置目录、项目是否为 git 仓库。检测不到时就地询问你，不会装错位置。**装完必须验证**：新开会话，让 agent 列出可用 skills，确认 `demo-page-builder` 在其中；不在就换用户级目录重装。

## 安装方式二：人工手动安装

```bash
# 1. 克隆本仓库（任意临时位置）
git clone https://github.com/zhiquanchi/prd-demo-skills.git /tmp/prd-demo-skills

# 2. 按上表复制到对应目录。示例（Kimi Code，项目为 git 仓库）：
mkdir -p /path/to/your-project/.agents
cp -r /tmp/prd-demo-skills/.agents/skills /path/to/your-project/.agents/
#    项目不是 git 仓库时装用户级（全项目生效）：
#    Linux/macOS: cp -r /tmp/prd-demo-skills/.agents/skills ~/.agents/
#    Windows(PS): xcopy /E /I C:\path\to\prd-demo-skills\.agents\skills %USERPROFILE%\.agents\skills

# 3. 重开 agent 会话，确认 skill 列表里出现 demo-page-builder
```

只需要复制 `demo-page-builder` 一个目录即可，`references/` 支撑材料已内嵌其中。

## 使用前提

无需提前准备工程：skill 以会话当前工作目录为项目根，目录为空或缺少 `package.json` 时会用 `assets/project-template/` 基准清单（package.json + package-lock.json + scripts）在当前目录就地初始化 Umi Max + React 18 + antd 5 工程。详细的环境探测、安装受阻处理见 `references/environment.md`，环境判断、起服务与验证规则见 `references/dev-server.md`。

## 包含的 skill

```
.agents/skills/
└── demo-page-builder/                # 唯一入口 skill：项目定位（当前工作目录就地初始化）、组件库白名单（antd / Ant Design Pro / Ant Design X）、先搜后用、Subagent 并行、交付确认
    ├── SKILL.md                      # 总控：流程编排与硬性规则（开工前置工具检测与任务清单、Git 检查点钩子、进度上报、交付确认）
    ├── references/                   # additional materials（非独立 skill，由 SKILL.md 引用）
    │   ├── whitelist.md              # 组件库白名单与清单外拒绝流程（依赖总闸，以 assets/project-template/package.json 为唯一标准）
    │   ├── environment.md            # node runtime 探测与安装、受阻处理、依赖安装的细则
    │   ├── dev-server.md             # 起服务与页面生效验证的细则（启动前检查 8000 端口被本任务旧进程占用则 kill 复用；WSL：生产构建+静态服务；其他环境：dev server 热更新）
    │   ├── routes.md                 # 路由与导航细则：路径命名与结构规范（kebab-case + REST）、首页空白自动跳转、新增页面必须绑定可点击入口、动态路由 $param 规则
    │   ├── interactivity.md         # 交互实现与「不生效」排查细则：事件绑定/受控组件/事件冒泡/列表 key 等硬规则、元素与行为解耦（同一行为收敛为单一实现）、源码→构建→服务→浏览器四层排查清单
    │   ├── directory-structure.md    # Umi 官方目录结构对照与按需创建规则、白名单模式 .gitignore
    │   ├── layout-patterns.md        # Umi Max 全局布局模式：<Outlet/> 而非 {children}（用错会内容区空白）
    │   ├── common-components.md      # 公共组件细则：侧边栏等跨页面布局组件必须提取为公共组件复用，样式不改、禁止重复侧边栏
    │   ├── replicate.md              # 参考原型复刻细则：用户提供 HTML/截图/原型时，先理解原稿再用当前技术栈一比一复刻
    │   ├── mock.md                   # 示例数据用 Umi mock 细则：生成/复刻时的示例数据一律写入 mock/ 目录（<domain>.json 唯一数据源 + <domain>.ts 导出接口）、页面用 request 取数，不放 UI 组件里
    │   ├── git.md                    # Git 预检/初始化/提交/推送频率、操作白名单、环境禁止 git 时的权限申请
    │   ├── use-cases.md              # 业务说明（用例）撰写细则：用例概述 → 正常流程 → 异常流程 → 业务规则
    │   ├── handover.md               # 交付确认细则：用户确认满意后打中文语义 git tag 并生成同名交接文档（docs/handover/<tag名>.md），多页面按页面拆分、存量核对、已交付页面的后续修订；格式可参考 handover.example.md
    │   ├── handover.template.md      # 交接文档固定模板：五个一级章节 + 每功能 0–8 用例字段，生成时逐字照抄只换占位符
    │   ├── handover.example.md       # 交接文档示例：以「用户管理页」演示五部分写法（使用说明+流程图、DOM树与组件说明、设计与UX、功能说明、对话过程摘要），其中 DOM 树最底层终止于白名单原子组件
    │   └── mermaid.md                # Mermaid 生成细则：交接文档的用户操作流程图 / 用户流程（flowchart）
    ├── scripts/                      # 机器护栏脚本（输出格式与退出码 POSIX/Windows 一致）
    │   ├── posix/                    # check-environment.sh / init-project.sh / verify-page.sh / git-checkpoint.sh（bash）
    │   ├── windows/                  # 同名 PowerShell 版（.ps1；不提供 cmd .bat，cmd 环境请改用 PowerShell）
    │   ├── serve-dist.js             # WSL 静态服务：express 4 静态托管 + mock JSON 等价 API 路由（防 SPA fallback 白屏）
    │   └── validate-handover.mjs     # 交接文档自检脚本：逐项输出 [PASS]/[FAIL]，全部通过才能报告完成
    └── assets/
        └── project-template/         # 就地初始化模板：package.json + package-lock.json（依赖清单基准）+ scripts/（serve-dist.js、validate-handover.mjs）
```

- **demo-page-builder**：生成 demo、画页面、生成 HTML 等任务的入口。**始终以用户会话的当前工作目录为项目根**，当前目录不是 Umi Max 工程时就地初始化（复制 `assets/project-template/` 的依赖清单与脚本、生成白名单模式 `.gitignore`、安装依赖），严禁写入 skill 自身所在的分发仓库。组件库严格限定 Ant Design / Ant Design Pro / Ant Design X，禁止其他组件库；长耗时环节必须定时上报任务进度，防止用户误以为卡死；每个改动必须生效（非 WSL 热更新/重启服务、WSL 重新构建）并交给用户确认效果；用户确认满意后打中文语义 git tag 并生成同名交接文档，作为交付收尾。
- **references/environment.md**：环境准备细则——node runtime 探测（识别 bun 壳）、无 runtime 时项目级免安装部署（Linux/macOS/Windows）、公司环境拦截时停止并上报、`--legacy-peer-deps` 安装。
- **references/dev-server.md**：起服务与验证细则——启动前先查 8000 端口：被本任务旧进程占用则 kill 复用原端口，被无关进程占用则换端口；再判断环境：WSL 用生产构建 + express 静态服务（规避 WSL 转发层断开 HMR WebSocket 导致的整页刷新），其他环境用 dev server 热更新（新目录后必须重启）；用懒加载 chunk 验证页面真的打进产物。
- **references/routes.md**：路由与页面导航细则——Umi 约定式路由速查；首页 `/` 不允许空白，自动跳转第一个有内容的页面；新增页面必须分析并绑定左侧导航入口（已有菜单项必绑跳转、缺入口则补菜单项），菜单选中态跟随路由。
- **references/replicate.md**：参考原型复刻细则——用户提供 HTML 文件/代码片段、截图、设计稿、线上 URL 等参考物时，先拆解原稿产出复刻清单（区块、精确配色、字体间距、交互、文案），再将原稿元素映射到白名单组件，用当前技术栈一比一复刻，最后截图与原稿对比验证还原度。
- **references/mock.md**：示例数据用 Umi mock 细则——生成 demo 和复刻原型时，页面所需的示例数据（列表、表格、卡片、图表、表单回填、详情等）一律用 Umi mock（https://umijs.org/docs/guides/mock）：数据写入项目根 `mock/<domain>.json`（唯一数据源）+ `mock/<domain>.ts`（导入 JSON 导出接口），页面用 Umi Max 内置 `request` 异步取数，禁止把示例数据硬编码在 UI 组件里；可用清单内已有的 `mockjs` 生成随机/批量数据。
- **references/common-components.md**：公共组件规则——侧边栏等跨页面布局组件必须提取到 `src/components/` 统一引用，禁止逐页复制；样式以项目现有实现为唯一来源，不改样式、不做覆盖；新增页面只允许加菜单项、绑跳转这类结构性变更。
- **references/handover.md**：交付确认细则——用户明确认可后，按 `deliver-<中文语义名>-<日期>-<序号>` 打 git tag 并推送，同时生成同名交接文档 `docs/handover/<tag名>.md`（**新增页面与复刻 demo 均适用**：描述使用者实际使用页面的操作逻辑并配用户操作流程图、给出页面 DOM 树并说明每个组件是什么、补充设计与用户体验（设计原则/用户流程/原型/全局状态）与功能说明（目标/场景/字段规则/状态/验收标准）、对话过程摘要放最后），作为每次交付的收尾动作。**硬性闭环：先套 `references/handover.template.md` 固定模板生成，生成后必须运行 `scripts/validate-handover.mjs` 自检，全部 `[PASS]` 才能报告完成**。
- **references/handover.template.md**：交接文档固定模板——五个一级章节 + 每个功能的 0–8 完整用例字段（用例概述/功能目标/用户场景/页面界面说明/正常流程/业务规则/状态表现/异常流程/验收标准），生成交接文档时逐字照抄、只换占位符。
- **scripts/validate-handover.mjs**：交接文档自检脚本——`node scripts/validate-handover.mjs docs/handover/<tag名>.md`，机器校验五个一级章节唯一性、mermaid/flowchart、Design & UX 独立用户流程、每个功能完整用例字段、异常流程为表格、DOM 树叶子为白名单组件、无 TODO/待补充/无依据假设、文件名与 tag 一致；任一 `[FAIL]` 必须修正后重跑。
