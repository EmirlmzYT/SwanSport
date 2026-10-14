# SwanSport — Canlı Maç & Skor Takip Merkezi Uygulama Planı (Codex)

**Hedef:** Hakem kokpitinden (`0112`) sahadan girilen anlık maç olaylarını (skor, kart, oyuncu değişikliği, periyot/set ve akan süre) velilere, sporculara, kulüp üyelerine ve taraftarlara güvenli, canlı ve yüksek kaliteli bir arayüzle sunmak.

---

## 1. Mimari Prensipler & Değişmezler (AGENTS.md)

1. **Widget'tan doğrudan Supabase çağrılmaz:** Tüm sorgular `packages/swansport_data` içindeki servis ve Riverpod sağlayıcılarından geçer.
2. **`swansport_data` arayüze bağlanmaz:** `IconData`, `Color`, widget veya Flutter tema bağımlılığı içermez.
3. **Açık Tip Deklarasyonu (Type Inference Circularity Koruması):** Tüm Riverpod sağlayıcıları (`Provider<T>`, `AutoDisposeFutureProvider<T>`, `FutureProviderFamily<T, A>`) açık tip deklarasyonuyla tanımlanır; `final x = Provider(...)` tip çıkarımına bırakılmaz.
4. **Çocuk Gizliliği & Veri Ayrımı:**
   - Hakemin özel rapor notları (`report_notes`) veya disiplin sevkleri seyirciye **asla yansıtılmaz** (yalnız hakem ve disiplin kuruluna özeldir).
   - Reşit olmayan sporcuların adları, veli izni (`guardian_child_consents`) yoksa maskeli (`Ahmet Y.` veya `#A3F91C`) olarak projekte edilir.
5. **Tasarım Jetonları:** Sadece `SwanType`, `SwanPalette`, `SwanShape` ve `SwanSpace` kullanılır; ham hex ve ham font boyutu yasaktır.
6. **İdempotent & Güvenli SQL:** `set local lock_timeout = '15s'`, `security definer`, `set search_path = public, pg_temp`, postgrest grantleri ve audit koruması.

---

## 2. Adım Adım Uygulama Aşamaları

### 🔴 Adım 1: Veritabanı Projeksiyonu (`supabase/migrations/0116_live_match_spectator_hub.sql`)

1. **`public_live_matches(p_sport text, p_city text)` RPC:**
   - Yayımlanmış resmi maçları (`org_matches` + `organizations.official = true`) listeler.
   - Durumlar: `scheduled` (bugün), `played` (son 48 saat) veya olay akışı devam edenler.
   - Çıktı: `match_id`, `sport_code`, `status`, `starts_at`, `home_club_name`, `away_club_name`, `home_club_logo`, `away_club_logo`, `home_score`, `away_score`, `period`, `is_live`, `elapsed_seconds`, `clock_started_at`.
2. **`match_public_live_state(p_match_id uuid)` RPC:**
   - `0112`'deki `_referee_state` fonksiyonunun seyirciye özel güvenli türevidir (hakem yetkisi gerektirmez; herkese ve misafire açıktır).
   - Güncel skor, periyot, set dağılımı (`sets`), akan süre (`clock_started_at` ve `elapsed_seconds`) ve filtrelenmiş olay akışı (`events`).
   - Olaylar: `kind` (`score`, `card`, `substitution`, `period_end`), `side` (`home`, `away`), `minute`, `period`, `athlete_name` (veli izinli veya maskeli), `replacement_name`.
   - **Kritik Kilit:** Hakemin `report_notes` ve `decline_reason` alanları bu projeksiyonda **kesinlikle bulunmaz**.
3. **`match_public_roster(p_match_id uuid)` RPC:**
   - Hakemin onayladığı (`match_lineup_approvals`) resmi kadroları döner.
   - Ev sahibi ve deplasman için ilk kadro (`starters`) ve yedekler (`substitutes`).
   - Forma numarası, pozisyon (varsa) ve maskeli/açık sporcu adı.

---

### 🔵 Adım 2: Ortak Veri Katmanı (`packages/swansport_data`)

