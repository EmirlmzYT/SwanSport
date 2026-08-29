-- ---------------------------------------------------------------------------
-- 0037 — Kort partneri arama
--
-- Kort sistemi tek başına şu soruyu çözmüyor: partnerin yoksa ne olacak?
-- `open_slots` bunun bir alt kümesini çözüyor ama önce saat almış olmayı
-- şart koşuyor. Burası saat almadan "şimdi/yakında oynamak istiyorum"
-- diyebilmeyi, sistemin ilgili yakın kişilere haber vermesini çözüyor.
-- Kabul eden biri olursa var olan sohbet akışına (direct_messages) geçiliyor
-- — yeni bir mesajlaşma sistemi yazılmadı.
--
-- "Yakınında" ŞEHİR bazlı: kime bildirim gideceğine karar vermek için tüm
-- adayların canlı GPS konumunu bilmemiz gerekirdi, bu da arka planda sürekli
-- konum izlemek demek — courts sisteminde bilerek kaçınılan şey. İsteyen
-- kişinin kendi anlık konumu yine yalnızca o an alınıyor (place.dart).
--
-- Güven mekanizması courts ile PAYLAŞILIYOR, tekrar yazılmadı:
-- verification_tier ve court_players.banned_until aynen kullanılıyor. Somut
-- sonucu: yeni bir kullanıcı önce bir kortu fiziksel ziyaret etmeden partner
-- arayamaz — doğrulama oradan geliyor.
-- ---------------------------------------------------------------------------

-- ======================= 1. İlgi alanları ===================================

create table if not exists public.sport_interests (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  sport_code text not null references public.sports(code),
  created_at timestamptz not null default now(),
  primary key (profile_id, sport_code)
);

alter table public.sport_interests enable row level security;

-- Kendi ilgi alanını kendisi yönetir — RPC gerekmiyor, doğrudan tablo.
drop policy if exists "sport_interest_own" on public.sport_interests;
create policy "sport_interest_own" on public.sport_interests for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ==================== 2. İstekler ve bildirim kayıtları =====================

create table if not exists public.partner_requests (
  id           uuid primary key default gen_random_uuid(),
  requester_id uuid not null references public.profiles(id) on delete cascade,
  sport_code   text not null references public.sports(code),
  city_code    text references public.cities(code),
  lat          numeric(9,6),
  lng          numeric(9,6),
  status       text not null default 'open',
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null default now() + interval '2 hours',

  constraint partner_request_status_valid
    check (status in ('open', 'matched', 'expired', 'cancelled'))
);

create index if not exists idx_partner_request_open
  on public.partner_requests (requester_id, status);

create table if not exists public.partner_request_pings (
  request_id uuid not null references public.partner_requests(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  status     text not null default 'pending',
  created_at timestamptz not null default now(),

  primary key (request_id, profile_id),
  constraint partner_ping_status_valid
    check (status in ('pending', 'accepted', 'declined', 'expired'))
);

create index if not exists idx_partner_ping_inbox
  on public.partner_request_pings (profile_id, status);

alter table public.partner_requests enable row level security;
alter table public.partner_request_pings enable row level security;

-- Bilerek hiç SELECT policy'si yok: partner isteği kimin kiminle oynamak
-- istediği gibi kişisel bir sinyal taşıyor, courts'un aksine "herkese açık"
-- değil. Tüm okuma iki RPC'den geçiyor (my_incoming_partner_pings,
-- my_open_partner_request) — security definer olduğu için RLS'i atlıyorlar.
-- Yazma da tamamen RPC'lerden: aşağıda hiçbir insert/update policy'si yok.

-- ============================ 3. RPC'ler ====================================

-- Eşleştirmenin bakacağı branşlar: yalnızca aktif kortu olanlar. Konsoldaki
-- kort formu artık branş istiyor (courts_screen.dart); branşsız kort burada
-- hiç görünmez.
create or replace function public.court_sport_codes()
returns table (code text, name text)
language sql stable security definer set search_path = public as $$
  select distinct s.code, s.name
    from public.courts c
    join public.sports s on s.code = c.sport_code
   where c.active
   order by 2;
$$;

-- İstek aç, aday havuzunu bul, toplu bildirim at.
create or replace function public.seek_partner(
  p_sport text,
  p_lat   numeric default null,
  p_lng   numeric default null)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_tier   text;
  v_city   text;
  v_banned timestamptz;
  v_id     uuid;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  select verification_tier, city_code into v_tier, v_city
    from public.profiles where id = auth.uid();

  if public.verification_rank(v_tier) < public.verification_rank('location') then
    raise exception 'Partner aramak için bir kez kortta olduğunu doğrulamalısın';
  end if;

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

  insert into public.partner_requests (requester_id, sport_code, city_code, lat, lng)
  values (auth.uid(), p_sport, v_city, p_lat, p_lng)
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
       and public.verification_rank(p.verification_tier)
           >= public.verification_rank('location')
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

