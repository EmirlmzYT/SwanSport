-- 0050 — Spor malzemeleri pazaryeri: şema, görseller, favoriler, raporlar
--
-- MEVCUT YAPI KORUNUYOR. `listings` tablosu sporcu, antrenör, kulüp ve seçme
-- ilanlarını taşıyor; 0034 malzeme ilanlarını ekledi. Bu migration o tabloyu
-- **genişletiyor**, ikinci bir ilan sistemi kurmuyor. Eski ilanlar ve
-- `create_listing` RPC'si aynen çalışmaya devam ediyor.
--
-- İlk sürümde ödeme, escrow, komisyon, kargo entegrasyonu ve iade YOK.
-- Alıcı ve satıcı mevcut DM sistemiyle anlaşıyor; buradaki iş ilan, güvenlik,
-- teslim tercihi, mağaza doğrulaması ve moderasyon altyapısı.

-- ===========================================================================
-- 1) MAĞAZALAR
-- ===========================================================================
create table if not exists public.stores (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  slug          text unique,
  logo_path     text,                  -- Storage yolu; URL değil
  description   text,
  city_code     text references public.cities(code),
  district      text,

  status        text not null default 'pending',
  -- pending | approved | rejected | suspended

  applied_at    timestamptz not null default now(),
  reviewed_at   timestamptz,
  reviewed_by   uuid references public.profiles(id) on delete set null,
  application_note text,               -- başvuranın notu
  review_note      text,               -- yöneticinin kararı (başvurana görünür)

  -- Kurum bilgisi ilk sürümde toplanmıyor. Gerekirse buraya eklenecek ve
  -- YALNIZCA platform yöneticisine açılacak; mağaza profilinde ve genel API
  -- yanıtlarında hiçbir zaman görünmeyecek.
  created_at    timestamptz not null default now(),

  constraint stores_status_valid
    check (status in ('pending', 'approved', 'rejected', 'suspended'))
);

create index if not exists idx_stores_status on public.stores (status);
create index if not exists idx_stores_city   on public.stores (city_code);

create table if not exists public.store_memberships (
  store_id   uuid not null references public.stores(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  role       text not null default 'owner',   -- owner | manager
  created_at timestamptz not null default now(),
  primary key (store_id, profile_id),
  constraint store_role_valid check (role in ('owner', 'manager'))
);

create index if not exists idx_store_member_profile
  on public.store_memberships (profile_id);

-- Bu kişi mağazayı yönetiyor mu — `is_turf_manager` (0038) ile aynı desen.
create or replace function public.is_store_manager(p_store uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.store_memberships m
     where m.store_id = p_store and m.profile_id = auth.uid());
$$;

-- Mağaza **onaylı** mı ve bu kişi yönetiyor mu. Sıfır ürün ilanının şartı.
create or replace function public.can_sell_new(p_store uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.stores s
     join public.store_memberships m on m.store_id = s.id
    where s.id = p_store
      and s.status = 'approved'
      and m.profile_id = auth.uid());
$$;

alter table public.stores enable row level security;
alter table public.store_memberships enable row level security;

-- Onaylı mağazalar herkese görünür; bekleyen/reddedilen yalnızca sahibine ve
-- platform yöneticisine. Reddedilmiş bir mağazanın adının arama sonucunda
-- çıkması hem yanıltıcı hem başvurana karşı haksız olurdu.
drop policy if exists "stores_read" on public.stores;
create policy "stores_read" on public.stores for select
  to authenticated
  using (
    status = 'approved'
    or public.is_store_manager(id)
    or public.is_platform_admin()
  );

-- Başvuru: kişi kendi adına mağaza açabilir, ama durumu değiştiremez.
drop policy if exists "stores_apply" on public.stores;
create policy "stores_apply" on public.stores for insert
  to authenticated with check (status = 'pending');

drop policy if exists "stores_admin" on public.stores;
create policy "stores_admin" on public.stores for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Yönetici kendi mağazasının profilini düzenleyebilir; `status` alanına
-- dokunamaması tetikleyiciyle korunuyor (aşağıda).
drop policy if exists "stores_manage" on public.stores;
create policy "stores_manage" on public.stores for update
  to authenticated
  using (public.is_store_manager(id))
  with check (public.is_store_manager(id));

create or replace function public.guard_store_status()
returns trigger language plpgsql security definer set search_path = public
as $fn$
begin
  -- Yalnızca platform yöneticisi durumu değiştirebilir. RLS `update`'e izin
  -- veriyor ama hangi sütuna dokunulduğunu göremiyor; kontrol burada.
  if new.status is distinct from old.status
     and not public.is_platform_admin() then
    raise exception 'Mağaza durumunu yalnızca platform yöneticisi değiştirir';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_guard_store_status on public.stores;
create trigger trg_guard_store_status
  before update on public.stores
  for each row execute function public.guard_store_status();

drop policy if exists "store_member_read" on public.store_memberships;
create policy "store_member_read" on public.store_memberships for select
  to authenticated
  using (profile_id = auth.uid()
         or public.is_store_manager(store_id)
         or public.is_platform_admin());

drop policy if exists "store_member_admin" on public.store_memberships;
create policy "store_member_admin" on public.store_memberships for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- ===========================================================================
-- 2) İLAN GENİŞLETMESİ
--
-- Yalnızca pazaryeri ilanlarında dolu olacak alanlar. Eski ilanlarda hepsi
-- null kalıyor ve hiçbir davranış değişmiyor.
-- ===========================================================================
alter table public.listings
  add column if not exists seller_type   text,      -- individual | verified_store
  add column if not exists store_id      uuid references public.stores(id) on delete cascade,
  add column if not exists item_condition text,     -- new | like_new | very_good | good | used
  add column if not exists defect_note   text,
  add column if not exists category      text,
  add column if not exists subcategory   text,
  add column if not exists brand         text,
  add column if not exists model         text,
  add column if not exists size_label    text,
  add column if not exists color         text,
  add column if not exists negotiable    boolean not null default false,
  add column if not exists stock         int,
  add column if not exists delivery      text,      -- hand_delivery | shipping | both
  add column if not exists market_status text;      -- yaşam döngüsü

