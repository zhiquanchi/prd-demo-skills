# Umi 目录结构（新项目按需创建）

官方文档：https://umijs.org/docs/guides/directory-structure

初始化新项目与后续新增功能时的目录组织，**以 Umi 官方约定目录结构为准**。核心原则：**按需创建，不需要的目录不要新建**——空目录不预建、不提交 git，用到该类文件时才连文件一起创建目录。

## 官方约定结构（完整版，仅作对照）

```text
.
├── config
│   └── config.ts
├── dist                          # 构建产物（不手动创建）
├── mock
│   ├── app.ts｜tsx
│   └── keywords.json             # 数据本体（唯一数据源），静态服务按 /api/keywords 提供等价路由
├── public
├── src
│   ├── .umi                      # dev 临时文件（不手动创建、不提交）
│   ├── .umi-production           # build 临时文件（不手动创建、不提交）
│   ├── layouts
│   │   ├── BasicLayout.tsx
│   │   └── index.less
│   ├── models
│   │   ├── global.ts
│   │   └── index.ts
│   ├── pages
│   │   ├── index.less
│   │   └── index.tsx
│   ├── utils                     # 推荐目录
│   │   └── index.ts
│   ├── services                  # 推荐目录
│   │   └── api.ts
│   ├── app.(ts|tsx)              # 运行时配置
│   ├── global.ts
│   ├── global.(css|less|sass|scss)
│   ├── overrides.(css|less|sass|scss)
│   └── favicon.(ico|gif|png|jpg|jpeg|svg|avif|webp)
├── plugin.ts                     # 项目级 Umi 插件
├── .umirc.ts                     # 与 config/config.ts 二选一
├── .env
└── package.json
```

## 按需创建规则（本 skill 强制）

| 目录/文件 | 何时创建 | 说明 |
|---|---|---|
| `package.json` | 初始化时 | 由 `assets/project-template/` 复制，`name` 改成当前目录名 |
| `scripts/serve-dist.js` | 初始化时 | WSL 静态服务用，由模板复制 |
| `.gitignore` | 初始化时 | **白名单模式**：默认忽略一切，只保留必要文件/目录（内容见下节），由初始化脚本生成 |
| `src/pages/` | 写第一个页面时 | 约定式路由入口，页面文件（如 `src/pages/index.tsx`）随页面一起建；`pages/404.tsx` 需要兜底页时才建 |
| `mock/` | 页面需要示例数据时 | 一个业务域一对文件：`<domain>.json`（数据本体，唯一数据源）+ `<domain>.ts`（导出 Umi Mock 接口），细则见 `mock.md`；本项目 demo 几乎必建 |
| `src/layouts/` | 需要全局布局（侧边栏等）时 | 写 `index.tsx`，Umi Max 必须用 `<Outlet/>`，见 `layout-patterns.md` 与 `common-components.md` |
| `src/utils/` | 出现首个工具函数时 | 推荐目录，无工具代码不建 |
| `src/services/` | 出现首个接口封装时 | 推荐目录，简单 demo 用 `request` 直连 mock 时可不建 |
| `src/models/` | 需要全局数据流时 | Umi Max 数据流约定目录，无跨页面共享状态不建 |
| `public/` | 需要固定静态资源时 | 放 `public/image.png` 即可通过 `/image.png` 访问；无静态资源不建 |
| `src/global.(ts|tsx)` | 有全局前置逻辑时 | 无显式入口文件，全局脚本写这里 |
| `src/global.(css|less)` | 有全局样式时 | 优先级在第三方库样式之后 |
| `src/overrides.(css|less)` | 需覆盖第三方库样式时 | 选择器自动加 `body` 前缀抬高优先级；antd 样式优先用主题 token，见 `layout-patterns.md` |
| `src/loading.(tsx|jsx)` | 需要全局加载动画时 | 按页分包默认开启，切换页面有加载过程 |
| `src/app.(ts|tsx)` | 需要运行时配置时 | 修改路由、render 方法等 |
| `.umirc.ts` 或 `config/config.ts` | 需要非运行时配置时 | 二选一（`.umirc.ts` 优先级高）；本项目约定式路由零配置即可跑，**默认都不建**，需要时优先 `.umirc.ts`（保持根目录整洁可不建 `config/`） |
| `.env` | 需要环境变量时 | 如 `PORT=8888` |
| `plugin.ts` | 需要 Umi 插件 API 定制时 | 罕用 |
| `src/favicon.*` | 需要站点图标时 | 也可用 `favicons` 配置项 |
| `dist/`、`src/.umi/`、`src/.umi-production/` | **永不手动创建** | 构建/dev 临时产物，已被 `.gitignore` 忽略 |

## `.gitignore`（白名单模式，初始化脚本自动生成）

**除必要文件外其他一律忽略**：用 `/*` 忽略根下所有条目，再用 `!` 逐个放行必要文件/目录。固定内容如下：

```gitignore
# Whitelist mode: ignore everything by default, keep only necessary files.

/*

# root-level files
!/.gitignore
!/package.json
!/package-lock.json
!/README.md
!/.umirc.ts
!/plugin.ts

# necessary dirs (created on demand, no empty dirs committed)
!/config/
!/docs/
!/mock/
!/public/
!/scripts/
!/src/

# build/temp artifacts inside allowed dirs stay ignored
node_modules/
dist/
.runtime/
src/.umi/
src/.umi-production/
```

要点：

- **不在白名单里的新目录/文件默认被忽略**（如 `coverage/`、临时脚本、编辑器目录），符合"除了必要的文件其他都要忽略"
- `.env` **有意不在白名单**（防止误提交敏感信息）：需要共享的配置写进 `.umirc.ts` 或 README；确需入库时先经用户确认再加 `!/.env`
- 放行目录内的构建/临时产物（`node_modules/`、`dist/`、`.runtime/`、`src/.umi*/`）仍被忽略
- 初始化脚本只在 `.gitignore` 不存在时写入；已存在的自定义 `.gitignore` 不覆盖
- 页面文件在 `!/src/` 白名单内，**必须能被 git 提交**

## 落地检查

- 初始化完成后项目里**没有空目录**；每个目录都因里面有文件而存在
- 新增功能时同步对照上表：文件放对目录，目录随文件建
- 新增的根级目录/文件**默认被 `.gitignore` 白名单忽略**（如 `coverage/`、`.vscode/`），确需入库时先改白名单并说明理由
- 提交 git 前确认没有把 `dist/`、`src/.umi*/` 加进来
