set local lock_timeout = '15s';

create table if not exists public.club_training_sports (
 club_id uuid not null references public.clubs(id) on delete cascade,
 sport_code text not null references public.sports(code) on delete cascade,
 created_at timestamptz not null default now(),
 created_by uuid references public.profiles(id) on delete set null,
 primary key(club_id,sport_code)
);
alter table public.club_training_sports enable row level security;
revoke all on public.club_training_sports from public,anon,authenticated;
grant select on public.club_training_sports to authenticated;
drop policy if exists club_training_sports_select on public.club_training_sports;
create policy club_training_sports_select on public.club_training_sports
for select to authenticated using(exists(
 select 1 from public.club_memberships m where m.club_id=club_training_sports.club_id
 and m.profile_id=auth.uid() and m.status='active'
));

create or replace function public.set_club_training_sports(p_club_id uuid,p_sport_codes text[])
returns int language plpgsql security definer set search_path = public as $fn$
declare codes text[]; n int;
begin
 -- Serialize replacements, then recheck membership after waiting for the club lock.
 perform 1 from public.clubs where id=p_club_id for update;
 if auth.uid() is null or not exists(
  select 1 from public.club_memberships m join public.clubs c on c.id=m.club_id
  where m.club_id=p_club_id and m.profile_id=auth.uid() and m.status='active'
  and m.role in ('club_admin','coach') and c.status='active'
 ) then raise exception 'Kulüp branşlarını güncelleme yetkin yok'; end if;
 select coalesce(array_agg(distinct s.code),array[]::text[]) into codes
 from unnest(coalesce(p_sport_codes,array[]::text[])) u(code)
 join public.sports s on s.code=trim(u.code);
 if cardinality(codes)>60 then raise exception 'En fazla 60 branş seçebilirsin'; end if;
 delete from public.club_training_sports where club_id=p_club_id and not(sport_code=any(codes));
 insert into public.club_training_sports(club_id,sport_code,created_by)
 select p_club_id,unnest(codes),auth.uid() on conflict do nothing;
 select count(*)::int into n from public.club_training_sports where club_id=p_club_id;
 return n;
end;
$fn$;
revoke all on function public.set_club_training_sports(uuid,text[]) from public,anon,authenticated;
grant execute on function public.set_club_training_sports(uuid,text[]) to authenticated;

create or replace function public.my_training_club_sports(p_club_id uuid)
returns table(sport_code text) language plpgsql stable security definer set search_path = public as $fn$
begin
 if auth.uid() is null or not exists(
  select 1 from public.club_memberships m join public.clubs c on c.id=m.club_id
  where m.club_id=p_club_id and m.profile_id=auth.uid() and m.status='active' and c.status='active'
 ) then raise exception 'Aktif kulüp üyeliği gerekli'; end if;
 return query
 select c.sport_code from public.clubs c where c.id=p_club_id and c.sport_code is not null
 union select r.sport_code from public.club_sport_registrations r where r.club_id=p_club_id
 union select t.sport_code from public.teams t where t.club_id=p_club_id and t.sport_code is not null
 union select cts.sport_code from public.club_training_sports cts where cts.club_id=p_club_id;
end;
$fn$;
revoke all on function public.my_training_club_sports(uuid) from public,anon,authenticated;
grant execute on function public.my_training_club_sports(uuid) to authenticated;

insert into public.faq_entries(question,answer,category,audience,feature,route,sort_order)
select 'Kulübümün antrenman branşlarını nasıl seçerim?',
 'Kulüp Ayarları içindeki Kulüp branşlarını yönet bölümünden branşlarını seçip kaydet. Bu seçim resmi federasyon tescili veya lisans yetkisi vermez. Ana branş, resmi tescil ve mevcut takımların branşları antrenman bağlamında ayrıca görünmeye devam eder.',
 'Antrenman','coach','sport_training_sessions','/settings',150
where not exists(select 1 from public.faq_entries where question='Kulübümün antrenman branşlarını nasıl seçerim?');

-- The existing FAQ publication trigger remains authoritative and can abort this transaction.
update public.feature_flags set audience='everyone' where audience='admins' and key in (
 'sport_training_sessions','season_setup','development_report','court_waitlist','turf_delegation',
 'referee_cockpit','club_staff_operations','live_match_hub','league_standings',
 'live_match_notifications','parent_hub'
);
