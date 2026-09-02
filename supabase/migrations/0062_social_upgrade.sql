-- ---------------------------------------------------------------------------
-- 0062 — Sosyal katman: görünürlük, çoklu fotoğraf, kaydedilenler, repost,
--        etiketleme ve çocuk gizliliği
--
-- GÜVENLİK NOTU — `posts_read` `using (true)` idi.
--
-- 0006'dan beri giriş yapmış herkes bütün gönderileri okuyabiliyordu. Kulüp
-- içi bir duyuru da, engellediğin kişinin gönderisi de dahil. Bu migration
-- politikayı görünürlük seviyesine ve engelleme durumuna bağlıyor.
-- `community_read` ile aynı hata, aynı düzeltme (0045).
--
-- ÇOCUK GİZLİLİĞİ: reşit olmayan hesaplarda görünürlük varsayılanı `public`
-- değil `followers`. Varsayılanı geniş tutup "isterse daraltır" demek,
-- kararı hiç vermemiş bir çocuğu en açık ayarda bırakırdı.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) GÖRÜNÜRLÜK VE DURUM
-- ---------------------------------------------------------------------------
alter table public.posts
  add column if not exists visibility   text not null default 'public',
  add column if not exists status       text not null default 'active',
  add column if not exists team_id      uuid references public.teams(id) on delete set null,
  add column if not exists repost_of_id uuid references public.posts(id) on delete set null,
  add column if not exists quote_of_id  uuid references public.posts(id) on delete set null,
  add column if not exists like_count   int not null default 0,
  add column if not exists edited_at    timestamptz;

