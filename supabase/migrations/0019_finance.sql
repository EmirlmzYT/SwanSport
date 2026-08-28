-- =============================================================================
-- SwanSport — AİDAT, TAHSİLAT VE BAĞIŞ
--   1) Aidat planları ve sporcuya atama (kişiye özel tutar / burs dahil)
--   2) Aylık borç tahakkuku (tekrar çalıştırılabilir, çift yazmaz)
--   3) Ödeme bildirimi (veli "ödedim" der) → kulüp onayı
--   4) Bağış kampanyaları
--   5) Gizlilik düzeltmesi: fatura yalnızca ilgilisine görünür
--
-- Supabase SQL editöründe BİR KEZ çalıştır. Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 0) KULÜP BANKA BİLGİSİ
--
-- Havaleyle tahsilat yapılacağı için IBAN bir yerde durmalı; veli ödeme
-- ekranında bunu görüp havale yapacak.
-- ---------------------------------------------------------------------------
alter table public.clubs
  add column if not exists iban           text,
  add column if not exists bank_name      text,
  add column if not exists account_holder text;


-- Bu sporcunun mali kaydını kim görebilir?
-- Kulüp görevlisi, sporcunun kendisi ve velisi. Kulübün diğer üyeleri HAYIR.
create or replace function public.can_view_athlete_fees(p_athlete uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.athletes a
     where a.id = p_athlete
       and (a.profile_id = auth.uid() or public.is_guardian_of(a.id))
  );
$$;




-- ---------------------------------------------------------------------------
-- 1) AİDAT PLANLARI
-- ---------------------------------------------------------------------------
create table if not exists public.fee_plans (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs(id) on delete cascade,
  name       text not null,                       -- "Altyapı — aylık"
  amount     numeric(12,2) not null default 0,
  -- Şimdilik yalnızca aylık; alan ileride 'quarterly' vb. için duruyor.
  period_kind text not null default 'monthly',
  due_day    int not null default 10,             -- ayın kaçında son ödeme
  active     boolean not null default true,
  created_at timestamptz not null default now()
);
create index if not exists idx_fee_plan_club on public.fee_plans (club_id, active);

alter table public.fee_plans enable row level security;

drop policy if exists "fee_plan_read" on public.fee_plans;
create policy "fee_plan_read" on public.fee_plans for select
  to authenticated using (public.is_club_member(club_id));

drop policy if exists "fee_plan_write" on public.fee_plans;
create policy "fee_plan_write" on public.fee_plans for all
  to authenticated
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));


-- Sporcunun aidat ataması. custom_amount doluysa plandaki tutar yerine o
-- kullanılır — kardeş indirimi, burslu sporcu, yarım dönem gibi durumlar için.
create table if not exists public.athlete_fees (
  athlete_id    uuid primary key references public.athletes(id) on delete cascade,
  club_id       uuid not null references public.clubs(id) on delete cascade,
  plan_id       uuid references public.fee_plans(id) on delete set null,
  custom_amount numeric(12,2),
  note          text,                     -- "burslu", "kardeş indirimi %50"
  active        boolean not null default true,
  updated_at    timestamptz not null default now()
);
create index if not exists idx_athlete_fee_club
  on public.athlete_fees (club_id, active);

alter table public.athlete_fees enable row level security;

drop policy if exists "athlete_fee_read" on public.athlete_fees;
create policy "athlete_fee_read" on public.athlete_fees for select
  to authenticated
  using (public.is_club_staff(club_id) or public.can_view_athlete_fees(athlete_id));

drop policy if exists "athlete_fee_write" on public.athlete_fees;
create policy "athlete_fee_write" on public.athlete_fees for all
  to authenticated
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));


-- ---------------------------------------------------------------------------
-- 2) FATURA (mevcut invoices tablosu genişletiliyor)
-- ---------------------------------------------------------------------------
alter table public.invoices
  add column if not exists plan_id  uuid references public.fee_plans(id) on delete set null,
  add column if not exists due_date date,
  -- 'aidat' otomatik tahakkuk, 'ekstra' tek seferlik (malzeme, turnuva…)
  add column if not exists kind     text not null default 'ekstra',
  add column if not exists note     text;

-- Aynı sporcuya aynı dönem için ikinci aidat faturası kesilmesin.
create unique index if not exists idx_invoice_period
  on public.invoices (athlete_id, period, plan_id)
  where kind = 'aidat' and athlete_id is not null;


