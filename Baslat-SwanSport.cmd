@echo off
setlocal
title SwanSport - Canli Veritabani

echo ===================================================================
echo   SwanSport Ana Uygulama Baslatiliyor...
echo   Baglanti: https://gokkimnokigqxmbppvle.supabase.co
echo   Kullanici: emirbendeniz@gmail.com
echo ===================================================================
echo.

cd /d "%~dp0apps\swansport_app"
flutter run -d chrome -t lib\main_development.dart --dart-define-from-file=..\..\env\dev.json

if %ERRORLEVEL% NEQ 0 (
    echo Chrome bulunamadi veya kapandi, Edge deneniyor...
    flutter run -d edge -t lib\main_development.dart --dart-define-from-file=..\..\env\dev.json
)

pause
