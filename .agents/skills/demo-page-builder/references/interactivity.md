# 交互实现与「交互不生效」排查（demo-page-builder 的参考文档）

> 本文件是 `demo-page-builder` skill 的 additional material，不是独立 skill。凡涉及让元素可交互（点击、切换、选择、输入）、以及用户反馈「点了没反应 / 改动没生效 / 只有部分生效」时，实现规范与排查流程以本文件为准。规则依据 React 官方文档与 antd 官方 FAQ 的已知行为，不是猜测。

## 一、交互实现硬规则（写代码时就避开"不生效"）

1. **事件绑定写法**：`onClick={handleClick}`（传函数引用）或 `onClick={() => doSomething(id)}`（传参）。禁止 `onClick={handleClick()}`——渲染时立即执行、返回值被当 handler，表现为「点击无反应」或「页面一加载就触发」。
2. **语义化交互组件**：可交互元素一律用白名单内交互组件（`Button` / `Menu` / `Switch` / `Select` / `Checkbox` / `Tabs` 等）；禁止 `div`/`span` + `onClick` 拼交互（键盘不可达、无 focus/hover 态、易被样式与事件代理问题吞掉）。确需自定义可点击区域时补 `role="button"` + `tabIndex={0}` + `onKeyDown`（Enter/Space 触发）。
3. **受控组件 `value`/`onChange` 必须成对**：只设 `value` 不设 `onChange`，组件是只读的，「点了没反应」；`value` 运行时变成 `undefined`/`null` 会触发受控↔非受控来回切换、行为异常——可选值兜底写 `value={x ?? ''}`。
4. **禁止在 onChange 里异步回填受控值**：onChange 触发后先同步 setState，异步结果（`request` 返回）再二次更新。直接异步更新受控 value，组件不立刻刷新、呈现假死态（antd 官方 FAQ：异步更新导致受控组件交互行为异常）。本 skill 页面大量 mock 取数，此条高频踩坑。
5. **嵌套交互的事件冒泡**：外层可点击行/卡片内的按钮，内层 handler 按需 `e.stopPropagation()`；反之，外层组件滥用 stopPropagation 会把内层一批交互全部吞掉——「部分元素点了没反应」时优先怀疑外层包裹（可点击行、Dropdown、Popover、Modal）吞事件。
6. **列表渲染 `key` 必须稳定**：批量修改列表项交互时用稳定业务 id 作 `key`；index 作 key 且发生重排/筛选时，React 复用旧实例，新挂的 handler/props 看似没生效。
7. **循环/批量 setState 用函数式更新**：`setX(prev => ...)`，避免闭包读到旧值导致多次修改只有一次生效。
8. **改动落点自查（批量改动高频翻车点）**：同一页面存在多处同构区块（复制粘贴产物）时，改交互必须 grep 出**全部**同构落点逐一修改——只改一处，其余就是「没生效」；改动不得落在永不渲染的分支（early return、空数据/权限分支）里。**根治手段是第二节「元素与行为解耦」**：同一行为收敛为单一实现后，此类改动天然只剩一处落点。
9. **交互的初始状态来自 mock 时**：元素的 disabled/默认选中/默认值等由接口字段驱动时，改交互行为要同步检查 `mock/<domain>.json` 契约（模式 A 重新 build，新增 mock 文件须重启服务，见 `references/dev-server.md`）。

## 二、元素与行为解耦（同一交互行为多处复用时，收敛为单一实现）

「改一种交互要挨个改 N 个元素」是批量改动漏改的架构根源。解法：**元素与行为解耦——行为的实现只写一份，元素侧只留绑定声明**。改行为 = 改 1 处，所有绑定的元素（含后续新增的）同时生效。

### 收敛判定（先判断，再动手）

- **同一交互行为被 2 个及以上元素使用**（或同一行为在同构区块里重复出现）→ **必须**收敛为单一实现，禁止复制粘贴 handler 各改各的
- 只被 1 个元素使用且无复用预期 → 就地写，**不预抽象**（为「以后可能复用」提前抽公共是过度设计）
- 完全配置驱动渲染（schema → 通用渲染器）不在本 skill 范围：demo 页用它会让 DOM 树、交接文档与代码的对应关系断裂，除非用户明确要求「可配置页面」

### 收敛形态按规模选档

