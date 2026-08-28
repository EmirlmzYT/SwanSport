-- =============================================================================
-- SwanSport — TEKRARLAYAN ANTRENMAN + HATIRLATMALAR
--   1) Haftalık tekrarlayan etkinlik serisi
--   2) Aidat son ödeme hatırlatması (veliye/sporcuya)
--   3) Yoklama hatırlatması (antrenöre)
--
-- Hatırlatmalar `notifications` tablosuna yazar; oradaki push tetikleyicisi
-- sayesinde telefona da düşer — ayrıca bir şey bağlamak gerekmez.
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) TEKRARLAYAN ETKİNLİK
--
-- Kulüp haftada üç gün çalışıyorsa ayda 12 kaydı elle girmek gerekiyordu.
-- Seri halinde üretilir; `series_id` ile birlikte silinebilirler.
-- ---------------------------------------------------------------------------
alter table public.events
  add column if not exists series_id uuid;

create index if not exists idx_events_series on public.events (series_id);


-- p_weekdays: ISO gün numaraları — 1 Pazartesi … 7 Pazar.
create or replace function public.create_event_series(
  p_club     uuid,
  p_title    text,
  p_kind     text,
  p_from     date,
  p_until    date,
  p_hour     int,
  p_minute   int,
  p_minutes  int default 90,
  p_weekdays int[] default array[1,3,5],
  p_facility uuid default null,
  p_place    text default null,
  p_team     uuid default null)
returns int
language plpgsql security definer set search_path = public as $$
declare
  v_series uuid := gen_random_uuid();
  v_count  int  := 0;
  v_day    date;
  v_start  timestamptz;
  v_place  text;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Yetkisiz';
  end if;

  if p_until < p_from then
    raise exception 'Bitiş tarihi başlangıçtan önce olamaz';
  end if;

  -- Aşırı uzun seri kazara oluşmasın (yaklaşık iki yıl).
  if p_until - p_from > 800 then
    raise exception 'Seri en fazla ~2 yıl olabilir';
  end if;

  -- Tesis seçilmişse yer adı ondan gelir.
  v_place := coalesce(nullif(p_place, ''),
                      (select f.name from public.facilities f
                        where f.id = p_facility));

  v_day := p_from;
  while v_day <= p_until loop
    if extract(isodow from v_day)::int = any(p_weekdays) then
      -- Veritabanı UTC çalışır; "17:30" diyen kişi Türkiye saatini kastediyor.
      v_start := (v_day + make_time(
                    least(greatest(p_hour, 0), 23),
                    least(greatest(p_minute, 0), 59), 0))
                 at time zone 'Europe/Istanbul';

      insert into public.events
        (club_id, team_id, title, place, kind, starts_at, ends_at,
         facility_id, series_id)
      values (p_club, p_team, p_title, v_place, p_kind::public.event_kind,
              v_start, v_start + (p_minutes || ' minutes')::interval,
              p_facility, v_series);

      v_count := v_count + 1;
    end if;
    v_day := v_day + 1;
  end loop;

  return v_count;
end; $$;


-- Serinin gelecekteki kayıtlarını siler; geçmiş kalır (yoklaması olabilir).
create or replace function public.delete_event_series(
  p_series uuid, p_only_future boolean default true)
returns int
language plpgsql security definer set search_path = public as $$
declare v_n int;
begin
  delete from public.events e
   where e.series_id = p_series
     and public.is_club_staff(e.club_id)
     and (not p_only_future or e.starts_at > now());
  get diagnostics v_n = row_count;
  return v_n;
end; $$;


-- ---------------------------------------------------------------------------
-- 2) HATIRLATMA KAYDI
--
-- Aynı hatırlatmanın her çalıştırmada tekrar gönderilmesini engeller.
-- ---------------------------------------------------------------------------
create table if not exists public.reminder_log (
  kind       text not null,        -- fee | attendance
  entity_id  uuid not null,        -- fatura ya da etkinlik
  profile_id uuid not null references public.profiles(id) on delete cascade,
  sent_on    date not null default current_date,
  primary key (kind, entity_id, profile_id, sent_on)
);

alter table public.reminder_log enable row level security;
-- Okuma/yazma yalnızca zamanlanmış işlerde (security definer) yapılır.


