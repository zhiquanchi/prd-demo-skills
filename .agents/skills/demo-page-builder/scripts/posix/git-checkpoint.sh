#!/usr/bin/env bash
set -euo pipefail

# git-checkpoint.sh — demo-page-builder 阶段钩子：检查 git 提交状态
# 用法：git-checkpoint.sh [项目目录]，不带参数时用当前目录
# 退出码：
#   0  = checkpoint=clean（仓库干净，全部已提交，PASS）
#   1  = checkpoint=dirty（有未提交改动，FAIL——先 git add -A && git commit 再继续）
#   20 = git 不可用（按 references/git.md 安装，唯一征询点）
#   21 = 尚未 git init（Git 预检阶段允许；预检完成后的任何阶段出现即 FAIL）
#   2  = 项目目录不存在

project_dir="${1:-$PWD}"

if [[ ! -d "$project_dir" ]]; then
  echo "Project directory does not exist: $project_dir" >&2
  exit 2
fi
project_dir="$(cd "$project_dir" && pwd -P)"

if ! command -v git >/dev/null 2>&1; then
  echo "checkpoint=git-missing"
  echo "git is not installed in this environment. Follow references/git.md to install it (the only point that asks the user for consent)." >&2
  exit 20
fi

if [[ ! -d "$project_dir/.git" ]]; then
  echo "checkpoint=no-git-repo"
  echo "No .git repository in $project_dir. Git 预检阶段允许此状态；预检完成后的任何阶段出现此状态均 FAIL——按 references/git.md 初始化并提交后再继续。" >&2
  exit 21
fi

status="$(cd "$project_dir" && git status --porcelain)"
if [[ -n "$status" ]]; then
  echo "checkpoint=dirty"
  echo "Uncommitted changes in $project_dir:" >&2
  printf '%s\n' "$status" | head -50 >&2
  echo "Run 'git add -A && git commit' (message: 类型: 简述) before continuing." >&2
  exit 1
fi

echo "checkpoint=clean"
echo "last_commit=$(cd "$project_dir" && git log -1 --format='%h %s' 2>/dev/null || echo none)"
exit 0