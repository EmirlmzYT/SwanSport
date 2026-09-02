-- ---------------------------------------------------------------------------
-- 0071 — Branşa özel antrenman oturum motoru: şema
--
-- Bugüne kadar bir antrenman "takvimde bir satır" (`events`) ve "yoklama
-- listesi" (`attendance`) idi. Sahada olan şey — kaç set, kaç ok, hangi
-- sürede, kaç puan — hiçbir yere yazılmıyordu.
--
-- `performance_tests` (0014) BU DEĞİL: orası ölçüm verisi ("30 m sprint,
-- 4.2 sn"). Günlük antrenman sonucunu oraya yazmak ikisini birbirine
-- karıştırır ve gelişim grafiğini bozar. Bilerek ayrı tablolar.
--
-- MOTOR BRANŞA DEĞİL PROTOKOLE BAKIYOR. İlk çalışan branş okçuluk ama
-- sütun adları branştan bağımsız: "ok" değil `unit`, "atış" değil `shoot`
-- fazı. Yüzmede unit = kulvar tekrarı, atletizmde = deneme. Yeni branş
-- eklemek yeni tablo değil yeni `config` demek.
--
-- SPORCU KİMLİĞİ: her yerde `athletes.id`. `profiles.id` DEĞİL — küçük yaşta
-- sporcuların giriş profili olmayabiliyor (0001'de `profile_id` nullable).
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) Yapılandırma doğrulaması
--
-- `config` serbest jsonb olsaydı istemcinin ayrıştırması sessizce patlardı:
-- eksik `set_count` ile başlayan bir oturum ekranda sıfır set gösterirdi.
-- Şemada kesiliyor.
--
-- NEDEN `case`: `(p->>'set_count')::int` sayısal olmayan bir değerde cast
-- hatası fırlatıyor ve Postgres `and` işlenenlerinin sırasını garanti
-- etmiyor. `case` sırayı garanti ediyor; önce tip, sonra aralık.
--
-- NEDEN `coalesce(..., false)`: check kısıtı NULL'ı "ihlal yok" sayıyor.
-- Eksik anahtar NULL üretirse kısıt sessizce geçerdi.
-- ---------------------------------------------------------------------------
create or replace function public.valid_training_config(p jsonb)
returns boolean
language sql
immutable
as $fn$
  select coalesce(
    case
      when jsonb_typeof(p->'set_count')       <> 'number' then false
      when jsonb_typeof(p->'units_per_set')   <> 'number' then false
      when jsonb_typeof(p->'prep_seconds')    <> 'number' then false
      when jsonb_typeof(p->'shoot_seconds')   <> 'number' then false
      when jsonb_typeof(p->'collect_seconds') <> 'number' then false
      when jsonb_typeof(p->'rest_seconds')    <> 'number' then false
      when jsonb_typeof(p->'max_unit_score')  <> 'number' then false
      else
            (p->>'set_count')::int       between 1 and 50
        and (p->>'units_per_set')::int   between 1 and 100
        and (p->>'prep_seconds')::int    between 0 and 3600
        and (p->>'shoot_seconds')::int   between 5 and 3600
        and (p->>'collect_seconds')::int between 0 and 3600
        and (p->>'rest_seconds')::int    between 0 and 3600
        and (p->>'max_unit_score')::numeric between 1 and 1000
        and (p->>'entry_mode') in ('simple', 'detailed', 'flexible')
        and (p->>'mode') in ('technique', 'scored', 'simulation')
    end, false);
$fn$;

-- ---------------------------------------------------------------------------
-- 2) Protokoller (şablonlar)
--
-- SÜRÜMLEME: şablon düzenlemek bu satırı değiştirmiyor, `version + 1` ile
-- YENİ satır yazıyor. Oturum `protocol_id` tutuyor, yani şablon "değişince"
-- geçmiş oturumun anlamı değişmiyor.
--
-- Tam anlık görüntü (`config_snapshot`) bilerek KOPYALANMIYOR: aynı veriyi
-- iki yerde tutmak ikisinin ayrışması demek. Değişmezlik 0072'de tetikleyici
-- ile zorlanıyor — umut değil kural.
--
-- `club_id` null = platform şablonu (herkesin görebildiği hazır şablonlar).
-- ---------------------------------------------------------------------------
create table if not exists public.training_protocols (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid references public.clubs (id) on delete cascade,
  sport_code  text not null references public.sports (code),
  name        text not null,
  description text,
  version     int  not null default 1,
  parent_id   uuid references public.training_protocols (id) on delete set null,
  config      jsonb not null,
  published   boolean not null default false,
  archived_at timestamptz,
  created_by  uuid references public.profiles (id) on delete set null,
  created_at  timestamptz not null default now(),

  constraint training_protocol_version_positive check (version >= 1),
  constraint training_protocol_config_valid
    check (public.valid_training_config(config))
);

