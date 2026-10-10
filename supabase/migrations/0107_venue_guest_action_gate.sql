set local lock_timeout = '15s';

-- Optional public facility metadata. No sample values and no second media system.
alter table public.courts add column if not exists surface_type text,
 add column if not exists photo_paths text[] not null default '{}';
alter table public.turf_fields add column if not exists surface_type text,
 add column if not exists photo_paths text[] not null default '{}';
alter table public.courts drop constraint if exists court_public_media_valid;
alter table public.courts add constraint court_public_media_valid check(
 coalesce(cardinality(photo_paths)<=8 and array_position(photo_paths,null) is null,false)
 and (surface_type is null or length(surface_type)<=80));
alter table public.turf_fields drop constraint if exists turf_public_media_valid;
alter table public.turf_fields add constraint turf_public_media_valid check(
 coalesce(cardinality(photo_paths)<=8 and array_position(photo_paths,null) is null,false)
 and (surface_type is null or length(surface_type)<=80));


-- Option B. Editable profiles.verification_tier is not verification evidence.
create or replace function public._venue_verification_tier(p_profile uuid)
returns text language sql stable security definer set search_path=public as $$
 select case
  when p_profile is null or not exists(select 1 from auth.users u where u.id=p_profile and not coalesce(u.is_anonymous,false)) then 'none'
  when public._c1_has_identity(p_profile) then 'id'
  when exists(select 1 from auth.users u where u.id=p_profile and nullif(trim(u.phone),'') is not null and u.phone_confirmed_at is not null) then 'phone'
  else 'none' end
$$;
revoke all on function public._venue_verification_tier(uuid) from public,anon,authenticated;

create or replace function public.my_venue_verification_tier()
returns text language sql stable security definer set search_path=public as $$
 select public._venue_verification_tier(auth.uid())
$$;
revoke all on function public.my_venue_verification_tier() from public,anon,authenticated;
grant execute on function public.my_venue_verification_tier() to authenticated;

create or replace function public._require_venue_verification()
returns void language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null then raise exception 'Giriş yapılmamış' using errcode='42501';end if;
 if not coalesce(public.verification_rank(public._venue_verification_tier(auth.uid()))>=public.verification_rank('phone'),false) then
  raise exception 'Tesis ve partner işlemleri için telefon veya kimlik doğrulaması gerekli.' using errcode='42501';
 end if;
end;$$;
revoke all on function public._require_venue_verification() from public,anon,authenticated;

create or replace function public.guard_venue_verification_tier()
returns trigger language plpgsql security definer set search_path=public as $$
declare verified text;begin
 verified:=public._venue_verification_tier(new.id);
 if new.verification_tier in ('phone','id') and verification_rank(new.verification_tier)>verification_rank(verified) then
  raise exception 'Doğrulama seviyesi yalnız sunucuda doğrulanmış kaynaktan gelir.' using errcode='42501';
 end if;
 return new;
end;$$;
drop trigger if exists guard_venue_verification_tier on public.profiles;
create trigger guard_venue_verification_tier before insert or update of verification_tier on public.profiles for each row execute function public.guard_venue_verification_tier();
revoke all on function public.guard_venue_verification_tier() from public,anon,authenticated;


create or replace function public.claim_slot(
  p_court     uuid,
  p_starts_at timestamptz,
  p_guests    int default 0,
  p_needed    int default 0)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_court  record;
  v_player record;
  v_id     uuid;
  v_local  time;
