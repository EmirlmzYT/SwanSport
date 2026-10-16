# SwanSport — Uygulama Genel Revizyon, Özellik Kilidi Açma ve Piksel Hizalama Planı (Codex Uygulama Rehberi)

Bu plan; uygulamada `audience = 'admins'` kilidi altında kaldığı için normal kullanıcılara (`taraftar`, `kulup-yoneticisi`, `antrenor-3`, `lisansli-sporcu`, `bashakem`) görünmeyen ana modüllerin herkese (`'everyone'`) açılmasını, kulüp yöneticisinin kulübün aktif antrenman branşlarını seçebileceği çoklu branş tescil ekranını ve 12+ ekrandaki `AppBar`, tipografi, kart yüzeyi ve piksel hizalamalarının tek bir standartta birleştirilmesini kapsar.

---

## 1. Hedef ve Mimari İlkeler (`AGENTS.md` Değişmezleri)

1. **Mevcut Migration Dosyalarına Dokunulmaz**: `0073`–`0120` arasındaki SQL dosyaları ve onların bağımsız testleri (`referee_cockpit_sql_test.mjs`, `live_match_spectator_sql_test.mjs` vb.) olduğu gibi korunur. Tüm veritabanı değişiklikleri yeni **`supabase/migrations/0121_general_availability_and_club_training_sports.sql`** dosyasında yapılır.
2. **Güvenlik Sınırları (`SwanAccess` + RLS) Korunur**: Özellik bayraklarının (`feature_flags`) `'admins'` seviyesinden `'everyone'` seviyesine çekilmesi yalnızca **görünürlük** kapısını açar; Hakem Kokpiti yine yalnızca hakemlere, Kulüp Operasyonları yine yalnızca aktif kulüp personeline, Veli merkezi yine yalnızca velilere açık kalır. `offline_attendance` ve `social_video` V1 dışı olduğu için `'off'` kalmaya devam eder.
3. **Federasyon Tescili (`club_sport_registrations`) ile Kulüp Antrenman Branşları (`club_training_sports`) Ayrımı**: Resmi federasyon tescil tablosu (`club_sport_registrations`) yalnız federasyon yetkilisi tarafından yazılır. Kulüp yöneticisinin kendi kulübünde antrenman yaptığı branşları (ör. 10 branş) seçebilmesi için ayrı `public.club_training_sports` tablosu ve `public.set_club_training_sports` RPC'si tanımlanır; `public.my_training_club_sports(uuid)` fonksiyonu bu tabloyu da kapsayacak şekilde güncellenir.
4. **Sıfır Ham `AppBar` ve Sıfır Ham `ListTile`**: Mobil uygulamadaki tüm alt modül ekranları `swanModuleAppBar(context, title: ...)` kullanır; tüm ekran gövdeleri `backgroundColor: c.bg` alır; `SwanColors.textSecondary` gibi sabit renkler yerine tema duyarlı `c.inkMuted` ve `SwanType` kullanılır.

---

## 2. Adım 1 — Veritabanı Migration (`supabase/migrations/0121_general_availability_and_club_training_sports.sql`)

Yeni migration dosyası `set local lock_timeout = '15s';` ile başlar ve şu 3 işi idempotent olarak yapar:

### 2.1. Tamamlanmış Özellik Bayraklarını `'everyone'` Kademesine Açma
Yalnızca mevcut durumu `'admins'` olan bayraklar `'everyone'` yapılır (böylece yönetici tarafından bilerek `'off'` yapılmış bir bayrak varsa ezilmez):

```sql
update public.feature_flags
   set audience = 'everyone'
 where audience = 'admins'
   and key in (
     'sport_training_sessions',
     'season_setup',
     'development_report',
     'court_waitlist',
     'turf_delegation',
     'referee_cockpit',
     'club_staff_operations',
     'live_match_hub',
     'league_standings',
     'live_match_notifications',
     'parent_hub'
   );
```

### 2.2. Kulüp Aktif Antrenman Branşları Tablosu ve RPC'si (`club_training_sports`)
Bir kulübün 10 farklı branşta antrenman şablonu ve filtre barı (`SmartSportScopeBar`) kullanabilmesi için kulüp yöneticisinin seçebileceği tablo:

