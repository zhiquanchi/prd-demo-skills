#!/usr/bin/env bash
set -euo pipefail

# Exit codes: 0=pass; 2=bad args; 3=route unreachable; 4=dist missing; 5=marker
# not in dist; 6=route file missing; 7=route not generated; 8=marker not in dev
# lazy chunk; 9=API HTTP status not 200; 10=API Content-Type not JSON;
# 11=API response not valid JSON or missing required fields.

usage() {
  echo "Usage: $0 --mode dist|dev --route /path --marker TEXT [--api /api/name[:field[,field...]]] [--port PORT] [--project DIR]" >&2
  echo "       --api 可重复传入页面依赖的每个 mock API；先验证 API，再验证页面与 chunk" >&2
}

mode=
route=
marker=
port=8000
project_dir="$PWD"
apis=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) mode="${2:-}"; shift 2 ;;
    --route) route="${2:-}"; shift 2 ;;
    --marker) marker="${2:-}"; shift 2 ;;
    --api) apis+=("${2:-}"); shift 2 ;;
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

for spec in ${apis[@]+"${apis[@]}"}; do
  if [[ ! "$spec" =~ ^/ ]]; then
    echo "API spec must start with /: $spec" >&2
    exit 2
  fi
done

if [[ ! -d "$project_dir" ]]; then
  echo "Project directory does not exist: $project_dir" >&2
  exit 2
fi

project_dir="$(cd "$project_dir" && pwd -P)"
base_url="http://localhost:$port"

# Request one mock API and assert HTTP 200 + JSON Content-Type + parseable body
# (with optional required top-level fields). Fails hard on SPA fallback HTML.
check_api() {
  local spec="$1"
  local api_path="${spec%%:*}"
  local fields=""
  if [[ "$spec" == *:* ]]; then
    fields="${spec#*:}"
  fi
  local tmp
  tmp="$(mktemp)"
  local meta code ctype
  meta="$(curl -sS -o "$tmp" -w '%{http_code} %{content_type}' "$base_url$api_path" 2>/dev/null || true)"
  code="${meta%% *}"
  ctype="${meta#* }"
  echo "API HTTP status: ${code:-000} (GET $api_path)"
  if [[ "$code" != 200 ]]; then
    echo "API check failed: $base_url$api_path returned HTTP ${code:-000} (expected 200)" >&2
    rm -f "$tmp"
    return 9
  fi
  if [[ "$ctype" != *application/json* ]]; then
    echo "API check failed: $base_url$api_path Content-Type is '${ctype:-<none>}', expected application/json (probably SPA fallback returning index.html)" >&2
    rm -f "$tmp"
    return 10
  fi
  local rc=0
  node - "$tmp" "$fields" "$api_path" <<'NODE' || rc=1
const fs = require('fs');
const [file, fieldsArg, apiPath] = process.argv.slice(2);
const fields = (fieldsArg || '').split(',').map((s) => s.trim()).filter(Boolean);
let data;
try {
  data = JSON.parse(fs.readFileSync(file, 'utf8'));
} catch {
  console.error(`API JSON validation: FAIL (${apiPath} response is not valid JSON, probably SPA fallback HTML)`);
  process.exit(1);
}
const target = Array.isArray(data) ? data[0] : data;
const missing = fields.filter((f) => !(target && typeof target === 'object' && f in target));
if (missing.length > 0) {
  console.error(`API JSON validation: FAIL (${apiPath} missing required field(s): ${missing.join(', ')})`);
  process.exit(1);
}
console.log(`API JSON validation: PASS (${apiPath} parses as JSON${fields.length ? `, fields: ${fields.join(', ')}` : ''})`);
NODE
  rm -f "$tmp"
  if [[ "$rc" != 0 ]]; then
    return 11
  fi
  return 0
}

api_status=0
for spec in ${apis[@]+"${apis[@]}"}; do
  check_api "$spec" || api_status=$?
done
if [[ "$api_status" != 0 ]]; then
  exit "$api_status"
fi

status="$(curl -sS -o /dev/null -w '%{http_code}' "$base_url$route" || true)"
echo "Page HTTP status: ${status:-000} (GET $route)"
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
  echo "Page chunk marker: PASS (found in dist JavaScript)"
  echo "Verified dist route, API and marker: $base_url$route"
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
    echo "Page chunk marker: PASS (found in $candidate)"
    echo "Verified dev route, API and marker: $base_url$route"
    exit 0
  fi
done

echo "Route exists, but the marker was not found in its conventional lazy chunk: $marker" >&2
exit 8
