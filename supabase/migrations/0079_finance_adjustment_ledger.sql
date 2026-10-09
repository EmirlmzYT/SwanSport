-- =============================================================================
-- SwanSport — KAPANMIŞ DÖNEM TERS İŞLEM VE ÇİFT TARAFLI HAREKET
--
-- Onaylanan düzeltmeler cari döneme atomik olarak karşı hareket yazar:
--   - Gider iadesi / ters gider -> Gelir / Kasa Artışı (payments, confirmed)
--   - Hatalı tahsilat iadesi    -> Gider / Kasa Çıkışı (expenses, complete)
-- Hedef kayıt doğrulaması (target_id, target_kind) zorunlu tutulur.
-- Muhasebeci gizliliği korunur: sporcu kimliği veya adı sızdırılmaz.
-- =============================================================================

-- Düzeltme kaydı oluşturma — hedef seçimi ve tutar kontrolüyle
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
  v_id            uuid;
  v_period        uuid;
  v_target_amount numeric;
  v_tx_date       date;
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

  if p_target_id is null then
    raise exception 'Düzeltme yapılacak hedef işlem seçilmelidir';
  end if;

  if p_target_kind not in ('expense', 'payment', 'donation') then
    raise exception 'Geçersiz hedef türü: %', p_target_kind;
  end if;

  -- Hedef kaydın varlığı ve kulübe aidiyeti
  if p_target_kind = 'expense' then
    select amount, spent_on into v_target_amount, v_tx_date
      from public.expenses
     where id = p_target_id and club_id = p_club and status = 'complete';

    if v_target_amount is null then
      raise exception 'Hedef gider kaydı bulunamadı veya bu kulübe ait değil';
    end if;
  elsif p_target_kind = 'payment' then
    select amount, paid_at into v_target_amount, v_tx_date
      from public.payments
     where id = p_target_id and club_id = p_club and status = 'confirmed';

    if v_target_amount is null then
      raise exception 'Hedef tahsilat kaydı bulunamadı veya bu kulübe ait değil';
    end if;
  elsif p_target_kind = 'donation' then
    select amount, created_at::date into v_target_amount, v_tx_date
      from public.donations
     where id = p_target_id and club_id = p_club and status = 'confirmed';

    if v_target_amount is null then
      raise exception 'Hedef bağış kaydı bulunamadı veya bu kulübe ait değil';
    end if;
  end if;

  -- Tutar asıl işlem tutarından büyük olamaz
  if abs(p_amount) > v_target_amount then
    raise exception 'Düzeltme tutarı (%) asıl işlem tutarından (%) büyük olamaz', abs(p_amount), v_target_amount;
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


-- Onaylama — atomik karşı hareket (defter hareketi) yazma ve idempotent kontrol
create or replace function public.approve_finance_adjustment(
  p_id uuid, p_approve boolean, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_a          public.finance_adjustments%rowtype;
  v_account_id uuid;
  v_cat_id     uuid;
  v_entry_id   uuid;
  v_entry_kind text;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  -- Satır düzeyinde kilit ile eşzamanlı çift onay engeli
  select * into v_a from public.finance_adjustments where id = p_id for update;
  if v_a.id is null then
    raise exception 'Düzeltme kaydı bulunamadı';
  end if;

  if not public.is_club_staff(v_a.club_id) then
    raise exception 'Düzeltmeyi yalnızca kulüp yöneticisi onaylayabilir';
  end if;

  -- İdempotent kontrol
  if v_a.status <> 'pending' then
    if (p_approve and v_a.status = 'approved') or (not p_approve and v_a.status = 'rejected') then
      return;
    end if;
    raise exception 'Bu düzeltme zaten sonuçlanmış (durum: %)', v_a.status;
  end if;

  if v_a.created_by = auth.uid() then
    raise exception 'Kendi açtığınız düzeltmeyi siz onaylayamazsınız';
  end if;

  if not p_approve then
    update public.finance_adjustments
       set status = 'rejected', approved_by = auth.uid(), approved_at = now()
     where id = p_id;

    insert into public.finance_period_logs (period_id, club_id, actor_id, action, note)
    values (v_a.period_id, v_a.club_id, auth.uid(), 'adjustment_rejected', coalesce(p_note, v_a.reason));

    return;
  end if;

  -- Onay durumunda kasa hesabını hedef işlemden türet
  if v_a.target_kind = 'expense' then
    select account_id into v_account_id from public.expenses where id = v_a.target_id;
  elsif v_a.target_kind = 'payment' then
    select account_id into v_account_id from public.payments where id = v_a.target_id;
  elsif v_a.target_kind = 'donation' then
    select account_id into v_account_id from public.donations where id = v_a.target_id;
  end if;

  if v_account_id is null then
    select id into v_account_id from public.cash_accounts
     where club_id = v_a.club_id and active
     order by created_at limit 1;
  end if;

  -- Yön ve karşı defter kaydı:
  -- Gider iadesi (target_kind = 'expense'): Para kulübe iade edilir -> Kasa artışı / Gelir (payments)
  -- Hatalı tahsilat iadesi (target_kind in ('payment', 'donation')): Kulüpten para çıkar -> Kasa çıkışı / Gider (expenses)
  if v_a.target_kind = 'expense' then
    insert into public.payments (
      club_id, account_id, amount, method, status, paid_at, note, athlete_id
    ) values (
      v_a.club_id, v_account_id, abs(v_a.amount), 'diger', 'confirmed', current_date,
      'Ters kayıt (Gider mahsubu #' || substr(v_a.id::text, 1, 8) || '): ' || v_a.reason,
      null
    ) returning id into v_entry_id;

    v_entry_kind := 'payment';
  else
    -- payment veya donation iadesi -> expenses kaydı
    select id into v_cat_id from public.expense_categories
     where (club_id = v_a.club_id or club_id is null)
     order by case when name = 'Diğer' then 1 else 2 end, sort limit 1;

    insert into public.expenses (
      club_id, category_id, account_id, amount, spent_on, note, status, entered_by
    ) values (
      v_a.club_id, v_cat_id, v_account_id, abs(v_a.amount), current_date,
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

