-- =============================================================================
-- 0084 — Mali Düzeltme İnceleme Görünümü Güvenliği, Kilit Sırası ve Güvenli Telafi
--
-- 1) v_finance_adjustment_reconciliation_issues görünümüne security_invoker ve
--    kulüp yetki filtresi (kulüpler arası veri sızıntısını önler).
-- 2) get_finance_adjustment_reconciliation_issues(p_club_id) yetki kontrollü RPC.
-- 3) approve_finance_adjustment: pozitif tutar kontrolü (amount > 0),
--    tutarlı kilit sırası (hedef -> düzeltme), ve negatif eski kayıtların
--    iade kapasitesini artırmasını önleyen sum(case when amount > 0 then amount else 0 end).
-- 4) acc_closed_period_candidates: negatif kayıtların kapasiteyi şişirmemesi
--    ve tr_contains ile Türkçe arama uyumu.
-- 5) Geçmiş telafi otomatik çalışmaz; eksik/belirsiz defter hareketi incelemeye kalır.
-- =============================================================================

set local lock_timeout = '15s';

-- ---------------------------------------------------------------------------
-- 1) v_finance_adjustment_reconciliation_issues Görünümü (RLS & Kulüp İzolasyonu)
-- ---------------------------------------------------------------------------
drop view if exists public.v_finance_adjustment_reconciliation_issues cascade;

create view public.v_finance_adjustment_reconciliation_issues
with (security_invoker = true) as
select a.id as adjustment_id,
       a.club_id,
       a.period_id,
       a.target_kind,
       a.target_id,
       a.amount,
       a.status,
       a.entry_kind,
       a.entry_id,
       a.created_at,
       case
         when a.amount <= 0 then 'Geçersiz Tutar'
         when a.status = 'approved' and a.entry_id is null then 'Eksik Defter Hareketi'
         when a.target_id is null then 'Hedef Kayıt Yok'
         else 'İnceleme Gerekli'
       end as issue_reason
  from public.finance_adjustments a
 where (
   public.is_platform_admin()
   or public.is_club_staff(a.club_id)
   or public.is_club_accountant(a.club_id)
 )
 and (
   (a.status = 'approved' and a.entry_id is null)
   or (a.amount <= 0)
 );

revoke all on public.v_finance_adjustment_reconciliation_issues from public, anon;
grant select on public.v_finance_adjustment_reconciliation_issues to authenticated;

