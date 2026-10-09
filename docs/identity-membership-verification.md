# Faz C1 — kimlik ve üyelik kapısı

2026-10-09. Yerel sunucu/veri katmanı uygulaması; ekran, konsol, hesap silme ve antrenör okuma RLS daraltması yapılmadı. Push, deploy ve canlı SQL çalıştırılmadı.

## Sözleşme

- 0099 mevcut `credential_kind` enum'una `identity` ekler. 0100 mevcut `profile_credentials` içinde `verified_national_id` tutar; ikinci tablo veya belge deposu yoktur. `verification_documents` ve mevcut yükleme yolu kullanılır.
- `profiles.national_id`, rol ve platform yöneticiliği kimlik doğrulaması değildir. Yeni kimlik yalnız platform yöneticisinin mevcut `review_credential` RPC'siyle, başvuru sahibinin kimlik belgesi referansı ve incelenmiş TCKN ile onaylanır. Bu insan incelemesidir; nüfus kayıt servisi entegrasyonu değildir.
- Doğrulanmış TCKN tekildir ve sonradan değiştirilemez. Ret sonrasında da hesap anahtarı korunur. Eski beyanlar taşınmaz, birleştirilmez veya unique yapılmaz. Doğrudan belge inceleme UPDATE/DELETE ve kullanıcı tarafından platform yöneticisi olma yolu kapalıdır.
- Yeni aktif üyelik, takım/antrenör ataması ve resmi kadro için kimlik ve aynı branşta geçerli onaylı belge aranır. Yeni spor belgesi onayında bitiş tarihi zorunludur; eski onaylı NULL bitiş tarihleri geçerlidir. Tarihler Türkiye takviminde değerlendirilir.
- Geçiş hakkı yalnız migration anında aktif mevcut üyeliklere bir defa işaretlenir. Başka kulübe taşınmaz, tekrar uygulamada genişlemez; yeni rol/takım/yetki veya yeniden aktifleştirme yeni kapılara tabidir. Eski üyelerin giriş/okuma akışı ve mevcut yetkileri kaldırılmaz.
- Veli için lisans gerekmez: doğrulanmış kimlik ve kulüp yetkilisinin geçerli davetini tüketmiş olmak gerekir. Eski veli bağlantıları bir defalık korunur; yeni çocuk üyeliği için velinin kimliği yine doğrulanmış olmalıdır. Çocuk/bilinmeyen doğum tarihi, bağlı sporcu kaydı üzerinden denetlenir. Eski hesap bağlama RPC'leri de tetikleyiciden geçer.
- `athletes.profile_id` nullable kalır. Hesapsız sporcu takım/resmi kadro yazımında mevcut branş tescili ve çocuk için doğrulanmış veli aranır. Eski aktif sporcu üyeliği muafiyeti yalnız mevcut kulübün ana branşını kapsar.
- Mevcut `create_club` imzası branş parametresi taşımadığından, doğrulanmış kimlik ve geçerli en az ikinci kademe branş belgesiyle kurucunun kendi bekleyen kulübüne ilk yönetici üyeliği kurulabilir. Bu özel kurulum yolu yeni bir legacy muafiyeti üretmez.
- `create_club`, `apply_to_club`, `offer_to_person`, `review_club_application`, `create_guardian_invite`, `redeem_invite_code` ve `federation_publish_roster` aynı adlarla korunur. Doğrudan tablo yazıları da tetikleyicilerle denetlenir; kopya RPC yoktur. İnceleme overload'ları kaldırılarak tek imza bırakılır.
- `my_identity_gate` yalnız kullanıcının kimlik durumunu ve eski kulüp geçiş kapsamını döndürür. Dart `SwanAccess` bu durumu kullanır; genel profil yüküne doğrulanmış TCKN eklenmez. Giriş/oturum yönlendirmesi değişmez.
- Resmi sonuç, lisans ve derece için federasyon görevi zorunluluğu korunur; platform yöneticisi bypass değildir. Sağlık kısıtları ve muhasebe RPC maskeleri değiştirilmez. Muhasebecinin doğrudan sporcu tablosu erişimi ve sportif personel yetkisi açılmaz.

## Migration sırası ve şema çakışması

0099 ve 0100 **ayrı işlemlerde** uygulanmalıdır: yeni enum değeri onu ekleyen işlem içinde kullanılamaz. Her dosyada 15 saniye lock timeout vardır. Bu oturumda yalnız izole yerel veritabanına uygulandı.

0009 geçmişte `athletes.club_id` NOT NULL kısıtını kaldırmış. C1 bunu tekrar NOT NULL yapmadan önce kulüpsüz eski satır arar. Varsa 0100 bütünüyle geri alınır; satır silinmez, sahte kulüp atanmaz. Gerçek ortamda böyle satırlar varsa kullanıcı kararıyla incelenmeden migration uygulanamaz. Bu ön kontrolün atomik başarısızlığı test edildi.

Yeni kimlik/expiry arayüzleri bu fazın kapsamında değildir. Mevcut başvuru ekranlarının expiry alanına bağlanması önceki Faz A yayın bağımlılığı olarak durur. Backend'in yerelde geçmesi tek başına tam ürünün canlıya hazır olduğu anlamına gelmez.

## Kanıt

| Kontrol | Sonuç |
|---|---|
| `node --test tools/identity_membership_sql_test.mjs` | 34/34: 18 C1 + import edilen 16 Faz A |
| `node --test tools/federation_public_sql_test.mjs` | 28/28: misafir okuma ve çocuk adı dahil |
| Ortak veri katmanı Flutter testleri | 343/343; yeni 7 kimlik testi dahil |
| Uygulama Flutter testleri | 290/290 |
| Konsol Flutter testleri | 46/46 |
| Değişen iki Dart kaynak dosyası ve yeni testin analizi | 0 bulgu, çıkış 0 |
| 0099/0100 PostgreSQL sözdizimi ve `git diff --check` | Başarılı |

Loglar yerel, ignored `build/identity-phase-c1/` altındadır: `sql-final.log`, `public-regression.log`, `data-full.log`, `app-full.log`, `console-full.log`, `analyze-final.log`.

SQL testleri PGlite PostgreSQL üzerinde gerçek eski RPC gövdeleri ve yeni migration'ları çalıştırır. Auth rolleri fixture içinde simüle edilir; yardımcı muhasebe/saha tabloları minimaldir. Bütün Supabase migration zinciri, canlı PostgREST/Storage ve gerçek hesaplı UI testi değildir. Kimlik/branş/veli kanıtları yazma işlemi boyunca satır kilidiyle tutulur; iki gerçek eşzamanlı PostgreSQL oturumu testi ayrıca gerekir.

Kod grafiği SQL/tools dizinlerini dışlıyor ve değişen Dart kaynaklarında güncel değildi; sonuçlar doğrudan kaynak okumaları ve davranış testleriyle doğrulandı. Önceden raporlanan authenticated `athlete_public` görünümü, kulüp geneli antrenör okuma yetkisi ve hesap/Storage silme yaşam döngüsü riskleri C1 ile kapatılmış sayılmaz; sonraki kapsamda kalır.
