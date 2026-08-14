# 起服务与页面验证（demo-page-builder 的参考文档）

> 本文件是 `demo-page-builder` skill 的 additional material，不是独立 skill。涉及起服务、热更新/构建、验证页面生效时，由 demo-page-builder 的流程引导到这里执行。node runtime 探测/安装、依赖安装等环境准备见同目录 `environment.md`。

适用于**用户会话当前工作目录**下的 Umi Max 4 + antd 5 + React 18 工程。执行本文件前，先按 `environment.md` 确保 node runtime 和依赖就绪。所有命令都在当前工作目录下执行，绝不在 skill 自身所在目录里起服务。

## 启动前：检查 8000 端口占用

起服务前先查 8000 端口是否被占用、被谁占用：

```bash
# macOS / Linux / WSL
lsof -nP -iTCP:8000 -sTCP:LISTEN
```

```powershell
# Windows（PowerShell）：找到占用 8000 的 PID
netstat -ano | findstr :8000 | findstr LISTENING
# 查看该 PID 的命令行，判断是不是本任务的进程
Get-CimInstance Win32_Process -Filter "ProcessId=<PID>" | Select-Object ProcessId, CommandLine
```

- **被本任务的旧进程占用**（命令行含 `max dev` / `umi` / `serve-dist.js`，或进一步确认进程工作目录就是当前项目：macOS/Linux/WSL 用 `lsof -p <PID> | grep cwd`，Windows 看上一步输出的 `CommandLine` 里的项目路径）→ 直接停掉旧进程（macOS/Linux/WSL：`kill <PID>`；Windows：`taskkill /PID <PID> /F`），继续使用 8000 端口起服务，保证用户手里的访问地址不变。
- **被与本项目无关的进程占用** → **不要 kill**，按各模式规则换端口（模式 B 由 dev server 自动换；模式 A 用 `PORT=<其他端口>` 启动），并把新地址发给用户。
- **未被占用** → 直接用 8000。

## 第一步：判断环境，选择服务模式

运行本 skill 的环境探测脚本，看输出里的 `environment=`（初始化阶段一般已跑过；POSIX 用 `scripts/posix/check-environment.sh`，Windows 在 PowerShell / cmd 里分别用 `scripts/windows/check-environment.ps1` / `scripts/windows/check-environment.bat`）：`wsl` → 模式 A，`native` → 模式 B。等价于手动执行：

```bash
grep -qi microsoft /proc/version || [ -n "$WSL_DISTRO_NAME" ]
```

- **命中（WSL）→ 模式 A：生产构建 + 静态服务**（见下节）。原因：WSL 的 localhost 转发层会断开浏览器到 dev server 的 HMR WebSocket（服务器端日志确认这期间没有任何重启或编译），webpack 客户端断线重连后强制整页刷新，用户在页面上的状态（输入内容、选中项、弹窗等）被清空。这是 WSL + dev server 的固有问题，不是代码问题，配置层面无法根除。
- **未命中（macOS、Windows 原生、普通 Linux）→ 模式 B：dev server 热更新**（见后文）。

## 模式 A（WSL）：生产构建 + 静态服务

纯 HTTP、无 WebSocket，页面长时间放着也不会自己刷新。

### Mock API 等价路由（强制，防白屏）

**Umi Mock 只在 dev 模式生效，`max build` 产物里没有 mock 逻辑**。静态服务如果不提供 `/api/*` 路由，SPA fallback 会把 `/api/xxx` 接住并返回 `index.html`，页面把 HTML 当 JSON 用、随后访问 `data.rows` 等字段抛运行时异常——**表现为刷新瞬间可见骨架、接口请求完成后整页白屏**。因此：

- **凡是页面 `request('/api/xxx')` 用到的 mock 接口，静态服务必须提供等价 API 路由**；没有等价路由的接口不允许上线静态验证
- 数据唯一来源是 `mock/<domain>.json`：`scripts/serve-dist.js` 自动把 `mock/<name>.json` 注册为 `GET /api/<name>`（Content-Type 为 `application/json`）；`mock/<domain>.ts` 导入同一份 JSON 导出 Umi Mock 接口，dev 与静态模式返回一致的数据。**禁止在页面组件或静态服务脚本里重复硬编码同一份示例数据**。细则与数据契约见 `references/mock.md`
- 未注册的 `/api/*` 一律返回 404 JSON，**绝不落入 SPA fallback 返回 HTML**——这是静态服务的底线行为
- 页面侧取数必须带格式校验与 `.catch()` 兜底（见 `references/mock.md` 的"页面侧取数"），接口异常时保留安全初始状态并显示错误提示，不得白屏

### 启动静态服务

项目内的 `scripts/serve-dist.js`（express 静态服务 + mock JSON API 路由 + SPA 路由 fallback）在初始化时已由 `scripts/posix/init-project.sh` 从 `assets/project-template/scripts/serve-dist.js` 复制到位（express 在依赖白名单内，无需新装包）；老项目缺失或版本过旧（没有 mock API 路由）时，把该模板文件重新复制到项目 `scripts/` 下覆盖，不要手抄，也不要改成 express 5 的通配写法（白名单锁的是 `express@^4.21.2`，express 4 语法）。