create index if not exists idx_training_protocol_club
  on public.training_protocols (club_id, sport_code)
  where archived_at is null;

-- ---------------------------------------------------------------------------
-- 3) Oturumlar
--
-- KULÜP ↔ KİŞİSEL: tek tablo, `kind` ayrımı. Ayrı tablo yerine tek tablo
-- çünkü set/skor/öz değerlendirme yapısı ikisinde de aynı; ikiye bölmek her
-- sorguyu ve her politikayı ikiye bölerdi. İzolasyon politikada (§7).
--
-- SAYAÇ ZAMAN DAMGASINDAN: `phase_started_at`/`phase_ends_at` var, "kalan
-- saniye" sütunu YOK. Uygulama arka plana gidip geri geldiğinde sayıcı
-- yanlış devam ederdi; iki zaman damgası arasındaki fark yanlış devam etmez.
--
-- `on delete restrict` protokolde: geçmişi olan bir şablon silinemiyor.
-- Silinebilseydi tamamlanmış oturumların anlamı kaybolurdu.
-- ---------------------------------------------------------------------------
create table if not exists public.training_sessions (
  id            uuid primary key default gen_random_uuid(),
  club_id       uuid not null references public.clubs (id) on delete cascade,
  protocol_id   uuid not null references public.training_protocols (id)
                  on delete restrict,
  kind          text not null default 'club',
  event_id      uuid references public.events (id) on delete set null,
  team_id       uuid references public.teams (id) on delete set null,
  athlete_id    uuid references public.athletes (id) on delete cascade,
  rhythm        text not null default 'shared',
  status        text not null default 'live',
  current_set   int  not null default 1,
  current_phase text not null default 'prep',
  phase_started_at timestamptz,
  phase_ends_at    timestamptz,
  -- Duraklatma da zaman damgasıyla: devam edilince `phase_ends_at` duraklama
  -- suresi kadar ileri kaydiriliyor. "Kalan saniye" sutunu tutsaydik ayni
  -- arka plan sorunu geri gelirdi.
  paused_at     timestamptz,
  join_code     text,
  join_code_expires_at timestamptz,
  started_at    timestamptz not null default now(),
  ended_at      timestamptz,
  created_by    uuid references public.profiles (id) on delete set null,
  created_at    timestamptz not null default now(),

  constraint training_session_kind_valid
    check (kind in ('club', 'personal')),
  constraint training_session_rhythm_valid
    check (rhythm in ('shared', 'individual', 'mixed')),
  constraint training_session_status_valid
    check (status in ('live', 'review', 'completed', 'cancelled')),
  constraint training_session_phase_valid
    check (current_phase in ('prep', 'shoot', 'collect', 'score', 'rest', 'done')),
  constraint training_session_set_positive check (current_set >= 1),

  -- Kişisel oturumun sahibi var ve takvime bağlanmıyor; kulüp oturumunun
  -- tek bir sahibi yok. Bu kısıt olmasaydı "hem kişisel hem etkinliğe bağlı"
  -- gibi anlamsız satırlar üretilebilirdi.
  constraint training_session_shape check (
    (kind = 'personal' and athlete_id is not null and event_id is null)
    or (kind = 'club' and athlete_id is null)
  )
);

-- Katılım kodu yalnızca CANLI oturumlar arasında tekil. Kapanmış oturumların
-- kodu yeniden kullanılabilsin diye kısmi indeks.
create unique index if not exists uq_training_join_code
  on public.training_sessions (join_code)
  where join_code is not null and status = 'live';

create index if not exists idx_training_session_club
  on public.training_sessions (club_id, started_at desc);

create index if not exists idx_training_session_athlete
  on public.training_sessions (athlete_id, started_at desc)
  where kind = 'personal';

create index if not exists idx_training_session_event
  on public.training_sessions (event_id)
  where event_id is not null;

