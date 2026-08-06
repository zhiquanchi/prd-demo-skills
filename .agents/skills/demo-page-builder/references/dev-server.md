# 开发服务器工作流（demo-page-builder 的参考文档）

> 本文件是 `demo-page-builder` skill 的 additional material，不是独立 skill。涉及装依赖、起服务、热更新、验证时，由 demo-page-builder 的流程引导到这里执行。

适用于 `/root/prd-demo-react`（Umi Max 4 + antd 5 + React 18）。

## 环境：先探测 node runtime，没有再装一个项目级隔离的

**不要假设 `node`/`npm` 存在或可用。** 按以下顺序探测，命中即用：

**先判断操作系统和 shell**：`uname -s`（Linux/macOS）或 `$env:OS`/`echo %OS%`（Windows）。下面命令分 POSIX shell（bash/zsh）和 Windows PowerShell 两种写法。

1. **验证现有 node 是否是真的 Node.js**（`node` 可能是 bun 的 wrapper，例如本机 `/usr/local/bin/node`；这条各平台通用）：

   ```bash
   node -p "process.versions.bun ? 'bun '+process.versions.bun : 'real node '+process.version"
   ```

   输出 `real node ...` 才是真 Node.js。**不要用 `process.release.name` 判断**——bun 出于兼容会谎报为 `node`（本项目实测踩过）。

2. **node 是 bun 壳或不存在时，找 npm 反推真实 node**（fnm/nvm/volta 等版本管理器的 npm 与 node 同目录）：

   ```bash
   # POSIX
   export PATH="$(dirname $(which npm)):$PATH"
   ```
   ```powershell
   # Windows PowerShell
   $env:Path = "$(Split-Path (Get-Command npm).Source);$env:Path"
   ```

   也可直接翻常见位置：
   - POSIX：`ls ~/.local/share/fnm/node-versions/*/installation/bin/node`、`ls ~/.nvm/versions/node/*/bin/node`
   - Windows：`dir "$env:LOCALAPPDATA\fnm\node-versions\*\installation\node.exe"`、`dir "$env:APPDATA\nvm\*\node.exe"`（nvm-windows）、`dir "$env:ProgramFiles\nodejs\node.exe"`

3. **完全没有 node runtime 时，装一个项目级隔离的**（不污染系统、不需要管理员权限、不依赖版本管理器）。Node 官方提供免安装压缩包，解压即用：

   ```bash
   # POSIX（Linux/macOS）
   mkdir -p .runtime
   curl -fsSL https://nodejs.org/dist/v24.18.0/node-v24.18.0-linux-x64.tar.xz | tar -xJ -C .runtime
   export PATH="$PWD/.runtime/node-v24.18.0-linux-x64/bin:$PATH"
   node -v   # v24.18.0
   ```
   ```powershell
   # Windows PowerShell（官方分发的是 .zip，注意不是 tar）
   New-Item -ItemType Directory -Force .runtime
   Invoke-WebRequest https://nodejs.org/dist/v24.18.0/node-v24.18.0-win-x64.zip -OutFile .runtime\node.zip
   Expand-Archive .runtime\node.zip -DestinationPath .runtime
   $env:Path = "$PWD\.runtime\node-v24.18.0-win-x64;$env:Path"   # Windows 上 node/npm 直接在根目录，没有 bin 子目录
   node -v
   ```

   - 文件名按平台和架构选择：Linux `linux-x64`/`linux-arm64`（`.tar.xz`），macOS `darwin-x64`/`darwin-arm64`（`.tar.gz`），Windows `win-x64`/`win-arm64`（`.zip`）。架构用 `uname -m`（POSIX）或 `$env:PROCESSOR_ARCHITECTURE`（Windows）判断
   - 版本号按 `package.json` 的 `engines` 调整；最新 LTS 版本号可查 https://nodejs.org/dist/index.json
   - `.runtime/` 在项目内，记得加进 `.gitignore`
   - 系统级安装（apt、winget、`brew`、安装程序等）会改系统环境，**先征得用户同意**再用

4. bun 可以跑多数脚本但和本项目工具链（Umi/webpack 生态）兼容性未验证，只作为最后手段，并告知用户风险。

