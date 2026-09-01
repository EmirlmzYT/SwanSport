-- 0047 — Core Loop: var olan özellikler birbiriyle konuşsun
--
-- Yeni özellik eklemiyor. Ölçüldü ve şu çıktı: `notifications` tablosunda
-- 16 bildirim türü tanımlı, `push_route` bunların hepsini bir ekrana
-- eşliyor, push zinciri çalışıyor — ama **`event` ve `announcement`
-- türlerini kimse üretmiyor.** Tür var, rota var, üreten yok.
--
-- Sonucu şu: antrenör antrenman oluşturuyor, kimsenin haberi olmuyor.
-- Duyuru yayınlıyor, kimsenin haberi olmuyor. Sporcu başarı kazanıyor
-- (0046'dan beri otomatik), kendi bile bilmiyor.
--
-- Döngünün eksik ilk halkası buydu:
--
--   antrenman oluşturulur → [BİLDİRİM YOK] → RSVP → yoklama → performans
--
-- RSVP'yi kimse vermiyor çünkü antrenmanın varlığından haberi yok.

-- ---------------------------------------------------------------------------
-- Ortak yardımcı: bir etkinliğin/kulübün ilgili kişileri
--
-- "Kime haber verilecek" sorusu üç tetikleyicide de aynı biçimde soruluyor;
-- üç kez yazmak üçünün zamanla ayrışması demekti.
--
-- Veliler dahil: denetimde veli deneyiminin kopuk olduğu çıkmıştı — çocuğun
-- antrenmanından velinin haberi olmaması bunun en görünür hâli.
-- ---------------------------------------------------------------------------
create or replace function public.event_audience(p_event uuid)
returns table (profile_id uuid)
language sql
stable
security definer
set search_path = public
as $fn$
  with ev as (select * from public.events where id = p_event),
  ath as (
    select a.id, a.profile_id
      from ev, public.athletes a
     where a.club_id = ev.club_id
       and (
         -- Takıma bağlı etkinlik yalnızca o takıma; bağsızsa kulübün tamamına.
         ev.team_id is null
         or exists (select 1 from public.team_memberships tm
                     where tm.team_id = ev.team_id and tm.athlete_id = a.id)
       )
  )
  select profile_id from ath where profile_id is not null
  union
  select g.profile_id
    from public.guardians g
    join ath on ath.id = g.athlete_id
   where g.profile_id is not null;
$fn$;

-- ---------------------------------------------------------------------------
-- 1) Antrenman/maç oluşturulunca ilgililere haber
--
-- Yalnızca INSERT'te: her düzenlemede yeniden bildirim atmak, saatini iki kez
-- düzelten antrenörün takımı üç kez rahatsız etmesi demekti. Saat değişimi
-- ayrı bir bildirim türü hak ediyor; o ayrı bir iş.
--
-- Geçmiş tarihli etkinlik bildirim üretmiyor: kayıt tutmak için geriye dönük
-- girilen antrenmanlar var ve onlar için haber vermek anlamsız.
-- ---------------------------------------------------------------------------
create or replace function public.notify_new_event()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_when text;
begin
  if new.starts_at < now() then
    return new;
  end if;

  v_when := to_char(new.starts_at at time zone 'Europe/Istanbul',
                    'DD.MM HH24:MI');

  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  select a.profile_id,
         'event',
         case new.kind
           when 'match' then 'Yeni maç: ' || new.title
           else 'Yeni antrenman: ' || new.title
         end,
         v_when || coalesce(' · ' || new.place, ''),
         null,
         'event',
         new.id
    from public.event_audience(new.id) a
   -- Kendi oluşturduğun etkinlik için sana bildirim gitmesin.
   where a.profile_id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid);

  return new;
end;
$fn$;

drop trigger if exists trg_notify_new_event on public.events;
create trigger trg_notify_new_event
  after insert on public.events
  for each row execute function public.notify_new_event();

-- ---------------------------------------------------------------------------
-- 2) Duyuru yayınlanınca kulübe haber
--
-- `announcement` türü ve `/announcements` rotası 0026'dan beri tanımlı;
-- eksik olan yalnızca üreten taraftı.
-- ---------------------------------------------------------------------------
create or replace function public.notify_new_announcement()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  select m.profile_id,
         'announcement',
         new.title,
         left(coalesce(new.body, ''), 140),
         new.author_id,
         'announcement',
         new.id
    from public.club_memberships m
   where m.club_id = new.club_id
     and m.status = 'active'
     and m.profile_id <> coalesce(new.author_id,
           '00000000-0000-0000-0000-000000000000'::uuid);

  return new;
end;
$fn$;

drop trigger if exists trg_notify_new_announcement on public.announcements;
create trigger trg_notify_new_announcement
  after insert on public.announcements
  for each row execute function public.notify_new_announcement();

-- ---------------------------------------------------------------------------
-- 3) Kazanılan başarı sporcuya (ve velisine) bildirilsin
--
-- 0046 başarıları otomatik üretmeye başladı ama sessizce: sporcu profiline
-- girip bakmadıkça hedefini tutturduğunu öğrenemiyordu. Gelişim döngüsünün
-- kullanıcıya dönen tek anı bu — sessiz kalması onu görünmez yapıyordu.
--
-- Yalnızca **otomatik** başarılarda (`source is not null`). Antrenörün elle
-- girdiği derece zaten konuşularak biliniyor; onu bildirmek gereksiz.
-- ---------------------------------------------------------------------------
create or replace function public.notify_new_achievement()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if new.source is null then
    return new;
  end if;

  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id)
  select p.profile_id,
         'achievement',
         'Yeni başarı: ' || new.title,
         coalesce(new.note, ''),
         'achievement',
         new.id
    from (
      select a.profile_id from public.athletes a where a.id = new.athlete_id
      union
      select g.profile_id from public.guardians g
       where g.athlete_id = new.athlete_id
    ) p
   where p.profile_id is not null;

  return new;
end;
$fn$;

drop trigger if exists trg_notify_new_achievement on public.athlete_achievements;
create trigger trg_notify_new_achievement
  after insert on public.athlete_achievements
  for each row execute function public.notify_new_achievement();

-- ---------------------------------------------------------------------------
-- 4) Yeni türün rotası
--
-- `push_route` bildirime dokununca hangi ekranın açılacağını söylüyor.
--
-- DİKKAT — bu fonksiyon her yeniden yazıldığında eşleme kaybediliyor.
-- Ölçüldü: 0022 `payment → /finans`, `attendance_reminder → /attendance` ve
-- `donation → /bagis` eşlemelerini eklemişti; 0039 fonksiyonu baştan yazarken
-- bu üçünü **düşürmüş**. Yani bugün canlıda ödeme bildirimine dokunan
-- kullanıcı finansa değil bildirim listesine gidiyor ve bu kimseye hata
-- gibi görünmüyor — sadece yanlış yere götürüyor.
--
-- Bu sürüm geçmişteki bütün eşlemeleri geri getiriyor. Bir dahaki sefere
-- yeniden yazan: önce `grep -rn "when '" supabase/migrations/*push*.sql`
-- ile eskileri topla.
-- ---------------------------------------------------------------------------
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
    else '/bildirimler'
  end;
$fn$;

revoke execute on function public.event_audience(uuid) from public, anon;
grant execute on function public.event_audience(uuid) to authenticated;
