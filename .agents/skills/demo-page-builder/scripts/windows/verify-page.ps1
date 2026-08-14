# verify-page.ps1 — demo-page-builder 页面生效验证（PowerShell 版）
# 行为、输出与退出码和 verify-page.sh 一致：
#   0=通过；2=参数错误；3=路由不可达；4=dist 缺失；5=marker 不在 dist；6=路由文件缺失；7=路由未生成；8=marker 不在 dev 懒加载 chunk；
#   9=API HTTP 状态非 200；10=API Content-Type 不是 JSON；11=API 响应不是合法 JSON 或缺必需字段
# 用法：verify-page.ps1 -Mode dist|dev -Route /path -Marker TEXT [-Api "/api/name[:field[,field...]]"] [-Port PORT] [-Project DIR]
#       -Api 可重复传入页面依赖的每个 mock API；先验证 API，再验证页面与 chunk
param(
    [string]$Mode = "",
    [string]$Route = "",
    [string]$Marker = "",
    [string[]]$Api = @(),
    [string]$Port = "8000",
    [string]$Project = ""
)

function Show-Usage {
    Write-Error "Usage: verify-page.ps1 -Mode dist|dev -Route /path -Marker TEXT [-Api /api/name[:field[,field...]]] [-Port PORT] [-Project DIR]"
    exit 2
}

if ($Mode -ne "dist" -and $Mode -ne "dev") { Show-Usage }
if ([string]::IsNullOrEmpty($Route) -or [string]::IsNullOrEmpty($Marker)) { Show-Usage }
if (-not $Route.StartsWith("/") -or $Port -notmatch '^[0-9]+$') {
    Write-Error "Route must start with / and port must be numeric."
    exit 2
}
foreach ($spec in $Api) {
    if (-not $spec.StartsWith("/")) {
        Write-Error "API spec must start with /: $spec"
        exit 2
    }
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

# 请求一个 mock API：断言 HTTP 200、Content-Type 为 JSON、响应可解析且具备必需字段。
# SPA fallback 返回 index.html 时会在这里失败（Content-Type / JSON 解析不过）。
function Check-Api([string]$Spec) {
    $apiPath = $Spec
    $fields = @()
    if ($Spec.Contains(":")) {
        $apiPath = $Spec.Substring(0, $Spec.IndexOf(":"))
        $fields = $Spec.Substring($Spec.IndexOf(":") + 1) -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }
    try {
        $resp = Invoke-WebRequest -Uri "$baseUrl$apiPath" -UseBasicParsing -TimeoutSec 15 -ErrorAction Stop
    } catch {
        $code = 0
        if ($_.Exception.Response) { $code = [int]$_.Exception.Response.StatusCode }
        Write-Output "API HTTP status: $code (GET $apiPath)"
        Write-Error "API check failed: $baseUrl$apiPath returned HTTP $code (expected 200)"
        exit 9
    }
    $code = [int]$resp.StatusCode
    Write-Output "API HTTP status: $code (GET $apiPath)"
    if ($code -ne 200) {
        Write-Error "API check failed: $baseUrl$apiPath returned HTTP $code (expected 200)"
        exit 9
    }
    $contentType = ""
    if ($resp.Headers -and $resp.Headers.ContainsKey("Content-Type")) {
        $contentType = [string]$resp.Headers["Content-Type"]
    }
    if (-not $contentType -or $contentType -notmatch 'json') {
        Write-Error "API check failed: $baseUrl$apiPath Content-Type is '$contentType', expected JSON (probably SPA fallback returning index.html)"
        exit 10
    }
    try {
        $data = $resp.Content | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Error "API JSON validation: FAIL ($apiPath response is not valid JSON, probably SPA fallback HTML)"
        exit 11
    }
    $target = $data
    if ($data -is [array] -and $data.Count -gt 0) { $target = $data[0] }
    $missing = @($fields | Where-Object { -not ($target -and $target.PSObject.Properties.Name -contains $_) })
    if ($missing.Count -gt 0) {
        Write-Error "API JSON validation: FAIL ($apiPath missing required field(s): $($missing -join ', '))"
        exit 11
    }
    $fieldNote = ""
    if ($fields.Count -gt 0) { $fieldNote = ", fields: $($fields -join ', ')" }
    Write-Output "API JSON validation: PASS ($apiPath parses as JSON$fieldNote)"
}

foreach ($spec in $Api) {
    Check-Api $spec
}

$status = Get-HttpStatus "$baseUrl$Route"
Write-Output "Page HTTP status: $status (GET $Route)"
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
    Write-Output "Page chunk marker: PASS (found in dist JavaScript)"
    Write-Output "Verified dist route, API and marker: $baseUrl$Route"
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
        Write-Output "Page chunk marker: PASS (found in $candidate)"
        Write-Output "Verified dev route, API and marker: $baseUrl$Route"
        exit 0
    }
}

Write-Error "Route exists, but the marker was not found in its conventional lazy chunk: $Marker"
exit 8
