# Spor rolleri — Faz 2 yerel doğrulama

2026-10-13. Kullanıcı 0111 dar RPC ekini açıkça onayladı. Canlı migration,
commit, push, deploy veya Faz 3 mobil kokpit bu işte yapılmadı.

## Sözleşme

- `0111_match_lineup_projection.sql`: ilk satır 15s yerel lock timeout;
  `match_approved_lineups(uuid)` tek imza, sekiz açık çıktı kolonu. Sabit
  search_path, authenticated-only EXECUTE, null auth reddi. Kaynak tablo
  grant/RLS değişikliği yok. Eski `_sports_approval_read` ile her katılımcı
  ayrı süzülür: kulüp yalnız kendi tarafını görür. Hakem yolu ayrıca kabul
  edilmiş/aktif/doğru branş gerektirir; federasyon/il kapsamı korunur.
  Yetkisiz ve bulunmayan maçlar boş döner, varlık farkı açıklanmaz.
- `sports_roles_models.dart`: yedi saf Dart model; snake_case enum eşlemesi,
  bilinmeyen enumda kapalı hata; revocation ve Türkiye gün sınırından rol
  etkinliği. `FederationRole.isActive` SQL'de olmayan bir kolon beklemez.
  Esame dizileri savunmalı immutable kopyadır; silinen onaylayan profil
  `verifiedBy == null` olabilir. TC, veli telefonu, tıbbi teşhis taşınmaz.
- `sports_roles_service.dart`: kendi profil ID'siyle rolleri/sicili okur;
  atama ve esame yazıları gerçek 0110 RPC parametrelerini kullanır. Başarılı
  yazıdan sonra maç/approval/accepted provider'ları invalidate edilir;
  başarısız yazı başarı gibi bildirilmez. Verisiz fixture rol üretmez.
- 0111'in sekiz kolonuna yapay `id` eklenmez. Modelin gerçek `id` alanı
  `match_lineup_approvals.select('id,participant_id')` üzerinden mevcut RLS
  ile alınır; RPC satırlarıyla kesiştirilir. Ham resmi maç tablosu okunmaz.
- Özel provider'lar auth session'a bağlıdır; çıkış/hesap değişiminde yeniden
  değerlendirilir. `SwanAccess` yeni yükleme/hata durumunda eski rol değerini
  yetki olarak kullanmaz (`asData`); rol süreleri getter'da da kontrol edilir.
- Başkanın il/kurul görünürlüğü devralması rol hiyerarşisidir; scoped
  `isProvincialRep(..., federationId: ...)` başka federasyona geçmez.
  Genel göstergeler branch yazma kapısı değildir; `canWriteFederation` ve
  eski resmi sonuç görevleri değiştirilmedi. Yeni role-only bir yetkiyle
  sonuç/lisans yazma açılmaz; sunucu her operasyonun son otoritesidir.
- Doktor/physiotherapist yalnız etikettir. Gerçek sağlık kulübü kümesi
  mevcut `is_authorized_health_officer(p_club)` RPC'sinden gelir (izin,
  iptal, aktif üyelik). İdari dinlenme aktif coach/admin kulübü için
  bağımsızdır, sağlık personeli yokluğunda kapanmaz. Bu gösterge tıbbi veya
  disiplin kilidini temizleme yetkisi değildir. Muhasebecilik ayrı eksendir;
  bu servis sporcu adlarına abone olmaz, `acc_*` sözleşmesi değişmedi.

## Doğrulama

- `node --test tools/sports_role_hierarchy_sql_test.mjs`: **55/55 geçti**;
  52 mevcut + 3 yeni gerçek PostgreSQL/PGlite fixture senaryosu. ACL, null
  auth, kabul/aktif hakem, il/branş/iptal, muhasebeci/admin reddi, home/away,
  kendi kulüp tarafı, sekiz kolon, replay ve veri korunması test edildi.
- `python tools/check_migrations.py`: **111 migration parse başarılı**.
- `python tools/check_faq.py`: **39/39 özellik yardımı mevcut**.
- `python tools/check_push_routes.py`: **40 eşleme, kayıp yok**.
- `node tools/platform_mission_control_sql_test.mjs`: **5/5 mevcut regresyon geçti**.
- Yedi değişen/yeni Dart dosyası tree-sitter ile sözdizimi kontrolünden geçti.
- Üç Dart regresyon dosyasında **25 test hazır**: model serileştirme/
  değişmezlik, hiyerarşi/süre/kulüp/doctorless/accountant, provider bağlantısı,
  HTTP RPC parametreleri/ID-side projeksiyonu/hata/oturum çıkışı.
- `git diff --check`: temiz.

**Sınır:** Flutter/Dart SDK bu makinede bulunamadı; `flutter test` ve
`flutter analyze` çalıştırılamadı. Tree-sitter parse, Dart tip denetimi veya
test çalışması değildir. Gerçek PostgREST, canlı iki hesap/oturum, cihaz UAT
ve üretim build yapılmadı. Faz 3 öncesinde SDK bulunan ortamda şu komutlar
çalıştırılmalı:

```powershell
flutter test test/sports_roles_access_test.dart test/sports_roles_test.dart test/sports_roles_service_test.dart
flutter test
flutter analyze
```

Komutlar `packages/swansport_data` dizinindendir. Sağlık/rol atamaları başka
bir yönetici tarafından değiştiğinde tüketici ilgili provider'ları
invalidate etmeli; bu faz arka plan realtime/polling aboneliği eklemez.