```sql
create table if not exists public.club_training_sports (
  club_id    uuid not null references public.clubs(id) on delete cascade,
  sport_code text not null references public.sports(code) on delete cascade,
  created_at timestamptz not null default now(),
  created_by uuid references public.profiles(id) on delete set null,
  primary key (club_id, sport_code)
);

alter table public.club_training_sports enable row level security;

drop policy if exists club_training_sports_select on public.club_training_sports;
create policy club_training_sports_select on public.club_training_sports
  for select to authenticated
  using (
    exists (
      select 1 from public.club_memberships m
      where m.club_id = club_training_sports.club_id
        and m.profile_id = auth.uid()
        and m.status = 'active'
    )
  );
```

* **`public.set_club_training_sports(p_club_id uuid, p_sport_codes text[]) returns int`**:
  - `security definer`, `set search_path = public`.
  - Çağıran kullanıcının `p_club_id` kulübünde aktif `admin` veya `coach` (`club_memberships.role in ('admin', 'coach')` ve `status = 'active'`, kulüp `status = 'active'`) olduğunu doğrular; değilse `raise exception 'Kulüp branşlarını güncelleme yetkin yok';`.
  - `p_sport_codes` içindeki geçersiz/boş kodları eler (`select distinct s.code from unnest(coalesce(p_sport_codes, array[]::text[])) u(code) join public.sports s on s.code = trim(u.code)`). En fazla 60 branş sınırını kontrol eder.
  - Kulübün mevcut `club_training_sports` kayıtlarını senkronize eder (listede olmayanları siler, yeni olanları `on conflict do nothing` ile ekler) ve toplam aktif branş sayısını (`int`) döndürür.
  - `revoke all on function public.set_club_training_sports(uuid, text[]) from public, anon, authenticated; grant execute on function public.set_club_training_sports(uuid, text[]) to authenticated;`

* **`public.my_training_club_sports(p_club_id uuid)` Güncellemesi**:
  - `0120`'deki `my_training_club_sports` fonksiyonu `create or replace` ile güncellenerek `union select cts.sport_code from public.club_training_sports cts where cts.club_id = p_club_id` satırı eklenir. Böylece kulüp yöneticisi branş seçtiği anda `activeClubSportsProvider` ve `SmartSportScopeBar` anında o branşları gösterir.

---

## 3. Adım 2 — Veri Katmanı (`packages/swansport_data`)

### 3.1. [`sport_context_service.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/packages/swansport_data/lib/src/sport_context_service.dart)
* `setClubTrainingSports(WidgetRef ref, {required String clubId, required List<String> sportCodes})` yardımcı fonksiyonu veya servis metodu eklenir:
  - `supabaseClientProvider.rpc<int>('set_club_training_sports', params: {'p_club_id': clubId, 'p_sport_codes': sportCodes})` çağrısını yapar.
  - Başarılı olduğunda `ref.invalidate(activeClubSportsProvider)` ve `ref.invalidate(sportContextOptionsProvider)` çağırarak tüm uygulamadaki branş barlarını anında günceller.

---

## 4. Adım 3 — Piksel, AppBar ve Kart Yüzeyi Standardizasyonu (`apps/swansport_app`)

### 4.1. Ham `AppBar` Kullanan 10 Ekranın `swanModuleAppBar` ve Tema Jetonlarına Geçirilmesi
Aşağıdaki ekranların tamamında standart `AppBar(...)` kaldırılıp `swanModuleAppBar(context, title: ...)` kullanılacak ve `Scaffold(backgroundColor: c.bg, ...)` güvenceye alınacaktır:

