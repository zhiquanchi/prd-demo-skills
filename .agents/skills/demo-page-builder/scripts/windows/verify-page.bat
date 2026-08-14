@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem verify-page.bat — demo-page-builder 页面生效验证（cmd 版，原生 Windows 用）
rem 行为、输出与退出码和 verify-page.sh 一致：
rem   0=通过；2=参数错误；3=路由不可达；4=dist 缺失；5=marker 不在 dist；6=路由文件缺失；7=路由未生成；8=marker 不在 dev 懒加载 chunk
rem   9=API HTTP 状态非 200；10=API Content-Type 不是 JSON；11=API 响应不是合法 JSON 或缺必需字段
rem 用法：verify-page.bat --mode dist^|dev --route /path --marker TEXT [--api /api/name[:field[,field...]]] [--port PORT] [--project DIR]
rem       --api 可重复传入页面依赖的每个 mock API；先验证 API，再验证页面与 chunk
rem 注意：cmd 的 findstr 对超长单行（约 8KB+，压缩产物常见）可能漏匹配，误报时请改用 verify-page.ps1

set "MODE="
set "ROUTE="
set "MARKER="
set "PORT=8000"
set "PROJECT_DIR=%CD%"
set "APIS="

:parse
if "%~1"=="" goto parse_done
if /i "%~1"=="--mode" ( set "MODE=%~2" & shift & shift & goto parse )
if /i "%~1"=="--route" ( set "ROUTE=%~2" & shift & shift & goto parse )
if /i "%~1"=="--marker" ( set "MARKER=%~2" & shift & shift & goto parse )
if /i "%~1"=="--api" (
    if defined APIS ( set "APIS=!APIS!;%~2" ) else ( set "APIS=%~2" )
    shift & shift & goto parse
)
if /i "%~1"=="--port" ( set "PORT=%~2" & shift & shift & goto parse )
if /i "%~1"=="--project" ( set "PROJECT_DIR=%~2" & shift & shift & goto parse )
if /i "%~1"=="-h" goto show_usage_ok
if /i "%~1"=="--help" goto show_usage_ok
echo Unknown argument: %~1 1>&2
goto show_usage_err

:show_usage_ok
echo Usage: %~nx0 --mode dist^|dev --route /path --marker TEXT [--api /api/name[:field[,field...]]] [--port PORT] [--project DIR]
exit /b 0

:show_usage_err
echo Usage: %~nx0 --mode dist^|dev --route /path --marker TEXT [--api /api/name[:field[,field...]]] [--port PORT] [--project DIR] 1>&2
exit /b 2

:parse_done
if /i not "%MODE%"=="dist" if /i not "%MODE%"=="dev" goto show_usage_err
if "%ROUTE%"=="" goto show_usage_err
if "%MARKER%"=="" goto show_usage_err
if not "%ROUTE:~0,1%"=="/" (
    echo Route must start with / and port must be numeric. 1>&2
    exit /b 2
)
if not defined PORT (
    echo Route must start with / and port must be numeric. 1>&2
    exit /b 2
)
set "PORT_CHECK=%PORT%"
for %%d in (0 1 2 3 4 5 6 7 8 9) do set "PORT_CHECK=!PORT_CHECK:%%d=!"
if defined PORT_CHECK (
    echo Route must start with / and port must be numeric. 1>&2
    exit /b 2
)

if not exist "%PROJECT_DIR%\" (
    echo Project directory does not exist: %PROJECT_DIR% 1>&2
    exit /b 2
)
for %%i in ("%PROJECT_DIR%") do set "PROJECT_DIR=%%~fi"

set "BASE_URL=http://localhost:%PORT%"
set "TMPOUT=%TEMP%\dpb-verify-page-%RANDOM%%RANDOM%.txt"

rem API 验证先于页面验证：断言 HTTP 200、Content-Type 为 JSON、响应可解析且具备必需字段
if not defined APIS goto after_api
set "SPECS=!APIS!"
:api_loop
set "SPEC="
for /f "tokens=1* delims=;" %%a in ("!SPECS!") do (
    set "SPEC=%%a"
    set "SPECS=%%b"
)
if not "!SPEC!"=="" (
    call :check_api "!SPEC!"
    set "API_RC=!ERRORLEVEL!"
    if not "!API_RC!"=="0" exit /b !API_RC!
)
if defined SPECS goto api_loop
:after_api

