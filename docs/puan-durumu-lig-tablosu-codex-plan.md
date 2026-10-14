# SwanSport — Canlı Puan Durumu & Lig Tablosu Motoru Uygulama Planı (Codex)

**Hedef:** Resmi liglerin (`organizations.official = true` ve `is_public = true`) ve amatör turnuvaların güncel puan durumunu, tamamlanmış maç revizyonlarından ve opsiyonel olarak devam eden canlı maçlardan anlık hesaplayarak mobil ve konsol arayüzlerine sunmak.

---

## 1. Mimari Prensipler & Değişmezler (AGENTS.md)

1. **Widget'tan doğrudan Supabase çağrılmaz:** Tüm sorgular `packages/swansport_data` servis ve Riverpod sağlayıcılarından geçer.
2. **`swansport_data` saf Dart kalır:** `Color`, `IconData` veya Flutter arayüz tipleri veri katmanına giremez.
3. **Açık Tip Deklarasyonu:** Tüm Riverpod sağlayıcıları (`Provider<T>`, `AutoDisposeFutureProvider<T>`, `FutureProviderFamily<T, A>`) açık tip deklarasyonuyla yazılır; tip çıkarımı döngü hatası (`circularity found during type inference`) engellenir.
4. **Resmi Sonuç Önceliği:** Puan durumu, tamamlanmış maçlarda `org_result_revisions` içindeki resmi onaylı protokolden (`score` veya `sets`) hesaplanır. Canlı puan durumu seçildiğinde (`p_include_live = true`), `match_live_events` üzerindeki anlık skorlar sanal olarak eklenir.
5. **Tasarım Jetonları:** Yalnızca `SwanType`, `SwanPalette`, `SwanShape` ve `SwanSpace` kullanılır; ham font boyutu ve ham hex kod yasaktır.

---

## 2. Adım Adım Uygulama Aşamaları

### 🔴 Adım 1: Veritabanı Motoru (`supabase/migrations/0117_league_standings_engine.sql`)

1. **`public_league_standings(p_org_id uuid, p_include_live boolean default false)` RPC:**
   - Organizasyonun resmi ve kamuya açık olduğunu doğrular (`official = true` ve `is_public = true` veya `not official`).
   - Katılımcı takımları listeler (`org_participants` + `clubs`).
   - Tamamlanan maçları (`status = 'played'`) güncel resmi sonuç protokolünden çeker.
   - Eğer `p_include_live = true` ise, o an oynanmakta olan maçların skorlarını (`_referee_state` mantığıyla) sanal olarak tabloya ekler.
   - Çıktı Tablosu:
     - `rank`: Sıralama pozisyonu (1, 2, 3...)
     - `participant_id`: Katılımcı UUID
     - `participant_name`: Takım adı
     - `club_id`, `club_name`, `club_logo`: Kulüp bilgileri
     - `played` (O): Oynanan maç sayısı
     - `won` (G): Galibiyet sayısı
     - `drawn` (B): Beraberlik sayısı
     - `lost` (M): Mağlubiyet sayısı
     - `goals_for` (A): Atılan gol / sayı
     - `goals_against` (Y): Yenen gol / sayı
     - `goal_diff` (AV): Averaj
     - `points` (P): Puan (Futbol: 3/1/0, Basketbol: 2/1/0, organizasyon kuralına göre)
     - `form`: Son 5 maçın sonucu (`jsonb` dizi: `['W', 'D', 'L', 'W', 'W']`)
   - Sıralama: `points desc, goal_diff desc, goals_for desc, participant_name asc`.
2. **Yetkilendirme:**
   - `revoke all on function public.public_league_standings(uuid, boolean) from public, anon, authenticated;`
   - `grant execute on function public.public_league_standings(uuid, boolean) to anon, authenticated;`
3. **Özellik Bayrağı & SSS:**
   - `league_standings` ('admins', 'Canlı Puan Durumu & Lig Tablosu') bayrağı.
   - SSS kaydı `117` sıralamasıyla senkronize edilir.

---

