# Spor rol hiyerarşisi — Faz 1 / 0110

13 Ekim 2026; yerel şema ve gerçek izole PostgreSQL doğrulaması.
Kullanıcının ek onayıyla açık SELECT politikaları ve turnuva kadrosuna yazan
örnek RPC yerine kapsamlı RLS ve ayrı maç-esame onayı uygulanır.

## Şema ve yetki

Altı yeni tablo: federation_roles, referee_profiles, match_officials,
club_staff_roles, org_match_lineup_notes, match_lineup_approvals.
İlk satır lock_timeout=15s; CREATE TABLE/INDEX IF NOT EXISTS kullanılır.
Tekrar uygulamada politikalar/tetikleyiciler önce düşürülür, fonksiyonlar
CASCADE olmadan yeniden kurulur; veri silinmez.
Canlı uygulama yapılırsa dosya ayrı bir BEGIN/COMMIT işlemi içinde yürütülmelidir;
SET LOCAL timeout ancak o işlem içinde geçerlidir. Bu görev canlı uygulamaz.

| Kaynak | Authenticated okuma | İstemci yazısı |
| --- | --- | --- |
| federation_roles | Kendi kayıtları; aynı branş başkanı | Yok |
| referee_profiles | Kendi sicili; branş/il yetkili başkan/temsilci/MHK | Yok |
| match_officials | Kendi ataması ve mazereti; branş/il kapsamlı başkan/temsilci/MHK | Yalnız respond_match_assignment |
| club_staff_roles | Kendisi; ilgili kulübün sportif/sağlık personeli | Yok |
| org_match_lineup_notes | Kendi kulübünün sportif/sağlık personeli; atanmış aktif branş hakemi; kapsamlı federasyon personeli | Yalnız set_match_lineup_note |
| match_lineup_approvals | Kendi tarafının kulüp personeli; ilgili hakem/federasyon görevlisi | Yalnız referee_verify_lineup, ardından immutable |

Salt üyelik, muhasebecilik, platform yöneticiliği veya ihtisas etiketi sportif
erişim sağlamaz. Rol/sicil/atama/ihtisas kayıtlarının yönetim yazma RPC'leri
sonraki fazdadır; bu fazda yalnız güvenilir yönetim SQL'iyle oluşturulabilirler.
Eski federation_appointments ve görev bazlı resmi sonuç/lisans RPC'leri değişmez;
başkan etiketi bu eski yazıcılara otomatik bypass vermez.

Anon'un yeni tablolara SELECT veya yazma izni yoktur. Tek yeni genel yüzey
accepted_match_officials(match): yayımlanmış resmi programda **yalnız kabul
edilmiş hakemin adı ve görevi**. İlgili kulüp personeli aynı dar projeksiyonu
yayımlanmamış maçında da kullanabilir. Atama/profil UUID, sicil, ret gerekçesi,
telefon ve kimlik numarası bu yüzeye girmez. Genel kullanıma izin verilen bu
projeksiyon kullanıcı tarafından açıkça yetkilendirildi.

RLS predikatları kaynak resmi tabloların eski kapalı SELECT politikasına
takılmamak için security-definer boolean yardımcıları kullanır. Bunların
EXECUTE izni RLS değerlendirmesi için authenticated'a açıktır; yalnız yetki
boolean'ı döner. Kadro doğrulayıcı ve mutation trigger yardımcıları istemciye
kapalıdır. Tüm definer fonksiyonlarında sabit public,pg_temp search_path vardır.

## Esame ve RPC sözleşmeleri

- İstenen is_federation_president, is_provincial_rep, is_match_official ve
  my_referee_matches oluşturuldu. Başkan branşında ülke geneli; temsilci yalnız
  kendi ili; tarih/iptal kontrolü Türkiye takvimiyle yapılır.
- respond_match_assignment yalnız kendi atamasını yanıtlar; NULL yanıt,
  kapanmış/değiştirilmiş görev ve yanlış/pasif hakem branşı reddedilir.
  Tekrarlanan kabul responded_at'ı değiştirmez; esame kilitliyken geri alınmaz.
- referee_verify_lineup yalnız kabul edilmiş, aktif ve aynı branştaki
  başhakem/masa hakemi için çalışır. Altı parametreli **tek imza** vardır:
  match_id, home_roster, away_roster, notes=null, home_substitutes={},
  away_substitutes={}. Eski dört argümanlı kullanım varsayılanlarla çalışır.
- Diziler starter/substitute olarak ayrıdır; NULL/boş starter, tekrar eden
  veya iki tarafta görünen sporcu, yanlış kulüp/takım, yayımlanmamış kadro,
  bitmiş branş lisansı, C1/veli şartı, tıbbi/idari/ceza kısıtı yeniden denetlenir.
  Branşa özel “ilk 11/ilk 5” sayıları bu fazda uydurulmaz; ortak sınır 1–200'dür.
- Her iki tarafın doğrulaması, maç onayları ve federation_audit aynı işlemde
  yazılır. Başarısız deplasman veya audit yazısı ev sahibi onayını da geri alır.
