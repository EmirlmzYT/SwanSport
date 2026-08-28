-- =============================================================================
-- SwanSport — FAZ 3: İLANLAR VE SEÇMELER
--
-- Dört ihtiyaç tek tabloda toplanıyor:
--   • Kulüp sporcu arıyor            (athlete_wanted)
--   • Kulüp antrenör arıyor          (coach_wanted)
--   • Sporcu/antrenör kulüp arıyor   (club_wanted)
--   • Kulüp seçme yapıyor            (tryout)
--
-- Seçme için ayrı modül açılmadı: seçme de bir ilandır, yalnızca tarih, konum
-- ve kontenjan alanları dolu olan bir ilan. Ayrı tablo, aynı filtreleri ve
-- başvuru akışını ikinci kez yazmak demekti.
--
-- Başvuru kabul edilince mevcut üyelik akışına bağlanır — paralel bir üyelik
-- sistemi kurulmuyor.
-- =============================================================================


create table if not exists public.listings (
  id           uuid primary key default gen_random_uuid(),
  kind         text not null,          -- athlete_wanted | coach_wanted | club_wanted | tryout
  -- Sahibi ya bir kulüptür ya da bir kişi; ikisinden biri dolu olmalı.
  club_id      uuid references public.clubs(id) on delete cascade,
  owner_id     uuid not null references public.profiles(id) on delete cascade,

  title        text not null,
  body         text,
  sport_code   text references public.sports(code),
  city_code    text references public.cities(code),
  district     text,

  -- Filtre alanları (branşa göre bir kısmı boş kalabilir)
  age_min      int,
  age_max      int,
  position     text,                   -- mevki (uygun branşlarda)
  coach_level_min int,                 -- antrenör ilanlarında aranan kademe

  -- Seçme alanları
  starts_at    timestamptz,
  location     text,
  quota        int,
  requirements text,

  deadline     date,
  status       text not null default 'open',   -- open | closed
  created_at   timestamptz not null default now(),

  constraint listing_owner_present
    check (club_id is not null or kind = 'club_wanted')
);

create index if not exists idx_listing_open
  on public.listings (status, kind, created_at desc);
create index if not exists idx_listing_filter
  on public.listings (sport_code, city_code, status);

alter table public.listings enable row level security;

-- İlanlar herkese açık: ağın çekim gücü görünür olmasına bağlı.
drop policy if exists "listing_read" on public.listings;
create policy "listing_read" on public.listings for select
  to authenticated using (true);

-- Yazma RPC üzerinden; doğrudan insert kapalı (yetki ve tutarlılık için).


create table if not exists public.listing_applications (
  id           uuid primary key default gen_random_uuid(),
  listing_id   uuid not null references public.listings(id) on delete cascade,
  applicant_id uuid not null references public.profiles(id) on delete cascade,
  note         text,
  status       text not null default 'pending',  -- pending | accepted | rejected
  reviewed_by  uuid references public.profiles(id) on delete set null,
  reviewed_at  timestamptz,
  created_at   timestamptz not null default now(),
  unique (listing_id, applicant_id)
);

create index if not exists idx_listing_app
  on public.listing_applications (listing_id, status);

alter table public.listing_applications enable row level security;

-- Başvuruyu yalnızca başvuran ve ilan sahibi görür.
drop policy if exists "listing_app_read" on public.listing_applications;
create policy "listing_app_read" on public.listing_applications for select
  to authenticated
  using (
    applicant_id = auth.uid()
    or exists (select 1 from public.listings l
                where l.id = listing_id
                  and (l.owner_id = auth.uid()
                       or (l.club_id is not null
                           and public.is_club_staff(l.club_id))))
  );