-- GİZLİLİK DÜZELTMESİ
-- Eski kural "kulübün her üyesi tüm faturaları okur" diyordu; bir veli
-- diğer sporcuların borcunu görebiliyordu. Artık yalnızca ilgilisi görüyor.
drop policy if exists "invoices_read" on public.invoices;
create policy "invoices_read" on public.invoices for select
  to authenticated
  using (
    public.is_club_staff(club_id)
    or (athlete_id is not null and public.can_view_athlete_fees(athlete_id))
  );


-- ---------------------------------------------------------------------------
-- 3) AYLIK TAHAKKUK
--
-- Belirtilen dönem için (YYYY-MM) aidatı olan her sporcuya fatura üretir.
-- Tekrar çalıştırılabilir: benzersiz indeks sayesinde ikinci kez borç yazmaz.
-- ---------------------------------------------------------------------------
create or replace function public.generate_fee_charges(
  p_club uuid, p_period text default to_char(now(), 'YYYY-MM'))
returns int language plpgsql security definer set search_path = public as $$
declare
  v_count int := 0;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Yetkisiz';
  end if;

  with created as (
    insert into public.invoices
      (club_id, athlete_id, plan_id, label, amount, status, period, due_date, kind)
    select
      af.club_id,
      af.athlete_id,
      af.plan_id,
      fp.name || ' · ' || p_period,
      coalesce(af.custom_amount, fp.amount),
      'pending'::public.invoice_status,
      p_period,
      -- Dönemin ayı + planın son ödeme günü
      (to_date(p_period || '-01', 'YYYY-MM-DD')
        + (least(greatest(fp.due_day, 1), 28) - 1) * interval '1 day')::date,
      'aidat'
    from public.athlete_fees af
    join public.fee_plans fp on fp.id = af.plan_id
    where af.club_id = p_club
      and af.active
      and fp.active
      -- Ücretsiz sporcuya (burslu, tutar 0) borç yazma.
      and coalesce(af.custom_amount, fp.amount) > 0
    on conflict do nothing
    returning 1
  )
  select count(*) into v_count from created;

  return v_count;
end; $$;


-- Tek seferlik borç (malzeme, turnuva katılım ücreti…)
create or replace function public.add_extra_charge(
  p_club uuid, p_athlete uuid, p_label text, p_amount numeric,
  p_due date default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid;
begin
  if not public.is_club_staff(p_club) then raise exception 'Yetkisiz'; end if;

  insert into public.invoices
    (club_id, athlete_id, label, amount, status, period, due_date, kind)
  values (p_club, p_athlete, p_label, p_amount, 'pending',
          to_char(now(), 'YYYY-MM'), p_due, 'ekstra')
  returning id into v_id;

  return v_id;
end; $$;


-- ---------------------------------------------------------------------------
-- 4) ÖDEMELER
--
-- Veli havale yapıp "ödedim" der (durum: bekliyor). Kulüp dekontu görüp
-- onaylar; onaylandığı anda fatura kapanır. Kulüp nakit tahsilatı doğrudan
-- onaylı olarak da girebilir.
-- ---------------------------------------------------------------------------
create table if not exists public.payments (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id) on delete cascade,
  invoice_id   uuid references public.invoices(id) on delete set null,
  athlete_id   uuid references public.athletes(id) on delete set null,
  amount       numeric(12,2) not null,
  method       text not null default 'havale',   -- havale | nakit | kart | diger
  status       text not null default 'pending',  -- pending | confirmed | rejected
  paid_at      date not null default current_date,
  note         text,
  receipt_path text,                             -- dekont görseli
  declared_by  uuid references public.profiles(id) on delete set null,
  confirmed_by uuid references public.profiles(id) on delete set null,
  confirmed_at timestamptz,
  created_at   timestamptz not null default now()
);
create index if not exists idx_payment_club
  on public.payments (club_id, status, created_at desc);

alter table public.payments enable row level security;

drop policy if exists "payment_read" on public.payments;
create policy "payment_read" on public.payments for select
  to authenticated
  using (
    public.is_club_staff(club_id)
    or declared_by = auth.uid()
    or (athlete_id is not null and public.can_view_athlete_fees(athlete_id))
  );

-- Yazma yalnızca RPC üzerinden.


