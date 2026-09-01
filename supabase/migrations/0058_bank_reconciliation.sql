-- ---------------------------------------------------------------------------
-- 0058 — Banka mutabakatı (CSV)
--
-- İlk sürümde banka API'si, e-fatura ve çoklu banka formatı YOK. Açık
-- belgelenmiş tek bir CSV şablonu var. Sebep: her bankanın kendi biçimini
-- desteklemek, mutabakatın kendisinden çok daha büyük bir iş ve hiçbiri
-- doğrulanmadan yazılamaz.
--
-- EN ÖNEMLİ KURAL: **öneri asla defter kaydı üretmez.** Sistem eşleşme
-- önerir, insan kabul eder. Otomatik eşleşme, yanlış eşleşmeyi denetim
-- izinde "muhasebeci onayladı" gibi gösterirdi.
--
-- CSV ŞABLONU (sütun sırası sabit, ilk satır başlık):
--   tarih;aciklama;tutar;yon
--   2026-09-01;EFT - AHMET Y.;1500,00;giris
--   2026-09-02;KIRA ODEMESI;12000,00;cikis
-- Ayraç `;` — Türkçe Excel varsayılanı. Tutar ondalığı virgül.
-- ---------------------------------------------------------------------------

create table if not exists public.bank_imports (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  account_id  uuid not null references public.cash_accounts(id) on delete cascade,
  file_path   text,
  -- İçerik özeti. Aynı ekstrenin ikinci kez yüklenmesini dosya adına değil
  -- içeriğine bakarak engelliyor: dosya adı değişse de içerik aynıysa
  -- mükerrer hareket oluşmuyor.
  file_hash   text not null,
  row_count   int not null default 0,
  period_from date,
  period_to   date,
  imported_by uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint bank_import_unique unique (club_id, file_hash)
);

create index if not exists idx_bank_import_club
  on public.bank_imports (club_id, created_at desc);

alter table public.bank_imports enable row level security;

drop policy if exists "bank_import_read" on public.bank_imports;
create policy "bank_import_read" on public.bank_imports for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));
-- Yazma yalnızca RPC'den: mükerrerlik ve satır ayrıştırma tek yerde kalsın.

-- ---------------------------------------------------------------------------
-- EKSTRE SATIRLARI
--
-- `raw_description` banka açıklaması: IBAN, ad-soyad, telefon içerebilir.
-- Bu yüzden okuma RPC'si maskeliyor ve dışa aktarıma **varsayılan olarak
-- girmiyor**.
-- ---------------------------------------------------------------------------
create table if not exists public.bank_transactions (
  id              uuid primary key default gen_random_uuid(),
  import_id       uuid not null references public.bank_imports(id) on delete cascade,
  club_id         uuid not null references public.clubs(id) on delete cascade,
  account_id      uuid not null references public.cash_accounts(id) on delete cascade,
  row_no          int not null,
  txn_on          date not null,
  amount          numeric(12,2) not null,
  direction       text not null,
  raw_description text,
  match_status    text not null default 'unmatched',
  matched_kind    text,
  matched_id      uuid,
  decided_by      uuid references public.profiles(id) on delete set null,
  decided_at      timestamptz,
  created_at      timestamptz not null default now(),
  constraint bank_txn_row_unique unique (import_id, row_no)
);

