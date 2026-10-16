# SwanSport — 60 Branş Antrenman Kokpiti & Çok Branşlı Kulüp/Sporcu Akıllı Bağlam Planı (Codex)

**Hedef:** `0119_turkey_sports_federations_catalog.sql` ve `SportsCatalog` ile kaydedilen **60 resmi spor branşının tamamına** kendi terminolojisi, ölçüm metrikleri ve görsel kontrol pediyle çalışan antrenman ekranları kazandırmak; aynı zamanda **3 branşlı sporcu** veya **10 branşı tescilli çok şubeli kulüp** senaryolarında 60 branşlık liste karmaşasını ortadan kaldıran **Akıllı Branş Bağlamı (Smart Sport Context)** mimarisini kurmak.

---

## 1. Mimari Prensipler & Değişmezler (AGENTS.md)

1. **Widget'tan doğrudan Supabase çağrılmaz:** Tüm sorgular ve durum yönetimi `packages/swansport_data` içinde açık tip deklarasyonlu (`Provider<T>`, `AutoDisposeFutureProvider<T>`, `StateProvider<T>`) Riverpod sağlayıcılarından geçer.
2. **Saf Dart Katmanları:** `packages/swansport_branch_engine` ve `packages/swansport_data` içine `Color`, `IconData` veya Flutter widget'ı giremez. Görsel ikon/renk eşlemeleri yalnızca `apps/swansport_app` sunum katmanında yapılır.
3. **Motor Branşa Değil Protokole ve Arketipe Bakar:** 60 branş için 60 ayrı veritabanı tablosu veya 60 kopya ekran yazılmaz; **7 Antrenman Arketipi + 60 Branş Kimlik Sözlüğü (`BranchTrainingProfile`)** ile her branş kendi dilini konuşur.
4. **Geriye Dönük Tam Uyum:** Mevcut 4 arketip (`target_score`, `attempt_drill`, `lap_interval`, `combat_rally`) ve okçuluk/yüzme/basketbol/tenis sözleşmeleri kırılmaz.
5. **Tasarım Jetonları:** Mobil arayüzde yalnızca `SwanType`, `SwanPalette`, `SwanShape`, `SwanSpace` ve `SwanSegmentedTabs` / `SwanPillTabs` kullanılır; ham font boyutu veya hex renk yasaktır.
6. **Güvenlik & Gizlilik:** `SwanAccess` tek yetki kaynağıdır; muhasebeci anonimliği (`#A3F91C`) ve C1 kimlik kapıları korunur.

---

## 2. Adım Adım Uygulama Aşamaları

### 🟠 Adım 1: Saf Branş Antrenman Motoru (`packages/swansport_branch_engine`)

1. **3 Yeni Antrenman Arketipi (`lib/protocols/drill_metric_payload.dart`):**
   Mevcut `targetScore`, `attemptDrill`, `lapInterval`, `combatRally` arketiplerine ek olarak:
   - **`strengthSet('strength_set')` → `StrengthSetMetric`:**
     - *Kapsadığı Branşlar:* Halter (`halter`), Vücut Geliştirme ve Fitness (`vucut-gelistirme-fitness`), Bedensel Engelliler (`bedensel-engelliler`).
     - *Alanlar:* `exercise_name` (String, 1–120 karakter), `weight_kg` (num, 0–1000, 0.5 kg hassasiyetli), `reps` (int, 1–1000), `rpe` (int?, 1–10), `good_lift` (bool, varsayılan true).
   - **`routineJudge('routine_judge')` → `RoutineJudgeMetric`:**
     - *Kapsadığı Branşlar:* Cimnastik (`cimnastik`), Dans Sporları (`dans-sporlari`), Halk Oyunları (`halk-oyunlari`), Buz Pateni (`buz-pateni`), Binicilik (`binicilik`), Kaykay (`kaykay`).
     - *Alanlar:* `routine_name` (String, 1–120), `difficulty_score` (num, 0–100), `execution_score` (num, 0–100), `deductions` (num, 0–100), `net_score` (num, `difficulty_score + execution_score - deductions` ile birebir tutarlı).
   - **`mindTactical('mind_tactical')` → `MindTacticalMetric`:**
     - *Kapsadığı Branşlar:* Satranç (`satranc`), Briç (`bric`), E-Spor (`e-spor`), İzcilik (`izcilik`), Dağcılık (`dagcilik`), Hava Sporları (`hava-sporlari`).
     - *Alanlar:* `task_name` (String, 1–120), `solved_count` (int, 0–10000), `failed_count` (int, 0–10000), `duration_seconds` (int, 1–86400), `accuracy_rate` (double, `solved / (solved + failed)`).

