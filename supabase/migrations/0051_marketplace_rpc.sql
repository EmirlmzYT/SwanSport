-- 0051 — Pazaryeri işlemleri
--
-- `create_listing` (0034) genişletilmedi, ayrı RPC yazıldı. Sebep iki tane:
--
--   1. O fonksiyon zaten 19 parametreli ve pazaryeri 12 alan daha getiriyor.
--      31 parametreli bir fonksiyonu doğru çağırmak imkânsıza yakın.
--   2. Geriye uyumluluk şartı: sporcu/iş/organizasyon ilanları ve o RPC'nin
--      mevcut çağrıları hiç etkilenmemeli. İmza değiştirmek 0034'ün kendi
--      yorumunda anlatılan `HTTP 300` tuzağını da geri getirirdi.
--
-- Ortak olan tek şey `listings` tablosu; iş mantıkları farklı.

-- ---------------------------------------------------------------------------
-- Pazaryeri ilanı oluştur
-- ---------------------------------------------------------------------------
create or replace function public.create_market_listing(
  p_title       text,
  p_body        text default null,
  p_store       uuid default null,
  p_sport       text default null,
  p_category    text default null,
  p_subcategory text default null,
  p_brand       text default null,
  p_model       text default null,
  p_size        text default null,
  p_color       text default null,
  p_condition   text default 'used',
  p_defect_note text default null,
  p_price       numeric default null,
  p_negotiable  boolean default false,
  p_stock       int default 1,
  p_delivery    text default 'hand_delivery',
  p_city        text default null,
  p_district    text default null,
  p_publish     boolean default true)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id     uuid;
  v_seller text;
  v_recent int;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if coalesce(trim(p_title), '') = '' then
    raise exception 'İlan başlığı boş olamaz';
  end if;

  -- ---- Satıcı türü ve yetkisi -------------------------------------------
  if p_store is not null then
    if not public.can_sell_new(p_store) then
      raise exception 'Bu mağaza adına ilan veremezsin (mağaza onaylı değil '
                      'ya da yöneticisi değilsin)';
    end if;
    v_seller := 'verified_store';
  else
    -- Bireysel satıcı yalnızca ikinci el yayınlayabilir.
    if p_condition = 'new' then
      raise exception 'Sıfır ürün yalnızca onaylı mağazalar tarafından '
                      'yayınlanabilir';
    end if;

    -- Kimlik doğrulaması: 0034'teki kural pazaryerinde de geçerli.
    if not public.has_approved_credential() then
      raise exception 'İlan verebilmek için onaylanmış bir belgen olmalı';
    end if;

    -- Hız sınırı: 24 saatte 5 ilan. Mağazalara uygulanmıyor; gerçek stoklu
    -- bir mağazanın günde beş üründen fazla yüklemesi normal.
    select count(*) into v_recent
      from public.listings
     where owner_id = auth.uid()
       and market_status is not null
       and store_id is null
       and created_at > now() - interval '24 hours';

    if v_recent >= 5 then
      raise exception 'Günde en fazla 5 ilan verebilirsin. Yarın tekrar dene.';
    end if;

    v_seller := 'individual';
  end if;

  -- ---- Tutarlılık --------------------------------------------------------
  if p_price is not null and p_price < 0 then
    raise exception 'Fiyat negatif olamaz';
  end if;

  insert into public.listings (
    kind, owner_id, title, body, sport_code, city_code, district,
    price, seller_type, store_id, item_condition, defect_note,
    category, subcategory, brand, model, size_label, color,
    negotiable, stock, delivery, market_status, status
  ) values (
    'equipment_sale',
    auth.uid(),
    trim(p_title),
    nullif(trim(coalesce(p_body, '')), ''),
    p_sport, p_city, p_district,
    p_price, v_seller, p_store, p_condition,
    nullif(trim(coalesce(p_defect_note, '')), ''),
    p_category, p_subcategory, p_brand, p_model, p_size, p_color,
    coalesce(p_negotiable, false),
    -- Bireysel ilanda stok her zaman 1: ikinci el ürün tektir ve stok alanı
    -- girdirmek kullanıcıyı anlamsız bir soruya maruz bırakır.
    case when v_seller = 'individual' then 1 else greatest(coalesce(p_stock, 1), 0) end,
    coalesce(p_delivery, 'hand_delivery'),
    case when p_publish then 'active' else 'draft' end,
    'open'
  )
  returning id into v_id;

  return v_id;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- İlan durumu değiştir — rezerve / satıldı / kaldır / yeniden yayınla
--
-- Ayrı RPC çünkü kimin neyi değiştirebileceği burada tek yerde duruyor.
-- Doğrudan `update` ile de yapılabilirdi ama o zaman "moderasyonla gizlenmiş
-- ilanı sahibi yeniden açabilir mi" sorusunun cevabı RLS'e gömülü kalırdı.
-- ---------------------------------------------------------------------------
create or replace function public.set_market_listing_status(
  p_listing uuid,
  p_status  text)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_owner uuid;
  v_store uuid;
  v_cur   text;
