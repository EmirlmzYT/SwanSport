-- =============================================================================
-- SwanSport — 0030: GİDER TAKİBİ VE MUHASEBECİ ERİŞİMİ
--
-- Finans bugüne kadar tek yönlüydü: aidat, fatura, ödeme, bağış — hepsi para
-- girişi. Kulüp ne harcadığını hiçbir yerde tutmuyordu, dolayısıyla "bu ay kâr
-- ettik mi" sorusunun cevabı yoktu.
--
-- Bu migration üç şey ekler:
--   1. Gider defteri (kategori, tedarikçi, belge, kasa/banka hesabı)
--   2. Dışarıdan bir muhasebecinin kulübe bağlanabilmesi
--   3. Muhasebecinin sporcu verisine DOKUNMADAN defteri görebilmesi
--
-- Üçüncüsü bu dosyanın en kritik parçası; aşağıda ayrıca açıklandı.
--
-- Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) MUHASEBECİ ↔ KULÜP
-- ---------------------------------------------------------------------------
-- Ayrı tablo, `club_memberships`'e rol eklemek değil: muhasebeci kulübün üyesi
-- değil, dışarıdan hizmet veren biri ve aynı anda birden çok kulübe bakabilir.
-- `guardians` tablosunda da aynı ayrım yapılmıştı.

create table if not exists public.club_accountants (
  club_id    uuid not null references public.clubs(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  status     text not null default 'active',        -- active | revoked
  added_by   uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (club_id, profile_id)
);

create index if not exists idx_accountant_profile
  on public.club_accountants (profile_id, status);

alter table public.club_accountants enable row level security;

create or replace function public.is_club_accountant(target_club uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.club_accountants
     where profile_id = auth.uid()
       and club_id = target_club
       and status = 'active'
  );
$$;

-- Kulüp yetkilisi listeyi yönetir; muhasebeci yalnızca kendi satırını görür.
drop policy if exists "accountant_read" on public.club_accountants;
create policy "accountant_read" on public.club_accountants for select
  to authenticated
  using (profile_id = auth.uid() or public.is_club_staff(club_id));

-- Ekleme/çıkarma yalnızca kulüp yöneticisinde; antrenörde değil.
drop policy if exists "accountant_manage" on public.club_accountants;
create policy "accountant_manage" on public.club_accountants for all
  to authenticated
  using (public.is_club_admin(club_id))
  with check (public.is_club_admin(club_id));


-- ---------------------------------------------------------------------------
-- 2) DAVET — mevcut invite_codes tablosu genişletiliyor
-- ---------------------------------------------------------------------------
-- Veli bağlama akışı zaten bu tabloyu kullanıyor; ikinci bir davet mekanizması
-- yazmak yerine `purpose` alanı ayrıştırıyor.

alter table public.invite_codes
  add column if not exists club_id uuid references public.clubs(id) on delete cascade;

-- Davetin kime verildiği. Doluysa YALNIZCA o e-postayla giriş yapan kullanabilir.
--
-- Veli bağlama akışında kod serbesttir; muhasebecide riski farklı, çünkü kodu
-- eline geçiren kulübün bütün parasını görür. E-posta bağlama zorunlu değil
-- ama kulüp yöneticisi muhasebecisinin adresini zaten biliyor.
alter table public.invite_codes
  add column if not exists target_email text;

-- Tek parametreli eski sürüm düşürülüyor.
--
-- `create or replace function` yalnızca AYNI imzayı değiştirir; parametre
-- eklenince yeni bir fonksiyon doğar ve eskisi yerinde kalır. İkisi bir arada
-- olduğunda PostgREST hangisini çağıracağını bilemiyor ve HTTP 300
-- ("Multiple Choices") dönüyor — yani özellik tamamen kırılıyor.
drop function if exists public.create_accountant_invite(uuid);

