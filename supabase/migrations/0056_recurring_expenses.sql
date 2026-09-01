-- ---------------------------------------------------------------------------
-- 0056 — Tekrarlayan giderler ve taahhütler
--
-- Kira, tesis, bakım, lisans, sigorta, internet, yazılım. Kulübün bildiği
-- ama sistemin bilmediği düzenli giderler; nakit tahmininin de temeli.
--
-- İKİ TABLO, BİR SEBEP: `recurring_expenses` taahhüdün kendisi,
-- `recurring_occurrences` her bir vadesi. Vade satırı, gider kaydından
-- **önce** var olmalı — yoksa "vadesine 7 gün kaldı" uyarısı için ortada
-- hiçbir şey olmaz ve uyarmak adına sahte gider yazmak gerekirdi.
-- ---------------------------------------------------------------------------

create table if not exists public.recurring_expenses (
  id             uuid primary key default gen_random_uuid(),
  club_id        uuid not null references public.clubs(id) on delete cascade,
  title          text not null,
  vendor_id      uuid references public.vendors(id) on delete set null,
  category_id    uuid references public.expense_categories(id) on delete set null,
  account_id     uuid references public.cash_accounts(id) on delete set null,
  amount         numeric(12,2) not null,
  currency       text not null default 'TRY',
  frequency      text not null default 'monthly',
  -- `custom` için ay adımı. monthly=1, quarterly=3, yearly=12 zaten sabit.
  interval_months int,
  -- İlk vade. Sonraki vadeler bundan türüyor; ayrı bir "ayın kaçı" alanı
  -- YOK: iki yerde gün tutmak, ikisinin ayrışması demek.
  starts_on      date not null,
  ends_on        date,
  owner_id       uuid references public.profiles(id) on delete set null,
  needs_approval boolean not null default false,
  team_id        uuid references public.teams(id) on delete set null,
  facility_id    uuid references public.facilities(id) on delete set null,
  event_id       uuid references public.events(id) on delete set null,
  note           text,
  active         boolean not null default true,
  created_by     uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now()
);

