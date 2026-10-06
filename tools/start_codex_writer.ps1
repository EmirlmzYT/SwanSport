[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$Host.UI.RawUI.WindowTitle = '1 - CODEX WRITER'

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
  throw 'Codex CLI bulunamadi. Yeni bir PowerShell acip codex --version komutunu deneyin.'
}

$writerPrompt = @'
Bu terminal SwanSport WRITER oturumudur.

Her görevden önce depo kökündeki AGENTS.md dosyasını tamamen oku; ardından .ai-team/README.md ve .ai-team/TEAM_BOARD.md dosyalarını oku ve bütün proje değişmezlerine uy.
Kullanıcı bu terminali aktif Writer seçtiğinde, ilk kaynak değişikliğinden önce TEAM_BOARD.md üzerinde görevi kendi adına active olarak üstlen. Başka bir Writer active görünüyorsa yazma ve çakışmayı bildir. Her anlamlı değişiklik grubundan, test/analiz sonucundan, engelden ve devirden sonra ortak defteri güncelle.
Bu oturum uygulama yapabilir; ancak kullanıcının mevcut değişikliklerini koru, kapsam dışı dosyalara dokunma ve yıkıcı Git komutları kullanma.
Alt ajanları bağımsız araştırma, güvenlik ve test incelemesi için kullanabilirsin. Alt ajanlar varsayılan olarak salt okunur çalışsın; aynı dosyalarda paralel yazma yaptırma. Normal durumda yalnızca ana ajan üretim kodu yazsın.
Değişiklikten önce git durumunu incele. Uygulamadan sonra ilgili dar testleri ve etkilenen paketin analizini çalıştır. Kanıt olmadan tamamlandı deme.
Antigravity veya Reviewer terminalinin aynı çalışma alanını okuyabileceğini, fakat bu oturum çalışırken onların yazmaması gerektiğini varsay. Ortak defterdeki bilgiyi gerçek Git durumu ve dosyalarla doğrula.

Şimdi yalnızca WRITER rolünün hazır olduğunu kısaca belirt ve kullanıcının kodlama görevini bekle.
'@

& codex `
  --cd $projectRoot `
  --sandbox workspace-write `
  --ask-for-approval on-request `
  $writerPrompt

exit $LASTEXITCODE
