# SwanSport — Faz 3: Mobil Hakem Kokpiti & Saha Operasyonu Codex Uygulama Şartnamesi

**Tarih:** 2026-10-13
**Kapsam:** `apps/swansport_app` içinde lisanslı hakemlerin maçlarını yönetebileceği Mobil Hakem Kokpiti (Atamalar, Dijital Esame Onayı, Canlı Maç Yönetimi, Resmi Maç Raporu).

---

## 1. Mimari Prensipler ve Değişmezler (Invariants)

1. **Widget'tan Doğrudan Supabase Çağrısı Yapılamaz:**
   - Ekranlar yalnızca `packages/swansport_data` içindeki provider'ları (`myRefereeMatchesProvider`, `matchLineupApprovalsProvider`, vb.) dinler ve servis metotlarını çağırır.
2. **Gezinme Bütünlüğü (`AGENTS.md`):**
   - Alt bar 5 öğelidir (`SwanBottomNav`: Ana Sayfa · Keşfet · + · Mesajlar · Profil) ve **değiştirilemez**.
   - Hakem kokpitine giriş noktası:
     - `profile_screen.dart` içinde yalnızca `swanAccess.isReferee` durumunda açılan **"Hakem Kokpiti / Müsabaka Yönetimi"** kartı.
     - Ana Akış (`feed_screen.dart`) "Bugün" bölümünde hakemin bugünkü atanmış maçı varsa gösterilen hızlı aksiyon kartı.
3. **Tasarım Jetonları Kuralı (`app/design/`):**
   - Ham sayı (`fontSize: 14`) ve ham hex (`Color(0xFF...)`) yazmak **kesinlikle yasaktır**.
   - Yazı tipi: `SwanType` adımları (`display`, `titleLarge`, `titleMedium`, `bodyLarge`, `bodyMedium`, `caption`, `overline`).
   - Renkler: `SwanPalette` (`context.swan` veya `isDark ? SwanPalette.dark : SwanPalette.light`).
   - Şekiller: `SwanShape` radius jetonları.
4. **Saha Kullanılabilirliği & Ergonomi:**
   - Hakem sahadayken güneş altında veya yağmurda tek elle telefonu kullanabilir. Canlı maç ekranındaki skor, kart ve periyot butonları **en az 48x48dp dokunma alanına**, yüksek kontrasta ve haptic feedback (titreşim) geri bildirimine sahip olmalıdır.
5. **Güvenlik & Kilit Kuralları:**
   - Esame onaylandığında (`referee_verify_lineup`), liste sunucu tarafında kilitlenir; maç esnasında değiştirilemez.
   - Hakem maçı tamamlayıp raporu imzaladığında sonuç tescil durumuna geçer.

---

## 2. Oluşturulacak Ekranlar ve Rotalar

### A. Rota Tanımları (`apps/swansport_app/lib/app/router.dart`)
1. `/hakem/gorevler`: `RefereeDutyListScreen` (Atandığım Maçlar)
2. `/hakem/esame/:matchId`: `RefereeLineupApprovalScreen` (Dijital Esame Onayı)
3. `/hakem/canli/:matchId`: `RefereeLiveCockpitScreen` (Canlı Maç & Skor Yönetimi)
4. `/hakem/rapor/:matchId`: `RefereeMatchReportScreen` (Resmi Maç Raporu ve İmza)

### B. Ekran Ayrıntıları

#### 1. `RefereeDutyListScreen` (`features/referee/referee_duty_list_screen.dart`)
- **Sekmeler (`SwanSegmentedTabs`):** "Yaklaşan / Bugün" (Aktif) ve "Tamamlananlar".
- **Maç Kartı:**
  - Tarih, Başlama Saati, Branş Rozeti (`sportCode`), Saha / Tesis Adı, İl.
  - Karşılaşma: Ev Sahibi vs. Deplasman Kulüp Adları.
  - Görev Rozeti: Başhakem, 1. Yrd. Hakem, Masa Hakemi, vb.
  - Durum:
    - `assigned` (Bekliyor): **"Kabul Et"** (Yeşil) ve **"Mazeret Bildir"** (Kırmızı) butonları.
    - Mazeret bildirildiğinde kısa bir açıklama modalı açılır ve `respondMatchAssignment(officialId, false, reason)` çağrılır.
    - `accepted` (Kabul Edildi): Maç günüyse **"Müsabakayı Yönet"** butonu -> Esame ekranına yönlendirir.

