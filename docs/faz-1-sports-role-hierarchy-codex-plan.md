# SwanSport — Faz 1: Gerçek Hayat Spor Rolleri & Hakemlik Veritabanı Temeli (Codex Uygulama Şartnamesi)

**Hedef:** SwanSport veri tabanına Federasyon Kurulları, İl Temsilciliği, Hakem Kadroları, Müsabaka Atamaları ve Kulüp İhtisas Rollerini (Doktor esnekliğiyle birlikte) idempotent, güvenli ve geriye dönük uyumlu biçimde eklemek.

---

## 1. Değişmezler & Güvenlik İlkeleri (Non-Negotiables)

1. **İşlem Güvenliği:**
   - Dosya başında `set local lock_timeout = '15s';` zorunludur.
   - Tüm tablolar `create table if not exists`, tüm indeksler `create index if not exists`.
   - RPC güncellemelerinde imza/dönüş tipi çakışmasını önlemek için önce `drop function if exists` kullanılır.
2. **Hiyerarşik Kapsama (Scoped RBAC):**
   - Federasyon Başkanı: `city_code IS NULL` (Tüm illeri, ligleri ve hakem atamalarını denetler).
   - İl Temsilcisi: `city_code` zorunludur (Yalnızca kendi ilindeki kulüpleri ve maçları yönetir).
   - Hakem: Yalnızca atandığı `match_id` için esame kontrolü ve canlı skor girebilir.
3. **Doktor Esnekliği (Amatör vs. Profesyonel Kuralı):**
   - Doktorsuz kulüplerde antrenör veya kulüp yöneticisi sporcuyu idari olarak dinlendirebilir (`injured_admin` / `rested`); sistem asla kilitlenmez.
   - Kulüpte sağlık görevlisi atanmışsa (`is_authorized_health_officer`), tıbbi kısıt (`injured_medical`) devreye girer ve sağlık görevlisi dışında kimse kaldıramaz.
4. **Gizlilik Sözleşmeleri:**
   - Muhasebeci (`club_accountants`) asla sporcu isimlerini göremez (`#A3F91C` maskeleme devam eder).
   - Hakem ekranında sporcunun TC kimlik numarası, veli telefonu veya özel bilgileri asla yer almaz; yalnızca Ad-Soyad, Forma No, Lisans No ve Lisans Vize Durumu görünür.

---

## 2. Oluşturulacak Veritabanı Nesneleri (`0110_sports_role_hierarchy.sql`)

### A. Tablolar

#### 1. `public.federation_roles`
Federasyonun tepe yöneticileri, kurulları ve il temsilcileri.
```sql
create table if not exists public.federation_roles (
  id uuid primary key default gen_random_uuid(),
  federation_id uuid not null references public.federations(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in (
    'president',            -- Federasyon Başkanı
    'board_member',         -- Yönetim Kurulu Üyesi
    'general_secretary',    -- Genel Sekreter (Lisans & Tescil)
    'provincial_rep',       -- İl Temsilcisi (Şehir Kapsamlı)
    'referee_committee',    -- MHK / İl Hakem Kurulu
    'disciplinary_board'    -- Disiplin Kurulu
  )),
  city_code text references public.cities(code),
  starts_on date not null default current_date,
  ends_on date not null default (current_date + interval '1 year'),
  revoked_at timestamptz,
  granted_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default clock_timestamp(),
  check (ends_on >= starts_on),
  check (
    (role = 'provincial_rep' and city_code is not null) or
    (role <> 'provincial_rep' and city_code is null)
  )
);
create index if not exists idx_federation_roles_profile on public.federation_roles(profile_id, role) where revoked_at is null;
```

#### 2. `public.referee_profiles`
Müsabakaları yönetecek lisanslı hakemlerin sicil ve klasman kaydı.
```sql
create table if not exists public.referee_profiles (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null unique references public.profiles(id) on delete cascade,
  license_number text not null unique,
  badge_tier text not null check (badge_tier in ('candidate', 'provincial', 'national', 'international')),
  sport_code text not null references public.sports(code),
  city_code text not null references public.cities(code),
  is_active boolean not null default true,
  created_at timestamptz not null default clock_timestamp(),
  updated_at timestamptz not null default clock_timestamp()
);
create index if not exists idx_referee_profiles_sport_city on public.referee_profiles(sport_code, city_code) where is_active = true;
```