1. **页内复用**：页面目录下建 `behaviors.ts`（或自定义 hook `useXxxActions`）导出行为工厂；组件 `useMemo` 建一份实例，元素绑定 `behaviors.xxx(params)`
2. **跨页面复用**：提升到 `src/components/` 公共 hook/组件，遵循 `references/common-components.md` 的公共组件规则
3. **大量元素统一绑定同类行为**（启用/停用、复制、导出、刷新……）：注册表 `Record<行为id, 工厂函数>` + `useBehaviors()` 取用，绑定处只写行为 id 与参数

页内形态示例（全部白名单内、零新依赖）：

```tsx
// src/pages/<页面>/behaviors.ts —— 行为唯一实现，元素差异走参数
import type { App } from 'antd';

export const createBehaviors = ({ message }: { message: App.useApp()['message'] }) => ({
  toggleStatus: (id: string, next: boolean) => async () => {
    /* 同一份逻辑：调接口/改 state/出提示 */
  },
  copyText: (text: string) => () => navigator.clipboard?.writeText(text),
});
```

```tsx
// 页面组件：元素侧只有绑定声明，没有业务逻辑
const behaviors = useMemo(() => createBehaviors({ message }), [message]);
// Table 列 render、工具栏按钮、行内操作统一绑定：
<Button onClick={behaviors.toggleStatus(row.id, !row.enabled)} />
```

改 `toggleStatus`（加确认弹窗、改提示文案）只改 `behaviors.ts` 一处，全部绑定元素同时生效。

### 硬规则

- **元素侧禁止内联业务逻辑**：JSX 里只写 `behaviors.xxx(params)` 这类绑定声明；差异一律通过参数传入，**禁止在行为实现里按元素身份分支**（`if (id === 'a') … else …`）——那是把耦合从元素搬进行为内部，换汤不换药
- **禁止「就地快改」**：行为已收敛后，不允许为某个元素复制一份 handler 单独改——出现这种诉求说明参数化不够，回去补参数，而不是分叉
- **解耦不消除绑定改动**：新增/删除元素、改绑定参数仍要逐元素处理；解耦解决的是**行为逻辑的单一来源**。批量改动核对时相应简化为：核对行为实现 1 处 + 确认各元素绑定仍指向它（见第四节）

## 三、「交互不生效」四层排查（用户反馈后按序定位）

用户说「改了没反应 / 只有部分生效」时，**按层从上往下排查，每层确认后再进下一层**，禁止跳层猜：

1. **源码层——改动是否真的写进了代码**：grep（或 React DevTools）确认该元素的 handler/props 存在且挂在**目标元素**上（不是父级/兄弟）；对照第一节规则 1/3/5/6 核对绑定写法、value/onChange 成对、外层吞事件、key 稳定；多处同构区块是否漏改（规则 8）。
2. **构建层（模式 A）——改动是否进了产物**：最后一次代码改动之后是否重新 `npm run build`；verify-page 的 `--marker`（ASCII 特征串）是否命中。
3. **服务层——用户访问的是不是新产物**：8000 端口是否被旧进程占用着旧 dist（重启）；新增 `mock/*.json` 是否已重启注册路由；模式 B 是否 watcher 没监听到新目录（重启 dev server）。
4. **浏览器层——前端是否报错/被遮挡**：强刷（Ctrl+Shift+R）清旧 bundle；console 有无运行时报错（**任一组件 render 抛错会中断整棵子树，表现为一批交互同时失效**）；DevTools Elements 检查元素是否被透明遮罩/高 z-index 层盖住、有无 `pointer-events: none`；受控组件是否假死（规则 3/4）。

排查结论必须落在具体一层并给出证据（grep 结果、构建时间戳、console 输出），不许「看着没问题」就回复「应该好了」。

## 四、批量改动的逐项核对方式（衔接 SKILL.md）

SKILL.md「交付与确认 → 业务改动」要求批量改动先拆带编号清单、报完成前逐项核对。本文件补充核对标准：

- 每个交互项先做**源码核对**（第一节规则的机械检查），再尽可能**实际操作一遍**（无头浏览器/点击模拟/截图对比），只有源码核对一种手段时要在汇报里注明；
- 一项核对失败，先按第三节四层排查定位到层再修，修复后重新走第三节确认，不许直接盲改。