-- ---------------------------------------------------------------------------
-- 0040 — Mesaj bildirimi + halı saha isteğinin gerçek sohbete dönmesi
--
-- İKİ SORUN:
--
-- 1) **Doğrudan mesajlar hiç bildirim üretmiyordu.** `NotificationService.send`
--    yalnızca `direct_messages`'a satır atıyor; `notifications` tablosuna
--    hiçbir şey yazılmıyor, dolayısıyla push da gitmiyordu. Yani birine mesaj
--    attığında karşı taraf ancak uygulamayı kendi açıp bakarsa görüyordu.
--    Tek istisna `send_club_message` (0027) — o bildirimi elle yazıyordu.
--
-- 2) **Halı saha "bu saati istiyorum" akışı yarım kalıyordu.** (0039) Yöneticiye
--    bildirim gidiyordu ama iki taraf birbiriyle konuşamıyordu; anlaşmanın
--    uygulama içinde bir yeri yoktu, "telefonla ara" demekten ibaretti.
--
-- ÇÖZÜM: mesaj bildirimini tetikleyiciye taşı (tek yer), ve halı saha isteğini
-- özel bir bildirim yerine **gerçek bir mesaj** olarak gönder. Böylece iki
-- taraf da var olan sohbet ekranından normalce konuşuyor — yeni bir sohbet
-- arayüzü yazılmadı.
-- ---------------------------------------------------------------------------

-- ============== 1. Mesaj bildirimi — tek kaynak: tetikleyici ================

create or replace function public.notify_direct_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_title text;
begin
  -- Kulüp adına gönderilen mesajda kulübün adı görünür (0027'deki davranış
  -- korunuyor), yoksa kişinin adı.
  if new.sender_club_id is not null then
    select name || ' size yazdı' into v_title
      from public.clubs where id = new.sender_club_id;
  end if;

  if v_title is null then
    select coalesce(nullif(trim(full_name), ''), 'Biri') || ' size yazdı'
      into v_title
      from public.profiles where id = new.sender_id;
  end if;

  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  values (new.recipient_id, 'message', coalesce(v_title, 'Yeni mesaj'),
          left(trim(new.body), 120), new.sender_id, 'message', new.id);

  return new;
end; $$;

drop trigger if exists trg_notify_direct_message on public.direct_messages;
create trigger trg_notify_direct_message
  after insert on public.direct_messages
  for each row execute function public.notify_direct_message();

-- `send_club_message` artık bildirimi kendisi yazmıyor — tetikleyici yazıyor.
-- İkisi birden kalsaydı kulüp mesajlarında çift bildirim olurdu.
create or replace function public.send_club_message(
  p_club uuid, p_recipient uuid, p_body text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Bu kulüp adına mesaj gönderemezsin';
  end if;
  if p_body is null or trim(p_body) = '' then
    raise exception 'Boş mesaj';
  end if;

  insert into public.direct_messages (sender_id, recipient_id, body, sender_club_id)
  values (auth.uid(), p_recipient, trim(p_body), p_club)
  returning id into v_id;

  return v_id;
end; $$;

-- ============ 2. Halı saha isteği artık gerçek bir sohbet açıyor ============

-- Özel `turf_slot_request` bildirimi yerine, oyuncunun ağzından yöneticiye
-- gerçek bir mesaj gidiyor. Bildirimi yukarıdaki tetikleyici üretiyor, rota
-- da zaten `/mesajlar` — yönetici dokunup doğrudan sohbete giriyor ve
-- cevap yazabiliyor. Oyuncu da aynı sohbeti kendi gelen kutusunda görüyor.
create or replace function public.request_turf_slot(p_field uuid, p_starts_at timestamptz)
returns void
language plpgsql security definer set search_path = public as $$
declare
  v_field   record;
  v_new     boolean;
  v_body    text;
  v_managers int;
begin
  if auth.uid() is null then raise exception 'Giriş yapılmamış'; end if;

  select * into v_field from public.turf_fields where id = p_field and active;
  if v_field is null then raise exception 'Saha bulunamadı'; end if;

  select count(*) into v_managers
    from public.turf_field_managers
   where field_id = p_field and status = 'active';

  -- Yöneticisi atanmamış sahada mesaj gidecek kimse yok; sessizce "gönderdim"
  -- demek kullanıcıyı yanıltırdı.
  if v_managers = 0 then
    raise exception 'Bu sahanın uygulamada yöneticisi yok — telefonla aramalısın';
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
   where m.field_id = p_field and m.status = 'active';
end; $$;

revoke execute on function public.request_turf_slot(uuid, timestamptz) from public, anon;