-- Veli/sporcu ödeme bildirir.
create or replace function public.declare_payment(
  p_invoice uuid,
  p_amount  numeric default null,
  p_method  text default 'havale',
  p_paid_at date default current_date,
  p_note    text default null,
  p_receipt text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_inv record;
  v_id  uuid;
begin
  select * into v_inv from public.invoices where id = p_invoice;
  if v_inv is null then raise exception 'Fatura bulunamadı'; end if;

  if not (public.can_view_athlete_fees(v_inv.athlete_id)
          or public.is_club_staff(v_inv.club_id)) then
    raise exception 'Yetkisiz';
  end if;

  insert into public.payments
    (club_id, invoice_id, athlete_id, amount, method, paid_at, note,
     receipt_path, declared_by, status)
  values (v_inv.club_id, p_invoice, v_inv.athlete_id,
          coalesce(p_amount, v_inv.amount), p_method, p_paid_at, p_note,
          p_receipt, auth.uid(), 'pending')
  returning id into v_id;

  -- Kulübe haber ver: onay bekleyen tahsilat var.
  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  select m.profile_id, 'payment',
         'Ödeme bildirimi',
         v_inv.label || ' · ' || coalesce(p_amount, v_inv.amount)::text || ' TL',
         auth.uid(), 'invoice', p_invoice
    from public.club_memberships m
   where m.club_id = v_inv.club_id
     and m.status = 'active'
     and m.role in ('club_admin', 'official')
     and m.profile_id <> auth.uid();

  return v_id;
end; $$;


-- Kulüp ödemeyi onaylar/reddeder.
create or replace function public.confirm_payment(
  p_payment uuid, p_approve boolean, p_note text default null)
returns void language plpgsql security definer set search_path = public as $$
declare v_pay record;
begin
  select * into v_pay from public.payments where id = p_payment;
  if v_pay is null then raise exception 'Ödeme bulunamadı'; end if;
  if not public.is_club_staff(v_pay.club_id) then raise exception 'Yetkisiz'; end if;

  update public.payments
     set status = case when p_approve then 'confirmed' else 'rejected' end,
         confirmed_by = auth.uid(),
         confirmed_at = now(),
         note = coalesce(p_note, note)
   where id = p_payment;

  -- Onaylanan ödeme faturayı kapatır.
  if p_approve and v_pay.invoice_id is not null then
    update public.invoices set status = 'paid' where id = v_pay.invoice_id;
  end if;

  -- Bildiren kişiye sonucu ilet.
  if v_pay.declared_by is not null and v_pay.declared_by <> auth.uid() then
    insert into public.notifications
      (profile_id, kind, title, body, actor_id, entity_type, entity_id)
    values (v_pay.declared_by, 'payment',
            case when p_approve then 'Ödemen onaylandı'
                 else 'Ödeme bildirimin reddedildi' end,
            coalesce(p_note, v_pay.amount::text || ' TL'),
            auth.uid(), 'payment', p_payment);
  end if;
end; $$;


-- Kulüp doğrudan tahsilat girer (nakit/elden) — onay adımı gerekmez.
create or replace function public.record_payment(
  p_invoice uuid, p_amount numeric default null,
  p_method text default 'nakit', p_note text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_inv record;
  v_id  uuid;
begin
  select * into v_inv from public.invoices where id = p_invoice;
  if v_inv is null then raise exception 'Fatura bulunamadı'; end if;
  if not public.is_club_staff(v_inv.club_id) then raise exception 'Yetkisiz'; end if;

  insert into public.payments
    (club_id, invoice_id, athlete_id, amount, method, note,
     declared_by, status, confirmed_by, confirmed_at)
  values (v_inv.club_id, p_invoice, v_inv.athlete_id,
          coalesce(p_amount, v_inv.amount), p_method, p_note,
          auth.uid(), 'confirmed', auth.uid(), now())
  returning id into v_id;

  update public.invoices set status = 'paid' where id = p_invoice;
  return v_id;
end; $$;


-- ---------------------------------------------------------------------------
-- 5) RAPORLAR
-- ---------------------------------------------------------------------------
-- Kulüp özeti. Gecikme, `status` alanına değil son ödeme tarihine bakılarak
-- hesaplanır — böylece ayrı bir "gecikmişleri işaretle" işi gerekmez.
create or replace function public.club_finance_summary(p_club uuid)
returns table (
  billed        numeric,
  collected     numeric,
  outstanding   numeric,
  overdue_count int,
  overdue_total numeric,
  pending_payments int,
  athletes_with_fee int
)
language plpgsql stable security definer set search_path = public as $$
begin
  -- Yetki kontrolü en başta: aksi halde alt sorgular yetkisiz çağrıya da
  -- sayı döndürürdü (security definer RLS'i aştığı için).
  if not public.is_club_staff(p_club) then
    return;
  end if;

  return query
  select
    coalesce(sum(i.amount), 0),
    coalesce(sum(i.amount) filter (where i.status = 'paid'), 0),
    coalesce(sum(i.amount) filter (where i.status <> 'paid'), 0),
    count(*) filter (where i.status <> 'paid'
                       and i.due_date is not null
                       and i.due_date < current_date)::int,
    coalesce(sum(i.amount) filter (where i.status <> 'paid'
                       and i.due_date is not null
                       and i.due_date < current_date), 0),
    (select count(*) from public.payments p
      where p.club_id = p_club and p.status = 'pending')::int,
    (select count(*) from public.athlete_fees af
      where af.club_id = p_club and af.active)::int
  from public.invoices i
  where i.club_id = p_club;
end; $$;


-- Kulübün borç listesi (sporcu bazında, dönem filtreli).
create or replace function public.club_fee_ledger(
  p_club uuid, p_period text default null)
returns table (
  invoice_id uuid,
  athlete_id uuid,
  athlete_name text,
  label text,
  amount numeric,
  status text,
  due_date date,
  period text,
  overdue boolean
)
language sql stable security definer set search_path = public as $$
  select
    i.id,
    i.athlete_id,
    trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')),
    i.label,
    i.amount,
    i.status::text,
    i.due_date,
    i.period,
    (i.status <> 'paid' and i.due_date is not null and i.due_date < current_date)
  from public.invoices i
  left join public.athletes a on a.id = i.athlete_id
  where i.club_id = p_club
    and (p_period is null or i.period = p_period)
    and public.is_club_staff(p_club)
  order by (i.status <> 'paid') desc, i.due_date nulls last,
           trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, ''));
