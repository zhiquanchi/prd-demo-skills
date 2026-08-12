# init-project.ps1 — demo-page-builder 就地初始化（PowerShell 版）
# 行为、输出与退出码和 init-project.sh 一致：
#   0=成功；1=模板缺失/复制失败/改名失败；2=项目目录不存在；3=拒绝在 skill 目录内初始化；4=已有 package 清单
# 用法：init-project.ps1 [项目目录]，不带参数时用当前目录
# 依赖 node 改写 package.json/package-lock.json 的 name（先跑 check-environment.ps1 确认 node 就绪）
param(
    [string]$ProjectDir = ""
)

if ([string]::IsNullOrEmpty($ProjectDir)) {
    $ProjectDir = $PWD.Path
}

if (-not (Test-Path -LiteralPath $ProjectDir -PathType Container)) {
    Write-Error "Project directory does not exist: $ProjectDir"
    exit 2
}
$ProjectDir = (Resolve-Path -LiteralPath $ProjectDir).Path

$scriptDir = $PSScriptRoot
$skillDir = Split-Path -LiteralPath $scriptDir -Parent
$templateDir = Join-Path $skillDir "assets/project-template"

$sep = [IO.Path]::DirectorySeparatorChar
if ($ProjectDir.Equals($skillDir, [StringComparison]::OrdinalIgnoreCase) -or
    $ProjectDir.StartsWith($skillDir + $sep, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "Refusing to initialize inside the skill directory: $ProjectDir"
    exit 3
}

if ((Test-Path -LiteralPath (Join-Path $ProjectDir "package.json")) -or
    (Test-Path -LiteralPath (Join-Path $ProjectDir "package-lock.json"))) {
    Write-Error "Refusing to overwrite an existing package manifest in: $ProjectDir"
    exit 4
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "node is required to rewrite the package name; run check-environment.ps1 first."
    exit 1
}

if (-not (Test-Path -LiteralPath (Join-Path $templateDir "package.json"))) {
    Write-Error "Template not found: $templateDir"
    exit 1
}

# 与 init-project.sh 相同的项目名规则：小写，空格/下划线转 -，其余非法字符转 -，折叠并去掉首尾 -
$name = (Split-Path -LiteralPath $ProjectDir -Leaf).ToLowerInvariant()
$name = $name -replace '[ _]', '-'
$name = $name -replace '[^a-z0-9._-]+', '-'
$name = $name -replace '-+', '-'
$name = $name.Trim('-')
if ([string]::IsNullOrEmpty($name)) {
    $name = "demo-page"
}

Copy-Item -LiteralPath (Join-Path $templateDir "package.json") -Destination (Join-Path $ProjectDir "package.json")
Copy-Item -LiteralPath (Join-Path $templateDir "package-lock.json") -Destination (Join-Path $ProjectDir "package-lock.json")
New-Item -ItemType Directory -Force -Path (Join-Path $ProjectDir "scripts") | Out-Null
Copy-Item -LiteralPath (Join-Path $templateDir "scripts/serve-dist.js") -Destination (Join-Path $ProjectDir "scripts/serve-dist.js")

$env:PKG_FILE = Join-Path $ProjectDir "package.json"
$env:LOCK_FILE = Join-Path $ProjectDir "package-lock.json"
$env:PROJECT_NAME = $name
& node -e 'const fs=require("fs");for(const f of[process.env.PKG_FILE,process.env.LOCK_FILE]){const j=JSON.parse(fs.readFileSync(f,"utf8"));j.name=process.env.PROJECT_NAME;fs.writeFileSync(f,JSON.stringify(j,null,2)+"\n");}'
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to rewrite package name."
    exit 1
}

$gitignore = Join-Path $ProjectDir ".gitignore"
$entries = @("node_modules/", ".runtime/", "src/.umi/", "src/.umi-production/", "dist/")
$existing = @()
if (Test-Path -LiteralPath $gitignore) {
    $existing = @(Get-Content -LiteralPath $gitignore)
}
foreach ($entry in $entries) {
    if ($existing -notcontains $entry) {
        Add-Content -LiteralPath $gitignore -Value $entry
    }
}

Write-Output "Initialized Umi Max demo project in $ProjectDir"
Write-Output "Next: check the environment, then run npm ci --legacy-peer-deps --no-audit --no-fund"
exit 0
