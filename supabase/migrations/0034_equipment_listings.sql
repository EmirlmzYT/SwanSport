-- ---------------------------------------------------------------------------
-- 0034 — Malzeme ilanları (Marketplace)
--
-- Kulüpler malzeme alıp satıyor, ikinci elini elden çıkarıyor. Bunun için
-- ayrı bir "ürünler" tablosu açmıyoruz: `listings` panosu sahiplik, şehir ve
-- branş filtresi, arama ve kapatma akışıyla zaten hazır. `kind` düz `text`
-- olduğu için yeni tür eklemek şema değişikliği gerektirmiyor.
--
-- Yeni türler: equipment_sale (Satılık) · equipment_wanted (Aranıyor)
--
-- Bu bir ilan panosu; mağaza değil. Ödeme, kargo ve iade yok — taraflar
-- mevcut mesajlaşma üzerinden anlaşır.
-- ---------------------------------------------------------------------------

-- ============================ 1. Yeni sütunlar =============================

alter table public.listings
  add column if not exists price      numeric(12,2),
  add column if not exists condition  text,
  add column if not exists image_path text;

-- Fiyatın boş olması "pazarlıklı" demek; ayrı bir bayrak tutmuyoruz, aynı
-- bilgiyi iki yerde saklamak olurdu.
alter table public.listings drop constraint if exists listing_price_sane;
alter table public.listings add constraint listing_price_sane
  check (price is null or price >= 0);

alter table public.listings drop constraint if exists listing_condition_valid;
alter table public.listings add constraint listing_condition_valid
  check (condition is null or condition in ('new', 'used'));

-- ====================== 2. Kim ilan verebilir ==============================

-- Malzeme ilanı kişisel de olabilir. Eski kısıt yalnızca 'club_wanted'
-- türüne kulüpsüz izin veriyordu.
--
-- Kısıt gövdesi `alter` ile değiştirilemez; düşürüp yeniden ekliyoruz. Yeni
-- kural eskisinden gevşek olduğu için mevcut satırlar sorunsuz geçer.
alter table public.listings drop constraint if exists listing_owner_present;
alter table public.listings add constraint listing_owner_present
  check (club_id is not null
         or kind in ('club_wanted', 'equipment_sale', 'equipment_wanted'));

-- Kişisel ilanda "doğrulanmış olma" şartı. Bu predicate `search_listings`
-- içinde satır içi yazılıydı; tekrarlamak yerine yardımcıya çıkarıyoruz.
--
-- Marketplace'in en büyük derdi dolandırıcılık. Kimliği onaylanmamış birinin
-- kendi adına malzeme satmasına izin vermiyoruz — platformun tek gerçek
-- güven avantajı bu.
create or replace function public.has_approved_credential(
  p_profile uuid default auth.uid())
returns boolean
language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.profile_credentials
     where profile_id = p_profile and status = 'approved');
$fn$;

-- ========================= 3. create_listing ===============================

