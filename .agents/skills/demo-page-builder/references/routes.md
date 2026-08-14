# 路由与页面导航（demo-page-builder 的参考文档）

> 本文件是 `demo-page-builder` skill 的 additional material，不是独立 skill。新增页面、配置路由、处理页面间跳转和左侧导航绑定时，由 demo-page-builder 的流程引导到这里执行。路由能力细节以 Umi 官方文档为准：https://umijs.org/docs/guides/routes

适用于**用户会话当前工作目录**下的 Umi Max 4 工程，项目使用**约定式路由**（零配置）：`src/pages/` 下的文件自动映射为路由。

## 约定式路由速查

- `src/pages/index.tsx` → `/`；`src/pages/users.tsx` → `/users`；`src/pages/foo/bar.tsx` → `/foo/bar`
- 目录式：`src/pages/foo/index.tsx` → `/foo`
- 不需要也不新增路由配置文件；改路由就是增删 `src/pages/` 下的文件
- 路由是否已生成，按 `references/dev-server.md` 的方法查 `src/.umi/core/route.tsx` 验证

## 规则一：首页（`/`）不允许空白

访问根路径 `/` 时**不允许出现空白页**——这是硬性要求：

- 项目只有一个/已有明确主页面时，`src/pages/index.tsx` 直接渲染 `<Navigate to="/<第一个有内容的页面路径>" replace />`，自动跳转到第一个有内容的页面
- `Navigate` 从 `@umijs/max`（或 `umi`）导入，不引入任何新依赖：

```tsx
import { Navigate } from '@umijs/max';

export default function IndexPage() {
  return <Navigate to="/users" replace />;
}
```

- 首页本身有内容（如仪表盘/落地页）时不需要跳转，直接渲染内容
- 新增第一个页面时：如果 `src/pages/index.tsx` 是空的/占位的，立即按上面改为跳转到新页面
- 后续新增页面后，重新确认首页跳转目标仍然是"第一个有内容的页面"（左侧导航的第一项），不要出现首页跳到已被删除/已无内容的页面

## 规则二：新增页面时分析导航绑定

每新增一个页面，**必须分析当前页面结构是否需要为它提供入口**：

1. **判断是否需要跳转入口**：页面是独立工具页/详情页（由其他页面内部跳转进入）可以不加导航；是主要功能页（用户需要直接访问）必须有入口
2. **左侧导航有对应按钮的，必须绑定**：左侧导航（Menu / ProLayout 的 menu）中已有对应该页面的按钮或菜单项时，必须把菜单项和新路由绑定——点击菜单项通过 `history.push('/<新路由>')` 或 `<Link to>` 跳转，不允许出现"菜单上有按钮但点了没反应"
3. **需要入口但导航里没有对应按钮的，补一个**：在左侧导航中新增菜单项（文案与页面功能一致，图标从 `@ant-design/icons` 选语义最接近的），并绑定跳转到新路由
4. **选中态同步**：菜单的 `selectedKeys` 跟随当前路由（用 `useLocation()` 取 pathname），保证刷新/直接输入 URL 时左侧高亮正确

导航跳转只用 Umi 内置能力，不加依赖：

- 声明式：`<Link to="/users">`（`@umijs/max` 导出）
- 编程式：`import { history } from '@umijs/max'`，`history.push('/users')`
- 当前路径：`useLocation().pathname`
## 规则三：主功能页面必须有侧栏入口（强制）

新增页面前，先判断它是否属于**用户可直接访问的主功能页面**。若是，**必须同时完成导航入口工作，不得只新增路由文件**：

1. **补菜单项**：在现有侧栏/顶部导航中新增或复用对应菜单项，菜单文案必须与页面名称一致（图标从 `@ant-design/icons` 选语义最接近的）
2. **菜单必须可跳转**：菜单项必须使用 `Link` 或 `history.push` 跳转到新路由，**禁止仅展示静态文字**；不允许出现"菜单看起来是入口但点击无反应"
3. **选中态同步**：使用 `useLocation().pathname` 或组件库的 `selectedKeys` 实现选中态同步——直接输入 URL、刷新页面、点击菜单时都必须高亮正确
4. **首页跳转需明确确认**：若首页是默认入口（`index.tsx` 跳转），新增主功能页后必须**明确确认首页应跳转到哪个主页面**，**不得擅自覆盖既有首页**；沿用既有首页跳转目标，仅在需要时才调整
5. **交付前逐项验证**（全部通过才能报告页面完成）：
   - 点击新菜单可进入目标路由；
   - 点击原有菜单可返回原页面；
   - 刷新目标路由后菜单高亮正确；
   - 不存在"菜单看起来是入口但点击无反应"的情况

验收未通过时，不得报告页面完成。此前的问题正是没有把「新增路由」和「新增导航入口」作为同一项强制验收，且错误地将首页默认入口改成了新页面——导航入口必须与路由作为同一交付闭环，首页跳转目标变更必须经用户明确确认。
## 验证

- 改完路由后按 `references/dev-server.md` 等热更新或重启，确认 `src/.umi/core/route.tsx` 里有新 path
- 访问 `/` 确认自动跳到第一个有内容的页面，不空白
- 点一遍左侧导航所有菜单项，确认每个都能跳到对应页面且选中态正确；有"点了没反应"的项必须修复

## ⚠️ 新增页面后内容区空白？

如果看到侧边栏/顶栏正常显示但**内容区全白**，99% 是因为布局文件用了 `{children}` 而不是 `<Outlet />`。详见 `references/layout-patterns.md`。修复：把 `src/layouts/index.tsx` 里的 `{children}` 换成 `<Outlet />`。
