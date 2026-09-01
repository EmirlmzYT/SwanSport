-- ---------------------------------------------------------------------------
-- 0057 — Gider onay politikaları
--
-- Harcama limiti `club_settings`'e ya da `club_memberships`'e sıkıştırılmıyor.
-- Sebebi: limit tek bir sayı değil — tutar aralığı, kategori, kaç onay,
-- hangi roller ve geçerlilik dönemi. Bunlar bir satırlık ayar değil, bir
-- politika; kendi tablosunu hak ediyor.
-- ---------------------------------------------------------------------------

create table if not exists public.expense_approval_policies (
  id                 uuid primary key default gen_random_uuid(),
  club_id            uuid not null references public.clubs(id) on delete cascade,
  label              text not null,
  min_amount         numeric(12,2) not null default 0,
  -- null = üst sınır yok. Politikanın en üst dilimi bu.
  max_amount         numeric(12,2),
  -- null = tüm kategoriler.
  category_id        uuid references public.expense_categories(id) on delete cascade,
  required_approvals int not null default 1,
  -- Kimler onaylayabilir. Varsayılan yalnızca kulüp yöneticisi.
  approver_roles     public.club_role[] not null default array['club_admin']::public.club_role[],
  reminder_hours     int not null default 48,
  valid_from         date,
  valid_to           date,
  active             boolean not null default true,
  created_by         uuid references public.profiles(id) on delete set null,
  created_at         timestamptz not null default now()
);

do $blk$ begin
  alter table public.expense_approval_policies
    add constraint expense_policy_range_check
    check (max_amount is null or max_amount > min_amount);
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.expense_approval_policies
    add constraint expense_policy_count_check
    check (required_approvals between 1 and 5);
exception when duplicate_object then null; end $blk$;

create index if not exists idx_expense_policy_club
  on public.expense_approval_policies (club_id, active, min_amount);

alter table public.expense_approval_policies enable row level security;

drop policy if exists "expense_policy_read" on public.expense_approval_policies;
create policy "expense_policy_read" on public.expense_approval_policies for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- Politikayı yalnızca kulüp yöneticisi kurar. Muhasebeci kendi onay
-- eşiğini yükseltebilseydi, denetim mekanizmasını kendisi kapatabilirdi.
drop policy if exists "expense_policy_write" on public.expense_approval_policies;
create policy "expense_policy_write" on public.expense_approval_policies for all
  to authenticated
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));

-- ---------------------------------------------------------------------------
-- ONAY OYLARI
--
-- Silinmiyor: `expense_approvals` satırı bir kez yazıldıktan sonra
-- politika DELETE'e izin vermiyor. Onay geçmişi denetim izinin parçası.
-- ---------------------------------------------------------------------------
create table if not exists public.expense_approvals (
  id          uuid primary key default gen_random_uuid(),
  expense_id  uuid not null references public.expenses(id) on delete cascade,
  club_id     uuid not null references public.clubs(id) on delete cascade,
  approver_id uuid not null references public.profiles(id) on delete cascade,
  decision    text not null,
  reason      text,
  created_at  timestamptz not null default now(),
  -- Bir kişi bir gidere bir kez oy verir.
  constraint expense_approval_once unique (expense_id, approver_id)
);

do $blk$ begin
  alter table public.expense_approvals
    add constraint expense_approval_decision_check
    check (decision in ('approve', 'reject'));
exception when duplicate_object then null; end $blk$;

-- Redde gerekçe zorunlu. Gerekçesiz red, kaydı giren kişiye ne
-- düzelteceğini söylemiyor ve kayıt kuyrukta çürüyor.
do $blk$ begin
  alter table public.expense_approvals
    add constraint expense_approval_reject_needs_reason
    check (decision <> 'reject' or coalesce(trim(reason), '') <> '');
exception when duplicate_object then null; end $blk$;

create index if not exists idx_expense_approval_expense
  on public.expense_approvals (expense_id, created_at);

alter table public.expense_approvals enable row level security;