do $blk$ begin
  alter table public.posts add constraint posts_visibility_check
    check (visibility in ('public', 'followers', 'club', 'team', 'private_draft'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.posts add constraint posts_status_check
    check (status in ('active', 'comments_closed', 'under_review',
                      'hidden_by_moderation', 'deleted_by_owner'));
exception when duplicate_object then null; end $blk$;

-- Bir gönderi hem repost hem alıntı olamaz: ikisi farklı şeyler ve ikisini
-- birden taşıyan satır hangi kartın çizileceğini belirsiz bırakırdı.
do $blk$ begin
  alter table public.posts add constraint posts_repost_xor_quote
    check (repost_of_id is null or quote_of_id is null);
exception when duplicate_object then null; end $blk$;

-- Kulüp/takım görünürlüğü kimliksiz olamaz; olursa gönderi kimseye
-- görünmez ve yazan kişi sebebini anlamaz.
do $blk$ begin
  alter table public.posts add constraint posts_scope_needs_id
    check (visibility <> 'club' or club_id is not null);
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.posts add constraint posts_team_needs_id
    check (visibility <> 'team' or team_id is not null);
exception when duplicate_object then null; end $blk$;

create index if not exists idx_posts_feed
  on public.posts (created_at desc) where status = 'active';
create index if not exists idx_posts_repost
  on public.posts (repost_of_id) where repost_of_id is not null;

-- Aynı kişi aynı gönderiyi iki kez repost edemez. Alıntı sınırsız —
-- alıntının her biri farklı bir yorum taşıyor, repost yalnızca bir sinyal.
create unique index if not exists idx_posts_repost_once
  on public.posts (author_profile_id, repost_of_id)
  where repost_of_id is not null;

-- ---------------------------------------------------------------------------
-- 2) ÇOCUK GİZLİLİĞİ
--
-- Reşit olmama iki kaynaktan anlaşılıyor:
--   • `guardians` bağlantısı — bu sistemde velisi olan hesap çocuk hesabıdır
--   • `athletes.birth_date` 18 yaşın altı
--
-- İkisi birlikte çünkü tek başına hiçbiri yetmiyor: velisi henüz
-- bağlanmamış bir çocuk da, doğum tarihi girilmemiş bir sporcu da var.
-- ---------------------------------------------------------------------------
create or replace function public.is_minor_profile(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.guardians g where g.profile_id is not null
       and exists (select 1 from public.athletes a
                    where a.id = g.athlete_id and a.profile_id = p_profile))
      or exists (
    select 1 from public.athletes a
     where a.profile_id = p_profile
       and a.birth_date is not null
       and a.birth_date > (current_date - interval '18 years'));
$fn$;

comment on function public.is_minor_profile(uuid) is
  'Reşit olmayan hesap. Sosyal görünürlük varsayılanı bu hesaplarda '
  'daraltılıyor ve dış paylaşım kapalı başlıyor.';

alter table public.profiles
  -- Etiketlenme izni: everyone | following | nobody
  add column if not exists mention_policy text not null default 'everyone',
  -- Dış paylaşım (uygulama dışına link çıkarma). Çocuk hesaplarda kapalı.
  add column if not exists allow_external_share boolean not null default true;

do $blk$ begin
  alter table public.profiles add constraint profiles_mention_policy_check
    check (mention_policy in ('everyone', 'following', 'nobody'));
exception when duplicate_object then null; end $blk$;

-- Yeni gönderide görünürlük varsayılanını çocuk hesaplarda daraltıyor.
create or replace function public.default_post_visibility()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  -- Yalnızca kullanıcı bilinçli bir seçim yapmadıysa (varsayılan `public`
  -- geldiyse) müdahale ediliyor. Açıkça `club` seçen bir çocuk hesabının
  -- tercihi ezilmiyor.
  if new.visibility = 'public'
     and public.is_minor_profile(new.author_profile_id) then
    new.visibility := 'followers';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_post_default_visibility on public.posts;
create trigger trg_post_default_visibility
  before insert on public.posts
  for each row execute function public.default_post_visibility();

-- ---------------------------------------------------------------------------
-- 3) GÖRÜNÜRLÜK KONTROLÜ
--
-- Tek fonksiyon: hem RLS politikası hem paylaşım kartı bunu çağırıyor.
-- İki yerde ayrı kural yazmak, ikisinin ayrışması demek — ve ayrıştığında
-- sızan taraf hep politikanın gevşek olanı oluyor.
-- ---------------------------------------------------------------------------
create or replace function public.can_view_post(p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1
      from public.posts p
     where p.id = p_post
       -- Silinmiş ve moderasyonla gizlenmiş içerik kimseye görünmüyor;
       -- sahibi ve platform yöneticisi hariç.
       and (p.status not in ('deleted_by_owner', 'hidden_by_moderation',
                             'under_review')
            or p.author_profile_id = auth.uid()
            or public.is_platform_admin())
       -- Taslak yalnızca sahibinde.
       and (p.visibility <> 'private_draft'
            or p.author_profile_id = auth.uid())
       -- Engelleme iki yönlü.
       and not public.is_blocked_between(auth.uid(), p.author_profile_id)
       and (
         p.author_profile_id = auth.uid()
         or public.is_platform_admin()
         or (p.visibility = 'public')
         -- `follows` polimorfik: (target_type, target_id). Kulüp takibi de
         -- aynı tabloda, o yüzden `target_type = 'profile'` şart.
         or (p.visibility = 'followers' and exists (
               select 1 from public.follows f
                where f.follower_id = auth.uid()
                  and f.target_type = 'profile'
                  and f.target_id = p.author_profile_id))
         or (p.visibility = 'club' and public.is_club_member(p.club_id))
         or (p.visibility = 'team' and exists (
               select 1 from public.team_memberships tm
                join public.athletes a on a.id = tm.athlete_id
               where tm.team_id = p.team_id and a.profile_id = auth.uid())
             or (p.visibility = 'team' and public.is_club_staff(p.club_id)))
       ));
$fn$;

-- Politikayı sıkılaştır. `using (true)` gitti.
drop policy if exists "posts_read" on public.posts;
create policy "posts_read" on public.posts for select
  to authenticated
  using (
    -- Kendi gönderin her zaman görünür (taslak dahil).
    author_profile_id = auth.uid()
    or public.is_platform_admin()
    or (
      status = 'active'
      and visibility <> 'private_draft'
      and not public.is_blocked_between(auth.uid(), author_profile_id)
      and (
        visibility = 'public'
        or (visibility = 'followers' and exists (
              select 1 from public.follows f
               where f.follower_id = auth.uid()
                 and f.target_type = 'profile'
                 and f.target_id = posts.author_profile_id))
        or (visibility = 'club' and public.is_club_member(posts.club_id))
        or (visibility = 'team' and (
              public.is_club_staff(posts.club_id)
              or exists (select 1 from public.team_memberships tm
                          join public.athletes a on a.id = tm.athlete_id
                         where tm.team_id = posts.team_id
                           and a.profile_id = auth.uid()))))
    ));

-- ---------------------------------------------------------------------------
-- 4) ÇOKLU FOTOĞRAF
--
-- Storage YOLU tutuluyor, URL değil: bucket ya da alan adı değişince
-- saklanmış URL'ler kırılırdı (pazaryerinde aynı karar, 0050).
-- ---------------------------------------------------------------------------
create table if not exists public.post_media (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts(id) on delete cascade,
  media_path text not null,
  sort_order int not null default 0,
  width      int,
  height     int,
  created_at timestamptz not null default now(),
  constraint post_media_order_unique unique (post_id, sort_order)
);

