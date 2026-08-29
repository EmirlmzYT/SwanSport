-- ---------------------------------------------------------------------------
-- 0036 — claim_slot / extend_slot çakışmayı kendi kendine karıştırıyordu
--
-- Ağ gecikmesiyle "Al" iki kez tetiklenirse (çift dokunuş, yavaş bağlantıda
-- kullanıcının "olmadı" sanıp tekrar basması) iki claim_slot çağrısı neredeyse
-- aynı anda çalışıyor. İkisi de "zaten aktif kutum var mı" kontrolünü kutu
-- henüz yazılmamışken geçiyor, ikisi de insert deniyor, unique kısıtı ikinciyi
-- reddediyor — ve reddedilen çağrı her zaman "O saati az önce başkası aldı"
-- diyordu. Gerçekte "başkası" kendisiydi; sıra onundu ama ekranda öyle
-- görünmedi.
--
-- Düzeltme: unique_violation yakalandığında çakışan satırın sahibine bakılır.
-- Sahibi çağıran kişiyse hata değil, var olan kutu döner (idempotent).
-- Gerçekten başka biri almışsa mesaj aynen kalır.
-- ---------------------------------------------------------------------------

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
     where court_id = p_court and starts_at = p_starts_at;

    if v_id is null or (select owner_id from public.court_slots where id = v_id) <> auth.uid() then
      raise exception 'O saati az önce başkası aldı';
    end if;
    -- Kendi çift dokunuşumuz: hata değil, zaten aldığın kutu dönüyor.
  end;

  insert into public.court_players (profile_id) values (auth.uid())
    on conflict (profile_id) do nothing;

  return v_id;
end; $$;

-- extend_slot'ta da aynı çift dokunuş riski var: "Devam et" iki kez basılırsa
-- ikinci çağrı aynı şekilde kendi başarılı uzatmasını "başkası aldı" sanabilir.
create or replace function public.extend_slot(p_slot uuid)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_slot record; v_court record; v_next timestamptz; v_id uuid; v_local time;
begin
  select * into v_slot from public.court_slots where id = p_slot;
  if v_slot is null then raise exception 'Kutu bulunamadı'; end if;
  if v_slot.owner_id <> auth.uid() then raise exception 'Yetkisiz'; end if;

  v_next := v_slot.starts_at + interval '1 hour';

  -- İkinci çağrı geldiğinde ilk çağrı zaten kutuyu 'done' yapmış olabilir;
  -- bu durumda "önce doğrula" hatası yerine mevcut uzatılmış kutuyu dön.
  if v_slot.status = 'done' then
    select id into v_id from public.court_slots
     where court_id = v_slot.court_id and starts_at = v_next
       and owner_id = auth.uid();
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
     where court_id = v_slot.court_id and starts_at = v_next;

    if v_id is null or (select owner_id from public.court_slots where id = v_id) <> auth.uid() then
      raise exception 'Sonraki saati başkası aldı';
    end if;
    -- Kendi çift dokunuşumuz: hata değil, zaten uzattığın kutu dönüyor.
  end;

  update public.court_slots set status = 'done' where id = p_slot;
  return v_id;
end; $$;

revoke execute on function public.claim_slot(uuid, timestamptz, int, int) from public, anon;
revoke execute on function public.extend_slot(uuid) from public, anon;
