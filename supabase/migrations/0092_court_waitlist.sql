-- Private FIFO court waitlist; existing claim/check-in rules remain authoritative.
set local lock_timeout='15s';
create or replace function public._swan_feature_for_profile(p_key text,p_profile uuid)
returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from feature_flags f where f.key=p_key and (
 f.audience='everyone' or (f.audience in ('admins','testers') and exists(select 1 from profiles p where p.id=p_profile and p.is_platform_admin))
 or (f.audience='testers' and exists(select 1 from feature_flag_testers t where t.key=f.key and (t.profile_id=p_profile or exists(select 1 from club_memberships m where m.club_id=t.club_id and m.profile_id=p_profile and m.status='active'))))));
$$;
revoke all on function public._swan_feature_for_profile(text,uuid) from public,anon,authenticated;
create or replace function public.my_feature_flags() returns table(key text)
language sql stable security definer set search_path=public as $$select f.key from feature_flags f where public._swan_feature_for_profile(f.key,auth.uid())$$;

create table if not exists public.court_waitlist (
 id uuid primary key default gen_random_uuid(),court_id uuid not null references courts(id) on delete cascade,
 starts_at timestamptz not null,profile_id uuid not null references profiles(id) on delete cascade,
 status text not null default 'waiting' check(status in ('waiting','offered','claimed','cancelled','expired')),
 created_at timestamptz not null default clock_timestamp(),offered_until timestamptz,
 claimed_slot_id uuid references court_slots(id) on delete set null
);
create unique index if not exists court_waitlist_one_live on court_waitlist(profile_id) where status in ('waiting','offered');
create index if not exists court_waitlist_fifo on court_waitlist(court_id,starts_at,created_at,id) where status in ('waiting','offered');
alter table court_waitlist enable row level security;
drop policy if exists waitlist_self on court_waitlist;
create policy waitlist_self on court_waitlist for select to authenticated using(profile_id=auth.uid());
revoke insert,update,delete on court_waitlist from public,anon,authenticated;
-- Terminal games keep their history; cancelled/expired slots can be taken again.
alter table court_slots drop constraint if exists court_slot_unique;
create unique index if not exists court_slot_live_unique on court_slots(court_id,starts_at) where status in ('claimed','active','done');

create or replace function public._court_waiter_eligible(p_profile uuid)
returns boolean language sql volatile security definer set search_path=public as $$
 select public._swan_feature_for_profile('court_waitlist',p_profile)
 and coalesce((select verification_rank(verification_tier)>=verification_rank('location') from profiles where id=p_profile),false)
 and not exists(select 1 from court_players where profile_id=p_profile and banned_until>clock_timestamp())
 and not exists(select 1 from court_slots where owner_id=p_profile and status in ('claimed','active') and starts_at+interval '1 hour'>clock_timestamp())
 and not exists(select 1 from court_slot_players sp join court_slots s on s.id=sp.slot_id where sp.profile_id=p_profile and sp.status='accepted' and s.status in ('claimed','active') and s.starts_at+interval '1 hour'>clock_timestamp());
$$;
revoke all on function public._court_waiter_eligible(uuid) from public,anon,authenticated;

create or replace function public._advance_court_waitlist(p_court uuid,p_start timestamptz)
returns void language plpgsql security definer set search_path=public as $$
declare w court_waitlist;begin
 perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));
 update court_waitlist set status='expired' where court_id=p_court and starts_at=p_start and status in ('waiting','offered') and (
 starts_at<=clock_timestamp() or (status='offered' and offered_until<=clock_timestamp()) or not public._court_waiter_eligible(profile_id)
 or not exists(select 1 from courts where id=p_court and active));
 if p_start<=clock_timestamp() or exists(select 1 from court_slots where court_id=p_court and starts_at=p_start and status in ('claimed','active','done')) then return;end if;
 if exists(select 1 from court_waitlist where court_id=p_court and starts_at=p_start and status='offered') then return;end if;
 select * into w from court_waitlist where court_id=p_court and starts_at=p_start and status='waiting' order by created_at,id limit 1;
 if w.id is null then return;end if;
 update court_waitlist set status='offered',offered_until=least(clock_timestamp()+interval '5 minutes',p_start) where id=w.id;
 insert into notifications(profile_id,kind,title,body,entity_type,entity_id) values(w.profile_id,'court_waitlist','Kort saati boşaldı','Sıradaki fırsat sana ait. Saha İşlemlerim ekranında süre dolmadan al; korta varınca ayrıca onaylamalısın.','court',p_court);
