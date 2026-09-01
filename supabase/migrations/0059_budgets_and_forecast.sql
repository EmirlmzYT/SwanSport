-- ---------------------------------------------------------------------------
-- 0059 — Bütçe, faaliyet maliyeti ve nakit tahmini
--
-- İKİ KURAL:
--
-- 1. GERÇEKLEŞEN ELLE GİRİLMİYOR. Bütçe ekranında "harcandı" alanı yok;
--    gerçekleşen `expenses`'ten hesaplanıyor. Elle giriş, defterle bütçenin
--    ayrışması demek ve hangisinin doğru olduğu hiçbir zaman bilinemez.
--
-- 2. TAHMİN KESİN BAKİYE GİBİ SUNULMUYOR. `cash_forecast` tek bir sayı
--    döndürmüyor; onaylı, beklenen ve belirsiz ayrı sütunlarda ve iki uçlu
--    bir aralık veriyor. Tek sayı, kulübün olmayan parayı var sanmasına
--    yol açar.
-- ---------------------------------------------------------------------------

create table if not exists public.budgets (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  period_from date not null,
  period_to   date not null,
  scope       text not null default 'club',
  -- `club` kapsamında null; takım/tesis/etkinlikte ilgili kimlik.
  scope_id    uuid,
  category_id uuid references public.expense_categories(id) on delete cascade,
  planned     numeric(12,2) not null default 0,
  note        text,
  owner_id    uuid references public.profiles(id) on delete set null,
  status      text not null default 'draft',
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);