drop policy if exists "expense_approval_read" on public.expense_approvals;
create policy "expense_approval_read" on public.expense_approvals for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));
-- INSERT/UPDATE/DELETE politikası bilerek yok: yazma yalnızca RPC'den.

-- ---------------------------------------------------------------------------
-- GİDER ALANLARI
-- ---------------------------------------------------------------------------
alter table public.expenses
  add column if not exists approval_status text not null default 'not_required',
  add column if not exists submitted_at    timestamptz,
  add column if not exists rejected_reason text;

do $blk$ begin
  alter table public.expenses
    add constraint expenses_approval_status_check
    check (approval_status in ('not_required', 'pending', 'approved', 'rejected'));
exception when duplicate_object then null; end $blk$;

create index if not exists idx_expenses_approval
  on public.expenses (club_id, approval_status)
  where approval_status = 'pending';

-- ---------------------------------------------------------------------------
-- POLİTİKA SEÇİMİ
--
-- Tutara ve kategoriye uyan en dar politika kazanır: kategoriye özel olan,
-- genel olandan önce. İki politika aynı aralığı kapsıyorsa daha yüksek
-- `min_amount` olan seçiliyor — kulüp üst dilimi bilerek daraltmış demektir.
-- ---------------------------------------------------------------------------
create or replace function public.expense_policy_for(
  p_club uuid, p_amount numeric, p_category uuid)
returns public.expense_approval_policies
language sql
stable
security definer
set search_path = public
as $fn$
  select p.*
    from public.expense_approval_policies p
   where p.club_id = p_club
     and p.active
     and p_amount >= p.min_amount
     and (p.max_amount is null or p_amount < p.max_amount)
     and (p.category_id is null or p.category_id = p_category)
     and (p.valid_from is null or p.valid_from <= current_date)
     and (p.valid_to   is null or p.valid_to   >= current_date)
   order by (p.category_id is not null) desc, p.min_amount desc
   limit 1;
$fn$;

revoke execute on function public.expense_policy_for(uuid, numeric, uuid)
  from public, anon;