- match_lineup_approvals roster_revision_id'yi referans alır; UUID dizileri
  dayanıklıdır, ad/sağlık snapshot'ı yoktur. org_roster_revisions'a INSERT,
  UPDATE veya DELETE yapılmaz. Sonraki turnuva kadrosu bu maç kartını değiştirmez.
- Onay UPDATE/DELETE/unlock edilemez; maçın tarafları da değiştirilemez.
  Hesap silme yalnız verified_by FK'sini NULL yapabilir, onay korunur.
- referee_lineup_card yalnız kabul edilmiş aktif maç görevlisine side, ad,
  forma no, lisans no ve bitiş tarihi döndürür. TCKN, veli telefonu, doğum tarihi,
  atlet/profil UUID ve sağlık notları yoktur. Çocuk/bilinmeyen doğumda güncel veli
  izin/ret sözleşmesi korunur; izin yoksa ad NULL olur.

Maç bazlı advisory kilidi, maç/atama/katılımcı/kadro ve ilgili yetki satır
kilitleri vardır; aktör hesabı FK yazılarından önce kilitlenir. Bunlar canlı
çok-oturum UAT yapılmış olduğu anlamına gelmez.

## Doktor esnekliği

club_staff_roles doctor/physiotherapist etiketi sağlık yetkisi yerine geçmez.
Mevcut club_staff_permissions.can_verify_medical + iptal edilmemiş izin + aktif
kulüp üyeliği, is_authorized_health_officer üzerinden otoritedir.

Doktorsuz kulüpte yönetici/antrenör injured_admin veya rested koyup kaldırabilir.
Yetkili sağlık personeli varsa sakatlık için injured_admin yerine tıbbi akış
gerekir; rested normal idari dinlenme olarak kalır. injured_medical durumunu
yalnız yetkili sağlık görevlisi değiştirebilir. Mevcut health_restrictions kilidi
eligible notuyla kaldırılamaz; önce eski sağlık RPC'si ve zorunlu gerekçe gerekir.
Doktor ayrıldığında mevcut tıbbi kilit otomatik silinmez. Suspended yalnız
branş/il kapsamlı federasyon/disiplin yetkisiyle değişir. Serbest not yalnız
operasyonel gerekçe içindir; teşhis/rapor/telefon/TCKN saklanmamalıdır.
Tıbbi kilit ↔ disiplin durumu dönüşümünde iki yetki de bağımsız denetlenir;
bir durumun adı diğer kilidin yetki kontrolünü atlatamaz.

## Doğrulama ve sınırlar

tools/sports_role_hierarchy_sql_test.mjs gerçek temel, sağlık, C1 ve 0103/0104
migration'ları üzerinde 0110'u çalıştırır. Önceki fixture'ın sağlık stub'ı gerçek
0064 şeması/RPC'leriyle değiştirilir; 0104 test fixture'ı yalnız export edilmiştir.

Yeni kapsam senaryoları: rol tarihi/iptali/il/branş; muhasebeci/yanlış il/kulüp
RLS; özel ret bilgisi/genel kabul projeksiyonu; NULL yanıt; başhakem/masa sınırı;
dizi ve C1 doğrulaması; klinik/ceza kilidi; çocuk rızası; ayrı yedek snapshot'ı;
deplasman gizliliği; audit rollback; tekrar migration; ACL ve tek imza.

Son geniş koşu: **52/52** (13 yeni 0110 + 39 mevcut federasyon/C1/0104).
Migration ayrıştırması 110/110, SSS 39/39, push 40 eşleme ve diff temiz.
İlk koşulardaki zaman nesnesi karşılaştırması, zorunlu sağlık kaldırma gerekçesi
ve C1 aktör kimliği test fikstürlerinde düzeltildi; mevcut güvenlik kuralları
gevşetilmedi. Tıbbi/disiplin çapraz geçişi ayrı olumsuz testlerle kapatıldı.

Komutlar:

```bash
node --test tools/sports_role_hierarchy_sql_test.mjs
python tools/check_migrations.py
python tools/check_faq.py
python tools/check_push_routes.py
git diff --check
```

check_migrations **yalnız ayrıştırıcıdır**, kilit/RLS/idempotentlik uygulamaz;
bu davranışlar yeni gerçek SQL testleriyle ayrıca denetlenir. SSS bayrağı veya
rota eklenmedi; mevcut 39 yardım/40 push eşlemesi korunur.

Faz 2 Dart modelleri/SwanAccess/provider'ları, hakem ekranları, canlı skor,
disiplin yönetim UI'sı ve mevcut resmi sonuç yazıcısının yeni maç onaylarını
tüketmesi henüz uygulanmadı. Eski sonuçların frozen roster davranışı değişmez.
Yeni esame onayı eski sonuç RPC'sini kendiliğinden zorunlu onay kapısına çevirmez.
Gerçek PostgREST, iki eşzamanlı üretim oturumu, cihaz/kokpit UAT ve canlı migration
yoktur. Kullanıcının iki taslak mimari dosyası değiştirilmedi.
Yalnız görev dosyaları stage edildi; commit/push/deploy yapılmadı.