后续所有 `node`/`npm`/`npx` 命令都在注入了上述 PATH 的同一个 shell 里执行（本 agent 每次 Bash 调用都是新 shell，PATH 前缀要每次带上）。

## 受阻处理：公司环境禁止安装时，停止并通知用户

公司网络/终端管控可能拦截下载和安装。识别信号：

- 下载被拒：HTTP 403/407（代理要求认证）、连接超时、TLS 拦截报错、域名被策略阻断
- 安装被拒：无管理员权限、EDR/杀软拦截可执行文件落地、写系统目录被拒
- npm 拉包失败：registry 被墙或强制走内网代理

**遇到上述情况，不要反复重试、不要绕过安全策略（换协议/关校验/找镜像绕过都是违规的），按下面做：**

1. **立即停止安装动作**，保留现场（错误日志、被拦截的 URL/命令）。
2. **通知用户**，说清楚：要装什么（node runtime / npm 依赖）、被什么拦了（贴关键报错）、卡在哪一步。
3. **请用户决策**，给出可选路径：
   - 用户去走公司权限/白名单申请流程（开放 nodejs.org、npm registry 或内网镜像权限）
   - 用户提供公司内网镜像地址（如内部 npm registry、node 分发镜像），由用户确认后再配置使用
   - 用户手动装好 node/runtime 后告知安装路径，agent 直接用现成环境继续
4. 拿到用户明确指示前，不尝试任何替代下载渠道。

## 安装依赖

与本文件同级的 `package.json`（`references/package.json`）是本项目**已知可用的依赖清单基准**：项目 `package.json` 丢失、被改坏、或需要在新目录快速重建环境时，直接复制它再安装。

```bash
npm install --legacy-peer-deps --no-audit --no-fund
```

- 必须加 `--legacy-peer-deps`：`@ant-design/x` 整个 v2 系列 peer 要求 antd ^6，但本项目钉在 antd ^5.25.0，严格模式必报 ERESOLVE。根治方案（二选一，需用户确认）：antd 升 6，或 `@ant-design/x` 降 1.x。
- 若报 `ETXTBSY`（esbuild postinstall，WSL 常见）：直接重跑一次 `npm install` 即可，已下载的包会复用。
- npm 11 会拦截 postinstall 脚本（allow-scripts 警告）。只要 `node_modules/@esbuild/linux-x64/bin/esbuild --version` 能输出版本号，就不影响运行，无需处理。

## 启动 dev server

```bash
npm run dev   # max dev，后台运行，disable_timeout
```

- 默认地址：Local `http://localhost:8000`，Network `http://172.25.136.185:8000`。
- 看到 `App listening at` 且 Webpack `Compiled` 即为就绪。

## 核心规则：每个页面/小功能完成后必须热更新或重启

1. 写完一个页面或小功能后，先等热更新：tail dev server 日志，确认出现新的 `wait - [Webpack] Compiling...` → `event - [Webpack] Compiled`。
2. **新建了 `src/pages` 等目录或首批文件时，watcher 经常监听不到新目录**（本项目已踩过：touch 文件也不触发重编译）。此时必须重启 dev server：
   - 停掉后台任务（TaskStop），重新 `npm run dev`。
3. 改已有文件一般能热更新；新增路由/新目录后如果页面没变化，不要排查代码，先重启。

## 验证页面真的生效（不要只靠肉眼）

- 路由是否生成：`cat src/.umi/core/route.tsx`，确认有对应 path 和 `routeComponents`。
- 页面代码在**懒加载 chunk** 里，不在 `/umi.js`：页面 `src/pages/foo.tsx` 对应 `http://localhost:8000/src__pages__foo.async.js`，用 `curl -s ... | grep "页面里的特征字符串"` 验证。
- 首页路径 `/` 返回 200 只说明服务活着，不说明页面有内容。
- 用户浏览器端如果仍空白：强刷（Ctrl+Shift+R）清旧 bundle。

## 已知现象

- 没有任何 `src/pages` 时，根路径是空白页（返回的 HTML 只有空的 `<div id="root">`），这是正常的。
