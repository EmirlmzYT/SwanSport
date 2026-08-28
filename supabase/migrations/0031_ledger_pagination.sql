-- SwanSport — 0031: defterde sunucu taraflı sayfalama
--
-- Defter büyüdüğünde bütün hareketleri tarayıcıya taşımak hem yavaş hem de
-- yanıltıcıdır: yalnızca görünen sayfayı sıralamak veya CSV'ye aktarmak doğru
-- sonucu vermez. Süzme, sayfalama ve toplam kayıt sayısı aynı yetkili RPC'de.

-- Parametre eklendiği için eski imza mutlaka düşürülür. Aksi halde PostgREST
-- iki `acc_ledger` sürümü görür ve HTTP 300 döndürür.
drop function if exists public.acc_ledger(uuid, date, date);

create or replace function public.acc_ledger(
  p_club      uuid,
  p_from      date default null,
  p_to        date default null,
  p_direction text default null,
  p_limit     int default 50,
  p_offset    int default 0
)
returns table (
  entry_id    uuid,
  moved_on    date,
  direction   text,
  label       text,
  category    text,
  counterpart text,
  account     text,
  amount      numeric,
  status      text,
  total_count bigint
)
language sql stable security definer set search_path = public as $$
  with allowed as (
    select public.is_club_staff(p_club) or public.is_club_accountant(p_club) as ok
  ),
  entries as (
    select e.id as entry_id, e.spent_on as moved_on, 'out'::text as direction,
           coalesce(e.note, c.name, 'Gider') as label,
           coalesce(c.name, '—') as category,
           coalesce(e.supplier, '—') as counterpart,
           coalesce(a.name, '—') as account, e.amount, e.status
      from public.expenses e
      left join public.expense_categories c on c.id = e.category_id
      left join public.cash_accounts a on a.id = e.account_id
     where e.club_id = p_club
       and (p_from is null or e.spent_on >= p_from)
       and (p_to is null or e.spent_on <= p_to)

    union all

    select p.id, p.paid_at, 'in'::text,
           coalesce(i.label, 'Ödeme'), 'Aidat', public.athlete_ref(p.athlete_id),
           coalesce(a.name, '—'), p.amount, p.status
      from public.payments p
      left join public.invoices i on i.id = p.invoice_id
      left join public.cash_accounts a on a.id = p.account_id
     where p.club_id = p_club
       and (p_from is null or p.paid_at >= p_from)
       and (p_to is null or p.paid_at <= p_to)

    union all

    select d.id, d.created_at::date, 'in'::text,
           coalesce(dc.title, 'Bağış'), 'Bağış',
           case when d.anonymous then 'Anonim' else coalesce(d.donor_name, '—') end,
           coalesce(a.name, '—'), d.amount, d.status
      from public.donations d
      left join public.donation_campaigns dc on dc.id = d.campaign_id
      left join public.cash_accounts a on a.id = d.account_id
     where d.club_id = p_club
       and (p_from is null or d.created_at::date >= p_from)
       and (p_to is null or d.created_at::date <= p_to)
  ),
  filtered as (
    select * from entries
     where p_direction is null or direction = p_direction
  )
  select entry_id, moved_on, direction, label, category, counterpart, account,
         amount, status, count(*) over()
    from filtered
   where (select ok from allowed)
   order by moved_on desc, entry_id desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- Özet görünür sayfadan değil, seçilen dönemin tamamından gelir. İptal ve
-- taslak satırlar önceki arayüz kuralıyla aynı biçimde toplamın dışında kalır.
create or replace function public.acc_ledger_totals(
  p_club      uuid,
  p_from      date default null,
  p_to        date default null,
  p_direction text default null
)
returns table (income numeric, outgo numeric, net numeric)
language sql stable security definer set search_path = public as $$
  with allowed as (
    select public.is_club_staff(p_club) or public.is_club_accountant(p_club) as ok
  ),
  entries as (
    select 'out'::text as direction, e.amount, e.status
      from public.expenses e
     where e.club_id = p_club
       and (p_from is null or e.spent_on >= p_from)
       and (p_to is null or e.spent_on <= p_to)
    union all
    select 'in'::text, p.amount, p.status
      from public.payments p
     where p.club_id = p_club
       and (p_from is null or p.paid_at >= p_from)
       and (p_to is null or p.paid_at <= p_to)
    union all
    select 'in'::text, d.amount, d.status
      from public.donations d
     where d.club_id = p_club
       and (p_from is null or d.created_at::date >= p_from)
       and (p_to is null or d.created_at::date <= p_to)
  ),
  totals as (
    select coalesce(sum(amount) filter (where direction = 'in'), 0)::numeric as income,
           coalesce(sum(amount) filter (where direction = 'out'), 0)::numeric as outgo
      from entries
     where (select ok from allowed)
       and status not in ('rejected', 'draft')
       and (p_direction is null or direction = p_direction)
  )
  select income, outgo, income - outgo from totals;
$$;

revoke execute on function public.acc_ledger(uuid, date, date, text, int, int)
  from public, anon;
revoke execute on function public.acc_ledger_totals(uuid, date, date, text)
  from public, anon;
grant execute on function public.acc_ledger(uuid, date, date, text, int, int)
  to authenticated;
grant execute on function public.acc_ledger_totals(uuid, date, date, text)
  to authenticated;