-- YALNIZCA KULÜP YÖNETİCİSİ davet üretebilir.
--
-- `is_club_staff` antrenörleri de kapsıyor (`coach`, `official`); onunla
-- yazılsaydı 1. kademe bir yardımcı antrenör kulübün defterine dışarıdan biri
-- sokabilirdi. Muhasebeci atamak antrenörlük kararı değil, yönetim kararı.
create or replace function public.create_accountant_invite(
  p_club uuid,
  p_email text default null
)
returns text language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if not public.is_club_admin(p_club) then
    raise exception 'Muhasebeci daveti yalnızca kulüp yöneticisi üretebilir';
  end if;

  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  -- 48 saat: mali erişim için bir hafta uzun. Süresi dolarsa yenisi üretilir.
  insert into public.invite_codes
    (code, purpose, club_id, created_by, expires_at, target_email)
  values (v_code, 'accountant', p_club, auth.uid(), now() + interval '48 hours',
          nullif(lower(trim(coalesce(p_email, ''))), ''));

  return v_code;
end; $$;

-- Kabul: mevcut redeem_invite_code'a muhasebeci dalı eklendi.
create or replace function public.redeem_invite_code(p_code text)
returns void language plpgsql security definer set search_path = public as $$
declare v_inv public.invite_codes; v_name text;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select * into v_inv from public.invite_codes
    where code = upper(p_code) and used_at is null and expires_at > now()
    limit 1;
  if v_inv.id is null then raise exception 'Kod geçersiz veya süresi dolmuş'; end if;

  if v_inv.purpose = 'accountant' then
    -- Davet bir e-postaya bağlanmışsa başkası kullanamaz.
    if v_inv.target_email is not null then
      if lower((select email from auth.users where id = auth.uid()))
         is distinct from v_inv.target_email then
        raise exception 'Bu davet başka bir hesap için üretilmiş';
      end if;
    end if;

    insert into public.club_accountants (club_id, profile_id, added_by, status)
    values (v_inv.club_id, auth.uid(), v_inv.created_by, 'active')
    on conflict (club_id, profile_id)
      do update set status = 'active';
  else
    select coalesce(full_name, 'Veli') into v_name
      from public.profiles where id = auth.uid();
    insert into public.guardians
      (athlete_id, profile_id, display_name, relationship, can_contact)
    values (v_inv.athlete_id, auth.uid(), v_name, 'Veli', true);
  end if;

  update public.invite_codes set used_at = now(), used_by = auth.uid()
   where id = v_inv.id;
end; $$;


-- ---------------------------------------------------------------------------
-- 3) KASA / BANKA HESAPLARI
-- ---------------------------------------------------------------------------
-- Bakiye SAKLANMAZ, hareketlerden hesaplanır. Saklanan bakiye ile hareketler
-- zamanla ayrışır (iptal edilen ödeme, düzeltilen gider, elle müdahale); tek
-- doğru kaynak hareketlerin toplamıdır.

create table if not exists public.cash_accounts (
  id         uuid primary key default gen_random_uuid(),
  club_id    uuid not null references public.clubs(id) on delete cascade,
  name       text not null,                        -- "Nakit kasa", "Ziraat"
  kind       text not null default 'bank',         -- cash | bank | pos
  active     boolean not null default true,
  created_at timestamptz not null default now()
);

do $$ begin
  alter table public.cash_accounts
    add constraint cash_accounts_kind_check check (kind in ('cash', 'bank', 'pos'));
exception when duplicate_object then null; end $$;

create index if not exists idx_cash_account_club
  on public.cash_accounts (club_id, active);

alter table public.cash_accounts enable row level security;

drop policy if exists "cash_account_rw" on public.cash_accounts;
create policy "cash_account_rw" on public.cash_accounts for all
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id))
  with check (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- Para hangi hesaba girdi / hangisinden çıktı.
alter table public.payments
  add column if not exists account_id uuid references public.cash_accounts(id) on delete set null;
alter table public.donations
  add column if not exists account_id uuid references public.cash_accounts(id) on delete set null;


-- ---------------------------------------------------------------------------
-- 4) GİDER KATEGORİLERİ
-- ---------------------------------------------------------------------------
-- club_id null = tüm kulüplere açık ortak kategori. Kulüp kendi kategorisini
-- ekleyebilir ama ortak olanları silemez.

create table if not exists public.expense_categories (
  id      uuid primary key default gen_random_uuid(),
  club_id uuid references public.clubs(id) on delete cascade,
  name    text not null,
  sort    int not null default 100
);

create unique index if not exists idx_expense_cat_shared
  on public.expense_categories (name) where club_id is null;

alter table public.expense_categories enable row level security;

