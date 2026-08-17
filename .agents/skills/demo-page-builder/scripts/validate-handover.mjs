#!/usr/bin/env node
/**
 * 交接文档自检脚本 validate-handover.mjs
 *
 * 用法：
 *   node scripts/validate-handover.mjs docs/handover/<tag名>.md
 *
 * 作用：对生成的交接文档做机器校验，输出逐项 [PASS]/[FAIL]。
 * 任一 [FAIL] 出现，即代表交接文档不合规，调用方必须修正后重新运行，
 * 直到全部 [PASS] 才能向用户报告完成。
 *
 * 依赖：仅 Node 内置模块，无第三方依赖，直接 node 运行。
 */
import fs from 'node:fs';
import path from 'node:path';

const ALLOWED_TOP_LEVEL = ['使用说明', 'DOM 树与组件说明', '设计与用户体验', '功能说明', '对话过程摘要'];
const WHITELIST_PREFIXES = ['antd:', '@ant-design/pro-components:', '@ant-design/x:', '@ant-design/icons:', '@ant-design/x-sdk:'];
// 白名单原子组件常见名（用于 DOM 树叶子检测）
const WHITELIST_NAMES = ['Button', 'Card', 'Table', 'Form', 'Input', 'Select', 'Drawer', 'Popconfirm',
  'Statistic', 'Avatar', 'Tag', 'Pagination', 'Space', 'Modal', 'InputNumber', 'DatePicker', 'Switch',
  'Tabs', 'Menu', 'Layout', 'ProTable', 'ProForm', 'ProFormText', 'ProFormSelect', 'ProFormTextArea',
  'ProCard', 'ProDescriptions', 'Sender', 'Bubble', 'Conversations', 'Prompts', 'ThoughtChain', 'Skeleton', 'Empty'];
// 每个功能的必备用例字段（功能说明下每个功能必须包含的标题）
const REQUIRED_USE_CASE_FIELDS = [
  '用例概述', '功能目标', '用户场景', '页面/界面说明',
  '正常流程', '业务规则', '各种状态表现', '异常流程', '验收标准',
];
const PLACEHOLDER_MARKERS = ['TODO', '待补充', '待确认', '此处填写', '占位', '<占位', '<?', '填写占位'];
const UNFOUNDED_MARKERS = ['无依据的假设', '假设：', '我猜测', '我推测', '应该是这样', '大概是这样'];

function fail(file, label, msg) {
  console.error(`[FAIL] ${label}${msg ? `：${msg}` : ''}`);
}

function pass(label, msg = '') {
  console.log(`[PASS] ${label}${msg ? `：${msg}` : ''}`);
}

function error(msg) {
  console.error(msg);
}