-- ---------------------------------------------------------------------------
-- 4) Katılımcılar
--
-- KULVAR İSTEĞE BAĞLI (`lane` nullable). Ürün kararı: ilk sürümde sporcu
-- kulvar SEÇMİYOR. Antrenör isterse atıyor, atamazsa sistem yalnızca
-- katılımcı listesiyle çalışıyor.
-- ---------------------------------------------------------------------------
create table if not exists public.training_session_participants (
  session_id uuid not null references public.training_sessions (id) on delete cascade,
  athlete_id uuid not null references public.athletes (id) on delete cascade,
  lane       int,
  joined_at  timestamptz not null default now(),
  left_at    timestamptz,

  primary key (session_id, athlete_id),
  constraint training_lane_positive check (lane is null or lane >= 1)
);

-- ---------------------------------------------------------------------------
-- 5) Setler
--
-- `total_score` NULLABLE VE BU KASITLI. Eksik seti 0 yazmak, sporcuyu hiç
-- atmamış gibi değil KÖTÜ ATMIŞ gibi gösterirdi — ortalamayı düşürür,
-- gelişim grafiğini yalanlar. Eksik sonuç "eksik" olarak duruyor.
--
-- `locked_at` dolu = antrenör onayladı, sporcu artık dokunamıyor (0072).
-- ---------------------------------------------------------------------------
create table if not exists public.training_sets (
  id           uuid primary key default gen_random_uuid(),
  session_id   uuid not null references public.training_sessions (id) on delete cascade,
  athlete_id   uuid not null references public.athletes (id) on delete cascade,
  set_no       int  not null,
  total_score  numeric(8,2),
  unit_count   int,
  completed_at timestamptz,
  locked_at    timestamptz,
  locked_by    uuid references public.profiles (id) on delete set null,
  created_at   timestamptz not null default now(),

  unique (session_id, athlete_id, set_no),
  constraint training_set_no_positive check (set_no >= 1),
  constraint training_set_score_nonneg
    check (total_score is null or total_score >= 0),
  constraint training_set_units_nonneg
    check (unit_count is null or unit_count >= 0)
);

create index if not exists idx_training_set_athlete
  on public.training_sets (athlete_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 6) Tek tek girişler (detaylı skor biçimi)
--
-- `score` nullable: atılmamış ok. Aynı gerekçe — atılmamış oku 0 yazmak
-- ıskalamış saymaktır.
-- ---------------------------------------------------------------------------
create table if not exists public.training_set_entries (
  set_id uuid not null references public.training_sets (id) on delete cascade,
  seq    int  not null,
  score  numeric(6,2),

  primary key (set_id, seq),
  constraint training_entry_seq_positive check (seq >= 1),
  constraint training_entry_score_nonneg check (score is null or score >= 0)
);

-- ---------------------------------------------------------------------------
-- 7) Denetim izi
--
-- Antrenör müdahalesi (duraklat, devam, aşama atla, erken bitir) ve kilitli
-- sonuç düzeltmesi buraya, GEREKÇESİYLE yazılıyor.
--
-- Bu tabloda insert/update/delete politikası YOK — yazma yalnızca 0072'deki
-- RPC'lerden. `expense_audit_logs` (0055) ile aynı desen: denetim izini
-- düzenleyebilen biri denetim izini anlamsızlaştırır.
-- ---------------------------------------------------------------------------
create table if not exists public.training_session_events (
  id         uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.training_sessions (id) on delete cascade,
  actor_id   uuid references public.profiles (id) on delete set null,
  action     text not null,
  reason     text,
  phase      text,
  set_no     int,
  athlete_id uuid references public.athletes (id) on delete set null,
  old_value  jsonb,
  new_value  jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_training_event_session
  on public.training_session_events (session_id, created_at desc);

-- ---------------------------------------------------------------------------
-- 8) Öz değerlendirme
--
-- Hepsi isteğe bağlı. Boş bırakılırsa antrenman kaydı ENGELLENMİYOR —
-- zorunlu değerlendirme, sporcuyu rastgele değer girmeye iter ve veriyi
-- kirletir.
--
-- Sağlık tanısı, doktor notu ve belge içeriği BURAYA TAŞINMIYOR. RPE
-- algılanan zorluk; tıbbi kayıt değil.
-- ---------------------------------------------------------------------------
create table if not exists public.training_self_assessments (
  session_id uuid not null references public.training_sessions (id) on delete cascade,
  athlete_id uuid not null references public.athletes (id) on delete cascade,
  rpe        int,
  tags       text[] not null default '{}',
  note       text,
  created_at timestamptz not null default now(),

  primary key (session_id, athlete_id),
  constraint training_rpe_range check (rpe is null or rpe between 1 and 10)
);

