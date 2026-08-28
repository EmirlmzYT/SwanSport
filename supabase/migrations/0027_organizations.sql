-- =============================================================================
-- SwanSport — FAZ 6 & 7: ORGANİZASYONLAR, KULÜP MESAJI, ETKİNLİK BAŞVURUSU
--
-- Turnuva/lig tek bir spor dalına göre kurgulanmadı: puan sistemi ve eleme
-- yapısı organizasyonun kendi ayarlarından gelir. Maçlar mevcut `events`
-- tablosuna da yazılabilir — takvim ikinci kez yazılmıyor.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) ORGANİZASYON
-- ---------------------------------------------------------------------------
create table if not exists public.organizations (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid references public.clubs(id) on delete cascade,  -- düzenleyen
  owner_id    uuid not null references public.profiles(id) on delete cascade,
  name        text not null,
  kind        text not null default 'league',   -- league | tournament | cup
  sport_code  text references public.sports(code),
  city_code   text references public.cities(code),
  district    text,
  age_group   text,                              -- "U-16", "Büyükler"
  starts_on   date,
  ends_on     date,
  location    text,
  description text,
  -- Puan kuralı branşa göre değişir (voleybolda 3-2-1-0, futbolda 3-1-0).
  win_points  int not null default 3,
  draw_points int not null default 1,
  loss_points int not null default 0,
  is_public   boolean not null default true,
  status      text not null default 'open',     -- open | running | finished
  created_at  timestamptz not null default now()
);

create index if not exists idx_org_public
  on public.organizations (is_public, status, starts_on desc);

alter table public.organizations enable row level security;

drop policy if exists "org_read" on public.organizations;
create policy "org_read" on public.organizations for select
  to authenticated
  using (is_public or owner_id = auth.uid()
         or (club_id is not null and public.is_club_member(club_id)));


-- Katılımcı: bir kulüp takımı ya da serbest isim (dışarıdan katılan takım).
create table if not exists public.org_participants (
  id       uuid primary key default gen_random_uuid(),
  org_id   uuid not null references public.organizations(id) on delete cascade,
  club_id  uuid references public.clubs(id) on delete set null,
  team_id  uuid references public.teams(id) on delete set null,
  name     text not null,
  status   text not null default 'accepted',   -- pending | accepted | rejected
  created_at timestamptz not null default now()
);

create index if not exists idx_org_part on public.org_participants (org_id, status);

alter table public.org_participants enable row level security;

drop policy if exists "org_part_read" on public.org_participants;
create policy "org_part_read" on public.org_participants for select
  to authenticated using (true);


