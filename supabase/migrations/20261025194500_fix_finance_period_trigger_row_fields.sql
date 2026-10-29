-- A polymorphic trigger record cannot safely reference columns that are absent
-- from the current table, even inside an otherwise exclusive CASE branch.
create or replace function public.block_closed_period()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_row  jsonb;
  v_club uuid;
  v_date date;
begin
  v_row := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
  v_club := (v_row ->> 'club_id')::uuid;
  v_date := case tg_table_name
    when 'expenses'  then (v_row ->> 'spent_on')::date
    when 'payments'  then (v_row ->> 'paid_at')::date
    when 'donations' then (v_row ->> 'created_at')::timestamptz::date
    else null
  end;

  if v_date is null then
    raise exception 'Mali dönem tarihi çözülemedi: %', tg_table_name;
  end if;
  if public.is_period_closed(v_club, v_date) then
    raise exception
      'Bu tarih kapanmış bir mali döneme ait. Değişiklik için düzeltme kaydı (ters kayıt) oluşturun.'
      using errcode = 'check_violation';
  end if;

  if tg_op = 'UPDATE' then
    v_row := to_jsonb(old);
    v_date := case tg_table_name
      when 'expenses'  then (v_row ->> 'spent_on')::date
      when 'payments'  then (v_row ->> 'paid_at')::date
      when 'donations' then (v_row ->> 'created_at')::timestamptz::date
      else null
    end;
    if v_date is null then
      raise exception 'Mali dönem kaynak tarihi çözülemedi: %', tg_table_name;
    end if;
    if public.is_period_closed(v_club, v_date) then
      raise exception 'Kaynak kayıt kapanmış mali döneme ait'
        using errcode = 'check_violation';
    end if;
  end if;

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$fn$;