end;$$;
revoke all on function public._advance_court_waitlist(uuid,timestamptz) from public,anon,authenticated;

-- One bounded global mutex also protects legacy clients and cron statements.
-- BEFORE STATEMENT obtains it before row/index locks, preventing reverse-order deadlocks.
create or replace function public.court_waitlist_lock() returns trigger language plpgsql security definer set search_path=public as $$begin perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));return null;end;$$;
drop trigger if exists court_waitlist_lock on court_slots;
create trigger court_waitlist_lock before insert or update or delete on court_slots for each statement execute function court_waitlist_lock();
create or replace function public.court_waitlist_claim_guard() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.status not in ('claimed','active') then return new;end if;
 if auth.uid() is null or new.owner_id<>auth.uid() then raise exception 'Oturum gerekli.';end if;
 if exists(select 1 from court_slots s where s.owner_id=new.owner_id and s.status in ('claimed','active') and s.starts_at+interval '1 hour'>clock_timestamp()
 and not(s.court_id=new.court_id and s.starts_at=new.starts_at)
 and not(new.status='active' and s.status='active' and s.court_id=new.court_id and s.starts_at=new.starts_at-interval '1 hour'))
 or exists(select 1 from court_slot_players sp join court_slots s on s.id=sp.slot_id where sp.profile_id=new.owner_id and sp.status='accepted' and s.status in ('claimed','active') and s.starts_at+interval '1 hour'>clock_timestamp()) then raise exception 'Zaten aktif bir sıran var.';end if;
 perform public._advance_court_waitlist(new.court_id,new.starts_at);
 if exists(select 1 from court_waitlist where court_id=new.court_id and starts_at=new.starts_at and status='offered' and offered_until>clock_timestamp() and profile_id<>new.owner_id) then raise exception 'Bu saat sıradaki kişiye ayrıldı.';end if;
 return new;
end;$$;
drop trigger if exists court_waitlist_claim_guard on court_slots;
create trigger court_waitlist_claim_guard before insert on court_slots for each row execute function court_waitlist_claim_guard();
create or replace function public.court_waitlist_slot_changed() returns trigger language plpgsql security definer set search_path=public as $$
begin
 if tg_op='INSERT' then update court_waitlist set status='claimed',claimed_slot_id=new.id where court_id=new.court_id and starts_at=new.starts_at and profile_id=new.owner_id and status='offered';
 elsif new.status in ('cancelled','expired') and old.status is distinct from new.status then perform public._advance_court_waitlist(new.court_id,new.starts_at);end if;
 return new;end;$$;
drop trigger if exists court_waitlist_slot_changed on court_slots;
create trigger court_waitlist_slot_changed after insert or update on court_slots for each row execute function court_waitlist_slot_changed();
revoke all on function public.court_waitlist_lock(),public.court_waitlist_claim_guard(),public.court_waitlist_slot_changed() from public,anon,authenticated;

create or replace function public.join_court_waitlist(p_court uuid,p_start timestamptz) returns uuid language plpgsql security definer set search_path=public as $$
declare result uuid;c courts;begin
 perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));
 if auth.uid() is null or not public._court_waiter_eligible(auth.uid()) then raise exception 'Bekleme listesi için erişim ve konum doğrulaması gerekli; aktif sıra bulunmamalı.';end if;
 select * into c from courts where id=p_court and active;
 if c.id is null or p_start is null or p_start<=clock_timestamp() or p_start>date_trunc('hour',clock_timestamp())+interval '3 hours' or p_start<>date_trunc('hour',p_start)
 or (p_start at time zone 'Europe/Istanbul')::time<c.opens_at or (p_start at time zone 'Europe/Istanbul')::time>=c.closes_at then raise exception 'Geçerli bir gelecek kort saati seç.';end if;
 select id into result from court_waitlist where profile_id=auth.uid() and court_id=p_court and starts_at=p_start and status in ('waiting','offered');
 if result is not null then perform public._advance_court_waitlist(p_court,p_start);return result;end if;
 if exists(select 1 from court_waitlist where profile_id=auth.uid() and status in ('waiting','offered')) then raise exception 'Önce mevcut bekleme listesinden çık.';end if;
 if not exists(select 1 from court_slots where court_id=p_court and starts_at=p_start and status in ('claimed','active')) then raise exception 'Saat boş; doğrudan sıra alabilirsin.';end if;
 insert into court_waitlist(court_id,starts_at,profile_id) values(p_court,p_start,auth.uid()) returning id into result;return result;
