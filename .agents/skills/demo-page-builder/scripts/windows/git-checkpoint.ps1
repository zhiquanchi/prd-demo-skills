# git-checkpoint.ps1 — demo-page-builder 阶段钩子（PowerShell 版）
# 用法：git-checkpoint.ps1 [项目目录]，不带参数时用当前目录
# 退出码：0=clean（全部已提交，PASS）；1=dirty（先提交再继续）；
#        20=git 缺失（按 git.md 安装）；21=未 git init（预检完成后 FAIL）；2=目录不存在
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

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    Write-Output "checkpoint=git-missing"
    Write-Error "git is not installed. Follow references/git.md to install it (the only point that asks the user for consent)."
    exit 20
}

if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir ".git") -PathType Container)) {
    Write-Output "checkpoint=no-git-repo"
    Write-Error "No .git repository in $ProjectDir. Git 预检阶段允许此状态；预检完成后出现即 FAIL——按 references/git.md 初始化并提交后再继续."
    exit 21
}

Push-Location $ProjectDir
try {
    $status = @(& git status --porcelain)
    if ($LASTEXITCODE -ne 0) {
        Write-Output "checkpoint=error"
        Write-Error "git status failed with code $LASTEXITCODE."
        exit 1
    }
    if ($status.Count -gt 0) {
        Write-Output "checkpoint=dirty"
        Write-Error "Uncommitted changes in ${ProjectDir}:"
        $status | Select-Object -First 50 | ForEach-Object { Write-Error $_ }
        Write-Error "Run 'git add -A && git commit' (message: 类型: 简述) before continuing."
        exit 1
    }
    $last = (& git log -1 --format="%h %s") 2>$null
    Write-Output "checkpoint=clean"
    Write-Output "last_commit=$last"
    exit 0
}
finally {
    Pop-Location
}