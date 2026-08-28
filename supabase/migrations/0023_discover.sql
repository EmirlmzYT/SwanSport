-- =============================================================================
-- SwanSport — FAZ 1: KULÜP KEŞFET
--
-- Kulüp künyesindeki il/ilçe/branş verisi zaten duruyordu ama hiçbir yerden
-- filtrelenemiyordu. Arama yalnızca isme bakıyordu.
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- Harita görünümü için hazırlık. Şimdilik doldurulmuyor; veri mimarisi hazır
-- olsun diye ekleniyor (istenen: "mümkünse harita görünümüne uygun veri").
alter table public.clubs
  add column if not exists latitude  numeric(9,6),
  add column if not exists longitude numeric(9,6);


-- ---------------------------------------------------------------------------
-- Kulüp keşfi — filtreli arama.
--
-- Tüm filtreler isteğe bağlı; boş geçilen filtre uygulanmaz. Sıralama
-- kasıtlı: onaylı kulüpler önce, sonra kadrosu kalabalık olanlar. Yeni açılmış
-- boş bir kulüp listenin başında durursa keşfetmenin anlamı kalmaz.
-- ---------------------------------------------------------------------------
create or replace function public.discover_clubs(
  p_query    text default null,
  p_city     text default null,   -- plaka kodu ('42') ya da il adı
  p_district text default null,
  p_sport    text default null,   -- sports.code
  p_verified boolean default false,
  p_limit    int default 40)
returns table (
  id            uuid,
  name          text,
  short_name    text,
  city          text,
  district      text,
  sport_name    text,
  logo_path     text,
  bio           text,
  status        text,
  athlete_count int,
  coach_count   int,
  is_following  boolean
)
language sql stable security definer set search_path = public as $$
  with city_name as (
    -- Plaka kodu da il adı da kabul edilir.
    select coalesce((select c.name from public.cities c where c.code = p_city),
                    p_city) as name
  )
  select
    c.id, c.name, c.short_name, c.city, c.district, s.name, c.logo_path, c.bio,
    c.status::text,
    (select count(*) from public.athletes a where a.club_id = c.id)::int,
    (select count(*) from public.club_memberships m
      where m.club_id = c.id and m.role = 'coach' and m.status = 'active')::int,
    exists (select 1 from public.follows f
             where f.follower_id = auth.uid()
               and f.target_type = 'club' and f.target_id = c.id)
  from public.clubs c
  left join public.sports s on s.code = c.sport_code
  cross join city_name cn
  where (p_query is null or trim(p_query) = ''
         or c.name ilike '%' || p_query || '%'
         or c.short_name ilike '%' || p_query || '%')
    and (cn.name is null or trim(cn.name) = ''
         or c.city ilike '%' || cn.name || '%')
    and (p_district is null or trim(p_district) = ''
         or c.district ilike '%' || p_district || '%')
    and (p_sport is null or trim(p_sport) = '' or c.sport_code = p_sport)
    and (not p_verified or c.status = 'active')
  order by (c.status = 'active') desc,
           (select count(*) from public.athletes a where a.club_id = c.id) desc,
           c.name
  limit greatest(p_limit, 1);
$$;


-- Filtre kutularını doldurmak için: hangi illerde ve branşlarda kulüp var?
-- Boş çıkacak bir filtreyi kullanıcıya sunmamak için kullanılır.
create or replace function public.club_filter_options()
returns table (kind text, code text, label text, club_count int)
language sql stable security definer set search_path = public as $$
  select 'city', c.city, c.city, count(*)::int
    from public.clubs c
   where c.city is not null and trim(c.city) <> ''
   group by c.city
  union all
  select 'sport', s.code, s.name, count(*)::int
    from public.clubs c
    join public.sports s on s.code = c.sport_code
   group by s.code, s.name
  order by 1, 4 desc, 3;
$$;
