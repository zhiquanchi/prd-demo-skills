#!/usr/bin/env bash
set -euo pipefail

minimum_major=18
project_dir="${1:-$PWD}"

if [[ ! -d "$project_dir" ]]; then
  echo "Project directory does not exist: $project_dir" >&2
  exit 2
fi

project_dir="$(cd "$project_dir" && pwd -P)"

if { [[ -r /proc/version ]] && grep -qi microsoft /proc/version; } || [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
  environment=wsl
else
  environment=native
fi

echo "project_dir=$project_dir"
echo "environment=$environment"

if ! command -v node >/dev/null 2>&1; then
  echo "node_status=missing"
  echo "Node.js >= $minimum_major is required. Follow references/environment.md to install a project-local runtime." >&2
  exit 10
fi

runtime="$(node -p "process.versions.bun ? 'bun ' + process.versions.bun : 'node ' + process.version" 2>/dev/null || true)"
echo "runtime=$runtime"

if [[ "$runtime" == bun\ * ]]; then
  echo "node_status=bun-wrapper"
  echo "The node command resolves to Bun. Follow references/environment.md to locate or install real Node.js." >&2
  exit 11
fi

node_major="$(node -p "Number(process.versions.node.split('.')[0])")"
if (( node_major < minimum_major )); then
  echo "node_status=too-old"
  echo "Node.js >= $minimum_major is required; found $(node -v)." >&2
  exit 12
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm_status=missing"
  echo "npm is required next to the selected Node.js runtime." >&2
  exit 13
fi

echo "node_status=ok"
echo "node_version=$(node -v)"
echo "npm_version=$(npm -v)"

if [[ -f "$project_dir/package.json" ]]; then
  echo "project_status=package-present"
else
  echo "project_status=needs-init"
fi

if [[ -d "$project_dir/node_modules" ]]; then
  echo "dependencies=present"
else
  echo "dependencies=missing"
fi