-- ---------------------------------------------------------------------------
-- İlan oluşturma
-- ---------------------------------------------------------------------------
create or replace function public.create_listing(
  p_kind       text,
  p_title      text,
  p_body       text default null,
  p_club       uuid default null,
  p_sport      text default null,
  p_city       text default null,
  p_district   text default null,
  p_age_min    int default null,
  p_age_max    int default null,
  p_position   text default null,
  p_level_min  int default null,
  p_starts_at  timestamptz default null,
  p_location   text default null,
  p_quota      int default null,
  p_requirements text default null,
  p_deadline   date default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  -- Kulüp adına ilan yalnızca kulüp yetkilisinden.
  if p_club is not null and not public.is_club_staff(p_club) then
    raise exception 'Bu kulüp adına ilan veremezsin';
  end if;

  -- Kulüp arayan ilanı kişiye aittir; diğer türler kulübe.
  if p_kind <> 'club_wanted' and p_club is null then
    raise exception 'Bu ilan türü için kulüp gerekiyor';
  end if;

  insert into public.listings
    (kind, club_id, owner_id, title, body, sport_code, city_code, district,
     age_min, age_max, "position", coach_level_min,
     starts_at, location, quota, requirements, deadline)
  values (p_kind, p_club, auth.uid(), p_title, p_body, p_sport, p_city,
          p_district, p_age_min, p_age_max, p_position, p_level_min,
          p_starts_at, p_location, p_quota, p_requirements, p_deadline)
  returning id into v_id;

  return v_id;
end; $$;


create or replace function public.close_listing(p_listing uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_row record;
begin
  select * into v_row from public.listings where id = p_listing;
  if v_row is null then raise exception 'İlan bulunamadı'; end if;

  if not (v_row.owner_id = auth.uid()
          or (v_row.club_id is not null and public.is_club_staff(v_row.club_id))) then
    raise exception 'Yetkisiz';
  end if;

  update public.listings set status = 'closed' where id = p_listing;
end; $$;


-- ---------------------------------------------------------------------------
-- Arama — tüm filtreler isteğe bağlı
-- ---------------------------------------------------------------------------
create or replace function public.search_listings(
  p_kind     text default null,
  p_sport    text default null,
  p_city     text default null,
  p_district text default null,
  p_level    int default null,     -- en az bu kademe
  p_verified boolean default false, -- yalnızca doğrulanmış hesapların ilanları
  p_query    text default null,
  p_limit    int default 40)
returns table (
  id uuid, kind text, title text, body text,
  club_id uuid, club_name text, club_logo text,
  owner_id uuid, owner_name text, owner_avatar text,
  sport_name text, city_name text, district text,
  -- NOT: 'position' PostgreSQL'de ayrılmış sözcük; çıktı sütunu olarak
  -- kullanılamıyor. Tablodaki sütun adı `position` olarak kalıyor, yalnızca
  -- fonksiyonun döndürdüğü ad değişti.
  age_min int, age_max int, position_name text, coach_level_min int,
  starts_at timestamptz, location text, quota int, deadline date,
  application_count int, applied boolean, can_manage boolean,
  created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select
    l.id, l.kind, l.title, l.body,
    l.club_id, c.name, c.logo_path,
    l.owner_id, p.full_name, p.avatar_path,
    s.name, ct.name, l.district,
    l.age_min, l.age_max, l.position, l.coach_level_min,
    l.starts_at, l.location, l.quota, l.deadline,
    (select count(*) from public.listing_applications a
      where a.listing_id = l.id)::int,
    exists (select 1 from public.listing_applications a
             where a.listing_id = l.id and a.applicant_id = auth.uid()),
    (l.owner_id = auth.uid()
     or (l.club_id is not null and public.is_club_staff(l.club_id))),
    l.created_at
  from public.listings l
  left join public.clubs c on c.id = l.club_id
  join public.profiles p on p.id = l.owner_id
  left join public.sports s on s.code = l.sport_code
  left join public.cities ct on ct.code = l.city_code
  where l.status = 'open'
    and (l.deadline is null or l.deadline >= current_date)
    and (p_kind is null or l.kind = p_kind)
    and (p_sport is null or l.sport_code = p_sport)
    and (p_city is null or l.city_code = p_city)
    and (p_district is null or trim(p_district) = ''
         or l.district ilike '%' || p_district || '%')
    and (p_level is null or coalesce(l.coach_level_min, 0) <= p_level)
    and (p_query is null or trim(p_query) = ''
         or l.title ilike '%' || p_query || '%'
         or l.body ilike '%' || p_query || '%')
    -- "Doğrulanmış" filtresi: kulüp ilanında kulüp onaylı, kişi ilanında
    -- kişinin onaylı bir kimliği olmalı.
    and (not p_verified
         or (l.club_id is not null and c.status = 'active')
         or (l.club_id is null and exists (
               select 1 from public.profile_credentials pc
                where pc.profile_id = l.owner_id and pc.status = 'approved')))
  order by l.created_at desc
  limit greatest(p_limit, 1);
$$;


-- ---------------------------------------------------------------------------
-- Başvuru
-- ---------------------------------------------------------------------------
create or replace function public.apply_to_listing(
  p_listing uuid, p_note text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_row record;
  v_id  uuid;
  v_name text;
begin
  select * into v_row from public.listings where id = p_listing;
  if v_row is null then raise exception 'İlan bulunamadı'; end if;
  if v_row.status <> 'open' then raise exception 'İlan kapanmış'; end if;
  if v_row.owner_id = auth.uid() then
    raise exception 'Kendi ilanına başvuramazsın';
  end if;

  insert into public.listing_applications (listing_id, applicant_id, note)
  values (p_listing, auth.uid(), p_note)
  on conflict (listing_id, applicant_id) do update set note = excluded.note
  returning id into v_id;

  select full_name into v_name from public.profiles where id = auth.uid();

  -- İlan sahibine haber ver.
  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (v_row.owner_id, 'application',
          'İlanına başvuru geldi',
          coalesce(v_name, 'Bir kullanıcı') || ' · ' || v_row.title,
          auth.uid(), 'listing', p_listing);

  return v_id;
end; $$;


create or replace function public.review_listing_application(
  p_application uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_app  record;
  v_list record;
begin
  select * into v_app from public.listing_applications where id = p_application;
  if v_app is null then raise exception 'Başvuru bulunamadı'; end if;

  select * into v_list from public.listings where id = v_app.listing_id;
  if not (v_list.owner_id = auth.uid()
          or (v_list.club_id is not null and public.is_club_staff(v_list.club_id))) then
    raise exception 'Yetkisiz';
  end if;

  update public.listing_applications
     set status = case when p_accept then 'accepted' else 'rejected' end,
         reviewed_by = auth.uid(), reviewed_at = now()
   where id = p_application;

  -- Başvurana sonucu bildir. Kabul edildiyse üyelik akışı kulüp tarafından
  -- yürütülür (mevcut teklif/başvuru sistemi) — burada ikinci bir üyelik
  -- mekanizması kurulmuyor.
  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (v_app.applicant_id, 'application',
          case when p_accept then 'Başvurun kabul edildi'
               else 'Başvurun olumsuz sonuçlandı' end,
          v_list.title, auth.uid(), 'listing', v_list.id);
end; $$;


-- İlana gelen başvurular (ilan sahibi için).
create or replace function public.listing_applicants(p_listing uuid)
returns table (
  id uuid, applicant_id uuid, name text, username text, avatar_path text,
  credentials text, city_name text, note text, status text,
  created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select a.id, a.applicant_id, p.full_name, p.username, p.avatar_path,
         (select string_agg(
                   case when c.kind = 'coach'
                        then coalesce(s.name || ' · ','') ||
                             coalesce(c.coach_level::text,'?') || '. Kademe'
                        else 'Sporcu' end, ', ')
            from public.profile_credentials c
            left join public.sports s on s.code = c.sport_code
           where c.profile_id = p.id and c.status = 'approved'),
         ct.name, a.note, a.status, a.created_at
    from public.listing_applications a
    join public.profiles p on p.id = a.applicant_id
    left join public.cities ct on ct.code = p.city_code
    join public.listings l on l.id = a.listing_id
   where a.listing_id = p_listing
     and (l.owner_id = auth.uid()
          or (l.club_id is not null and public.is_club_staff(l.club_id)))
   order by a.created_at;
$$;


-- Kişinin kendi ilanları ve başvuruları.
create or replace function public.my_listings()
returns table (
  id uuid, kind text, title text, status text,
  application_count int, pending_count int, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select l.id, l.kind, l.title, l.status,
         (select count(*) from public.listing_applications a
           where a.listing_id = l.id)::int,
         (select count(*) from public.listing_applications a
           where a.listing_id = l.id and a.status = 'pending')::int,
         l.created_at
    from public.listings l
   where l.owner_id = auth.uid()
      or (l.club_id is not null and public.is_club_staff(l.club_id))
   order by l.created_at desc;
$$;
