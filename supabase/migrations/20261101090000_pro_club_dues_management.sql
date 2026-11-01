set local lock_timeout = '15s';

-- Pro club managers need named dues records. Accountants keep using the
-- existing masked acc_ledger projection; coaches must never enter this path.
alter table public.payments
  add column if not exists operation_id uuid;

create unique index if not exists idx_payments_club_operation
  on public.payments (club_id, operation_id)
  where operation_id is not null;

create or replace function public.pro_club_dues_overview(
  p_club uuid,
  p_period text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare result jsonb;
begin
  if auth.uid() is null or not public.is_club_admin(p_club) then
    raise exception 'Kulüp yöneticisi yetkisi gerekli';
  end if;

  with payment_totals as (
    select p.invoice_id,
           coalesce(sum(p.amount) filter (where p.status = 'confirmed'), 0) as confirmed,
           coalesce(sum(p.amount) filter (where p.status = 'pending'), 0) as pending
      from public.payments p
     where p.club_id = p_club and p.invoice_id is not null
     group by p.invoice_id
  ), scoped_invoices as (
    select i.*, trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')) as athlete_name,
           coalesce(pt.confirmed, 0) as confirmed_amount,
           coalesce(pt.pending, 0) as pending_amount,
           greatest(i.amount - coalesce(pt.confirmed, 0), 0) as balance
      from public.invoices i
      left join public.athletes a on a.id = i.athlete_id
      left join payment_totals pt on pt.invoice_id = i.id
     where i.club_id = p_club
       and (p_period is null or i.period = p_period)
  )
  select jsonb_build_object(
    'summary', jsonb_build_object(
      'billed', coalesce((select sum(amount) from scoped_invoices), 0),
      'collected', coalesce((select sum(confirmed_amount) from scoped_invoices), 0),
      'outstanding', coalesce((select sum(balance) from scoped_invoices), 0),
      'paid_count', (select count(*) from scoped_invoices where balance = 0),
      'partial_count', (select count(*) from scoped_invoices where confirmed_amount > 0 and balance > 0),
      'pending_count', (select count(*) from scoped_invoices where confirmed_amount = 0 and balance > 0 and (due_date is null or due_date >= current_date)),
      'overdue_count', (select count(*) from scoped_invoices where balance > 0 and due_date < current_date),
      'pending_payment_count', (select count(*) from public.payments where club_id = p_club and status = 'pending')
    ),
    'invoices', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', id,
        'athlete_id', athlete_id,
        'athlete_name', nullif(athlete_name, ''),
        'label', label,
        'amount', amount,
        'confirmed_amount', confirmed_amount,
        'pending_amount', pending_amount,
        'balance', balance,
        'status', case
          when balance = 0 then 'paid'
          when confirmed_amount > 0 then 'partial'
          when due_date is not null and due_date < current_date then 'overdue'
          else 'pending'
        end,
        'period', period,
        'due_date', due_date
      ) order by due_date nulls last, athlete_name)
      from scoped_invoices
    ), '[]'::jsonb),
    'payments', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id,
        'invoice_id', p.invoice_id,
        'athlete_name', nullif(trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')), ''),
        'label', coalesce(i.label, 'Serbest ödeme'),
        'amount', p.amount,
        'method', p.method,
        'status', p.status,
        'paid_at', p.paid_at,
        'receipt_path', p.receipt_path,
        'created_at', p.created_at
      ) order by p.created_at desc)
      from public.payments p
      left join public.invoices i on i.id = p.invoice_id
      left join public.athletes a on a.id = p.athlete_id
      where p.club_id = p_club
        and (p_period is null or i.period = p_period)
    ), '[]'::jsonb),
    'plans', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', fp.id,
        'name', fp.name,
        'amount', fp.amount,
        'due_day', fp.due_day,
        'active', fp.active
      ) order by fp.active desc, fp.name)
      from public.fee_plans fp where fp.club_id = p_club
    ), '[]'::jsonb),
    'periods', coalesce((
      select jsonb_agg(period order by period desc)
      from (select distinct i.period from public.invoices i
            where i.club_id = p_club and i.period is not null) periods
    ), '[]'::jsonb)
  ) into result;

  return result;