#### 2. `RefereeLineupApprovalScreen` (`features/referee/referee_lineup_approval_screen.dart`)
- Maç öncesi esame listelerinin kontrolü.
- İki takım için sekmeli görünüm (Ev Sahibi / Deplasman).
- Sporcu Listesi: Forma No, Ad-Soyad, Lisans No, Vize durumu.
- Durum Rozetleri:
  - Sağlık Kilidi (Varsa kırmızı rozet: "Oynayamaz - Tıbbi Engel").
  - İdari Dinlenme (Sarı rozet: "Dinlendiriliyor").
  - Ceza (Kırmızı rozet: "Cezalı").
- Starters (Sahaya çıkanlar) ve Substitutes (Yedekler) seçimi.
- Alt Kısım: **"Esameyi Onayla ve Kilitle"** butonu (`verifyMatchLineup` RPC çağrısı). Onay sonrası doğrudan Canlı Kokpit'e geçer.

#### 3. `RefereeLiveCockpitScreen` (`features/referee/referee_live_cockpit_screen.dart`)
- Maç esnasında canlı operasyon ekranı.
- Üst Bölüm: Canlı Skor Tablosu, Periyot / Devre / Set Göstergesi, Süreç durumu.
- Buton Matrisi (Büyük Dokunmatik Hedefler):
  - **Skor Ekle:** Ev Sahibi Skor (+) / Deplasman Skor (+).
  - **Kart / Faul Ekle:** Sporcu seçici açılır -> Sarı Kart, Kırmızı Kart, 2dk Cezası / Teknik Faul.
  - **Oyuncu Değişikliği:** Çıkan sporcu (sahadakilerden) -> Giren sporcu (yedeklerden).
  - **Periyot Bitir / Devre Arası:** 1. Yarı Sonu, 2. Yarı Sonu, vb.
- Olay Zaman Çizelgesi (Feed): Dakika dakika düşen gol/kart olayları; hatalı giriş durumunda geri alma (undo) imkanı.
- Maç bittiğinde: **"Müsabakayı Bitir ve Raporla"** butonu.

#### 4. `RefereeMatchReportScreen` (`features/referee/referee_match_report_screen.dart`)
- Müsabaka sonu resmi raporlama.
- Özet Skor ve Olaylar: Tüm goller, sayılar, kartlar ve değişiklikler listelenir.
- **Hakem Gözlem ve Olay Notu Kutusu:** Saha olayları, sportmenlik dışı davranışlar veya disiplin sevki açıklaması yazılır (`notes`).
- **"Resmi Maç Raporunu İmzala ve Tescil Et"** butonu.
- İmza sonrası maç durumu `played` olarak tescil edilir ve tebrik ekranı ile ana sayfaya döner.

---

## 3. Özellik Bayrağı & SSS Entegrasyonu

1. Özellik bayrağı: `referee_cockpit` (varsayılan: `admins`).
2. SSS kaydı: `tools/check_faq.py` için soru-cevap eklenir ("Hakem kokpiti nedir ve esame nasıl onaylanır?").
3. Push rotaları: `tools/check_push_routes.py` için `/hakem/gorevler` rotası eklenir.

---

## 4. Test ve Doğrulama Adımları

1. `python tools/check_faq.py`: 40/40 yeşil olmalı.
2. `python tools/check_push_routes.py`: 41/41 yeşil olmalı.
3. `python tools/check_mobile_ui_tokens.py`: Yeni hakem ekranlarında token sözleşmesi kontrolü (100% yeşil).
4. `git diff --check`: Boşluk/satır sonu kontrolü (temiz).