do $blk$ begin
  alter table public.bank_transactions
    add constraint bank_txn_direction_check check (direction in ('in', 'out'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.bank_transactions
    add constraint bank_txn_status_check
    check (match_status in ('unmatched', 'matched', 'ignored'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.bank_transactions
    add constraint bank_txn_kind_check
    check (matched_kind is null
           or matched_kind in ('payment', 'expense', 'donation'));
exception when duplicate_object then null; end $blk$;

-- Aynı defter kaydına iki banka hareketi bağlanamaz: bağlansaydı tek
-- ödeme iki kez mutabık gösterilir ve fark sessizce kapanırdı.
create unique index if not exists idx_bank_txn_matched_once
  on public.bank_transactions (matched_kind, matched_id)
  where match_status = 'matched' and matched_id is not null;

create index if not exists idx_bank_txn_club_status
  on public.bank_transactions (club_id, match_status, txn_on desc);

alter table public.bank_transactions enable row level security;

drop policy if exists "bank_txn_read" on public.bank_transactions;
create policy "bank_txn_read" on public.bank_transactions for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));
-- Yazma yalnızca RPC'den.

-- ---------------------------------------------------------------------------
-- MUTABAKAT KARAR İZİ
--
-- `expense_audit_logs` gibi: politika yalnızca SELECT veriyor, yazma
-- `security definer` RPC'den. Her kabul, ret ve elle eşleştirme buraya.
-- ---------------------------------------------------------------------------
create table if not exists public.bank_reconcile_logs (
  id           uuid primary key default gen_random_uuid(),
  txn_id       uuid not null,
  club_id      uuid not null references public.clubs(id) on delete cascade,
  actor_id     uuid references public.profiles(id) on delete set null,
  action       text not null,
  matched_kind text,
  matched_id   uuid,
  note         text,
  created_at   timestamptz not null default now()
);

create index if not exists idx_bank_reconcile_txn
  on public.bank_reconcile_logs (txn_id, created_at desc);

alter table public.bank_reconcile_logs enable row level security;

drop policy if exists "bank_reconcile_read" on public.bank_reconcile_logs;
create policy "bank_reconcile_read" on public.bank_reconcile_logs for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- ---------------------------------------------------------------------------
-- MASKELEME
--
-- IBAN ve uzun rakam dizileri (kart, telefon, TC) maskeleniyor. Mükemmel
-- bir anonimleştirme değil — banka açıklaması serbest metin ve her şey
-- yazılabilir. Amaç, ekrana ve rapora kazara kimlik bilgisi düşmesini
-- zorlaştırmak.
-- ---------------------------------------------------------------------------
create or replace function public.mask_bank_text(p_text text)
returns text
language sql
immutable
as $fn$
  select case when p_text is null then null else
    regexp_replace(
      regexp_replace(p_text, '(TR)[0-9]{2}[0-9 ]{16,}', '\1•• •••• ••••', 'gi'),
      '[0-9]{7,}', '•••••••', 'g')
  end;
$fn$;

-- ---------------------------------------------------------------------------
-- EKSTRE YÜKLEME
--
-- Satırlar istemcide ayrıştırılıp jsonb dizisi olarak geliyor; hash
-- istemcide dosyanın ham içeriğinden hesaplanıyor. Sunucu hash'i yeniden
-- hesaplamıyor — ham dosya sunucuya hiç gelmiyor, yalnızca Storage'a.
--
-- Bu bir sınır ve açıkça söylenmeli: hash mükerrer yüklemeyi engelliyor,
-- içerik bütünlüğünü kanıtlamıyor. Aynı istemci farklı hash gönderirse
-- ikinci kayıt açılır. Karşı tarafta kötü niyet değil, dikkatsizlik
-- varsayımıyla kurulmuş bir koruma.
-- ---------------------------------------------------------------------------
create or replace function public.import_bank_statement(
  p_club    uuid,
  p_account uuid,
  p_hash    text,
  p_rows    jsonb,
  p_path    text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_import uuid;
  v_n      int;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if not (public.is_club_staff(p_club) or public.is_club_accountant(p_club)) then
    raise exception 'Bu kulüpte ekstre yükleme yetkiniz yok';
  end if;

  if not exists (select 1 from public.cash_accounts
                  where id = p_account and club_id = p_club) then
    raise exception 'Hesap bu kulübe ait değil';
  end if;

  if coalesce(trim(p_hash), '') = '' then
    raise exception 'Dosya özeti (hash) zorunlu';
  end if;

  if jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then
    raise exception 'Ekstre satırı yok';
  end if;

  -- Mükerrer yükleme: aynı içerik ikinci kez gelmiş.
  select id into v_import from public.bank_imports
   where club_id = p_club and file_hash = trim(p_hash);
  if v_import is not null then
    raise exception 'Bu ekstre daha önce yüklenmiş';
  end if;

  insert into public.bank_imports
    (club_id, account_id, file_path, file_hash, imported_by)
  values (p_club, p_account, p_path, trim(p_hash), auth.uid())
  returning id into v_import;

  insert into public.bank_transactions
    (import_id, club_id, account_id, row_no, txn_on, amount, direction,
     raw_description)
  select v_import, p_club, p_account,
         (r.ord)::int,
         (r.item ->> 'date')::date,
         abs((r.item ->> 'amount')::numeric),
         case when lower(coalesce(r.item ->> 'direction', '')) in ('in', 'giris', 'giriş')
              then 'in' else 'out' end,
         nullif(trim(coalesce(r.item ->> 'description', '')), '')
    from jsonb_array_elements(p_rows) with ordinality as r(item, ord);

  select count(*) into v_n from public.bank_transactions
   where import_id = v_import;

  update public.bank_imports
     set row_count = v_n,
         period_from = (select min(txn_on) from public.bank_transactions
                         where import_id = v_import),
         period_to   = (select max(txn_on) from public.bank_transactions
                         where import_id = v_import)
   where id = v_import;

  return v_import;
end;
$fn$;

revoke execute on function public.import_bank_statement(uuid, uuid, text, jsonb, text)
  from public, anon;
grant execute on function public.import_bank_statement(uuid, uuid, text, jsonb, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- EŞLEŞME ÖNERİSİ
--
-- Tutar birebir, yön aynı, tarih ±5 gün. Skor tarih yakınlığından geliyor:
-- aynı gün en yüksek. Tutarda tolerans YOK — 1 kuruş farkı tolere etmek,
-- yanlış eşleşmeyi doğru göstermenin en kolay yolu.
--
-- Muhasebeci gizliliği: sporcu adı seçilmiyor, `athlete_ref` dönüyor.
-- ---------------------------------------------------------------------------
create or replace function public.bank_match_suggestions(p_txn uuid)
returns table (
  kind       text,
  entry_id   uuid,
  entry_on   date,
  amount     numeric,
  label      text,
  day_gap    int)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_txn public.bank_transactions%rowtype;
begin
  select * into v_txn from public.bank_transactions where id = p_txn;
  if v_txn.id is null then
    raise exception 'Banka hareketi bulunamadı';
  end if;

  if not (public.is_club_staff(v_txn.club_id)
          or public.is_club_accountant(v_txn.club_id)) then
    raise exception 'Bu hareketi görme yetkiniz yok';
  end if;

  return query
  with taken as (
    -- Başka bir harekete bağlanmış defter kayıtları aday değil.
    select b.matched_kind as k, b.matched_id as i
      from public.bank_transactions b
     where b.club_id = v_txn.club_id
       and b.match_status = 'matched'
       and b.matched_id is not null
  ),
  cand as (
    select 'payment'::text as kind, p.id, p.paid_at as on_date, p.amount,
           coalesce(public.athlete_ref(p.athlete_id), 'Tahsilat') as label
      from public.payments p
     where v_txn.direction = 'in'
       and p.club_id = v_txn.club_id
       and p.status = 'confirmed'
       and p.amount = v_txn.amount
       and p.paid_at between v_txn.txn_on - 5 and v_txn.txn_on + 5
    union all
    select 'donation', d.id, d.created_at::date, d.amount, 'Bağış'
      from public.donations d
     where v_txn.direction = 'in'
       and d.club_id = v_txn.club_id
       and d.status = 'confirmed'
       and d.amount = v_txn.amount
       and d.created_at::date between v_txn.txn_on - 5 and v_txn.txn_on + 5
    union all
    select 'expense', e.id, e.spent_on, e.amount,
           coalesce(ve.name, e.supplier, 'Gider')
      from public.expenses e
      left join public.vendors ve on ve.id = e.vendor_id
     where v_txn.direction = 'out'
       and e.club_id = v_txn.club_id
       and e.status = 'complete'
       and e.amount = v_txn.amount
       and e.spent_on between v_txn.txn_on - 5 and v_txn.txn_on + 5
  )
  select c.kind, c.id, c.on_date, c.amount, c.label,
         abs(c.on_date - v_txn.txn_on)::int
    from cand c
   where not exists (select 1 from taken t
                      where t.k = c.kind and t.i = c.id)
   order by 6, 3 desc
   limit 10;
end;
$fn$;

revoke execute on function public.bank_match_suggestions(uuid) from public, anon;
grant execute on function public.bank_match_suggestions(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- MUTABAKAT KARARI
--
-- `p_action`: match | unmatch | ignore
--
-- Defter kaydı OLUŞTURMUYOR. Yalnızca var olan bir kaydı banka hareketiyle
-- ilişkilendiriyor. Eksik defter kaydı varsa muhasebeci onu normal yolundan
-- girer; mutabakat ekranı gider yazma yeri değil.
-- ---------------------------------------------------------------------------
create or replace function public.decide_bank_match(
  p_txn    uuid,
  p_action text,
  p_kind   text default null,
  p_id     uuid default null,
  p_note   text default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_txn public.bank_transactions%rowtype;
  v_ok  boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_txn from public.bank_transactions where id = p_txn;
  if v_txn.id is null then
    raise exception 'Banka hareketi bulunamadı';
  end if;

  if not (public.is_club_staff(v_txn.club_id)
          or public.is_club_accountant(v_txn.club_id)) then
    raise exception 'Bu hareketi eşleştirme yetkiniz yok';
  end if;

  if p_action = 'match' then
    if p_kind is null or p_id is null then
      raise exception 'Eşleştirme için defter kaydı seçilmeli';
    end if;

    -- Seçilen kayıt gerçekten bu kulübün mü. Kimlik tahmin edilebilir
    -- olmasa da "uuid'yi bilmiyor" bir erişim kontrolü değil.
    if p_kind = 'payment' then
      select exists (select 1 from public.payments
                      where id = p_id and club_id = v_txn.club_id) into v_ok;
    elsif p_kind = 'donation' then
      select exists (select 1 from public.donations
                      where id = p_id and club_id = v_txn.club_id) into v_ok;
    elsif p_kind = 'expense' then
      select exists (select 1 from public.expenses
                      where id = p_id and club_id = v_txn.club_id) into v_ok;
    else
      raise exception 'Geçersiz kayıt türü';
    end if;

    if not v_ok then
      raise exception 'Seçilen kayıt bu kulübe ait değil';
    end if;

    update public.bank_transactions
       set match_status = 'matched', matched_kind = p_kind, matched_id = p_id,
           decided_by = auth.uid(), decided_at = now()
     where id = p_txn;

  elsif p_action = 'unmatch' then
    update public.bank_transactions
       set match_status = 'unmatched', matched_kind = null, matched_id = null,
           decided_by = auth.uid(), decided_at = now()
     where id = p_txn;

  elsif p_action = 'ignore' then
    update public.bank_transactions
       set match_status = 'ignored', matched_kind = null, matched_id = null,
           decided_by = auth.uid(), decided_at = now()
     where id = p_txn;
  else
    raise exception 'Geçersiz işlem';
  end if;

  insert into public.bank_reconcile_logs
    (txn_id, club_id, actor_id, action, matched_kind, matched_id, note)
  values (p_txn, v_txn.club_id, auth.uid(), p_action, p_kind, p_id,
          nullif(trim(coalesce(p_note, '')), ''));
end;
$fn$;

revoke execute on function public.decide_bank_match(uuid, text, text, uuid, text)
  from public, anon;
grant execute on function public.decide_bank_match(uuid, text, text, uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- EKSTRE OKUMA — maskeli
--
-- Ham açıklama bu fonksiyondan **hiç çıkmıyor**. Ekranda ve dışa aktarımda
-- kullanılan tek yol bu. Ham metne erişim yalnızca tabloyu doğrudan okuyan
-- kulüp personelinde; muhasebeci de tabloyu okuyabildiği için maskeleme
-- kesin bir gizlilik sınırı değil, kazara sızmayı önleyen bir katman.
-- ---------------------------------------------------------------------------
create or replace function public.bank_transactions_page(
  p_club   uuid,
  p_status text default 'unmatched',
  p_limit  int default 100,
  p_offset int default 0)
returns table (
  txn_id       uuid,
  txn_on       date,
  amount       numeric,
  direction    text,
  description  text,
  match_status text,
  matched_kind text,
  matched_id   uuid,
  account_name text,
  total_count  bigint)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if not (public.is_club_staff(p_club) or public.is_club_accountant(p_club)) then
    raise exception 'Bu kulübün ekstresini görme yetkiniz yok';
  end if;

  return query
    select t.id, t.txn_on, t.amount, t.direction,
           public.mask_bank_text(t.raw_description),
           t.match_status, t.matched_kind, t.matched_id,
           coalesce(a.name, '—'),
           count(*) over ()
      from public.bank_transactions t
      left join public.cash_accounts a on a.id = t.account_id
     where t.club_id = p_club
       and (p_status is null or p_status = 'all' or t.match_status = p_status)
     order by t.txn_on desc, t.row_no
     limit least(greatest(coalesce(p_limit, 100), 1), 500)
    offset greatest(coalesce(p_offset, 0), 0);
end;
$fn$;

revoke execute on function public.bank_transactions_page(uuid, text, int, int)
  from public, anon;
grant execute on function public.bank_transactions_page(uuid, text, int, int)
  to authenticated;