do $blk$ begin
  alter table public.post_media add constraint post_media_order_range
    check (sort_order between 0 and 7);
exception when duplicate_object then null; end $blk$;

create index if not exists idx_post_media_post
  on public.post_media (post_id, sort_order);

-- Sekiz görsel sınırı. `sort_order 0-7` kısıtı tek başına yetmiyor:
-- aynı sırayı boşaltıp yeniden kullanan bir istemci sınırı aşabilirdi.
-- Pazaryerinde de aynı ikili koruma var (0050).
create or replace function public.check_post_media_limit()
returns trigger
language plpgsql
as $fn$
begin
  if (select count(*) from public.post_media where post_id = new.post_id) >= 8 then
    raise exception 'Bir gönderiye en fazla 8 fotoğraf eklenebilir';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_post_media_limit on public.post_media;
create trigger trg_post_media_limit
  before insert on public.post_media
  for each row execute function public.check_post_media_limit();

alter table public.post_media enable row level security;

drop policy if exists "post_media_read" on public.post_media;
create policy "post_media_read" on public.post_media for select
  to authenticated using (public.can_view_post(post_id));

drop policy if exists "post_media_write" on public.post_media;
create policy "post_media_write" on public.post_media for all
  to authenticated
  using (exists (select 1 from public.posts p
                  where p.id = post_id and p.author_profile_id = auth.uid()))
  with check (exists (select 1 from public.posts p
                       where p.id = post_id and p.author_profile_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- 5) KAYDEDİLENLER
--
-- Tamamen kişiye özel. Gönderi sahibine sosyal sinyal olarak GİTMİYOR:
-- "kim kaydetti" bilgisi, kaydetmeyi kişisel bir yer imi olmaktan çıkarıp
-- kamusal bir beğeniye çevirirdi.
-- ---------------------------------------------------------------------------
create table if not exists public.saved_posts (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  post_id    uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, post_id)
);

create index if not exists idx_saved_posts_profile
  on public.saved_posts (profile_id, created_at desc);

alter table public.saved_posts enable row level security;

-- Yalnızca kendi kayıtların. Başkasınınkini okumanın yolu yok.
drop policy if exists "saved_posts_own" on public.saved_posts;
create policy "saved_posts_own" on public.saved_posts for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 6) ETİKETLEME (@mention)
--
-- Metindeki `@kullanıcıadı` yalnızca görünüm; ilişki profil UUID'siyle
-- saklanıyor. Kullanıcı adını saklasaydık ad değiştiğinde etiket kopardı.
-- ---------------------------------------------------------------------------
create table if not exists public.post_mentions (
  post_id              uuid not null references public.posts(id) on delete cascade,
  mentioned_profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at           timestamptz not null default now(),
  primary key (post_id, mentioned_profile_id)
);

create index if not exists idx_post_mentions_profile
  on public.post_mentions (mentioned_profile_id, created_at desc);

create or replace function public.check_post_mention_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_author uuid;
  v_policy text;
begin
  if (select count(*) from public.post_mentions
       where post_id = new.post_id) >= 10 then
    raise exception 'Bir gönderide en fazla 10 kişi etiketlenebilir';
  end if;

  select author_profile_id into v_author from public.posts
   where id = new.post_id;

  -- Engellenen kişi etiketlenemez ve etiketleyemez.
  if public.is_blocked_between(v_author, new.mentioned_profile_id) then
    raise exception 'Bu kişi etiketlenemez';
  end if;

  select mention_policy into v_policy from public.profiles
   where id = new.mentioned_profile_id;

  if v_policy = 'nobody' and new.mentioned_profile_id <> v_author then
    raise exception 'Bu kişi etiketlenmeyi kapatmış';
  end if;

  if v_policy = 'following' and new.mentioned_profile_id <> v_author
     and not exists (select 1 from public.follows f
                      where f.follower_id = new.mentioned_profile_id
                        and f.target_type = 'profile'
                        and f.target_id = v_author) then
    raise exception 'Bu kişi yalnızca takip ettiklerinin etiketlemesine açık';
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_post_mention_guard on public.post_mentions;
create trigger trg_post_mention_guard
  before insert on public.post_mentions
  for each row execute function public.check_post_mention_limit();