end;
$fn$;

create or replace function public.pro_decide_payment(
  p_payment uuid,
  p_approve boolean,
  p_note text default null
)
returns text
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_pay public.payments%rowtype;
  v_target text := case when p_approve then 'confirmed' else 'rejected' end;
begin
  select * into v_pay from public.payments where id = p_payment for update;
  if v_pay.id is null or not public.is_club_admin(v_pay.club_id) then
    raise exception 'Ödeme işlemi bulunamadı veya yetkin yok';
  end if;
  if v_pay.status = v_target then return v_target; end if;
  if v_pay.status <> 'pending' then
    raise exception 'Ödeme daha önce farklı bir kararla sonuçlandırıldı';
  end if;

  update public.payments
     set status = v_target, confirmed_by = auth.uid(), confirmed_at = now(),
         note = coalesce(nullif(trim(p_note), ''), note)
   where id = p_payment;

  if v_pay.invoice_id is not null then
    update public.invoices i
       set status = case when coalesce((
         select sum(p.amount) from public.payments p
          where p.invoice_id = i.id and p.status = 'confirmed'
       ), 0) >= i.amount then 'paid'::public.invoice_status
       else 'pending'::public.invoice_status end
     where i.id = v_pay.invoice_id;
  end if;
  return v_target;
end;
$fn$;

create or replace function public.pro_record_payment(
  p_invoice uuid,
  p_amount numeric,
  p_method text,
  p_note text,
  p_operation uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_inv public.invoices%rowtype;
  v_existing public.payments%rowtype;
  v_id uuid;
  v_balance numeric;
begin
  if p_operation is null or p_amount is null or p_amount <= 0
     or p_method not in ('nakit', 'havale', 'kart', 'diger') then
    raise exception 'Geçersiz tahsilat bilgisi';
  end if;
  select * into v_inv from public.invoices where id = p_invoice for update;
  if v_inv.id is null or not public.is_club_admin(v_inv.club_id) then
    raise exception 'Fatura bulunamadı veya yetkin yok';
  end if;

  select * into v_existing from public.payments
   where club_id = v_inv.club_id and operation_id = p_operation;
  if v_existing.id is not null then
    if v_existing.invoice_id = p_invoice and v_existing.amount = p_amount
       and v_existing.method = p_method then return v_existing.id; end if;
    raise exception 'İşlem anahtarı farklı bir tahsilatta kullanılmış';
  end if;

  select greatest(v_inv.amount - coalesce(sum(p.amount), 0), 0) into v_balance
    from public.payments p
   where p.invoice_id = p_invoice and p.status = 'confirmed';
  if v_balance <= 0 or p_amount > v_balance then
    raise exception 'Tahsilat kalan borcu aşamaz';
  end if;

  insert into public.payments
    (club_id, invoice_id, athlete_id, amount, method, note, declared_by,
     status, confirmed_by, confirmed_at, operation_id)
  values
    (v_inv.club_id, p_invoice, v_inv.athlete_id, p_amount, p_method,
     nullif(trim(p_note), ''), auth.uid(), 'confirmed', auth.uid(), now(), p_operation)
  returning id into v_id;

  update public.invoices
     set status = case when p_amount >= v_balance then 'paid'::public.invoice_status
                       else 'pending'::public.invoice_status end
   where id = p_invoice;
  return v_id;
end;
$fn$;

revoke all on function public.pro_club_dues_overview(uuid, text) from public, anon, authenticated;
revoke all on function public.pro_decide_payment(uuid, boolean, text) from public, anon, authenticated;
revoke all on function public.pro_record_payment(uuid, numeric, text, text, uuid) from public, anon, authenticated;
grant execute on function public.pro_club_dues_overview(uuid, text) to authenticated;
grant execute on function public.pro_decide_payment(uuid, boolean, text) to authenticated;
grant execute on function public.pro_record_payment(uuid, numeric, text, text, uuid) to authenticated;
