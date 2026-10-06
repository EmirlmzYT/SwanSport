[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$shell = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source

if (-not $shell) {
  $shell = (Get-Command powershell.exe -ErrorAction Stop).Source
}

$sessions = @(
  @{ Title = '1 - CODEX WRITER'; Script = Join-Path $PSScriptRoot 'start_codex_writer.ps1' },
  @{ Title = '2 - CODEX REVIEWER'; Script = Join-Path $PSScriptRoot 'start_codex_reviewer.ps1' },
  @{ Title = '3 - AGY WRITER'; Script = Join-Path $PSScriptRoot 'start_agy_writer.ps1' },
  @{ Title = '4 - AGY REVIEWER'; Script = Join-Path $PSScriptRoot 'start_agy_reviewer.ps1' }
)

$windowsTerminal = Get-Command wt.exe -ErrorAction SilentlyContinue

if ($windowsTerminal) {
  $tabCommands = foreach ($session in $sessions) {
    $title = $session.Title.Replace('"', '\"')
    $scriptPath = [System.IO.Path]::GetFullPath($session.Script)
    "new-tab --title `"$title`" --suppressApplicationTitle -d `"$projectRoot`" `"$shell`" -NoExit -ExecutionPolicy Bypass -File `"$scriptPath`""
  }

  $arguments = '-w new ' + ($tabCommands -join ' ; ')
  Start-Process -FilePath $windowsTerminal.Source -ArgumentList $arguments
  exit 0
}

foreach ($session in $sessions) {
  $scriptPath = [System.IO.Path]::GetFullPath($session.Script)
  Start-Process -FilePath $shell -WorkingDirectory $projectRoot -ArgumentList @(
    '-NoExit',
    '-ExecutionPolicy', 'Bypass',
    '-File', $scriptPath
  )
}
