set local lock_timeout = '15s';

-- 0129: Disiplin kararının kaydı ile kamusal bülten yayını ayrı sözleşmelerdir.
-- `disciplinary_decisions.reason` kurulun özel dosya gerekçesidir; asla
-- anonim projeksiyona katılmaz. Kamusal metin, yetkili kurulun ayrıca ve
-- değiştirilemez biçimde yayımladığı kısa özettir.

create table if not exists public.federation_disciplinary_bulletins (
  id uuid primary key default gen_random_uuid(),
  decision_id uuid not null unique references public.disciplinary_decisions(id) on delete restrict,
  public_summary text not null check (length(trim(public_summary)) between 1 and 500),
  published_by uuid not null references public.profiles(id) on delete restrict,
  published_at timestamptz not null default clock_timestamp()
);
alter table public.federation_disciplinary_bulletins enable row level security;
revoke all on public.federation_disciplinary_bulletins from public, anon, authenticated;

create table if not exists public.federation_match_notices (
  id uuid primary key default gen_random_uuid(),
  match_id uuid not null unique references public.org_matches(id) on delete restrict,
  notice_type text not null check (notice_type in ('match_cancelled','match_postponed')),
  public_summary text not null check (length(trim(public_summary)) between 1 and 500),
  published_by uuid not null references public.profiles(id) on delete restrict,
  published_at timestamptz not null default clock_timestamp()
);
alter table public.federation_match_notices enable row level security;
revoke all on public.federation_match_notices from public, anon, authenticated;

create or replace function public._federation_bulletin_immutable()
returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
begin
  raise exception 'Yayımlanmış federasyon bülteni değiştirilemez' using errcode='55000';
end $$;
drop trigger if exists federation_disciplinary_bulletin_immutable on public.federation_disciplinary_bulletins;
create trigger federation_disciplinary_bulletin_immutable before update or delete on public.federation_disciplinary_bulletins
  for each row execute function public._federation_bulletin_immutable();
drop trigger if exists federation_match_notice_immutable on public.federation_match_notices;
create trigger federation_match_notice_immutable before update or delete on public.federation_match_notices
  for each row execute function public._federation_bulletin_immutable();

create or replace function public.publish_disciplinary_bulletin(
  p_decision_id uuid,
  p_public_summary text
)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare d record; existing public.federation_disciplinary_bulletins; result_id uuid;
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501'; end if;
  if p_decision_id is null or length(trim(coalesce(p_public_summary,''))) not between 1 and 500 then
    raise exception 'Kamusal bülten özeti 1–500 karakter olmalı' using errcode='22023';
  end if;
  select d.id,o.sport_code,o.city_code into d
  from public.disciplinary_decisions d
  join public.org_matches m on m.id=d.match_id
  join public.organizations o on o.id=m.org_id
  where d.id=p_decision_id and o.official for key share of d,o;
  if d.id is null or not public._console_federation_scope(d.sport_code,d.city_code,array['disciplinary_board']) then
    raise exception 'Disiplin Kurulu branş yetkisi gerekli' using errcode='42501';
  end if;
  select * into existing from public.federation_disciplinary_bulletins where decision_id=p_decision_id;
  if found then
    if existing.published_by=auth.uid() and existing.public_summary=trim(p_public_summary) then return existing.id; end if;
    raise exception 'Bu karar zaten yayımlanmış; kamusal bülten değiştirilemez' using errcode='55000';
  end if;
  insert into public.federation_disciplinary_bulletins(decision_id,public_summary,published_by)
  values(p_decision_id,trim(p_public_summary),auth.uid()) returning id into result_id;
  return result_id;
end $$;

create or replace function public.publish_federation_match_notice(
  p_match_id uuid,
  p_notice_type text,
  p_public_summary text
)
returns uuid language plpgsql security definer set search_path=public,pg_temp as $$
declare m record; existing public.federation_match_notices; result_id uuid;
begin
  if auth.uid() is null then raise exception 'Giriş gerekli' using errcode='42501'; end if;
  if p_notice_type not in ('match_cancelled','match_postponed') or length(trim(coalesce(p_public_summary,''))) not between 1 and 500 then
    raise exception 'Geçerli duyuru türü ve 1–500 karakterlik kamusal özet gerekli' using errcode='22023';
  end if;
  select m.id,m.status,o.sport_code,o.city_code into m
  from public.org_matches m join public.organizations o on o.id=m.org_id
  where m.id=p_match_id and o.official and o.is_public for key share of m,o;
  if m.id is null or not public._console_federation_scope(m.sport_code,m.city_code,array['president','provincial_rep']) then
    raise exception 'Federasyon duyuru yetkisi gerekli' using errcode='42501';
  end if;
  if (p_notice_type='match_cancelled' and m.status<>'cancelled') or (p_notice_type='match_postponed' and m.status<>'postponed') then
    raise exception 'Duyuru türü mevcut müsabaka durumuyla uyuşmuyor' using errcode='22023';
  end if;
  select * into existing from public.federation_match_notices where match_id=p_match_id;
  if found then
    if existing.published_by=auth.uid() and existing.notice_type=p_notice_type and existing.public_summary=trim(p_public_summary) then return existing.id; end if;
    raise exception 'Bu müsabaka için duyuru zaten yayımlanmış; duyuru değiştirilemez' using errcode='55000';
  end if;
  insert into public.federation_match_notices(match_id,notice_type,public_summary,published_by)
  values(p_match_id,p_notice_type,trim(p_public_summary),auth.uid()) returning id into result_id;
  return result_id;