drop policy if exists "expense_cat_read" on public.expense_categories;
create policy "expense_cat_read" on public.expense_categories for select
  to authenticated
  using (
    club_id is null
    or public.is_club_staff(club_id)
    or public.is_club_accountant(club_id)
  );

drop policy if exists "expense_cat_write" on public.expense_categories;
create policy "expense_cat_write" on public.expense_categories for all
  to authenticated
  using (club_id is not null
         and (public.is_club_staff(club_id) or public.is_club_accountant(club_id)))
  with check (club_id is not null
         and (public.is_club_staff(club_id) or public.is_club_accountant(club_id)));

insert into public.expense_categories (club_id, name, sort) values
  (null, 'Kira',      10),
  (null, 'Personel',  20),
  (null, 'Malzeme',   30),
  (null, 'Ulaşım',    40),
  (null, 'Turnuva',   50),
  (null, 'Fatura',    60),
  (null, 'Bakım',     70),
  (null, 'Diğer',     99)
on conflict do nothing;


-- ---------------------------------------------------------------------------
-- 5) GİDER KAYITLARI
-- ---------------------------------------------------------------------------
-- `status='draft'`: mobilden fiş fotoğrafıyla hızlı giriş. Tutar ve görsel
-- girilir, kategori/tedarikçi sonra masaüstünde tamamlanır. Raporlar
-- varsayılan olarak yalnızca `complete` sayar — yarım kayıt toplamı bozmasın.

create table if not exists public.expenses (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id) on delete cascade,
  category_id  uuid references public.expense_categories(id) on delete set null,
  account_id   uuid references public.cash_accounts(id) on delete set null,
  supplier     text,
  amount       numeric(12,2) not null,
  spent_on     date not null default current_date,
  note         text,
  receipt_path text,
  status       text not null default 'complete',   -- draft | complete
  entered_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

do $$ begin
  alter table public.expenses
    add constraint expenses_status_check check (status in ('draft', 'complete'));
exception when duplicate_object then null; end $$;

do $$ begin
  alter table public.expenses
    add constraint expenses_amount_positive check (amount > 0);
exception when duplicate_object then null; end $$;

create index if not exists idx_expense_club_date
  on public.expenses (club_id, spent_on desc);

drop trigger if exists trg_expenses_updated on public.expenses;
create trigger trg_expenses_updated before update on public.expenses
  for each row execute function public.set_updated_at();

alter table public.expenses enable row level security;

drop policy if exists "expense_rw" on public.expenses;
create policy "expense_rw" on public.expenses for all
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id))
  with check (public.is_club_staff(club_id) or public.is_club_accountant(club_id));


-- ---------------------------------------------------------------------------
-- 6) BELGE DEPOSU
-- ---------------------------------------------------------------------------
-- Ayrı bucket: `verification-docs`'ta kimlik belgeleri var ve oraya platform
-- yöneticisi erişiyor. Fiş/fatura ise kulübün ve muhasebecisinin işi; erişim
-- kuralları farklı olduğu için karıştırılmıyor.

insert into storage.buckets (id, name, public)
values ('finance-docs', 'finance-docs', false)
on conflict (id) do nothing;

-- Yol düzeni: "{club_id}/{zaman}_{ad}.{uzantı}" — ilk klasör kulübün id'si.
drop policy if exists "findoc_write" on storage.objects;
create policy "findoc_write" on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'finance-docs'
    and (
      public.is_club_staff(((storage.foldername(name))[1])::uuid)
      or public.is_club_accountant(((storage.foldername(name))[1])::uuid)
    )
  );

drop policy if exists "findoc_read" on storage.objects;
create policy "findoc_read" on storage.objects for select
  to authenticated
  using (
    bucket_id = 'finance-docs'
    and (
      public.is_club_staff(((storage.foldername(name))[1])::uuid)
      or public.is_club_accountant(((storage.foldername(name))[1])::uuid)
    )
  );