function main() {
  const target = process.argv[2];
  if (!target) {
    error('用法：node scripts/validate-handover.mjs docs/handover/<tag名>.md');
    process.exit(2);
  }
  if (!fs.existsSync(target)) {
    error(`[FAIL] 文件不存在：${target}`);
    process.exit(1);
  }

  const file = path.resolve(target);
  const content = fs.readFileSync(file, 'utf8');
  const basename = path.basename(file, '.md');
  const lines = content.split(/\r?\n/);
  let exitCode = 0;
  const check = (ok, label, msg) => {
    if (ok) pass(label, msg);
    else { fail(file, label, msg); exitCode = 1; }
  };

  console.log(`\n校验交接文档：${target}\n`);

  /* ---------- 1. 只有规定的五个一级章节 ---------- */
  const h1 = [];
  for (const ln of lines) {
    const m = ln.match(/^#\s+(.+?)\s*$/);
    if (m) h1.push(m[1].trim());
  }
  // 允许标题带序号（如「一、使用说明」）与括注（如「Design & UX」），归一化后比对
  const norm = (s) => s
    .replace(/^[一二三四五六七八九十]+、/, '')
    .replace(/[（(].*?[)）]$/, '')
    .trim();
  const normH1 = h1.map(norm);
  const onlyFive = normH1.length === 5;
  check(onlyFive, '一级章节数量为 5', `实际 ${normH1.length} 个：${h1.join(' / ')}`);
  const allAllowed = normH1.every((h) => ALLOWED_TOP_LEVEL.includes(h));
  check(allAllowed, '一级章节均属规定五章节', normH1.filter((h) => !ALLOWED_TOP_LEVEL.includes(h)).join(' / ') || undefined);
  // 去重：同一章节只能出现一次
  const seen = new Set();
  const dups = normH1.filter((h) => (seen.has(h) ? true : (seen.add(h), false)));
  check(dups.length === 0, '一级章节无重复', dups.join(' / ') || undefined);

  /* ---------- 2. 至少一个 mermaid 代码块 ---------- */
  const mermaidBlocks = [...content.matchAll(/```mermaid\s*\n([\s\S]*?)```/g)];
  check(mermaidBlocks.length >= 1, '存在 mermaid 代码块', `共 ${mermaidBlocks.length} 个`);

  /* ---------- 3. Mermaid 包含 flowchart ---------- */
  const hasFlowchart = mermaidBlocks.some((b) => /^\s*flowchart\s+(TD|TB|BT|LR|RL)/m.test(b[1]));
  check(hasFlowchart, 'Mermaid 含 flowchart', mermaidBlocks.length === 0 ? '无 mermaid 块' : undefined);

  /* ---------- 4. Design & UX 有独立用户流程（每功能一条） ---------- */
  const dxIdx = normH1.findIndex((h) => h === '设计与用户体验');
  const dxStart = dxIdx >= 0 ? findSectionStart(normH1, lines, dxIdx) : -1;
  const fnIdx = normH1.findIndex((h) => h === '功能说明');
  const fnStart = fnIdx >= 0 ? findSectionStart(normH1, lines, fnIdx) : -1;
  const dxContent = dxStart >= 0 ? lines.slice(dxStart, fnStart >= 0 ? fnStart : lines.length).join('\n') : '';
  const fnSection = fnStart >= 0 ? lines.slice(fnStart).join('\n') : '';
  const featureBlocks = splitFeatures(fnSection);
  check(
    dxStart >= 0 && /用户流程|User Flow|user flow/i.test(dxContent),
    'Design & UX 含用户流程小节',
    dxStart < 0 ? '未找到该章节' : undefined,
  );
  // 用户流程与功能一一对应：每条流程标题必须引用对应用例编号（UC-XXX-NN）
  const featureIds = featureBlocks
    .map((fb) => { const m = fb.match(/（(UC-[A-Za-z]+-\d+)）/); return m ? m[1] : null; })
    .filter(Boolean);
  const dxFlowIds = [...dxContent.matchAll(/用户流程[：:].+?（(UC-[A-Za-z]+-\d+)）/g)].map((m) => m[1]);
  const missingFlows = featureIds.filter((id) => !dxFlowIds.includes(id));
  check(
    dxStart >= 0 && missingFlows.length === 0,
    '用户流程与功能一一对应（每功能一条，标题含用例编号）',
    missingFlows.length ? `缺流程：${missingFlows.join('、')}` : undefined,
  );

  /* ---------- 5. 每个功能含完整用例字段 ---------- */
  check(featureBlocks.length >= 1, '功能说明存在功能', `共识别 ${featureBlocks.length} 个功能`);
  featureBlocks.forEach((fb, i) => {
    const idMatch = fb.match(/（([A-Za-z]+-\d+)）/);
    const id = idMatch ? idMatch[1] : `功能#${i + 1}`;
    const missing = REQUIRED_USE_CASE_FIELDS.filter((f) => !new RegExp(`###?\\s*\\d*\\.?\\s*${escapeRegExp(f)}`).test(fb));
    check(missing.length === 0, `功能 ${id} 含完整用例字段`, missing.join('、') || undefined);
    // 每个功能内必须有用例编号
    check(/UC-[A-Z]+-\d+/.test(fb), `功能 ${id} 含用例编号`, undefined);
  });

  /* ---------- 6. 异常流程为表格 ---------- */
  featureBlocks.forEach((fb, i) => {
    const idMatch = fb.match(/（([A-Za-z]+-\d+)）/);
    const id = idMatch ? idMatch[1] : `功能#${i + 1}`;
    const excSection = fb.match(/###\s*7\.\s*异常流程[\s\S]*?###\s*8\./);
    const sec = excSection ? excSection[0] : '';
    const hasTableHeader = /\|.*编号.*\|.*触发操作.*\|.*系统表现.*\|.*处理结果.*\|/.test(sec);
    check(hasTableHeader, `功能 ${id} 异常流程为表格`, undefined);
  });

  /* ---------- 7. DOM 树：单页面单棵树 + 叶子为白名单组件 ---------- */
  const domIdx = normH1.findIndex((h) => h === 'DOM 树与组件说明');
  const domStart = domIdx >= 0 ? findSectionStart(normH1, lines, domIdx) : -1;
  const dxSectionStart = dxIdx >= 0 ? findSectionStart(normH1, lines, dxIdx) : lines.length;
  const domLines = domStart >= 0 ? lines.slice(domStart, dxSectionStart) : [];
  // 提取 DOM 树代码块（``` 包裹的树状结构）：一块 = 一棵树 = 一个页面
  const treeBlocks = extractTreeBlocks(domLines);
  check(treeBlocks.length >= 1, 'DOM 树存在且非空', undefined);
  check(treeBlocks.length <= 1, 'DOM 树代码块数量为 1（一份文档只写一个页面）',
    treeBlocks.length > 1 ? `实际 ${treeBlocks.length} 个——多页面交付须按页面拆分多份文档` : undefined);
  const treeLines = treeBlocks.flat();
  if (treeLines.length > 0) {
    const leafViolations = findNonWhitelistLeaves(treeLines);
    check(leafViolations.length === 0, 'DOM 树叶子均为白名单组件',
      leafViolations.length ? leafViolations.join(' / ') : undefined);
  }
  if (treeLines.length > 0) {
    const bareLeaves = findLeavesWithoutAnnotations(treeLines);
    check(bareLeaves.length === 0, 'DOM 树叶子带用途注释（# 字段/列名/按钮行为等，防粗粒度树）',
      bareLeaves.length ? bareLeaves.join(' / ') : undefined);
  }

  /* ---------- 8. 无 TODO / 待补充 / 无依据假设 ---------- */
  const placeholders = PLACEHOLDER_MARKERS.filter((m) => content.includes(m));
  check(placeholders.length === 0, '无 TODO/待补充/占位标记', placeholders.join('、') || undefined);
  const unfounded = UNFOUNDED_MARKERS.filter((m) => content.includes(m));
  check(unfounded.length === 0, '无无依据假设', unfounded.join('、') || undefined);

  /* ---------- 9. 文件名与 tag 完全一致 ---------- */
  const tagFromName = basename.trim();
  const validTag = /^deliver-[\u4e00-\u9fa5A-Za-z0-9]+-\d{8}-\d{2}$/.test(tagFromName);
  check(validTag, '文件名符合 tag 命名规范（deliver-<语义名>-<YYYYMMDD>-<序号>）', tagFromName);

  console.log(`\n${exitCode === 0 ? '✅ 全部通过' : '❌ 存在未通过项，请按 [FAIL] 修正后重新运行'}\n`);
  process.exit(exitCode);
}

/** 找到第 idx 个一级章节的起始行号（按 H1 出现顺序定位，归一化名称比对） */
function findSectionStart(normH1, lines, idx) {
  const target = normH1[idx];
  const normLine = (s) => s
    .replace(/^[一二三四五六七八九十]+、/, '')
    .replace(/[（(].*?[)）]$/, '')
    .trim();
  let seen = -1;
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^#\s+(.+?)\s*$/);
    if (!m) continue;
    const n = normLine(m[1]);
    if (n === target) { seen = i; break; }
  }
  return seen;
}

/** 从功能说明段落中切分出各个功能块（按「## 功能名称」分割），丢弃功能标题前的引导内容 */
function splitFeatures(fnSection) {
  const lines = fnSection.split(/\r?\n/);
  const blocks = [];
  let current = null;   // null = 尚未遇到第一个功能标题
  const flush = () => { if (current && current.length) { blocks.push(current.join('\n')); current = null; } };
  for (const ln of lines) {
    if (/^##\s+功能名称/.test(ln)) { flush(); current = [ln]; continue; }
    if (current) current.push(ln);
  }
  flush();
  return blocks;
}

/** 提取 DOM 树章节内各代码块中的树状行（一块 = 一棵树；排除说明/注释行） */
function extractTreeBlocks(domLines) {
  const blocks = [];
  let current = null;
  for (const ln of domLines) {
    if (/^```/.test(ln.trim())) {
      if (current) { if (current.length) blocks.push(current); current = null; }
      else current = [];
      continue;
    }
    if (!current) continue;
    const t = ln.trim();
    if (!t || /^#/.test(t)) continue;          // 注释
    if (/[│├└]/.test(t)) current.push(ln);     // 含树形符号即视为树行
  }
  if (current && current.length) blocks.push(current);
  return blocks;
}

/** 判断某行是否为叶子节点：其后没有更深的树形行（以最后一个 ├/└ 的列位置为深度） */
function isLeaf(lines, i) {
  const depthOf = (ln) => {
    const m = ln.match(/[├└]/g);
    // 最后一个分支符在行内的列位置即该节点深度
    const last = Math.max(ln.lastIndexOf('├'), ln.lastIndexOf('└'));
    return last;
  };
  const d = depthOf(lines[i]);
  for (let j = i + 1; j < lines.length; j++) {
    if (depthOf(lines[j]) > d) return false;
  }
  return true;
}

/** 找 DOM 树中的叶子节点，并判断是否白名单组件 */
function findNonWhitelistLeaves(treeLines) {
  const violations = [];
  for (let i = 0; i < treeLines.length; i++) {
    if (!isLeaf(treeLines, i)) continue;
    const text = treeLines[i].trim();
    const stripped = text.replace(/^[│├└─\s]+/, '');        // 去掉左侧树形符号与缩进
    const namePart = stripped.split('#')[0].split('：')[0].trim();
    if (!namePart) continue;
    // 区块标题类标签（后面跟冒号/纯文字且无组件标注）若成叶子，按不合规处理
    const isWhitelist = WHITELIST_PREFIXES.some((p) => namePart.startsWith(p))
      || WHITELIST_NAMES.some((n) => namePart.includes(n));
    if (!isWhitelist) {
      violations.push(`原生叶子「${namePart}」`);
    }
  }
  return violations;
}

/** 找 DOM 树中不带任何用途注释（# 或全/半角括注）的叶子节点——粗粒度树的信号 */
function findLeavesWithoutAnnotations(treeLines) {
  const bare = [];
  for (let i = 0; i < treeLines.length; i++) {
    if (!isLeaf(treeLines, i)) continue;
    const stripped = treeLines[i].trim().replace(/^[│├└─\s]+/, '');
    if (!stripped) continue;
    if (!/[#（(]/.test(stripped)) bare.push(`「${stripped}」`);
  }
  return bare;
}

function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

main();
