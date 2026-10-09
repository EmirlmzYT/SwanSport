# Mali düzeltme doğrulaması — 2026-10-07

0085, uygulamanın gönderdiği `p_id`, `p_approve`, `p_note` parametrelerini
tek `approve_finance_adjustment(uuid, boolean, text)` imzasında birleştirir.
Eski iki parametreli aşırı yükleme kaldırılır. Muhasebeci talep açabilir;
onay ve ret kulüp personeline aittir. Platform yöneticisi olmak kendi
talebini onaylama yasağını kaldırmaz.

Oluşturma ve onay önce kaynak hareketi, ardından gerekiyorsa düzeltme
satırını kilitler. Tutar pozitif, sonlu ve kuruş hassasiyetinde olmalıdır.
Bekleyen talepler kapasiteyi ayırır; onaylı kayıtların bağlı defter hareketi
gerçekten mevcut olmalı, aynı kulüp/kasa/tutar ve doğru yön/durum taşımalıdır.
Eksik, negatif, eşleşmeyen, birden çok düzeltmeye bağlanan veya toplamı kaynak
tutarını aşan geçmiş hareketler yeni iadeye kapasite sağlayamaz.

0082 ve 0084 içindeki otomatik geçmiş telafi blokları kaldırıldı. Migration
geçmiş para hareketi üretmez, silmez veya tutarını değiştirmez. Daha önce
uygulanmış 0084 bulunan veritabanı için ileri düzeltme 0085'tir; geçmiş
migration dosyalarını tekrar uygulamak gerekmez.

İnceleme listesi, yetkili kullanıcının oturumuyla
`get_finance_adjustment_reconciliation_issues(p_club_id)` üzerinden alınır.
Eksik ve negatif kayıtları; ayrıca dolu fakat geçersiz defter bağlantılarını
ve gerçekleşmiş toplam aşımını raporlar. Onay durumunu gerçek ödeme kanıtı
saymaz. Hatalı eski kayıtların nasıl düzeltileceği gerçek mali belgelerle
belirlenmelidir; uygulama bunlar için otomatik para hareketi yazmaz.

## Tekrarlanabilir yerel test

```powershell
npm install --prefix build/finance-sql-tests --no-audit --no-fund @electric-sql/pglite@0.5.8
node --test tools/finance_rpc_test.mjs
python tools/check_migrations.py
```

Test, migration dosyalarındaki gerçek SQL/PLpgSQL fonksiyonlarını izole,
bellekte çalışan PostgreSQL motorunda çalıştırır. 0079 → 0082 → 0084 → 0085
mali zincirini ve yalnızca 0085 ile ileri düzeltmeyi dener. Yetki yardımcıları
ve bağımlı tablolar kontrollü fixture'dır; tüm Supabase şemasının veya canlı
RLS yapılandırmasının doğrulandığı anlamına gelmez. Yetkisiz onay, kendi
talebini onaylama, tekrar onay, toplam sınırı, bağlı hareketin doğrulanması,
geçmiş kayıtların korunması, arama/sayfalama, yetkili kulüp incelemesi ve
denetim hatasında atomik geri alma kontrol edilir.

PGlite tek bağlantı kullanır. Kilit sırası kaynakta düzeltilmiştir; iki ayrı
PostgreSQL oturumunda eşzamanlı kilit yarışı bu koşuda sınanmadı. Canlı
migration, dağıtım ve gerçek hesaplı UAT yapılmadı.