1. **[`attendance_workspace.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/apps/swansport_app/lib/features/attendance/presentation/screens/attendance_workspace.dart)**:
   - Satır 190: `Scaffold` içine `backgroundColor: c.bg` ve `appBar: swanModuleAppBar(context, title: 'Yoklama')` eklenir.
   - Ham `const Text(...)` uyarı metinleri `SwanType.bodySm(c.inkMuted)` ile sarılır.
2. **[`workout_builder_screen.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/apps/swansport_app/lib/features/training/presentation/workout_builder_screen.dart)**:
   - Satır 67: `appBar: swanModuleAppBar(context, title: 'Antrenman Şablonu Oluştur')`.
   - Form alanları (`_name`, `_description`, branş ve arketip seçicileri, metrik kutuları) `Container(padding: const EdgeInsets.all(SwanSpace.lg), decoration: BoxDecoration(color: c.surface, borderRadius: SwanRadius.lg, border: Border.all(color: c.borderSubtle)))` kart yüzeyleri içine alınarak ham çizgi görünümünden kurtarılır.
3. **[`season_setup_screen.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/apps/swansport_app/lib/features/configuration/presentation/season_setup_screen.dart)**:
   - Satır 209 ve 221: Her iki `Scaffold` için `backgroundColor: c.bg` ve `appBar: swanModuleAppBar(context, title: 'Sezon Açılışı')` kullanılır.
   - Yetki/durum boş ekranlarında ham `Center(child: Text(...))` yerine `premiumEmpty` kullanılır.
4. **[`guardian_official_result_screen.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/apps/swansport_app/lib/features/calendar/presentation/screens/guardian_official_result_screen.dart)**:
   - Satır 36: `appBar: swanModuleAppBar(context, title: 'Resmi Müsabaka Karnesi')`.
5. **[`document_detail_screen.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/apps/swansport_app/lib/features/documents/presentation/screens/document_detail_screen.dart)**:
   - Satır 21: `appBar: swanModuleAppBar(context, title: 'Belge Ayrıntısı')`.
   - Belge meta bilgileri (`d.typeLabel`, `Sahip`, `Durum`, `Doğrulanmış`) `c.surface` ve `c.borderSubtle` kenarlıklı şık bir bilgi kartı içine alınır (`Key('document-detail-title')`, `Key('document-invalid-route')`, `Key('document-not-found')` anahtarları birebir korunur!).
6. **[`guest_explore_screen.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/apps/swansport_app/lib/features/network/presentation/guest_explore_screen.dart)**:
   - Satır 18: `backgroundColor: c.bg`, `appBar: swanModuleAppBar(context, title: 'SwanSport · Keşfet')`.
   - Ham `ListTile` öğeleri `c.surface` + `c.borderSubtle` kart görünümüne ve `SwanType.body(c.ink)` / `SwanType.caption(c.inkMuted)` tipografisine kavuşturulur.
7. **[`performance_workflow_editors.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/apps/swansport_app/lib/features/performance_analytics/presentation/performance_workflow_editors.dart)**:
   - Satır 161 ve 175: `backgroundColor: c.bg` ve `appBar: swanModuleAppBar(context, title: _title)`.
   - Satır 188: `Theme.of(context).textTheme.headlineSmall` yerine `SwanType.h2(c.ink)` kullanılır (`Key('workflow-permission-denied')`, `Key('workflow-editor-${widget.kind.name}')`, `Key('workflow-cancel')`, `Key('workflow-save')` anahtarları birebir korunur!).
8. **[`find_partner_screen.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/apps/swansport_app/lib/features/courts/presentation/find_partner_screen.dart)**:
   - Satır 54: `appBar: swanModuleAppBar(context, title: 'Partner Bul')`.
   - Dosya içindeki tüm `SwanColors.textSecondary` kullanımları tema duyarlı `c.inkMuted` ile değiştirilir.
9. **[`court_detail_screen.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/apps/swansport_app/lib/features/courts/presentation/court_detail_screen.dart)**:
   - Üst bar `swanModuleAppBar(context, title: _court.name, subtitle: '${_court.opensAt} – ${_court.closesAt}')` (veya mevcut `swanModuleAppBar` imzasına uygun başlık + aksiyon) ile standartlaştırılır.
   - `SwanColors.textSecondary` kullanımları `c.inkMuted` yapılır.
   - Satır 80–85'teki havada asılı duran `TextButton('Bekleme listem')` düğmesi, `c.surface` arka planlı, `Icons.schedule_rounded` ikonlu ve sağ oklu kompakt bir aksiyon kartına dönüştürülür (metin `'Bekleme listem'` olarak korunur ki mevcut widget testleri kırılmasın).
10. **[`turf_field_detail_screen.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/apps/swansport_app/lib/features/turf/presentation/turf_field_detail_screen.dart)**:
    - Üst bar `swanModuleAppBar` ile standartlaştırılır, `SwanColors.textSecondary` kullanımları `c.inkMuted` yapılır.
    - Satır 88–108'deki `'Saha görevlerim'` ve `'Görev devret'` düğmeleri yan yana şık aksiyon çipleri/kartları olarak hizalanır (düğme metinleri `'Saha görevlerim'` ve `'Görev devret'` olarak korunur).

