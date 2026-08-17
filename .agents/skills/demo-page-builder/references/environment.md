# 环境准备（demo-page-builder 的参考文档）

> 本文件是 `demo-page-builder` skill 的 additional material，不是独立 skill。涉及 node runtime 探测/安装、受阻处理、依赖安装时，由 demo-page-builder 的流程引导到这里执行。起服务、热更新、页面验证见同目录 `dev-server.md`。

适用于**用户会话当前工作目录**下的 Umi Max 4 + antd 5 + React 18 工程；当前目录还不是该工程时，先按 SKILL.md 的「项目定位」节在当前目录就地初始化，再执行本文档。**严禁**把 skill 自身所在目录当作项目根来安装依赖。

## 环境：先探测 node runtime，没有再装一个项目级隔离的

**不要假设 `node`/`npm` 存在或可用。** 可先运行本 skill 的环境探测脚本一键探测（两者输出格式与退出码一致）：POSIX 环境（Linux/macOS/WSL）用 `scripts/posix/check-environment.sh <项目目录>`；Windows 在 PowerShell 里用 `scripts/windows/check-environment.ps1 <项目目录>`（不提供 cmd `.bat` 版本，cmd 环境请改用 PowerShell）。输出 `environment`（wsl/native）、`node_status`（ok/missing/bun-wrapper/too-old）、`project_status`、`dependencies` 等；退出码非 0 时按 stderr 提示对应下面的手动步骤（10=node 缺失，11=node 是 bun 壳，12=node 版本过旧，13=npm 缺失）。探测脚本覆盖不到的环节（如安装 runtime、用 npm 反推 node 路径）按下面的手动步骤执行。

按以下顺序探测，命中即用：

**先判断操作系统和 shell**：`uname -s`（Linux/macOS）或 `$env:OS`/`echo %OS%`（Windows）。下面命令分 POSIX shell（bash/zsh）和 Windows PowerShell 两种写法。

1. **验证现有 node 是否是真的 Node.js 且版本达标**（`node` 可能是 bun 的 wrapper，例如本机 `/usr/local/bin/node`；这条各平台通用）：

   ```bash
   node -p "process.versions.bun ? 'bun '+process.versions.bun : 'real node '+process.version"
   ```

   输出 `real node ...` 才是真 Node.js。**不要用 `process.release.name` 判断**——bun 出于兼容会谎报为 `node`（本项目实测踩过）。

   是真 Node.js 还要再查主版本号，本项目工具链（Umi Max 4 / TypeScript 5 / 新版 npm）要求 **Node >= 18**：

   ```bash
   node -p "const [maj,min]=process.versions.node.split('.').map(Number); (maj>18||(maj===18&&min>=0)) ? 'ok' : 'too old '+process.version"
   ```

   输出 `too old`（如 Node 12/14/16）时视为不可用，按下面第 3 步装一个达标的，不要用旧版本硬跑——`engines` 声明和工具链实际要求都已不支持。

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