begin
  perform public._require_venue_verification();
  perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  select * into v_court from public.courts where id = p_court and active;
  if v_court is null then raise exception 'Kort bulunamadı'; end if;

  select * into v_player from public.court_players where profile_id = auth.uid();
  if v_player.banned_until is not null and v_player.banned_until > now() then
    raise exception 'Tekrar tekrar gelmediğin için % tarihine kadar sıra alamazsın',
      to_char(v_player.banned_until at time zone 'Europe/Istanbul', 'DD.MM.YYYY');
  end if;



  if exists (
    select 1 from public.court_slots
     where owner_id = auth.uid()
       and status in ('claimed', 'active')
       and starts_at + interval '1 hour' > now()
       -- Az önce çift dokunuşla aldığımız kutunun kendisiyse "zaten aktif
       -- kutun var" demek yanlış olurdu — aşağıda idempotent dönülecek.
       -- Yalnızca TAM OLARAK aynı kort+saat için geçerli: yoksa kişi aynı
       -- saatte iki farklı kortu birden "kendi kutum" diyerek alabilirdi.
       and not (court_id = p_court and starts_at = p_starts_at)
  ) or exists (
    select 1 from public.court_slot_players sp
      join public.court_slots s on s.id = sp.slot_id
     where sp.profile_id = auth.uid() and sp.status = 'accepted'
       and s.status in ('claimed', 'active')
       and s.starts_at + interval '1 hour' > now()
  ) then
    raise exception 'Zaten aktif bir sıran var';
  end if;

  if p_starts_at <> date_trunc('hour', p_starts_at) then
    raise exception 'Saat tam saat olmalı';
  end if;
  if p_starts_at < date_trunc('hour', now()) then
    raise exception 'Geçmiş saat alınamaz';
  end if;
  if p_starts_at > date_trunc('hour', now()) + interval '3 hours' then
    raise exception 'En fazla 3 saat ilerisi alınabilir';
  end if;

  v_local := (p_starts_at at time zone 'Europe/Istanbul')::time;
  if v_local < v_court.opens_at or v_local >= v_court.closes_at then
    raise exception 'Kort o saatte kapalı';
  end if;

  if p_guests + p_needed + 1 > v_court.capacity then
    raise exception 'Kort en fazla % kişilik', v_court.capacity;
  end if;

  begin
    insert into public.court_slots
      (court_id, starts_at, owner_id, guest_count, needed)
    values (p_court, p_starts_at, auth.uid(), p_guests, p_needed)
    returning id into v_id;
  exception when unique_violation then
    select id into v_id from public.court_slots
     where court_id = p_court and starts_at = p_starts_at and status in ('claimed','active','done');

    if v_id is null or (select owner_id from public.court_slots where id = v_id) <> auth.uid() then
      raise exception 'O saati az önce başkası aldı';
    end if;
    -- Kendi çift dokunuşumuz: hata değil, zaten aldığın kutu dönüyor.
  end;

  insert into public.court_players (profile_id) values (auth.uid())
    on conflict (profile_id) do nothing;

  return v_id;
end; $$;

revoke all on function public.claim_slot(uuid,timestamptz,int,int) from public,anon,authenticated;
grant execute on function public.claim_slot(uuid,timestamptz,int,int) to authenticated;

create or replace function public.extend_slot(p_slot uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_slot record; v_court record; v_next timestamptz; v_id uuid; v_local time;
begin
  perform public._require_venue_verification();
  if auth.uid() is null then raise exception 'Giriş yapılmamış';end if;
  perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));
  select * into v_slot from public.court_slots where id = p_slot;
  if v_slot is null then raise exception 'Kutu bulunamadı'; end if;
  if v_slot.owner_id <> auth.uid() then raise exception 'Yetkisiz'; end if;

  v_next := v_slot.starts_at + interval '1 hour';

  -- İkinci çağrı geldiğinde ilk çağrı zaten kutuyu 'done' yapmış olabilir;
  -- bu durumda "önce doğrula" hatası yerine mevcut uzatılmış kutuyu dön.
  if v_slot.status = 'done' then
    select id into v_id from public.court_slots
     where court_id = v_slot.court_id and starts_at = v_next
       and owner_id = auth.uid() and status in ('claimed','active','done');
    if v_id is not null then return v_id; end if;
    raise exception 'Bu kutu artık geçerli değil';
  end if;

  if v_slot.status <> 'active' then
    raise exception 'Uzatmak için önce kortta olduğunu doğrula';
  end if;

  if now() < v_next - interval '15 minutes' then
    raise exception 'Uzatma saatin sonunda açılır';
  end if;

  select * into v_court from public.courts where id = v_slot.court_id;
  v_local := (v_next at time zone 'Europe/Istanbul')::time;
  if v_local < v_court.opens_at or v_local >= v_court.closes_at then
    raise exception 'Kort kapanıyor';
  end if;

  begin
    insert into public.court_slots
      (court_id, starts_at, owner_id, guest_count, status, checked_in_at)
    values (v_slot.court_id, v_next, auth.uid(), v_slot.guest_count,
            'active', now())
    returning id into v_id;
  exception when unique_violation then
    select id into v_id from public.court_slots
     where court_id = v_slot.court_id and starts_at = v_next and status in ('claimed','active','done');

    if v_id is null or (select owner_id from public.court_slots where id = v_id) <> auth.uid() then
      raise exception 'Sonraki saati başkası aldı';
    end if;
    -- Kendi çift dokunuşumuz: hata değil, zaten uzattığın kutu dönüyor.
  end;

  update public.court_slots set status = 'done' where id = p_slot;
  return v_id;
