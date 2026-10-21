set local lock_timeout = '15s';

-- 0128: Kamusal Federasyon Disiplin Bülteni ve Resmi Müsabaka Kararları
-- Çocuk/sporcu gizliliği: Reşit olmayan veya veli açık izni bulunmayan sporcular
-- kamuya açık bültende ad-soyad ile değil, 'Sporcu (' || athlete_ref(athlete_id) || ')' formatıyla projekte edilir.
-- Muhasebeci ve harici sistemler ham tabloya doğrudan erişemez; kısıt sunucuda zorunludur.

drop function if exists public.public_federation_disciplinary_bulletin(text,text,int,int);
create or replace function public.public_federation_disciplinary_bulletin(
  p_sport text default null,
  p_city text default null,
  p_offset int default 0,
  p_limit int default 50
)
returns table(
  id uuid,
  match_id uuid,
  sport_code text,
  city_code text,
  club_name text,
  athlete_display text,
  penalty_type text,
  penalty_label text,
  reason text,
  created_at timestamptz,
  match_title text,
  program_name text
)
language sql stable security definer set search_path = public, pg_temp as $$
  select
    d.id,
    d.match_id,
    d.sport_code,
    o.city_code,
    coalesce(c.name, 'Kulüp') as club_name,
    case
      when at.id is null or not exists(
        select 1 from public.athlete_sport_registrations reg
        where reg.athlete_id = at.id and reg.sport_code = d.sport_code
      ) then 'Sporcu (' || public.athlete_ref(d.athlete_id) || ')'
      when (
        at.birth_date is null
        or at.birth_date > ((now() at time zone 'Europe/Istanbul')::date - interval '18 years')::date
        or exists(select 1 from public.guardians g where g.athlete_id = at.id)
      ) and (
        not exists(
          select 1 from public.athlete_publicity ap
          join public.guardians g on g.id = ap.guardian_id and g.athlete_id = ap.athlete_id
          where ap.athlete_id = at.id and g.profile_id is not null and ap.allowed
        )
        or exists(
          select 1 from public.athlete_publicity ap
          join public.guardians g on g.id = ap.guardian_id and g.athlete_id = ap.athlete_id
          where ap.athlete_id = at.id and g.profile_id is not null and not ap.allowed
        )
      ) then 'Sporcu (' || public.athlete_ref(d.athlete_id) || ')'
      else trim(at.first_name || ' ' || at.last_name)
    end as athlete_display,
    d.penalty_type,
    case d.penalty_type
      when 'match_ban' then coalesce(d.match_ban_count::text, '1') || ' Maç Men'
      when 'rights_ban' then coalesce(d.months::text, '1') || ' Ay Hak Mahrumiyeti'
      when 'warning' then 'İhtar'
      when 'fine' then to_char(d.fine_amount, 'FM999,999,999.00') || ' ₺ Para Cezası'
      else 'Disiplin Cezası'
    end as penalty_label,
    d.reason,
    d.created_at,
    concat(coalesce(h.name, 'Ev Sahibi'), ' – ', coalesce(a.name, 'Deplasman')) as match_title,
    o.name as program_name
  from public.disciplinary_decisions d
  join public.org_matches m on m.id = d.match_id
  join public.organizations o on o.id = m.org_id
  left join public.clubs c on c.id = d.club_id
  left join public.athletes at on at.id = d.athlete_id
  left join public.org_participants h on h.id = m.home_id
  left join public.org_participants a on a.id = m.away_id
  where o.official and o.is_public
    and (p_sport is null or d.sport_code = p_sport)
    and (p_city is null or o.city_code is null or o.city_code = p_city)
  order by d.created_at desc, d.id
  limit greatest(least(coalesce(p_limit, 50), 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.public_federation_disciplinary_bulletin(text,text,int,int) from public,anon,authenticated;
grant execute on function public.public_federation_disciplinary_bulletin(text,text,int,int) to anon,authenticated;

-- Resmi müsabaka kararları (erteleme, iptal ve durum değişiklikleri)
drop function if exists public.public_federation_notices(text,text,int,int);
create or replace function public.public_federation_notices(
  p_sport text default null,
  p_city text default null,
  p_offset int default 0,
  p_limit int default 50
)
returns table(
  id uuid,
  sport_code text,
  city_code text,
  notice_type text,
  title text,
  body text,
  published_at timestamptz,
  program_name text,
  match_id uuid
)
language sql stable security definer set search_path = public, pg_temp as $$
  with match_notices as (
    select
      m.id as id,
      o.sport_code,
      o.city_code,
      case m.status
        when 'cancelled' then 'match_cancelled'
        when 'postponed' then 'match_postponed'
        else 'status_update'
      end as notice_type,
      case m.status
        when 'cancelled' then concat('Müsabaka İptali: ', coalesce(h.name, 'Ev Sahibi'), ' – ', coalesce(a.name, 'Deplasman'))
        when 'postponed' then concat('Müsabaka Erteleme: ', coalesce(h.name, 'Ev Sahibi'), ' – ', coalesce(a.name, 'Deplasman'))
        else concat('Resmi Müsabaka Bildirimi: ', coalesce(h.name, 'Ev Sahibi'), ' – ', coalesce(a.name, 'Deplasman'))
      end as title,
      concat(
        o.name, ' kapsamında planlanan müsabaka resmi federasyon kararı ile ',
        case m.status when 'cancelled' then 'iptal edilmiştir.' when 'postponed' then 'ileri bir tarihe ertelenmiştir.' else 'güncellenmiştir.' end,
        case when m.location is not null then concat(' Yer: ', m.location) else '' end
      ) as body,
      coalesce(m.starts_at, o.created_at) as published_at,
      o.name as program_name,
      m.id as match_id
    from public.org_matches m
    join public.organizations o on o.id = m.org_id
    left join public.org_participants h on h.id = m.home_id
    left join public.org_participants a on a.id = m.away_id
    where o.official and o.is_public
      and m.status in ('cancelled', 'postponed')
      and (p_sport is null or o.sport_code = p_sport)
      and (p_city is null or o.city_code is null or o.city_code = p_city)
  )
  select * from match_notices
  order by published_at desc, id
  limit greatest(least(coalesce(p_limit, 50), 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke all on function public.public_federation_notices(text,text,int,int) from public,anon,authenticated;
grant execute on function public.public_federation_notices(text,text,int,int) to anon,authenticated;

insert into public.faq_entries(question,answer,category,audience,sort_order,route)
select 'Federasyon disiplin bülteni ve ceza kararlarını nereden görebilirim?',
 'Federasyon Yayın Merkezi içindeki Disiplin & Bülten sekmesinden resmi müsabaka disiplin kurulu kararlarını, maç men ve hak mahrumiyeti cezalarını ve resmi müsabaka erteleme/iptal duyurularını inceleyebilirsin. Çocuk sporcuların kişisel verileri yasal gizlilik kuralları gereği maskelenmiş referans koduyla gösterilir.',
 'Genel','everyone',128,'/federasyon'
where not exists(select 1 from public.faq_entries where question='Federasyon disiplin bülteni ve ceza kararlarını nereden görebilirim?');