2. **60 Branş Kimlik Sözlüğü (`lib/definitions/branch_training_profile.dart`):**
   - `BranchTrainingProfile` saf sınıfı:
     - `sportCode`: `String` (60 branş kodu)
     - `defaultArchetype`: `TrainingArchetype`
     - `supportedArchetypes`: `List<TrainingArchetype>`
     - `setLabel`: `String` (örn: `'Set'`, `'Seri'`, `'Raund'`, `'Tur'`, `'Etap'`)
     - `unitLabel`: `String` (örn: `'Ok'`, `'Şut'`, `'Servis / Hücum'`, `'Mesafe (m)'`, `'Tekrar'`, `'Kaldırış'`, `'Seri'`, `'Görev / Bulmaca'`)
     - `workPhaseLabel`: `String` (örn: `'Atış'`, `'Dril Aktif'`, `'Yüzüş'`, `'Koşu'`, `'Raund'`, `'Kaldırış'`, `'Seri İcrası'`)
     - `successLabel`: `String` (örn: Futbol `'İsabet / Gol'`, Basketbol `'Basket'`, Voleybol `'Ace / Sayı'`, Dövüş `'Etkili Puan / Teknik'`)
     - `faultLabel`: `String` (örn: Futbol `'Aut / Kayıp'`, Basketbol `'Kaçan Şut'`, Voleybol `'File / Aut'`, Dövüş `'Ceza / Hata'`)
     - `rateLabel`: `String?` (Yüzme `'Kulaç / Dk'`, Bisiklet `'Kadans (RPM)'`, Kürek/Kano `'Çekiş (SPM)'`, Atletizm `'Adım / Dk'`, Motor `'Devir / Sektör'`)
     - `presetDrills`: `List<String>` (Her branşa özel 4–6 hazır dril/istasyon adı)
     - `defaultDistances`: `List<int>` (`lap_interval` branşları için hızlı mesafe butonları, örn. Yüzme `[25, 50, 100, 200, 400]`)
   - `BranchTrainingProfile branchTrainingProfileFor(String sportCode)` fonksiyonu 60 branşın tamamı için eksiksiz profil döndürür.

---

### 🔴 Adım 2: Veritabanı Motoru (`supabase/migrations/0120_multi_branch_training_engine.sql`)

1. **`valid_training_config(p jsonb)` Güncellemesi:**
   - `archetype` kontrolüne `'strength_set'`, `'routine_judge'`, `'mind_tactical'` eklenir.
   - `collect_seconds` yalnız `target_score` arketipinde kullanılır; diğer arketiplerde `0` kabul edilir.
2. **`valid_drill_metric(p_archetype text, p jsonb)` Güncellemesi:**
   - `strength_set`, `routine_judge` ve `mind_tactical` JSON şemalarını, sayı sınırlarını ve matematiksel eşitlikleri (`net_score` ve `accuracy_rate`) doğrular; bilinmeyen anahtarları reddeder.
3. **`training_next_phase` & `training_phase_seconds`:**
   - Yeni 3 arketip `prep -> active_drill -> rest -> done` aşama makinesini kullanır.
4. **60 Branş İçin Hazır Platform Şablonları (`training_protocols`):**
   - `club_id is null` olarak 60 branşın tamamı için kendi `defaultArchetype` yapılandırmasında 2'şer standart şablon (`Temel Teknik Çalışma` ve `Performans & Simülasyon`) idempotent (`where not exists`) olarak eklenir.

---

### 🔵 Adım 3: Ortak Veri Katmanı — Akıllı Branş Bağlamı (`packages/swansport_data`)

1. **`lib/src/sport_context_service.dart` (Açık Tipli Sağlayıcılar):**
   - **`activeClubSportsProvider` (`AutoDisposeFutureProvider<List<SportItem>>`):**
     - Aktif kulübün ana branşı (`clubs.sport_code`), tescilli branşları (`club_sport_registrations.sport_code`) ve aktif takımlarının branşlarını (`teams.sport_code`) birleştirerek kulübün gerçekte kullandığı branşları (örn. 10 branş) `SportsCatalog` üzerinden döndürür.
   - **`myActiveSportsProvider` (`AutoDisposeFutureProvider<List<SportItem>>`):**
     - Kullanıcının onaylı belgelerindeki (`profile_credentials.sport_code`), üyesi olduğu takımlardaki (`teams.sport_code`) ve yaptığı antrenman geçmişindeki branşları (örn. sporcunun 3 branşı) döndürür.
   - **`selectedSportContextProvider` (`StateProvider<String?>`):**
     - Kullanıcının ekranlarda seçtiği aktif branş filtresi.
   - **`effectiveSportContextProvider` (`AutoDisposeProvider<String?>`):**
     - Eğer kullanıcı açıkça bir branş seçmişse onu döner; seçmemişse ve kullanıcının/kulübün **yalnızca 1 aktif branşı varsa otomatik olarak o branşı** döner! Böylece tek branşlı kulüp/sporcu hiçbir yerde tekrar branş seçmek zorunda kalmaz.