end; $$;

revoke all on function public.extend_slot(uuid) from public,anon,authenticated;
grant execute on function public.extend_slot(uuid) to authenticated;

create or replace function public.check_in_slot(
  p_slot uuid, p_lat numeric, p_lng numeric)
returns boolean
language plpgsql security definer set search_path = public as $$
declare v_slot record; v_court record; v_distance numeric;
begin
  perform public._require_venue_verification();
  select * into v_slot from public.court_slots where id = p_slot;
  if v_slot is null then raise exception 'Kutu bulunamadı'; end if;
  if v_slot.owner_id <> auth.uid() then raise exception 'Yetkisiz'; end if;
  if v_slot.status not in ('claimed', 'active') then
    raise exception 'Bu kutu artık geçerli değil';
  end if;

  -- Saatinden 15 dakika önce başlayabilir; erken gelen kortu boş bulmuşsa
  -- beklemesin.
  if now() < v_slot.starts_at - interval '15 minutes' then
    raise exception 'Henüz erken';
  end if;

  select * into v_court from public.courts where id = v_slot.court_id;
  v_distance := public.meters_between(p_lat, p_lng, v_court.lat, v_court.lng);
  if v_distance > public.court_checkin_radius() then
    raise exception 'Kortta değilsin (% metre uzaktasın)', round(v_distance);
  end if;

  update public.court_slots
     set checked_in_at = now(), status = 'active'
   where id = p_slot;

  -- Geldiğinde sayaç sıfırlanır: ceza ÜST ÜSTE gelmemeye, toplama değil.
  update public.court_players set no_shows = 0 where profile_id = auth.uid();

  return true;
end; $$;

revoke all on function public.check_in_slot(uuid,numeric,numeric) from public,anon,authenticated;
grant execute on function public.check_in_slot(uuid,numeric,numeric) to authenticated;

