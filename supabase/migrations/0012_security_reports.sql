-- =============================================================================
-- SwanSport — GÜVENLİK & YASAL
--   1) İçerik şikayeti (gönderi, yorum, kullanıcı)
--   2) Kullanıcı engelleme
--   3) Hesap silme (KVKK)
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) ŞİKAYETLER
-- ---------------------------------------------------------------------------
create table if not exists public.content_reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  target_type text not null check (target_type in ('post','comment','profile')),
  target_id   uuid not null,
  reason      text not null,          -- spam | taciz | uygunsuz | yanlis_bilgi | diger
  detail      text,
  status      text not null default 'open',  -- open | reviewed | dismissed
  created_at  timestamptz not null default now(),
  reviewed_by uuid references public.profiles(id) on delete set null,
  reviewed_at timestamptz,
  review_note text
);

create index if not exists idx_report_status
  on public.content_reports (status, created_at desc);
-- Aynı kişi aynı içeriği bir kez şikayet etsin.
create unique index if not exists idx_report_unique
  on public.content_reports (reporter_id, target_type, target_id)
  where status = 'open';

alter table public.content_reports enable row level security;

drop policy if exists "report_insert_own" on public.content_reports;
create policy "report_insert_own" on public.content_reports for insert
  to authenticated with check (reporter_id = auth.uid());

drop policy if exists "report_read" on public.content_reports;
create policy "report_read" on public.content_reports for select
  to authenticated
  using (reporter_id = auth.uid() or public.is_platform_admin());

drop policy if exists "report_admin_update" on public.content_reports;
create policy "report_admin_update" on public.content_reports for update
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Şikayeti sonuçlandır (platform yöneticisi).
create or replace function public.review_report(
  p_report uuid,
  p_action text,              -- 'reviewed' | 'dismissed'
  p_note text default null,
  p_delete_content boolean default false
)
returns void
language plpgsql security definer set search_path = public as $$
declare r public.content_reports%rowtype;
begin
  if not public.is_platform_admin() then
    raise exception 'Yetkisiz';
  end if;

  select * into r from public.content_reports where id = p_report;
  if not found then raise exception 'Şikayet bulunamadı'; end if;

  update public.content_reports
     set status = case when p_action = 'dismissed' then 'dismissed'
                       else 'reviewed' end,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         review_note = p_note
   where id = p_report;

  if p_delete_content then
    if r.target_type = 'post' then
      delete from public.posts where id = r.target_id;
    elsif r.target_type = 'comment' then
      delete from public.post_comments where id = r.target_id;
    end if;
  end if;
end; $$;


-- ---------------------------------------------------------------------------
-- 2) ENGELLEME
-- ---------------------------------------------------------------------------
create table if not exists public.blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint blocks_not_self check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

drop policy if exists "blocks_own" on public.blocks;
create policy "blocks_own" on public.blocks for all
  to authenticated
  using (blocker_id = auth.uid())
  with check (blocker_id = auth.uid());

-- Engellediklerim + beni engelleyenler (içerik gizlemede kullanılır).
create or replace function public.hidden_profiles()
returns setof uuid
language sql stable security definer set search_path = public as $$
  select blocked_id from public.blocks where blocker_id = auth.uid()
  union
  select blocker_id from public.blocks where blocked_id = auth.uid();
$$;

-- Engellendiğinde karşılıklı takip de düşsün.
create or replace function public.trg_block_cleanup()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  delete from public.follows
   where (follower_id = new.blocker_id and target_type = 'profile'
          and target_id = new.blocked_id)
      or (follower_id = new.blocked_id and target_type = 'profile'
          and target_id = new.blocker_id);
  return new;
end; $$;
drop trigger if exists trg_blocks_cleanup on public.blocks;
create trigger trg_blocks_cleanup after insert on public.blocks
  for each row execute function public.trg_block_cleanup();


-- ---------------------------------------------------------------------------
-- 3) HESAP SİLME (KVKK — kullanıcının verisini silme hakkı)
--
-- profiles.id → auth.users(id) üzerine kuruludur; auth kaydı silinince
-- profil ve ona bağlı tüm içerik (gönderi, yorum, beğeni, takip, mesaj)
-- cascade ile silinir.
-- ---------------------------------------------------------------------------
create or replace function public.delete_my_account()
returns void
language plpgsql security definer set search_path = public, auth as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'Oturum bulunamadı'; end if;

  -- Kulübün tek yöneticisiyse önce devretmeli; veri sahipsiz kalmasın.
  if exists (
    select 1 from public.club_memberships m
    where m.profile_id = v_uid and m.role = 'club_admin' and m.status = 'active'
      and (
        select count(*) from public.club_memberships m2
        where m2.club_id = m.club_id and m2.role = 'club_admin'
          and m2.status = 'active'
      ) = 1
  ) then
    raise exception
      'Kulübün tek yöneticisisin. Önce başka birini yönetici yap veya kulübü kapat.';
  end if;

  delete from auth.users where id = v_uid;
end; $$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;
