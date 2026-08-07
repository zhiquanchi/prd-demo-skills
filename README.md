# prd-demo-skills

React demo 页面构建的 agent skills，适用于 Umi Max + Ant Design 技术栈。目录结构遵循 [Agent Skills 开放标准](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)：每个 skill 一个扁平目录，目录名即 skill 名，`SKILL.md` 为入口，支撑材料放同级并由 SKILL.md 引用。

## 包含的 skill

```
.agents/skills/
└── demo-page-builder/                # 唯一入口 skill：项目定位（当前工作目录就地初始化）、组件库白名单（antd / Ant Design Pro / Ant Design X）、先搜后用、交付确认
    ├── SKILL.md
    └── references/                   # additional materials（非独立 skill，由 SKILL.md 引用）
        ├── environment.md            # node runtime 探测与安装、受阻处理、依赖安装的细则
        ├── dev-server.md             # dev server 启停、热更新与页面生效验证的细则
        ├── replicate.md              # 参考原型复刻细则：用户提供 HTML/截图/原型时，先理解原稿再用当前技术栈一比一复刻
        └── package.json              # 已知可用的依赖清单基准（新项目就地初始化时复制使用）
```

- **demo-page-builder**：生成 demo、画页面、生成 HTML 等任务的入口。**始终以用户会话的当前工作目录为项目根**，当前目录不是 Umi Max 工程时就地初始化（复制 `references/package.json`、生成 `.gitignore`、安装依赖），严禁写入 skill 自身所在的分发仓库。组件库严格限定 Ant Design / Ant Design Pro / Ant Design X，禁止其他组件库；每个改动必须热更新或重启服务并交给用户确认效果。
- **references/environment.md**：环境准备细则——node runtime 探测（识别 bun 壳）、无 runtime 时项目级免安装部署（Linux/macOS/Windows）、公司环境拦截时停止并上报、`--legacy-peer-deps` 安装。
- **references/dev-server.md**：起服务与验证细则——dev server 启停、新目录后必须重启、用懒加载 chunk 验证页面真的打进 bundle。
- **references/replicate.md**：参考原型复刻细则——用户提供 HTML 文件/代码片段、截图、设计稿、线上 URL 等参考物时，先拆解原稿产出复刻清单（区块、精确配色、字体间距、交互、文案），再将原稿元素映射到白名单组件，用当前技术栈一比一复刻，最后截图与原稿对比验证还原度。

## 安装方式一：让 agent 自动安装（推荐）

在支持 skills 的 agent 会话中，直接对 agent 说：

> 把 https://github.com/zhiquanchi/prd-demo-skills 仓库里的 skills 安装好

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

无需提前准备工程：skill 以会话当前工作目录为项目根，目录为空或缺少 `package.json` 时会用 `references/package.json` 基准清单在当前目录就地初始化 Umi Max + React 18 + antd 5 工程。详细的环境探测、安装受阻处理见 `references/environment.md`，起服务、热更新与验证规则见 `references/dev-server.md`。