create or replace function public.request_join(p_slot uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare v_slot record;
begin
  perform public._require_venue_verification();
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  select * into v_slot from public.court_slots where id = p_slot;
  if v_slot is null then raise exception 'Kutu bulunamadı'; end if;
  if v_slot.owner_id = auth.uid() then raise exception 'Bu senin oyunun'; end if;
  if v_slot.status not in ('claimed', 'active') then
    raise exception 'Bu oyun artık geçerli değil';
  end if;
  if v_slot.needed <= 0 then raise exception 'Oyuncu aranmıyor'; end if;



  insert into public.court_slot_players (slot_id, profile_id)
  values (p_slot, auth.uid())
  on conflict (slot_id, profile_id) do nothing;

  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (v_slot.owner_id, 'court_join', 'Oyununa katılmak isteyen var',
          'Kabul veya reddet.', auth.uid(), 'court_slot', p_slot);
end; $$;

revoke all on function public.request_join(uuid) from public,anon,authenticated;
grant execute on function public.request_join(uuid) to authenticated;

create or replace function public.review_join(
  p_slot uuid, p_profile uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare v_slot record; v_accepted int;
begin
  perform public._require_venue_verification();
  select * into v_slot from public.court_slots where id = p_slot;
  if v_slot is null then raise exception 'Kutu bulunamadı'; end if;
  if v_slot.owner_id <> auth.uid() then raise exception 'Yetkisiz'; end if;

  if p_accept then
    select count(*) into v_accepted from public.court_slot_players
     where slot_id = p_slot and status = 'accepted';
    if v_accepted >= v_slot.needed then
      raise exception 'Aranan oyuncu sayısı doldu';
    end if;
  end if;

  update public.court_slot_players
     set status = case when p_accept then 'accepted' else 'rejected' end
   where slot_id = p_slot and profile_id = p_profile;

  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (p_profile, 'court_join_result',
          case when p_accept then 'Oyuna kabul edildin'
               else 'Oyun isteğin kabul edilmedi' end,
          null, auth.uid(), 'court_slot', p_slot);
end; $$;

revoke all on function public.review_join(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.review_join(uuid,uuid,boolean) to authenticated;

create or replace function public.join_court_waitlist(p_court uuid,p_start timestamptz) returns uuid language plpgsql security definer set search_path=public as $$
declare result uuid;c courts;begin
  perform public._require_venue_verification();
 perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));
 if auth.uid() is null or not public._court_waiter_eligible(auth.uid()) then raise exception 'Bekleme listesi için erişim ve telefon/kimlik doğrulaması gerekli; aktif sıra bulunmamalı.';end if;
 select * into c from courts where id=p_court and active;
 if c.id is null or p_start is null or p_start<=clock_timestamp() or p_start>date_trunc('hour',clock_timestamp())+interval '3 hours' or p_start<>date_trunc('hour',p_start)
 or (p_start at time zone 'Europe/Istanbul')::time<c.opens_at or (p_start at time zone 'Europe/Istanbul')::time>=c.closes_at then raise exception 'Geçerli bir gelecek kort saati seç.';end if;
 select id into result from court_waitlist where profile_id=auth.uid() and court_id=p_court and starts_at=p_start and status in ('waiting','offered');
 if result is not null then perform public._advance_court_waitlist(p_court,p_start);return result;end if;
 if exists(select 1 from court_waitlist where profile_id=auth.uid() and status in ('waiting','offered')) then raise exception 'Önce mevcut bekleme listesinden çık.';end if;
 if not exists(select 1 from court_slots where court_id=p_court and starts_at=p_start and status in ('claimed','active')) then raise exception 'Saat boş; doğrudan sıra alabilirsin.';end if;
 insert into court_waitlist(court_id,starts_at,profile_id) values(p_court,p_start,auth.uid()) returning id into result;return result;
end;$$;

revoke all on function public.join_court_waitlist(uuid,timestamptz) from public,anon,authenticated;
grant execute on function public.join_court_waitlist(uuid,timestamptz) to authenticated;

create or replace function public.accept_court_waitlist(p_id uuid,p_guests int default 0,p_needed int default 0) returns uuid language plpgsql security definer set search_path=public as $$
declare w court_waitlist;begin
  perform public._require_venue_verification();
 perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));
 if auth.uid() is null or not public._swan_feature_for_profile('court_waitlist',auth.uid()) then raise exception 'Bekleme listesi erişimi kapalı.';end if;
 select * into w from court_waitlist where id=p_id and profile_id=auth.uid();
 if w.id is null then raise exception 'Bu sıraya erişilemiyor.';end if;
 if w.status='claimed' then return w.claimed_slot_id;end if;
 perform public._advance_court_waitlist(w.court_id,w.starts_at);
 select * into w from court_waitlist where id=p_id;
 if w.status<>'offered' or w.offered_until<=clock_timestamp() then raise exception 'Fırsat süresi dolmuş veya henüz sana gelmemiş.';end if;
 return public.claim_slot(w.court_id,w.starts_at,p_guests,p_needed);
end;$$;

revoke all on function public.accept_court_waitlist(uuid,int,int) from public,anon,authenticated;
grant execute on function public.accept_court_waitlist(uuid,int,int) to authenticated;

create or replace function public.request_turf_slot(p_field uuid, p_starts_at timestamptz)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_field   record;
  v_new     boolean;
  v_body    text;
  v_managers int;
begin
  perform public._require_venue_verification();
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  select * into v_field from public.turf_fields where id = p_field and active;
  if v_field is null then raise exception 'Saha bulunamadı'; end if;

  select count(*) into v_managers
    from public.turf_field_managers
   where field_id = p_field and status = 'active'
     and profile_id<>auth.uid() and not public.is_blocked_between(auth.uid(),profile_id);

  -- Yöneticisi atanmamış sahada mesaj gidecek kimse yok; sessizce "gönderdim"
  -- demek kullanıcıyı yanıltırdı.
  if v_managers = 0 then
    raise exception 'Saha yetkilisine uygulamadan mesaj gönderilemiyor — tesisle iletişime geçmelisin';
  end if;

  insert into public.turf_slot_requests (field_id, starts_at, requester_id)
  values (p_field, p_starts_at, auth.uid())
  on conflict (field_id, starts_at, requester_id) do nothing
  returning true into v_new;

  -- Zaten istemiş: ikinci bir mesaj gönderme.
  if v_new is not true then return; end if;

  v_body := v_field.venue_name || ' · ' || v_field.name || ' · ' ||
            to_char(p_starts_at at time zone 'Europe/Istanbul', 'DD.MM HH24:MI') ||
            ' saati müsait mi? Uygulamadan sordum.';

  insert into public.direct_messages (sender_id, recipient_id, body)
  select auth.uid(), m.profile_id, v_body
    from public.turf_field_managers m
   where m.field_id = p_field and m.status = 'active'
     and m.profile_id<>auth.uid() and not public.is_blocked_between(auth.uid(),m.profile_id);
