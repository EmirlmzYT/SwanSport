set local lock_timeout = '15s';

-- Each edit creates a fresh revision, including an edit back to older text.
alter table public.announcements add column if not exists receipt_version uuid not null default gen_random_uuid();
create or replace function public._announcement_receipt_version()
returns trigger language plpgsql set search_path=public,pg_temp as $$begin
 new.receipt_version:=case when (new.title,new.body) is distinct from (old.title,old.body) then gen_random_uuid() else old.receipt_version end;
 return new;
end $$;
revoke all on function public._announcement_receipt_version() from public,anon,authenticated;
drop trigger if exists announcement_receipt_version on public.announcements;
create trigger announcement_receipt_version before update on public.announcements for each row execute function public._announcement_receipt_version();
create table if not exists public.announcement_receipts (
 announcement_id uuid not null references public.announcements(id) on delete cascade,
 profile_id uuid not null references public.profiles(id) on delete cascade,
 content_version text not null,
 read_at timestamptz not null default clock_timestamp(),
 acknowledged_at timestamptz,
 primary key(announcement_id,profile_id,content_version)
);
alter table public.announcement_receipts enable row level security;
revoke all on public.announcement_receipts from public,anon,authenticated;

create or replace function public.announcement_detail(p_id uuid)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare a announcements; v text; r announcement_receipts; staff boolean;
begin
 select * into a from announcements where id=p_id;
 if auth.uid() is null or a.id is null or not coalesce(is_club_member(a.club_id) or is_club_staff(a.club_id),false) then
  raise exception 'Duyuruya erişilemiyor.' using errcode='42501';
 end if;
 v:=a.receipt_version::text;
 select * into r from announcement_receipts where announcement_id=a.id and profile_id=auth.uid() and content_version=v;
 staff:=coalesce(is_club_staff(a.club_id),false);
 return jsonb_build_object('id',a.id,'title',a.title,'body',a.body,'version',v,
 'read_at',r.read_at,'acknowledged_at',r.acknowledged_at,
 'read_count',case when staff then (select count(*) from announcement_receipts x where x.announcement_id=a.id and x.content_version=v) end,
 'acknowledged_count',case when staff then (select count(*) from announcement_receipts x where x.announcement_id=a.id and x.content_version=v and x.acknowledged_at is not null) end);
end $$;

create or replace function public.record_announcement_receipt(p_id uuid,p_version text,p_acknowledge boolean)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare a announcements;v text;
begin
 -- Lock content so a concurrent edit cannot acknowledge unseen text.
 select * into a from announcements where id=p_id for share;
 if auth.uid() is null or a.id is null or not coalesce(is_club_member(a.club_id) or is_club_staff(a.club_id),false) then
  raise exception 'Duyuruya erişilemiyor.' using errcode='42501';
 end if;
 v:=a.receipt_version::text;
 if p_version is distinct from v or p_acknowledge is null then
  raise exception 'Duyuru değişti. Yeniden açıp oku.' using errcode='40001';
 end if;
 insert into announcement_receipts(announcement_id,profile_id,content_version,acknowledged_at)
 values(a.id,auth.uid(),v,case when p_acknowledge then clock_timestamp() end)
 on conflict(announcement_id,profile_id,content_version) do update
 set acknowledged_at=coalesce(announcement_receipts.acknowledged_at,excluded.acknowledged_at);
 return announcement_detail(a.id);
end $$;
revoke all on function public.announcement_detail(uuid),public.record_announcement_receipt(uuid,text,boolean) from public,anon;
grant execute on function public.announcement_detail(uuid),public.record_announcement_receipt(uuid,text,boolean) to authenticated;

insert into public.faq_entries(question,answer,category,audience,sort_order,route)
select 'Duyurularda okundu ve onaylandı ne anlama gelir?',
 'Duyuru kartındaki ayrıntıyı açınca okundu kaydı tutulur. Okudum, onaylıyorum düğmesi ayrıca açık onayını kaydeder; bu yoklama veya hukuki rıza değildir. Kulüp personeli o anki içerik için gerçek okuma ve onay sayılarını görür. Duyuru metni değişirse önceki içeriğin onayı yeni metin için sayılmaz. Bildirim teslimi veya tüm üyelerin okuması garanti edilmez.',
 'Kulüp','everyone',210,'/announcements'
where not exists(select 1 from public.faq_entries where question='Duyurularda okundu ve onaylandı ne anlama gelir?');