```bash
node scripts/serve-dist.js   # 长驻进程，优先用后台任务启动；若无后台任务功能，用 subagent 后台运行
```

- 启动日志会列出每个已注册的 Mock API（`Mock API: /api/keywords -> mock/keywords.json`）与总数，**逐条核对页面依赖的接口都在列表里**
- 服务**读取**三样东西：`dist/` 产物、启动时扫描注册的 `mock/*.json` 路由表、每次请求现读的 `mock/*.json` 文件内容。因此：**重新 `npm run build` 后新产物自动生效、修改既有 `mock/*.json` 数据自动生效，都不用重启；但新增了 `mock/*.json` 文件（新 API 路由）必须重启服务**，路由表是启动时注册的

### 重启前必须检测端口占用（强制）

需要重启服务（新增了 mock JSON 文件、更换了 serve-dist.js 等）时，**先按本文开头的方法检测 8000 端口**：

- 若被**当前项目旧的 `serve-dist.js` 进程**占用：`kill <PID>`（Windows：`taskkill /PID <PID> /F`）停掉后重启；
- **不得复用旧进程后直接宣布新构建/新路由生效**——旧进程可能还持有旧的路由表或在服务旧目录；
- 重启后**必须重新验证**：请求涉及的 `/api/<domain>`，确认返回的是**新数据的合法 JSON**（Content-Type 为 `application/json`、JSON 可解析、字段符合预期），而不是 SPA fallback 的 `index.html`——用下方 verify-page 脚本的 `--api` 参数断言；
- 若被与本项目无关的进程占用：不要 kill，按前述规则换端口并把新地址发给用户。

### 核心规则：每次代码改动后必须重新构建

1. 改完代码执行 `npm run build`（max build），等构建完成。
2. 把地址发给用户，请用户强刷（Ctrl+Shift+R）确认效果。
3. 服务不用重启，没有热更新，也不需要 tail 日志等 Compiled。构建较慢时按 SKILL.md 的进度上报规则间断报进度。
4. 构建后页面没变化：先确认构建确实完成、用户已强刷，再做其他排查，不做无效排查。

### 验证页面真的生效（模式 A）

在项目根目录运行本 skill 的 `scripts/posix/verify-page.sh`（位于 skill 根目录的 `scripts/posix/`，不是项目的 `scripts/`）一键验证。**页面用到 mock 接口时必须传 `--api`（可重复，每个页面依赖的接口一个）**，脚本会先验证每个 API（HTTP 200、Content-Type 为 JSON、响应可解析且具备 `:字段` 列出的页面必需字段），再验证页面 HTML 与懒加载 chunk：

```bash
<skill目录>/scripts/posix/verify-page.sh --mode dist --route /<路由> --marker "<页面里的特征字符串>" \
  --api "/api/keywords:rows,total" --api "/api/users:rows"
```

`--api` 格式为 `/api/<name>[:field[,field...]]`，字段列表对应页面的数据契约（如 `rows`、`total`）；不写字段则只校验"HTTP 200 + JSON Content-Type + 可解析"。退出码非 0 即对应项失败（9=API 非 200、10=Content-Type 不是 JSON、11=JSON 非法或缺字段），其中 10/11 通常意味着 `/api/*` 落进了 SPA fallback 返回了 `index.html`——回看上一节的等价路由规则排查（`mock/<name>.json` 是否存在、serve-dist 是否需要重启）。端口不是 8000 时加 `--port`，不在项目根目录时加 `--project`。

通过时输出四类结果，缺一不可：

```text
API HTTP status: 200 (GET /api/keywords)
API JSON validation: PASS (/api/keywords parses as JSON, fields: rows, total)
Page HTTP status: 200 (GET /keywords)
Page chunk marker: PASS (found in dist JavaScript)
```

Windows（无 bash）用对应的 PowerShell / cmd 版脚本（输出与退出码一致）：

```powershell
# PowerShell（端口不是 8000 加 -Port，不在项目根目录加 -Project，-Api 可重复）
scripts/windows/verify-page.ps1 -Mode dist -Route /<路由> -Marker "<特征字符串>" -Api "/api/keywords:rows,total"
```

```bat
rem cmd（端口不是 8000 加 --port，不在项目根目录加 --project，--api 可重复）
scripts\windows\verify-page.bat --mode dist --route /<路由> --marker "<特征字符串>" --api "/api/keywords:rows,total"
```

注意 cmd 的 findstr 对超长单行（约 8KB+，压缩产物常见）可能漏匹配，结果可疑时改用 PowerShell 版。

- 从 dev 模式切换到静态模式后，用户浏览器必须强刷一次（Ctrl+Shift+R）清掉旧的 dev bundle，否则可能还连着已失效的旧服务。

### 必测回归场景：静态模式白屏（强制）

任何页面在模式 A 下交付前，**必须完整走一遍以下回归清单**，全部通过才算生效：