-- Yeni parametreler imzayı değiştiriyor. `create or replace` yalnızca AYNI
-- imzayı değiştirir; eski sürüm ayakta kalır, PostgREST iki aday görüp
-- HTTP 300 döner ve özellik sessizce kırılır. Bu depoda bir kez yaşandı.
drop function if exists public.create_listing(
  text, text, text, uuid, text, text, text, int, int, text, int,
  timestamptz, text, int, text, date);

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
  p_deadline   date default null,
  p_price      numeric default null,
  p_condition  text default null,
  p_image_path text default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_equipment boolean := p_kind in ('equipment_sale', 'equipment_wanted');
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  -- Kulüp adına ilan yalnızca kulüp yetkilisinden.
  if p_club is not null and not public.is_club_staff(p_club) then
    raise exception 'Bu kulüp adına ilan veremezsin';
  end if;

  -- Kulüp arayan ve malzeme ilanları kişiye ait olabilir; diğerleri kulübe.
  if p_club is null
     and p_kind <> 'club_wanted'
     and not v_equipment then
    raise exception 'Bu ilan türü için kulüp gerekiyor';
  end if;

  -- Kişisel malzeme ilanında kimlik doğrulaması şart. Kulüp adına verilen
  -- ilanda kulübün kendisi zaten onaylı.
  if v_equipment and p_club is null and not public.has_approved_credential() then
    raise exception 'Kişisel malzeme ilanı için onaylanmış bir belgen olmalı';
  end if;

  -- Fiyat yalnızca satılık ilanda anlamlı; "aranıyor" ilanına yazılmış
  -- fiyat karşı tarafı yanıltır.
  if p_price is not null and p_kind <> 'equipment_sale' then
    raise exception 'Fiyat yalnızca satılık ilanda kullanılır';
  end if;

  insert into public.listings
    (kind, club_id, owner_id, title, body, sport_code, city_code, district,
     age_min, age_max, "position", coach_level_min,
     starts_at, location, quota, requirements, deadline,
     price, condition, image_path)
  values (p_kind, p_club, auth.uid(), p_title, p_body, p_sport, p_city,
          p_district, p_age_min, p_age_max, p_position, p_level_min,
          p_starts_at, p_location, p_quota, p_requirements, p_deadline,
          p_price, p_condition, p_image_path)
  returning id into v_id;

  return v_id;
end; $$;

-- ========================= 4. search_listings ==============================

-- Dönüş tablosuna üç sütun ekleniyor. Dönüş tipi değiştiği için `create or
-- replace` çalışmaz — düşürmek zorunlu (yukarıdaki HTTP 300 tuzağı).
drop function if exists public.search_listings(
  text, text, text, text, int, boolean, text, int);

create or replace function public.search_listings(
  p_kind      text default null,
  p_sport     text default null,
  p_city      text default null,
  p_district  text default null,
  p_level     int default null,      -- en az bu kademe
  p_verified  boolean default false, -- yalnızca doğrulanmış hesapların ilanları
  p_query     text default null,
  p_limit     int default 40,
  p_price_max numeric default null)
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
  price numeric, condition text, image_path text,
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
    l.price, l.condition, l.image_path,
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
    -- Fiyat süzgeci: fiyatı belirtilmemiş ("pazarlıklı") ilanlar elenmez,
    -- aksi halde tavan verildiği anda pazarlığa açık ilanlar kaybolurdu.
    and (p_price_max is null or l.price is null or l.price <= p_price_max)
    -- "Doğrulanmış" filtresi: kulüp ilanında kulüp onaylı, kişi ilanında
    -- kişinin onaylı bir kimliği olmalı.
    and (not p_verified
         or (l.club_id is not null and c.status = 'active')
         or (l.club_id is null and public.has_approved_credential(l.owner_id)))
  order by l.created_at desc
  limit greatest(p_limit, 1);
$$;

-- ========================= 5. İzinler ======================================

-- 0028'in dersi: izin PUBLIC'ten miras alınır. Yalnızca anon'dan almak
-- yetmez, `public` rolü de düşürülmeli. 0025 bu iki fonksiyonda hiç revoke
-- yapmamıştı; yeniden yazarken kapatıyoruz.
revoke execute on function public.create_listing(
  text, text, text, uuid, text, text, text, int, int, text, int,
  timestamptz, text, int, text, date, numeric, text, text) from public, anon;

revoke execute on function public.search_listings(
  text, text, text, text, int, boolean, text, int, numeric) from public, anon;

-- has_approved_credential yalnızca "onaylı belgesi var mı" sorusuna evet/hayır
-- döner; belge içeriği ya da türü sızmaz. Yine de anon'a kapalı: hangi
-- profilin doğrulandığı giriş yapmamış birini ilgilendirmez.
revoke execute on function public.has_approved_credential(uuid) from public, anon;
