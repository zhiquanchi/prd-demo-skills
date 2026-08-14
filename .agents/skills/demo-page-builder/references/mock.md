# 示例数据用 Umi Mock（demo-page-builder 的参考文档）

> 本文件是 `demo-page-builder` skill 的 additional material，不是独立 skill。生成 demo、复刻原型时，只要页面需要展示/操作**示例数据**（列表、表格、卡片、图表、表单回填、详情等），一律由本规则约束。Umi 官方文档见：https://umijs.org/docs/guides/mock

## 硬性规则：示例数据写进 `mock/`，不放 UI 组件里

生成和复刻时的所有示例数据，**必须写入项目根的 `mock/` 目录**，页面通过 HTTP 请求从 mock 接口取数。**禁止把示例数据直接硬编码在 UI 组件（`src/pages/**`、`src/components/**`）里**：

- ❌ 在页面里写 `const data = [{...}]` 数组/对象字面量作为列表、表格、图表、表单的数据源
- ❌ 在页面里 import 一个放在 `src/` 下的"数据文件"
- ✅ 数据统一放在 `mock/*.ts`，页面用 `request('/api/xxx')` 异步取数

mock 的是**数据来源**，不是功能本身。交互逻辑（增删改、搜索、筛选、排序、分页、表单校验）仍然真实实现、真实生效，只是数据来自 mock 接口，不能因为 mock 就跳过功能。

## mock 目录与文件

项目根下新建 `mock/` 目录，按业务域拆文件（如 `mock/users.ts`、`mock/orders.ts`、`mock/charts.ts`）。Umi 约定 `mock/` 下所有文件都是 mock 文件，默认导出对象，对象的每个 key 对应一个接口：

```ts
// ./mock/users.ts
export default {
  // GET 可省略方法名
  '/api/users': [
    { id: 1, name: 'foo', role: 'admin' },
    { id: 2, name: 'bar', role: 'user' },
  ],
  '/api/users/1': { id: 1, name: 'foo', role: 'admin' },
  // 其它请求方法
  'POST /api/users': { result: 'ok' },
  'PUT /api/users/1': { id: 1, name: 'new-foo' },
  'DELETE /api/users/1': { result: 'ok' },
};
```

也可用 `defineMock` 获得类型提示，或函数形式返回（`req`/`res` 同 Express）：

```ts
import { defineMock } from 'umi';

export default defineMock({
  'GET /api/users': [{ id: 1, name: 'foo' }],
  'GET /api/users/:id': (req, res) => {
    res.status(200).json({ id: req.params.id, name: 'foo' });
  },
});
```

需要随机/批量数据时，可用清单内已有的 `mockjs`（项目模板 `package.json` 已含）：

```ts
import mockjs from 'mockjs';

export default {
  'GET /api/tags': mockjs.mock({
    'list|100': [{ name: '@city', 'value|1-100': 50 }],
  }),
};
```

## 页面侧取数

页面用 Umi Max 内置的 `request`（从 `@umijs/max` 导入，零配置、免装依赖）异步请求 mock 接口：

```tsx
import { request } from '@umijs/max';
import { useEffect, useState } from 'react';
import { Table } from 'antd';

export default function Users() {
  const [data, setData] = useState([]);
  useEffect(() => {
    request('/api/users').then((res) => setData(res));
  }, []);
  return <Table rowKey="id" columns={columns} dataSource={data} />;
}
```

要点：

- 接口路径（如 `/api/users`）在 `mock/` 与页面 `request` 里**保持一致**，否则请求 404
- mock 默认开启，无需配置；如页面取不到数据，先确认 mock 文件确实导出且路径一致，再看 `mock/` 文件是否正确加载
- 交互后的数据变化由 mock 函数或前端 state 驱动，mock 接口只负责给初始/静态示例数据
- 复刻原稿时，原稿里的真实文案/数据可直接作为 mock 返回值

## 约束范围

- 适用于"生成 demo"与"复刻原型"两类任务中的示例数据
- 不接真实后端：即便配置了 mock，页面也不连真实服务，示例数据全部来自本地 mock
- 若某个页面确实无法走 mock（如纯静态落地页无数据），可不用 mock，但只要有示例数据就必须走 mock
