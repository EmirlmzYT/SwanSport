-- One RSVP ledger for calendar, guardian actions and the home card.
begin;
set local lock_timeout = '15s';

create or replace function public.my_today_training_rsvps()
returns jsonb language plpgsql stable security definer
set search_path = public, pg_temp as $$
declare stamp timestamptz := statement_timestamp(); result jsonb;
  today_date date := (stamp at time zone 'Europe/Istanbul')::date;
  day_start timestamptz := today_date::timestamp at time zone 'Europe/Istanbul';
  day_end timestamptz := (today_date+1)::timestamp at time zone 'Europe/Istanbul';
begin
  if auth.uid() is null then raise exception 'Oturum gerekli.' using errcode='42501'; end if;
  if not exists(select 1 from public.my_feature_flags() f where f.key='sport_training_sessions') then
    return jsonb_build_object('server_now',stamp,'items','[]'::jsonb);
  end if;
  select coalesce(jsonb_agg(jsonb_build_object(
    'event_id',e.id,'athlete_id',a.id,'title',e.title,'place',e.place,
    'club_name',c.name,'is_self',coalesce(a.profile_id=auth.uid(),false),
    'child_name',case when a.profile_id=auth.uid() then null else trim(a.first_name||' '||a.last_name) end,
    'starts_at',e.starts_at,'ends_at',e.ends_at,'response',r.status,'response_at',r.updated_at
  ) order by e.starts_at,e.id,a.id),'[]'::jsonb) into result
  from public.athletes a
  join public.events e on e.club_id=a.club_id and e.kind::text='training'
  join public.clubs c on c.id=a.club_id
  left join public.event_rsvps r on r.event_id=e.id and r.athlete_id=a.id
  where a.status::text='active'
    and (a.profile_id=auth.uid() or (
      exists(select 1 from public.my_feature_flags() f where f.key='parent_hub')
      and exists(select 1 from public.guardians g where g.athlete_id=a.id and g.profile_id=auth.uid())))
    and e.starts_at>=day_start and e.starts_at<day_end
    and (e.ends_at is null or e.ends_at>stamp)
    and (e.team_id is null or exists(
      select 1 from public.team_memberships tm join public.teams t on t.id=tm.team_id and t.club_id=e.club_id
      where tm.team_id=e.team_id and tm.athlete_id=a.id));
  return jsonb_build_object('server_now',stamp,'items',result);
end $$;

create or replace function public.respond_today_training(
  p_event uuid,p_athlete uuid,p_status text,p_expected timestamptz)
returns void language plpgsql security definer
set search_path = public, pg_temp as $$
declare ev public.events; ath public.athletes; reply public.event_rsvps; inserted uuid;
begin
  if auth.uid() is null then raise exception 'Oturum gerekli.' using errcode='42501'; end if;
  if not exists(select 1 from public.my_feature_flags() f where f.key='sport_training_sessions') then
    raise exception 'Antrenman katılımı şu anda hesabına açık değil.' using errcode='42501';
  end if;
  if p_status is null or p_status not in ('attending','unavailable') then
    raise exception 'Geçersiz katılım yanıtı.';
  end if;
  select * into ev from public.events where id=p_event for share;
  if not found or ev.kind::text<>'training' then raise exception 'Antrenmana erişilemiyor.' using errcode='42501'; end if;
  select * into ath from public.athletes where id=p_athlete and club_id=ev.club_id and status::text='active' for update;
  if not found then raise exception 'Antrenmana erişilemiyor.' using errcode='42501'; end if;
  if ath.profile_id is distinct from auth.uid() then
    if not exists(select 1 from public.my_feature_flags() f where f.key='parent_hub') then
      raise exception 'Veli katılımı şu anda hesabına açık değil.' using errcode='42501';
    end if;
    perform 1 from public.guardians g where g.profile_id=auth.uid() and g.athlete_id=ath.id for share;
    if not found then raise exception 'Antrenmana erişilemiyor.' using errcode='42501'; end if;
  end if;
  if ev.team_id is not null and not exists(
    select 1 from public.team_memberships tm join public.teams t on t.id=tm.team_id and t.club_id=ev.club_id
    where tm.team_id=ev.team_id and tm.athlete_id=ath.id) then
    raise exception 'Sporcu bu antrenmanın kadrosunda değil.' using errcode='42501';
  end if;
  -- Re-check after locks: waiting for another responder must not extend the deadline.
  if ev.starts_at<=clock_timestamp() or
     (ev.starts_at at time zone 'Europe/Istanbul')::date<>(clock_timestamp() at time zone 'Europe/Istanbul')::date then
    raise exception 'Antrenman başlamış veya bugün için planlanmamış.';
  end if;
  select * into reply from public.event_rsvps where event_id=ev.id and athlete_id=ath.id for update;
  if ev.starts_at<=clock_timestamp() then
    raise exception 'Antrenman başlamış. Yanıt süresi doldu.';
  end if;
  if found then
    if reply.status=p_status then return; end if;
    if reply.updated_at is distinct from p_expected then raise exception 'Yanıt değişmiş. Güncel yanıtı kontrol edip tekrar dene.' using errcode='40001'; end if;
    update public.event_rsvps set status=p_status,updated_at=clock_timestamp()
      where event_id=ev.id and athlete_id=ath.id;
  else
    if p_expected is not null then raise exception 'Yanıt değişmiş. Yenileyip tekrar dene.' using errcode='40001'; end if;
    insert into public.event_rsvps(event_id,athlete_id,status) values(ev.id,ath.id,p_status)
      on conflict do nothing returning event_id into inserted;
    if inserted is null then raise exception 'Yanıt değişmiş. Yenileyip tekrar dene.' using errcode='40001'; end if;
  end if;
end $$;

revoke all on function public.my_today_training_rsvps() from public, anon, authenticated;
revoke all on function public.respond_today_training(uuid,uuid,text,timestamptz) from public, anon, authenticated;
grant execute on function public.my_today_training_rsvps() to authenticated;
grant execute on function public.respond_today_training(uuid,uuid,text,timestamptz) to authenticated;

insert into public.faq_entries(question,answer,category,audience,feature,route,sort_order)
select 'Ana sayfadan bugünkü antrenmana katılımımı nasıl bildiririm?',
 'Bugünkü antrenman kartında saat ve yeri kontrol edip Katılacağım veya Katılamayacağım seç. Yanıtın kaydedilince kartta görünür; antrenman başlayana kadar değiştirebilirsin. Aynı gün birden fazla antrenman varsa diğerlerini de açabilirsin. Veli, yalnız bağlı çocuğunun kendi kulüp ve takımına ait antrenmanına yanıt verebilir. Başka biri yanıtı değiştirdiyse güncel yanıtı kontrol edip tekrar seçmen istenir. Bu bir katılım niyetidir; antrenörün gerçek yoklamasını değiştirmez. Bugün antrenman yoksa kart gösterilmez.',
 'Antrenman','everyone','sport_training_sessions','/akis',170
where not exists(select 1 from public.faq_entries where question='Ana sayfadan bugünkü antrenmana katılımımı nasıl bildiririm?');
commit;