grant execute on function public.expense_policy_for(uuid, numeric, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- ONAYA GÖNDER
--
-- Politika yoksa onay gerekmiyor: kulüp bir eşik tanımlamadıysa sistem
-- kendiliğinden onay dayatmıyor. Bayrak gibi burada da varsayılanı
-- kısıtlayıcı yapmak, hiçbir gider kaydedilemez hâle getirirdi.
-- ---------------------------------------------------------------------------
create or replace function public.submit_expense_for_approval(p_expense uuid)
returns text
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_exp    public.expenses%rowtype;
  v_policy public.expense_approval_policies%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_exp from public.expenses where id = p_expense;
  if v_exp.id is null then
    raise exception 'Gider bulunamadı';
  end if;

  if not (public.is_club_staff(v_exp.club_id)
          or public.is_club_accountant(v_exp.club_id)) then
    raise exception 'Bu gideri onaya gönderme yetkiniz yok';
  end if;

  v_policy := public.expense_policy_for(v_exp.club_id, v_exp.amount,
                                        v_exp.category_id);

  if v_policy.id is null then
    update public.expenses
       set approval_status = 'not_required', status = 'complete'
     where id = p_expense;
    return 'not_required';
  end if;

  update public.expenses
     set approval_status = 'pending',
         submitted_at = now(),
         rejected_reason = null
   where id = p_expense;

  return 'pending';
end;
$fn$;

revoke execute on function public.submit_expense_for_approval(uuid) from public, anon;
grant execute on function public.submit_expense_for_approval(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- ONAY / RED
--
-- İKİ KURAL:
--
-- 1. Kendi girdiği gideri kimse onaylayamaz. "Tek başına nihai onay
--    veremez" kuralını uygularken oyu saymayıp yine de kabul etmek,
--    tek yöneticili kulüpte sessiz kilitlenme üretirdi; açık hata mesajı
--    vermek dürüst olan. Tek yöneticili kulüp eşiği yükselterek çözer.
--
-- 2. Rol kontrolü politikadan geliyor. `is_club_staff` yetmiyor: antrenör
--    de kulüp personeli ama politika yalnızca `club_admin` diyorsa
--    onaylayamamalı.
-- ---------------------------------------------------------------------------
create or replace function public.decide_expense_approval(
  p_expense uuid,
  p_approve boolean,
  p_reason  text default null)
returns text
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_exp    public.expenses%rowtype;
  v_policy public.expense_approval_policies%rowtype;
  v_ok     int;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_exp from public.expenses where id = p_expense;
  if v_exp.id is null then
    raise exception 'Gider bulunamadı';
  end if;

  if v_exp.approval_status <> 'pending' then
    raise exception 'Bu gider onay beklemiyor';
  end if;

  if v_exp.entered_by = auth.uid() then
    raise exception 'Kendi girdiğiniz gideri siz onaylayamazsınız; '
                    'başka bir yetkili onaylamalı';
  end if;

  v_policy := public.expense_policy_for(v_exp.club_id, v_exp.amount,
                                        v_exp.category_id);
  if v_policy.id is null then
    raise exception 'Bu gidere uyan onay politikası yok';
  end if;

  if not exists (
    select 1 from public.club_memberships m
     where m.club_id = v_exp.club_id
       and m.profile_id = auth.uid()
       and m.status = 'active'
       and m.role = any (v_policy.approver_roles)) then
    raise exception 'Bu tutarı onaylama yetkiniz yok';
  end if;

  if not p_approve and coalesce(trim(p_reason), '') = '' then
    raise exception 'Red için gerekçe zorunlu';
  end if;

  insert into public.expense_approvals
    (expense_id, club_id, approver_id, decision, reason)
  values (p_expense, v_exp.club_id, auth.uid(),
          case when p_approve then 'approve' else 'reject' end,
          nullif(trim(coalesce(p_reason, '')), ''))
  on conflict (expense_id, approver_id) do nothing;

  if not p_approve then
    update public.expenses
       set approval_status = 'rejected',
           status = 'draft',
           rejected_reason = trim(p_reason)
     where id = p_expense;

    -- Kaydı giren kişi neden reddedildiğini bilmeli.
    if v_exp.entered_by is not null then
      insert into public.notifications
        (profile_id, kind, title, body, entity_type, entity_id, actor_id)
      values (v_exp.entered_by, 'expense_rejected', 'Gider reddedildi',
              trim(to_char(v_exp.amount, 'FM999G999G999')) || ' TL · ' ||
                trim(p_reason),
              'expense', p_expense, auth.uid());
    end if;

    return 'rejected';
  end if;

  select count(*) into v_ok
    from public.expense_approvals a
   where a.expense_id = p_expense and a.decision = 'approve';

  if v_ok >= v_policy.required_approvals then
    update public.expenses
       set approval_status = 'approved', status = 'complete'
     where id = p_expense;
    return 'approved';
  end if;

  return 'pending';
end;
$fn$;

revoke execute on function public.decide_expense_approval(uuid, boolean, text)
  from public, anon;
grant execute on function public.decide_expense_approval(uuid, boolean, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- BEKLEYEN ONAY HATIRLATMASI
--
-- Politikanın `reminder_hours` süresini aşmış bekleyen giderler için.
-- `reminder_log` günlük tekillik veriyor: aynı gider için aynı kişiye
-- günde bir hatırlatma.
-- ---------------------------------------------------------------------------
create or replace function public.send_approval_reminders()
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_n int := 0;
begin
  with due as (
    -- `expense_policy_for` tek satırlık bileşik dönüyor; eşleşme yoksa
    -- lateral join bütün sütunları NULL veren bir satır üretiyor, o yüzden
    -- `pol.id is not null` süzgeci şart.
    select e.id as expense_id, e.club_id, e.amount, e.entered_by,
           pol.approver_roles
      from public.expenses e
      cross join lateral public.expense_policy_for(
        e.club_id, e.amount, e.category_id) pol
     where e.approval_status = 'pending'
       and e.submitted_at is not null
       and pol.id is not null
       and e.submitted_at
           < now() - make_interval(hours => coalesce(pol.reminder_hours, 48))
  ),
  targets as (
    -- Kaydı giren kişiye "senin onayını bekliyor" demiyoruz: zaten
    -- onaylayamaz.
    select distinct d.expense_id, m.profile_id, d.amount
      from due d
      join public.club_memberships m
        on m.club_id = d.club_id
       and m.status = 'active'
       and m.role = any (d.approver_roles)
     where m.profile_id is distinct from d.entered_by
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'expense_approval', t.expense_id, t.profile_id from targets t
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'expense_approval', 'Gider onayı bekliyor',
           trim(to_char(t.amount, 'FM999G999G999')) ||
             ' TL tutarındaki gider onayınızı bekliyor',
           'expense', f.entity_id
      from fresh f
      join targets t
        on t.expense_id = f.entity_id and t.profile_id = f.profile_id
    returning 1
  )
  select count(*) into v_n from sent;

  return v_n;
end;
$fn$;

select cron.schedule(
  'swansport_approval_reminders', '0 7 * * *',
  $cron$select public.send_approval_reminders();$cron$);

-- ---------------------------------------------------------------------------
-- TASLAĞI TAMAMLA
--
-- Mobilden gelen taslak burada gerçek bir gidere dönüşüyor. Tek RPC olmasının
-- sebebi: tamamlama, onay politikası kontrolü ve denetim kaydı **aynı işlemde**
-- olmalı. Üçünü ayrı çağrıya bölmek, ikincisi başarısız olunca yarım
-- tamamlanmış gider bırakırdı.
--
-- Zorunlu alanlar burada kesiliyor: kategorisiz gider kategori raporunu,
-- hesapsız gider bakiyeyi bozuyor. İkisi de sessizce yanlış rakam üretir.
-- ---------------------------------------------------------------------------
create or replace function public.complete_draft_expense(
  p_expense    uuid,
  p_category   uuid,
  p_account    uuid,
  p_vendor     uuid default null,
  p_amount     numeric default null,
  p_spent_on   date default null,
  p_note       text default null,
  p_receipt    text default null,
  p_team       uuid default null,
  p_facility   uuid default null,
  p_event      uuid default null,
  p_reason     text default null)
returns text
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_exp public.expenses%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_exp from public.expenses where id = p_expense;
  if v_exp.id is null then
    raise exception 'Gider bulunamadı';
  end if;

  if not (public.is_club_staff(v_exp.club_id)
          or public.is_club_accountant(v_exp.club_id)) then
    raise exception 'Bu gideri tamamlama yetkiniz yok';
  end if;

  if p_category is null then
    raise exception 'Kategori zorunlu';
  end if;

  if p_account is null then
    raise exception 'Kasa/banka hesabı zorunlu';
  end if;

  -- Denetim tetikleyicisi bu değişkeni okuyor. `true` = yalnızca bu işlem
  -- boyunca geçerli; oturuma sızmıyor.
  perform set_config('swansport.change_reason',
                     coalesce(nullif(trim(coalesce(p_reason, '')), ''),
                              'taslak tamamlandı'), true);

  update public.expenses
     set category_id  = p_category,
         account_id   = p_account,
         vendor_id    = coalesce(p_vendor, vendor_id),
         amount       = coalesce(p_amount, amount),
         spent_on     = coalesce(p_spent_on, spent_on),
         note         = coalesce(p_note, note),
         receipt_path = coalesce(p_receipt, receipt_path),
         team_id      = coalesce(p_team, team_id),
         facility_id  = coalesce(p_facility, facility_id),
         event_id     = coalesce(p_event, event_id),
         updated_at   = now()
   where id = p_expense;

  -- Onay gerekiyorsa `pending`, gerekmiyorsa doğrudan `complete`.
  return public.submit_expense_for_approval(p_expense);
end;
$fn$;

revoke execute on function public.complete_draft_expense(
  uuid, uuid, uuid, uuid, numeric, date, text, text, uuid, uuid, uuid, text)
  from public, anon;
grant execute on function public.complete_draft_expense(
  uuid, uuid, uuid, uuid, numeric, date, text, text, uuid, uuid, uuid, text)
  to authenticated;