### 🔵 Adım 2: Ortak Veri Katmanı (`packages/swansport_data`)

1. **Saf Modeller (`packages/swansport_data/lib/src/league_standings_models.dart`):**
   - `LeagueStandingsRow`: `rank`, `participantId`, `name`, `clubId`, `clubName`, `clubLogo`, `played`, `won`, `drawn`, `lost`, `goalsFor`, `goalsAgainst`, `goalDiff`, `points`, `form` (`List<String>`).
   - `LeagueStandingsTable`: `orgId`, `sportCode`, `isLive`, `rows` (`List<LeagueStandingsRow>`).
2. **Servis (`packages/swansport_data/lib/src/league_standings_service.dart`):**
   - `LeagueStandingsService(this.client)`
   - `Future<List<LeagueStandingsRow>> fetchStandings(String orgId, {bool includeLive = false})`
3. **Açık Tipli Riverpod Sağlayıcıları:**
   - `final Provider<LeagueStandingsService> leagueStandingsServiceProvider = Provider<LeagueStandingsService>(...);`
   - `final AutoDisposeFutureProviderFamily<List<LeagueStandingsRow>, ({String orgId, bool includeLive})> leagueStandingsProvider = FutureProvider.autoDispose.family<...>(...);`
4. **Export:** `packages/swansport_data/lib/swansport_data.dart` içine eklenir.

---

### 🟣 Adım 3: Mobil ve Konsol Arayüzleri

1. **Mobil Puan Durumu Bileşeni (`apps/swansport_app/lib/features/live_match/presentation/league_standings_view.dart`):**
   - Atletik, responsive lig tablosu.
   - Sütunlar: `#`, `Takım`, `O`, `G`, `B`, `M`, `AV`, `P`, `Son 5`.
   - Form rozetleri: Mini yeşil `G`, gri `B`, kırmızı `M` noktaları/rozetleri.
   - Vurgulama: İlgili maçtaki takımlar tabloda parlak tema rengiyle (`accentSoft`) vurgulanır.
   - Şalter: `Resmi Sonuçlar` ↔ `Canlı Puan Durumu 🔴` (anlık maç skorlarını ekleyerek sıralar).
2. **Canlı Maç Detay Ekranı (`live_match_detail_screen.dart`):**
   - Sekme çubuğuna 3. sekme eklenir: `['Olay Akışı', 'Kadrolar', 'Puan Durumu']`.
   - Kullanıcı maçı izlerken tek dokunuşla canlı puan durumunu ve takımının ligdeki yerini görür.
3. **Canlı Skor Merkezi (`live_match_hub_screen.dart`):**
   - Üst sekmeler: `['Canlı 🔴', 'Günün Maçları', 'Bitenler', 'Puan Durumu']`.
   - Puan durumu sekmesinde lig seçici açılır menü (`Dropdown`) ile ligler arasında geçiş yapılır.
4. **Masaüstü Konsol (`apps/swansport_console`):**
   - `/il-ligleri` (`provincial_leagues_screen.dart`) ekranına `[ Fikstür & Maçlar | Puan Durumu ]` sekmesi eklenir.

---

### 🟢 Adım 4: Testler & Doğrulama

1. **SQL Regresyon Testi (`tools/league_standings_sql_test.mjs`):**
   - Resmi maç sonuçlarının puan tablosuna (3/1/0 puanlama) doğru yansıdığının testi.
   - Averaj ve atılan gol eşitliğinde doğru sıralama testi.
   - `p_include_live = true` olduğunda devam eden maç skorunun sanal olarak sıralamayı etkilediğinin testi.
   - Anonim ve kimlikli kullanıcıların güvenli erişim testi; kapalı/gizli liglerin sızmadığının kanıtı.
2. **Kalite Araçları:**
   - `python tools/check_migrations.py`
   - `python tools/check_faq.py`
   - `python tools/check_push_routes.py`
   - `python tools/check_mobile_ui_tokens.py`
   - `packages/swansport_data/test/feature_flag_sync_test.dart`