-- ---------------------------------------------------------------------------
-- 9) Yetki yardımcıları
--
-- `can_view_athlete_performance` (0014) ZATEN VAR ve tam istediğimiz hesabı
-- yapıyor: kulüp yetkilisi VEYA sporcunun kendisi VEYA velisi. Kulüp
-- oturumu okumasında onu çağırıyoruz, ikinci bir kopya yazmıyoruz.
--
-- Kişisel oturum için ayrı bir kontrol gerekiyor çünkü orada veli ve
-- antrenör GÖRMEMELİ — yalnızca sporcunun kendisi.
-- ---------------------------------------------------------------------------
create or replace function public.is_athlete_self(p_athlete uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.athletes a
     where a.id = p_athlete
       and a.profile_id = auth.uid()
  );
$fn$;

-- Oturumu okuyabilir miyim. Kişisel oturumda YALNIZCA sahibi; kulüp
-- oturumunda kulüp personeli, sporcunun kendisi ve velisi.
create or replace function public.can_view_training_session(p_session uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.training_sessions s
     where s.id = p_session
       and case
             when s.kind = 'personal' then public.is_athlete_self(s.athlete_id)
             else public.is_club_member(s.club_id)
           end
  );
$fn$;

-- Oturumu yönetebilir miyim (antrenör tarafı). Kişisel oturumda antrenör
-- YOK — sahibinin kendisi yönetiyor.
create or replace function public.can_manage_training_session(p_session uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.training_sessions s
     where s.id = p_session
       and case
             when s.kind = 'personal' then public.is_athlete_self(s.athlete_id)
             else public.is_club_staff(s.club_id)
           end
  );
$fn$;

-- ---------------------------------------------------------------------------
-- 10) RLS
--
-- ROL MATRİSİ
--   sporcu      → kendi setleri + katıldığı kulüp oturumunun akışı
--   antrenör    → kendi kulübünün oturumları (kişisel oturumlar HARİÇ)
--   veli        → bağlı çocuğunun kulüp oturumu özeti (kişisel HARİÇ)
--   muhasebeci  → HİÇBİRİ (`is_club_staff` kapsamında değil, 0049)
--
-- Muhasebeci bu modüle hiç girmiyor: politikaların hiçbirinde
-- `club_accountants` geçmiyor ve `is_club_staff` muhasebeciyi saymıyor.
-- ---------------------------------------------------------------------------
alter table public.training_protocols          enable row level security;
alter table public.training_sessions           enable row level security;
alter table public.training_session_participants enable row level security;
alter table public.training_sets               enable row level security;
alter table public.training_set_entries        enable row level security;
alter table public.training_session_events     enable row level security;
alter table public.training_self_assessments   enable row level security;

-- Protokoller: platform şablonları herkese, kulüp şablonları kulübe.
drop policy if exists "training_protocol_read" on public.training_protocols;
create policy "training_protocol_read" on public.training_protocols for select
  to authenticated
  using (
    (club_id is null and published)
    or (club_id is not null and public.is_club_member(club_id))
  );

-- Yazma yalnızca RPC'den (0072). Doğrudan insert/update yolu YOK — sürüm
-- disiplini ancak tek kapıdan geçilirse korunur.
drop policy if exists "training_protocol_admin" on public.training_protocols;
create policy "training_protocol_admin" on public.training_protocols for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Oturumlar.
drop policy if exists "training_session_read" on public.training_sessions;
create policy "training_session_read" on public.training_sessions for select
  to authenticated
  using (
    case
      when kind = 'personal' then public.is_athlete_self(athlete_id)
      else public.is_club_member(club_id)
    end
  );

