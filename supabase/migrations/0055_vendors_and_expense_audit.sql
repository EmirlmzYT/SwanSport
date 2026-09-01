-- ---------------------------------------------------------------------------
-- 0055 — Tedarikçiler, gider alanları ve silinemez denetim izi
--
-- Mali Operasyon Merkezi'nin birinci katmanı. Yeni bir defter kurmuyor:
-- `expenses` tablosunu genişletiyor ve her değişikliğin izini tutuyor.
--
-- SIRA NOTU: mali iş kuyruğu özeti (`acc_operations_summary`) bilerek en
-- sonda, 0061'de. Sebebi AGENTS.md'deki HTTP 300 tuzağı: `create or replace`
-- yalnızca aynı imzayı değiştirir, sütun eklendiğinde eski sürüm kalır ve
-- PostgREST 300 döner. Özeti her kaynak tablo hazır olduktan sonra **bir
-- kez** yazmak, altı kez imza değiştirmekten güvenli.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) TEDARİKÇİLER
--
-- Muhasebeci tedarikçi adını görür — mali iş için gerekli ve sporcu verisi
-- değil. VERGİ/KURUM BİLGİSİ AYRI TABLODA: kural "yalnızca kulüp
-- yöneticisine açık". RLS satır düzeyinde çalışır, sütun gizleyemez; bu
-- yüzden alanı arayüzde saklamak yerine **ayrı tabloya** koyuyoruz.
-- Arayüzde gizlemek güvenlik değildir (AGENTS.md değişmez 4).
-- ---------------------------------------------------------------------------
create table if not exists public.vendors (
  id                  uuid primary key default gen_random_uuid(),
  club_id             uuid not null references public.clubs(id) on delete cascade,
  name                text not null,
  contact_note        text,
  default_category_id uuid references public.expense_categories(id) on delete set null,
  active              boolean not null default true,
  created_by          uuid references public.profiles(id) on delete set null,
  created_at          timestamptz not null default now()
);

create index if not exists idx_vendors_club
  on public.vendors (club_id, active, name);

-- Aynı kulüpte aynı ada iki tedarikçi, gider raporunu ikiye böler.
create unique index if not exists idx_vendors_club_name
  on public.vendors (club_id, lower(name));

alter table public.vendors enable row level security;

drop policy if exists "vendor_read" on public.vendors;
create policy "vendor_read" on public.vendors for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

drop policy if exists "vendor_write" on public.vendors;
create policy "vendor_write" on public.vendors for all
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id))
  with check (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- Vergi/kurum bilgisi — yalnızca kulüp yöneticisi.
create table if not exists public.vendor_private (
  vendor_id  uuid primary key references public.vendors(id) on delete cascade,
  club_id    uuid not null references public.clubs(id) on delete cascade,
  tax_office text,
  tax_id     text,
  iban       text,
  note       text,
  updated_at timestamptz not null default now()
);

alter table public.vendor_private enable row level security;

-- `is_club_accountant` burada bilerek YOK. Muhasebeci bu satırı hiç görmez.
drop policy if exists "vendor_private_staff" on public.vendor_private;
create policy "vendor_private_staff" on public.vendor_private for all
  to authenticated
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));

-- ---------------------------------------------------------------------------
-- 2) GİDER ALANLARI
--
-- `supplier text` sütunu duruyor: geçmiş kayıtlar onu kullanıyor ve silmek
-- veri kaybı olurdu. Yeni kayıtlar `vendor_id` kullanıyor, okuma ikisini de
-- karşılıyor.
-- ---------------------------------------------------------------------------
alter table public.expenses
  add column if not exists vendor_id   uuid references public.vendors(id) on delete set null,
  add column if not exists team_id     uuid references public.teams(id) on delete set null,
  add column if not exists facility_id uuid references public.facilities(id) on delete set null,
  add column if not exists event_id    uuid references public.events(id) on delete set null,
  add column if not exists op_id       uuid;

-- Mobil taslak gider için idempotency anahtarı. Ağ koptuğunda uygulama
-- isteği tekrarlıyor; `op_id` olmadan aynı fiş iki gider satırı yazardı.
-- Kısmi indeks: eski kayıtların hepsinde null ve NULL'lar çakışmıyor.
create unique index if not exists idx_expenses_op
  on public.expenses (op_id) where op_id is not null;

