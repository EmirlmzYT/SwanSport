[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Host.UI.RawUI.WindowTitle = '4 - AGY REVIEWER'

if (-not (Get-Command agy -ErrorAction SilentlyContinue)) {
  throw 'Antigravity CLI bulunamadi. Yeni bir PowerShell acip agy --version komutunu deneyin.'
}

Push-Location -LiteralPath $projectRoot
try {
  $reviewerPrompt = @'
Bu terminal SwanSport ANTIGRAVITY REVIEWER oturumudur.

Kök AGENTS.md dosyasını tamamen oku; ardından .ai-team/README.md ve .ai-team/TEAM_BOARD.md dosyalarını oku. Writer terminallerinin ürettiği kodu bağımsız olarak incele.
Hiçbir dosyayı değiştirme. Ajanının dosya yazma ve komut çalıştırma araçları bilerek kapalıdır.
Defterdeki kayıtları gerçek değişikliklerle karşılaştır; eskimiş veya çelişkiliyse raporla. TEAM_BOARD.md dosyasını da değiştirme; kabul edilen bulguları aktif Writer kaydedecek.
Bulguları önem sırasıyla, kaynak kanıtıyla ve Writer terminaline aktarılabilecek düzeltme talimatıyla raporla.

Şimdi yalnızca ANTIGRAVITY REVIEWER rolünün hazır ve salt okunur olduğunu kısaca belirt ve denetim görevini bekle.
'@

  & agy `
    --agent swan-reviewer `
    --mode plan `
    --sandbox `
    --prompt-interactive $reviewerPrompt

  exit $LASTEXITCODE
}
finally {
  Pop-Location
}
