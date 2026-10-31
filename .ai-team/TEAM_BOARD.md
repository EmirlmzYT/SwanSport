# SwanSport AI Team Board

Son güncelleme: 2026-10-31 Europe/Istanbul  
Aktif Writer: yok  
Durum: `free`

## Açık / devam eden işler

- SwanSport Pro Faz 2 kaynak kabulü tamam; operasyonel kabul için fiziksel rol/cihaz UAT bekliyor.
- iOS APNs kabulü ve fiziksel Android/iPhone doğrulaması dış bağımlılık olarak açık.
- Cloudflare ön koşullu push-ledger doğrulaması açık; tamamlanmadan Faz 2 operasyonel `complete` sayılmaz.
- Staging/production dışı ortamlarda gerçek cihaz ve hesaplı kabul yalnız yetkili ortam/hesaplarla yapılmalı.

## Verilmiş kritik kararlar

- `apps/swansport_pro`, ortak Supabase/Auth ve tek `SwanAccess` otoritesi kullanan ayrı Flutter istemcisidir.
- Pro ortam bootstrap'ı fail-closed çalışır; bilinen production referansı dışındaki hedefler kabul edilmez.
- Kullanıcı/şifre kopyalanmaz; production ve staging kimlik verileri ayrıdır.
- Ana SwanSport uygulamasının Ana Sayfası ve mevcut davranışı Pro çalışmalarıyla değiştirilmez.
- Yetki kaynağının yükleme/hata durumu erişim izni gibi yorumlanmaz; erişim reddi fail-closed kalır.
- Preview paketleri imzasız olabilir; TestFlight, mağaza yayını, canlı SQL ve production deploy ayrı açık yetki gerektirir.

## Bilinen engeller

- Yerel Android SDK/Xcode ve fiziksel cihaz bulunmaması cihaz kabulünü engelliyor.
- APNs/SMS/push gibi sağlayıcı kabulü gerçek yapılandırma ve fiziksel cihaz gerektiriyor.
- Canlı hedefte migration veya deploy yapılması, kullanıcıdan açık yetki ve hedef doğrulaması gerektirir.

## Ortak Writer sözleşmesi

- Başlangıçtaki kullanıcı değişikliklerini ve Git çalışma durumunu koru; kapsam dışı değişiklik yapma.
- Supabase çağrılarını veri katmanında tut; erişim kararlarında yalnız `SwanAccess` kullan.
- Yetkilendirmeyi RLS veya korumalı RPC ile uygula; doğrulanmamış erişim ya da veri yazımı açma.
- Gizli değerleri, cihaz kayıtlarını, kullanıcı bilgilerini veya kimlik bilgilerini panoya/repoya kopyalama.
- Gerçek cihaz, canlı SQL, deploy veya dış servis kabulünü yapılmadıysa yapılmış gibi raporlama.
- Doğrulama ve kabul sınırlarını açık yaz; biten işlerin ayrıntılarını arşivde bırak.
