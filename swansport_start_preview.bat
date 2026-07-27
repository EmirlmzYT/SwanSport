@echo off
setlocal

title SwanSport Preview

set "PROJECT_ROOT=%~dp0"
set "APP_DIR=%PROJECT_ROOT%apps\swansport_app"
set "PATH=C:\Program Files\Git\cmd;C:\src\flutter\bin;C:\Users\Nisa\AppData\Local\Pub\Cache\bin;%PATH%"

echo.
echo SwanSport development preview baslatiliyor...
echo URL: http://localhost:8080
echo.

cd /d "%APP_DIR%"

start "" "http://localhost:8080"

flutter run -d web-server --web-port 8080 --web-hostname localhost -t lib\main_development.dart ^
  --dart-define=APP_ENV=development ^
  --dart-define=APP_NAME=SwanSport ^
  --dart-define=ENABLE_DEBUG_TOOLS=true

echo.
echo Preview kapandi. Cikmak icin bir tusa basin.
pause >nul

