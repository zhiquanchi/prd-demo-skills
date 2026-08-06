# prd-demo-skills

React demo 页面构建的 agent skills，适用于 Umi Max + Ant Design 技术栈。

## 包含的 skill

```
.agents/skills/
└── demo-page-builder/            # 父 skill：组件库白名单（antd / Ant Design Pro / Ant Design X）、先搜后用、交付确认
    └── skills/
        └── dev-server/           # 子 skill：node 环境探测与安装、依赖安装、dev server 启停、热更新与验证
            └── package.json      # 已知可用的依赖清单基准
```

- **demo-page-builder**：生成 demo、画页面、生成 HTML 等任务的入口。组件库严格限定 Ant Design / Ant Design Pro / Ant Design X，禁止其他组件库；每个改动必须热更新或重启服务并交给用户确认效果。
- **dev-server**：node runtime 探测（识别 bun 壳）、无 runtime 时项目级免安装部署（Linux/macOS/Windows）、公司环境拦截时停止并上报、`--legacy-peer-deps` 安装、dev server 启动与页面生效验证。

## 安装方式一：让 agent 自动安装（推荐）

在支持 skills 的 agent（如 Kimi Code CLI）会话中，直接对 agent 说：

> 把 https://github.com/zhiquanchi/prd-demo-skills 仓库里的 skills 安装到当前项目的 .agents/skills/ 目录下

agent 会自动 clone/下载该仓库，并把 `.agents/skills/` 复制到你的项目根目录。安装后新开会话即可生效。

## 安装方式二：人工手动安装

```bash
# 1. 克隆本仓库（任意临时位置）
git clone https://github.com/zhiquanchi/prd-demo-skills.git /tmp/prd-demo-skills

# 2. 复制 skills 到你的项目根目录
cp -r /tmp/prd-demo-skills/.agents/skills /path/to/your-project/.agents/

# 3. 重开 agent 会话，skill 列表会重新扫描加载
```

只需单个 skill 时，也可以只复制对应子目录，例如只要页面构建能力：

```bash
mkdir -p /path/to/your-project/.agents/skills
cp -r /tmp/prd-demo-skills/.agents/skills/demo-page-builder /path/to/your-project/.agents/skills/
```

注意 `demo-page-builder` 依赖子 skill `dev-server`（已内嵌在其 `skills/` 目录中），复制整个 `demo-page-builder` 目录即可完整带走。

## 使用前提

目标项目应为 Umi Max + React 18 + antd 5 技术栈；缺少 `package.json` 时可用 `dev-server` skill 内附的基准清单重建。详细的环境探测、安装受阻处理、热更新与验证规则见各 SKILL.md。