end; $$;

revoke all on function public.request_turf_slot(uuid,timestamptz) from public,anon,authenticated;
grant execute on function public.request_turf_slot(uuid,timestamptz) to authenticated;

create or replace function public.respond_partner_ping(
  p_request uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare v_req record; v_matched int;
begin
  if p_accept is null then raise exception 'Yanıt kabul veya ret olmalı';end if;
  if p_accept then perform public._require_venue_verification();end if;
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  if p_accept and exists(select 1 from public.partner_requests pr where pr.id=p_request and (pr.expires_at<=now() or public.is_blocked_between(auth.uid(),pr.requester_id))) then raise exception 'Bu istek artık geçerli değil';end if;

  if not exists (
    select 1 from public.partner_request_pings
     where request_id = p_request and profile_id = auth.uid() and status = 'pending'
  ) then
    raise exception 'Bu istek sana gönderilmemiş ya da zaten yanıtladın';
  end if;

  if not p_accept then
    update public.partner_request_pings
       set status = 'declined'
     where request_id = p_request and profile_id = auth.uid();
    return;
  end if;

  update public.partner_requests
     set status = 'matched'
   where id = p_request and status = 'open';

  get diagnostics v_matched = row_count;
  if v_matched = 0 then
    update public.partner_request_pings
       set status = 'expired'
     where request_id = p_request and profile_id = auth.uid();
    raise exception 'Bu istek artık geçerli değil — başka biriyle eşleşmiş olabilir';
  end if;

  select * into v_req from public.partner_requests where id = p_request;

  update public.partner_request_pings
     set status = 'accepted'
   where request_id = p_request and profile_id = auth.uid();

  update public.partner_request_pings
     set status = 'expired'
   where request_id = p_request and profile_id <> auth.uid() and status = 'pending';

  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (v_req.requester_id, 'partner_request_accepted', 'Partnerin bulundu',
          (select full_name from public.profiles where id = auth.uid())
            || ' teklifini kabul etti.',
          auth.uid(), 'partner_request', p_request);
end; $$;

revoke all on function public.respond_partner_ping(uuid,boolean) from public,anon,authenticated;
grant execute on function public.respond_partner_ping(uuid,boolean) to authenticated;

create or replace function public._court_waiter_eligible(p_profile uuid)
returns boolean language sql volatile security definer set search_path=public as $$
 select public._swan_feature_for_profile('court_waitlist',p_profile)
 and coalesce(verification_rank(public._venue_verification_tier(p_profile))>=verification_rank('phone'),false)
 and not exists(select 1 from court_players where profile_id=p_profile and banned_until>clock_timestamp())
 and not exists(select 1 from court_slots where owner_id=p_profile and status in ('claimed','active') and starts_at+interval '1 hour'>clock_timestamp())
 and not exists(select 1 from court_slot_players sp join court_slots s on s.id=sp.slot_id where sp.profile_id=p_profile and sp.status='accepted' and s.status in ('claimed','active') and s.starts_at+interval '1 hour'>clock_timestamp());
$$;

revoke all on function public._court_waiter_eligible(uuid) from public,anon,authenticated;

create or replace function public.court_timeline(p_court uuid)
returns table (
  starts_at timestamptz,
  slot_id   uuid,
  owner_id  uuid,
  owner_name text,
  status    text,
  needed    int,
  players   int,
  mine      boolean
)
language sql stable security definer set search_path = public as $$
  with court as (select * from public.courts where id = p_court and active),
  -- Şeridin başı: içinde bulunduğumuz saat. Sonu: 3 saat ileri.
  hours as (
    select generate_series(
             date_trunc('hour', now()),
             date_trunc('hour', now()) + interval '3 hours',
             interval '1 hour') as h
  )
  select
    hours.h,
    s.id,
    case when auth.uid() is not null then s.owner_id end,
    case when auth.uid() is not null then p.full_name end,
    coalesce(s.status, 'free'),
    coalesce(s.needed, 0),
    coalesce(s.guest_count, 0)
      + coalesce((select count(*)::int from public.court_slot_players sp
                   where sp.slot_id = s.id and sp.status = 'accepted'), 0)
      + case when s.id is null then 0 else 1 end,
    coalesce(s.owner_id = auth.uid(), false)
  from hours
  cross join court
  left join public.court_slots s
    on s.court_id = court.id
   and s.starts_at = hours.h
   and s.status in ('claimed', 'active')
  left join public.profiles p on p.id = s.owner_id
  -- Kortun kapalı olduğu saatler şeritte görünmez.
  where (hours.h at time zone 'Europe/Istanbul')::time >= court.opens_at
    and (hours.h at time zone 'Europe/Istanbul')::time <  court.closes_at
  order by 1;
$$;

create or replace function public.open_slots(p_city text default null)
returns table (
  slot_id    uuid,
  court_id   uuid,
  court_name text,
  venue      text,
  city_name  text,
  starts_at  timestamptz,
  owner_id   uuid,
  owner_name text,
  needed     int,
  accepted   int,
  requested  boolean
)
language sql stable security definer set search_path = public as $$
  select s.id, c.id, c.name, c.venue, ct.name, s.starts_at,
         case when auth.uid() is not null then s.owner_id end,
         case when auth.uid() is not null then p.full_name else 'Oyuncu' end, s.needed,
         (select count(*)::int from public.court_slot_players sp
           where sp.slot_id = s.id and sp.status = 'accepted'),
         exists (select 1 from public.court_slot_players sp
                  where sp.slot_id = s.id and sp.profile_id = auth.uid())
    from public.court_slots s
    join public.courts c on c.id = s.court_id
    join public.profiles p on p.id = s.owner_id
    left join public.cities ct on ct.code = c.city_code
   where c.active and s.status in ('claimed', 'active')
     and s.starts_at + interval '1 hour' > now()
     and s.needed > 0
     and s.owner_id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid)
     and (p_city is null or c.city_code = p_city)
     and (select count(*) from public.court_slot_players sp
           where sp.slot_id = s.id and sp.status = 'accepted') < s.needed
   order by s.starts_at;
