# SwanSport AI ekip protokolü

Bu klasör, aynı çalışma alanını kullanan Codex ve Antigravity terminalleri
arasındaki vardiya defteridir. Kaynak kodun yerine geçmez; güncel durum her
zaman Git ve gerçek dosyalarla doğrulanır.

## Her görevde zorunlu sıra

1. Kök `AGENTS.md` dosyasını tamamen oku.
2. `.ai-team/TEAM_BOARD.md` dosyasını oku.
3. Git durumunu ve ilgili gerçek dosyaları kontrol ederek defteri doğrula.
4. Yalnızca kullanıcı tarafından seçilmiş Writer değişiklik yapar.

## Writer güncelleme noktaları

Aktif Writer, `TEAM_BOARD.md` dosyasını:

- ilk kaynak kod değişikliğinden önce görevi üstlenirken,
- her anlamlı değişiklik grubundan sonra,
- test veya analiz çalıştırdıktan sonra,
- engellendiğinde ve terminal değiştirmeden/işi bırakmadan önce

günceller. Her tuş vuruşunu değil, diğer ajanın devam edebilmesi için gereken
anlamlı kontrol noktalarını kaydeder.

Bir başka Writer `active` görünüyorsa dosya değiştirme; kullanıcıdan hangi
Writer'ın devraldığını belirtmesini iste. Devralan Writer önce defteri
`active` durumuyla kendi adına günceller.

## Reviewer davranışı

Reviewer terminalleri salt okunurdur. Defteri ve gerçek diff'i karşılaştırır,
eskimiş veya çelişkili kayıtları raporlar; defteri kendileri değiştirmez.
Reviewer bulgularından kabul edilenleri aktif Writer deftere işler.

## Kayıt ilkeleri

- Sır, erişim anahtarı, kişisel veri, uzun log veya kaynak kod kopyalama.
- Dosya yollarını ve çalıştırılan komutların kısa sonucunu yaz.
- Başarısız doğrulamaları başarı gibi gösterme.
- Eski satırları sessizce yeniden yazmak yerine Değişiklik günlüğüne yeni
  satır ekle; tablo büyüdüğünde tamamlanmış eski satırlar arşivlenebilir.
