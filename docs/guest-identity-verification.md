# Misafir gezinti ve kimlik kapısı — yerel doğrulama

2026-10-10. Ürün kodu ve aşağıdaki testler yerelde doğrulandı. Canlı migration, push, deploy ve hesaplı cihaz/tarayıcı UAT yapılmadı.

## Davranış

- Tanıtım korunur. Oturumsuz açılış daha sonra misafir keşfine gider; giriş/kayıt seçeneği görünür. Sahte veya anonim auth hesabı oluşturulmaz.
- Oturum değişince profil yeniden okunur. Oturumsuz erişim `SwanAccess.none` olur; eski profil önbelleği misafiri yetkilendirmez.
- Misafir keşfi haberleri, mevcut kort/saha ekranlarını ve yalnız yayımlanmış resmi faaliyet programı/fikstür RPC'lerini kullanır. Federasyon kadrosu veya özel sonuç girdileri istenmez.
- `SwanAccess.decisionFor` tek işlem kararıdır. Kulüp başvurusu, RSVP, mesaj, ilan, yayın ve rezervasyon eylemleri misafire giriş/kayıt alt penceresi açar. Pencereden dönüş işlemi otomatik tekrar etmez.
- Özel isimli ve üretilen rotalar `AccountRouteGate` ile ekran oluşturulmadan korunur. Alt menüde mesaj/profil/oluşturma girişleri de aynı kapıya gider.
- Kimliği doğrulanmamış hesabın kulüp başvurusu kimlik uyarısını gösterir ve `/dogrulama` ekranına yönlendirir. Platform yöneticiliği bu UI kararını atlamaz.
- Mevcut belge ekranında Kimlik bölümü, spor/antrenör belgesinde zorunlu bitiş tarihi vardır. Kimlik ve branş belgesi ayrı onaylardır. Bekleyen kimlik başvurusu yükleme tekrarında yeniden oluşturulmaz.
- Widget'larda yeni Supabase sorgusu yoktur. Kamu programları ve RSS kaynağı okumaları ortak veri katmanındadır. Yeni UI mevcut tasarım jetonlarını kullanır; dar ekran alt menü taşması da giderildi.

## Sunucu ve kurulum bağımlılığı

0097/0098 yayımlanmış program/fikstür/sonuç sınırlarını, 0099/0100 kimlik ve üyelik yazma kapılarını sağlar. Bu görev onların yetkilerini gevşetmez. 0101 yalnız aktif RSS kaynaklarının id/ad/url/active alanlarını döndüren `public_news_sources()` ve iki SSS kaydı ekler. PUBLIC execute alınır, yalnız anon/authenticated execute verilir; yeni anon tablo grant'i yoktur.

0101 henüz canlıya uygulanmadı. İlgili migration'lar kurulu olmayan ortamda haber/program veya belge işlemlerinin çalıştığı iddia edilmez. 0099/0100 kurulumundaki ayrı işlem ve eski kulüpsüz kayıt ön kontrolü koşulları `identity-membership-verification.md` içinde geçerlidir. Kimlik onayı sahte hesabı tek başına bütünüyle önleyen bir garanti değildir; sunucu kapıları ve yönetici incelemesine dayanır.

## Kanıt

Loglar `build/identity-phase-c1/guest-*.log` altında yereldir, Git'e eklenmez.

| Kontrol | Sonuç | Log |
|---|---|---|
| Uygulama `flutter test` | 304/304 | guest-app-final.log |
| Ortak veri `flutter test` | 348/348 | guest-data-final.log |
| Konsol `flutter test` | 46/46 | guest-console-final.log |
| Misafir/kimlik ve alt menü odaklı widget testleri | 20/20, yukarıdaki toplamın içinde | guest-layout-final.log |
| `node --test tools/federation_public_sql_test.mjs` | 28/28 | guest-public-sql.log |
| Kimlik SQL regresyonları | 34/34 | guest-identity-sql.log |
| `node --test tools/guest_news_sql_test.mjs` | 1/1; migration tekrar uygulama, ACL, alan ve aktiflik sınırı | guest-news-sql.log |
| Değişen 34 Dart dosyasının `dart analyze` kontrolü | 0 hata, 0 uyarı, 535 info; çıkış 0 | guest-analyze-final.log |
| Üretim web derlemesi, `main_production.dart` ve `env/prod.json` | Başarılı; çıkış 0, Wasm ön kontrolü geçti | guest-web-build.log |
| 0101 PostgreSQL parse / yardım kapsamı / diff-check | Başarılı / 39 bayrak için 39 yardım / temiz | Yerel komut çıktısı |

Web derlemesi CupertinoIcons font ailesinin asset'lerde bulunmadığı uyarısını verdi; derleme başarıyla tamamlandı. Bu görevde ikon/font bağımlılığı değiştirilmedi.

Widget testleri gerçek uygulama özel derin bağlantılarını, giriş/çıkış geçişini, iptal sonrası yazmama davranışını, altı işlem türünü, doğrulanmış başvurunun korunmasını ve 320px koyu tema/büyütülmüş metni kapsar. Veri testleri public RPC parametrelerini, anonim RSS yolunu ve eski profille oturumsuz erişimin kapalı kalmasını doğrular. SQL testleri yerel PGlite üzerinde çalışır; canlı API veya iki bağlantılı PostgreSQL yarış testi değildir.

Antrenör RLS daraltması, hesap silme yaşam döngüsü, federasyon yönetim konsolu ve ferdi kayıt bu görevde uygulanmadı.
