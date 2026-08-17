# 示例数据用 Umi Mock（demo-page-builder 的参考文档）

> 本文件是 `demo-page-builder` skill 的 additional material，不是独立 skill。生成 demo、复刻原型时，只要页面需要展示/操作**示例数据**（列表、表格、卡片、图表、表单回填、详情等），一律由本规则约束。Umi 官方文档见：https://umijs.org/docs/guides/mock

## 硬性规则：示例数据写进 `mock/`，不放 UI 组件里

生成和复刻时的所有示例数据，**必须写入项目根的 `mock/` 目录**，页面通过 HTTP 请求从 mock 接口取数。**禁止把示例数据直接硬编码在 UI 组件（`src/pages/**`、`src/components/**`）里**：

- ❌ 在页面里写 `const data = [{...}]` 数组/对象字面量作为列表、表格、图表、表单的数据源
- ❌ 在页面里 import 一个放在 `src/` 下的"数据文件"
- ✅ 数据统一放在 `mock/*.json` + `mock/*.ts`（见下节），页面用 `request('/api/xxx')` 异步取数

**`mock/` 是示例数据的唯一数据源**：同一份示例数据只允许存在一份，禁止在页面组件、静态服务脚本（`scripts/serve-dist.js`）或其他任何位置重复硬编码。

mock 的是**数据来源**，不是功能本身。交互逻辑（增删改、搜索、筛选、排序、分页、表单校验）仍然真实实现、真实生效，只是数据来自 mock 接口，不能因为 mock 就跳过功能。

## mock 目录与文件

项目根下新建 `mock/` 目录，按业务域拆文件（如 `mock/users.ts` + `mock/users.json`、`mock/orders.ts` + `mock/orders.json`）。Umi 约定 `mock/` 下所有 `.ts` 文件都是 mock 文件，默认导出对象，对象的每个 key 对应一个接口（**页面取数的 GET 数据本体必须落 `mock/<domain>.json`**，见下节；GET 接口从 JSON 导入，POST/PUT/DELETE 等操作型响应可直接内联）：

```ts
// ./mock/users.ts —— GET 数据从 JSON 导入，操作型响应可内联
import users from './users.json';

export default {
  // GET 接口：数据来自 JSON 文件（唯一数据源）
  '/api/users': users,
  // 其它请求方法：操作型响应可直接内联
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

## 数据落盘：`mock/<domain>.json` 为唯一数据源（强制）

页面使用的每个 GET 型示例数据接口，数据本体放 `mock/<domain>.json`，`mock/<domain>.ts` 导入该 JSON 并导出 Umi Mock 接口：

```jsonc
// ./mock/keywords.json —— 数据本体，唯一数据源
{
  "rows": [
    { "id": 1, "keyword": "示例词", "score": 96 }
  ],
  "total": 1
}
```

```ts
// ./mock/keywords.ts —— 导入 JSON，导出 mock 接口
import keywords from './keywords.json';