begin
  select owner_id, store_id, market_status
    into v_owner, v_store, v_cur
    from public.listings where id = p_listing;

  if v_owner is null then
    raise exception 'İlan bulunamadı';
  end if;

  if not (v_owner = auth.uid()
          or (v_store is not null and public.is_store_manager(v_store))
          or public.is_platform_admin()) then
    raise exception 'Bu ilanı değiştirme yetkin yok';
  end if;

  -- Sahibinin kullanabileceği durumlar. `under_review` ve
  -- `hidden_by_moderation` yalnızca platform yöneticisinin.
  if p_status not in ('draft', 'active', 'reserved', 'sold', 'removed_by_owner')
     and not public.is_platform_admin() then
    raise exception 'Geçersiz durum';
  end if;

  -- Moderasyonla gizlenmiş ilanı sahibi geri açamaz; açabilseydi moderasyon
  -- kararının hiçbir anlamı kalmazdı.
  if v_cur = 'hidden_by_moderation' and not public.is_platform_admin() then
    raise exception 'Bu ilan moderasyon tarafından gizlendi';
  end if;

  update public.listings
     set market_status = p_status,
         status = case when p_status = 'sold' then 'closed' else 'open' end
   where id = p_listing;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Pazaryeri araması
--
-- Sayfalama `(created_at, id)` çifti üzerinden: `offset` kullanmak, arada yeni
-- ilan eklenince sayfa sınırında ilan atlatıyor ya da tekrarlatıyor.
--
-- Arama `tr_contains` (0048) ile: kullanıcı "isiklar" yazınca "Işıklar"
-- bulunmalı.
-- ---------------------------------------------------------------------------
create or replace function public.search_market_listings(
  p_query      text default null,
  p_sport      text default null,
  p_category   text default null,
  p_city       text default null,
  p_district   text default null,
  p_condition  text default null,
  p_delivery   text default null,
  p_seller     text default null,      -- individual | verified_store
  p_brand      text default null,
  p_min_price  numeric default null,
  p_max_price  numeric default null,
  p_sort       text default 'new',     -- new | price_asc | price_desc
  p_after_at   timestamptz default null,
  p_after_id   uuid default null,
  p_limit      int default 20)
returns table (
  id            uuid,
  title         text,
  price         numeric,
  item_condition text,
  seller_type   text,
  store_id      uuid,
  store_name    text,
  city_code     text,
  district      text,
  delivery      text,
  market_status text,
  image_path    text,
  created_at    timestamptz)
language sql
stable
security definer
set search_path = public
as $fn$
  select l.id, l.title, l.price, l.item_condition, l.seller_type,
         l.store_id, s.name,
         l.city_code, l.district, l.delivery, l.market_status,
         (select i.image_path from public.listing_images i
           where i.listing_id = l.id
           order by i.sort_order limit 1),
         l.created_at
    from public.listings l
    left join public.stores s on s.id = l.store_id
   where l.market_status in ('active', 'reserved', 'sold')
     and (p_query     is null or public.tr_contains(l.title, p_query)
                              or public.tr_contains(coalesce(l.brand, ''), p_query))
     and (p_sport     is null or l.sport_code = p_sport)
     and (p_category  is null or l.category = p_category)
     and (p_city      is null or l.city_code = p_city)
     and (p_district  is null or l.district = p_district)
     and (p_condition is null or l.item_condition = p_condition)
     and (p_delivery  is null or l.delivery = p_delivery or l.delivery = 'both')
     and (p_seller    is null or l.seller_type = p_seller)
     and (p_brand     is null or public.tr_contains(coalesce(l.brand, ''), p_brand))
     and (p_min_price is null or l.price >= p_min_price)
     and (p_max_price is null or l.price <= p_max_price)
     -- İmleç: yalnızca "en yeni" sıralamasında anlamlı; fiyat sıralamasında
     -- istemci sayfa numarası yerine tam listeyi daraltarak ilerliyor.
     and (p_after_at is null
          or (l.created_at, l.id) < (p_after_at, p_after_id))
   order by
     case when p_sort = 'price_asc'  then l.price end asc nulls last,
     case when p_sort = 'price_desc' then l.price end desc nulls last,
     l.created_at desc, l.id desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$fn$;

revoke execute on function public.create_market_listing(
  text,text,uuid,text,text,text,text,text,text,text,text,text,
  numeric,boolean,int,text,text,text,boolean) from public, anon;
grant execute on function public.create_market_listing(
  text,text,uuid,text,text,text,text,text,text,text,text,text,
  numeric,boolean,int,text,text,text,boolean) to authenticated;

revoke execute on function public.set_market_listing_status(uuid, text) from public, anon;
grant execute on function public.set_market_listing_status(uuid, text) to authenticated;

-- Arama giriş yapmamış kullanıcıya da açık: pazaryerinin çekim gücü
-- görünür olmasına bağlı, mevcut ilan politikasıyla da tutarlı.
revoke execute on function public.search_market_listings(
  text,text,text,text,text,text,text,text,text,numeric,numeric,text,
  timestamptz,uuid,int) from public;
grant execute on function public.search_market_listings(
  text,text,text,text,text,text,text,text,text,numeric,numeric,text,
  timestamptz,uuid,int) to anon, authenticated;
