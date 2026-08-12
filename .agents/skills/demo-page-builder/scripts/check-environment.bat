@echo off
setlocal EnableExtensions

rem check-environment.bat — demo-page-builder 环境一键探测（cmd 版，原生 Windows 用）
rem 输出格式与退出码和 check-environment.sh 完全一致：
rem   退出码 0=就绪；10=node 缺失；11=node 是 bun 壳；12=node 版本过旧；13=npm 缺失；2=参数错误
rem 用法：check-environment.bat [项目目录]，不带参数时用当前目录

set "MINIMUM_MAJOR=18"
set "PROJECT_DIR=%~1"
if "%PROJECT_DIR%"=="" set "PROJECT_DIR=%CD%"

if not exist "%PROJECT_DIR%\" (
    echo Project directory does not exist: %PROJECT_DIR% 1>&2
    exit /b 2
)

echo project_dir=%PROJECT_DIR%
rem cmd 只会在原生 Windows 上运行，固定 native；WSL 请用 check-environment.sh
echo environment=native

where node >nul 2>nul
if errorlevel 1 (
    echo node_status=missing
    echo Node.js ^>= %MINIMUM_MAJOR% is required. Follow references/environment.md to install a project-local runtime. 1>&2
    exit /b 10
)

set "TMPOUT=%TEMP%\dpb-check-env-%RANDOM%%RANDOM%.txt"

node -p "process.versions.bun ? 'bun ' + process.versions.bun : 'node ' + process.version" > "%TMPOUT%" 2>nul
set "RUNTIME="
for /f "delims=" %%v in ("%TMPOUT%") do set "RUNTIME=%%v"
echo runtime=%RUNTIME%

if "%RUNTIME:~0,4%"=="bun " (
    del "%TMPOUT%" >nul 2>nul
    echo node_status=bun-wrapper
    echo The node command resolves to Bun. Follow references/environment.md to locate or install real Node.js. 1>&2
    exit /b 11
)

node -p "Number(process.versions.node.split('.')[0])" > "%TMPOUT%" 2>nul
set "NODE_MAJOR="
for /f "delims=" %%v in ("%TMPOUT%") do set "NODE_MAJOR=%%v"
del "%TMPOUT%" >nul 2>nul

if "%NODE_MAJOR%"=="" (
    echo node_status=too-old
    echo Unable to determine Node.js major version. 1>&2
    exit /b 12
)
if %NODE_MAJOR% lss %MINIMUM_MAJOR% (
    echo node_status=too-old
    echo Node.js ^>= %MINIMUM_MAJOR% is required. 1>&2
    exit /b 12
)

where npm >nul 2>nul
if errorlevel 1 (
    echo npm_status=missing
    echo npm is required next to the selected Node.js runtime. 1>&2
    exit /b 13
)

echo node_status=ok
for /f "delims=" %%v in ('node -v 2^>nul') do echo node_version=%%v
for /f "delims=" %%v in ('npm -v 2^>nul') do echo npm_version=%%v

if exist "%PROJECT_DIR%\package.json" (
    echo project_status=package-present
) else (
    echo project_status=needs-init
)

if exist "%PROJECT_DIR%\node_modules" (
    echo dependencies=present
) else (
    echo dependencies=missing
)

exit /b 0