end;$$;
create or replace function public.leave_court_waitlist(p_id uuid) returns void language plpgsql security definer set search_path=public as $$
declare w court_waitlist;begin
 perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));
 select * into w from court_waitlist where id=p_id and profile_id=auth.uid();
 if auth.uid() is null or w.id is null then raise exception 'Bu sıraya erişilemiyor.';end if;
 update court_waitlist set status='cancelled' where id=w.id and status in ('waiting','offered');
 perform public._advance_court_waitlist(w.court_id,w.starts_at);
end;$$;
create or replace function public.accept_court_waitlist(p_id uuid,p_guests int default 0,p_needed int default 0) returns uuid language plpgsql security definer set search_path=public as $$
declare w court_waitlist;begin
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
create or replace function public.my_court_waitlist() returns jsonb language plpgsql security definer set search_path=public as $$
declare w record;result jsonb;begin
 if auth.uid() is null or not public._swan_feature_for_profile('court_waitlist',auth.uid()) then raise exception 'Bekleme listesi erişimi kapalı.';end if;
 perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));
 for w in select distinct court_id,starts_at from court_waitlist where profile_id=auth.uid() and status in ('waiting','offered') loop perform public._advance_court_waitlist(w.court_id,w.starts_at);end loop;
 select coalesce(jsonb_agg(jsonb_build_object('id',w.id,'court_id',w.court_id,'court_name',c.name,'starts_at',w.starts_at,'status',w.status,'offered_until',w.offered_until,
 'position',(select count(*)+1 from court_waitlist x where x.court_id=w.court_id and x.starts_at=w.starts_at and x.status in ('waiting','offered') and (x.created_at,x.id)<(w.created_at,w.id))) order by w.created_at desc),'[]') into result
 from (select * from court_waitlist where profile_id=auth.uid() order by created_at desc limit 20) w join courts c on c.id=w.court_id;
 return result;
end;$$;
create or replace function public.court_waitlist_maintenance() returns void language plpgsql security definer set search_path=public as $$declare w record;begin
 perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));
 for w in select distinct court_id,starts_at from court_waitlist where status in ('waiting','offered') loop perform public._advance_court_waitlist(w.court_id,w.starts_at);end loop;
end;$$;
revoke all on function public.join_court_waitlist(uuid,timestamptz),public.leave_court_waitlist(uuid),public.accept_court_waitlist(uuid,int,int),public.my_court_waitlist() from public,anon;
grant execute on function public.join_court_waitlist(uuid,timestamptz),public.leave_court_waitlist(uuid),public.accept_court_waitlist(uuid,int,int),public.my_court_waitlist() to authenticated;
revoke all on function public.court_waitlist_maintenance() from public,anon,authenticated;
select cron.unschedule('swansport_court_waitlist') where exists(select 1 from cron.job where jobname='swansport_court_waitlist');
select cron.schedule('swansport_court_waitlist','* * * * *',$cron$select public.court_waitlist_maintenance();$cron$);
insert into public.feature_flags(key,audience,label,description) values('court_waitlist','admins','Kort bekleme listesi','Dolu gelecek saat için kişisel sıra ve süreli fırsat.') on conflict(key) do nothing;
insert into public.faq_entries(question,answer,category,audience,sort_order,route,feature)
select 'Dolu kort saatinde bekleme listesine nasıl girerim?','Kort detayında dolu gelecek saatin altındaki Bekleme listesine gir düğmesini kullan. Konum doğrulaması ve aktif sıra bulunmaması gerekir. Bir bekleme listesinde bulunabilirsin. Saat boşalınca sıradaki kişiye en fazla beş dakika, saat başlayana kadar fırsat verilir. Saha İşlemlerim ekranında süre dolmadan Saati al seç. Bu işlemden sonra korta varınca mevcut konum onayını yine yapmalısın. Fırsat süresi sunucuda korunur. Vazgeçersen listeden çıkabilirsin.','Sahalar','everyone',197,'/saha-islemlerim','court_waitlist'
where not exists(select 1 from faq_entries where feature='court_waitlist' and active);

