-- =============================================================================
-- SwanSport — SOSYAL KATMAN (akış, profil, takip, beğeni, yorum)
-- Supabase SQL editöründe BİR KEZ çalıştır (SETUP.sql + STORAGE.sql sonrası).
-- Tekrar çalıştırılabilir (idempotent).
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1) Profil zenginleştirme (biyografi, avatar, kullanıcı adı)
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists bio          text,
  add column if not exists avatar_path  text,
  add column if not exists username     text;

-- Kullanıcı adı benzersiz olsun (null'lar serbest)
create unique index if not exists idx_profiles_username
  on public.profiles (lower(username)) where username is not null;

-- Kulüplere de profil alanları
alter table public.clubs
  add column if not exists bio        text,
  add column if not exists logo_path  text;

-- ---------------------------------------------------------------------------
-- 2) Gönderiler
--    club_id dolu  → kulüp adına paylaşım
--    club_id boş   → kişisel paylaşım (doğrulanmış kimlik şart)
-- ---------------------------------------------------------------------------
create table if not exists public.posts (
  id                uuid primary key default gen_random_uuid(),
  author_profile_id uuid not null references public.profiles(id) on delete cascade,
  club_id           uuid references public.clubs(id) on delete cascade,
  body              text not null,
  image_path        text,                       -- Storage: post-media
  kind              text not null default 'post', -- post | news
  created_at        timestamptz not null default now()
);
create index if not exists idx_posts_created on public.posts (created_at desc);
create index if not exists idx_posts_club    on public.posts (club_id);
create index if not exists idx_posts_author  on public.posts (author_profile_id);

-- ---------------------------------------------------------------------------
-- 3) Beğeniler
-- ---------------------------------------------------------------------------
create table if not exists public.post_likes (
  post_id    uuid not null references public.posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, profile_id)
);

-- ---------------------------------------------------------------------------
-- 4) Yorumlar
-- ---------------------------------------------------------------------------
create table if not exists public.post_comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  body       text not null,
  created_at timestamptz not null default now()
);
create index if not exists idx_comments_post on public.post_comments (post_id, created_at);

-- ---------------------------------------------------------------------------
-- 5) Takip (hedef: kulüp veya kişi)
-- ---------------------------------------------------------------------------
create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('club','profile')),
  target_id   uuid not null,
  created_at  timestamptz not null default now(),
  primary key (follower_id, target_type, target_id)
);
create index if not exists idx_follows_target on public.follows (target_type, target_id);

-- ---------------------------------------------------------------------------
-- 6) Yardımcı: kişi paylaşım yapabilir mi? (onaylı kimlik)
-- ---------------------------------------------------------------------------
create or replace function public.can_post_personally()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profile_credentials c
    where c.profile_id = auth.uid() and c.status = 'approved'
  );
$$;

-- Kulüp adına paylaşım yetkisi (yönetici veya antrenör)
create or replace function public.can_post_for_club(p_club uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.club_memberships m
    where m.club_id = p_club
      and m.profile_id = auth.uid()
      and m.status = 'active'
      and m.role in ('club_admin','coach')
  );
$$;

-- ---------------------------------------------------------------------------
-- 7) RLS
-- ---------------------------------------------------------------------------
alter table public.posts         enable row level security;
alter table public.post_likes    enable row level security;
alter table public.post_comments enable row level security;
alter table public.follows       enable row level security;

-- Gönderiler: giriş yapan herkes okur (herkese açık akış)
drop policy if exists "posts_read" on public.posts;
create policy "posts_read" on public.posts for select
  to authenticated using (true);

-- Gönderi oluşturma: kulüp adına yetkili VEYA doğrulanmış kişi
drop policy if exists "posts_insert" on public.posts;
create policy "posts_insert" on public.posts for insert
  to authenticated
  with check (
    author_profile_id = auth.uid()
    and (
      (club_id is not null and public.can_post_for_club(club_id))
      or
      (club_id is null and public.can_post_personally())
    )
  );