$$;

create or replace function public.turf_occupancy_grid(p_field uuid, p_days int default 7)
returns table (
  starts_at        timestamptz,
  occupied         boolean,
  note             text,
  requested_by_me  boolean
)
language sql stable security definer set search_path = public as $$
  with field as (select * from public.turf_fields where id = p_field and active),
  slots as (
    select (d.day + (h.hr || ' hours')::interval) as local_starts_at
      from field f,
           lateral generate_series(
             date_trunc('day', now() at time zone 'Europe/Istanbul'),
             date_trunc('day', now() at time zone 'Europe/Istanbul')
               + ((greatest(p_days, 1) - 1) || ' days')::interval,
             interval '1 day') as d(day),
           lateral generate_series(
             extract(hour from f.opens_at)::int,
             extract(hour from f.closes_at)::int - 1) as h(hr)
  )
  select
    (s.local_starts_at at time zone 'Europe/Istanbul'),
    (o.id is not null),
    case when auth.uid() is not null and public.can_edit_turf_occupancy(p_field) then o.note end,
    exists (
      select 1 from public.turf_slot_requests r
       where r.field_id = p_field
         and r.starts_at = (s.local_starts_at at time zone 'Europe/Istanbul')
         and r.requester_id = auth.uid()
    )
    from slots s
    left join public.turf_occupancy o
      on o.field_id = p_field
     and o.starts_at = (s.local_starts_at at time zone 'Europe/Istanbul')
   where (s.local_starts_at at time zone 'Europe/Istanbul') >= now()
   order by 1;
$$;

