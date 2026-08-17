@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem init-project.bat — demo-page-builder 就地初始化（cmd 版，原生 Windows 用）
rem 行为、输出与退出码和 init-project.sh 一致：
rem   0=成功；1=模板缺失/复制失败/改名失败；2=项目目录不存在；3=拒绝在 skill 目录内初始化；4=已有 package 清单
rem 用法：init-project.bat [项目目录]，不带参数时用当前目录
rem 依赖 node 计算项目名并改写 package.json/package-lock.json（先跑 check-environment.bat 确认 node 就绪）

set "PROJECT_DIR=%~1"
if "%PROJECT_DIR%"=="" set "PROJECT_DIR=%CD%"

if not exist "%PROJECT_DIR%\" (
    echo Project directory does not exist: %PROJECT_DIR% 1>&2
    exit /b 2
)
for %%i in ("%PROJECT_DIR%") do set "PROJECT_DIR=%%~fi"

for %%i in ("%~dp0..\..") do set "SKILL_DIR=%%~fi"
if /i "%PROJECT_DIR%"=="%SKILL_DIR%" (
    echo Refusing to initialize inside the skill directory: %PROJECT_DIR% 1>&2
    exit /b 3
)
set "SUBCHECK=!PROJECT_DIR:%SKILL_DIR%\=!"
if /i not "%SUBCHECK%"=="%PROJECT_DIR%" (
    echo Refusing to initialize inside the skill directory: %PROJECT_DIR% 1>&2
    exit /b 3
)

if exist "%PROJECT_DIR%\package.json" (
    echo Refusing to overwrite an existing package manifest in: %PROJECT_DIR% 1>&2
    exit /b 4
)
if exist "%PROJECT_DIR%\package-lock.json" (
    echo Refusing to overwrite an existing package manifest in: %PROJECT_DIR% 1>&2
    exit /b 4
)

for %%i in ("%~dp0..\assets\project-template") do set "TEMPLATE_DIR=%%~fi"
if not exist "%TEMPLATE_DIR%\package.json" (
    echo Template not found: %TEMPLATE_DIR% 1>&2
    exit /b 1
)

copy /y "%TEMPLATE_DIR%\package.json" "%PROJECT_DIR%\package.json" >nul
if errorlevel 1 (
    echo Failed to copy package.json template. 1>&2
    exit /b 1
)
copy /y "%TEMPLATE_DIR%\package-lock.json" "%PROJECT_DIR%\package-lock.json" >nul
if errorlevel 1 (
    echo Failed to copy package-lock.json template. 1>&2
    exit /b 1
)
if not exist "%PROJECT_DIR%\scripts" mkdir "%PROJECT_DIR%\scripts"
copy /y "%TEMPLATE_DIR%\scripts\serve-dist.js" "%PROJECT_DIR%\scripts\serve-dist.js" >nul
if errorlevel 1 (
    echo Failed to copy serve-dist.js template. 1>&2
    exit /b 1
)
copy /y "%TEMPLATE_DIR%\scripts\validate-handover.mjs" "%PROJECT_DIR%\scripts\validate-handover.mjs" >nul
if errorlevel 1 (
    echo Failed to copy validate-handover.mjs template. 1>&2
    exit /b 1
)

set "RAW_NAME="
for %%i in ("%PROJECT_DIR%") do set "RAW_NAME=%%~nxi"

rem 项目名规则与 init-project.sh 相同（小写、空格/下划线转 -、非法字符转 -、折叠去首尾 -），由 node 计算并完成 JSON 改名
set "PKG_FILE=%PROJECT_DIR%\package.json"
set "LOCK_FILE=%PROJECT_DIR%\package-lock.json"
node -e "const fs=require('fs');let n=(process.env.RAW_NAME||'').toLowerCase().replace(/[ _]/g,'-').replace(/[^a-z0-9._-]+/g,'-').replace(/-+/g,'-').replace(/^-+|-+$/g,'');if(!n)n='demo-page';for(const f of[process.env.PKG_FILE,process.env.LOCK_FILE]){const j=JSON.parse(fs.readFileSync(f,'utf8'));j.name=n;fs.writeFileSync(f,JSON.stringify(j,null,2)+'\n');}" >nul
if errorlevel 1 (
    echo Failed to rewrite package name. 1>&2
    exit /b 1
)

rem Whitelist .gitignore: ignore everything except necessary files (Umi directory structure, created on demand)
set "GITIGNORE=%PROJECT_DIR%\.gitignore"
if not exist "%GITIGNORE%" (
    (
        echo # Whitelist mode: ignore everything by default, keep only necessary files.
        echo.
        echo /*
        echo.
        echo # root-level files
        echo ^!/.gitignore
        echo ^!/package.json
        echo ^!/package-lock.json
        echo ^!/README.md
        echo ^!/.umirc.ts
        echo ^!/plugin.ts
        echo.
        echo # necessary dirs ^(created on demand, no empty dirs committed^)
        echo ^!/config/
        echo ^!/docs/
        echo ^!/mock/
        echo ^!/public/
        echo ^!/scripts/
        echo ^!/src/
        echo.
        echo # build/temp artifacts inside allowed dirs stay ignored
        echo node_modules/
        echo dist/
        echo .runtime/
        echo src/.umi/
        echo src/.umi-production/
    ) > "%GITIGNORE%"
)

echo Initialized Umi Max demo project in %PROJECT_DIR%
echo Next: check the environment, then run npm ci --legacy-peer-deps --no-audit --no-fund
exit /b 0
