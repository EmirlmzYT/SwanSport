-- 0052 — Engelleme gerçekten engellesin + pazaryeri bildirimleri
--
-- BULGU: `blocks` tablosu 0012'den beri var ama **hiçbir yerde
-- uygulanmıyor.** `dm_send` politikası yalnızca `sender_id = auth.uid()`
-- kontrol ediyor; engellediğin kişi sana mesaj atmaya devam edebiliyor.
-- Kullanıcı "engelledim" diyor, sistem engellemiyor — en kötü tür sessiz
-- hata, çünkü kullanıcı korunduğunu sanıyor.
--
-- Pazaryeri bunu zorunlu kıldı: yabancılarla mesajlaşılan bir yerde
-- engellemenin işlemesi şart.

-- ---------------------------------------------------------------------------
-- 1) Engelleme kontrolü
-- ---------------------------------------------------------------------------
create or replace function public.is_blocked_between(p_a uuid, p_b uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.blocks
     where (blocker_id = p_a and blocked_id = p_b)
        or (blocker_id = p_b and blocked_id = p_a));
$$;

comment on function public.is_blocked_between(uuid, uuid) is
  'İki yön de kontrol ediliyor: A B''yi engellediyse B de A''ya yazamaz. '
  'Tek yönlü olsaydı engellenen kişi konuşmayı sürdürebilirdi.';

-- ---------------------------------------------------------------------------
-- 2) Engellenen kişiye mesaj gönderilemesin
--
-- Mevcut sohbet için davranış: **yeni mesaj engelleniyor.** Geçmiş mesajlar
-- duruyor — silmek, iki tarafın da kaydını yok etmek olurdu ve engelleme
-- bir silme aracı değil.
--
-- Karşı taraf engellendiğine dair bildirim ALMIYOR. Bildirim gitseydi
-- engelleme, taciz eden kişiye "beni engelledi" sinyali vererek başka
-- kanaldan devam etmesini kolaylaştırırdı.
-- ---------------------------------------------------------------------------
drop policy if exists "dm_send" on public.direct_messages;
create policy "dm_send" on public.direct_messages for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and not public.is_blocked_between(sender_id, recipient_id)
  );

-- ---------------------------------------------------------------------------
-- 3) Engellenen kişinin ilanları aramada görünmesin
--
-- `search_market_listings` yeniden yazılıyor; tek eklenen şart engelleme.
-- Fonksiyon `security definer` ve RLS'i atlıyor, o yüzden kontrol burada
-- olmak zorunda.
-- ---------------------------------------------------------------------------
create or replace function public.search_market_listings(
  p_query      text default null,
  p_sport      text default null,
  p_category   text default null,
  p_city       text default null,
  p_district   text default null,
  p_condition  text default null,
  p_delivery   text default null,
  p_seller     text default null,
  p_brand      text default null,
  p_min_price  numeric default null,
  p_max_price  numeric default null,
  p_sort       text default 'new',
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
     -- Engellenen kişinin ilanı görünmüyor. `auth.uid()` null olabilir
     -- (giriş yapmamış kullanıcı); o durumda engelleme de yok.
     and (auth.uid() is null
          or not public.is_blocked_between(auth.uid(), l.owner_id))
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
     and (p_after_at is null
          or (l.created_at, l.id) < (p_after_at, p_after_id))
   order by
     case when p_sort = 'price_asc'  then l.price end asc nulls last,
     case when p_sort = 'price_desc' then l.price end desc nulls last,
     l.created_at desc, l.id desc
   limit least(greatest(coalesce(p_limit, 20), 1), 50);
$fn$;

-- ---------------------------------------------------------------------------
-- 4) Mağaza başvurusu sonucu bildirilsin
--
-- Başvuran, kararı öğrenmek için ekranı tekrar tekrar açmak zorunda kalmasın.
-- Ret notu da gövdeye giriyor: sebebini bilmeyen aynı başvuruyu tekrar
-- gönderiyor.
-- ---------------------------------------------------------------------------
create or replace function public.notify_store_decision()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.status is not distinct from old.status then
    return new;
  end if;
  -- `pending`'e dönüş bir karar değil; bildirilmiyor.
  if new.status = 'pending' then
    return new;
  end if;

  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id)
  select m.profile_id,
         'store_decision',
         case new.status
           when 'approved'  then new.name || ' onaylandı'
           when 'rejected'  then new.name || ' başvurusu reddedildi'
           when 'suspended' then new.name || ' askıya alındı'
           else new.name || ' durumu değişti'
         end,
         coalesce(new.review_note, ''),
         'store',
         new.id
    from public.store_memberships m
   where m.store_id = new.id;

  return new;