-- ---------------------------------------------------------------------------
-- 2) get_finance_adjustment_reconciliation_issues RPC (Yetki Denetimli)
-- ---------------------------------------------------------------------------
create or replace function public.get_finance_adjustment_reconciliation_issues(
  p_club_id uuid
)
returns table (
  adjustment_id uuid,
  club_id       uuid,
  period_id     uuid,
  target_kind   text,
  target_id     uuid,
  amount        numeric,
  status        text,
  entry_kind    text,
  entry_id      uuid,
  created_at    timestamptz,
  issue_reason  text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not (
    public.is_platform_admin()
    or public.is_club_staff(p_club_id)
    or public.is_club_accountant(p_club_id)
  ) then
    raise exception 'Yetkisiz erişim: Bu kulübün mali inceleme kayıtlarını görüntüleme yetkiniz yok';
  end if;

  return query
  select v.adjustment_id,
         v.club_id,
         v.period_id,
         v.target_kind,
         v.target_id,
         v.amount,
         v.status,
         v.entry_kind,
         v.entry_id,
         v.created_at,
         v.issue_reason
    from public.v_finance_adjustment_reconciliation_issues v
   where v.club_id = p_club_id
   union all
   select a.id, a.club_id, a.period_id, a.target_kind, a.target_id, a.amount,
          a.status, a.entry_kind, a.entry_id, a.created_at, 'Defter Hareketi Eşleşmiyor'::text
     from public.finance_adjustments a
    where a.club_id = p_club_id and a.status = 'approved' and a.entry_id is not null
      and a.amount > 0
      and not public.finance_adjustment_entry_matches(a,
        case a.target_kind
          when 'expense' then (select e.account_id from public.expenses e where e.id=a.target_id and e.club_id=a.club_id)
          when 'payment' then (select e.account_id from public.payments e where e.id=a.target_id and e.club_id=a.club_id)
          when 'donation' then (select e.account_id from public.donations e where e.id=a.target_id and e.club_id=a.club_id)
        end)
   order by 10 desc;
end;
$$;

revoke execute on function public.get_finance_adjustment_reconciliation_issues(uuid) from public, anon;
grant execute on function public.get_finance_adjustment_reconciliation_issues(uuid) to authenticated;


-- ---------------------------------------------------------------------------
-- 3) approve_finance_adjustment Güncellemesi
-- ---------------------------------------------------------------------------
-- Internal validation: status alone is not evidence of a ledger movement.
create or replace function public.finance_adjustment_entry_matches(
  p_adjustment public.finance_adjustments, p_account uuid
)
returns boolean language sql stable set search_path = public as $fn$
  select coalesce((p_adjustment.amount > 0
    and p_adjustment.amount::text not in ('NaN', 'Infinity', '-Infinity')
    and p_account is not null
    and (select coalesce(sum(greatest(a.amount, 0)), 0)
           from public.finance_adjustments a
          where a.club_id = p_adjustment.club_id and a.target_kind = p_adjustment.target_kind
            and a.target_id = p_adjustment.target_id and a.status = 'approved')
        <= case p_adjustment.target_kind
          when 'expense' then (select amount from public.expenses where id = p_adjustment.target_id and club_id = p_adjustment.club_id)
          when 'payment' then (select amount from public.payments where id = p_adjustment.target_id and club_id = p_adjustment.club_id)
          when 'donation' then (select amount from public.donations where id = p_adjustment.target_id and club_id = p_adjustment.club_id)
        end
    and not exists (
      select 1 from public.finance_adjustments other
       where other.id <> p_adjustment.id and other.entry_id = p_adjustment.entry_id
         and other.entry_kind = p_adjustment.entry_kind
    )
    and case
      when p_adjustment.target_kind = 'expense' and p_adjustment.entry_kind = 'payment' then
        exists (select 1 from public.payments e
          where e.id = p_adjustment.entry_id and e.club_id = p_adjustment.club_id
            and e.account_id = p_account and e.status = 'confirmed'
            and e.amount = p_adjustment.amount)
      when p_adjustment.target_kind in ('payment', 'donation') and p_adjustment.entry_kind = 'expense' then
        exists (select 1 from public.expenses e
          where e.id = p_adjustment.entry_id and e.club_id = p_adjustment.club_id
            and e.account_id = p_account and e.status = 'complete'
            and e.amount = p_adjustment.amount)
      else false
    end), false);
$fn$;
revoke all on function public.finance_adjustment_entry_matches(public.finance_adjustments, uuid)
  from public, anon, authenticated;

drop function if exists public.approve_finance_adjustment(uuid, boolean);
drop function if exists public.approve_finance_adjustment(uuid, boolean, text);

