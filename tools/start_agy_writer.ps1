[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Host.UI.RawUI.WindowTitle = '3 - AGY WRITER'

if (-not (Get-Command agy -ErrorAction SilentlyContinue)) {
  throw 'Antigravity CLI bulunamadi. Yeni bir PowerShell acip agy --version komutunu deneyin.'
}

Push-Location -LiteralPath $projectRoot
try {
  $writerPrompt = @'
Bu terminal SwanSport ANTIGRAVITY WRITER oturumudur.

Her görevden önce kök AGENTS.md dosyasını tamamen oku; ardından .ai-team/README.md ve .ai-team/TEAM_BOARD.md dosyalarını oku. swan-orchestrator olarak gerekli uzman alt ajanları görevlendir.
Kullanıcı bu terminali aktif Writer seçtiğinde, ilk kaynak değişikliğinden önce TEAM_BOARD.md üzerinde görevi kendi adına active olarak üstlen. Başka bir Writer active görünüyorsa yazma ve çakışmayı bildir. Her anlamlı değişiklik grubundan, test/analiz sonucundan, engelden ve devirden sonra ortak defteri güncelle.
Bu oturum uygulama yapabilir; kullanıcı değişikliklerini koru, kapsam dışı dosyalara dokunma ve ilgili testleri çalıştır.
Codex Writer terminali de açık olabilir. Kullanıcı açıkça bu oturumu yazıcı olarak seçmeden dosya değiştirme. Codex Writer aktifken yazma; aynı çalışma klasöründe yalnızca bir Writer görev alsın.
Alt ajanları bağımsız alanlara ayır. Aynı dosyada paralel yazma yaptırma. Gizlilik ve QA denetimlerini uygulamadan sonra ayrıca bekle.
Ortak defterdeki bilgiyi gerçek Git durumu ve dosyalarla doğrula.

Şimdi yalnızca ANTIGRAVITY WRITER rolünün hazır olduğunu kısaca belirt ve kullanıcının görevini bekle.
'@

  & agy `
    --agent swan-orchestrator `
    --mode accept-edits `
    --sandbox `
    --prompt-interactive $writerPrompt

  exit $LASTEXITCODE
}
finally {
  Pop-Location
}
