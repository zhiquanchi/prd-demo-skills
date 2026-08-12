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

运行本 skill 的 `scripts/check-environment.sh`，看输出里的 `environment=`（初始化阶段一般已跑过）：`wsl` → 模式 A，`native` → 模式 B。等价于手动执行：

```bash
grep -qi microsoft /proc/version || [ -n "$WSL_DISTRO_NAME" ]
```

- **命中（WSL）→ 模式 A：生产构建 + 静态服务**（见下节）。原因：WSL 的 localhost 转发层会断开浏览器到 dev server 的 HMR WebSocket（服务器端日志确认这期间没有任何重启或编译），webpack 客户端断线重连后强制整页刷新，用户在页面上的状态（输入内容、选中项、弹窗等）被清空。这是 WSL + dev server 的固有问题，不是代码问题，配置层面无法根除。
- **未命中（macOS、Windows 原生、普通 Linux）→ 模式 B：dev server 热更新**（见后文）。

## 模式 A（WSL）：生产构建 + 静态服务

纯 HTTP、无 WebSocket，页面长时间放着也不会自己刷新。

### 启动静态服务

项目内的 `scripts/serve-dist.js`（express 静态服务 + SPA 路由 fallback）在初始化时已由 `scripts/init-project.sh` 从 `assets/project-template/scripts/serve-dist.js` 复制到位（express 在依赖白名单内，无需新装包）；老项目缺失时把该模板文件复制到项目 `scripts/` 下即可，不要手抄，也不要改成 express 5 的通配写法（白名单锁的是 `express@^4.21.2`，express 4 语法）。

```bash
node scripts/serve-dist.js   # 后台运行，disable_timeout
```

- 服务一旦启动就**不需要再重启**——它只读 `dist/` 目录，重新构建后新产物自动生效。

### 核心规则：每次代码改动后必须重新构建

1. 改完代码执行 `npm run build`（max build），等构建完成。
2. 把地址发给用户，请用户强刷（Ctrl+Shift+R）确认效果。
3. 服务不用重启，没有热更新，也不需要 tail 日志等 Compiled。构建较慢时按 SKILL.md 的进度上报规则间断报进度。
4. 构建后页面没变化：先确认构建确实完成、用户已强刷，再做其他排查，不做无效排查。

### 验证页面真的生效（模式 A）

在项目根目录运行本 skill 的 `scripts/verify-page.sh`（位于 skill 根目录的 `scripts/`，不是项目的 `scripts/`）一键验证：

```bash
<skill目录>/scripts/verify-page.sh --mode dist --route /<路由> --marker "<页面里的特征字符串>"
```

它同时验证两件事：路由可达（`http://localhost:8000/<路由>` 经 SPA fallback 返回 200）和构建产物（marker 出现在 `dist/` 的 JS 里，即页面真的打进了懒加载 chunk，如 `src/pages/foo.tsx` 对应 `dist/src__pages__foo.async.js` 之类）。退出码非 0 即对应项失败，按报错输出排查；端口不是 8000 时加 `--port`，不在项目根目录时加 `--project`。

- 从 dev 模式切换到静态模式后，用户浏览器必须强刷一次（Ctrl+Shift+R）清掉旧的 dev bundle，否则可能还连着已失效的旧服务。

## 模式 B（非 WSL）：dev server 热更新

```bash
npm run dev   # max dev，后台运行，disable_timeout
```

- 端口不固定：Umi Max 默认尝试 8000，被占用会自动换端口；**实际地址（Local / Network）一律以 dev server 启动日志的实际输出为准**，不要假设是 8000。
- 看到 `App listening at` 且 Webpack `Compiled` 即为就绪。

### 核心规则：每个页面/小功能完成后必须热更新或重启

1. 写完一个页面或小功能后，先等热更新：tail dev server 日志，确认出现新的 `wait - [Webpack] Compiling...` → `event - [Webpack] Compiled`。
2. **新建了 `src/pages` 等目录或首批文件时，watcher 经常监听不到新目录**（本项目已踩过：touch 文件也不触发重编译）。此时必须重启 dev server：停掉后台任务（TaskStop），重新 `npm run dev`。
3. 改已有文件一般能热更新；新增路由/新目录后如果页面没变化，不要排查代码，先重启。

### 验证页面真的生效（模式 B）

在项目根目录运行本 skill 的 `scripts/verify-page.sh`（位于 skill 根目录的 `scripts/`，不是项目的 `scripts/`）一键验证，**端口必须传启动日志里的实际值**：

```bash
<skill目录>/scripts/verify-page.sh --mode dev --route /<路由> --marker "<页面里的特征字符串>" --port <实际端口>
```

它同时验证三件事：`src/.umi/core/route.tsx` 里已生成对应路由、路由访问返回 200、页面代码真的打进了**懒加载 chunk**（如 `src/pages/foo.tsx` 对应 `http://localhost:<实际端口>/src__pages__foo.async.js`，marker 能命中），而不是只在 `/umi.js` 里。退出码非 0 即对应项失败，按报错输出排查。

- 用户浏览器端如果仍空白：强刷（Ctrl+Shift+R）清旧 bundle。

## 已知现象（两种模式通用）

- 首页路径 `/` 返回 200 只说明服务活着，不说明页面有内容。
- 没有任何 `src/pages` 时，根路径是空白页（返回的 HTML 只有空的 `<div id="root">`），这是正常的。
