# 起服务与页面验证（demo-page-builder 的参考文档）

> 本文件是 `demo-page-builder` skill 的 additional material，不是独立 skill。涉及起 dev server、热更新、验证页面生效时，由 demo-page-builder 的流程引导到这里执行。node runtime 探测/安装、依赖安装等环境准备见同目录 `environment.md`。

适用于 `/root/prd-demo-react`（Umi Max 4 + antd 5 + React 18）。执行本文件前，先按 `environment.md` 确保 node runtime 和依赖就绪。

## 启动 dev server

```bash
npm run dev   # max dev，后台运行，disable_timeout
```

- 默认地址：Local `http://localhost:8000`；Network 地址以 dev server 启动日志的实际输出为准（不同机器 IP 不同）。
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