-- Guest gets facility metadata and safe RPC projections, not player tables.
grant select on public.courts,public.turf_fields,public.cities,public.sports to anon;
revoke select on public.court_slots,public.court_slot_players,public.court_players,public.turf_occupancy,public.turf_slot_requests,public.partner_requests,public.partner_request_pings,public.sport_interests from public,anon;
revoke all on function public.court_timeline(uuid),public.open_slots(text),public.turf_occupancy_grid(uuid,int),public.court_sport_codes() from public,anon,authenticated;
grant execute on function public.court_timeline(uuid),public.open_slots(text),public.turf_occupancy_grid(uuid,int),public.court_sport_codes() to anon,authenticated;

-- Old private requests stay private. Only explicit new opt-in publishes.
alter table public.partner_requests add column if not exists is_public boolean not null default false;
drop function if exists public.seek_partner(text,numeric,numeric);


create or replace function public.seek_partner(
  p_sport text,
  p_lat   numeric default null,
  p_lng   numeric default null,
  p_public boolean default false)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_city   text;
  v_banned timestamptz;
  v_id     uuid;
begin
  perform public._require_venue_verification();
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  select city_code into v_city
    from public.profiles where id = auth.uid();



  select banned_until into v_banned
    from public.court_players where profile_id = auth.uid();
  if v_banned is not null and v_banned > now() then
    raise exception 'Tekrar tekrar gelmediğin için % tarihine kadar bu özelliği kullanamazsın',
      to_char(v_banned at time zone 'Europe/Istanbul', 'DD.MM.YYYY');
  end if;

  if not exists (select 1 from public.sports where code = p_sport) then
    raise exception 'Branş bulunamadı';
  end if;

  -- Tek aktif istek — courts'taki "tek aktif kutu" kuralının aynısı, akşamı
  -- birden fazla açık istekle bloke etmeyi engelliyor.
  if exists (
    select 1 from public.partner_requests
     where requester_id = auth.uid() and status = 'open'
  ) then
    raise exception 'Zaten açık bir isteğin var';
  end if;

  insert into public.partner_requests (requester_id, sport_code, city_code, lat, lng, is_public)
  values (auth.uid(), p_sport, v_city, p_lat, p_lng, coalesce(p_public,false))
  returning id into v_id;

  -- Aday havuzu: aynı branşla ilgilenen + aynı şehir + doğrulanmış + yasaklı
  -- değil + kendisi değil. Küçük şehirde bildirim seli olmasın diye 40 ile
  -- sınırlı, rastgele sıralı (aynı 40 kişiye her seferinde gitmesin).
  with candidates as (
    select si.profile_id
      from public.sport_interests si
      join public.profiles p on p.id = si.profile_id
      left join public.court_players cp on cp.profile_id = si.profile_id
     where si.sport_code = p_sport
       and p.city_code is not distinct from v_city
       and p.id <> auth.uid()
       and public.verification_rank(public._venue_verification_tier(p.id))
           >= public.verification_rank('phone')
       and not public.is_blocked_between(auth.uid(),p.id)
       and (cp.banned_until is null or cp.banned_until <= now())
     order by random()
     limit 40
  ),
  pinged as (
    insert into public.partner_request_pings (request_id, profile_id)
    select v_id, profile_id from candidates
    returning profile_id
  )
  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  select pinged.profile_id, 'partner_request', 'Kort partneri aranıyor',
         (select full_name from public.profiles where id = auth.uid())
           || ' yakınında ' || (select name from public.sports where code = p_sport)
           || ' oynamak istiyor, müsait misin?',
         auth.uid(), 'partner_request', v_id
    from pinged;

  return v_id;
end; $$;

revoke all on function public.seek_partner(text,numeric,numeric,boolean) from public,anon,authenticated;
grant execute on function public.seek_partner(text,numeric,numeric,boolean) to authenticated;

create or replace function public.public_partner_requests(p_sport text default null,p_city text default null)
returns table(request_id uuid,sport_code text,sport_name text,city_name text,created_at timestamptz,expires_at timestamptz)
language sql stable security definer set search_path=public as $$
 select pr.id,pr.sport_code,s.name,c.name,pr.created_at,pr.expires_at
 from public.partner_requests pr join public.sports s on s.code=pr.sport_code left join public.cities c on c.code=pr.city_code
 where pr.is_public and pr.status='open' and pr.expires_at>now()
 and (p_sport is null or pr.sport_code=p_sport) and (p_city is null or pr.city_code=p_city)
 and public.verification_rank(public._venue_verification_tier(pr.requester_id))>=public.verification_rank('phone')
 and not exists(select 1 from public.court_players cp where cp.profile_id=pr.requester_id and cp.banned_until>now())
 and (auth.uid() is null or (pr.requester_id<>auth.uid() and not public.is_blocked_between(auth.uid(),pr.requester_id)))
 order by pr.created_at desc,pr.id limit 100
