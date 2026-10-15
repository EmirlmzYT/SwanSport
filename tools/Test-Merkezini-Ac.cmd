@echo off
setlocal
cd /d "%~dp0.."
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js 20 veya ustu gerekiyor. docs/local-test-center.md dosyasina bakin.
  pause
  exit /b 1
)
node tools\start_local_test_center.mjs
if errorlevel 1 (
  echo.
  echo Kurulum tamamlanamadi. Yukaridaki hata mesajini paylasabilirsiniz.
)
pause
