# 组件库白名单（严格限制，禁止引入其他组件库）

**依赖总闸**：所有可用的库以 `assets/project-template/package.json` 的依赖清单为准——只允许 import 清单里已有的包，**禁止安装任何新依赖**（`npm install <pkg>` 一律不行）。清单里没有的能力，用清单内已有的库实现，或如实告诉用户做不了，不擅自引入。

**唯一标准**：只允许使用 `assets/project-template/package.json` 依赖清单（`dependencies` + `devDependencies`）里已有的包和其中的组件——工具类包（如 `express`、`mockjs`、`typescript`）多在 `devDependencies`，同样属清单内。判断依据只有这一份清单——不看 `node_modules` 里实际装了什么，不看历史代码里 import 过什么。**绝不允许引入清单之外的任何新组件、新库、新依赖**（`npm install <pkg>` 一律不行，手写/vendored 复制外部组件代码也不行）。

清单内主要能力速查（以 `assets/project-template/package.json` 实际内容为准）：

| 需求场景 | 用清单里的 |
|---|---|
| 通用 UI 组件（按钮、表单、布局、导航、反馈等） | **antd**（默认选择） |
| 复杂表单/复杂表格（ProForm、ProTable） | **@ant-design/pro-components** |
| AI 组件（Sender、Bubble、Conversations、Prompts、ThoughtChain 等） | **@ant-design/x** / `@ant-design/x-sdk` |
| 图标 | **@ant-design/icons** |
| 图表 | **echarts** + `echarts-for-react` |
| 流程图/画布 | **@xyflow/react**、`dagre`、`fabric`、`konva`/`react-konva`、`react-sketch-canvas` |
| 文本流程图/结构图渲染 | **mermaid** |
| 富文本/Markdown 编辑 | **@tinymce/tinymce-react**、`@uiw/react-md-editor`、`react-markdown` + `remark-gfm` |
| 样式定制 | **antd-style**、`classnames`/`clsx`/`tailwind-merge` |
| 工具库 | `lodash`、`dayjs`、`rc-virtual-list`、`react-fast-marquee` 等清单内其余包 |

## 用户点名要求清单外组件时：直接拒绝 + 给替代（无例外）

这是**硬约束**，以下借口全部不成立，逐一识破：

- ❌ "用户点名要求了" → 用户要求也不能直接用，只能走下面的拒绝流程
- ❌ "这个库本来就在 node_modules 里，没新装包" → 判断标准只有 `assets/project-template/package.json` 清单，不看 `node_modules` 里有什么
- ❌ "只是一个小页面/临时 demo" → 没有规模豁免
- ❌ "清单里没有一模一样的组件" → 用清单内功能最接近的替代，而不是引入新组件
- ❌ "我自己手写一个/抄一段源码进来" → 这也算引入新组件，同样禁止

即使用户明确要求（"用 Element Plus 的表格"、"用 Arco 的 AutoComplete"、"用 shadcn 重做"），也**不得安装、不得 import、不得"这次先用了再提示"**。按以下三步回应：

1. **拒绝**：明确说不能用，不妥协、不"先试试"、不"按你的要求做了再提醒"
2. **告知原因**：项目可用组件以 `assets/project-template/package.json` 清单为唯一标准，清单外一律禁用——混用外部组件库会导致包体积膨胀、主题/设计 token 割裂、交互风格不一致
3. **推荐同功能替代**：先在上面速查表找，找不到就按"先搜后用"流程在清单内的库（antd → ProComponents → Ant Design X → 其余清单内包）中搜索功能最接近的组件推荐给用户

清单内确实没有能力覆盖的，如实告诉用户做不了，由用户决策是否破例，**不擅自引入**。