end;
$fn$;

drop trigger if exists trg_notify_store_decision on public.stores;
create trigger trg_notify_store_decision
  after update on public.stores
  for each row execute function public.notify_store_decision();

-- ---------------------------------------------------------------------------
-- 5) Moderasyon kararı ilan sahibine bildirilsin
--
-- İlanı sessizce gizlemek en kötüsü: satıcı ilanının yayında olduğunu sanıp
-- bekliyor. Yalnızca moderasyon kaynaklı durumlar bildiriliyor; sahibin
-- kendi yaptığı "rezerve"/"satıldı" değişikliği zaten kendisinden geliyor.
-- ---------------------------------------------------------------------------
create or replace function public.notify_moderation()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.market_status is not distinct from old.market_status then
    return new;
  end if;
  if new.market_status not in ('under_review', 'hidden_by_moderation') then
    return new;
  end if;

  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id)
  values (
    new.owner_id,
    'moderation',
    case new.market_status
      when 'under_review' then 'İlanın incelemeye alındı'
      else 'İlanın yayından kaldırıldı'
    end,
    new.title,
    'listing',
    new.id
  );

  return new;
end;
$fn$;

drop trigger if exists trg_notify_moderation on public.listings;
create trigger trg_notify_moderation
  after update on public.listings
  for each row execute function public.notify_moderation();

-- ---------------------------------------------------------------------------
-- 6) Yeni türlerin rotası
--
-- 0047'nin eşlemeleri korunuyor; iki yeni tür ekleniyor. Eşleme kaybını
-- `tools/check_push_routes.py` denetliyor.
-- ---------------------------------------------------------------------------
create or replace function public.push_route(p_kind text, p_entity text)
returns text
language sql
immutable
as $fn$
  select case p_kind
    when 'message'                   then '/mesajlar'
    when 'application'               then '/basvurular'
    when 'offer'                     then '/bildirimler'
    when 'follow'                    then '/bildirimler'
    when 'fee'                       then '/aidatlarim'
    when 'fee_reminder'              then '/aidatlarim'
    when 'payment'                   then '/finans'
    when 'donation'                  then '/bagis'
    when 'attendance'                then '/attendance'
    when 'attendance_reminder'       then '/attendance'
    when 'event'                     then '/calendar'
    when 'announcement'              then '/announcements'
    when 'achievement'               then '/performance-analytics'
    when 'document'                  then '/documents'
    when 'documents'                 then '/documents'
    when 'document_expiry'           then '/documents'
    when 'partner_request'           then '/partner-ara'
    when 'partner_request_accepted'  then '/partner-ara'
    when 'turf_slot_request'         then '/halisahalar'
    when 'turf_field'                then '/halisahalar'
    when 'turf_manager'              then '/halisahalar'
    when 'store_decision'            then '/magaza-basvuru'
    when 'moderation'                then '/pazaryeri'
    else '/bildirimler'
  end;
$fn$;

revoke execute on function public.is_blocked_between(uuid, uuid) from public, anon;
grant execute on function public.is_blocked_between(uuid, uuid) to authenticated;