-- Kendi gönderini düzenle/sil (platform yöneticisi de silebilir)
drop policy if exists "posts_update_own" on public.posts;
create policy "posts_update_own" on public.posts for update
  to authenticated
  using (author_profile_id = auth.uid())
  with check (author_profile_id = auth.uid());

drop policy if exists "posts_delete_own" on public.posts;
create policy "posts_delete_own" on public.posts for delete
  to authenticated
  using (author_profile_id = auth.uid() or public.is_platform_admin());

-- Beğeniler: herkes okur, kendi beğenini ekler/siler
drop policy if exists "likes_read" on public.post_likes;
create policy "likes_read" on public.post_likes for select
  to authenticated using (true);

drop policy if exists "likes_insert_own" on public.post_likes;
create policy "likes_insert_own" on public.post_likes for insert
  to authenticated with check (profile_id = auth.uid());

drop policy if exists "likes_delete_own" on public.post_likes;
create policy "likes_delete_own" on public.post_likes for delete
  to authenticated using (profile_id = auth.uid());

-- Yorumlar: herkes okur; giriş yapan herkes yorum yazar; kendi yorumunu siler
drop policy if exists "comments_read" on public.post_comments;
create policy "comments_read" on public.post_comments for select
  to authenticated using (true);

drop policy if exists "comments_insert_own" on public.post_comments;
create policy "comments_insert_own" on public.post_comments for insert
  to authenticated with check (profile_id = auth.uid());

drop policy if exists "comments_delete_own" on public.post_comments;
create policy "comments_delete_own" on public.post_comments for delete
  to authenticated
  using (
    profile_id = auth.uid()
    or public.is_platform_admin()
    or exists (select 1 from public.posts p
               where p.id = post_id and p.author_profile_id = auth.uid())
  );

-- Takip: herkes okur (takipçi sayısı için), kendi takibini yönetir
drop policy if exists "follows_read" on public.follows;
create policy "follows_read" on public.follows for select
  to authenticated using (true);

drop policy if exists "follows_insert_own" on public.follows;
create policy "follows_insert_own" on public.follows for insert
  to authenticated with check (follower_id = auth.uid());

drop policy if exists "follows_delete_own" on public.follows;
create policy "follows_delete_own" on public.follows for delete
  to authenticated using (follower_id = auth.uid());

-- Profilleri herkes görebilsin (sosyal profil sayfası için).
-- Mevcut dar politikalara EK olarak okuma açıyoruz.
drop policy if exists "profiles: public read" on public.profiles;
create policy "profiles: public read" on public.profiles for select
  to authenticated using (true);

-- Kulüpleri de herkes görebilsin (kulüp profili + takip için)
drop policy if exists "clubs: public read" on public.clubs;
create policy "clubs: public read" on public.clubs for select
  to authenticated using (true);

-- ---------------------------------------------------------------------------
-- 8) Storage — gönderi görselleri ve avatarlar (herkese açık okuma)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('post-media', 'post-media', true)
on conflict (id) do nothing;

-- Yükleme: yalnızca kendi klasörüne ({uid}/...)
drop policy if exists "postmedia_upload_own" on storage.objects;
create policy "postmedia_upload_own" on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Okuma: herkese açık (public bucket)
drop policy if exists "postmedia_read_all" on storage.objects;
create policy "postmedia_read_all" on storage.objects for select
  using (bucket_id = 'post-media');

-- Güncelleme/silme: yalnızca sahibi
drop policy if exists "postmedia_update_own" on storage.objects;
create policy "postmedia_update_own" on storage.objects for update
  to authenticated
  using (bucket_id = 'post-media'
         and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'post-media'
              and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "postmedia_delete_own" on storage.objects;
create policy "postmedia_delete_own" on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'post-media'
    and ((storage.foldername(name))[1] = auth.uid()::text
         or public.is_platform_admin())
  );
