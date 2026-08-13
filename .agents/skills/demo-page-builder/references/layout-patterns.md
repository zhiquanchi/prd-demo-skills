# Umi Max 全局布局模式

> 本文件是 `demo-page-builder` skill 的 additional material，不是独立 skill。新建或修改 `src/layouts/index.tsx`（或任何 layouts 目录下的布局组件）时必读。

## 核心问题：`{children}` vs `<Outlet/>`

**Umi Max（基于 react-router v6+）使用嵌套路由，子页面通过 `<Outlet/>` 渲染，不是作为 `children` 属性传入。**

### ❌ 错误写法：用 `{children}`

```tsx
// src/layouts/index.tsx — 这是错的！
export default function Layout({ children }) {
  return (
    <ProLayout>
      <Header>...</Header>
      <Sider>...</Sider>
      <Content>{children}</Content>  {/* children 始终为空 → 空白页 */}
    </ProLayout>
  );
}
```

结果：侧边栏和顶栏能显示，但内容区永远空白——看起来就是"空白页"。

### ✅ 正确写法：用 `<Outlet />`

```tsx
// src/layouts/index.tsx — 正确
import { Outlet } from '@umijs/max';
import { ProLayout } from '@ant-design/pro-components';

export default function Layout() {
  return (
    <ProLayout>
      <Header>...</Header>
      <Sider>...</Sider>
      <Content>
        <Outlet />  {/* 子页面通过这个挂载 */}
      </Content>
    </ProLayout>
  );
}
```

### 为什么 `{children}` 是空的？

- Umi Max 的全局布局 (`src/layouts/index.tsx`) 是一个**路由容器**，不是普通组件
- react-router v6 中，嵌套路由的子路由通过 `<Outlet />` 渲染
- 布局组件不会从父级收到 `children` prop——它始终是 `undefined`

## 布局文件的层级规则

| 文件路径 | 作用 | 如何渲染子页面 |
|---|---|---|
| `src/layouts/index.tsx` | 全局布局（所有路由共用） | `<Outlet />` |
| `src/layouts/basic.tsx` | 自定义布局（需手动关联路由） | `<Outlet />` |
| `src/pages/xxx.tsx` | 业务页面（在布局内部渲染） | 不需要 outlet，直接返回内容 |

## 布局与路由的绑定

自定义布局（非 `index.tsx`）需要手动关联到路由：

```ts
// src/app.tsx —— 指定使用哪个自定义布局
export const layout = {
  // 使用 layouts/basic.tsx 作为布局
};
```

全局布局 `src/layouts/index.tsx` 无需额外配置，Umi 自动识别。

## 验证清单

创建/修改布局后，逐一核对：

1. ✅ 使用了 `<Outlet />`（不是 `{children}`）
2. ✅ `<Outlet />` 放在布局外壳的内容区域内部
3. ✅ 访问一个有内容的子页面（如 `/users`），确认内容正常显示而非空白
4. ✅ 刷新页面仍能正常显示（排除只靠热更新掩盖的问题）

## 常见症状与对策

| 症状 | 原因 | 修复 |
|---|---|---|
| 看到侧边栏/顶栏但内容为空 | 用了 `{children}` 而不是 `<Outlet />` | 改为 `<Outlet />` |
| 布局完全不生效 | 文件名不对或位置不对 | 确保文件在 `src/layouts/index.tsx` |
| 部分页面有布局，部分没有 | 使用了自定义布局但未绑定 | 检查 `src/app.tsx` 的 layout 配置 |
| 布局在热更新后消失 | `.umi` 缓存问题 | 删除 `.umi` 目录后重启 dev server |
