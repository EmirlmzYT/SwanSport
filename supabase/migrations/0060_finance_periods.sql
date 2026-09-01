-- ---------------------------------------------------------------------------
-- 0060 — Mali dönemler, kapanış ve düzeltme
--
-- Kapanış bir bayrak değil, bir KİLİT. Kapanmış dönemde gider/fatura/ödeme
-- değişikliği tetikleyiciyle kesiliyor — arayüzde düğmeyi gizlemek güvenlik
-- değil (AGENTS.md değişmez 4); REST üzerinden doğrudan `update` yine
-- geçerdi ve kapanmış bir ayın rakamı sessizce değişirdi.
--
-- Düzeltme yolu: geçmişi değiştirmek değil, **bugüne ters kayıt yazmak.**
-- Muhasebenin standart yolu bu ve denetim izini bozmayan tek yol.
-- ---------------------------------------------------------------------------

create table if not exists public.finance_periods (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  period_from date not null,
  period_to   date not null,
  status      text not null default 'open',
  closed_by   uuid references public.profiles(id) on delete set null,
  closed_at   timestamptz,
  close_note  text,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint finance_period_unique unique (club_id, period_from, period_to)
);

do $blk$ begin
  alter table public.finance_periods
    add constraint finance_period_status_check
    check (status in ('open', 'preparing', 'review', 'closed', 'needs_correction'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.finance_periods
    add constraint finance_period_range_check check (period_to >= period_from);
exception when duplicate_object then null; end $blk$;

create index if not exists idx_finance_period_club
  on public.finance_periods (club_id, period_from desc);

-- Kilit sorgusu her yazma işleminde çalışıyor; indeks olmadan tetikleyici
-- her gider kaydında tam tarama yapardı.
create index if not exists idx_finance_period_closed
  on public.finance_periods (club_id, period_from, period_to)
  where status = 'closed';

alter table public.finance_periods enable row level security;

drop policy if exists "finance_period_read" on public.finance_periods;
create policy "finance_period_read" on public.finance_periods for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- Dönem açmak muhasebeciye de açık; KAPATMAK ve AÇMAK yalnızca RPC'den ve
-- yalnızca kulüp yöneticisine. Doğrudan `update` ile status değiştirmeyi
-- engellemek için burada `for all` yok.
drop policy if exists "finance_period_insert" on public.finance_periods;
create policy "finance_period_insert" on public.finance_periods for insert
  to authenticated
  with check ((public.is_club_staff(club_id) or public.is_club_accountant(club_id))
              and status = 'open');

drop policy if exists "finance_period_update" on public.finance_periods;
create policy "finance_period_update" on public.finance_periods for update
  to authenticated
  using (public.is_club_staff(club_id) and status <> 'closed')
  with check (public.is_club_staff(club_id) and status <> 'closed');

-- ---------------------------------------------------------------------------
-- DÜZELTME KAYITLARI
-- ---------------------------------------------------------------------------
create table if not exists public.finance_adjustments (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id) on delete cascade,
  period_id    uuid references public.finance_periods(id) on delete set null,
  -- Neyi düzeltiyor.
  target_kind  text not null,
  target_id    uuid,
  -- Karşı kayıt: düzeltme sonucu doğan yeni gider/ödeme.
  entry_kind   text,
  entry_id     uuid,
  amount       numeric(12,2) not null,
  reason       text not null,
  status       text not null default 'pending',
  created_by   uuid references public.profiles(id) on delete set null,
  approved_by  uuid references public.profiles(id) on delete set null,
  approved_at  timestamptz,
  created_at   timestamptz not null default now()
);

do $blk$ begin
  alter table public.finance_adjustments
    add constraint finance_adjustment_target_check
    check (target_kind in ('expense', 'payment', 'donation', 'invoice', 'other'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.finance_adjustments
    add constraint finance_adjustment_status_check
    check (status in ('pending', 'approved', 'rejected'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.finance_adjustments
    add constraint finance_adjustment_reason_check
    check (coalesce(trim(reason), '') <> '');
exception when duplicate_object then null; end $blk$;

create index if not exists idx_finance_adjustment_club
  on public.finance_adjustments (club_id, created_at desc);

alter table public.finance_adjustments enable row level security;

drop policy if exists "finance_adjustment_read" on public.finance_adjustments;
create policy "finance_adjustment_read" on public.finance_adjustments for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));
-- Yazma yalnızca RPC'den.

-- ---------------------------------------------------------------------------
-- DÖNEM İŞLEM İZİ
-- ---------------------------------------------------------------------------
create table if not exists public.finance_period_logs (
  id         uuid primary key default gen_random_uuid(),
  -- Nullable: düzeltme kaydı açık bir döneme denk gelmeyebilir. `not null`
  -- olsaydı oraya düzeltmenin kendi kimliğini yazmak gerekirdi ve iz
  -- okunamaz hale gelirdi.
  period_id  uuid,
  club_id    uuid not null references public.clubs(id) on delete cascade,
  actor_id   uuid references public.profiles(id) on delete set null,
  action     text not null,
  note       text,
  created_at timestamptz not null default now()
);

create index if not exists idx_finance_period_log
  on public.finance_period_logs (period_id, created_at desc);

alter table public.finance_period_logs enable row level security;

drop policy if exists "finance_period_log_read" on public.finance_period_logs;
create policy "finance_period_log_read" on public.finance_period_logs for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- ---------------------------------------------------------------------------
-- KİLİT
-- ---------------------------------------------------------------------------
create or replace function public.is_period_closed(p_club uuid, p_date date)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.finance_periods
     where club_id = p_club
       and status = 'closed'
       and p_date between period_from and period_to);
$fn$;

create or replace function public.block_closed_period()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_club uuid;
  v_date date;
begin
  -- DELETE'te `old`, diğerlerinde `new` bakılır. Silme de engelleniyor:
  -- kapanmış dönemin hareketi silinemez.
  if tg_op = 'DELETE' then
    v_club := old.club_id;
    v_date := case tg_table_name
                when 'expenses'  then old.spent_on
                when 'payments'  then old.paid_at
                when 'donations' then old.created_at::date
                else old.created_at::date
              end;
  else
    v_club := new.club_id;
    v_date := case tg_table_name
                when 'expenses'  then new.spent_on
                when 'payments'  then new.paid_at
                when 'donations' then new.created_at::date
                else new.created_at::date
              end;
  end if;

  if public.is_period_closed(v_club, v_date) then
    raise exception
      'Bu tarih kapanmış bir mali döneme ait. Değişiklik için düzeltme '
      'kaydı (ters kayıt) oluşturun.'
      using errcode = 'check_violation';
  end if;

  -- UPDATE'te kaydın tarihi kapanmış bir döneme TAŞINAMAZ da.
  if tg_op = 'UPDATE' then
    v_date := case tg_table_name
                when 'expenses'  then old.spent_on
                when 'payments'  then old.paid_at
                else old.created_at::date
              end;
    if public.is_period_closed(v_club, v_date) then
      raise exception 'Kaynak kayıt kapanmış mali döneme ait'
        using errcode = 'check_violation';
    end if;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$fn$;

drop trigger if exists trg_expenses_period_lock on public.expenses;
create trigger trg_expenses_period_lock
  before insert or update or delete on public.expenses
  for each row execute function public.block_closed_period();

drop trigger if exists trg_payments_period_lock on public.payments;
create trigger trg_payments_period_lock
  before insert or update or delete on public.payments
  for each row execute function public.block_closed_period();

drop trigger if exists trg_donations_period_lock on public.donations;
create trigger trg_donations_period_lock
  before insert or update or delete on public.donations
  for each row execute function public.block_closed_period();

-- ---------------------------------------------------------------------------
-- KAPANIŞ KONTROL LİSTESİ
--
-- On madde. `blocking` olanlar giderilmeden dönem kapanmıyor; diğerleri
-- bilgi amaçlı. Kapanışı engellemeyen maddeleri de göstermek gerekiyor:
-- "bütçe sapması" kapanışı durdurmaz ama kapatmadan önce görülmelidir.
-- ---------------------------------------------------------------------------
create or replace function public.period_close_checklist(
  p_club uuid, p_from date, p_to date)
returns table (
  code     text,
  label    text,
  blocking boolean,
  qty      bigint,
  amount   numeric)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if not (public.is_club_staff(p_club) or public.is_club_accountant(p_club)) then
    raise exception 'Bu kulübün kapanış listesini görme yetkiniz yok';
  end if;

  return query
  select 'draft_expense', 'Açık taslak gider', true,
         count(*), coalesce(sum(e.amount), 0)
    from public.expenses e
   where e.club_id = p_club and e.status = 'draft'
     and e.spent_on between p_from and p_to
  union all
  select 'pending_payment', 'Onay bekleyen ödeme bildirimi', true,
         count(*), coalesce(sum(p.amount), 0)
    from public.payments p
   where p.club_id = p_club and p.status = 'pending'
     and p.paid_at between p_from and p_to
  union all
  select 'unlinked', 'Hesaba bağlanmamış hareket', true, count(*),
         coalesce(sum(x.amount), 0)
    from (
      select p.amount from public.payments p
       where p.club_id = p_club and p.status = 'confirmed'
         and p.account_id is null and p.paid_at between p_from and p_to
      union all
      select e.amount from public.expenses e
       where e.club_id = p_club and e.status = 'complete'
         and e.account_id is null and e.spent_on between p_from and p_to
      union all
      select d.amount from public.donations d
       where d.club_id = p_club and d.status = 'confirmed'
         and d.account_id is null
         and d.created_at::date between p_from and p_to) x
  union all
  select 'negative_account', 'Negatif bakiyeli hesap', true, count(*),
         coalesce(sum(b.balance), 0)
    from public.acc_account_balances(p_club) b
   where b.balance < 0
  union all
  select 'bank_import', 'Dönemde banka ekstresi yüklendi mi', false,
         count(*), 0::numeric
    from public.bank_imports i
   where i.club_id = p_club
     and coalesce(i.period_to, i.created_at::date) between p_from and p_to
  union all
  select 'bank_unmatched', 'Eşleşmemiş banka hareketi', true, count(*),
         coalesce(sum(t.amount), 0)
    from public.bank_transactions t
   where t.club_id = p_club and t.match_status = 'unmatched'
     and t.txn_on between p_from and p_to
  union all
  select 'pending_approval', 'Onay bekleyen gider', true, count(*),
         coalesce(sum(e.amount), 0)
    from public.expenses e
   where e.club_id = p_club and e.approval_status = 'pending'
     and e.spent_on between p_from and p_to
  union all
  select 'overdue_fee', 'Gecikmiş tahsilat', false, count(*),
         coalesce(sum(i.amount), 0)
    from public.invoices i
   where i.club_id = p_club and i.status <> 'paid'
     and i.due_date is not null and i.due_date between p_from and p_to
  union all
  -- Aşım tutarı `remaining` negatifken onun mutlak değeri.
  select 'budget_overrun', 'Bütçesi aşılmış satır', false, count(*),
         coalesce(sum(greatest(-v.remaining, 0)), 0)
    from public.budget_vs_actual(p_club, p_from, p_to) v
   where v.risk = 'kritik';
  -- Kapanış notu listede yok: hesaplanan bir kontrol değil, kapatma
  -- diyaloğunda alınan bir girdi. Sıfır adetli sahte satır olarak
  -- döndürmek, listeyi "tamamlanmış madde" gibi kirletiyordu.
end;
$fn$;

revoke execute on function public.period_close_checklist(uuid, date, date)
  from public, anon;
grant execute on function public.period_close_checklist(uuid, date, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- KAPAT
--
-- Engel varsa kapanmıyor ve hangi maddenin engellediği hata mesajında.
-- "Kapat" düğmesini pasif yapıp sebebi söylememek, kullanıcıyı sistemle
-- güreştiriyor.
-- ---------------------------------------------------------------------------
create or replace function public.close_finance_period(
  p_period uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_p        public.finance_periods%rowtype;
  v_blockers text;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_p from public.finance_periods where id = p_period;
  if v_p.id is null then
    raise exception 'Dönem bulunamadı';
  end if;

  -- Kapatmak muhasebecinin değil kulüp yöneticisinin kararı: kapanış
  -- rakamların nihai olduğunu ilan etmek demek.
  if not public.is_club_staff(v_p.club_id) then
    raise exception 'Dönemi yalnızca kulüp yöneticisi kapatabilir';
  end if;

  if v_p.status = 'closed' then
    raise exception 'Bu dönem zaten kapalı';
  end if;

  select string_agg(c.label || ' (' || c.qty || ')', ', ')
    into v_blockers
    from public.period_close_checklist(v_p.club_id, v_p.period_from, v_p.period_to) c
   where c.blocking and c.qty > 0;

  if v_blockers is not null then
    raise exception 'Kapanış engellendi: %', v_blockers;
  end if;

  update public.finance_periods
     set status = 'closed', closed_by = auth.uid(), closed_at = now(),
         close_note = nullif(trim(coalesce(p_note, '')), '')
   where id = p_period;

  insert into public.finance_period_logs (period_id, club_id, actor_id, action, note)
  values (p_period, v_p.club_id, auth.uid(), 'close', p_note);

  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id)
  select distinct m.profile_id, 'period_closed', 'Mali dönem kapandı',
         to_char(v_p.period_from, 'DD.MM.YYYY') || ' – ' ||
           to_char(v_p.period_to, 'DD.MM.YYYY') || ' dönemi kapatıldı',
         'finance_period', p_period
    from public.club_memberships m
   where m.club_id = v_p.club_id and m.role = 'club_admin'
     and m.status = 'active';
end;
$fn$;

revoke execute on function public.close_finance_period(uuid, text) from public, anon;
grant execute on function public.close_finance_period(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- GERİ AÇ
--
-- Gerekçe zorunlu ve iz bırakıyor. Kapanışı geri almak olağan bir işlem
-- değil; kolaylaştırmak, kapanışın anlamını yok eder.
-- ---------------------------------------------------------------------------
create or replace function public.reopen_finance_period(
  p_period uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_p public.finance_periods%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if coalesce(trim(coalesce(p_reason, '')), '') = '' then
    raise exception 'Dönemi geri açmak için gerekçe zorunlu';
  end if;

  select * into v_p from public.finance_periods where id = p_period;
  if v_p.id is null then
    raise exception 'Dönem bulunamadı';
  end if;

  if not public.is_club_staff(v_p.club_id) then
    raise exception 'Dönemi yalnızca kulüp yöneticisi geri açabilir';
  end if;

  if v_p.status <> 'closed' then
    raise exception 'Bu dönem kapalı değil';
  end if;

  update public.finance_periods
     set status = 'needs_correction', closed_by = null, closed_at = null
   where id = p_period;

  insert into public.finance_period_logs (period_id, club_id, actor_id, action, note)
  values (p_period, v_p.club_id, auth.uid(), 'reopen', trim(p_reason));
end;
$fn$;

revoke execute on function public.reopen_finance_period(uuid, text) from public, anon;
grant execute on function public.reopen_finance_period(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- DÜZELTME KAYDI
--
-- Kapanmış dönemin gideri için **bugüne** ters kayıt yazıyor. Geçmiş
-- satıra dokunmuyor; muhasebenin standart yolu bu.
--
-- Ters gider negatif tutarla değil, ayrı bir düzeltme satırıyla tutuluyor:
-- `expenses.amount` şemada negatif olabilir ama negatif gider, kategori ve
-- bütçe raporlarında sessizce yanlış toplam üretiyordu.
-- ---------------------------------------------------------------------------
create or replace function public.create_finance_adjustment(
  p_club        uuid,
  p_target_kind text,
  p_target_id   uuid,
  p_amount      numeric,
  p_reason      text)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id     uuid;
  v_period uuid;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if not (public.is_club_staff(p_club) or public.is_club_accountant(p_club)) then
    raise exception 'Bu kulüpte düzeltme kaydı açma yetkiniz yok';
  end if;

  if coalesce(trim(coalesce(p_reason, '')), '') = '' then
    raise exception 'Düzeltme gerekçesi zorunlu';
  end if;

  if p_amount is null or p_amount = 0 then
    raise exception 'Düzeltme tutarı sıfır olamaz';
  end if;

  select id into v_period from public.finance_periods
   where club_id = p_club and current_date between period_from and period_to
   order by period_from desc limit 1;

  insert into public.finance_adjustments
    (club_id, period_id, target_kind, target_id, amount, reason, created_by)
  values (p_club, v_period, p_target_kind, p_target_id, p_amount,
          trim(p_reason), auth.uid())
  returning id into v_id;

  return v_id;
end;
$fn$;

revoke execute on function public.create_finance_adjustment(uuid, text, uuid, numeric, text)
  from public, anon;
grant execute on function public.create_finance_adjustment(uuid, text, uuid, numeric, text)
  to authenticated;

create or replace function public.approve_finance_adjustment(
  p_id uuid, p_approve boolean, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_a public.finance_adjustments%rowtype;
begin
  select * into v_a from public.finance_adjustments where id = p_id;
  if v_a.id is null then
    raise exception 'Düzeltme kaydı bulunamadı';
  end if;

  -- Düzeltmeyi açan kişi kendi kaydını onaylayamaz: gider onayındaki
  -- kuralın aynısı, aynı gerekçeyle.
  if v_a.created_by = auth.uid() then
    raise exception 'Kendi açtığınız düzeltmeyi siz onaylayamazsınız';
  end if;

  if not public.is_club_staff(v_a.club_id) then
    raise exception 'Düzeltmeyi yalnızca kulüp yöneticisi onaylayabilir';
  end if;

  if v_a.status <> 'pending' then
    raise exception 'Bu düzeltme zaten sonuçlanmış';
  end if;

  update public.finance_adjustments
     set status = case when p_approve then 'approved' else 'rejected' end,
         approved_by = auth.uid(), approved_at = now()
   where id = p_id;

  insert into public.finance_period_logs
    (period_id, club_id, actor_id, action, note)
  select v_a.period_id, v_a.club_id, auth.uid(),
         case when p_approve then 'adjustment_approved'
              else 'adjustment_rejected' end,
         coalesce(p_note, v_a.reason);
end;
$fn$;

revoke execute on function public.approve_finance_adjustment(uuid, boolean, text)
  from public, anon;
grant execute on function public.approve_finance_adjustment(uuid, boolean, text)
  to authenticated;
