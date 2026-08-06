# prd-demo-skills

React demo 页面构建的 agent skills，适用于 Umi Max + Ant Design 技术栈。目录结构遵循 [Agent Skills 开放标准](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)：每个 skill 一个扁平目录，目录名即 skill 名，`SKILL.md` 为入口，支撑材料放同级并由 SKILL.md 引用。

## 包含的 skill

```
.agents/skills/
└── demo-page-builder/                # 唯一入口 skill：组件库白名单（antd / Ant Design Pro / Ant Design X）、先搜后用、交付确认
    ├── SKILL.md
    └── references/                   # additional materials（非独立 skill，由 SKILL.md 引用）
        ├── dev-server.md             # node 环境探测与安装、依赖安装、dev server 启停、热更新与验证的细则
        └── package.json              # 已知可用的依赖清单基准
```

- **demo-page-builder**：生成 demo、画页面、生成 HTML 等任务的入口。组件库严格限定 Ant Design / Ant Design Pro / Ant Design X，禁止其他组件库；每个改动必须热更新或重启服务并交给用户确认效果。
- **references/dev-server.md**：dev server 工作流细则——node runtime 探测（识别 bun 壳）、无 runtime 时项目级免安装部署（Linux/macOS/Windows）、公司环境拦截时停止并上报、`--legacy-peer-deps` 安装、页面生效验证。

## 安装方式一：让 agent 自动安装（推荐）

在支持 skills 的 agent 会话中，直接对 agent 说：

> 把 https://github.com/zhiquanchi/prd-demo-skills 仓库里的 skills 安装到当前项目

**不需要指定目录**——agent 会自动检测自己是什么工具，并把 skills 装到该工具对应的项目级 skill 目录：

| agent 工具 | 自动检测后安装到 |
|---|---|
| Kimi Code CLI | `.agents/skills/` |
| Claude Code | `.claude/skills/` |
| 其他兼容 Agent Skills 标准的工具 | 按该工具的 skill 扫描约定（一般是 `<配置目录>/skills/`） |

检测依据：agent 当前会话已加载的 skill 列表来自哪个目录、项目里已存在哪个配置目录（`.agents/` / `.claude/`）。检测不到时就地询问你，不会装错位置。安装后新开会话即可生效。

## 安装方式二：人工手动安装

```bash
# 1. 克隆本仓库（任意临时位置）
git clone https://github.com/zhiquanchi/prd-demo-skills.git /tmp/prd-demo-skills

# 2. 复制 skills 到你的项目根目录（Claude Code 用户改为 .claude/skills）
mkdir -p /path/to/your-project/.agents
cp -r /tmp/prd-demo-skills/.agents/skills /path/to/your-project/.agents/

# 3. 重开 agent 会话，skill 列表会重新扫描加载
```

只需要复制 `demo-page-builder` 一个目录即可，`references/` 支撑材料已内嵌其中。

## 使用前提

目标项目应为 Umi Max + React 18 + antd 5 技术栈；缺少 `package.json` 时可用 `references/package.json` 基准清单重建。详细的环境探测、安装受阻处理、热更新与验证规则见 `references/dev-server.md`。