$$;


-- Kişinin kendi (ya da velisi olduğu sporcuların) borçları.
create or replace function public.my_fees()
returns table (
  invoice_id uuid,
  athlete_name text,
  club_name text,
  club_id uuid,
  label text,
  amount numeric,
  status text,
  due_date date,
  overdue boolean,
  pending_declared boolean
)
language sql stable security definer set search_path = public as $$
  select
    i.id,
    trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')),
    c.name,
    c.id,
    i.label,
    i.amount,
    i.status::text,
    i.due_date,
    (i.status <> 'paid' and i.due_date is not null and i.due_date < current_date),
    exists (select 1 from public.payments p
             where p.invoice_id = i.id and p.status = 'pending')
  from public.invoices i
  join public.athletes a on a.id = i.athlete_id
  join public.clubs c on c.id = i.club_id
  where public.can_view_athlete_fees(i.athlete_id)
  order by (i.status <> 'paid') desc, i.due_date nulls last;
$$;


-- Onay bekleyen ödeme bildirimleri (kulüp görevlisi için).
create or replace function public.pending_payments(p_club uuid)
returns table (
  id uuid, athlete_name text, label text, amount numeric,
  method text, paid_at date, note text, receipt_path text,
  declared_name text, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select
    p.id,
    trim(coalesce(a.first_name, '') || ' ' || coalesce(a.last_name, '')),
    coalesce(i.label, 'Serbest ödeme'),
    p.amount, p.method, p.paid_at, p.note, p.receipt_path,
    pr.full_name, p.created_at
  from public.payments p
  left join public.athletes a on a.id = p.athlete_id
  left join public.invoices i on i.id = p.invoice_id
  left join public.profiles pr on pr.id = p.declared_by
  where p.club_id = p_club
    and p.status = 'pending'
    and public.is_club_staff(p_club)
  order by p.created_at;
$$;


-- ---------------------------------------------------------------------------
-- 6) BAĞIŞ KAMPANYALARI
-- ---------------------------------------------------------------------------
create table if not exists public.donation_campaigns (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  title       text not null,
  description text,
  target      numeric(12,2) not null default 0,
  cover_path  text,
  status      text not null default 'active',   -- active | closed
  ends_at     date,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now()
);
create index if not exists idx_campaign_club
  on public.donation_campaigns (club_id, status);

alter table public.donation_campaigns enable row level security;

-- Kampanyalar herkese açık: bağış toplanabilmesi için görünür olmalı.
drop policy if exists "campaign_read" on public.donation_campaigns;
create policy "campaign_read" on public.donation_campaigns for select
  to authenticated using (true);

drop policy if exists "campaign_write" on public.donation_campaigns;
create policy "campaign_write" on public.donation_campaigns for all
  to authenticated
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));