---

### 🟣 Adım 4: Mobil Arayüz & Deneyim Kolaylaştırma (`apps/swansport_app`)

1. **Akıllı Branş Seçici Çubuğu (`lib/features/training/presentation/widgets/smart_sport_scope_bar.dart`):**
   - **1 Branş Varsa:** Seçim barı gizlenir; yalnızca şık bir branş bilgi rozeti gösterilir (Sıfır seçim zahmeti).
   - **2–4 Branş Varsa (Örn. 3 Branşlı Sporcu / Antrenör):** Üstte `SwanSegmentedTabs` veya `SwanPillTabs` ile yalnızca o 3 branş gösterilir (`[ 🏊 Yüzme ] [ 🏃 Atletizm ] [ 🏹 Okçuluk ]`).
   - **5+ Branş Varsa (Örn. 10 Branşlı Kulüp Yöneticisi):** Yatay kaydırılabilir `SwanPillTabs` (`[ Tümü ] [ ⚽ Futbol ] [ 🏀 Basketbol ] ...`) ve en sonda `+ Tüm Branşlar (60)` arama sayfası tetikleyicisi yer alır.
2. **Branşa Özel Antrenman Kokpiti (`branch_drill_pad.dart`):**
   - `BranchDrillPad` içine `StrengthSetPad`, `RoutineJudgePad` ve `MindTacticalPad` eklenir.
   - Mevcut `AttemptDrillPad`, `LapIntervalPad`, `CombatRallyPad` ve `TargetScorePad`, protokolün `sportCode` değerinden `branchTrainingProfileFor(sportCode)` okuyarak:
     - Branşa özel hazır dril çiplerini (`presetDrills`),
     - Branşa özel başarı/hata buton isimlerini (`+1 Basket` / `+1 Kaçan`, `+1 Gol` / `+1 Aut`),
     - Branşa özel hızlı mesafe çiplerini (`25m · 50m · 100m`) ve frekans etiketini (`Kulaç / Dk`, `Kadans RPM`) gösterir.
3. **Dinamik Şablon Oluşturucu (`workout_builder_screen.dart`):**
   - Antrenör ekranı açtığında tek branşı varsa branş otomatik seçili gelir; birden fazla branşı varsa kendi aktif branşları listenin en üstünde yer alır.
   - Branş seçildiği anda:
     - Arketip otomatik olarak `profile.defaultArchetype` değerine geçer (veya `profile.supportedArchetypes` içinden seçilebilir).
     - Form etiketleri dinamikleşir (`Set sayısı` → `${profile.setLabel} sayısı`, `Set başına tekrar` → `${profile.setLabel} başına ${profile.unitLabel.toLowerCase()}`, `Çalışma (saniye)` → `${profile.workPhaseLabel} süresi (saniye)`).
     - `collect_seconds` (Ok toplama süresi) yalnızca `target_score` arketipinde gösterilir; diğer tüm branşlarda gizlenir ve otomatik `0` gönderilir.
4. **Şablon Listesi & Bireysel Antrenmanlarım (`protocol_list_screen.dart` & `my_training_screen.dart`):**
   - Üst kısma `SmartSportScopeBar` eklenir.
   - 3 branşlı sporcu `Yüzme` sekmesine dokunduğunda yalnız yüzme şablonlarını ve yüzme geçmişini, `Okçuluk` sekmesine dokunduğunda yalnız okçuluk şablonlarını ve ok puanlarını görür.

---

### 🟢 Adım 5: Testler & Doğrulama

1. **Birim Testleri (`packages/swansport_branch_engine/test/branch_training_profile_test.dart`):**
   - 60 branşın tamamının (`SportsCatalog.all`) geçerli bir `BranchTrainingProfile` döndürdüğünü doğrular.
   - `StrengthSetMetric`, `RoutineJudgeMetric` ve `MindTacticalMetric` sınıflarının serileştirme (`toMap`/`fromMap`) ve sınır doğrulama testlerini çalıştırır.
2. **SQL Regresyon Testi (`tools/training_archetypes_sql_test.mjs`):**
   - `0120` migration'ındaki 3 yeni arketipin `valid_training_config`, `valid_drill_metric` ve `submit_set_score` RPC'lerinde kabul/ret sınırlarını test eder.
   - 60 branşın platform şablonlarının hatasız oluştuğunu doğrular.
3. **Kalite Araçları:**
   - `python tools/check_migrations.py`
   - `python tools/check_faq.py`
   - `python tools/check_push_routes.py`
   - `python tools/check_mobile_ui_tokens.py`
   - `node tools/sports_federations_catalog_test.mjs`