create index if not exists idx_expenses_club_status
  on public.expenses (club_id, status, spent_on desc);

create index if not exists idx_expenses_vendor
  on public.expenses (vendor_id) where vendor_id is not null;

-- ---------------------------------------------------------------------------
-- 3) DENETİM İZİ — silinemez
--
-- TETİKLEYİCİ, RPC DEĞİL. Yalnızca RPC'ye güvenmek doğrudan `update` yapan
-- her yolu izsiz bırakırdı — `expense_rw` politikası kulüp personeline ve
-- muhasebeciye zaten doğrudan yazma hakkı veriyor. Tetikleyici o yolu da
-- yakalıyor.
--
-- Tabloda INSERT/UPDATE/DELETE politikası **hiç yok**: RLS açık ve politika
-- yoksa erişim reddedilir. Yazma yalnızca `security definer` tetikleyiciden.
-- ---------------------------------------------------------------------------
create table if not exists public.expense_audit_logs (
  id         uuid primary key default gen_random_uuid(),
  expense_id uuid not null,
  club_id    uuid not null references public.clubs(id) on delete cascade,
  actor_id   uuid references public.profiles(id) on delete set null,
  action     text not null,
  old_data   jsonb,
  new_data   jsonb,
  reason     text,
  created_at timestamptz not null default now()
);

-- `expense_id` bilerek foreign key DEĞİL: gider silinirse denetim kaydı
-- kalmalı. `on delete cascade` koysaydık izi silmenin yolu kaydı silmek
-- olurdu — denetim izinin varlık sebebini ortadan kaldırırdı.

do $blk$ begin
  alter table public.expense_audit_logs
    add constraint expense_audit_action_check
    check (action in ('create', 'update', 'complete', 'approve',
                      'reject', 'cancel', 'correct', 'delete'));
exception when duplicate_object then null; end $blk$;

create index if not exists idx_expense_audit_expense
  on public.expense_audit_logs (expense_id, created_at desc);
create index if not exists idx_expense_audit_club
  on public.expense_audit_logs (club_id, created_at desc);

alter table public.expense_audit_logs enable row level security;

drop policy if exists "expense_audit_read" on public.expense_audit_logs;
create policy "expense_audit_read" on public.expense_audit_logs for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- Değişiklik nedenini taşıyan oturum değişkeni. RPC bunu set eder,
-- tetikleyici okur — tetikleyici imzası sabit olduğu için parametre
-- geçirmenin başka yolu yok.
create or replace function public.log_expense_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_action text;
  v_reason text := nullif(current_setting('swansport.change_reason', true), '');
begin
  if tg_op = 'INSERT' then
    v_action := case when new.status = 'draft' then 'create' else 'complete' end;
    insert into public.expense_audit_logs
      (expense_id, club_id, actor_id, action, old_data, new_data, reason)
    values (new.id, new.club_id, auth.uid(), v_action, null,
            to_jsonb(new), v_reason);
    return new;
  end if;

  if tg_op = 'DELETE' then
    insert into public.expense_audit_logs
      (expense_id, club_id, actor_id, action, old_data, new_data, reason)
    values (old.id, old.club_id, auth.uid(), 'delete', to_jsonb(old), null,
            v_reason);
    return old;
  end if;

  -- Hiçbir alan değişmediyse kayıt yazma: gürültü denetim izini okunmaz
  -- yapıyor ve `updated_at` dokunuşu tek başına bir değişiklik değil.
  if to_jsonb(old) - 'updated_at' = to_jsonb(new) - 'updated_at' then
    return new;
  end if;

  v_action := case
    when old.status = 'draft' and new.status = 'complete' then 'complete'
    else 'update'
  end;

  insert into public.expense_audit_logs
    (expense_id, club_id, actor_id, action, old_data, new_data, reason)
  values (new.id, new.club_id, auth.uid(), v_action, to_jsonb(old),
          to_jsonb(new), v_reason);
  return new;
end;
$fn$;