1. `max build` 生产构建成功；
2. 静态服务启动，启动日志的 Mock API 列表覆盖页面全部依赖接口；
3. 页面首次加载（GET 路由）返回 200，不白屏——刷新后骨架可见、接口返回后内容正常渲染；
4. 每个页面依赖的 mock API 返回**合法 JSON**（Content-Type 为 `application/json`、可解析、具备必需字段），**绝不返回 `index.html`**（verify-page `--api` 断言）；
5. **接口异常兜底**：模拟接口失败（如临时改名 `mock/<name>.json` 使路由 404、或确认返回非 JSON 时），页面不白屏——保留安全初始状态并显示可理解的错误提示，其余区块可用；
6. 验证结果明确输出：页面 HTTP 状态、API HTTP 状态、JSON 校验结果、页面 chunk 标记。

**验收标准**：`max build` 后通过静态服务访问页面不白屏；`/api/<domain>` 返回合法 JSON 而非 `index.html`；网络请求失败或响应格式错误时页面不白屏；verify-page 输出四类结果且全部 PASS。

## 模式 B（非 WSL）：dev server 热更新

**优先使用后台任务启动 umi**：`npm run dev`（即 umi 的 `max dev`）是长驻进程，必须通过本 agent/IDE 的「后台任务」机制启动（等同后台运行并规避命令超时），**不要用阻塞式前台命令启动**。若当前环境无后台任务功能，则使用 **subagent** 后台运行。任务启动后保留其任务句柄，供后续 tail 日志（确认 `App listening at` 与 Webpack `Compiled`）和重启时停止使用：

```bash
npm run dev   # 优先用后台任务启动；若无后台任务功能，用 subagent 后台运行
```

- 端口不固定：Umi Max 默认尝试 8000，被占用会自动换端口；**实际地址（Local / Network）一律以 dev server 启动日志的实际输出为准**，不要假设是 8000。
- 看到 `App listening at` 且 Webpack `Compiled` 即为就绪。

### 核心规则：每个页面/小功能完成后必须热更新或重启

1. 写完一个页面或小功能后，先等热更新：tail dev server 日志，确认出现新的 `wait - [Webpack] Compiling...` → `event - [Webpack] Compiled`。
2. **新建了 `src/pages` 等目录或首批文件时，watcher 经常监听不到新目录**（本项目已踩过：touch 文件也不触发重编译）。此时必须重启 dev server：先停掉后台任务（TaskStop），再重新用后台任务或 subagent 启动 umi（`npm run dev`）。
3. 改已有文件一般能热更新；新增路由/新目录后如果页面没变化，不要排查代码，先重启。

### 验证页面真的生效（模式 B）

在项目根目录运行本 skill 的 `scripts/posix/verify-page.sh`（位于 skill 根目录的 `scripts/posix/`，不是项目的 `scripts/`）一键验证，**端口必须传启动日志里的实际值**：

```bash
<skill目录>/scripts/posix/verify-page.sh --mode dev --route /<路由> --marker "<页面里的特征字符串>" --port <实际端口>
```

它同时验证三件事：`src/.umi/core/route.tsx` 里已生成对应路由、路由访问返回 200、页面代码真的打进了**懒加载 chunk**（如 `src/pages/foo.tsx` 对应 `http://localhost:<实际端口>/src__pages__foo.async.js`，marker 能命中），而不是只在 `/umi.js` 里。退出码非 0 即对应项失败，按报错输出排查。dev 模式下同样支持 `--api`（Umi Mock 原生生效，主要用于确认路径与数据契约一致）。

Windows（无 bash）用对应的 PowerShell / cmd 版脚本（输出与退出码一致），**端口必须传启动日志里的实际值**：

```powershell
# PowerShell
scripts/windows/verify-page.ps1 -Mode dev -Route /<路由> -Marker "<页面里的特征字符串>" -Port <实际端口>
```

```bat
rem cmd
scripts\windows\verify-page.bat --mode dev --route /<路由> --marker "<页面里的特征字符串>" --port <实际端口>
```

- 用户浏览器端如果仍空白：强刷（Ctrl+Shift+R）清旧 bundle。

## 服务管理（环境操作，不算交付）

起服务、热更新/重启、重新构建都只是让改动生效的手段，**不单独作为交付物、不单独提交 git**；只有业务改动（页面、功能、样式）才走交付与提交流程。

- **服务保持可用**：按上方判断的环境与模式启动服务（没在跑就启动，已在跑就复用），保证地址（默认 http://localhost:8000/<路由>）始终可访问
- 页面没变化时按所选模式排查：
  - 模式 B（dev server）：新建目录/新路由后先重启 server（watcher 经常监听不到新目录）
  - 模式 A（WSL 静态服务）：先确认构建完成、用户已强刷；**骨架闪现后白屏的，先查 mock API 是否返回了 `index.html`**（SPA fallback 接住了 `/api/*`，按「Mock API 等价路由」节排查），不要先怀疑页面代码
  - 以上做过仍无变化，再回头排查代码，不做无效排查

## 已知现象（两种模式通用）

- 首页路径 `/` 返回 200 只说明服务活着，不说明页面有内容。
- 没有任何 `src/pages` 时，根路径是空白页（返回的 HTML 只有空的 `<div id="root">`），这是正常的。