1. **Saf Modeller (`packages/swansport_data/lib/src/live_match_models.dart`):**
   - `PublicLiveMatchSummary`: Maç kartı özet bilgisi.
   - `PublicLiveMatchDetail`: Canlı skor, süre, periyot ve olay listesi.
   - `PublicLiveMatchEvent`: Dakika, olay tipi (gol, kart, değişiklik), taraf ve oyuncu bilgisi.
   - `PublicMatchRoster`: Takım kadroları ve sporcular.
2. **Servis (`packages/swansport_data/lib/src/live_match_service.dart`):**
   - `LiveMatchService(this.client)`
   - `fetchLiveMatches({String? sport, String? city})`
   - `fetchPublicMatchState(String matchId)`
   - `fetchPublicMatchRoster(String matchId)`
3. **Riverpod Sağlayıcıları:**
   - `final Provider<LiveMatchService> liveMatchServiceProvider = ...`
   - `final AutoDisposeFutureProvider<List<PublicLiveMatchSummary>> publicLiveMatchesProvider = ...` (30 saniyede bir otomatik yenileme timer'ı).
   - `final AutoDisposeFutureProviderFamily<PublicLiveMatchDetail?, String> publicMatchLiveStateProvider = ...` (Canlı maç sırasında 8-10 saniyede bir self-invalidation).
   - `final AutoDisposeFutureProviderFamily<PublicMatchRoster?, String> publicMatchRosterProvider = ...`

---

### 🟣 Adım 3: Mobil Arayüz & Entegrasyon (`apps/swansport_app`)

1. **Ana Akış (Feed) Canlı Maç Bandı (`feed_screen.dart`):**
   - Eğer o anda aktif oynanan resmi bir maç varsa (`is_live == true`), akışın üstünde dikkat çeken atletik bir canlı maç kartı gösterilir:
     `[ 🔴 CANLI · 64' ] Galatasaray 2 - 1 Fenerbahçe (Futbol · U16 İl Ligi)`
   - Dokunulduğunda doğrudan `/canli-mac/:id` rotasına gider.
2. **Canlı Maç & Skor Merkezi (`live_match_hub_screen.dart` — `/canli-skor`):**
   - Üst Bar: `SwanSegmentedTabs` (`Canlı 🔴`, `Günün Maçları`, `Sonuçlananlar`).
   - Branş Filtre Çipleri (Tümü, Futbol, Basketbol, Voleybol, Tenis).
   - Canlı maç kartları (kulüp logoları, büyük skor, dakika/periyot rozeti, saha adı).
3. **Canlı Müsabaka Detay Ekranı (`live_match_detail_screen.dart` — `/canli-mac/:id`):**
   - **Skor Tabelası:** Ev sahibi & deplasman kulüpleri, canlı skor, tenis ise set skorları, canlı akan kronometre (running stopwatch ticker).
   - **Olay Akışı (Timeline):** Kronolojik dikey olay listesi (⚽ Gol, 🟨 Sarı kart, 🟥 Kırmızı kart, 🔄 Değişiklik, ⏱️ Devre/Periyot sonu).
   - **Esame / Kadrolar Sekmesi:** Sahaya çıkanlar ve yedekler listesi.
   - **Maç Künyesi:** Saha, il, hakem heyeti (kabul edilmiş başhakem/yardımcılar).

---

### 🟢 Adım 4: Doğrulama, Testler ve Kalite Kapıları

1. **SQL Regresyon Testi (`tools/live_match_spectator_sql_test.mjs`):**
   - Anonim ve normal authenticated kullanıcıların canlı skoru okuyabilmesi.
   - Hakem notlarının ve disiplin sevklerinin seyirci projeksiyonunda dönmediğinin kanıtı.
   - Çocuk gizliliği: Rızasız çocukların adlarının maskelendiğinin doğrulanması.
   - İdempotent replay ve kilit kontrolleri.
2. **Araç Kontrolleri:**
   - `python tools/check_migrations.py`: 0116 migration sözdizimi ve kilit kontrolleri.
   - `python tools/check_faq.py`: Yeni canlı skor özellikleri için SSS senkronizasyonu.
   - `python tools/check_push_routes.py`: `/canli-skor` ve `/canli-mac/:id` rotalarının tescili.
   - `python tools/check_mobile_ui_tokens.py`: Ham stil ve renk kullanılmadığının doğrulanması.
3. **Melos Format & Analyze Kontrolleri.**