create table if not exists public.donations (
  id           uuid primary key default gen_random_uuid(),
  campaign_id  uuid not null references public.donation_campaigns(id) on delete cascade,
  club_id      uuid not null references public.clubs(id) on delete cascade,
  donor_id     uuid references public.profiles(id) on delete set null,
  donor_name   text,
  amount       numeric(12,2) not null,
  message      text,
  anonymous    boolean not null default false,
  status       text not null default 'pending',  -- pending | confirmed | rejected
  receipt_path text,
  created_at   timestamptz not null default now()
);
create index if not exists idx_donation_campaign
  on public.donations (campaign_id, status);

alter table public.donations enable row level security;

-- Onaylı bağışlar herkese görünür (destekçi listesi); bekleyenleri yalnızca
-- bağışçının kendisi ve kulüp görür.
drop policy if exists "donation_read" on public.donations;
create policy "donation_read" on public.donations for select
  to authenticated
  using (status = 'confirmed'
         or donor_id = auth.uid()
         or public.is_club_staff(club_id));


create or replace function public.donate(
  p_campaign uuid, p_amount numeric, p_message text default null,
  p_anonymous boolean default false, p_receipt text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_camp record;
  v_id   uuid;
  v_name text;
begin
  select * into v_camp from public.donation_campaigns where id = p_campaign;
  if v_camp is null then raise exception 'Kampanya bulunamadı'; end if;
  if v_camp.status <> 'active' then raise exception 'Kampanya kapalı'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'Geçersiz tutar'; end if;

  select full_name into v_name from public.profiles where id = auth.uid();

  insert into public.donations
    (campaign_id, club_id, donor_id, donor_name, amount, message, anonymous,
     receipt_path)
  values (p_campaign, v_camp.club_id, auth.uid(), v_name, p_amount, p_message,
          p_anonymous, p_receipt)
  returning id into v_id;

  -- Kulübe haber ver.
  insert into public.notifications
    (profile_id, kind, title, body, actor_id, entity_type, entity_id)
  select m.profile_id, 'donation', 'Yeni bağış bildirimi',
         v_camp.title || ' · ' || p_amount::text || ' TL',
         auth.uid(), 'campaign', p_campaign
    from public.club_memberships m
   where m.club_id = v_camp.club_id
     and m.status = 'active'
     and m.role in ('club_admin', 'official')
     and m.profile_id <> auth.uid();

  return v_id;
end; $$;


create or replace function public.confirm_donation(
  p_donation uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = public as $$
declare v_don record;
begin
  select * into v_don from public.donations where id = p_donation;
  if v_don is null then raise exception 'Bağış bulunamadı'; end if;
  if not public.is_club_staff(v_don.club_id) then raise exception 'Yetkisiz'; end if;

  update public.donations
     set status = case when p_approve then 'confirmed' else 'rejected' end
   where id = p_donation;
end; $$;


-- Kampanya listesi — toplanan tutar ve destekçi sayısıyla.
create or replace function public.campaigns(p_club uuid default null)
returns table (
  id uuid, club_id uuid, club_name text, title text, description text,
  target numeric, collected numeric, supporters int, status text,
  ends_at date, cover_path text, can_manage boolean, pending_count int
)
language sql stable security definer set search_path = public as $$
  select
    dc.id, dc.club_id, c.name, dc.title, dc.description,
    dc.target,
    coalesce((select sum(d.amount) from public.donations d
               where d.campaign_id = dc.id and d.status = 'confirmed'), 0),
    (select count(*) from public.donations d
      where d.campaign_id = dc.id and d.status = 'confirmed')::int,
    dc.status,
    dc.ends_at,
    dc.cover_path,
    public.is_club_staff(dc.club_id),
    (select count(*) from public.donations d
      where d.campaign_id = dc.id and d.status = 'pending')::int
  from public.donation_campaigns dc
  join public.clubs c on c.id = dc.club_id
  where (p_club is null or dc.club_id = p_club)
  order by (dc.status = 'active') desc, dc.created_at desc;
$$;


-- Bir kampanyanın destekçileri (isimsiz bağışlar gizli kalır).
create or replace function public.campaign_donors(p_campaign uuid)
returns table (
  id uuid, donor_name text, amount numeric, message text,
  anonymous boolean, status text, created_at timestamptz, can_manage boolean
)
language sql stable security definer set search_path = public as $$
  select
    d.id,
    case when d.anonymous then 'İsimsiz bağışçı'
         else coalesce(nullif(trim(d.donor_name), ''), 'Bağışçı') end,
    d.amount, d.message, d.anonymous, d.status, d.created_at,
    public.is_club_staff(d.club_id)
  from public.donations d
  where d.campaign_id = p_campaign
    and (d.status = 'confirmed' or d.donor_id = auth.uid()
         or public.is_club_staff(d.club_id))
  order by d.created_at desc;
$$;