drop trigger if exists trg_expense_audit on public.expenses;
create trigger trg_expense_audit
  after insert or update or delete on public.expenses
  for each row execute function public.log_expense_change();

-- ---------------------------------------------------------------------------
-- 4) TASLAK GİDER — mobil hızlı giriş
--
-- Idempotent: aynı `op_id` ikinci kez gelirse var olan kaydın kimliği döner,
-- yeni satır yazılmaz ve yeni denetim kaydı oluşmaz. Ağ koptuğunda mobil
-- isteği tekrarlıyor ve fiş iki kez yazılıyordu.
-- ---------------------------------------------------------------------------
create or replace function public.create_draft_expense(
  p_club     uuid,
  p_amount   numeric,
  p_op_id    uuid,
  p_receipt  text default null,
  p_note     text default null,
  p_spent_on date default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if not (public.is_club_staff(p_club) or public.is_club_accountant(p_club)) then
    raise exception 'Bu kulübe gider ekleme yetkiniz yok';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Tutar sıfırdan büyük olmalı';
  end if;

  if p_op_id is null then
    raise exception 'İşlem kimliği (op_id) zorunlu';
  end if;

  -- Tekrar gönderim: kaydı zaten yazmışız.
  select id into v_id from public.expenses where op_id = p_op_id;
  if v_id is not null then
    return v_id;
  end if;

  insert into public.expenses
    (club_id, amount, status, receipt_path, note, spent_on, entered_by, op_id)
  values (p_club, p_amount, 'draft', p_receipt, p_note,
          coalesce(p_spent_on, current_date), auth.uid(), p_op_id)
  returning id into v_id;

  return v_id;
end;
$fn$;

revoke execute on function public.create_draft_expense(uuid, numeric, uuid, text, text, date)
  from public, anon;
grant execute on function public.create_draft_expense(uuid, numeric, uuid, text, text, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5) DENETİM İZİ OKUMA
--
-- Muhasebeci gizliliği: bu fonksiyon sporcu ya da veli adı seçmiyor.
-- `actor_id` mali işlemi yapan personelin kimliği, sporcunun değil. Ad
-- yalnızca kulüp personeline dönüyor; muhasebeci kısaltma görüyor.
-- ---------------------------------------------------------------------------
create or replace function public.expense_audit_trail(p_expense uuid)
returns table (
  log_id     uuid,
  action     text,
  actor      text,
  reason     text,
  changed_at timestamptz,
  changed    jsonb)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_club  uuid;
  v_staff boolean;
begin
  select e.club_id into v_club from public.expenses e where e.id = p_expense;

  -- Gider silinmiş olabilir; kulübü denetim kaydından bul.
  if v_club is null then
    select l.club_id into v_club
      from public.expense_audit_logs l
     where l.expense_id = p_expense
     limit 1;
  end if;

  if v_club is null then
    raise exception 'Gider bulunamadı';
  end if;

  v_staff := public.is_club_staff(v_club);

  if not (v_staff or public.is_club_accountant(v_club)) then
    raise exception 'Bu giderin denetim izini görme yetkiniz yok';
  end if;

  return query
    select l.id,
           l.action,
           case when v_staff then coalesce(p.full_name, 'Bilinmiyor')
                else public.athlete_ref(l.actor_id) end,
           l.reason,
           l.created_at,
           -- Yalnızca gerçekten değişen alanlar. Tam satırı döndürmek
           -- denetim izini okunmaz yapardı ve ileride eklenen her sütunu
           -- otomatik olarak sızdırırdı.
           coalesce((
             select jsonb_object_agg(k.key, k.value)
               from jsonb_each(coalesce(l.new_data, '{}'::jsonb)) k
              where coalesce(l.old_data, '{}'::jsonb) -> k.key
                    is distinct from k.value
                and k.key <> 'updated_at'
           ), '{}'::jsonb)
      from public.expense_audit_logs l
      left join public.profiles p on p.id = l.actor_id
     where l.expense_id = p_expense
     order by l.created_at desc;
end;
$fn$;

revoke execute on function public.expense_audit_trail(uuid) from public, anon;
grant execute on function public.expense_audit_trail(uuid) to authenticated;