end $$;

create or replace function public.public_federation_disciplinary_bulletin(
  p_sport text default null,p_city text default null,p_offset int default 0,p_limit int default 50
)
returns table(id uuid,match_id uuid,sport_code text,city_code text,club_name text,athlete_display text,
  penalty_type text,penalty_label text,reason text,created_at timestamptz,match_title text,program_name text)
language sql stable security definer set search_path=public,pg_temp as $$
  select b.id,d.match_id,d.sport_code,o.city_code,coalesce(c.name,'Kulüp'),
    case when at.id is null or not exists(select 1 from public.athlete_sport_registrations r where r.athlete_id=at.id and r.sport_code=d.sport_code)
      or ((at.birth_date is null or at.birth_date>((now() at time zone 'Europe/Istanbul')::date-interval '18 years')::date or exists(select 1 from public.guardians g where g.athlete_id=at.id))
        and (not exists(select 1 from public.athlete_publicity ap join public.guardians g on g.id=ap.guardian_id and g.athlete_id=ap.athlete_id where ap.athlete_id=at.id and g.profile_id is not null and ap.allowed)
          or exists(select 1 from public.athlete_publicity ap join public.guardians g on g.id=ap.guardian_id and g.athlete_id=ap.athlete_id where ap.athlete_id=at.id and g.profile_id is not null and not ap.allowed)))
      then 'Sporcu ('||public.athlete_ref(d.athlete_id)||')' else trim(at.first_name||' '||at.last_name) end,
    d.penalty_type,case d.penalty_type when 'match_ban' then coalesce(d.match_ban_count::text,'1')||' Maç Men' when 'rights_ban' then coalesce(d.months::text,'1')||' Ay Hak Mahrumiyeti' when 'warning' then 'İhtar' when 'fine' then to_char(d.fine_amount,'FM999,999,999.00')||' ₺ Para Cezası' else 'Disiplin Cezası' end,
    b.public_summary,b.published_at,concat(coalesce(h.name,'Ev Sahibi'),' – ',coalesce(a.name,'Deplasman')),o.name
  from public.federation_disciplinary_bulletins b join public.disciplinary_decisions d on d.id=b.decision_id
  join public.org_matches m on m.id=d.match_id join public.organizations o on o.id=m.org_id
  left join public.clubs c on c.id=d.club_id left join public.athletes at on at.id=d.athlete_id
  left join public.org_participants h on h.id=m.home_id left join public.org_participants a on a.id=m.away_id
  where o.official and o.is_public and (p_sport is null or d.sport_code=p_sport) and (p_city is null or o.city_code is null or o.city_code=p_city)
  order by b.published_at desc,b.id limit greatest(least(coalesce(p_limit,50),100),1) offset greatest(coalesce(p_offset,0),0)
$$;

create or replace function public.public_federation_notices(
  p_sport text default null,p_city text default null,p_offset int default 0,p_limit int default 50
)
returns table(id uuid,sport_code text,city_code text,notice_type text,title text,body text,published_at timestamptz,program_name text,match_id uuid)
language sql stable security definer set search_path=public,pg_temp as $$
  select n.id,o.sport_code,o.city_code,n.notice_type,
    case n.notice_type when 'match_cancelled' then concat('Müsabaka İptali: ',coalesce(h.name,'Ev Sahibi'),' – ',coalesce(a.name,'Deplasman')) else concat('Müsabaka Erteleme: ',coalesce(h.name,'Ev Sahibi'),' – ',coalesce(a.name,'Deplasman')) end,
    n.public_summary,n.published_at,o.name,n.match_id
  from public.federation_match_notices n join public.org_matches m on m.id=n.match_id join public.organizations o on o.id=m.org_id
  left join public.org_participants h on h.id=m.home_id left join public.org_participants a on a.id=m.away_id
  where o.official and o.is_public and (p_sport is null or o.sport_code=p_sport) and (p_city is null or o.city_code is null or o.city_code=p_city)
  order by n.published_at desc,n.id limit greatest(least(coalesce(p_limit,50),100),1) offset greatest(coalesce(p_offset,0),0)
$$;

revoke all on function public._federation_bulletin_immutable(),public.publish_disciplinary_bulletin(uuid,text),public.publish_federation_match_notice(uuid,text,text) from public,anon,authenticated;
grant execute on function public.publish_disciplinary_bulletin(uuid,text),public.publish_federation_match_notice(uuid,text,text) to authenticated;
revoke all on function public.public_federation_disciplinary_bulletin(text,text,int,int),public.public_federation_notices(text,text,int,int) from public,anon,authenticated;
grant execute on function public.public_federation_disciplinary_bulletin(text,text,int,int),public.public_federation_notices(text,text,int,int) to anon,authenticated;

insert into public.feature_flags(key,audience,label) values('federation_bulletin','admins','Resmi Disiplin Bülteni') on conflict(key) do nothing;
update public.faq_entries set feature='federation_bulletin'
where route='/federasyon' and question='Federasyon disiplin bülteni ve ceza kararlarını nereden görebilirim?';