#### 3. `public.match_officials`
Resmi maçlara yapılan hakem, masa görevlisi ve gözlemci atamaları.
```sql
create table if not exists public.match_officials (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.org_matches(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  duty text not null check (duty in (
    'head_referee',          -- Başhakem
    'assistant_referee_1',   -- 1. Yardımcı Hakem
    'assistant_referee_2',   -- 2. Yardımcı Hakem
    'fourth_referee',        -- 4. Hakem
    'table_official',        -- Masa / Skor Hakemi
    'observer'               -- Gözlemci / Federasyon Temsilcisi
  )),
  status text not null default 'assigned' check (status in ('assigned', 'accepted', 'declined', 'replaced')),
  decline_reason text,
  assigned_by uuid references public.profiles(id) on delete set null,
  assigned_at timestamptz not null default clock_timestamp(),
  responded_at timestamptz,
  unique (match_id, duty)
);
create index if not exists idx_match_officials_profile on public.match_officials(profile_id, status);
create index if not exists idx_match_officials_match on public.match_officials(match_id);
```

#### 4. `public.club_staff_roles`
Kulüp başkanlığı, idari, teknik ve sağlık kadroları.
```sql
create table if not exists public.club_staff_roles (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in (
    'president',          -- Kulüp Başkanı
    'sporting_director',  -- Sportif Direktör / Branş Sorumlusu
    'doctor',             -- Kulüp Doktoru
    'physiotherapist',    -- Kulüp Fizyoterapisti
    'kit_manager',        -- Malzeme Sorumlusu
    'media_officer'       -- Medya / Basın Sorumlusu
  )),
  assigned_at timestamptz not null default clock_timestamp(),
  unique (club_id, profile_id, role)
);
create index if not exists idx_club_staff_roles_club on public.club_staff_roles(club_id, role);
```

#### 5. `public.org_match_lineup_notes` (Doktor Esnekliği & Esame Notları)
Maç öncesi sporcunun idari veya tıbbi durumunu saklayan esnek yapı.
```sql
create table if not exists public.org_match_lineup_notes (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null references public.org_matches(id) on delete cascade,
  athlete_id uuid not null references public.athletes(id) on delete cascade,
  club_id uuid not null references public.clubs(id) on delete cascade,
  status text not null check (status in ('eligible', 'injured_admin', 'injured_medical', 'rested', 'suspended')),
  note text,
  recorded_by uuid references public.profiles(id) on delete set null,
  recorded_at timestamptz not null default clock_timestamp(),
  unique (match_id, athlete_id)
);
```

---

### B. Yetkilendirme Fonksiyonları & RPC'ler (Security Definer)

#### 1. `public.is_federation_president(p_sport_code text default null)`
Giriş yapan kullanıcının Federasyon Başkanı olup olmadığını kontrol eder.
```sql
create or replace function public.is_federation_president(p_sport_code text default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.federation_roles fr
    join public.federations f on f.id = fr.federation_id
    where fr.profile_id = auth.uid()
      and fr.role = 'president'
      and fr.revoked_at is null
      and current_date between fr.starts_on and fr.ends_on
      and (p_sport_code is null or f.sport_code = p_sport_code)
  );
$$;
```

#### 2. `public.is_provincial_rep(p_city_code text, p_sport_code text default null)`
Giriş yapan kullanıcının ilgili ilin temsilcisi veya Federasyon Başkanı olup olmadığını doğrular (Hiyerarşi kuralı).
```sql
create or replace function public.is_provincial_rep(p_city_code text, p_sport_code text default null)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_federation_president(p_sport_code) or exists (
    select 1 from public.federation_roles fr
    join public.federations f on f.id = fr.federation_id
    where fr.profile_id = auth.uid()
      and fr.role = 'provincial_rep'
      and fr.city_code = p_city_code
      and fr.revoked_at is null
      and current_date between fr.starts_on and fr.ends_on
      and (p_sport_code is null or f.sport_code = p_sport_code)
  );
$$;
```

#### 3. `public.is_match_official(p_match_id uuid)`
Giriş yapan kişinin o maçta görevli hakem veya gözlemci olup olmadığını doğrular.
```sql
create or replace function public.is_match_official(p_match_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.match_officials mo
    where mo.match_id = p_match_id
      and mo.profile_id = auth.uid()
      and mo.status in ('assigned', 'accepted')
  );
$$;
```

#### 4. `public.my_referee_matches(p_status text default null)`
Hakemin kendisine atanan maçları listelemesini sağlayan güvenli RPC.
```sql
create or replace function public.my_referee_matches(p_status text default null)
returns table (
  official_id uuid,
  match_id uuid,
  duty text,
  status text,
  assigned_at timestamptz,
  starts_at timestamptz,
  location text,
  sport_code text,
  home_club_name text,
  away_club_name text
) language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  return query
  select
    mo.id as official_id,
    m.id as match_id,
    mo.duty,
    mo.status,
    mo.assigned_at,
    m.starts_at,
    m.location,
    o.sport_code,
    c_home.legal_name as home_club_name,
    c_away.legal_name as away_club_name
  from public.match_officials mo
  join public.org_matches m on m.id = mo.match_id
  join public.organizations o on o.id = m.org_id
  join public.org_participants p_home on p_home.id = m.home_id
  join public.clubs c_home on c_home.id = p_home.club_id
  left join public.org_participants p_away on p_away.id = m.away_id
  left join public.clubs c_away on c_away.id = p_away.club_id
  where mo.profile_id = auth.uid()
    and (p_status is null or mo.status = p_status)
  order by m.starts_at asc;
end;
$$;
```

