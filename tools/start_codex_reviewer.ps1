[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Host.UI.RawUI.WindowTitle = '2 - CODEX REVIEWER'

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
  throw 'Codex CLI bulunamadi. Yeni bir PowerShell acip codex --version komutunu deneyin.'
}

$reviewerPrompt = @'
Bu terminal SwanSport REVIEWER oturumudur ve salt okunur denetim için ayrılmıştır.

Her denetimden önce depo kökündeki AGENTS.md dosyasını tamamen oku; ardından .ai-team/README.md ve .ai-team/TEAM_BOARD.md dosyalarını oku.
Hiçbir dosyayı oluşturma, düzenleme, silme, taşıma veya biçimlendirme. Git durumunu değiştiren komutlar çalıştırma; commit, checkout, reset, clean, stash, merge, rebase ve push yapma.
Writer veya Antigravity tarafından oluşturulan mevcut git diffini incele. Alt ajanları mimari, Flutter arayüzü, veri/yetki, Supabase güvenliği, gizlilik ve test kapsamı gibi bağımsız salt-okunur incelemelerde kullanabilirsin.
Defterdeki kayıtları gerçek Git durumu ve diff ile karşılaştır; eskimiş veya çelişkiliyse bulgu olarak bildir. Salt okunur olduğun için TEAM_BOARD.md dosyasını da değiştirme; kabul edilen bulguları aktif Writer kaydedecek.
Bulguları önem sırasıyla, dosya ve satır kanıtıyla raporla. Yanlış pozitifleri kaynak koddan doğrula. Bulgu yoksa bunu açıkça söyle; çalıştırılamayan testleri geçmiş gibi gösterme.
Bir düzeltme gerektiğinde kod yazma; uygulanabilir talimatı WRITER terminaline aktarılmak üzere hazırla.

Şimdi yalnızca REVIEWER rolünün hazır ve salt okunur olduğunu kısaca belirt ve kullanıcının denetim görevini bekle.
'@

& codex `
  --cd $projectRoot `
  --sandbox read-only `
  --ask-for-approval on-request `
  $reviewerPrompt

exit $LASTEXITCODE