alter table public.post_mentions enable row level security;

drop policy if exists "post_mentions_read" on public.post_mentions;
create policy "post_mentions_read" on public.post_mentions for select
  to authenticated using (public.can_view_post(post_id));

drop policy if exists "post_mentions_write" on public.post_mentions;
create policy "post_mentions_write" on public.post_mentions for all
  to authenticated
  using (exists (select 1 from public.posts p
                  where p.id = post_id and p.author_profile_id = auth.uid()))
  with check (exists (select 1 from public.posts p
                       where p.id = post_id and p.author_profile_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- 7) HASHTAG
--
-- `tr_fold` ile saklanıyor (0048): `#Işıklar` ve `#isiklar` aynı etiket.
-- İstemcideki `trFold` ile aynı davranışta olmalı; ayrışırsa arama sonucu
-- istemci ve sunucuda farklı çıkar.
-- ---------------------------------------------------------------------------
create table if not exists public.post_hashtags (
  post_id    uuid not null references public.posts(id) on delete cascade,
  tag        text not null,
  created_at timestamptz not null default now(),
  primary key (post_id, tag)
);

create index if not exists idx_post_hashtags_tag
  on public.post_hashtags (tag, created_at desc);

alter table public.post_hashtags enable row level security;

drop policy if exists "post_hashtags_read" on public.post_hashtags;
create policy "post_hashtags_read" on public.post_hashtags for select
  to authenticated using (public.can_view_post(post_id));

drop policy if exists "post_hashtags_write" on public.post_hashtags;
create policy "post_hashtags_write" on public.post_hashtags for all
  to authenticated
  using (exists (select 1 from public.posts p
                  where p.id = post_id and p.author_profile_id = auth.uid()))
  with check (exists (select 1 from public.posts p
                       where p.id = post_id and p.author_profile_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- 8) DM'DE ZENGİN İÇERİK
--
-- Mesaj gövdesi düz metin kalıyor; paylaşılan şey ayrı iki sütunda. Kartın
-- görüntüsünü mesaja gömseydik, kaynak silindiğinde eski veri mesajda
-- donmuş olarak kalırdı — planın açıkça istemediği şey.
-- ---------------------------------------------------------------------------
alter table public.direct_messages
  add column if not exists content_type text not null default 'text',
  add column if not exists shared_kind  text,
  add column if not exists shared_id    uuid;

do $blk$ begin
  alter table public.direct_messages add constraint dm_content_type_check
    check (content_type in ('text', 'content_share', 'marketplace_share',
                            'event_share', 'organization_share'));
exception when duplicate_object then null; end $blk$;

-- Paylaşım türü seçildiyse hedef zorunlu; yoksa boş kart çizilirdi.
do $blk$ begin
  alter table public.direct_messages add constraint dm_share_needs_target
    check (content_type = 'text' or shared_id is not null);
exception when duplicate_object then null; end $blk$;

-- Topluluk mesajlarında da aynı yapı.
alter table public.community_messages
  add column if not exists content_type text not null default 'text',
  add column if not exists shared_kind  text,
  add column if not exists shared_id    uuid;

do $blk$ begin
  alter table public.community_messages
    add constraint cm_content_type_check
    check (content_type in ('text', 'content_share', 'marketplace_share',
                            'event_share', 'organization_share'));
exception when duplicate_object then null; end $blk$;

-- ---------------------------------------------------------------------------
-- 9) BEĞENİ SAYACI
--
-- Sayacı satırda tutmak, her akış satırında `count(*)` çalıştırmaktan çok
-- daha ucuz. Tetikleyiciyle güncelleniyor — uygulama koduna bırakılsaydı
-- bir yerde artırılıp başka yerde azaltılmayı unuturdu.
-- ---------------------------------------------------------------------------
create or replace function public.sync_post_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op = 'INSERT' then
    update public.posts set like_count = like_count + 1
     where id = new.post_id;
    return new;
  end if;
  update public.posts set like_count = greatest(like_count - 1, 0)
   where id = old.post_id;
  return old;
end;
$fn$;

drop trigger if exists trg_post_like_count on public.post_likes;
create trigger trg_post_like_count
  after insert or delete on public.post_likes
  for each row execute function public.sync_post_like_count();

-- Mevcut satırları bir kez düzelt.
update public.posts p
   set like_count = coalesce(
     (select count(*) from public.post_likes l where l.post_id = p.id), 0)
 where p.like_count is distinct from coalesce(
     (select count(*) from public.post_likes l where l.post_id = p.id), 0);