#### 5. `public.respond_match_assignment(p_official_id uuid, p_accept boolean, p_reason text default null)`
Hakemin atamayı kabul etmesi veya mazeret bildirip reddetmesi.
```sql
create or replace function public.respond_match_assignment(
  p_official_id uuid,
  p_accept boolean,
  p_reason text default null
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_official public.match_officials;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;
  select * into v_official from public.match_officials where id = p_official_id and profile_id = auth.uid();
  if not found then raise exception 'Atama bulunamadı veya yetkiniz yok'; end if;

  update public.match_officials
  set status = case when p_accept then 'accepted' else 'declined' end,
      decline_reason = case when not p_accept then p_reason else null end,
      responded_at = clock_timestamp()
  where id = p_official_id;
end;
$$;
```

#### 6. `public.referee_verify_lineup(p_match_id uuid, p_home_roster uuid[], p_away_roster uuid[], p_notes text default null)`
Hakemin maç öncesi dijital esame listesini onaylaması ve kilitlemesi.
```sql
create or replace function public.referee_verify_lineup(
  p_match_id uuid,
  p_home_roster uuid[],
  p_away_roster uuid[],
  p_notes text default null
) returns void language plpgsql security definer set search_path = public as $$
declare
  v_match public.org_matches;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;
  if not exists (
    select 1 from public.match_officials
    where match_id = p_match_id and profile_id = auth.uid()
      and duty in ('head_referee', 'table_official') and status = 'accepted'
  ) then
    raise exception 'Bu maçın esamesini onaylama yetkiniz yok (Yalnızca Başhakem veya Masa Hakemi)';
  end if;

  select * into v_match from public.org_matches where id = p_match_id;
  if not found then raise exception 'Maç bulunamadı'; end if;

  -- Resmi kadro revizyonu kontrolü ve kilit
  insert into public.org_roster_revisions(participant_id, version, athlete_ids, reason, actor_id)
  values (v_match.home_id, 1, p_home_roster, coalesce(p_notes, 'Hakem esame onayı'), auth.uid())
  on conflict (participant_id, version) do update set athlete_ids = excluded.athlete_ids;

  if v_match.away_id is not null and p_away_roster is not null then
    insert into public.org_roster_revisions(participant_id, version, athlete_ids, reason, actor_id)
    values (v_match.away_id, 1, p_away_roster, coalesce(p_notes, 'Hakem esame onayı'), auth.uid())
    on conflict (participant_id, version) do update set athlete_ids = excluded.athlete_ids;
  end if;
end;
$$;
```

---

## 3. RLS İlkeleri ve Erişim Hakları (Grants)

```sql
alter table public.federation_roles enable row level security;
alter table public.referee_profiles enable row level security;
alter table public.match_officials enable row level security;
alter table public.club_staff_roles enable row level security;
alter table public.org_match_lineup_notes enable row level security;

-- Okuma Politikaları
create policy federation_roles_read on public.federation_roles for select using (true);
create policy referee_profiles_read on public.referee_profiles for select using (true);
create policy match_officials_read on public.match_officials for select using (true);
create policy club_staff_roles_read on public.club_staff_roles for select using (true);
create policy org_match_lineup_notes_read on public.org_match_lineup_notes for select using (true);

-- İzin Temizliği & Grant
revoke all on function public.is_federation_president(text) from public, anon;
grant execute on function public.is_federation_president(text) to authenticated;

revoke all on function public.is_provincial_rep(text, text) from public, anon;
grant execute on function public.is_provincial_rep(text, text) to authenticated;

revoke all on function public.my_referee_matches(text) from public, anon;
grant execute on function public.my_referee_matches(text) to authenticated;

revoke all on function public.respond_match_assignment(uuid, boolean, text) from public, anon;
grant execute on function public.respond_match_assignment(uuid, boolean, text) to authenticated;

revoke all on function public.referee_verify_lineup(uuid, uuid[], uuid[], text) from public, anon;
grant execute on function public.referee_verify_lineup(uuid, uuid[], uuid[], text) to authenticated;
```

---

## 4. Doğrulama ve Test Adımları

Migration yazıldıktan sonra Codex / ajan şu adımlarla doğrulamayı tamamlar:
1. `python tools/check_migrations.py` ile söz dizimi ve kilit kontrolleri (0 hata).
2. SSS kaydı ekleme: `python tools/check_faq.py` (39/39 yeşil).
3. Push route kontrolü: `python tools/check_push_routes.py` (40/40 yeşil).
4. `git diff --check` temiz çıktısı.