-- ---------------------------------------------------------------------------
-- 7) MUHASEBECİ OKUMALARI — sporcu adı GEÇMEZ
-- ---------------------------------------------------------------------------
-- Muhasebeci kulübün defterini görmeli ama sporcuları görmemeli. Aidat
-- satırları para hareketi olduğu için gizlenemez; gizlenecek olan KİMİN
-- ödediği.
--
-- Bu yüzden muhasebeciye `athletes` tablosuna RLS erişimi VERİLMEZ ve finans
-- okumaları aşağıdaki fonksiyonlardan geçer. Fonksiyonlar sporcu adını hiç
-- seçmez; yerine kimlikten türetilmiş sabit bir takma gösterim döner:
--
--   #A3F91C   — kulüp içinde sabit, isim taşımaz, geri çevrilemez değil ama
--               tek başına bir kişiyi tanımlamaz
--
-- Arayüzde gizlemek yeterli değildi: muhasebeci REST üzerinden tabloyu
-- doğrudan sorgulayabilirdi. Veri hiç gelmiyor.

create or replace function public.athlete_ref(p_athlete uuid)
returns text language sql immutable as $$
  select case when p_athlete is null then null
         else '#' || upper(substr(replace(p_athlete::text, '-', ''), 1, 6))
         end;
$$;

/* Gelir–gider defteri: tek akışta iki yön. */
create or replace function public.acc_ledger(
  p_club uuid,
  p_from date default null,
  p_to   date default null
)
returns table (
  entry_id   uuid,
  moved_on   date,
  direction  text,          -- in | out
  label      text,
  category   text,
  counterpart text,         -- tedarikçi ya da sporcu takma gösterimi
  account    text,
  amount     numeric,
  status     text
)
language sql stable security definer set search_path = public as $$
  with allowed as (
    select public.is_club_staff(p_club) or public.is_club_accountant(p_club) as ok
  )
  -- GİDER
  select e.id, e.spent_on, 'out'::text,
         coalesce(e.note, c.name, 'Gider'),
         coalesce(c.name, '—'),
         coalesce(e.supplier, '—'),
         coalesce(a.name, '—'),
         e.amount, e.status
    from public.expenses e
    left join public.expense_categories c on c.id = e.category_id
    left join public.cash_accounts a      on a.id = e.account_id
   where e.club_id = p_club
     and (select ok from allowed)
     and (p_from is null or e.spent_on >= p_from)
     and (p_to   is null or e.spent_on <= p_to)

  union all

  -- AİDAT / ÖDEME  (sporcu adı yok, takma gösterim var)
  select p.id, p.paid_at, 'in'::text,
         coalesce(i.label, 'Ödeme'),
         'Aidat'::text,
         public.athlete_ref(p.athlete_id),
         coalesce(a.name, '—'),
         p.amount, p.status
    from public.payments p
    left join public.invoices i      on i.id = p.invoice_id
    left join public.cash_accounts a on a.id = p.account_id
   where p.club_id = p_club
     and (select ok from allowed)
     and (p_from is null or p.paid_at >= p_from)
     and (p_to   is null or p.paid_at <= p_to)

  union all

  -- BAĞIŞ  (anonim bağışta ad zaten gizli)
  select d.id, d.created_at::date, 'in'::text,
         coalesce(dc.title, 'Bağış'),
         'Bağış'::text,
         case when d.anonymous then 'Anonim' else coalesce(d.donor_name, '—') end,
         coalesce(a.name, '—'),
         d.amount, d.status
    from public.donations d
    left join public.donation_campaigns dc on dc.id = d.campaign_id
    left join public.cash_accounts a       on a.id = d.account_id
   where d.club_id = p_club
     and (select ok from allowed)
     and (p_from is null or d.created_at::date >= p_from)
     and (p_to   is null or d.created_at::date <= p_to)

   order by 2 desc;
$$;

/* Hesap bakiyeleri — onaylı hareketler üzerinden. */
create or replace function public.acc_account_balances(p_club uuid)
returns table (
  account_id uuid,
  name       text,
  kind       text,
  income     numeric,
  outgo      numeric,
  balance    numeric
)
language sql stable security definer set search_path = public as $$
  select a.id, a.name, a.kind,
         coalesce(inc.total, 0),
         coalesce(exp.total, 0),
         coalesce(inc.total, 0) - coalesce(exp.total, 0)
    from public.cash_accounts a
    left join lateral (
      select sum(x.amount) as total from (
        select p.amount from public.payments p
         where p.account_id = a.id and p.status = 'confirmed'
        union all
        select d.amount from public.donations d
         where d.account_id = a.id and d.status = 'confirmed'
      ) x
    ) inc on true
    left join lateral (
      select sum(e.amount) as total from public.expenses e
       where e.account_id = a.id and e.status = 'complete'
    ) exp on true
   where a.club_id = p_club
     and a.active
     and (public.is_club_staff(p_club) or public.is_club_accountant(p_club))
   order by a.name;