create or replace function public.approve_finance_adjustment(
  p_id      uuid,
  p_approve boolean,
  p_note    text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_a                public.finance_adjustments%rowtype;
  v_initial          public.finance_adjustments%rowtype;
  v_account_id       uuid;
  v_cat_id           uuid;
  v_entry_id         uuid;
  v_entry_kind       text;
  v_target_amount    numeric;
  v_tx_date          date;
  v_already_approved numeric;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if p_approve is null then
    raise exception 'Onay kararı zorunlu';
  end if;
  -- İlk okuma yalnızca kilitlenecek kaynağı belirler. Kilitten sonra yeniden oku.
  select * into v_initial from public.finance_adjustments where id = p_id;
  if not found then raise exception 'Düzeltme kaydı bulunamadı'; end if;
  if not coalesce(public.is_club_staff(v_initial.club_id), false) then
    raise exception 'Düzeltmeyi yalnızca kulüp personeli onaylayabilir';
  end if;

  -- Bütün yazma yolları: kaynak -> düzeltme. Reddetme kaynak kilidi gerektirmez.
  if p_approve then
    if v_initial.target_kind = 'expense' then
      select amount, spent_on, account_id into v_target_amount, v_tx_date, v_account_id
        from public.expenses
       where id = v_initial.target_id and club_id = v_initial.club_id and status = 'complete'
         for update;

      if v_target_amount is null then
        raise exception 'Hedef gider kaydı bulunamadı veya geçerli durumda değil';
      end if;
    elsif v_initial.target_kind = 'payment' then
      select amount, paid_at, account_id into v_target_amount, v_tx_date, v_account_id
        from public.payments
       where id = v_initial.target_id and club_id = v_initial.club_id and status = 'confirmed'
         for update;

      if v_target_amount is null then
        raise exception 'Hedef tahsilat kaydı bulunamadı veya geçerli durumda değil';
      end if;
    elsif v_initial.target_kind = 'donation' then
      select amount, created_at::date, account_id into v_target_amount, v_tx_date, v_account_id
        from public.donations
       where id = v_initial.target_id and club_id = v_initial.club_id and status = 'confirmed'
         for update;

      if v_target_amount is null then
        raise exception 'Hedef bağış kaydı bulunamadı veya geçerli durumda değil';
      end if;
    else
      raise exception 'Desteklenmeyen hedef işlem türü: %', v_initial.target_kind;
    end if;

  end if;
  select * into v_a from public.finance_adjustments where id = p_id for update;
  if not found then raise exception 'Düzeltme kaydı bulunamadı'; end if;
  if v_a.club_id is distinct from v_initial.club_id
     or v_a.target_kind is distinct from v_initial.target_kind
     or v_a.target_id is distinct from v_initial.target_id then
    raise exception 'Düzeltme değişti; yeniden deneyin';
  end if;
  if v_a.created_by = auth.uid() then
    raise exception 'Kendi açtığınız düzeltmeyi siz onaylayamazsınız';
  end if;
  if v_a.status <> 'pending' then
    if p_approve and v_a.status = 'approved' then
      if not public.finance_adjustment_entry_matches(v_a, v_account_id) then
        raise exception 'Onaylı kayıt mali inceleme gerektiriyor';
      end if;
      return;
    end if;
    if not p_approve and v_a.status = 'rejected' then return; end if;
    raise exception 'Bu düzeltme zaten sonuçlanmış (durum: %)', v_a.status;
  end if;
  if not p_approve then
    update public.finance_adjustments
       set status = 'rejected', approved_by = auth.uid(), approved_at = now()
     where id = p_id;
    insert into public.finance_period_logs (period_id, club_id, actor_id, action, note)
    values (v_a.period_id, v_a.club_id, auth.uid(), 'adjustment_rejected', coalesce(p_note, v_a.reason));
    return;
  end if;
  if v_a.amount <= 0 or v_a.amount::text in ('NaN', 'Infinity', '-Infinity')
     or v_target_amount <= 0 or v_target_amount::text in ('NaN', 'Infinity', '-Infinity') then
    raise exception 'Düzeltme ve kaynak tutarı pozitif ve sonlu olmalıdır';
  end if;
  if exists (select 1 from public.finance_adjustments
    where club_id = v_a.club_id and target_kind = v_a.target_kind and target_id = v_a.target_id
      and id <> v_a.id and status in ('approved', 'pending')
      and (amount <= 0 or amount::text in ('NaN', 'Infinity', '-Infinity')
           or (status = 'approved' and not public.finance_adjustment_entry_matches(finance_adjustments, v_account_id)))) then
    raise exception 'Bu kaynağın geçmiş düzeltmeleri mali inceleme gerektiriyor';
  end if;

  -- Kaynak işlemin kapanmış döneme ait olduğunu doğrula
  if not public.is_period_closed(v_a.club_id, v_tx_date) then
    raise exception 'Kaynak işlem kapanmış bir döneme ait değil';
  end if;

  -- Kasa hesabı kontrolü: Asla rastgele ilk kasaya yazılmaz!
  if v_account_id is null or not exists (
    select 1 from public.cash_accounts where id = v_account_id and club_id = v_a.club_id and active
  ) then
    raise exception 'Kaynak hareketin kasa hesabı bulunamadı veya pasif durumda';
  end if;

  -- Eşzamanlı onaylarda toplam iade tutarının aşılmadığını yeniden doğrula
  select coalesce(sum(greatest(amount, 0)), 0) into v_already_approved
    from public.finance_adjustments
   where club_id = v_a.club_id and target_kind = v_a.target_kind
     and target_id = v_a.target_id and status in ('approved', 'pending') and id <> v_a.id;

  if v_a.amount > (v_target_amount - v_already_approved) then
    raise exception 'Bu kaynak işlem için toplam iade tutarı aşılamaz. Kalan: %, İstenen: %',
      (v_target_amount - v_already_approved), v_a.amount;
  end if;

  -- Cari dönemin kapalı olmadığını doğrula
  if public.is_period_closed(v_a.club_id, current_date) then
    raise exception 'Cari dönem kapalı olduğundan cari döneme ters kayıt yazılamaz';
  end if;

  -- 3) Karşı hareket oluşturma:
  -- Gider iadesi (target_kind = 'expense'): Para kulübe geri döner -> Kasa girişi / payments
  -- Muhasebeci gizliliği: athlete_id = null
  if v_a.target_kind = 'expense' then
    insert into public.payments (
      club_id, account_id, amount, method, status, paid_at, note, athlete_id
    ) values (
      v_a.club_id, v_account_id, v_a.amount, 'diger', 'confirmed', current_date,
      'Ters kayıt (Gider mahsubu #' || substr(v_a.id::text, 1, 8) || '): ' || v_a.reason,
      null
    ) returning id into v_entry_id;

    v_entry_kind := 'payment';
  else
    -- Hatalı tahsilat veya bağış iadesi -> Kasa çıkışı / expenses
    select id into v_cat_id from public.expense_categories
     where (club_id = v_a.club_id or club_id is null)
     order by case when name = 'Diğer' then 1 else 2 end, sort limit 1;

    insert into public.expenses (
      club_id, category_id, account_id, amount, spent_on, note, status, entered_by
    ) values (
      v_a.club_id, v_cat_id, v_account_id, v_a.amount, current_date,
      'Ters kayıt (Tahsilat iadesi #' || substr(v_a.id::text, 1, 8) || '): ' || v_a.reason,
      'complete', auth.uid()
    ) returning id into v_entry_id;

    v_entry_kind := 'expense';
  end if;

  update public.finance_adjustments
     set status = 'approved',
         approved_by = auth.uid(),
         approved_at = now(),
         entry_kind = v_entry_kind,
         entry_id = v_entry_id
   where id = p_id;

  insert into public.finance_period_logs (period_id, club_id, actor_id, action, note)
  values (v_a.period_id, v_a.club_id, auth.uid(), 'adjustment_approved', coalesce(p_note, v_a.reason));