set "STATUS="
for /f "delims=" %%v in ('curl -s -o nul -w "%%{http_code}" "%BASE_URL%%ROUTE%" 2^>nul') do set "STATUS=%%v"
if "%STATUS%"=="" set "STATUS=000"
echo Page HTTP status: %STATUS% (GET %ROUTE%)
if not "%STATUS%"=="200" (
    echo Route check failed: %BASE_URL%%ROUTE% returned HTTP %STATUS% ^(server unreachable or route error^) 1>&2
    exit /b 3
)

if /i "%MODE%"=="dist" (
    if not exist "%PROJECT_DIR%\dist\" (
        echo Missing build directory: %PROJECT_DIR%\dist 1>&2
        exit /b 4
    )
    findstr /s /m /c:"%MARKER%" "%PROJECT_DIR%\dist\*.js" >nul
    if errorlevel 1 (
        echo Marker was not found in dist JavaScript: %MARKER% 1>&2
        exit /b 5
    )
    echo Page chunk marker: PASS (found in dist JavaScript)
    echo Verified dist route, API and marker: %BASE_URL%%ROUTE%
    exit /b 0
)

set "ROUTE_FILE=%PROJECT_DIR%\src\.umi\core\route.tsx"
if not exist "%ROUTE_FILE%" (
    echo Missing generated route file: %ROUTE_FILE% 1>&2
    exit /b 6
)
findstr /c:"%ROUTE%" "%ROUTE_FILE%" >nul
if errorlevel 1 (
    echo Generated route file does not contain route: %ROUTE% 1>&2
    exit /b 7
)

set "ENCODED=%ROUTE:~1%"
set "ENCODED=%ENCODED:/=__%"

call :check_chunk "%BASE_URL%/src__pages__%ENCODED%.async.js"
if defined CHUNK_OK goto dev_ok
call :check_chunk "%BASE_URL%/src__pages__%ENCODED%__index.async.js"
if defined CHUNK_OK goto dev_ok

echo Route exists, but the marker was not found in its conventional lazy chunk: %MARKER% 1>&2
exit /b 8

:dev_ok
echo Verified dev route, API and marker: %BASE_URL%%ROUTE%
exit /b 0

:check_chunk
set "CHUNK_OK="
curl -fsS "%~1" > "%TMPOUT%" 2>nul
if errorlevel 1 goto :eof
findstr /c:"%MARKER%" "%TMPOUT%" >nul && set "CHUNK_OK=1"
goto :eof

:check_api
rem %1 = "/api/name[:field[,field...]]"；用 curl 取状态码/Content-Type，用 node 校验 JSON 与字段
set "API_SPEC=%~1"
set "API_PATH=%API_SPEC%"
set "API_FIELDS="
for /f "tokens=1,2 delims=:" %%a in ("%API_SPEC%") do (
    set "API_PATH=%%a"
    set "API_FIELDS=%%b"
)
set "API_META="
for /f "delims=" %%v in ('curl -s -o "%TMPOUT%" -w "%%{http_code} %%{content_type}" "%BASE_URL%!API_PATH!" 2^>nul') do set "API_META=%%v"
if "!API_META!"=="" set "API_META=000"
for /f "tokens=1" %%a in ("!API_META!") do set "API_CODE=%%a"
set "API_CT=!API_META:* =!"
echo API HTTP status: !API_CODE! (GET !API_PATH!)
if not "!API_CODE!"=="200" (
    echo API check failed: %BASE_URL%!API_PATH! returned HTTP !API_CODE! ^(expected 200^) 1>&2
    exit /b 9
)
echo !API_CT!| findstr /I /C:"json" >nul
if errorlevel 1 (
    echo API check failed: %BASE_URL%!API_PATH! Content-Type is '!API_CT!', expected JSON ^(probably SPA fallback returning index.html^) 1>&2
    exit /b 10
)
node -e "const fs=require('fs');let d;try{d=JSON.parse(fs.readFileSync(process.argv[1],'utf8'))}catch(e){console.error('API JSON validation: FAIL ('+'!API_PATH!'+' is not valid JSON, probably SPA fallback HTML)');process.exit(1)}const t=Array.isArray(d)?d[0]:d;const want=(process.argv[2]||'').split(',').map(s=>s.trim()).filter(Boolean);const miss=want.filter(f=>!(t&&typeof t==='object'&&f in t));if(miss.length){console.error('API JSON validation: FAIL ('+'!API_PATH!'+' missing required field(s): '+miss.join(', ')+')');process.exit(1)}console.log('API JSON validation: PASS ('+'!API_PATH!'+(want.length?' fields: '+want.join(', '):' parses as JSON')+')')" "%TMPOUT%" "!API_FIELDS!"
if errorlevel 1 exit /b 11
exit /b 0
