param(
  [string]$Flutter = 'C:/src/flutter/bin/flutter.bat',
  [string]$Chrome = 'C:/Program Files/Google/Chrome/Application/chrome.exe'
)
$ErrorActionPreference = 'Stop'
$workspace = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$package = Join-Path $workspace 'packages/swansport_data'
$target = [IO.Path]::GetFullPath((Join-Path $package 'test/canvaskit'))
if (-not $target.StartsWith($workspace + [IO.Path]::DirectorySeparatorChar)) { throw 'Invalid asset target' }
if (Test-Path -LiteralPath $target) { throw 'Temporary CanvasKit target already exists; preserve and inspect it first' }
$sdk = Split-Path (Split-Path ([IO.Path]::GetFullPath($Flutter)))
$assets = Join-Path $sdk 'bin/cache/flutter_web_sdk/canvaskit'
$files = @('canvaskit.js', 'canvaskit.wasm', 'chromium/canvaskit.js', 'chromium/canvaskit.wasm')
$previousChrome = $env:CHROME_EXECUTABLE
$originalLocation = Get-Location
try {
  # Flutter 3.44.7's Windows test asset handler checks '/' after fromUri returns '\'.
  # Its test-directory fallback can serve the same local SDK files; no SDK edits/downloads.
  New-Item -ItemType Directory -Path (Join-Path $target 'chromium') -Force | Out-Null
  foreach ($file in $files) { Copy-Item -LiteralPath (Join-Path $assets $file) -Destination (Join-Path $target $file) }
  $env:CHROME_EXECUTABLE = $Chrome
  Set-Location -LiteralPath $package
  & $Flutter test --no-pub --platform chrome test/offline_attendance_web_test.dart --reporter expanded
  $testExit = $LASTEXITCODE
} finally {
  Set-Location -LiteralPath $originalLocation.Path
  $env:CHROME_EXECUTABLE = $previousChrome
  foreach ($file in $files) {
    $path = Join-Path $target $file
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
  }
  # Non-recursive removal deliberately fails if unexpected files appeared.
  if (Test-Path -LiteralPath (Join-Path $target 'chromium')) { [IO.Directory]::Delete((Join-Path $target 'chromium')) }
  if (Test-Path -LiteralPath $target) { [IO.Directory]::Delete($target) }
}
exit $testExit