-- ---------------------------------------------------------------------------
-- 3) AİDAT HATIRLATMASI
--
-- Son ödeme gününe 3 gün kala, son ödeme günü ve gecikmenin 3. gününde
-- hatırlatır. Ödenmiş ya da ödeme bildirimi yapılmış faturaya dokunmaz —
-- parayı yatırmış veliye "borcun var" demek en sinir bozucu şeydir.
-- ---------------------------------------------------------------------------
create or replace function public.send_fee_reminders()
returns int
language plpgsql security definer set search_path = public as $$
declare v_n int := 0;
begin
  with due as (
    select i.id, i.athlete_id, i.label, i.amount, i.due_date, i.club_id,
           case
             when i.due_date = current_date + 3 then 'yaklaşıyor'
             when i.due_date = current_date     then 'bugün son gün'
             else 'gecikti'
           end as phase
      from public.invoices i
     where i.status <> 'paid'
       and i.due_date in (current_date + 3, current_date, current_date - 3)
       -- Ödeme bildirimi yapılmışsa hatırlatma gönderme.
       and not exists (select 1 from public.payments p
                        where p.invoice_id = i.id and p.status = 'pending')
  ),
  targets as (
    -- Sporcunun kendisi
    select d.id as invoice_id, a.profile_id, d.label, d.amount, d.phase,
           d.due_date, c.name as club_name
      from due d
      join public.athletes a on a.id = d.athlete_id
      join public.clubs c on c.id = d.club_id
     where a.profile_id is not null
    union
    -- Velileri
    select d.id, g.profile_id, d.label, d.amount, d.phase, d.due_date, c.name
      from due d
      join public.guardians g on g.athlete_id = d.athlete_id
      join public.clubs c on c.id = d.club_id
     where g.profile_id is not null
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'fee', t.invoice_id, t.profile_id from targets t
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'fee_reminder',
           case t.phase
             when 'yaklaşıyor'   then 'Aidat son ödeme yaklaşıyor'
             when 'bugün son gün' then 'Aidat son ödeme bugün'
             else 'Aidat ödemesi gecikti'
           end,
           t.club_name || ' · ' || t.label || ' · ' ||
             trim(to_char(t.amount, 'FM999G999G999')) || ' TL',
           'invoice', f.entity_id
      from fresh f
      join targets t
        on t.invoice_id = f.entity_id and t.profile_id = f.profile_id
    returning 1
  )
  select count(*) into v_n from sent;

  return v_n;
end; $$;


-- ---------------------------------------------------------------------------
-- 4) YOKLAMA HATIRLATMASI
--
-- Önümüzdeki 2 saat içinde başlayan antrenmanlar için kulüp görevlilerine
-- haber verir. Yoklaması zaten alınmış etkinlik atlanır.
-- ---------------------------------------------------------------------------
create or replace function public.send_attendance_reminders()
returns int
language plpgsql security definer set search_path = public as $$
declare v_n int := 0;
begin
  with soon as (
    select e.id, e.club_id, e.title, e.starts_at, e.place
      from public.events e
     where e.kind = 'training'
       and e.starts_at between now() and now() + interval '2 hours'
       and not exists (select 1 from public.attendance a
                        where a.event_id = e.id)
  ),
  targets as (
    select s.id as event_id, m.profile_id, s.title, s.starts_at, s.place,
           c.name as club_name
      from soon s
      join public.club_memberships m
        on m.club_id = s.club_id and m.status = 'active'
       and m.role in ('coach', 'club_admin')
      join public.clubs c on c.id = s.club_id
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'attendance', t.event_id, t.profile_id from targets t
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'attendance_reminder',
           'Yoklama zamanı yaklaşıyor',
           t.title || ' · ' ||
             to_char(t.starts_at at time zone 'Europe/Istanbul', 'HH24:MI') ||
             coalesce(' · ' || t.place, ''),
           'event', f.entity_id
      from fresh f
      join targets t
        on t.event_id = f.entity_id and t.profile_id = f.profile_id
    returning 1
  )
  select count(*) into v_n from sent;

  return v_n;
end; $$;


-- ---------------------------------------------------------------------------
-- 5) BİLDİRİM YÖNLENDİRMESİ
--
-- Telefondaki bildirime dokununca doğru sayfa açılsın.
-- ---------------------------------------------------------------------------
create or replace function public.push_route(p_kind text, p_entity text)
returns text language sql immutable as $$
  select case p_kind
    when 'message'             then '/mesajlar'
    when 'application'         then '/basvurular'
    when 'fee_reminder'        then '/aidatlarim'
    when 'payment'             then '/finans'
    when 'attendance_reminder' then '/attendance'
    when 'donation'            then '/bagis'
    else '/bildirimler'
  end;
$$;


-- ---------------------------------------------------------------------------
-- 6) ZAMANLAMA
--
-- pg_cron Supabase'de mevcuttur. Zaman UTC'dir: Türkiye saati = UTC + 3.
--   • Aidat  : her gün 09:00 TR  → 06:00 UTC
--   • Yoklama: her saat başı
-- ---------------------------------------------------------------------------
create extension if not exists pg_cron;

do $$
begin
  -- Aynı isimli iş varsa önce kaldırılır (tekrar çalıştırılabilirlik).
  perform cron.unschedule('swansport_fee_reminders');
exception when others then null;
end $$;

do $$
begin
  perform cron.unschedule('swansport_attendance_reminders');
exception when others then null;
end $$;

select cron.schedule(
  'swansport_fee_reminders', '0 6 * * *',
  $$select public.send_fee_reminders();$$);

select cron.schedule(
  'swansport_attendance_reminders', '0 * * * *',
  $$select public.send_attendance_reminders();$$);


-- Zamanlamayı beklemeden elle denemek için:
--   select public.send_fee_reminders();
--   select public.send_attendance_reminders();