create or replace function public.push_route(p_kind text, p_entity text)
returns text
language sql
immutable
as $fn$
  select case p_kind
    when 'message'                   then '/mesajlar'
    when 'application'               then '/basvurular'
    when 'offer'                     then '/bildirimler'
    when 'follow'                    then '/bildirimler'
    when 'fee'                       then '/aidatlarim'
    when 'fee_reminder'              then '/aidatlarim'
    when 'payment'                   then '/finans'
    when 'donation'                  then '/bagis'
    when 'attendance'                then '/attendance'
    when 'attendance_reminder'       then '/attendance'
    when 'event'                     then '/calendar'
    when 'announcement'              then '/announcements'
    when 'achievement'               then '/performance-analytics'
    when 'document'                  then '/documents'
    when 'documents'                 then '/documents'
    when 'document_expiry'           then '/documents'
    when 'partner_request'           then '/partner-ara'
    when 'partner_request_accepted'  then '/partner-ara'
    when 'turf_slot_request'         then '/halisahalar'
    when 'turf_field'                then '/halisahalar'
    when 'turf_manager'              then '/halisahalar'
    when 'store_decision'            then '/magaza-basvuru'
    when 'moderation'                then '/pazaryeri'
    when 'expense_approval'          then '/mali-isler'
    when 'expense_rejected'          then '/mali-isler'
    when 'commitment_due'            then '/mali-isler'
    when 'account_negative'          then '/mali-isler'
    when 'bank_unmatched'            then '/mali-isler'
    when 'period_closed'             then '/mali-isler'
    when 'period_blocked'            then '/mali-isler'
    when 'mention'                   then '/akis'
    when 'post_repost'               then '/akis'
    when 'post_quote'                then '/akis'
    when 'support'                   then '/destek'
    when 'eligibility'               then '/athletes'
    -- 0073
    when 'training_session'          then '/antrenman-oturumu'
    when 'training_result'           then '/antrenman-sonuc'
    when 'court_waitlist' then '/saha-islemlerim'
    when 'turf_delegation' then '/saha-islemlerim'
    else '/bildirimler'
  end;
$fn$;

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
  perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  select * into v_court from public.courts where id = p_court and active;
  if v_court is null then raise exception 'Kort bulunamadı'; end if;

  select * into v_player from public.court_players where profile_id = auth.uid();
  if v_player.banned_until is not null and v_player.banned_until > now() then
    raise exception 'Tekrar tekrar gelmediğin için % tarihine kadar sıra alamazsın',
      to_char(v_player.banned_until at time zone 'Europe/Istanbul', 'DD.MM.YYYY');
  end if;

  if public.verification_rank(
       (select verification_tier from public.profiles where id = auth.uid()))
     < public.verification_rank('location') then
    raise exception 'Sıra alabilmek için bir kez kortta olduğunu doğrulamalısın';
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

create or replace function public.extend_slot(p_slot uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_slot record; v_court record; v_next timestamptz; v_id uuid; v_local time;
begin
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

create or replace function public.cancel_slot(p_slot uuid)
returns void
language plpgsql security definer set search_path = public as $$
declare v_slot record;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış';end if;
  perform pg_advisory_xact_lock(hashtextextended('swansport_court_waitlist',0));
  select * into v_slot from public.court_slots where id = p_slot;
  if v_slot is null then raise exception 'Kutu bulunamadı'; end if;
  if v_slot.owner_id <> auth.uid() then raise exception 'Yetkisiz'; end if;

  if v_slot.status='cancelled' then return;end if;
  if v_slot.status not in ('claimed','active') then raise exception 'Bu kutu artık geçerli değil';end if;
  update public.court_slots set status = 'cancelled' where id = p_slot;

  -- Katılması onaylanmış oyunculara haber ver; boşuna gitmesinler.
  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id)
  select sp.profile_id, 'court_cancelled', 'Oyun iptal edildi',
         'Katıldığın oyun iptal edildi.', 'court_slot', p_slot
    from public.court_slot_players sp
   where sp.slot_id = p_slot and sp.status = 'accepted';
end; $$;

create or replace function public.court_waitlist_transition_guard() returns trigger language plpgsql security definer set search_path=public as $$begin
 if new.status='active' and old.status not in ('claimed','active') then raise exception 'Bu kutu artık geçerli değil.';end if;
 return new;end;$$;
drop trigger if exists court_waitlist_transition_guard on court_slots;
create trigger court_waitlist_transition_guard before update on court_slots for each row execute function court_waitlist_transition_guard();
revoke all on function public.court_waitlist_transition_guard() from public,anon,authenticated;