$$;
revoke all on function public.public_partner_requests(text,text) from public,anon,authenticated;
grant execute on function public.public_partner_requests(text,text) to anon,authenticated;

-- Public Oynayalım atomically accepts the invitation via the existing matching path.
create or replace function public.send_partner_ping(p_request uuid)
returns void language plpgsql security definer set search_path=public as $$
declare request public.partner_requests;begin
 perform public._require_venue_verification();
 select * into request from public.partner_requests where id=p_request for update;
 if request.id is null or not request.is_public or request.status<>'open' or request.expires_at<=now()
  or request.requester_id=auth.uid() or public.is_blocked_between(auth.uid(),request.requester_id)
  or public.verification_rank(public._venue_verification_tier(request.requester_id))<public.verification_rank('phone')
  or exists(select 1 from public.court_players cp where cp.profile_id=request.requester_id and cp.banned_until>now()) then
  raise exception 'Bu oyun ilanı artık kullanılamıyor.';end if;
 if exists(select 1 from public.court_players where profile_id=auth.uid() and banned_until>now()) then
  raise exception 'Partner işlemlerine erişimin geçici olarak kısıtlı.';end if;
 insert into public.partner_request_pings(request_id,profile_id) values(p_request,auth.uid())
  on conflict(request_id,profile_id) do update set status='pending' where partner_request_pings.status='pending';
 perform public.respond_partner_ping(p_request,true);
end;$$;
revoke all on function public.send_partner_ping(uuid) from public,anon,authenticated;
grant execute on function public.send_partner_ping(uuid) to authenticated;

create or replace function public.guard_venue_action_write()
returns trigger language plpgsql security definer set search_path=public as $$
begin perform public._require_venue_verification();return new;end;$$;
revoke all on function public.guard_venue_action_write() from public,anon,authenticated;
drop trigger if exists guard_venue_action_write on public.turf_slot_requests;
create trigger guard_venue_action_write before insert on public.turf_slot_requests for each row execute function public.guard_venue_action_write();
drop trigger if exists guard_venue_action_write on public.sport_interests;
create trigger guard_venue_action_write before insert or update on public.sport_interests for each row execute function public.guard_venue_action_write();

insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'Saha ve partner ilanlarına hesapsız bakabilir miyim?',
 'Evet. Kortları, halı sahaları, müsait saatleri ve halka açık oyun ilanlarını misafir olarak inceleyebilirsin. Rezervasyon, bekleme listesi, kortta geldim onayı ve partner iletişimi için hesap ve SMS ile doğrulanmış telefon veya onaylı kimlik gerekir. Doğrulama ekranında telefonuna kod isteyebilirsin. Halı saha saat isteği kesin rezervasyon değildir; saha yetkilisiyle anlaşman gerekir. Partner isteğini halka açık yayımlamayı seçersen branş, şehir ve geçerlilik saati misafirlere görünür; adın, profil kimliğin ve konumun görünmez.',
 'Sahalar','everyone',30,'/kortlar',null
where not exists(select 1 from public.faq_entries where question='Saha ve partner ilanlarına hesapsız bakabilir miyim?');


create or replace function public.cancel_partner_request(p_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 if auth.uid() is null then raise exception 'Giriş yapılmamış';end if;
 perform 1 from public.partner_requests where id=p_id and requester_id=auth.uid() for update;
 if not found then raise exception 'Bu isteğe erişilemiyor.';end if;
 update public.partner_requests set status='cancelled' where id=p_id and requester_id=auth.uid() and status='open';
 update public.partner_request_pings set status='expired' where request_id=p_id and status='pending';
end;$$;
revoke all on function public.cancel_partner_request(uuid) from public,anon,authenticated;
grant execute on function public.cancel_partner_request(uuid) to authenticated;