3. **完全没有 node runtime（或版本不达标）时，装一个项目级隔离的**（不污染系统、不需要管理员权限、不依赖版本管理器）。Node 官方提供免安装压缩包，解压即用。**不要照抄写死的文件名，先探测 OS 和架构再拼装**：

   ```bash
   # POSIX（Linux/macOS）：先探测平台和架构，拼出正确的分发文件名
   # VER 需使用当前最新 LTS 版本（查询：https://nodejs.org/dist/index.json 或 https://nodejs.org/en/download）
   # 下方写死的版本号可能已过期，执行前请先确认最新 LTS
   VER=v24.18.0
   case "$(uname -s)" in
     Linux)  OS=linux;  EXT=tar.xz ;;
     Darwin) OS=darwin; EXT=tar.gz ;;   # macOS 官方分发是 .tar.gz，不是 .tar.xz
     *) echo "unsupported: $(uname -s)"; exit 1 ;;
   esac
   case "$(uname -m)" in
     x86_64|amd64) ARCH=x64 ;;
     arm64|aarch64) ARCH=arm64 ;;
     *) echo "unsupported arch: $(uname -m)"; exit 1 ;;
   esac
   PKG="node-${VER}-${OS}-${ARCH}"
   mkdir -p .runtime
   curl -fsSL "https://nodejs.org/dist/${VER}/${PKG}.${EXT}" | tar -xJ -C .runtime 2>/dev/null \
     || curl -fsSL "https://nodejs.org/dist/${VER}/${PKG}.${EXT}" | tar -xz -C .runtime
   export PATH="$PWD/.runtime/${PKG}/bin:$PATH"
   node -v   # 应输出 v24.18.0
   ```
   ```powershell
   # Windows PowerShell（官方分发的是 .zip，注意不是 tar）
   # VER 需使用当前最新 LTS 版本（查询：https://nodejs.org/en/download）
   # 下方写死的版本号可能已过期，执行前请先确认最新 LTS
   $VER = "v24.18.0"
   $ARCH = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "x64" }
   New-Item -ItemType Directory -Force .runtime
   Invoke-WebRequest "https://nodejs.org/dist/$VER/node-$VER-win-$ARCH.zip" -OutFile .runtime\node.zip
   Expand-Archive .runtime\node.zip -DestinationPath .runtime
   $env:Path = "$PWD\.runtime\node-$VER-win-$ARCH;$env:Path"   # Windows 上 node/npm 直接在根目录，没有 bin 子目录
   node -v
   ```

   - 文件名按平台和架构选择：Linux `linux-x64`/`linux-arm64`（`.tar.xz`），macOS `darwin-x64`/`darwin-arm64`（`.tar.gz`），Windows `win-x64`/`win-arm64`（`.zip`）。架构用 `uname -m`（POSIX）或 `$env:PROCESSOR_ARCHITECTURE`（Windows）判断
   - 版本号必须满足 `engines`（Node >= 18，建议用当前 LTS）；最新 LTS 版本号可查 https://nodejs.org/dist/index.json
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

本 skill 根目录下的 `assets/project-template/package.json` 是本项目**已知可用的依赖清单基准**：项目 `package.json` 丢失、被改坏、或需要在新目录快速重建环境时，直接复制它再安装（就地初始化场景一般由 `scripts/posix/init-project.sh` 一步完成复制与改名）。配套的锁文件是 `assets/project-template/package-lock.json`，一并复制后用 `npm ci` 安装，版本完全锁定且更快：

```bash
npm ci --legacy-peer-deps --no-audit --no-fund
```

仅当 lock 文件缺失或与 `package.json` 不同步时，才退回：

```bash
npm install --legacy-peer-deps --no-audit --no-fund
```

- 必须加 `--legacy-peer-deps`（`npm ci` 同样要加）：`@ant-design/x` 整个 v2 系列 peer 要求 antd ^6，但本项目钉在 antd ^5.25.0，严格模式必报 ERESOLVE。根治方案（二选一，需用户确认）：antd 升 6，或 `@ant-design/x` 降 1.x。
- 清单里的 `tailwindcss`/`tailwind-merge`、`tinymce`、`@xyflow/react`、`socket.io-client` 等是历史残留或特定场景工具包，**不代表获准作为 UI 组件库使用**——UI 组件仍只走 SKILL.md 的白名单（antd / ProComponents / Ant Design X）；fabric/konva/mermaid/echarts 等绘制引擎仅在需求明确涉及图表/画布时可用。
- 若报 `ETXTBSY`（esbuild postinstall，WSL 常见）：直接重跑一次 `npm install` 即可，已下载的包会复用。
- npm 11 会拦截 postinstall 脚本（allow-scripts 警告）。只要 `node_modules/@esbuild/linux-x64/bin/esbuild --version` 能输出版本号，就不影响运行，无需处理。
