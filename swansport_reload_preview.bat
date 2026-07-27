@echo off
setlocal

title SwanSport Preview Reload

set "PROJECT_ROOT=%~dp0"
set "APP_DIR=%PROJECT_ROOT%apps\swansport_app"
set "PATH=C:\Program Files\Git\cmd;C:\src\flutter\bin;C:\Users\Nisa\AppData\Local\Pub\Cache\bin;%PATH%"

echo.
echo SwanSport preview reload/restart hazirlaniyor...
echo Port: 8080
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$targets = Get-CimInstance Win32_Process | Where-Object { ($_.Name -in @('dart.exe','dartvm.exe','dartaotruntime.exe','cmd.exe')) -and ($_.CommandLine -match 'flutter' -or $_.CommandLine -match 'web-server' -or $_.CommandLine -match 'main_development') }; foreach ($p in $targets) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch {} }"

timeout /t 2 /nobreak >nul

cd /d "%APP_DIR%"

start "" "http://localhost:8080"

flutter run -d web-server --web-port 8080 --web-hostname localhost -t lib\main_development.dart ^
  --dart-define=APP_ENV=development ^
  --dart-define=APP_NAME=SwanSport ^
  --dart-define=ENABLE_DEBUG_TOOLS=true

echo.
echo Preview kapandi. Cikmak icin bir tusa basin.
pause >nul