-- Maç. `event_id` doluysa aynı maç kulübün takviminde de görünür.
create table if not exists public.org_matches (
  id         uuid primary key default gen_random_uuid(),
  org_id     uuid not null references public.organizations(id) on delete cascade,
  round      int,
  home_id    uuid references public.org_participants(id) on delete cascade,
  away_id    uuid references public.org_participants(id) on delete cascade,
  starts_at  timestamptz,
  location   text,
  home_score int,
  away_score int,
  status     text not null default 'scheduled',  -- scheduled | played | cancelled
  event_id   uuid references public.events(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_org_match on public.org_matches (org_id, round, starts_at);

alter table public.org_matches enable row level security;

drop policy if exists "org_match_read" on public.org_matches;
create policy "org_match_read" on public.org_matches for select
  to authenticated using (true);


-- Düzenleyici mi?
create or replace function public.is_org_owner(p_org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.organizations o
     where o.id = p_org
       and (o.owner_id = auth.uid()
            or (o.club_id is not null and public.is_club_staff(o.club_id)))
  );
$$;


create or replace function public.create_organization(
  p_name text, p_kind text default 'league', p_club uuid default null,
  p_sport text default null, p_city text default null, p_district text default null,
  p_age text default null, p_starts date default null, p_ends date default null,
  p_location text default null, p_description text default null,
  p_win int default 3, p_draw int default 1, p_loss int default 0)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;
  if p_club is not null and not public.is_club_staff(p_club) then
    raise exception 'Bu kulüp adına organizasyon açamazsın';
  end if;

  insert into public.organizations
    (club_id, owner_id, name, kind, sport_code, city_code, district, age_group,
     starts_on, ends_on, location, description, win_points, draw_points, loss_points)
  values (p_club, auth.uid(), p_name, p_kind, p_sport, p_city, p_district, p_age,
          p_starts, p_ends, p_location, p_description, p_win, p_draw, p_loss)
  returning id into v_id;

  return v_id;
end; $$;


-- Katılım başvurusu: kulüp kendi takımıyla katılmak ister.
create or replace function public.join_organization(
  p_org uuid, p_club uuid default null, p_team uuid default null,
  p_name text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text;
begin
  if p_club is not null and not public.is_club_staff(p_club) then
    raise exception 'Yetkisiz';
  end if;

  v_name := coalesce(nullif(p_name, ''),
                     (select t.name from public.teams t where t.id = p_team),
                     (select c.name from public.clubs c where c.id = p_club),
                     'Katılımcı');

  insert into public.org_participants (org_id, club_id, team_id, name, status)
  values (p_org, p_club, p_team, v_name,
          case when public.is_org_owner(p_org) then 'accepted' else 'pending' end)
  returning id into v_id;

  return v_id;
end; $$;


create or replace function public.review_participant(
  p_participant uuid, p_accept boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_org uuid;
begin
  select org_id into v_org from public.org_participants where id = p_participant;
  if not public.is_org_owner(v_org) then raise exception 'Yetkisiz'; end if;

  update public.org_participants
     set status = case when p_accept then 'accepted' else 'rejected' end
   where id = p_participant;
end; $$;


-- ---------------------------------------------------------------------------
-- 2) FİKSTÜR
--
-- Tek devreli lig fikstürü (round-robin). Tek sayıda takım varsa her turda
-- biri bay geçer — o tur için maç üretilmez.
-- ---------------------------------------------------------------------------
create or replace function public.generate_fixture(
  p_org uuid, p_start date default null, p_days_between int default 7)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_ids   uuid[];
  v_n     int;
  v_round int;
  v_i     int;
  v_home  uuid;
  v_away  uuid;
  v_count int := 0;
  v_date  date;
begin
  if not public.is_org_owner(p_org) then raise exception 'Yetkisiz'; end if;

  select array_agg(id order by created_at) into v_ids
    from public.org_participants
   where org_id = p_org and status = 'accepted';

  v_n := coalesce(array_length(v_ids, 1), 0);
  if v_n < 2 then raise exception 'En az iki katılımcı gerekiyor'; end if;

  -- Var olan fikstürü temizle (yalnızca oynanmamışları).
  delete from public.org_matches
   where org_id = p_org and status = 'scheduled';

  -- Tek sayıdaysa bir "boş" yer eklenir; o eşleşme atlanır.
  if v_n % 2 = 1 then
    v_ids := v_ids || array[null::uuid];
    v_n := v_n + 1;
  end if;

  v_date := coalesce(p_start, current_date + 7);

  for v_round in 1..(v_n - 1) loop
    for v_i in 1..(v_n / 2) loop
      v_home := v_ids[v_i];
      v_away := v_ids[v_n + 1 - v_i];

      if v_home is not null and v_away is not null then
        insert into public.org_matches
          (org_id, round, home_id, away_id, starts_at)
        values (p_org, v_round, v_home, v_away,
                (v_date + (v_round - 1) * p_days_between)::timestamptz
                  + interval '18 hours');
        v_count := v_count + 1;
      end if;
    end loop;

    -- Berger dönüşü: ilk takım sabit, diğerleri saat yönünde kayar.
    v_ids := array[v_ids[1]] || array[v_ids[v_n]] ||
             v_ids[2:v_n - 1];
  end loop;

  update public.organizations set status = 'running' where id = p_org;
  return v_count;
end; $$;


create or replace function public.set_match_result(
  p_match uuid, p_home int, p_away int)
returns void language plpgsql security definer set search_path = public as $$
declare v_org uuid;
begin
  select org_id into v_org from public.org_matches where id = p_match;
  if not public.is_org_owner(v_org) then raise exception 'Yetkisiz'; end if;

  update public.org_matches
     set home_score = p_home, away_score = p_away, status = 'played'
   where id = p_match;
end; $$;


-- ---------------------------------------------------------------------------
-- 3) PUAN DURUMU
--
-- Puanlar organizasyonun kendi kuralından hesaplanır; hiçbir branş
-- sabitlenmiyor.
-- ---------------------------------------------------------------------------
create or replace function public.org_standings(p_org uuid)
returns table (
  participant_id uuid, name text, club_id uuid,
  played int, won int, drawn int, lost int,
  scored int, conceded int, diff int, points int
)
language sql stable security definer set search_path = public as $$
  with cfg as (select win_points w, draw_points d, loss_points l
                 from public.organizations where id = p_org),
  games as (
    select m.home_id as pid, m.home_score as gf, m.away_score as ga
      from public.org_matches m
     where m.org_id = p_org and m.status = 'played'
       and m.home_score is not null and m.away_score is not null
    union all
    select m.away_id, m.away_score, m.home_score
      from public.org_matches m
     where m.org_id = p_org and m.status = 'played'
       and m.home_score is not null and m.away_score is not null
  ),
  agg as (
    select g.pid,
           count(*)::int as played,
           count(*) filter (where g.gf > g.ga)::int as won,
           count(*) filter (where g.gf = g.ga)::int as drawn,
           count(*) filter (where g.gf < g.ga)::int as lost,
           coalesce(sum(g.gf), 0)::int as scored,
           coalesce(sum(g.ga), 0)::int as conceded
      from games g group by g.pid
  )
  select p.id, p.name, p.club_id,
         coalesce(a.played, 0), coalesce(a.won, 0), coalesce(a.drawn, 0),
         coalesce(a.lost, 0), coalesce(a.scored, 0), coalesce(a.conceded, 0),
         coalesce(a.scored, 0) - coalesce(a.conceded, 0),
         (coalesce(a.won,0) * (select w from cfg)
          + coalesce(a.drawn,0) * (select d from cfg)
          + coalesce(a.lost,0) * (select l from cfg))::int
    from public.org_participants p
    left join agg a on a.pid = p.id
   where p.org_id = p_org and p.status = 'accepted'
   -- Sıralama: puan (11), averaj (10), atılan (8). Çıktı 11 sütun.
   order by 11 desc, 10 desc, 8 desc, p.name;
$$;


-- Organizasyon listesi (keşif için) ve fikstür.
create or replace function public.list_organizations(
  p_sport text default null, p_city text default null,
  p_kind text default null, p_limit int default 40)
returns table (
  id uuid, name text, kind text, sport_name text, city_name text,
  age_group text, starts_on date, ends_on date, status text,
  club_id uuid, club_name text, participant_count int, can_manage boolean
)
language sql stable security definer set search_path = public as $$
  select o.id, o.name, o.kind, s.name, ct.name, o.age_group,
         o.starts_on, o.ends_on, o.status, o.club_id, c.name,
         (select count(*) from public.org_participants p
           where p.org_id = o.id and p.status = 'accepted')::int,
         public.is_org_owner(o.id)
    from public.organizations o
    left join public.sports s on s.code = o.sport_code
    left join public.cities ct on ct.code = o.city_code
    left join public.clubs c on c.id = o.club_id
   where (o.is_public or public.is_org_owner(o.id))
     and (p_sport is null or o.sport_code = p_sport)
     and (p_city is null or o.city_code = p_city)
     and (p_kind is null or o.kind = p_kind)
   order by (o.status <> 'finished') desc, o.starts_on desc nulls last
   limit greatest(p_limit, 1);
$$;


create or replace function public.org_fixture(p_org uuid)
returns table (
  id uuid, round int, starts_at timestamptz, status text,
  home_id uuid, home_name text, away_id uuid, away_name text,
  home_score int, away_score int, can_manage boolean
)
language sql stable security definer set search_path = public as $$
  select m.id, m.round, m.starts_at, m.status,
         m.home_id, h.name, m.away_id, a.name,
         m.home_score, m.away_score, public.is_org_owner(m.org_id)
    from public.org_matches m
    left join public.org_participants h on h.id = m.home_id
    left join public.org_participants a on a.id = m.away_id
   where m.org_id = p_org
   order by m.round, m.starts_at;
$$;


-- ---------------------------------------------------------------------------
-- 4) KULÜP ADINA MESAJ
--
-- İkinci bir mesajlaşma sistemi kurulmuyor: mevcut birebir mesajlaşmaya
-- "gönderen kulüp" bilgisi ekleniyor. Kulüpler arası yazışma da bu kanaldan
-- yürür — alıcı, karşı kulübün yetkilisidir.
-- ---------------------------------------------------------------------------
alter table public.direct_messages
  add column if not exists sender_club_id uuid references public.clubs(id) on delete set null;


create or replace function public.send_club_message(
  p_club uuid, p_recipient uuid, p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_name text;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Bu kulüp adına mesaj gönderemezsin';
  end if;
  if p_body is null or trim(p_body) = '' then
    raise exception 'Boş mesaj';
  end if;

  insert into public.direct_messages (sender_id, recipient_id, body, sender_club_id)
  values (auth.uid(), p_recipient, trim(p_body), p_club)
  returning id into v_id;

  select name into v_name from public.clubs where id = p_club;

  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (p_recipient, 'message', v_name || ' size yazdı',
          left(trim(p_body), 120), auth.uid(), 'message', v_id);

  return v_id;
end; $$;


-- ---------------------------------------------------------------------------
-- 5) ETKİNLİK BAŞVURUSU (eğitim / seminer / kamp)
--
-- Yeni bir etkinlik tablosu açılmıyor: mevcut `events` herkese açık hale
-- getirilebiliyor ve kontenjan tutabiliyor.
-- ---------------------------------------------------------------------------
alter table public.events
  add column if not exists is_public   boolean not null default false,
  add column if not exists capacity    int,
  add column if not exists reg_deadline date,
  add column if not exists description text;

create table if not exists public.event_registrations (
  id         uuid primary key default gen_random_uuid(),
  event_id   uuid not null references public.events(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  note       text,
  status     text not null default 'registered', -- registered | cancelled
  created_at timestamptz not null default now(),
  unique (event_id, profile_id)
);

alter table public.event_registrations enable row level security;

drop policy if exists "event_reg_read" on public.event_registrations;
create policy "event_reg_read" on public.event_registrations for select
  to authenticated
  using (profile_id = auth.uid()
         or exists (select 1 from public.events e
                     where e.id = event_id and public.is_club_staff(e.club_id)));


create or replace function public.register_for_event(
  p_event uuid, p_note text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_e record; v_taken int; v_id uuid;
begin
  select * into v_e from public.events where id = p_event;
  if v_e is null then raise exception 'Etkinlik bulunamadı'; end if;
  if not v_e.is_public then raise exception 'Bu etkinlik başvuruya açık değil'; end if;
  if v_e.reg_deadline is not null and v_e.reg_deadline < current_date then
    raise exception 'Başvuru süresi doldu';
  end if;

  if v_e.capacity is not null then
    select count(*) into v_taken from public.event_registrations
     where event_id = p_event and status = 'registered';
    if v_taken >= v_e.capacity then raise exception 'Kontenjan dolu'; end if;
  end if;

  insert into public.event_registrations (event_id, profile_id, note)
  values (p_event, auth.uid(), p_note)
  on conflict (event_id, profile_id) do update
    set status = 'registered', note = excluded.note
  returning id into v_id;

  return v_id;
end; $$;


create or replace function public.public_events(
  p_sport text default null, p_city text default null, p_limit int default 40)
returns table (
  id uuid, title text, kind text, description text,
  starts_at timestamptz, place text, club_id uuid, club_name text,
  city text, capacity int, taken int, reg_deadline date, registered boolean
)
language sql stable security definer set search_path = public as $$
  select e.id, e.title, e.kind::text, e.description, e.starts_at, e.place,
         e.club_id, c.name, c.city, e.capacity,
         (select count(*) from public.event_registrations r
           where r.event_id = e.id and r.status = 'registered')::int,
         e.reg_deadline,
         exists (select 1 from public.event_registrations r
                  where r.event_id = e.id and r.profile_id = auth.uid()
                    and r.status = 'registered')
    from public.events e
    join public.clubs c on c.id = e.club_id
   where e.is_public
     and e.starts_at >= now()
     and (p_city is null or c.city ilike '%' || p_city || '%')
     and (p_sport is null or c.sport_code = p_sport)
   order by e.starts_at
   limit greatest(p_limit, 1);
$$;
