-- Yanıtlar aynı gönderinin mevcut bir yorumuna bağlanır.
alter table public.post_comments
  add column if not exists parent_comment_id uuid;

create unique index if not exists post_comments_post_id_id_unique
  on public.post_comments (post_id, id);

create index if not exists post_comments_parent_idx
  on public.post_comments (parent_comment_id, created_at)
  where parent_comment_id is not null;

do $migration$
begin
  alter table public.post_comments
    add constraint post_comments_parent_same_post_fk
    foreign key (post_id, parent_comment_id)
    references public.post_comments (post_id, id)
    on delete cascade;
exception when duplicate_object then null;
end;
$migration$;

-- Yorumlar yalnız gönderiyi görebilen hesaplara açılır; yanıt ekleme de
-- kapalı yorumlu ya da erişilemeyen gönderilerde durur.
drop policy if exists "comments_read" on public.post_comments;
create policy "comments_read" on public.post_comments for select
  to authenticated
  using (public.can_view_post(post_id));

drop policy if exists "comments_insert_own" on public.post_comments;
create policy "comments_insert_own" on public.post_comments for insert
  to authenticated
  with check (
    profile_id = (select auth.uid())
    and public.can_view_post(post_id)
    and exists (
      select 1 from public.posts p
       where p.id = post_id and p.status = 'active'
    )
  );

do $migration$
begin
  alter table public.post_comments
    add constraint post_comments_not_self_reply
    check (parent_comment_id is null or parent_comment_id <> id);
exception when duplicate_object then null;
end;
$migration$;