$$;

/* Aylık özet — grafik ve karşılaştırma için. */
create or replace function public.acc_monthly_summary(p_club uuid, p_year int)
returns table (month int, income numeric, outgo numeric, net numeric)
language sql stable security definer set search_path = public as $$
  with months as (select generate_series(1, 12) as m),
  inc as (
    select extract(month from p.paid_at)::int as m, sum(p.amount) as total
      from public.payments p
     where p.club_id = p_club and p.status = 'confirmed'
       and extract(year from p.paid_at)::int = p_year
     group by 1
  ),
  don as (
    select extract(month from d.created_at)::int as m, sum(d.amount) as total
      from public.donations d
     where d.club_id = p_club and d.status = 'confirmed'
       and extract(year from d.created_at)::int = p_year
     group by 1
  ),
  out_ as (
    select extract(month from e.spent_on)::int as m, sum(e.amount) as total
      from public.expenses e
     where e.club_id = p_club and e.status = 'complete'
       and extract(year from e.spent_on)::int = p_year
     group by 1
  )
  select months.m,
         coalesce(inc.total, 0) + coalesce(don.total, 0),
         coalesce(out_.total, 0),
         coalesce(inc.total, 0) + coalesce(don.total, 0) - coalesce(out_.total, 0)
    from months
    left join inc  on inc.m  = months.m
    left join don  on don.m  = months.m
    left join out_ on out_.m = months.m
   where public.is_club_staff(p_club) or public.is_club_accountant(p_club)
   order by months.m;
$$;

/* Kategori dağılımı. */
create or replace function public.acc_category_breakdown(
  p_club uuid, p_from date default null, p_to date default null)
returns table (category text, total numeric, entry_count int)
language sql stable security definer set search_path = public as $$
  select coalesce(c.name, 'Kategorisiz'), sum(e.amount), count(*)::int
    from public.expenses e
    left join public.expense_categories c on c.id = e.category_id
   where e.club_id = p_club
     and e.status = 'complete'
     and (p_from is null or e.spent_on >= p_from)
     and (p_to   is null or e.spent_on <= p_to)
     and (public.is_club_staff(p_club) or public.is_club_accountant(p_club))
   group by 1
   order by 2 desc;
$$;

/* Alacaklar — kim ödemedi. Sporcu adı yerine takma gösterim. */
create or replace function public.acc_receivables(p_club uuid)
-- Cikti sutunu `athlete_code`: ayni isimde bir fonksiyon (athlete_ref) var,
-- karisikliga yer birakilmiyor.
returns table (athlete_code text, unpaid_count int, total numeric, oldest date)
language sql stable security definer set search_path = public as $$
  select public.athlete_ref(i.athlete_id),
         count(*)::int,
         sum(i.amount),
         min(i.created_at::date)
    from public.invoices i
   where i.club_id = p_club
     and i.status <> 'paid'
     and (public.is_club_staff(p_club) or public.is_club_accountant(p_club))
   group by 1
   order by 3 desc;
$$;


-- ---------------------------------------------------------------------------
-- 8) YETKİ SIKILAŞTIRMA
-- ---------------------------------------------------------------------------
-- Bu fonksiyonlar kulüp finansını döndürüyor; yetkiyi kendi içlerinde
-- doğruluyorlar ama anon rolüne hiç açık olmamalılar.
--
-- `public` rolü unutulmuyor — 0028'de öğrenildi: yalnızca anon ve
-- authenticated'dan almak yetmez, izin PUBLIC'ten miras alınır.

revoke execute on function public.acc_ledger(uuid, date, date) from public, anon;
revoke execute on function public.acc_account_balances(uuid) from public, anon;
revoke execute on function public.acc_monthly_summary(uuid, int) from public, anon;
revoke execute on function public.acc_category_breakdown(uuid, date, date) from public, anon;
revoke execute on function public.acc_receivables(uuid) from public, anon;
revoke execute on function public.create_accountant_invite(uuid, text) from public, anon;

-- athlete_ref saf bir dönüşüm, sır taşımıyor; açık kalabilir.