do $blk$ begin
  alter table public.budgets
    add constraint budget_scope_check
    check (scope in ('club', 'team', 'facility', 'event'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.budgets
    add constraint budget_status_check
    check (status in ('draft', 'approved'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.budgets
    add constraint budget_period_check check (period_to >= period_from);
exception when duplicate_object then null; end $blk$;

-- `club` dışındaki kapsam kimliksiz olamaz; olursa "hangi takım" sorusunun
-- cevabı yok ve satır rapora hiç girmiyor.
do $blk$ begin
  alter table public.budgets
    add constraint budget_scope_needs_id
    check (scope = 'club' or scope_id is not null);
exception when duplicate_object then null; end $blk$;

-- Aynı dönem+kapsam+kategori için iki bütçe satırı, planlanan tutarı ikiye
-- böler. NULL'lar çakışmadığı için `coalesce` şart — bu tuzağa bu depoda
-- `athlete_achievements`'te bir kez düşüldü (0046).
create unique index if not exists idx_budget_unique
  on public.budgets (
    club_id, period_from, period_to, scope,
    coalesce(scope_id,    '00000000-0000-0000-0000-000000000000'::uuid),
    coalesce(category_id, '00000000-0000-0000-0000-000000000000'::uuid));

create index if not exists idx_budget_club_period
  on public.budgets (club_id, period_from, period_to);

alter table public.budgets enable row level security;

drop policy if exists "budget_read" on public.budgets;
create policy "budget_read" on public.budgets for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

drop policy if exists "budget_write" on public.budgets;
create policy "budget_write" on public.budgets for all
  to authenticated
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));

-- ---------------------------------------------------------------------------
-- BÜTÇE / GERÇEKLEŞEN
--
-- `committed`: henüz harcanmamış ama bağlanmış para — onay bekleyen giderler
-- ve vadesi gelmemiş taahhütler. Bunu "kalan"dan düşmemek, bütçeyi olduğundan
-- geniş gösterir.
--
-- Muhasebeci gizliliği: bu fonksiyon sporcu tablosuna hiç dokunmuyor.
-- ---------------------------------------------------------------------------
create or replace function public.budget_vs_actual(
  p_club uuid,
  p_from date default null,
  p_to   date default null)
returns table (
  budget_id     uuid,
  scope         text,
  scope_id      uuid,
  scope_label   text,
  category_id   uuid,
  category      text,
  period_from   date,
  period_to     date,
  planned       numeric,
  actual        numeric,
  committed     numeric,
  remaining     numeric,
  overrun_pct   numeric,
  risk          text)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if not (public.is_club_staff(p_club) or public.is_club_accountant(p_club)) then
    raise exception 'Bu kulübün bütçesini görme yetkiniz yok';
  end if;

  return query
  with b as (
    select * from public.budgets bg
     where bg.club_id = p_club
       and (p_from is null or bg.period_to   >= p_from)
       and (p_to   is null or bg.period_from <= p_to)
  ),
  act as (
    select b.id as bid,
           coalesce(sum(e.amount) filter (
             where e.status = 'complete'), 0) as spent,
           coalesce(sum(e.amount) filter (
             where e.approval_status = 'pending'), 0) as pending
      from b
      left join public.expenses e
        on e.club_id = p_club
       and e.spent_on between b.period_from and b.period_to
       and (b.category_id is null or e.category_id = b.category_id)
       and (b.scope = 'club'
            or (b.scope = 'team'     and e.team_id     = b.scope_id)
            or (b.scope = 'facility' and e.facility_id = b.scope_id)
            or (b.scope = 'event'    and e.event_id    = b.scope_id))
     group by b.id
  ),
  com as (
    -- Vadesi bu dönemde olan, henüz gidere dönüşmemiş taahhütler.
    select b.id as bid, coalesce(sum(o.amount), 0) as due
      from b
      left join public.recurring_occurrences o
        on o.club_id = p_club
       and o.status = 'pending'
       and o.due_on between b.period_from and b.period_to
     group by b.id
  )
  select b.id, b.scope, b.scope_id,
         case b.scope
           when 'team'     then (select t.name from public.teams t where t.id = b.scope_id)
           when 'facility' then (select f.name from public.facilities f where f.id = b.scope_id)
           when 'event'    then (select ev.title from public.events ev where ev.id = b.scope_id)
           else 'Kulüp geneli'
         end,
         b.category_id,
         coalesce((select c.name from public.expense_categories c
                    where c.id = b.category_id), 'Tüm kategoriler'),
         b.period_from, b.period_to,
         b.planned,
         coalesce(a.spent, 0),
         coalesce(a.pending, 0) + coalesce(cm.due, 0),
         b.planned - coalesce(a.spent, 0)
                   - coalesce(a.pending, 0) - coalesce(cm.due, 0),
         case when b.planned > 0
              then round(((coalesce(a.spent, 0) + coalesce(a.pending, 0)
                           + coalesce(cm.due, 0)) / b.planned) * 100, 1)
              else null end,
         case
           when b.planned <= 0 then 'bilgi'
           when (coalesce(a.spent, 0) + coalesce(a.pending, 0)
                 + coalesce(cm.due, 0)) > b.planned then 'kritik'
           when (coalesce(a.spent, 0) + coalesce(a.pending, 0)
                 + coalesce(cm.due, 0)) > b.planned * 0.85 then 'dikkat'
           else 'bilgi'
         end
    from b
    left join act a  on a.bid = b.id
    left join com cm on cm.bid = b.id
   -- Risk sırasını açık yazmak şart: `order by 14 desc` alfabetik olarak
   -- doğru sonucu veriyordu (kritik > dikkat > bilgi) ama bu tesadüf —
   -- etiketlerden biri değişince sıralama sessizce bozulurdu.
   order by case
              when b.planned <= 0 then 0
              when (coalesce(a.spent, 0) + coalesce(a.pending, 0)
                    + coalesce(cm.due, 0)) > b.planned then 2
              when (coalesce(a.spent, 0) + coalesce(a.pending, 0)
                    + coalesce(cm.due, 0)) > b.planned * 0.85 then 1
              else 0
            end desc,
            b.planned desc;
end;
$fn$;

revoke execute on function public.budget_vs_actual(uuid, date, date)
  from public, anon;
grant execute on function public.budget_vs_actual(uuid, date, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- NAKİT TAHMİNİ — 30 / 60 / 90 gün
--
-- Üç güven kademesi ayrı sütunda:
--
--   ONAYLI    bugünkü hesap bakiyesi + onaylanmış ama hesaba bağlanmamış
--             hareketler. Parası var, yeri belli.
--   BEKLENEN  vadesi pencerede olan ödenmemiş faturalar ve vadesi gelen
--             taahhütler. Olması beklenen ama gerçekleşmemiş.
--   BELİRSİZ  bütçelenmiş ama ne harcanmış ne taahhüt edilmiş tutar.
--
-- `projected_low` yalnızca onaylıyı, `projected_high` beklenenle birlikte
-- taşıyor. BELİRSİZ hiçbirine girmiyor — girseydi kulüp, planladığı ama
-- taahhüt etmediği harcamayı gerçek bir borç sanardı.
-- ---------------------------------------------------------------------------
create or replace function public.cash_forecast(p_club uuid)
returns table (
  horizon_days   int,
  opening        numeric,
  confirmed_in   numeric,
  confirmed_out  numeric,
  expected_in    numeric,
  expected_out   numeric,
  uncertain_out  numeric,
  projected_low  numeric,
  projected_high numeric)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_opening numeric := 0;
begin
  if not (public.is_club_staff(p_club) or public.is_club_accountant(p_club)) then
    raise exception 'Bu kulübün nakit tahminini görme yetkiniz yok';
  end if;

  -- Bakiye matematiği burada tekrarlanmıyor: `acc_account_balances` zaten
  -- doğru durumları süzüyor (gelirde `confirmed`, giderde `complete`).
  -- İkinci bir bakiye hesabı yazmak, ikisinin ayrışması demek.
  select coalesce(sum(b.balance), 0) into v_opening
    from public.acc_account_balances(p_club) b;

  return query
  -- Bileşenler bir kez hesaplanıyor. Aynı aritmetiği `projected_low` ve
  -- `projected_high` içinde tekrar yazmak, birini düzeltip diğerini
  -- unutmanın en kolay yoluydu.
  with h as (select unnest(array[30, 60, 90]) as days),
  parts as (
    select h.days,
           -- Onaylanmış ama hesaba bağlanmamış: para var, hangi kasada
           -- olduğu yazılmamış. Bakiyeye girmiyor ama gerçek.
           coalesce((select sum(p.amount) from public.payments p
                      where p.club_id = p_club and p.status = 'confirmed'
                        and p.account_id is null), 0)
           + coalesce((select sum(d.amount) from public.donations d
                        where d.club_id = p_club and d.status = 'confirmed'
                          and d.account_id is null), 0) as c_in,
           coalesce((select sum(e.amount) from public.expenses e
                      where e.club_id = p_club and e.status = 'complete'
                        and e.account_id is null), 0) as c_out,
           -- Vadesi pencerede olan ödenmemiş faturalar.
           coalesce((select sum(i.amount) from public.invoices i
                      where i.club_id = p_club and i.status <> 'paid'
                        and i.due_date is not null
                        and i.due_date <= current_date + h.days), 0) as e_in,
           -- Vadesi pencerede olan taahhütler.
           coalesce((select sum(o.amount) from public.recurring_occurrences o
                      where o.club_id = p_club and o.status = 'pending'
                        and o.due_on <= current_date + h.days), 0) as e_out,
           -- Bütçelenmiş ama ne harcanmış ne taahhüt edilmiş kısım.
           greatest(coalesce((
             select sum(v.remaining) from public.budget_vs_actual(
               p_club, current_date, current_date + h.days) v
              where v.remaining > 0), 0), 0) as u_out
      from h
  )
  select p.days, v_opening, p.c_in, p.c_out, p.e_in, p.e_out, p.u_out,
         v_opening + p.c_in - p.c_out,
         v_opening + p.c_in - p.c_out + p.e_in - p.e_out
    from parts p
   order by p.days;
end;
$fn$;

revoke execute on function public.cash_forecast(uuid) from public, anon;
grant execute on function public.cash_forecast(uuid) to authenticated;
