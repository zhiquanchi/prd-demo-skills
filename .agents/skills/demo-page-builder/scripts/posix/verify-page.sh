#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 --mode dist|dev --route /path --marker TEXT [--port PORT] [--project DIR]" >&2
}

mode=
route=
marker=
port=8000
project_dir="$PWD"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) mode="${2:-}"; shift 2 ;;
    --route) route="${2:-}"; shift 2 ;;
    --marker) marker="${2:-}"; shift 2 ;;
    --port) port="${2:-}"; shift 2 ;;
    --project) project_dir="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

if [[ "$mode" != dist && "$mode" != dev ]] || [[ -z "$route" || -z "$marker" ]]; then
  usage
  exit 2
fi

if [[ ! "$route" =~ ^/ ]] || [[ ! "$port" =~ ^[0-9]+$ ]]; then
  echo "Route must start with / and port must be numeric." >&2
  exit 2
fi

if [[ ! -d "$project_dir" ]]; then
  echo "Project directory does not exist: $project_dir" >&2
  exit 2
fi

project_dir="$(cd "$project_dir" && pwd -P)"
base_url="http://localhost:$port"
status="$(curl -sS -o /dev/null -w '%{http_code}' "$base_url$route" || true)"
if [[ "$status" != 200 ]]; then
  echo "Route check failed: $base_url$route returned HTTP ${status:-000} (server unreachable or route error)" >&2
  exit 3
fi

if [[ "$mode" == dist ]]; then
  if [[ ! -d "$project_dir/dist" ]]; then
    echo "Missing build directory: $project_dir/dist" >&2
    exit 4
  fi
  if ! grep -rFq --include='*.js' "$marker" "$project_dir/dist"; then
    echo "Marker was not found in dist JavaScript: $marker" >&2
    exit 5
  fi
  echo "Verified dist route and marker: $base_url$route"
  exit 0
fi

route_file="$project_dir/src/.umi/core/route.tsx"
if [[ ! -f "$route_file" ]]; then
  echo "Missing generated route file: $route_file" >&2
  exit 6
fi
if ! grep -Fq "$route" "$route_file"; then
  echo "Generated route file does not contain route: $route" >&2
  exit 7
fi

encoded_route="${route#/}"
encoded_route="${encoded_route//\//__}"
for candidate in \
  "$base_url/src__pages__${encoded_route}.async.js" \
  "$base_url/src__pages__${encoded_route}__index.async.js"; do
  if curl -fsS "$candidate" 2>/dev/null | grep -Fq "$marker"; then
    echo "Verified dev route and marker: $base_url$route"
    exit 0
  fi
done

echo "Route exists, but the marker was not found in its conventional lazy chunk: $marker" >&2
exit 8