---

## 5. Adım 4 — Kulüp Ayarları Ekranı (`club_settings_screen.dart`) Yenilemesi & Kulüp Branş Seçici

[`club_settings_screen.dart`](file:///c:/Users/anado/OneDrive/Documents/ChatGPT/swansport/apps/swansport_app/lib/features/settings/presentation/screens/club_settings_screen.dart) şu an düz `ListTile` ve `Divider` satırlarından oluşuyor. Bu ekran şu şekilde iyileştirilecek:

1. **Gruplanmış Premium Ayar Kartları**:
   - `Hesap & Güvenlik` (`Profilim`, `Lisans ve kimlik doğrulama`, `Veli bağlantısı`, `Gizlilik ve engellenenler`), `Görünüm, Dil ve Bildirimler`, `Kulüp Yönetimi`, `Destek ve Oturum` bölümleri `c.surface` arka planlı, `SwanRadius.lg` köşeli, `c.borderSubtle` kenarlıklı kart grupları içine alınır.
   - Her satırda 36x36 `c.surfaceAlt` ikon kutusu, `SwanType.body(c.ink, w: FontWeight.w600)` başlık ve `Icons.chevron_right_rounded` (`c.inkSoft`) kullanılır.
2. **Kulüp Aktif Branşları Seçici (`Kulüp branşlarını yönet`)**:
   - `club != null && access.isClubStaff` bloğu içine **"Kulüp branşlarını yönet"** (`Icons.sports_rounded`) satırı eklenir.
   - Tıklandığında açılan modal bottom sheet (`_ClubTrainingSportsSheet`), 60 federasyon branşını (`SportsCatalog.all`) arama kutusu ve çoklu seçim (`FilterChip` / `CheckboxListTile`) ile listeler; mevcut seçili branşları `activeClubSportsProvider` üzerinden işaretli başlatır.
   - **"Kaydet"** düğmesine basıldığında `set_club_training_sports` RPC'sini çağırır, `activeClubSportsProvider`'ı yeniler ve kullanıcıya bilgi verir.

---

## 6. Adım 5 — Test ve Doğrulama Kriterleri

1. **Yeni SQL Testi (`tools/general_availability_and_club_sports_sql_test.mjs`)**:
   - `0121` migration'ının `live_match_hub`, `league_standings`, `live_match_notifications`, `sport_training_sessions`, `referee_cockpit`, `club_staff_operations` vb. bayrakları `'everyone'` yaptığını, ancak `'off'` olan bir bayrağı (`offline_attendance`) açmadığını doğrular.
   - `set_club_training_sports` RPC'sinin:
     - Kulüp yöneticisi/antrenörü için çoklu branşları (ör. 10 branş) kaydettiğini ve `my_training_club_sports` çıktısında döndürdüğünü,
     - Kulüp üyesi olmayan veya sıradan sporcu/muhasebeci olan kullanıcıyı reddettiğini doğrular.
2. **Mevcut Tüm SQL ve Senkronizasyon Testleri**:
   - `tools/multi_branch_training_sql_test.mjs`, `tools/referee_cockpit_sql_test.mjs`, `tools/live_match_spectator_sql_test.mjs`, `tools/league_standings_sql_test.mjs`, `tools/match_following_sql_test.mjs` dahil tüm testler 100% geçmelidir.
   - `SwanType` / `SwanPalette` kuralı: Değiştirilen hiçbir `features/` dosyasında ham `jakarta(` / `sora(` veya `SwanColors.textSecondary` kalmamalıdır.