do $blk$ begin
  alter table public.recurring_expenses
    add constraint recurring_frequency_check
    check (frequency in ('monthly', 'quarterly', 'yearly', 'custom'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.recurring_expenses
    add constraint recurring_amount_check check (amount > 0);
exception when duplicate_object then null; end $blk$;

-- `custom` seçilip adım verilmezse vade üretimi sessizce durur. Şema
-- düzeyinde kesiyoruz.
do $blk$ begin
  alter table public.recurring_expenses
    add constraint recurring_custom_needs_interval
    check (frequency <> 'custom' or coalesce(interval_months, 0) > 0);
exception when duplicate_object then null; end $blk$;

create index if not exists idx_recurring_club
  on public.recurring_expenses (club_id, active);

alter table public.recurring_expenses enable row level security;

drop policy if exists "recurring_read" on public.recurring_expenses;
create policy "recurring_read" on public.recurring_expenses for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

drop policy if exists "recurring_write" on public.recurring_expenses;
create policy "recurring_write" on public.recurring_expenses for all
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id))
  with check (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- ---------------------------------------------------------------------------
-- VADELER
--
-- `unique (recurring_id, due_on)` bu tasarımın kilit taşı: aynı taahhüt aynı
-- dönem için iki kez gider üretemiyor ve bunu uygulama değil veritabanı
-- garanti ediyor. Zamanlanmış iş iki kez çalışsa da sonuç aynı.
-- ---------------------------------------------------------------------------
create table if not exists public.recurring_occurrences (
  id           uuid primary key default gen_random_uuid(),
  recurring_id uuid not null references public.recurring_expenses(id) on delete cascade,
  club_id      uuid not null references public.clubs(id) on delete cascade,
  due_on       date not null,
  amount       numeric(12,2) not null,
  expense_id   uuid references public.expenses(id) on delete set null,
  status       text not null default 'pending',
  created_at   timestamptz not null default now(),
  constraint recurring_occurrence_unique unique (recurring_id, due_on)
);

do $blk$ begin
  alter table public.recurring_occurrences
    add constraint recurring_occurrence_status_check
    check (status in ('pending', 'recorded', 'skipped'));
exception when duplicate_object then null; end $blk$;

create index if not exists idx_recurring_occ_club_due
  on public.recurring_occurrences (club_id, status, due_on);

alter table public.recurring_occurrences enable row level security;

drop policy if exists "recurring_occ_read" on public.recurring_occurrences;
create policy "recurring_occ_read" on public.recurring_occurrences for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

drop policy if exists "recurring_occ_write" on public.recurring_occurrences;
create policy "recurring_occ_write" on public.recurring_occurrences for all
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id))
  with check (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- Gider hangi taahhütten doğdu.
alter table public.expenses
  add column if not exists recurring_id uuid references public.recurring_expenses(id) on delete set null;

-- ---------------------------------------------------------------------------
-- VADE ÜRETİMİ
--
-- Vadeler `starts_on`'dan türüyor; Postgres ay eklemede ay sonunu kendisi
-- kırpıyor (31 Ocak + 1 ay = 28 Şubat), bu yüzden elle gün hesabı yok.
--
-- Pencere bilerek dar: geçmişe 90 gün, geleceğe 60 gün. Beş yıl önce
-- başlamış aylık bir taahhüt için altmış vade geriye dönük üretmek, iş
-- kuyruğunu ilk çalıştırmada anlamsız biçimde dolduruyordu.
-- ---------------------------------------------------------------------------
create or replace function public.generate_recurring_occurrences()
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_n int := 0;
begin
  with step as (
    select r.id, r.club_id, r.amount, r.starts_on, r.ends_on,
           (case r.frequency
              when 'monthly'   then 1
              when 'quarterly' then 3
              when 'yearly'    then 12
              else greatest(coalesce(r.interval_months, 1), 1)
            end) as months
      from public.recurring_expenses r
     where r.active
       and r.starts_on <= current_date + 60
       and (r.ends_on is null or r.ends_on >= current_date - 90)
  ),
  dates as (
    select s.id, s.club_id, s.amount, d::date as due_on
      from step s,
           lateral generate_series(
             s.starts_on::timestamp,
             least(coalesce(s.ends_on, current_date + 60),
                   current_date + 60)::timestamp,
             (s.months || ' months')::interval) as d
     where d::date >= current_date - 90
  ),
  ins as (
    insert into public.recurring_occurrences
      (recurring_id, club_id, due_on, amount)
    select dt.id, dt.club_id, dt.due_on, dt.amount from dates dt
    on conflict (recurring_id, due_on) do nothing
    returning 1
  )
  select count(*) into v_n from ins;

  return v_n;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- VADEYİ GİDERE ÇEVİR
--
-- Otomatik gider yazılmıyor — vade geldi diye para çıktığını varsaymak
-- defteri gerçekle ayırırdı. Kullanıcı "ödendi" dediğinde gider oluşuyor.
-- ---------------------------------------------------------------------------
create or replace function public.record_recurring_occurrence(
  p_occurrence uuid,
  p_amount     numeric default null,
  p_account    uuid default null,
  p_spent_on   date default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_occ  public.recurring_occurrences%rowtype;
  v_rec  public.recurring_expenses%rowtype;
  v_id   uuid;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_occ from public.recurring_occurrences where id = p_occurrence;
  if v_occ.id is null then
    raise exception 'Vade kaydı bulunamadı';
  end if;

  if not (public.is_club_staff(v_occ.club_id)
          or public.is_club_accountant(v_occ.club_id)) then
    raise exception 'Bu kulüpte gider kaydetme yetkiniz yok';
  end if;

  -- Idempotent: ikinci çağrı var olan gideri döndürüyor, yenisini yazmıyor.
  if v_occ.expense_id is not null then
    return v_occ.expense_id;
  end if;

  select * into v_rec from public.recurring_expenses where id = v_occ.recurring_id;

  insert into public.expenses
    (club_id, category_id, account_id, vendor_id, amount, spent_on, note,
     status, entered_by, recurring_id, team_id, facility_id, event_id)
  values (v_occ.club_id, v_rec.category_id,
          coalesce(p_account, v_rec.account_id), v_rec.vendor_id,
          coalesce(p_amount, v_occ.amount),
          coalesce(p_spent_on, v_occ.due_on),
          v_rec.title,
          'complete', auth.uid(), v_rec.id,
          v_rec.team_id, v_rec.facility_id, v_rec.event_id)
  returning id into v_id;

  update public.recurring_occurrences
     set expense_id = v_id, status = 'recorded'
   where id = p_occurrence;

  return v_id;
end;
$fn$;

revoke execute on function public.record_recurring_occurrence(uuid, numeric, uuid, date)
  from public, anon;
grant execute on function public.record_recurring_occurrence(uuid, numeric, uuid, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- TAAHHÜT İPTALİ
--
-- Geçmiş silinmiyor. `active = false` yalnızca **gelecek** vade üretimini
-- durduruyor; kaydedilmiş giderler ve geçmiş vadeler yerinde kalıyor.
-- Bekleyen gelecek vadeler `skipped`'a çekiliyor ki iş kuyruğunda
-- görünmesinler.
-- ---------------------------------------------------------------------------
create or replace function public.cancel_recurring_expense(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_club uuid;
begin
  select club_id into v_club from public.recurring_expenses where id = p_id;
  if v_club is null then
    raise exception 'Taahhüt bulunamadı';
  end if;

  if not public.is_club_staff(v_club) then
    raise exception 'Taahhüdü yalnızca kulüp yöneticisi durdurabilir';
  end if;

  update public.recurring_expenses set active = false where id = p_id;

  update public.recurring_occurrences
     set status = 'skipped'
   where recurring_id = p_id
     and status = 'pending'
     and due_on > current_date;
end;
$fn$;

revoke execute on function public.cancel_recurring_expense(uuid) from public, anon;
grant execute on function public.cancel_recurring_expense(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- VADE HATIRLATMASI
--
-- Mevcut `reminder_log` kullanılıyor, ikinci bir tekillik mekanizması
-- kurulmuyor. Anahtar `(kind, entity_id, profile_id, sent_on)`; aynı vade
-- için aynı kişiye aynı gün ikinci bildirim gitmiyor.
--
-- Üç aşama: 7 gün kala, 3 gün kala, vade geçtiğinde. `send_fee_reminders`
-- ile aynı desen.
-- ---------------------------------------------------------------------------
create or replace function public.send_commitment_reminders()
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_n int := 0;
begin
  with due as (
    select o.id, o.club_id, o.due_on, o.amount, r.title,
           case
             when o.due_on = current_date + 7 then 'yaklaşıyor'
             when o.due_on = current_date + 3 then 'yakın'
             else 'gecikti'
           end as phase
      from public.recurring_occurrences o
      join public.recurring_expenses r on r.id = o.recurring_id
     where o.status = 'pending'
       and o.due_on in (current_date + 7, current_date + 3, current_date)
  ),
  targets as (
    -- Kulüp yöneticileri. Antrenör ve görevliye gitmiyor: taahhüt ödemesi
    -- onların işi değil ve ilgisiz bildirim, bildirimlerin tamamını
    -- okunmaz yapıyor.
    --
    -- `status = 'active'` şart: üyeliği kaldırılmış yönetici hâlâ kulübün
    -- mali bildirimini alırdı. `distinct` de şart — aynı kişi farklı
    -- takımlarda ikinci bir club_admin satırı taşıyabiliyor
    -- (`unique (club_id, profile_id, role, team_id)`).
    select distinct d.id as occ_id, m.profile_id, d.title, d.amount, d.phase,
           d.due_on, c.name as club_name
      from due d
      join public.club_memberships m
        on m.club_id = d.club_id
       and m.role = 'club_admin'
       and m.status = 'active'
      join public.clubs c on c.id = d.club_id
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'commitment', t.occ_id, t.profile_id from targets t
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'commitment_due',
           case t.phase
             when 'yaklaşıyor' then 'Taahhüt ödemesi bir hafta sonra'
             when 'yakın'      then 'Taahhüt ödemesine 3 gün kaldı'
             else 'Taahhüt ödemesinin vadesi bugün'
           end,
           t.club_name || ' · ' || t.title || ' · ' ||
             trim(to_char(t.amount, 'FM999G999G999')) || ' TL',
           'recurring_occurrence', f.entity_id
      from fresh f
      join targets t
        on t.occ_id = f.entity_id and t.profile_id = f.profile_id
    returning 1
  )
  select count(*) into v_n from sent;

  return v_n;
end;
$fn$;

-- Vade üretimi ve hatırlatma her sabah. `send_fee_reminders` 09:00'da
-- çalışıyor; taahhüt 08:30'da, önce vadeler üretilsin diye.
-- `cron.schedule` aynı iş adıyla çağrıldığında üzerine yazıyor; tekrar
-- çalıştırmak zararsız. 0022'deki desenin aynısı — `cron.job` tablosunu
-- okumaya kalkmak superuser olmayan rolde izin hatası veriyor.
select cron.schedule(
  'swansport_recurring_generate', '0 5 * * *',
  $cron$select public.generate_recurring_occurrences();$cron$);

select cron.schedule(
  'swansport_commitment_reminders', '30 5 * * *',
  $cron$select public.send_commitment_reminders();$cron$);
