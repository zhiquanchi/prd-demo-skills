# check-environment.ps1 — demo-page-builder 环境一键探测（PowerShell 版）
# 输出格式与退出码和 check-environment.sh 完全一致：
#   退出码 0=就绪；10=node 缺失；11=node 是 bun 壳；12=node 版本过旧；13=npm 缺失；2=参数错误
param(
    [string]$ProjectDir = ""
)

$minimumMajor = 18

if ([string]::IsNullOrEmpty($ProjectDir)) {
    $ProjectDir = $PWD.Path
}

if (-not (Test-Path -LiteralPath $ProjectDir -PathType Container)) {
    Write-Error "Project directory does not exist: $ProjectDir"
    exit 2
}
$ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path

# 原生 Windows 为 native；若在 WSL 内运行 pwsh，则与 .sh 一致判定为 wsl
$environment = "native"
if (Test-Path "/proc/version") {
    if (Select-String -Path "/proc/version" -Pattern "microsoft" -Quiet) {
        $environment = "wsl"
    }
}

Write-Output "project_dir=$ProjectDir"
Write-Output "environment=$environment"

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) {
    Write-Output "node_status=missing"
    Write-Error "Node.js >= $minimumMajor is required. Follow references/environment.md to install a project-local runtime."
    exit 10
}

$runtime = (& node -p "process.versions.bun ? 'bun ' + process.versions.bun : 'node ' + process.version" 2>$null) -join ""
Write-Output "runtime=$runtime"

if ($runtime -like "bun *") {
    Write-Output "node_status=bun-wrapper"
    Write-Error "The node command resolves to Bun. Follow references/environment.md to locate or install real Node.js."
    exit 11
}

$nodeMajorRaw = (& node -p "Number(process.versions.node.split('.')[0])" 2>$null) -join ""
$nodeMajor = 0
if (-not [int]::TryParse($nodeMajorRaw.Trim(), [ref]$nodeMajor)) {
    Write-Output "node_status=too-old"
    Write-Error "Unable to determine Node.js major version from: $nodeMajorRaw"
    exit 12
}
if ($nodeMajor -lt $minimumMajor) {
    Write-Output "node_status=too-old"
    Write-Error "Node.js >= $minimumMajor is required; found $(& node -v)."
    exit 12
}

$npmCmd = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npmCmd) {
    Write-Output "npm_status=missing"
    Write-Error "npm is required next to the selected Node.js runtime."
    exit 13
}

Write-Output "node_status=ok"
Write-Output "node_version=$(& node -v)"
Write-Output "npm_version=$(& npm -v)"

if (Test-Path -LiteralPath (Join-Path $ProjectDir "package.json")) {
    Write-Output "project_status=package-present"
} else {
    Write-Output "project_status=needs-init"
}

if (Test-Path -LiteralPath (Join-Path $ProjectDir "node_modules")) {
    Write-Output "dependencies=present"
} else {
    Write-Output "dependencies=missing"
}

exit 0