-- YAZMA POLITIKASI YOK ve bu kasitli. Personele dogrudan `update` verseydik
-- antrenor `current_phase` ve `status` alanlarini denetim izi yazilmadan
-- degistirebilirdi -- oysa spec mudahalelerin gerekceyle kaydedilmesini
-- istiyor. Butun yazma 0072'deki RPC'lerden gecivor; onlar `security definer`
-- oldugu icin RLS'e takilmiyor ve her biri denetim satirini kendisi yaziyor.
--
-- Okuma kaybi yok: `is_club_staff` `is_club_member`'in alt kumesi (ayni
-- tablo, ek rol suzgeci), yani personel yukaridaki okuma politikasindan
-- zaten geciyor.

-- Katılımcılar: oturumu görebilen listeyi görüyor.
drop policy if exists "training_participant_read" on public.training_session_participants;
create policy "training_participant_read" on public.training_session_participants
  for select to authenticated
  using (public.can_view_training_session(session_id));

drop policy if exists "training_participant_manage" on public.training_session_participants;
create policy "training_participant_manage" on public.training_session_participants
  for all to authenticated
  using (public.can_manage_training_session(session_id))
  with check (public.can_manage_training_session(session_id));

-- Setler: sporcu kendi setini, personel/veli 0014'teki hesapla.
drop policy if exists "training_set_read" on public.training_sets;
create policy "training_set_read" on public.training_sets for select
  to authenticated
  using (
    public.is_athlete_self(athlete_id)
    or (
      public.can_view_training_session(session_id)
      and public.can_view_athlete_performance(athlete_id)
    )
  );

-- Sporcuya DOGRUDAN yazma verilmiyor. Ilk taslakta "kendi kilitlenmemis
-- setini duzeltebilsin" diye bir `update` politikasi vardi; o politika
-- `submit_set_score`'daki protokol dogrulamasini ATLATIYORDU -- sporcu
-- dogrudan `update ... set total_score = 9999` yazabilirdi, cunku sema
-- kisiti yalnizca negatif degeri engelliyor.
--
-- Duzeltme yolu kapanmadi, tek kapiya baglandi: `submit_set_score` ayni seti
-- `on conflict do update` ile guncelliyor ve kilitliyse reddediyor.
drop policy if exists "training_set_own_write" on public.training_sets;

drop policy if exists "training_entry_read" on public.training_set_entries;
create policy "training_entry_read" on public.training_set_entries for select
  to authenticated
  using (exists (
    select 1 from public.training_sets t
     where t.id = set_id
       and (
         public.is_athlete_self(t.athlete_id)
         or (
           public.can_view_training_session(t.session_id)
           and public.can_view_athlete_performance(t.athlete_id)
         )
       )
  ));

-- Denetim izi: okuma yalnızca oturumu YÖNETEBİLEN tarafta. Yazma politikası
-- bilerek yok — insert yalnızca 0072'deki RPC'lerden.
drop policy if exists "training_event_read" on public.training_session_events;
create policy "training_event_read" on public.training_session_events for select
  to authenticated
  using (public.can_manage_training_session(session_id));

-- Öz değerlendirme: sporcunun kendisi yazıyor ve okuyor; antrenör kulüp
-- oturumunda okuyabiliyor (RPE antrenman yükünü ayarlamak için gerekli).
drop policy if exists "training_assessment_read" on public.training_self_assessments;
create policy "training_assessment_read" on public.training_self_assessments
  for select to authenticated
  using (
    public.is_athlete_self(athlete_id)
    or (
      public.can_view_training_session(session_id)
      and public.can_view_athlete_performance(athlete_id)
    )
  );

drop policy if exists "training_assessment_own" on public.training_self_assessments;
create policy "training_assessment_own" on public.training_self_assessments
  for all to authenticated
  using (public.is_athlete_self(athlete_id))
  with check (public.is_athlete_self(athlete_id));

-- ---------------------------------------------------------------------------
-- 11) İzinler
--
-- `PUBLIC` ayrı ele alınıyor: yalnızca `anon` ve `authenticated`'dan almak
-- yetmiyor, izin `PUBLIC`'ten miras alınıyor.
-- ---------------------------------------------------------------------------
revoke execute on function public.is_athlete_self(uuid) from public, anon;
revoke execute on function public.can_view_training_session(uuid) from public, anon;
revoke execute on function public.can_manage_training_session(uuid) from public, anon;

grant execute on function public.is_athlete_self(uuid) to authenticated;
grant execute on function public.can_view_training_session(uuid) to authenticated;
grant execute on function public.can_manage_training_session(uuid) to authenticated;
