# SwanSport Pro Faz 0–5 ilerleme kaydı

| Faz | Durum | Kanıt |
| --- | --- | --- |
| 0 — Mesleki Belge Başvuruları | Tamamlandı | Pro liste/detay, korumalı belge açma, onay, gerekçeli ret, geçmiş ve branş eşlemesi; SQL satır kilidi; widget/rota/SQL testleri |
| 1 — Ana yüzeyler | Tamamlandı | Panel özeti/Görev kuyruğu ayrımı, takvim kısmi kaynak uyarısı, bildirim hedefleri, workspace reset ve 320–1440 px cihaz matrisi geçti |
| 2 — Kulüp ve antrenman | Tamamlandı | Ayrı üyelik/evrak, takım-kadro, yoklama, App geçmiş/veli sonucu yeşil; Pro antrenör katılımcı ölçümü ve dar staff RPC eklendi |
| 3 — Diğer operasyonlar | Tamamlandı | Veli → finans → tesis → hakem → federasyon sıralı widget/RLS-RPC kanıtı geçti; yeni ürün değişikliği gerekmedi |
| 4 — App/Pro ayrımı | Tamamlandı | Pro işleri sosyal menüden ayrık; öz-servis korunuyor; legacy/dynamic rota, bildirim ve ortak host fallback testleri 31/31 geçti |
| 5 — Son kabul | Tamamlandı (yerel) | Rol zincirleri, SQL/RLS, App/Pro rotaları, analiz ve 390/1440 px render goldens geçti; canlı/fiziksel cihaz bekliyor |

## Faz 0 gözlemleri

- Çalışan App servis sözleşmeleri yeniden kullanıldı; widget içinde doğrudan Supabase çağrısı eklenmedi.
- `review_credential` aynı bekleyen satırı `FOR UPDATE` ile kilitliyor ve ikinci terminal kararı açık hata yapıyor.
- Belge URL'si yalnız korumalı açma köprüsüne aktarılıyor; kart, bildirim veya log metnine yazılmıyor.
- Pro dialog ile liste aynı route/state altında kaldığından filtre ve scroll state'i korunuyor.
- Canlı Supabase ve fiziksel cihaz kabulü yapılmadı; yerel PGlite ve Flutter widget kanıtıdır.

## Faz 1 gözlemleri

- Panel ve Görevler aynı kart kataloğunu tekrarlamıyor; Panel özet, Görevler işlenebilir kuyruk olarak kalıyor.
- Platform yöneticisinin belge kuyruğu yeni doğrudan hedefe eklendi. Kulüp başvurusu ve yoklama/antrenman hedefleri mevcut doğrudan rotalarını koruyor.
- Workspace/kulüp değişimi controller state'ini yeniliyor; önceki kullanıcının e-posta ve workspace state'i logout/account change testinde siliniyor.
- Gelen Kutusu yalnız desteklenen beyaz listeli hedeflere gider; hedef rota kendi SwanAccess kapısını yeniden uygular.
- 320×568–1440×900 ve 1.0×–2.0× metin ölçeği matrisi overflow olmadan geçti.

## Faz 2 gözlemleri

- Üyelik başvurusu ve kulüp evrakı aynı ekranda ayrı bölümler, ayrı servis/yetki sözleşmeleri olarak kalıyor.
- Pro antrenör oturumunda aktif katılımcı açıkça seçiliyor. Sporcu değişiminde girilmiş ama kaydedilmemiş toplam temizleniyor; yanlış sporcuya taşınmıyor.
- Yeni `submit_coach_set_score` yalnız kulüp oturumu, aktif staff, aktif katılımcı ve kilitsiz set için çalışıyor. Ayrıntılı/archetype ölçüm isteyen protokolleri basit toplamla kaydetmiyor.
- App bireysel antrenman, katılım, geçmiş ve veliye açılan sonuç ekranlarını koruyor.

## Faz 3 gözlemleri

- Veli bağlantısı uydurma onay kuyruğu değil; maskeli bağlantılar ve gerçek, süreli davet iptal/ tüketim sözleşmesi.
- Aidat adları yalnız kulüp yöneticisine; muhasebeci defteri athlete_ref ile maskeli ve kulüp değişiminde sayfalama state'i temizleniyor.
- Tesis yöneticisinin görev/rezervasyon yönetimi ile kullanıcının kendi rezervasyonu ayrı girişlerde. Belirsiz ağ tekrarında aynı operation ID korunuyor.
- Hakem canlı olay/rapor işlemleri ve federasyon atama/rapor/tesis tahsisi mevcut dar rol kapılarını koruyor; private ret notları il temsilcisine açılmıyor.

## Faz 4 gözlemleri

- Doğrulanan profesyonel işler App sosyal menüsünde yinelenmiyor; Pro ana işlem noktası.
- App'te başvuru/belge, aidat durumu, bireysel antrenman, sporcu/veli sonucu gibi öz-servis girişleri korunuyor.
- Eski profesyonel rotalar bildirim ve deep link uyumluluğu için registry'de; ortak host rol/feature kapısını yeniden çalıştırıyor ve boş ekrana düşmüyor.