export default {
  '/api/keywords': keywords,
};
```

- **禁止在页面组件或静态服务脚本（`scripts/serve-dist.js`）里重复硬编码同一份数据**——它们只能从 `mock/<domain>.json` 读取
- 顶层字段就是页面的数据契约（如 `rows`、`total`），页面与验证脚本都按它校验
- mockjs 随机数据这类"非静态 JSON"只能用于开发期增强，页面核心展示数据仍要有确定性的 JSON 落盘

## 生产静态服务下的 mock API 等价路由（模式 A 强制）

**Umi Mock 只在开发模式（`max dev`）生效**。WSL 环境走"生产构建 + 静态服务"（模式 A，见 `dev-server.md`）时，`max build` 产物里没有任何 mock 逻辑——静态服务如果不提供等价 API 路由，`/api/xxx` 会被 SPA fallback 接住并返回 `index.html`，页面把 HTML 当 JSON 解析后访问 `data.rows` 等字段直接运行时异常，**表现为刷新瞬间可见页面骨架、接口请求返回后整页白屏**。

强制规则：

1. **凡是页面 `request('/api/xxx')` 用到的接口，静态服务必须提供等价路由**——没有等价路由的 mock 接口不允许上线静态验证
2. 项目模板的 `scripts/serve-dist.js` 已内置等价路由：**自动把 `mock/<name>.json` 注册为 `GET /api/<name>`**（按启动时扫描注册，新增 JSON 文件需重启服务；文件内容每次请求现读，改数据不用重启）；未注册的 `/api/*` 一律返回 404 JSON，绝不落入 SPA fallback 返回 HTML
3. 路径对应关系：`mock/keywords.json` ⇄ `/api/keywords` ⇄ 页面 `request('/api/keywords')`，三处路径必须一致
4. 老项目的 `serve-dist.js` 没有 mock 路由时，从 `assets/project-template/scripts/serve-dist.js` 重新复制，不要手抄
5. 验证时用 verify-page 脚本的 `--api` 参数逐个断言（见 `dev-server.md`），确认返回的是合法 JSON 而不是 `index.html`

## 页面侧取数（必须带格式校验与兜底）

页面用 Umi Max 内置的 `request`（从 `@umijs/max` 导入，零配置、免装依赖）异步请求 mock 接口。**取数必须做运行时格式校验并接 `.catch()` 兜底**：接口失败或响应不符合预期时保留安全初始状态并给出可理解的错误提示，**绝不把 `undefined`/非预期结构写进后续会 `.filter()`、`.map()` 的 state**——否则一次异常就白屏：

```tsx
import { request } from '@umijs/max';
import { useEffect, useState } from 'react';
import { Table, Alert } from 'antd';

type UserRow = { id: number; name: string; role: string };
type UsersResp = { rows?: UserRow[] };

export default function Users() {
  // 安全初始状态：数组就是数组，绝不为 undefined
  const [rows, setRows] = useState<UserRow[]>([]);
  const [error, setError] = useState('');

  useEffect(() => {
    let alive = true;
    request('/api/users')
      .then((res: UsersResp) => {
        if (!alive) return;
        // 运行时格式校验：只有拿到符合预期的结构才写入 state
        if (Array.isArray(res?.rows)) {
          setRows(res.rows);
        } else {
          setError('接口返回的数据格式不符合预期，请稍后重试');
        }
      })
      .catch(() => {
        if (alive) setError('数据加载失败，请检查网络后重试');
      });
    return () => {
      alive = false;
    };
  }, []);

  if (error) return <Alert type="error" showIcon message={error} />;
  return <Table rowKey="id" columns={columns} dataSource={rows} />;
}
```

要点：

- **安全初始状态**：列表/表格/图表数据初始值用 `[]`，对象用 `{}` 或明确兜底值；`res.rows` 之类取字段前先判结构（`Array.isArray` 等）
- **`.catch()` 必须有**：请求失败（网络错误、404、超时）时展示错误提示（如 antd `Alert`/`message`），页面骨架与其他区块保持可用，不允许抛到 React 边界外白屏
- **错误提示可理解**：面向用户的文案，不是原始异常堆栈
- 接口路径（如 `/api/users`）在 `mock/` 与页面 `request` 里**保持一致**，否则请求 404
- mock 默认开启，无需配置；如页面取不到数据，先确认 mock 文件确实导出且路径一致，再看 `mock/` 文件是否正确加载；生产静态模式下则先确认 `mock/<domain>.json` 存在且 serve-dist 已注册对应路由
- 交互后的数据变化由 mock 函数或前端 state 驱动，mock 接口只负责给初始/静态示例数据
- 复刻原稿时，原稿里的真实文案/数据可直接作为 mock 返回值

## 约束范围

- 适用于"生成 demo"与"复刻原型"两类任务中的示例数据
- 不接真实后端：即便配置了 mock，页面也不连真实服务，示例数据全部来自本地 mock
- 若某个页面确实无法走 mock（如纯静态落地页无数据），可不用 mock，但只要有示例数据就必须走 mock
