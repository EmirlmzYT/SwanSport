-- Atomic season opening; existing domain tables remain authoritative.
set local lock_timeout = '15s';
create table if not exists public.season_setup_runs (
  actor_id uuid not null references auth.users(id) on delete cascade,
  op_id uuid not null, club_id uuid not null references public.clubs(id) on delete cascade,
  input_hash text not null, result jsonb not null,
  created_at timestamptz not null default now(), primary key(actor_id,op_id)
);
alter table public.season_setup_runs enable row level security;
revoke all on public.season_setup_runs from public,anon,authenticated;

create or replace function public.open_club_season(p_club uuid,p_op uuid,p_input jsonb)
returns jsonb language plpgsql security definer set search_path=public as $fn$
declare old_run season_setup_runs; season uuid; team uuid; plan uuid; result jsonb;
  starts date; ends date; until_date date; days int[]; hour_value int; minute_value int; duration_value int;
  athletes uuid[]; athlete_count int; event_count int:=0; fee_amount numeric; fee_day int;
  config jsonb; activate_season boolean;
begin
  if auth.uid() is null or not coalesce(public.is_club_admin(p_club),false) then
    raise exception 'Sezon açılışı için bu kulübün yöneticisi olmalısın.';
  end if;
  if p_op is null or jsonb_typeof(p_input) is distinct from 'object' or octet_length(p_input::text)>32768 then
    raise exception 'Geçersiz sezon isteği.';
  end if;
  -- Serialize openings for this club; no partial activation or duplicate retry.
  perform 1 from public.clubs where id=p_club and status='active' for update;
  if not found then raise exception 'Aktif bir kulüp gerekli.'; end if;
  select * into old_run from season_setup_runs where actor_id=auth.uid() and op_id=p_op;
  if found then
    if old_run.club_id<>p_club or old_run.input_hash<>md5(p_input::text) then
      raise exception 'Bu işlem kimliği farklı bir hazırlık için kullanılmış.';
    end if;
    return old_run.result;
  end if;
  if not exists(select 1 from public.my_feature_flags() f where f.key='season_setup') then
    raise exception 'Sezon açılışı şu anda hesabına açık değil.';
  end if;
  if exists(select 1 from jsonb_object_keys(p_input) k where k not in
    ('label','starts_on','ends_on','team_name','athlete_ids','activate','schedule','fee')) then
    raise exception 'Geçersiz hazırlık alanı.';
  end if;
  if jsonb_typeof(p_input->'label') is distinct from 'string' or
    jsonb_typeof(p_input->'team_name') is distinct from 'string' or
    length(btrim(p_input->>'label')) not between 1 and 80 or
    length(btrim(p_input->>'team_name')) not between 1 and 80 then
    raise exception 'Sezon ve takım adı 1–80 karakter olmalı.';
  end if;
  if coalesce(p_input->>'starts_on','') !~ '^\d{4}-\d{2}-\d{2}$' or
    coalesce(p_input->>'ends_on','') !~ '^\d{4}-\d{2}-\d{2}$' or
    jsonb_typeof(p_input->'activate') is distinct from 'boolean' then
    raise exception 'Sezon tarihleri ve aktiflik seçimi gerekli.';
  end if;
  starts:=(p_input->>'starts_on')::date; ends:=(p_input->>'ends_on')::date;
  activate_season:=(p_input->>'activate')::boolean;
  if ends-starts not between 0 and 365 then raise exception 'Sezon en fazla 366 gün olmalı.'; end if;
  if jsonb_typeof(p_input->'athlete_ids') is distinct from 'array' then raise exception 'Kadro listesi gerekli.'; end if;
  if jsonb_array_length(p_input->'athlete_ids')>200 then raise exception 'En fazla 200 sporcu seçilebilir.'; end if;
  select coalesce(array_agg(value::uuid),'{}'::uuid[]) into athletes
    from jsonb_array_elements_text(p_input->'athlete_ids');
  if cardinality(athletes)<>(select count(distinct id) from unnest(athletes) id) then
    raise exception 'Kadroda aynı sporcu iki kez bulunamaz.';
  end if;
  -- Lock selected athletes as well so their status/club cannot change mid-save.
  perform 1 from public.athletes a where a.id=any(athletes) order by a.id for share;
  select count(*) into athlete_count from public.athletes a
    where a.id=any(athletes) and a.club_id=p_club and a.status='active';
  if athlete_count<>cardinality(athletes) then raise exception 'Kadrodaki sporcular aktif ve aynı kulüpten olmalı.'; end if;
  if exists(select 1 from public.seasons where club_id=p_club and lower(btrim(label))=lower(btrim(p_input->>'label'))) then
    raise exception 'Bu isimde bir sezon zaten var.';
  end if;
  if exists(select 1 from public.teams where club_id=p_club and lower(btrim(name))=lower(btrim(p_input->>'team_name'))) then
    raise exception 'Bu isimde bir takım zaten var. İlk sürüm yeni takım açar.';
  end if;
  if p_input ? 'schedule' then
    config:=p_input->'schedule';
    if jsonb_typeof(config) is distinct from 'object' or coalesce(config->>'until','') !~ '^\d{4}-\d{2}-\d{2}$' then
      raise exception 'Geçersiz program.';
    end if;
    if jsonb_typeof(config->'weekdays') is distinct from 'array' then raise exception 'Antrenman günlerini seç.'; end if;
    if jsonb_array_length(config->'weekdays') not between 1 and 7 then raise exception 'Antrenman günlerini seç.'; end if;
    if exists(select 1 from jsonb_array_elements(config->'weekdays') v where jsonb_typeof(v)<>'number' or v::text !~ '^[1-7]$') then
      raise exception 'Geçersiz antrenman günü.';
    end if;
    select array_agg(value::text::int) into days from jsonb_array_elements(config->'weekdays');
    if cardinality(days)<>(select count(distinct id) from unnest(days) id) then raise exception 'Aynı gün iki kez seçilemez.'; end if;
    if jsonb_typeof(config->'hour') is distinct from 'number' or coalesce(config->>'hour','') !~ '^\d+$' or
       jsonb_typeof(config->'minute') is distinct from 'number' or coalesce(config->>'minute','') !~ '^\d+$' or
       jsonb_typeof(config->'minutes') is distinct from 'number' or coalesce(config->>'minutes','') !~ '^\d+$' then
      raise exception 'Geçersiz antrenman saati.';
    end if;
    hour_value:=(config->>'hour')::int; minute_value:=(config->>'minute')::int; duration_value:=(config->>'minutes')::int;
    until_date:=(config->>'until')::date;
    if until_date<starts or until_date>ends or until_date-starts>90 or hour_value not between 0 and 23 or
      minute_value not between 0 and 59 or duration_value not between 15 and 240 then
      raise exception 'Program sezon içinde ve en fazla 91 gün olmalı; süre 15–240 dakika olmalı.';
    end if;
    if not exists(select 1 from generate_series(starts::timestamp,until_date::timestamp,interval '1 day') d
      where extract(isodow from d)::int=any(days)) then raise exception 'Bu tarihlerde seçili güne ait antrenman yok.'; end if;
  end if;
  if p_input ? 'fee' then
    config:=p_input->'fee';
    if jsonb_typeof(config) is distinct from 'object' or jsonb_typeof(config->'name') is distinct from 'string' or
       length(btrim(config->>'name')) not between 1 and 80 or jsonb_typeof(config->'amount') is distinct from 'number' or
       jsonb_typeof(config->'due_day') is distinct from 'number' or coalesce(config->>'due_day','') !~ '^\d+$' then
      raise exception 'Geçersiz aidat planı.';
    end if;
    fee_amount:=(config->>'amount')::numeric; fee_day:=(config->>'due_day')::int;
    if fee_amount not between 0.01 and 10000000 or fee_amount<>round(fee_amount,2) or fee_day not between 1 and 28 then
      raise exception 'Aidat pozitif, en fazla iki ondalıklı olmalı; ödeme günü 1–28 arası olmalı.';
    end if;
  end if;
  if activate_season then update public.seasons set is_active=false where club_id=p_club; end if;
  insert into public.seasons(club_id,label,starts_on,ends_on,is_active)
    values(p_club,btrim(p_input->>'label'),starts,ends,activate_season) returning id into season;
  insert into public.teams(club_id,name) values(p_club,btrim(p_input->>'team_name')) returning id into team;
  insert into public.team_memberships(athlete_id,team_id,season_id) select id,team,season from unnest(athletes) id;
  if p_input ? 'schedule' then
    event_count:=public.create_event_series(p_club,btrim(p_input->>'team_name')||' antrenmanı','training',
      starts,until_date,hour_value,minute_value,duration_value,days,null,null,team);
  end if;
  if p_input ? 'fee' then
    insert into public.fee_plans(club_id,name,amount,due_day,active)
      values(p_club,btrim(p_input->'fee'->>'name'),fee_amount,fee_day,false) returning id into plan;
  end if;
  result:=jsonb_build_object('season_id',season,'team_id',team,'roster_count',athlete_count,'event_count',event_count,'fee_plan_id',plan);
  insert into season_setup_runs(actor_id,op_id,club_id,input_hash,result) values(auth.uid(),p_op,p_club,md5(p_input::text),result);
  return result;
end $fn$;
revoke all on function public.open_club_season(uuid,uuid,jsonb) from public,anon;
grant execute on function public.open_club_season(uuid,uuid,jsonb) to authenticated;

insert into public.feature_flags(key,audience,label,description) values
  ('season_setup','admins','Sezon açılış sihirbazı','Sezon, yeni takım, kadro, program ve taslak aidat planını birlikte hazırlar.')
on conflict(key) do nothing;
insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'Sezon açılışını nasıl hazırlayabilirim?',
  'Kulüp yöneticisi olarak Profil > Yönetim > Sezon Açılışı ekranını aç. Tarihleri, yeni takımı ve mevcut sporculardan kadroyu seç. İstersen ilk haftaların antrenman programını ve pasif taslak aidat planını ekle. Son kontrolden sonra kaydet. Bir hata olursa hazırlık bütünüyle geri alınır; aynı işlemi tekrar denemek ikinci sezon oluşturmaz. Aidat ataması ve tahakkuk Aidat Yönetimi ekranından ayrıca yapılır.',
  'Kulüp','club_staff',190,'/sezon-acilisi','season_setup'
where not exists(select 1 from public.faq_entries where feature='season_setup' and active);
