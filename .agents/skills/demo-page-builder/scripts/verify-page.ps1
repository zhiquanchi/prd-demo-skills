# verify-page.ps1 — demo-page-builder 页面生效验证（PowerShell 版）
# 行为、输出与退出码和 verify-page.sh 一致：
#   0=通过；2=参数错误；3=路由不可达；4=dist 缺失；5=marker 不在 dist；6=路由文件缺失；7=路由未生成；8=marker 不在 dev 懒加载 chunk
# 用法：verify-page.ps1 -Mode dist|dev -Route /path -Marker TEXT [-Port PORT] [-Project DIR]
param(
    [string]$Mode = "",
    [string]$Route = "",
    [string]$Marker = "",
    [string]$Port = "8000",
    [string]$Project = ""
)

function Show-Usage {
    Write-Error "Usage: verify-page.ps1 -Mode dist|dev -Route /path -Marker TEXT [-Port PORT] [-Project DIR]"
    exit 2
}

if ($Mode -ne "dist" -and $Mode -ne "dev") { Show-Usage }
if ([string]::IsNullOrEmpty($Route) -or [string]::IsNullOrEmpty($Marker)) { Show-Usage }
if (-not $Route.StartsWith("/") -or $Port -notmatch '^[0-9]+$') {
    Write-Error "Route must start with / and port must be numeric."
    exit 2
}

if ([string]::IsNullOrEmpty($Project)) {
    $Project = $PWD.Path
}
if (-not (Test-Path -LiteralPath $Project -PathType Container)) {
    Write-Error "Project directory does not exist: $Project"
    exit 2
}
$projectDir = (Resolve-Path -LiteralPath $Project).Path
$baseUrl = "http://localhost:$Port"

function Get-HttpStatus([string]$Url) {
    try {
        $resp = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
        return [int]$resp.StatusCode
    } catch {
        if ($_.Exception.Response) {
            return [int]$_.Exception.Response.StatusCode
        }
        return 0
    }
}

$status = Get-HttpStatus "$baseUrl$Route"
if ($status -ne 200) {
    Write-Error "Route check failed: $baseUrl$Route returned HTTP $status (server unreachable or route error)"
    exit 3
}

if ($Mode -eq "dist") {
    $distDir = Join-Path $projectDir "dist"
    if (-not (Test-Path -LiteralPath $distDir -PathType Container)) {
        Write-Error "Missing build directory: $distDir"
        exit 4
    }
    $hit = Get-ChildItem -LiteralPath $distDir -Recurse -Filter *.js |
        Select-String -SimpleMatch -Pattern $Marker -List |
        Select-Object -First 1
    if (-not $hit) {
        Write-Error "Marker was not found in dist JavaScript: $Marker"
        exit 5
    }
    Write-Output "Verified dist route and marker: $baseUrl$Route"
    exit 0
}

$routeFile = Join-Path $projectDir "src/.umi/core/route.tsx"
if (-not (Test-Path -LiteralPath $routeFile)) {
    Write-Error "Missing generated route file: $routeFile"
    exit 6
}
$routeContent = Get-Content -LiteralPath $routeFile -Raw
if ((-not $routeContent) -or (-not $routeContent.Contains($Route))) {
    Write-Error "Generated route file does not contain route: $Route"
    exit 7
}

$encoded = $Route.TrimStart('/') -replace '/', '__'
$candidates = @(
    "$baseUrl/src__pages__$encoded.async.js",
    "$baseUrl/src__pages__$encoded`__index.async.js"
)
foreach ($candidate in $candidates) {
    try {
        $content = (Invoke-WebRequest -Uri $candidate -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop).Content
    } catch {
        continue
    }
    if ($content -and $content.Contains($Marker)) {
        Write-Output "Verified dev route and marker: $baseUrl$Route"
        exit 0
    }
}

Write-Error "Route exists, but the marker was not found in its conventional lazy chunk: $Marker"
exit 8