end;
$fn$;

revoke execute on function public.approve_finance_adjustment(uuid, boolean, text)
  from public, anon;
grant execute on function public.approve_finance_adjustment(uuid, boolean, text)
  to authenticated;



-- ---------------------------------------------------------------------------
-- 4) acc_closed_period_candidates (Türkçe arama ve negatif kayıt güvenliği)
-- ---------------------------------------------------------------------------
drop function if exists public.acc_closed_period_candidates(uuid, text, text, int, int);

create or replace function public.acc_closed_period_candidates(
  p_club        uuid,
  p_target_kind text default null,
  p_search      text default null,
  p_limit       int default 50,
  p_offset      int default 0
)
returns table (
  entry_id         uuid,
  target_kind      text,
  moved_on         date,
  amount           numeric,
  label            text,
  counterpart      text,
  account_id       uuid,
  account_name     text,
  already_reversed numeric,
  remaining_amount numeric,
  total_count      bigint
)
language sql
stable
security definer
set search_path = public
as $$
  with allowed as (
    select public.is_platform_admin() or public.is_club_staff(p_club) or public.is_club_accountant(p_club) as ok
  ),
  closed_periods as (
    select period_from, period_to
      from public.finance_periods
     where club_id = p_club and status = 'closed'
  ),
  adjustments_summary as (
    select target_id, target_kind,
           coalesce(sum(case when amount > 0 then amount else 0 end), 0) as sum_adj,
           bool_or(amount <= 0 or amount::text in ('NaN', 'Infinity', '-Infinity')
             or (status = 'approved' and not public.finance_adjustment_entry_matches(finance_adjustments, case finance_adjustments.target_kind
               when 'expense' then (select account_id from public.expenses where id = finance_adjustments.target_id and club_id = finance_adjustments.club_id)
               when 'payment' then (select account_id from public.payments where id = finance_adjustments.target_id and club_id = finance_adjustments.club_id)
               when 'donation' then (select account_id from public.donations where id = finance_adjustments.target_id and club_id = finance_adjustments.club_id)
             end))) as needs_review
      from public.finance_adjustments
     where club_id = p_club and status in ('approved', 'pending')
     group by target_id, target_kind
  ),
  candidates as (
    -- Giderler
    select e.id as entry_id,
           'expense'::text as target_kind,
           e.spent_on as moved_on,
           e.amount,
           coalesce(e.note, c.name, 'Gider') as label,
           coalesce(e.supplier, '—') as counterpart,
           e.account_id,
           coalesce(a.name, '—') as account_name,
           coalesce(adj.sum_adj, 0) as already_reversed,
           (e.amount - coalesce(adj.sum_adj, 0)) as remaining_amount
      from public.expenses e
      join closed_periods cp on (e.spent_on between cp.period_from and cp.period_to)
      left join public.expense_categories c on c.id = e.category_id
      left join public.cash_accounts a on a.id = e.account_id
      left join adjustments_summary adj on adj.target_id = e.id and adj.target_kind = 'expense'
     where e.club_id = p_club
       and not coalesce(adj.needs_review, false)
       and e.amount::text not in ('NaN', 'Infinity', '-Infinity')
       and e.status = 'complete'
       and (e.amount - coalesce(adj.sum_adj, 0)) > 0

    union all

    -- Tahsilatlar / Aidatlar (Muhasebeci gizliliği: athlete_ref)
    select p.id as entry_id,
           'payment'::text as target_kind,
           p.paid_at as moved_on,
           p.amount,
           coalesce(i.label, 'Tahsilat') as label,
           public.athlete_ref(p.athlete_id) as counterpart,
           p.account_id,
           coalesce(a.name, '—') as account_name,
           coalesce(adj.sum_adj, 0) as already_reversed,
           (p.amount - coalesce(adj.sum_adj, 0)) as remaining_amount
      from public.payments p
      join closed_periods cp on (p.paid_at between cp.period_from and cp.period_to)
      left join public.invoices i on i.id = p.invoice_id
      left join public.cash_accounts a on a.id = p.account_id
      left join adjustments_summary adj on adj.target_id = p.id and adj.target_kind = 'payment'
     where p.club_id = p_club
       and not coalesce(adj.needs_review, false)
       and p.amount::text not in ('NaN', 'Infinity', '-Infinity')
       and p.status = 'confirmed'
       and (p.amount - coalesce(adj.sum_adj, 0)) > 0

    union all

    -- Bağışlar
    select d.id as entry_id,
           'donation'::text as target_kind,
           d.created_at::date as moved_on,
           d.amount,
           coalesce(dc.title, 'Bağış') as label,
           case when d.anonymous then 'Anonim' else coalesce(d.donor_name, '—') end as counterpart,
           d.account_id,
           coalesce(a.name, '—') as account_name,
           coalesce(adj.sum_adj, 0) as already_reversed,
           (d.amount - coalesce(adj.sum_adj, 0)) as remaining_amount
      from public.donations d
      join closed_periods cp on (d.created_at::date between cp.period_from and cp.period_to)
      left join public.donation_campaigns dc on dc.id = d.campaign_id
      left join public.cash_accounts a on a.id = d.account_id
      left join adjustments_summary adj on adj.target_id = d.id and adj.target_kind = 'donation'
     where d.club_id = p_club
       and not coalesce(adj.needs_review, false)
       and d.amount::text not in ('NaN', 'Infinity', '-Infinity')
       and d.status = 'confirmed'
       and (d.amount - coalesce(adj.sum_adj, 0)) > 0
  ),
  filtered as (
    select c.*
      from candidates c
     where (p_target_kind is null or c.target_kind = p_target_kind)
       and (
         p_search is null
         or trim(p_search) = ''
         or public.tr_contains(c.label, p_search)
         or public.tr_contains(c.counterpart, p_search)
         or public.tr_contains(c.account_name, p_search)
       )
  )
  select f.entry_id,
         f.target_kind,
         f.moved_on,
         f.amount,
         f.label,
         f.counterpart,
         f.account_id,
         f.account_name,
         f.already_reversed,
         f.remaining_amount,
         count(*) over() as total_count
    from filtered f
   where (select ok from allowed)
   order by f.moved_on desc, f.entry_id desc
   limit least(greatest(coalesce(p_limit, 50), 1), 200)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke execute on function public.acc_closed_period_candidates(uuid, text, text, int, int) from public, anon;
grant execute on function public.acc_closed_period_candidates(uuid, text, text, int, int) to authenticated;


-- Otomatik telafi yok: geçmiş kaydın onayı, paranın gerçekleştiğini kanıtlamaz.
-- Eksik/negatif kayıtlar inceleme görünümünde kalır; migration deftere yazmaz.

