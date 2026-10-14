set local lock_timeout = '15s';

-- Legal club/team participants only. Never expose private amateur names or
-- athlete/profile identifiers through a public standings projection.
create or replace function public.public_standings_leagues()
returns table(id uuid,name text,sport_code text,city_code text,win_points int,draw_points int,loss_points int,federation_id uuid)
language sql stable security definer set search_path=public,pg_temp as $$
  select o.id,o.name,o.sport_code,o.city_code,o.win_points,o.draw_points,o.loss_points,fo.federation_id
  from public.organizations o join public.sport_seasons ss on ss.id=o.sport_season_id
    join public.federation_offices fo on fo.id=ss.office_id where o.official and o.is_public
    and o.kind in ('league','tournament') and o.sport_code in ('futbol','basketbol','voleybol','tenis')
  order by o.starts_on desc nulls last,o.name,o.id
$$;

-- A detail tab must not infer a league from its display name or from the
-- last-48-hour match list. The same publication gate owns this mapping.
create or replace function public.match_public_standings_context(p_match_id uuid)
returns jsonb language sql stable security definer set search_path=public,pg_temp as $$
  select jsonb_build_object('org_id',o.id,'name',o.name,'sport_code',o.sport_code,
    'home_participant_id',m.home_id,'away_participant_id',m.away_id)
  from public.org_matches m join public.organizations o on o.id=m.org_id
  where m.id=p_match_id and o.official and o.is_public and m.status in ('scheduled','played')
    and o.kind in ('league','tournament') and o.sport_code in ('futbol','basketbol','voleybol','tenis')
$$;

create or replace function public.public_league_standings(p_org_id uuid,p_include_live boolean default false)
returns table(rank int,participant_id uuid,participant_name text,club_id uuid,club_name text,club_logo text,
  played bigint,won bigint,drawn bigint,lost bigint,goals_for bigint,goals_against bigint,goal_diff bigint,
  points bigint,form jsonb,is_provisional boolean)
language sql stable security definer set search_path=public,pg_temp as $$
  with league as materialized (
    select o.id,o.win_points,o.draw_points,o.loss_points from public.organizations o
    where o.id=p_org_id and o.official and o.is_public and o.kind in ('league','tournament')
      and o.sport_code in ('futbol','basketbol','voleybol','tenis')
  ), participants as materialized (
    select p.id,p.name,p.club_id,c.legal_name club_name,c.logo_path
    from league o join public.org_participants p on p.org_id=o.id
    left join public.clubs c on c.id=p.club_id where p.status='accepted'
  ), projected as materialized (
    select m.id,m.home_id,m.away_id,m.starts_at,m.status,public._public_match_header(m.id) h
    from league o join public.org_matches m on m.org_id=o.id
    join participants hp on hp.id=m.home_id join participants ap on ap.id=m.away_id
    where m.home_id<>m.away_id and (m.status='played' or (coalesce(p_include_live,false) and m.status='scheduled'))
  ), scores as (
    select p.*, (p.h->>'home_score')::int hs,(p.h->>'away_score')::int aws,
      p.status='scheduled' live
    from projected p where p.h is not null and p.h->>'home_score' is not null
      and p.h->>'away_score' is not null and (p.status='played' or (p.h->>'is_live')::boolean)
  ), results as (
    select s.id,s.starts_at,s.home_id pid,s.hs gf,s.aws ga,s.live from scores s
    union all select s.id,s.starts_at,s.away_id,s.aws,s.hs,s.live from scores s
  ), numbered as (
    select r.*,case when r.gf>r.ga then 'W' when r.gf=r.ga then 'D' else 'L' end outcome,
      row_number() over(partition by r.pid order by r.starts_at desc nulls last,r.id desc) recency
    from results r
  ), totals as (
    select p.id,p.name,p.club_id,p.club_name,p.logo_path,
      count(r.id) played,count(r.id) filter(where r.outcome='W') won,
      count(r.id) filter(where r.outcome='D') drawn,count(r.id) filter(where r.outcome='L') lost,
      coalesce(sum(r.gf),0)::bigint gf,coalesce(sum(r.ga),0)::bigint ga,
      coalesce(sum(case r.outcome when 'W' then o.win_points when 'D' then o.draw_points
        when 'L' then o.loss_points end),0)::bigint pts,
      coalesce(jsonb_agg(r.outcome order by r.recency desc) filter(where r.recency<=5),'[]'::jsonb) recent_form,
      coalesce(bool_or(r.live),false) provisional
    from participants p cross join league o left join numbered r on r.pid=p.id
    group by p.id,p.name,p.club_id,p.club_name,p.logo_path
  )
  select (row_number() over(order by t.pts desc,t.gf-t.ga desc,t.gf desc,t.name,t.id))::int,
    t.id,t.name,t.club_id,t.club_name,t.logo_path,t.played,t.won,t.drawn,t.lost,t.gf,t.ga,t.gf-t.ga,
    t.pts,t.recent_form,t.provisional from totals t
  order by t.pts desc,t.gf-t.ga desc,t.gf desc,t.name,t.id
$$;

revoke all on function public.public_league_standings(uuid,boolean),public.public_standings_leagues(),public.match_public_standings_context(uuid) from public,anon,authenticated;
grant execute on function public.public_league_standings(uuid,boolean),public.public_standings_leagues(),public.match_public_standings_context(uuid) to anon,authenticated;

insert into public.feature_flags(key,audience,label) values('league_standings','admins','Canlı Puan Durumu & Lig Tablosu') on conflict(key) do nothing;
insert into public.faq_entries(question,answer,category,feature,route,sort_order)
select 'Canlı puan durumu ile resmi lig tablosu arasındaki fark nedir?',
  'Canlı Skor Merkezi içindeki Puan Durumu sekmesinden yayımlanmış resmi lig veya turnuvayı seçebilirsiniz. Resmi tablo yalnız güncel tescilli sonuçları içerir. Canlı şalteri devam eden maçları geçici olarak ekler; geri alınan olay ve sonuç düzeltmeleri sonraki yenilemede hesaplanır. Puanlar organizasyonun galibiyet, beraberlik ve mağlubiyet kuralından gelir (varsayılan 3/1/0). Sıralama puan, averaj, atılan sayı ve takım adına göredir; özel ikili averaj, grup/eleme ve set bazlı bonus kuralları uygulanmaz. Son 5 en eskiden en yeniye G/B/M gösterilir. Gizli veya amatör organizasyonlar bu genel tabloda yer almaz.',
  'spor','league_standings','/canli-skor',117
where not exists(select 1 from public.faq_entries where feature='league_standings' and route='/canli-skor');