do $$ begin
  alter table public.listings add constraint listings_seller_type_valid
    check (seller_type is null or seller_type in ('individual', 'verified_store'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.listings add constraint listings_condition_valid
    check (item_condition is null or item_condition in
           ('new', 'like_new', 'very_good', 'good', 'used'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.listings add constraint listings_delivery_valid
    check (delivery is null or delivery in ('hand_delivery', 'shipping', 'both'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.listings add constraint listings_market_status_valid
    check (market_status is null or market_status in
           ('draft', 'active', 'reserved', 'sold',
            'removed_by_owner', 'under_review', 'hidden_by_moderation'));
exception when duplicate_object then null; end $$;

-- Sıfır ürün yalnızca mağazadan. Kural istemcide de gösteriliyor ama asıl
-- yeri burası: doğrudan tablo erişimiyle atlatılamamalı.
do $$ begin
  alter table public.listings add constraint listings_new_needs_store
    check (item_condition is distinct from 'new'
           or seller_type = 'verified_store');
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.listings add constraint listings_store_type_match
    check ((seller_type = 'verified_store') = (store_id is not null)
           or seller_type is null);
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.listings add constraint listings_stock_sane
    check (stock is null or stock >= 0);
exception when duplicate_object then null; end $$;

create index if not exists idx_listings_market
  on public.listings (market_status, sport_code, city_code)
  where market_status is not null;

create index if not exists idx_listings_store
  on public.listings (store_id) where store_id is not null;

-- ===========================================================================
-- 3) GÖRSELLER — ilan başına en fazla 8
-- ===========================================================================
create table if not exists public.listing_images (
  id         uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  image_path text not null,            -- Storage yolu; URL üretimi istemcide
  sort_order int not null default 0,
  created_at timestamptz not null default now(),

  constraint listing_image_order_range check (sort_order between 0 and 7),
  unique (listing_id, sort_order)
);

create index if not exists idx_listing_images
  on public.listing_images (listing_id, sort_order);

-- Sınır veritabanı seviyesinde. `sort_order` 0-7 tek başına yetmiyor: aynı
-- sıraya iki kayıt `unique` ile engelleniyor ama sekiz satır sonrası dokuzuncu
-- bir sıra numarası olmadan da eklenebilirdi.
create or replace function public.guard_listing_image_count()
returns trigger language plpgsql security definer set search_path = public
as $fn$
begin
  if (select count(*) from public.listing_images
       where listing_id = new.listing_id) >= 8 then
    raise exception 'Bir ilanda en fazla 8 görsel olabilir';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_guard_listing_image_count on public.listing_images;
create trigger trg_guard_listing_image_count
  before insert on public.listing_images
  for each row execute function public.guard_listing_image_count();

-- Eski tek görselli ilanların `image_path` verisi ilk görsel olarak taşınıyor.
-- `listings.image_path` sütunu KALDIRILMIYOR: eski ekranlar ve
-- `create_listing` RPC'si onu okumaya devam ediyor.
insert into public.listing_images (listing_id, image_path, sort_order)
select l.id, l.image_path, 0
  from public.listings l
 where l.image_path is not null
   and not exists (select 1 from public.listing_images i
                    where i.listing_id = l.id)
on conflict do nothing;

alter table public.listing_images enable row level security;

drop policy if exists "listing_image_read" on public.listing_images;
create policy "listing_image_read" on public.listing_images for select
  to anon, authenticated using (true);

drop policy if exists "listing_image_write" on public.listing_images;
create policy "listing_image_write" on public.listing_images for all
  to authenticated
  using (exists (select 1 from public.listings l
                  where l.id = listing_id
                    and (l.owner_id = auth.uid()
                         or (l.store_id is not null
                             and public.is_store_manager(l.store_id)))))
  with check (exists (select 1 from public.listings l
                       where l.id = listing_id
                         and (l.owner_id = auth.uid()
                              or (l.store_id is not null
                                  and public.is_store_manager(l.store_id)))));

-- ===========================================================================
-- 4) FAVORİLER
-- ===========================================================================
create table if not exists public.marketplace_favorites (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, listing_id)
);

create index if not exists idx_fav_listing
  on public.marketplace_favorites (listing_id);

alter table public.marketplace_favorites enable row level security;

-- Kullanıcı yalnızca kendi favorilerini görür ve yönetir. Bir ilanın kaç kez
-- favorilendiği satıcıya bile gösterilmiyor: az favorili ilan satıcıyı
-- fiyat kırmaya iter, çok favorili ilan alıcıyı acele ettirir. İkisi de
-- ilk sürümde istemediğimiz baskılar.
drop policy if exists "fav_own" on public.marketplace_favorites;
create policy "fav_own" on public.marketplace_favorites for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ===========================================================================
-- 5) RAPORLAR
-- ===========================================================================
create table if not exists public.marketplace_reports (
  id          uuid primary key default gen_random_uuid(),
  listing_id  uuid not null references public.listings(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason      text not null,
  -- counterfeit | wrong_description | prohibited | spam | inappropriate | other
  note        text,

  status      text not null default 'open',   -- open|reviewing|resolved|dismissed
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  decision_note text,
  created_at  timestamptz not null default now(),

  -- Aynı kullanıcı aynı ilanı bir kez raporlar.
  unique (listing_id, reporter_id),

  constraint report_reason_valid check (reason in
    ('counterfeit','wrong_description','prohibited','spam','inappropriate','other')),
  constraint report_status_valid check (status in
    ('open','reviewing','resolved','dismissed'))
);

create index if not exists idx_report_open
  on public.marketplace_reports (status, created_at desc);

alter table public.marketplace_reports enable row level security;

drop policy if exists "report_create" on public.marketplace_reports;
create policy "report_create" on public.marketplace_reports for insert
  to authenticated with check (reporter_id = auth.uid() and status = 'open');

-- Raporlayan kendi raporunu görür; kararı takip edebilsin.
drop policy if exists "report_read" on public.marketplace_reports;
create policy "report_read" on public.marketplace_reports for select
  to authenticated
  using (reporter_id = auth.uid() or public.is_platform_admin());

drop policy if exists "report_admin" on public.marketplace_reports;
create policy "report_admin" on public.marketplace_reports for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- ===========================================================================
-- 6) GÖRÜNÜRLÜK
--
-- Mevcut `listing_read` politikası `using (true)`: bütün ilanlar herkese.
-- Eski ilan türleri için doğru, ama pazaryerinde taslak, incelemedeki ve
-- moderasyonla gizlenmiş ilanlar genel akışta görünmemeli.
-- ===========================================================================
drop policy if exists "listing_read" on public.listings;
create policy "listing_read" on public.listings for select
  to authenticated
  using (
    -- Pazaryeri dışındaki ilanlar: eskisi gibi açık.
    market_status is null
    -- Pazaryeri: yalnızca yayında olanlar. Rezerve ve satıldı da görünüyor;
    -- alıcı "bu ilana ne oldu" sorusunun cevabını bulabilmeli.
    or market_status in ('active', 'reserved', 'sold')
    -- Sahibi ve mağaza yöneticisi kendi taslağını görür.
    or owner_id = auth.uid()
    or (store_id is not null and public.is_store_manager(store_id))
    or public.is_platform_admin()
  );