-- Kabul/ret. Kabul, tek kişilik eşleşme olduğu için atomik: iki kişi
-- neredeyse aynı anda kabul ederse Postgres'in satır kilidi ikinciyi
-- bekletir, birinci commit olunca ikincinin WHERE'i artık tutmaz — yarışı
-- veritabanı çözer, claim_slot'taki unique kısıtıyla aynı ilke.
create or replace function public.respond_partner_ping(
  p_request uuid, p_accept boolean)
returns void
language plpgsql security definer set search_path = public as $$
declare v_req record; v_matched int;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

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

-- İptal — courts'taki gibi cezasız.
create or replace function public.cancel_partner_request(p_id uuid)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  update public.partner_requests
     set status = 'cancelled'
   where id = p_id and requester_id = auth.uid() and status = 'open';

  update public.partner_request_pings
     set status = 'expired'
   where request_id = p_id and status = 'pending';
end; $$;

-- Bana gelen, henüz yanıtlamadığım istekler.
create or replace function public.my_incoming_partner_pings()
returns table (
  request_id      uuid,
  sport_code      text,
  sport_name      text,
  requester_id    uuid,
  requester_name  text,
  created_at      timestamptz
)
language sql stable security definer set search_path = public as $$
  select pp.request_id, pr.sport_code, s.name, pr.requester_id, p.full_name, pp.created_at
    from public.partner_request_pings pp
    join public.partner_requests pr on pr.id = pp.request_id
    join public.sports s on s.code = pr.sport_code
    join public.profiles p on p.id = pr.requester_id
   where pp.profile_id = auth.uid()
     and pp.status = 'pending'
     and pr.status = 'open'
   order by pp.created_at desc;
$$;

-- Benim açık ya da az önce eşleşmiş isteğim (tek aktif istek kuralı
-- gereği en fazla bir tane).
create or replace function public.my_open_partner_request()
returns table (
  id               uuid,
  sport_code       text,
  sport_name       text,
  status           text,
  created_at       timestamptz,
  expires_at       timestamptz,
  accepted_by      uuid,
  accepted_by_name text
)
language sql stable security definer set search_path = public as $$
  select pr.id, pr.sport_code, s.name, pr.status, pr.created_at, pr.expires_at,
         acc.profile_id, accp.full_name
    from public.partner_requests pr
    join public.sports s on s.code = pr.sport_code
    left join public.partner_request_pings acc
      on acc.request_id = pr.id and acc.status = 'accepted'
    left join public.profiles accp on accp.id = acc.profile_id
   where pr.requester_id = auth.uid()
     and pr.status in ('open', 'matched')
   order by pr.created_at desc
   limit 1;
$$;

-- ======================= 4. Zamanlanmış bakım ===============================

-- Ayrı fonksiyon — court_slot_maintenance'a eklemek yerine: tek fonksiyon
-- tek işten sorumlu kalsın.
create or replace function public.partner_request_maintenance()
returns int
language plpgsql security definer set search_path = public as $$
declare v_expired int := 0;
begin
  with dropped as (
    update public.partner_requests
       set status = 'expired'
     where status = 'open' and expires_at < now()
    returning id
  )
  update public.partner_request_pings pp
     set status = 'expired'
    from dropped d
   where pp.request_id = d.id and pp.status = 'pending';

  get diagnostics v_expired = row_count;
  return v_expired;
end; $$;

select cron.unschedule('swansport_partner_maintenance')
 where exists (select 1 from cron.job where jobname = 'swansport_partner_maintenance');

select cron.schedule('swansport_partner_maintenance', '*/5 * * * *',
  $cron$select public.partner_request_maintenance();$cron$);

-- ============================ 5. push_route =================================

create or replace function public.push_route(p_kind text, p_entity text)
returns text language sql immutable as $$
  select case p_kind
    when 'message'                   then '/mesajlar'
    when 'application'               then '/basvurular'
    when 'offer'                     then '/bildirimler'
    when 'follow'                    then '/bildirimler'
    when 'partner_request'           then '/partner-ara'
    when 'partner_request_accepted'  then '/partner-ara'
    else '/bildirimler'
  end;
$$;

-- ============================ 6. İzinler ====================================

revoke execute on function public.seek_partner(text, numeric, numeric) from public, anon;
revoke execute on function public.respond_partner_ping(uuid, boolean) from public, anon;
revoke execute on function public.cancel_partner_request(uuid) from public, anon;
revoke execute on function public.my_incoming_partner_pings() from public, anon;
revoke execute on function public.my_open_partner_request() from public, anon;
revoke execute on function public.partner_request_maintenance() from public, anon, authenticated;

-- court_sport_codes bilerek açık bırakıldı — courts okuması gibi herkese
-- açık bilgi (hangi branşlarda kort var), giriş yapmamış biri de görebilir.
