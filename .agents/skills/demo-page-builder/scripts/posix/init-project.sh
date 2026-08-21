#!/usr/bin/env bash
set -euo pipefail

# init-project.sh — demo-page-builder 就地初始化（POSIX 版）
# 行为、输出与退出码和 init-project.ps1 一致：
#   0=成功；1=模板缺失/复制失败/改名失败（set -e 提前退出）；2=项目目录不存在；3=拒绝在 skill 目录内初始化；4=已有 package 清单
# 用法：init-project.sh [项目目录]，不带参数时用当前目录
# 依赖 node 改写 package.json/package-lock.json 的 name（先跑 check-environment.sh 确认 node 就绪）

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
skill_dir="$(cd "$script_dir/../.." && pwd -P)"
template_dir="$skill_dir/assets/project-template"
project_dir="${1:-$PWD}"

if [[ ! -d "$project_dir" ]]; then
  echo "Project directory does not exist: $project_dir" >&2
  exit 2
fi

project_dir="$(cd "$project_dir" && pwd -P)"
if [[ "$project_dir" == "$skill_dir" || "$project_dir" == "$skill_dir/"* ]]; then
  echo "Refusing to initialize inside the skill directory: $project_dir" >&2
  exit 3
fi

if [[ -e "$project_dir/package.json" || -e "$project_dir/package-lock.json" ]]; then
  echo "Refusing to overwrite an existing package manifest in: $project_dir" >&2
  exit 4
fi

project_name="$(basename "$project_dir" | tr '[:upper:] _' '[:lower:]--')"
project_name="$(printf '%s' "$project_name" | sed -E 's/[^a-z0-9._-]+/-/g; s/-+/-/g; s/^-|-$//g')"
if [[ -z "$project_name" ]]; then
  project_name=demo-page
fi

cp "$template_dir/package.json" "$project_dir/package.json"
cp "$template_dir/package-lock.json" "$project_dir/package-lock.json"
mkdir -p "$project_dir/scripts"
cp "$template_dir/scripts/serve-dist.js" "$project_dir/scripts/serve-dist.js"
cp "$template_dir/scripts/validate-handover.mjs" "$project_dir/scripts/validate-handover.mjs"

PKG_FILE="$project_dir/package.json" LOCK_FILE="$project_dir/package-lock.json" PROJECT_NAME="$project_name" node -e '
const fs = require("fs");
for (const file of [process.env.PKG_FILE, process.env.LOCK_FILE]) {
  const json = JSON.parse(fs.readFileSync(file, "utf8"));
  json.name = process.env.PROJECT_NAME;
  fs.writeFileSync(file, JSON.stringify(json, null, 2) + "\n");
}
'

# Whitelist .gitignore: ignore everything except necessary files (Umi directory structure, created on demand)
gitignore="$project_dir/.gitignore"
if [[ ! -f "$gitignore" ]]; then
  cat > "$gitignore" <<'EOF'
# Whitelist mode: ignore everything by default, keep only necessary files.

/*

# root-level files
!/.gitignore
!/package.json
!/package-lock.json
!/README.md
!/.umirc.ts
!/plugin.ts

# necessary dirs (created on demand, no empty dirs committed)
!/config/
!/docs/
!/mock/
!/public/
!/scripts/
!/src/

# build/temp artifacts inside allowed dirs stay ignored
node_modules/
dist/
.runtime/
src/.umi/
src/.umi-production/
EOF
fi

echo "Initialized Umi Max demo project in $project_dir"
echo "Next: check the environment, then run npm ci --legacy-peer-deps --no-audit --no-fund"
