-- ===========================================================================
-- SwanSport — bekleyen migration'lar (0053-0066)
--
-- Supabase SQL Editor'e yapistir, TEK SEFERDE calistir.
--
-- TEK ISLEM: `begin`/`commit` arasinda. Bir yerde hata olursa hicbiri
-- uygulanmiyor; yarim sema kalmiyor.
--
-- TEKRAR CALISTIRILABILIR: `create or replace`, `if not exists`,
-- `on conflict do nothing`. Emin degilsen tekrar calistir, zarari yok.
--
-- SURE: 14 dosya, 5382 satir. Editorde birkac saniye surer.
--
-- ---------------------------------------------------------------------------
-- ICINDEKILER
--
--   0053  Ozellik bayraklari — kademeli yayin (off/admins/testers/everyone)
--   0054  Antronor kesfi
--
--   MALI OPERASYON MERKEZI
--   0055  Tedarikciler, gider alanlari, SILINEMEZ denetim izi
--   0056  Tekrarlayan giderler ve taahhutler
--   0057  Gider onay politikalari
--   0058  Banka mutabakati (CSV)
--   0059  Butce ve nakit tahmini
--   0060  Mali donem kapanisi + KAPANMIS DONEM KILIDI
--   0061  Mali is kuyrugu ozeti + kulup operasyon merkezi
--
--   SOSYAL KATMAN
--   0062  Gonderi gorunurlugu, coklu fotograf, kaydedilenler, etiketleme
--   0063  Paylasim, repost/alinti, GUVENLI KART
--
--   KULUP YASAM DONGUSU
--   0064  Saglik kisiti ve KATI UYGUNLUK KILIDI
--   0065  Idempotent yoklama ve surum cakismasi
--   0066  Destek merkezi, operasyon riski, veri saklama
--
-- ---------------------------------------------------------------------------
-- BU MIGRATION UC GUVENLIK ACIGINI KAPATIYOR
--
--   1. `posts_read` politikasi `using (true)` idi (0006'dan beri).
--      Giris yapmis herkes BUTUN gonderileri okuyabiliyordu — kulup ici
--      duyuru da, engelledigin kisinin gonderisi de.
--
--   2. Gider degisiklikleri hicbir yerde izlenmiyordu. Artik tetikleyici
--      her degisikligi yaziyor ve kayit silinemiyor.
--
--   3. Kapanmis mali donem diye bir sey yoktu; gecmis ayin rakami her an
--      degistirilebiliyordu.
--
-- ---------------------------------------------------------------------------
-- CALISTIRDIKTAN SONRA
--
-- Butun yeni ozellikler `admins` kademesinde basliyor, yani yalnizca
-- platform yoneticisine gorunuyor. Bu bilincli: hicbiri gercek kullanimda
-- denenmedi. Konsol > Ozellik bayraklari'ndan kademeleri sen yonetiyorsun.
--
-- `offline_attendance` bayragi `off` — cakisma cozme ekrani yazilmadan
-- acilmamali, yanlis calistiginda VERI KAYBETTIRIR.
-- ===========================================================================

begin;


-- ===========================================================================
-- 0053_feature_flags.sql
-- ===========================================================================

-- 0053 — Özellik bayrakları ve kademeli yayın
--
-- Planın 1. bölümü: "Büyük özellikler doğrudan herkese açılmaz." Bugüne kadar
-- öyle açıldı — pazaryeri, kort sistemi, partner arama, halı saha; hepsi
-- yazıldığı gün herkese görünür oldu ve hiçbiri önce denenmedi.
--
-- Bu migration o kararı **uygulanabilir** hale getiriyor. Bayrak olmadan
-- "önce test kullanıcılarıyla dene" bir niyet; bayrakla bir düğme.
--
-- Kademeler planın sırasıyla:
--   off       kimse görmüyor  (geri alma da bu)
--   admins    yalnızca platform yöneticisi
--   testers   seçili kullanıcılar ve kulüpler
--   everyone  genel yayın

create table if not exists public.feature_flags (
  key         text primary key,
  audience    text not null default 'off',
  label       text not null,
  description text,
  updated_at  timestamptz not null default now(),
  updated_by  uuid references public.profiles(id) on delete set null,

  constraint feature_flag_audience_valid
    check (audience in ('off', 'admins', 'testers', 'everyone'))
);

-- Kullanıcı bazlı test listesi. Kulüp bazlı yayın için `club_id` de var:
-- planda "seçili test kulübü" geçiyor ve tek tek kullanıcı eklemek bir
-- kulübün tamamını açmak için pratik değil.
create table if not exists public.feature_flag_testers (
  key        text not null references public.feature_flags(key) on delete cascade,
  profile_id uuid references public.profiles(id) on delete cascade,
  club_id    uuid references public.clubs(id) on delete cascade,
  created_at timestamptz not null default now(),

  -- Ya kişi ya kulüp; ikisi birden anlamsız, hiçbiri boş satır demek.
  constraint tester_target_present
    check (num_nonnulls(profile_id, club_id) = 1)
);

create unique index if not exists idx_flag_tester_profile
  on public.feature_flag_testers (key, profile_id) where profile_id is not null;
create unique index if not exists idx_flag_tester_club
  on public.feature_flag_testers (key, club_id) where club_id is not null;

alter table public.feature_flags enable row level security;
alter table public.feature_flag_testers enable row level security;

-- Bayrak listesi herkese okunur: istemci hangi özelliğin açık olduğunu
-- bilmek zorunda. Gizli tutulacak bir şey değil — asıl koruma özelliğin
-- kendi RLS'inde, bayrak yalnızca görünürlük.
drop policy if exists "flag_read" on public.feature_flags;
create policy "flag_read" on public.feature_flags for select
  to anon, authenticated using (true);

drop policy if exists "flag_admin" on public.feature_flags;
create policy "flag_admin" on public.feature_flags for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- Test listesi yalnızca yöneticiye ve kişinin kendisine. Kimin test
-- kullanıcısı olduğu başkasını ilgilendirmiyor.
drop policy if exists "flag_tester_read" on public.feature_flag_testers;
create policy "flag_tester_read" on public.feature_flag_testers for select
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

drop policy if exists "flag_tester_admin" on public.feature_flag_testers;
create policy "flag_tester_admin" on public.feature_flag_testers for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- ---------------------------------------------------------------------------
-- Bu kullanıcı için açık olan bayraklar
--
-- Tek çağrıda hepsi dönüyor: uygulama açılışta bir kez alıp bellekte
-- tutuyor. Her ekranda ayrı sorgu, açılışı ekran sayısı kadar yavaşlatırdı.
-- ---------------------------------------------------------------------------
create or replace function public.my_feature_flags()
returns table (key text)
language sql
stable
security definer
set search_path = public
as $fn$
  select f.key
    from public.feature_flags f
   where f.audience = 'everyone'
      or (f.audience = 'admins' and public.is_platform_admin())
      or (f.audience = 'testers' and (
            public.is_platform_admin()
            or exists (select 1 from public.feature_flag_testers t
                        where t.key = f.key and t.profile_id = auth.uid())
            or exists (select 1 from public.feature_flag_testers t
                        join public.club_memberships m
                          on m.club_id = t.club_id
                         and m.profile_id = auth.uid()
                         and m.status = 'active'
                       where t.key = f.key)
         ));
$fn$;

revoke execute on function public.my_feature_flags() from public;
grant execute on function public.my_feature_flags() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Mevcut özellikler için bayraklar
--
-- Pazaryeri `admins`'te başlıyor — bugün herkese açıldı ve hiç denenmedi.
-- Geri çekmek değil, planın söylediği sıraya oturtmak: önce yönetici, sonra
-- seçili kullanıcılar, sonra genel.
--
-- Diğerleri `everyone`: aylardır canlıdalar ve kapatmak, kullanan varsa
-- (kimse denemediği için bilmiyoruz) elinden almak olurdu. Bayrağa
-- bağlanmalarının sebebi ileride geri alınabilmeleri.
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('marketplace', 'admins', 'Spor malzemeleri pazaryeri',
   'İlan, mağaza, favori ve raporlama. Kademeli açılıyor.'),
  ('courts', 'everyone', 'Halka açık kortlar',
   'Kort sırası ve konum doğrulama.'),
  ('partner_search', 'everyone', 'Partner arama',
   'Branşa göre partner eşleştirme.'),
  ('turf_fields', 'everyone', 'Halı sahalar',
   'Doluluk panosu ve saat isteme.'),
  ('team_hub', 'everyone', 'Takım merkezi',
   'Kadro, program ve takım sohbeti.')
on conflict (key) do nothing;

-- ===========================================================================
-- 0054_coach_discovery.sql
-- ===========================================================================

-- 0054 — Antrenör keşfi
--
-- Planın Dönem 5'i: doğrulanmış antrenör profilleri, branş/şehir/kademe ile
-- aranabilsin, ilk aşamada ödeme değil **talep ve sohbet**.
--
-- YENİ TABLO YOK. Gereken her şey duruyor: `profile_credentials` doğrulanmış
-- antrenörlüğü ve kademeyi (`coach_level`) tutuyor, `my_coach_sports()`
-- branşları veriyor, `profiles.city_code` şehri. Eksik olan tek şey bunları
-- birleştiren bir arama.
--
-- DEĞERLENDİRME/YORUM YOK. Plan da istemiyor: doğrulanabilir bir hizmet
-- kaydı olmadan yıldız sistemi kurmak manipülasyona açık — kimin gerçekten
-- ders aldığını bilmeden puan toplamak, puanı anlamsız yapar.

-- ---------------------------------------------------------------------------
-- Antrenör arama
--
-- Yalnızca **görünür olmayı kabul etmiş** antrenörler dönüyor. Doğrulanmış
-- olmak tek başına yetmiyor: kulübünde çalışan bir antrenörün yeni öğrenci
-- aramıyor olabileceğini varsaymak, onu istemediği taleplere açardı.
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists coach_discoverable boolean not null default false,
  add column if not exists coach_bio text;

comment on column public.profiles.coach_discoverable is
  'Antrenör keşfinde görünmeyi kabul etti mi. Varsayılan KAPALI — '
  'doğrulanmış olmak, talep almak istemekle aynı şey değil.';

create index if not exists idx_profiles_coach_discoverable
  on public.profiles (city_code) where coach_discoverable;

create or replace function public.search_coaches(
  p_query text default null,
  p_sport text default null,
  p_city  text default null,
  p_min_level int default null,
  p_limit int default 30)
returns table (
  profile_id uuid,
  full_name  text,
  city_code  text,
  bio        text,
  level      int,
  sports     text[])
language sql
stable
security definer
set search_path = public
as $fn$
  select p.id,
         p.full_name,
         p.city_code,
         p.coach_bio,
         max(c.coach_level),
         coalesce(array_agg(distinct c.sport_code)
                    filter (where c.sport_code is not null), '{}')
    from public.profiles p
    join public.profile_credentials c
      on c.profile_id = p.id
     and c.kind = 'coach'
     and c.status = 'approved'
   where p.coach_discoverable
     -- Kendini aramanın anlamı yok ve sonucu kirletiyor.
     and p.id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid)
     -- Engellenen kişi görünmüyor (0052 ile aynı kural).
     and (auth.uid() is null or not public.is_blocked_between(auth.uid(), p.id))
     and (p_query is null or public.tr_contains(p.full_name, p_query))
     and (p_city  is null or p.city_code = p_city)
     and (p_sport is null or c.sport_code = p_sport)
   group by p.id, p.full_name, p.city_code, p.coach_bio
  having (p_min_level is null or max(c.coach_level) >= p_min_level)
   order by max(c.coach_level) desc nulls last, p.full_name
   limit least(greatest(coalesce(p_limit, 30), 1), 50);
$fn$;

revoke execute on function public.search_coaches(text, text, text, int, int)
  from public;
grant execute on function public.search_coaches(text, text, text, int, int)
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Keşfedilebilirlik anahtarı
--
-- RPC olmasının sebebi: yalnızca **doğrulanmış** antrenör açabilsin.
-- Doğrudan `update` ile herkes kendini keşfedilebilir yapabilirdi ve
-- doğrulanmamış kişiler arama sonucunda çıkmasa da bayrak taşırdı.
-- ---------------------------------------------------------------------------
create or replace function public.set_coach_discoverable(
  p_on boolean,
  p_bio text default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if p_on and not public.is_verified_coach() then
    raise exception 'Antrenör keşfinde görünmek için onaylanmış antrenör '
                    'belgen olmalı';
  end if;

  update public.profiles
     set coach_discoverable = p_on,
         coach_bio = case when p_bio is null then coach_bio
                          else nullif(trim(p_bio), '') end
   where id = auth.uid();
end;
$fn$;

revoke execute on function public.set_coach_discoverable(boolean, text)
  from public, anon;
grant execute on function public.set_coach_discoverable(boolean, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Bayrak — kademeli yayın (0053)
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('coach_discovery', 'admins', 'Antrenör keşfi',
   'Doğrulanmış antrenörleri branş, şehir ve kademeye göre bulma.')
on conflict (key) do nothing;

-- ===========================================================================
-- 0055_vendors_and_expense_audit.sql
-- ===========================================================================

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

-- ===========================================================================
-- 0056_recurring_expenses.sql
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 0056 — Tekrarlayan giderler ve taahhütler
--
-- Kira, tesis, bakım, lisans, sigorta, internet, yazılım. Kulübün bildiği
-- ama sistemin bilmediği düzenli giderler; nakit tahmininin de temeli.
--
-- İKİ TABLO, BİR SEBEP: `recurring_expenses` taahhüdün kendisi,
-- `recurring_occurrences` her bir vadesi. Vade satırı, gider kaydından
-- **önce** var olmalı — yoksa "vadesine 7 gün kaldı" uyarısı için ortada
-- hiçbir şey olmaz ve uyarmak adına sahte gider yazmak gerekirdi.
-- ---------------------------------------------------------------------------

create table if not exists public.recurring_expenses (
  id             uuid primary key default gen_random_uuid(),
  club_id        uuid not null references public.clubs(id) on delete cascade,
  title          text not null,
  vendor_id      uuid references public.vendors(id) on delete set null,
  category_id    uuid references public.expense_categories(id) on delete set null,
  account_id     uuid references public.cash_accounts(id) on delete set null,
  amount         numeric(12,2) not null,
  currency       text not null default 'TRY',
  frequency      text not null default 'monthly',
  -- `custom` için ay adımı. monthly=1, quarterly=3, yearly=12 zaten sabit.
  interval_months int,
  -- İlk vade. Sonraki vadeler bundan türüyor; ayrı bir "ayın kaçı" alanı
  -- YOK: iki yerde gün tutmak, ikisinin ayrışması demek.
  starts_on      date not null,
  ends_on        date,
  owner_id       uuid references public.profiles(id) on delete set null,
  needs_approval boolean not null default false,
  team_id        uuid references public.teams(id) on delete set null,
  facility_id    uuid references public.facilities(id) on delete set null,
  event_id       uuid references public.events(id) on delete set null,
  note           text,
  active         boolean not null default true,
  created_by     uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now()
);

do $blk$ begin
  alter table public.recurring_expenses
    add constraint recurring_frequency_check
    check (frequency in ('monthly', 'quarterly', 'yearly', 'custom'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.recurring_expenses
    add constraint recurring_amount_check check (amount > 0);
exception when duplicate_object then null; end $blk$;

-- `custom` seçilip adım verilmezse vade üretimi sessizce durur. Şema
-- düzeyinde kesiyoruz.
do $blk$ begin
  alter table public.recurring_expenses
    add constraint recurring_custom_needs_interval
    check (frequency <> 'custom' or coalesce(interval_months, 0) > 0);
exception when duplicate_object then null; end $blk$;

create index if not exists idx_recurring_club
  on public.recurring_expenses (club_id, active);

alter table public.recurring_expenses enable row level security;

drop policy if exists "recurring_read" on public.recurring_expenses;
create policy "recurring_read" on public.recurring_expenses for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

drop policy if exists "recurring_write" on public.recurring_expenses;
create policy "recurring_write" on public.recurring_expenses for all
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id))
  with check (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- ---------------------------------------------------------------------------
-- VADELER
--
-- `unique (recurring_id, due_on)` bu tasarımın kilit taşı: aynı taahhüt aynı
-- dönem için iki kez gider üretemiyor ve bunu uygulama değil veritabanı
-- garanti ediyor. Zamanlanmış iş iki kez çalışsa da sonuç aynı.
-- ---------------------------------------------------------------------------
create table if not exists public.recurring_occurrences (
  id           uuid primary key default gen_random_uuid(),
  recurring_id uuid not null references public.recurring_expenses(id) on delete cascade,
  club_id      uuid not null references public.clubs(id) on delete cascade,
  due_on       date not null,
  amount       numeric(12,2) not null,
  expense_id   uuid references public.expenses(id) on delete set null,
  status       text not null default 'pending',
  created_at   timestamptz not null default now(),
  constraint recurring_occurrence_unique unique (recurring_id, due_on)
);

do $blk$ begin
  alter table public.recurring_occurrences
    add constraint recurring_occurrence_status_check
    check (status in ('pending', 'recorded', 'skipped'));
exception when duplicate_object then null; end $blk$;

create index if not exists idx_recurring_occ_club_due
  on public.recurring_occurrences (club_id, status, due_on);

alter table public.recurring_occurrences enable row level security;

drop policy if exists "recurring_occ_read" on public.recurring_occurrences;
create policy "recurring_occ_read" on public.recurring_occurrences for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

drop policy if exists "recurring_occ_write" on public.recurring_occurrences;
create policy "recurring_occ_write" on public.recurring_occurrences for all
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id))
  with check (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- Gider hangi taahhütten doğdu.
alter table public.expenses
  add column if not exists recurring_id uuid references public.recurring_expenses(id) on delete set null;

-- ---------------------------------------------------------------------------
-- VADE ÜRETİMİ
--
-- Vadeler `starts_on`'dan türüyor; Postgres ay eklemede ay sonunu kendisi
-- kırpıyor (31 Ocak + 1 ay = 28 Şubat), bu yüzden elle gün hesabı yok.
--
-- Pencere bilerek dar: geçmişe 90 gün, geleceğe 60 gün. Beş yıl önce
-- başlamış aylık bir taahhüt için altmış vade geriye dönük üretmek, iş
-- kuyruğunu ilk çalıştırmada anlamsız biçimde dolduruyordu.
-- ---------------------------------------------------------------------------
create or replace function public.generate_recurring_occurrences()
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_n int := 0;
begin
  with step as (
    select r.id, r.club_id, r.amount, r.starts_on, r.ends_on,
           (case r.frequency
              when 'monthly'   then 1
              when 'quarterly' then 3
              when 'yearly'    then 12
              else greatest(coalesce(r.interval_months, 1), 1)
            end) as months
      from public.recurring_expenses r
     where r.active
       and r.starts_on <= current_date + 60
       and (r.ends_on is null or r.ends_on >= current_date - 90)
  ),
  dates as (
    select s.id, s.club_id, s.amount, d::date as due_on
      from step s,
           lateral generate_series(
             s.starts_on::timestamp,
             least(coalesce(s.ends_on, current_date + 60),
                   current_date + 60)::timestamp,
             (s.months || ' months')::interval) as d
     where d::date >= current_date - 90
  ),
  ins as (
    insert into public.recurring_occurrences
      (recurring_id, club_id, due_on, amount)
    select dt.id, dt.club_id, dt.due_on, dt.amount from dates dt
    on conflict (recurring_id, due_on) do nothing
    returning 1
  )
  select count(*) into v_n from ins;

  return v_n;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- VADEYİ GİDERE ÇEVİR
--
-- Otomatik gider yazılmıyor — vade geldi diye para çıktığını varsaymak
-- defteri gerçekle ayırırdı. Kullanıcı "ödendi" dediğinde gider oluşuyor.
-- ---------------------------------------------------------------------------
create or replace function public.record_recurring_occurrence(
  p_occurrence uuid,
  p_amount     numeric default null,
  p_account    uuid default null,
  p_spent_on   date default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_occ  public.recurring_occurrences%rowtype;
  v_rec  public.recurring_expenses%rowtype;
  v_id   uuid;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_occ from public.recurring_occurrences where id = p_occurrence;
  if v_occ.id is null then
    raise exception 'Vade kaydı bulunamadı';
  end if;

  if not (public.is_club_staff(v_occ.club_id)
          or public.is_club_accountant(v_occ.club_id)) then
    raise exception 'Bu kulüpte gider kaydetme yetkiniz yok';
  end if;

  -- Idempotent: ikinci çağrı var olan gideri döndürüyor, yenisini yazmıyor.
  if v_occ.expense_id is not null then
    return v_occ.expense_id;
  end if;

  select * into v_rec from public.recurring_expenses where id = v_occ.recurring_id;

  insert into public.expenses
    (club_id, category_id, account_id, vendor_id, amount, spent_on, note,
     status, entered_by, recurring_id, team_id, facility_id, event_id)
  values (v_occ.club_id, v_rec.category_id,
          coalesce(p_account, v_rec.account_id), v_rec.vendor_id,
          coalesce(p_amount, v_occ.amount),
          coalesce(p_spent_on, v_occ.due_on),
          v_rec.title,
          'complete', auth.uid(), v_rec.id,
          v_rec.team_id, v_rec.facility_id, v_rec.event_id)
  returning id into v_id;

  update public.recurring_occurrences
     set expense_id = v_id, status = 'recorded'
   where id = p_occurrence;

  return v_id;
end;
$fn$;

revoke execute on function public.record_recurring_occurrence(uuid, numeric, uuid, date)
  from public, anon;
grant execute on function public.record_recurring_occurrence(uuid, numeric, uuid, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- TAAHHÜT İPTALİ
--
-- Geçmiş silinmiyor. `active = false` yalnızca **gelecek** vade üretimini
-- durduruyor; kaydedilmiş giderler ve geçmiş vadeler yerinde kalıyor.
-- Bekleyen gelecek vadeler `skipped`'a çekiliyor ki iş kuyruğunda
-- görünmesinler.
-- ---------------------------------------------------------------------------
create or replace function public.cancel_recurring_expense(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_club uuid;
begin
  select club_id into v_club from public.recurring_expenses where id = p_id;
  if v_club is null then
    raise exception 'Taahhüt bulunamadı';
  end if;

  if not public.is_club_staff(v_club) then
    raise exception 'Taahhüdü yalnızca kulüp yöneticisi durdurabilir';
  end if;

  update public.recurring_expenses set active = false where id = p_id;

  update public.recurring_occurrences
     set status = 'skipped'
   where recurring_id = p_id
     and status = 'pending'
     and due_on > current_date;
end;
$fn$;

revoke execute on function public.cancel_recurring_expense(uuid) from public, anon;
grant execute on function public.cancel_recurring_expense(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- VADE HATIRLATMASI
--
-- Mevcut `reminder_log` kullanılıyor, ikinci bir tekillik mekanizması
-- kurulmuyor. Anahtar `(kind, entity_id, profile_id, sent_on)`; aynı vade
-- için aynı kişiye aynı gün ikinci bildirim gitmiyor.
--
-- Üç aşama: 7 gün kala, 3 gün kala, vade geçtiğinde. `send_fee_reminders`
-- ile aynı desen.
-- ---------------------------------------------------------------------------
create or replace function public.send_commitment_reminders()
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_n int := 0;
begin
  with due as (
    select o.id, o.club_id, o.due_on, o.amount, r.title,
           case
             when o.due_on = current_date + 7 then 'yaklaşıyor'
             when o.due_on = current_date + 3 then 'yakın'
             else 'gecikti'
           end as phase
      from public.recurring_occurrences o
      join public.recurring_expenses r on r.id = o.recurring_id
     where o.status = 'pending'
       and o.due_on in (current_date + 7, current_date + 3, current_date)
  ),
  targets as (
    -- Kulüp yöneticileri. Antrenör ve görevliye gitmiyor: taahhüt ödemesi
    -- onların işi değil ve ilgisiz bildirim, bildirimlerin tamamını
    -- okunmaz yapıyor.
    --
    -- `status = 'active'` şart: üyeliği kaldırılmış yönetici hâlâ kulübün
    -- mali bildirimini alırdı. `distinct` de şart — aynı kişi farklı
    -- takımlarda ikinci bir club_admin satırı taşıyabiliyor
    -- (`unique (club_id, profile_id, role, team_id)`).
    select distinct d.id as occ_id, m.profile_id, d.title, d.amount, d.phase,
           d.due_on, c.name as club_name
      from due d
      join public.club_memberships m
        on m.club_id = d.club_id
       and m.role = 'club_admin'
       and m.status = 'active'
      join public.clubs c on c.id = d.club_id
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'commitment', t.occ_id, t.profile_id from targets t
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'commitment_due',
           case t.phase
             when 'yaklaşıyor' then 'Taahhüt ödemesi bir hafta sonra'
             when 'yakın'      then 'Taahhüt ödemesine 3 gün kaldı'
             else 'Taahhüt ödemesinin vadesi bugün'
           end,
           t.club_name || ' · ' || t.title || ' · ' ||
             trim(to_char(t.amount, 'FM999G999G999')) || ' TL',
           'recurring_occurrence', f.entity_id
      from fresh f
      join targets t
        on t.occ_id = f.entity_id and t.profile_id = f.profile_id
    returning 1
  )
  select count(*) into v_n from sent;

  return v_n;
end;
$fn$;

-- Vade üretimi ve hatırlatma her sabah. `send_fee_reminders` 09:00'da
-- çalışıyor; taahhüt 08:30'da, önce vadeler üretilsin diye.
-- `cron.schedule` aynı iş adıyla çağrıldığında üzerine yazıyor; tekrar
-- çalıştırmak zararsız. 0022'deki desenin aynısı — `cron.job` tablosunu
-- okumaya kalkmak superuser olmayan rolde izin hatası veriyor.
select cron.schedule(
  'swansport_recurring_generate', '0 5 * * *',
  $cron$select public.generate_recurring_occurrences();$cron$);

select cron.schedule(
  'swansport_commitment_reminders', '30 5 * * *',
  $cron$select public.send_commitment_reminders();$cron$);

-- ===========================================================================
-- 0057_expense_approvals.sql
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 0057 — Gider onay politikaları
--
-- Harcama limiti `club_settings`'e ya da `club_memberships`'e sıkıştırılmıyor.
-- Sebebi: limit tek bir sayı değil — tutar aralığı, kategori, kaç onay,
-- hangi roller ve geçerlilik dönemi. Bunlar bir satırlık ayar değil, bir
-- politika; kendi tablosunu hak ediyor.
-- ---------------------------------------------------------------------------

create table if not exists public.expense_approval_policies (
  id                 uuid primary key default gen_random_uuid(),
  club_id            uuid not null references public.clubs(id) on delete cascade,
  label              text not null,
  min_amount         numeric(12,2) not null default 0,
  -- null = üst sınır yok. Politikanın en üst dilimi bu.
  max_amount         numeric(12,2),
  -- null = tüm kategoriler.
  category_id        uuid references public.expense_categories(id) on delete cascade,
  required_approvals int not null default 1,
  -- Kimler onaylayabilir. Varsayılan yalnızca kulüp yöneticisi.
  approver_roles     public.club_role[] not null default array['club_admin']::public.club_role[],
  reminder_hours     int not null default 48,
  valid_from         date,
  valid_to           date,
  active             boolean not null default true,
  created_by         uuid references public.profiles(id) on delete set null,
  created_at         timestamptz not null default now()
);

do $blk$ begin
  alter table public.expense_approval_policies
    add constraint expense_policy_range_check
    check (max_amount is null or max_amount > min_amount);
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.expense_approval_policies
    add constraint expense_policy_count_check
    check (required_approvals between 1 and 5);
exception when duplicate_object then null; end $blk$;

create index if not exists idx_expense_policy_club
  on public.expense_approval_policies (club_id, active, min_amount);

alter table public.expense_approval_policies enable row level security;

drop policy if exists "expense_policy_read" on public.expense_approval_policies;
create policy "expense_policy_read" on public.expense_approval_policies for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- Politikayı yalnızca kulüp yöneticisi kurar. Muhasebeci kendi onay
-- eşiğini yükseltebilseydi, denetim mekanizmasını kendisi kapatabilirdi.
drop policy if exists "expense_policy_write" on public.expense_approval_policies;
create policy "expense_policy_write" on public.expense_approval_policies for all
  to authenticated
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));

-- ---------------------------------------------------------------------------
-- ONAY OYLARI
--
-- Silinmiyor: `expense_approvals` satırı bir kez yazıldıktan sonra
-- politika DELETE'e izin vermiyor. Onay geçmişi denetim izinin parçası.
-- ---------------------------------------------------------------------------
create table if not exists public.expense_approvals (
  id          uuid primary key default gen_random_uuid(),
  expense_id  uuid not null references public.expenses(id) on delete cascade,
  club_id     uuid not null references public.clubs(id) on delete cascade,
  approver_id uuid not null references public.profiles(id) on delete cascade,
  decision    text not null,
  reason      text,
  created_at  timestamptz not null default now(),
  -- Bir kişi bir gidere bir kez oy verir.
  constraint expense_approval_once unique (expense_id, approver_id)
);

do $blk$ begin
  alter table public.expense_approvals
    add constraint expense_approval_decision_check
    check (decision in ('approve', 'reject'));
exception when duplicate_object then null; end $blk$;

-- Redde gerekçe zorunlu. Gerekçesiz red, kaydı giren kişiye ne
-- düzelteceğini söylemiyor ve kayıt kuyrukta çürüyor.
do $blk$ begin
  alter table public.expense_approvals
    add constraint expense_approval_reject_needs_reason
    check (decision <> 'reject' or coalesce(trim(reason), '') <> '');
exception when duplicate_object then null; end $blk$;

create index if not exists idx_expense_approval_expense
  on public.expense_approvals (expense_id, created_at);

alter table public.expense_approvals enable row level security;

drop policy if exists "expense_approval_read" on public.expense_approvals;
create policy "expense_approval_read" on public.expense_approvals for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));
-- INSERT/UPDATE/DELETE politikası bilerek yok: yazma yalnızca RPC'den.

-- ---------------------------------------------------------------------------
-- GİDER ALANLARI
-- ---------------------------------------------------------------------------
alter table public.expenses
  add column if not exists approval_status text not null default 'not_required',
  add column if not exists submitted_at    timestamptz,
  add column if not exists rejected_reason text;

do $blk$ begin
  alter table public.expenses
    add constraint expenses_approval_status_check
    check (approval_status in ('not_required', 'pending', 'approved', 'rejected'));
exception when duplicate_object then null; end $blk$;

create index if not exists idx_expenses_approval
  on public.expenses (club_id, approval_status)
  where approval_status = 'pending';

-- ---------------------------------------------------------------------------
-- POLİTİKA SEÇİMİ
--
-- Tutara ve kategoriye uyan en dar politika kazanır: kategoriye özel olan,
-- genel olandan önce. İki politika aynı aralığı kapsıyorsa daha yüksek
-- `min_amount` olan seçiliyor — kulüp üst dilimi bilerek daraltmış demektir.
-- ---------------------------------------------------------------------------
create or replace function public.expense_policy_for(
  p_club uuid, p_amount numeric, p_category uuid)
returns public.expense_approval_policies
language sql
stable
security definer
set search_path = public
as $fn$
  select p.*
    from public.expense_approval_policies p
   where p.club_id = p_club
     and p.active
     and p_amount >= p.min_amount
     and (p.max_amount is null or p_amount < p.max_amount)
     and (p.category_id is null or p.category_id = p_category)
     and (p.valid_from is null or p.valid_from <= current_date)
     and (p.valid_to   is null or p.valid_to   >= current_date)
   order by (p.category_id is not null) desc, p.min_amount desc
   limit 1;
$fn$;

revoke execute on function public.expense_policy_for(uuid, numeric, uuid)
  from public, anon;
grant execute on function public.expense_policy_for(uuid, numeric, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- ONAYA GÖNDER
--
-- Politika yoksa onay gerekmiyor: kulüp bir eşik tanımlamadıysa sistem
-- kendiliğinden onay dayatmıyor. Bayrak gibi burada da varsayılanı
-- kısıtlayıcı yapmak, hiçbir gider kaydedilemez hâle getirirdi.
-- ---------------------------------------------------------------------------
create or replace function public.submit_expense_for_approval(p_expense uuid)
returns text
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_exp    public.expenses%rowtype;
  v_policy public.expense_approval_policies%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_exp from public.expenses where id = p_expense;
  if v_exp.id is null then
    raise exception 'Gider bulunamadı';
  end if;

  if not (public.is_club_staff(v_exp.club_id)
          or public.is_club_accountant(v_exp.club_id)) then
    raise exception 'Bu gideri onaya gönderme yetkiniz yok';
  end if;

  v_policy := public.expense_policy_for(v_exp.club_id, v_exp.amount,
                                        v_exp.category_id);

  if v_policy.id is null then
    update public.expenses
       set approval_status = 'not_required', status = 'complete'
     where id = p_expense;
    return 'not_required';
  end if;

  update public.expenses
     set approval_status = 'pending',
         submitted_at = now(),
         rejected_reason = null
   where id = p_expense;

  return 'pending';
end;
$fn$;

revoke execute on function public.submit_expense_for_approval(uuid) from public, anon;
grant execute on function public.submit_expense_for_approval(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- ONAY / RED
--
-- İKİ KURAL:
--
-- 1. Kendi girdiği gideri kimse onaylayamaz. "Tek başına nihai onay
--    veremez" kuralını uygularken oyu saymayıp yine de kabul etmek,
--    tek yöneticili kulüpte sessiz kilitlenme üretirdi; açık hata mesajı
--    vermek dürüst olan. Tek yöneticili kulüp eşiği yükselterek çözer.
--
-- 2. Rol kontrolü politikadan geliyor. `is_club_staff` yetmiyor: antrenör
--    de kulüp personeli ama politika yalnızca `club_admin` diyorsa
--    onaylayamamalı.
-- ---------------------------------------------------------------------------
create or replace function public.decide_expense_approval(
  p_expense uuid,
  p_approve boolean,
  p_reason  text default null)
returns text
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_exp    public.expenses%rowtype;
  v_policy public.expense_approval_policies%rowtype;
  v_ok     int;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_exp from public.expenses where id = p_expense;
  if v_exp.id is null then
    raise exception 'Gider bulunamadı';
  end if;

  if v_exp.approval_status <> 'pending' then
    raise exception 'Bu gider onay beklemiyor';
  end if;

  if v_exp.entered_by = auth.uid() then
    raise exception 'Kendi girdiğiniz gideri siz onaylayamazsınız; '
                    'başka bir yetkili onaylamalı';
  end if;

  v_policy := public.expense_policy_for(v_exp.club_id, v_exp.amount,
                                        v_exp.category_id);
  if v_policy.id is null then
    raise exception 'Bu gidere uyan onay politikası yok';
  end if;

  if not exists (
    select 1 from public.club_memberships m
     where m.club_id = v_exp.club_id
       and m.profile_id = auth.uid()
       and m.status = 'active'
       and m.role = any (v_policy.approver_roles)) then
    raise exception 'Bu tutarı onaylama yetkiniz yok';
  end if;

  if not p_approve and coalesce(trim(p_reason), '') = '' then
    raise exception 'Red için gerekçe zorunlu';
  end if;

  insert into public.expense_approvals
    (expense_id, club_id, approver_id, decision, reason)
  values (p_expense, v_exp.club_id, auth.uid(),
          case when p_approve then 'approve' else 'reject' end,
          nullif(trim(coalesce(p_reason, '')), ''))
  on conflict (expense_id, approver_id) do nothing;

  if not p_approve then
    update public.expenses
       set approval_status = 'rejected',
           status = 'draft',
           rejected_reason = trim(p_reason)
     where id = p_expense;

    -- Kaydı giren kişi neden reddedildiğini bilmeli.
    if v_exp.entered_by is not null then
      insert into public.notifications
        (profile_id, kind, title, body, entity_type, entity_id, actor_id)
      values (v_exp.entered_by, 'expense_rejected', 'Gider reddedildi',
              trim(to_char(v_exp.amount, 'FM999G999G999')) || ' TL · ' ||
                trim(p_reason),
              'expense', p_expense, auth.uid());
    end if;

    return 'rejected';
  end if;

  select count(*) into v_ok
    from public.expense_approvals a
   where a.expense_id = p_expense and a.decision = 'approve';

  if v_ok >= v_policy.required_approvals then
    update public.expenses
       set approval_status = 'approved', status = 'complete'
     where id = p_expense;
    return 'approved';
  end if;

  return 'pending';
end;
$fn$;

revoke execute on function public.decide_expense_approval(uuid, boolean, text)
  from public, anon;
grant execute on function public.decide_expense_approval(uuid, boolean, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- BEKLEYEN ONAY HATIRLATMASI
--
-- Politikanın `reminder_hours` süresini aşmış bekleyen giderler için.
-- `reminder_log` günlük tekillik veriyor: aynı gider için aynı kişiye
-- günde bir hatırlatma.
-- ---------------------------------------------------------------------------
create or replace function public.send_approval_reminders()
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_n int := 0;
begin
  with due as (
    -- `expense_policy_for` tek satırlık bileşik dönüyor; eşleşme yoksa
    -- lateral join bütün sütunları NULL veren bir satır üretiyor, o yüzden
    -- `pol.id is not null` süzgeci şart.
    select e.id as expense_id, e.club_id, e.amount, e.entered_by,
           pol.approver_roles
      from public.expenses e
      cross join lateral public.expense_policy_for(
        e.club_id, e.amount, e.category_id) pol
     where e.approval_status = 'pending'
       and e.submitted_at is not null
       and pol.id is not null
       and e.submitted_at
           < now() - make_interval(hours => coalesce(pol.reminder_hours, 48))
  ),
  targets as (
    -- Kaydı giren kişiye "senin onayını bekliyor" demiyoruz: zaten
    -- onaylayamaz.
    select distinct d.expense_id, m.profile_id, d.amount
      from due d
      join public.club_memberships m
        on m.club_id = d.club_id
       and m.status = 'active'
       and m.role = any (d.approver_roles)
     where m.profile_id is distinct from d.entered_by
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'expense_approval', t.expense_id, t.profile_id from targets t
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'expense_approval', 'Gider onayı bekliyor',
           trim(to_char(t.amount, 'FM999G999G999')) ||
             ' TL tutarındaki gider onayınızı bekliyor',
           'expense', f.entity_id
      from fresh f
      join targets t
        on t.expense_id = f.entity_id and t.profile_id = f.profile_id
    returning 1
  )
  select count(*) into v_n from sent;

  return v_n;
end;
$fn$;

select cron.schedule(
  'swansport_approval_reminders', '0 7 * * *',
  $cron$select public.send_approval_reminders();$cron$);

-- ---------------------------------------------------------------------------
-- TASLAĞI TAMAMLA
--
-- Mobilden gelen taslak burada gerçek bir gidere dönüşüyor. Tek RPC olmasının
-- sebebi: tamamlama, onay politikası kontrolü ve denetim kaydı **aynı işlemde**
-- olmalı. Üçünü ayrı çağrıya bölmek, ikincisi başarısız olunca yarım
-- tamamlanmış gider bırakırdı.
--
-- Zorunlu alanlar burada kesiliyor: kategorisiz gider kategori raporunu,
-- hesapsız gider bakiyeyi bozuyor. İkisi de sessizce yanlış rakam üretir.
-- ---------------------------------------------------------------------------
create or replace function public.complete_draft_expense(
  p_expense    uuid,
  p_category   uuid,
  p_account    uuid,
  p_vendor     uuid default null,
  p_amount     numeric default null,
  p_spent_on   date default null,
  p_note       text default null,
  p_receipt    text default null,
  p_team       uuid default null,
  p_facility   uuid default null,
  p_event      uuid default null,
  p_reason     text default null)
returns text
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_exp public.expenses%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_exp from public.expenses where id = p_expense;
  if v_exp.id is null then
    raise exception 'Gider bulunamadı';
  end if;

  if not (public.is_club_staff(v_exp.club_id)
          or public.is_club_accountant(v_exp.club_id)) then
    raise exception 'Bu gideri tamamlama yetkiniz yok';
  end if;

  if p_category is null then
    raise exception 'Kategori zorunlu';
  end if;

  if p_account is null then
    raise exception 'Kasa/banka hesabı zorunlu';
  end if;

  -- Denetim tetikleyicisi bu değişkeni okuyor. `true` = yalnızca bu işlem
  -- boyunca geçerli; oturuma sızmıyor.
  perform set_config('swansport.change_reason',
                     coalesce(nullif(trim(coalesce(p_reason, '')), ''),
                              'taslak tamamlandı'), true);

  update public.expenses
     set category_id  = p_category,
         account_id   = p_account,
         vendor_id    = coalesce(p_vendor, vendor_id),
         amount       = coalesce(p_amount, amount),
         spent_on     = coalesce(p_spent_on, spent_on),
         note         = coalesce(p_note, note),
         receipt_path = coalesce(p_receipt, receipt_path),
         team_id      = coalesce(p_team, team_id),
         facility_id  = coalesce(p_facility, facility_id),
         event_id     = coalesce(p_event, event_id),
         updated_at   = now()
   where id = p_expense;

  -- Onay gerekiyorsa `pending`, gerekmiyorsa doğrudan `complete`.
  return public.submit_expense_for_approval(p_expense);
end;
$fn$;

revoke execute on function public.complete_draft_expense(
  uuid, uuid, uuid, uuid, numeric, date, text, text, uuid, uuid, uuid, text)
  from public, anon;
grant execute on function public.complete_draft_expense(
  uuid, uuid, uuid, uuid, numeric, date, text, text, uuid, uuid, uuid, text)
  to authenticated;

-- ===========================================================================
-- 0058_bank_reconciliation.sql
-- ===========================================================================

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

-- ===========================================================================
-- 0059_budgets_and_forecast.sql
-- ===========================================================================

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

-- ===========================================================================
-- 0060_finance_periods.sql
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 0060 — Mali dönemler, kapanış ve düzeltme
--
-- Kapanış bir bayrak değil, bir KİLİT. Kapanmış dönemde gider/fatura/ödeme
-- değişikliği tetikleyiciyle kesiliyor — arayüzde düğmeyi gizlemek güvenlik
-- değil (AGENTS.md değişmez 4); REST üzerinden doğrudan `update` yine
-- geçerdi ve kapanmış bir ayın rakamı sessizce değişirdi.
--
-- Düzeltme yolu: geçmişi değiştirmek değil, **bugüne ters kayıt yazmak.**
-- Muhasebenin standart yolu bu ve denetim izini bozmayan tek yol.
-- ---------------------------------------------------------------------------

create table if not exists public.finance_periods (
  id          uuid primary key default gen_random_uuid(),
  club_id     uuid not null references public.clubs(id) on delete cascade,
  period_from date not null,
  period_to   date not null,
  status      text not null default 'open',
  closed_by   uuid references public.profiles(id) on delete set null,
  closed_at   timestamptz,
  close_note  text,
  created_by  uuid references public.profiles(id) on delete set null,
  created_at  timestamptz not null default now(),
  constraint finance_period_unique unique (club_id, period_from, period_to)
);

do $blk$ begin
  alter table public.finance_periods
    add constraint finance_period_status_check
    check (status in ('open', 'preparing', 'review', 'closed', 'needs_correction'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.finance_periods
    add constraint finance_period_range_check check (period_to >= period_from);
exception when duplicate_object then null; end $blk$;

create index if not exists idx_finance_period_club
  on public.finance_periods (club_id, period_from desc);

-- Kilit sorgusu her yazma işleminde çalışıyor; indeks olmadan tetikleyici
-- her gider kaydında tam tarama yapardı.
create index if not exists idx_finance_period_closed
  on public.finance_periods (club_id, period_from, period_to)
  where status = 'closed';

alter table public.finance_periods enable row level security;

drop policy if exists "finance_period_read" on public.finance_periods;
create policy "finance_period_read" on public.finance_periods for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- Dönem açmak muhasebeciye de açık; KAPATMAK ve AÇMAK yalnızca RPC'den ve
-- yalnızca kulüp yöneticisine. Doğrudan `update` ile status değiştirmeyi
-- engellemek için burada `for all` yok.
drop policy if exists "finance_period_insert" on public.finance_periods;
create policy "finance_period_insert" on public.finance_periods for insert
  to authenticated
  with check ((public.is_club_staff(club_id) or public.is_club_accountant(club_id))
              and status = 'open');

drop policy if exists "finance_period_update" on public.finance_periods;
create policy "finance_period_update" on public.finance_periods for update
  to authenticated
  using (public.is_club_staff(club_id) and status <> 'closed')
  with check (public.is_club_staff(club_id) and status <> 'closed');

-- ---------------------------------------------------------------------------
-- DÜZELTME KAYITLARI
-- ---------------------------------------------------------------------------
create table if not exists public.finance_adjustments (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id) on delete cascade,
  period_id    uuid references public.finance_periods(id) on delete set null,
  -- Neyi düzeltiyor.
  target_kind  text not null,
  target_id    uuid,
  -- Karşı kayıt: düzeltme sonucu doğan yeni gider/ödeme.
  entry_kind   text,
  entry_id     uuid,
  amount       numeric(12,2) not null,
  reason       text not null,
  status       text not null default 'pending',
  created_by   uuid references public.profiles(id) on delete set null,
  approved_by  uuid references public.profiles(id) on delete set null,
  approved_at  timestamptz,
  created_at   timestamptz not null default now()
);

do $blk$ begin
  alter table public.finance_adjustments
    add constraint finance_adjustment_target_check
    check (target_kind in ('expense', 'payment', 'donation', 'invoice', 'other'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.finance_adjustments
    add constraint finance_adjustment_status_check
    check (status in ('pending', 'approved', 'rejected'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.finance_adjustments
    add constraint finance_adjustment_reason_check
    check (coalesce(trim(reason), '') <> '');
exception when duplicate_object then null; end $blk$;

create index if not exists idx_finance_adjustment_club
  on public.finance_adjustments (club_id, created_at desc);

alter table public.finance_adjustments enable row level security;

drop policy if exists "finance_adjustment_read" on public.finance_adjustments;
create policy "finance_adjustment_read" on public.finance_adjustments for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));
-- Yazma yalnızca RPC'den.

-- ---------------------------------------------------------------------------
-- DÖNEM İŞLEM İZİ
-- ---------------------------------------------------------------------------
create table if not exists public.finance_period_logs (
  id         uuid primary key default gen_random_uuid(),
  -- Nullable: düzeltme kaydı açık bir döneme denk gelmeyebilir. `not null`
  -- olsaydı oraya düzeltmenin kendi kimliğini yazmak gerekirdi ve iz
  -- okunamaz hale gelirdi.
  period_id  uuid,
  club_id    uuid not null references public.clubs(id) on delete cascade,
  actor_id   uuid references public.profiles(id) on delete set null,
  action     text not null,
  note       text,
  created_at timestamptz not null default now()
);

create index if not exists idx_finance_period_log
  on public.finance_period_logs (period_id, created_at desc);

alter table public.finance_period_logs enable row level security;

drop policy if exists "finance_period_log_read" on public.finance_period_logs;
create policy "finance_period_log_read" on public.finance_period_logs for select
  to authenticated
  using (public.is_club_staff(club_id) or public.is_club_accountant(club_id));

-- ---------------------------------------------------------------------------
-- KİLİT
-- ---------------------------------------------------------------------------
create or replace function public.is_period_closed(p_club uuid, p_date date)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.finance_periods
     where club_id = p_club
       and status = 'closed'
       and p_date between period_from and period_to);
$fn$;

create or replace function public.block_closed_period()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_club uuid;
  v_date date;
begin
  -- DELETE'te `old`, diğerlerinde `new` bakılır. Silme de engelleniyor:
  -- kapanmış dönemin hareketi silinemez.
  if tg_op = 'DELETE' then
    v_club := old.club_id;
    v_date := case tg_table_name
                when 'expenses'  then old.spent_on
                when 'payments'  then old.paid_at
                when 'donations' then old.created_at::date
                else old.created_at::date
              end;
  else
    v_club := new.club_id;
    v_date := case tg_table_name
                when 'expenses'  then new.spent_on
                when 'payments'  then new.paid_at
                when 'donations' then new.created_at::date
                else new.created_at::date
              end;
  end if;

  if public.is_period_closed(v_club, v_date) then
    raise exception
      'Bu tarih kapanmış bir mali döneme ait. Değişiklik için düzeltme '
      'kaydı (ters kayıt) oluşturun.'
      using errcode = 'check_violation';
  end if;

  -- UPDATE'te kaydın tarihi kapanmış bir döneme TAŞINAMAZ da.
  if tg_op = 'UPDATE' then
    v_date := case tg_table_name
                when 'expenses'  then old.spent_on
                when 'payments'  then old.paid_at
                else old.created_at::date
              end;
    if public.is_period_closed(v_club, v_date) then
      raise exception 'Kaynak kayıt kapanmış mali döneme ait'
        using errcode = 'check_violation';
    end if;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$fn$;

drop trigger if exists trg_expenses_period_lock on public.expenses;
create trigger trg_expenses_period_lock
  before insert or update or delete on public.expenses
  for each row execute function public.block_closed_period();

drop trigger if exists trg_payments_period_lock on public.payments;
create trigger trg_payments_period_lock
  before insert or update or delete on public.payments
  for each row execute function public.block_closed_period();

drop trigger if exists trg_donations_period_lock on public.donations;
create trigger trg_donations_period_lock
  before insert or update or delete on public.donations
  for each row execute function public.block_closed_period();

-- ---------------------------------------------------------------------------
-- KAPANIŞ KONTROL LİSTESİ
--
-- On madde. `blocking` olanlar giderilmeden dönem kapanmıyor; diğerleri
-- bilgi amaçlı. Kapanışı engellemeyen maddeleri de göstermek gerekiyor:
-- "bütçe sapması" kapanışı durdurmaz ama kapatmadan önce görülmelidir.
-- ---------------------------------------------------------------------------
create or replace function public.period_close_checklist(
  p_club uuid, p_from date, p_to date)
returns table (
  code     text,
  label    text,
  blocking boolean,
  qty      bigint,
  amount   numeric)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if not (public.is_club_staff(p_club) or public.is_club_accountant(p_club)) then
    raise exception 'Bu kulübün kapanış listesini görme yetkiniz yok';
  end if;

  return query
  select 'draft_expense', 'Açık taslak gider', true,
         count(*), coalesce(sum(e.amount), 0)
    from public.expenses e
   where e.club_id = p_club and e.status = 'draft'
     and e.spent_on between p_from and p_to
  union all
  select 'pending_payment', 'Onay bekleyen ödeme bildirimi', true,
         count(*), coalesce(sum(p.amount), 0)
    from public.payments p
   where p.club_id = p_club and p.status = 'pending'
     and p.paid_at between p_from and p_to
  union all
  select 'unlinked', 'Hesaba bağlanmamış hareket', true, count(*),
         coalesce(sum(x.amount), 0)
    from (
      select p.amount from public.payments p
       where p.club_id = p_club and p.status = 'confirmed'
         and p.account_id is null and p.paid_at between p_from and p_to
      union all
      select e.amount from public.expenses e
       where e.club_id = p_club and e.status = 'complete'
         and e.account_id is null and e.spent_on between p_from and p_to
      union all
      select d.amount from public.donations d
       where d.club_id = p_club and d.status = 'confirmed'
         and d.account_id is null
         and d.created_at::date between p_from and p_to) x
  union all
  select 'negative_account', 'Negatif bakiyeli hesap', true, count(*),
         coalesce(sum(b.balance), 0)
    from public.acc_account_balances(p_club) b
   where b.balance < 0
  union all
  select 'bank_import', 'Dönemde banka ekstresi yüklendi mi', false,
         count(*), 0::numeric
    from public.bank_imports i
   where i.club_id = p_club
     and coalesce(i.period_to, i.created_at::date) between p_from and p_to
  union all
  select 'bank_unmatched', 'Eşleşmemiş banka hareketi', true, count(*),
         coalesce(sum(t.amount), 0)
    from public.bank_transactions t
   where t.club_id = p_club and t.match_status = 'unmatched'
     and t.txn_on between p_from and p_to
  union all
  select 'pending_approval', 'Onay bekleyen gider', true, count(*),
         coalesce(sum(e.amount), 0)
    from public.expenses e
   where e.club_id = p_club and e.approval_status = 'pending'
     and e.spent_on between p_from and p_to
  union all
  select 'overdue_fee', 'Gecikmiş tahsilat', false, count(*),
         coalesce(sum(i.amount), 0)
    from public.invoices i
   where i.club_id = p_club and i.status <> 'paid'
     and i.due_date is not null and i.due_date between p_from and p_to
  union all
  -- Aşım tutarı `remaining` negatifken onun mutlak değeri.
  select 'budget_overrun', 'Bütçesi aşılmış satır', false, count(*),
         coalesce(sum(greatest(-v.remaining, 0)), 0)
    from public.budget_vs_actual(p_club, p_from, p_to) v
   where v.risk = 'kritik';
  -- Kapanış notu listede yok: hesaplanan bir kontrol değil, kapatma
  -- diyaloğunda alınan bir girdi. Sıfır adetli sahte satır olarak
  -- döndürmek, listeyi "tamamlanmış madde" gibi kirletiyordu.
end;
$fn$;

revoke execute on function public.period_close_checklist(uuid, date, date)
  from public, anon;
grant execute on function public.period_close_checklist(uuid, date, date)
  to authenticated;

-- ---------------------------------------------------------------------------
-- KAPAT
--
-- Engel varsa kapanmıyor ve hangi maddenin engellediği hata mesajında.
-- "Kapat" düğmesini pasif yapıp sebebi söylememek, kullanıcıyı sistemle
-- güreştiriyor.
-- ---------------------------------------------------------------------------
create or replace function public.close_finance_period(
  p_period uuid, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_p        public.finance_periods%rowtype;
  v_blockers text;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_p from public.finance_periods where id = p_period;
  if v_p.id is null then
    raise exception 'Dönem bulunamadı';
  end if;

  -- Kapatmak muhasebecinin değil kulüp yöneticisinin kararı: kapanış
  -- rakamların nihai olduğunu ilan etmek demek.
  if not public.is_club_staff(v_p.club_id) then
    raise exception 'Dönemi yalnızca kulüp yöneticisi kapatabilir';
  end if;

  if v_p.status = 'closed' then
    raise exception 'Bu dönem zaten kapalı';
  end if;

  select string_agg(c.label || ' (' || c.qty || ')', ', ')
    into v_blockers
    from public.period_close_checklist(v_p.club_id, v_p.period_from, v_p.period_to) c
   where c.blocking and c.qty > 0;

  if v_blockers is not null then
    raise exception 'Kapanış engellendi: %', v_blockers;
  end if;

  update public.finance_periods
     set status = 'closed', closed_by = auth.uid(), closed_at = now(),
         close_note = nullif(trim(coalesce(p_note, '')), '')
   where id = p_period;

  insert into public.finance_period_logs (period_id, club_id, actor_id, action, note)
  values (p_period, v_p.club_id, auth.uid(), 'close', p_note);

  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id)
  select distinct m.profile_id, 'period_closed', 'Mali dönem kapandı',
         to_char(v_p.period_from, 'DD.MM.YYYY') || ' – ' ||
           to_char(v_p.period_to, 'DD.MM.YYYY') || ' dönemi kapatıldı',
         'finance_period', p_period
    from public.club_memberships m
   where m.club_id = v_p.club_id and m.role = 'club_admin'
     and m.status = 'active';
end;
$fn$;

revoke execute on function public.close_finance_period(uuid, text) from public, anon;
grant execute on function public.close_finance_period(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- GERİ AÇ
--
-- Gerekçe zorunlu ve iz bırakıyor. Kapanışı geri almak olağan bir işlem
-- değil; kolaylaştırmak, kapanışın anlamını yok eder.
-- ---------------------------------------------------------------------------
create or replace function public.reopen_finance_period(
  p_period uuid, p_reason text)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_p public.finance_periods%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if coalesce(trim(coalesce(p_reason, '')), '') = '' then
    raise exception 'Dönemi geri açmak için gerekçe zorunlu';
  end if;

  select * into v_p from public.finance_periods where id = p_period;
  if v_p.id is null then
    raise exception 'Dönem bulunamadı';
  end if;

  if not public.is_club_staff(v_p.club_id) then
    raise exception 'Dönemi yalnızca kulüp yöneticisi geri açabilir';
  end if;

  if v_p.status <> 'closed' then
    raise exception 'Bu dönem kapalı değil';
  end if;

  update public.finance_periods
     set status = 'needs_correction', closed_by = null, closed_at = null
   where id = p_period;

  insert into public.finance_period_logs (period_id, club_id, actor_id, action, note)
  values (p_period, v_p.club_id, auth.uid(), 'reopen', trim(p_reason));
end;
$fn$;

revoke execute on function public.reopen_finance_period(uuid, text) from public, anon;
grant execute on function public.reopen_finance_period(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- DÜZELTME KAYDI
--
-- Kapanmış dönemin gideri için **bugüne** ters kayıt yazıyor. Geçmiş
-- satıra dokunmuyor; muhasebenin standart yolu bu.
--
-- Ters gider negatif tutarla değil, ayrı bir düzeltme satırıyla tutuluyor:
-- `expenses.amount` şemada negatif olabilir ama negatif gider, kategori ve
-- bütçe raporlarında sessizce yanlış toplam üretiyordu.
-- ---------------------------------------------------------------------------
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
  v_id     uuid;
  v_period uuid;
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

create or replace function public.approve_finance_adjustment(
  p_id uuid, p_approve boolean, p_note text default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_a public.finance_adjustments%rowtype;
begin
  select * into v_a from public.finance_adjustments where id = p_id;
  if v_a.id is null then
    raise exception 'Düzeltme kaydı bulunamadı';
  end if;

  -- Düzeltmeyi açan kişi kendi kaydını onaylayamaz: gider onayındaki
  -- kuralın aynısı, aynı gerekçeyle.
  if v_a.created_by = auth.uid() then
    raise exception 'Kendi açtığınız düzeltmeyi siz onaylayamazsınız';
  end if;

  if not public.is_club_staff(v_a.club_id) then
    raise exception 'Düzeltmeyi yalnızca kulüp yöneticisi onaylayabilir';
  end if;

  if v_a.status <> 'pending' then
    raise exception 'Bu düzeltme zaten sonuçlanmış';
  end if;

  update public.finance_adjustments
     set status = case when p_approve then 'approved' else 'rejected' end,
         approved_by = auth.uid(), approved_at = now()
   where id = p_id;

  insert into public.finance_period_logs
    (period_id, club_id, actor_id, action, note)
  select v_a.period_id, v_a.club_id, auth.uid(),
         case when p_approve then 'adjustment_approved'
              else 'adjustment_rejected' end,
         coalesce(p_note, v_a.reason);
end;
$fn$;

revoke execute on function public.approve_finance_adjustment(uuid, boolean, text)
  from public, anon;
grant execute on function public.approve_finance_adjustment(uuid, boolean, text)
  to authenticated;

-- ===========================================================================
-- 0061_operations_center.sql
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 0061 — Mali iş kuyruğu, kulüp operasyon merkezi, bildirimler ve bayraklar
--
-- Kaynak tabloların hepsi 0055-0060'ta kurulduğu için özet burada **bir kez**
-- yazılıyor. Her migration'da imza değiştirmek HTTP 300 tuzağını altı kez
-- açardı (AGENTS.md).
--
-- İKİ AYRI ÖZET, BİLEREK:
--
--   acc_operations_summary    → mali. Muhasebeciye AÇIK. Sporcu, veli,
--                               isim ve sportif veri yok.
--   club_operations_summary   → kulüp operasyonu. Yalnızca kulüp personeli.
--                               Üyelik, belge, yoklama, RSVP içeriyor.
--
-- Tek fonksiyonda birleştirip alanları role göre boşaltmak, gizliliği
-- çağıranın doğru parametreyi geçmesine bağlardı. Ayrı fonksiyon, ayrı izin.
-- ---------------------------------------------------------------------------

-- Dönüş tipi değiştiği için `create or replace` yetmez; önce düşür.
drop function if exists public.acc_operations_summary(uuid);

create or replace function public.acc_operations_summary(p_club uuid)
returns table (
  draft_expense_count      bigint,
  draft_expense_total      numeric,
  pending_payment_count    bigint,
  pending_payment_total    numeric,
  overdue_invoice_count    bigint,
  overdue_invoice_total    numeric,
  unlinked_income_count    bigint,
  unlinked_income_total    numeric,
  unlinked_expense_count   bigint,
  unlinked_expense_total   numeric,
  negative_account_count   bigint,
  negative_account_total   numeric,
  missing_receipt_count    bigint,
  commitment_due_count     bigint,
  commitment_due_total     numeric,
  pending_approval_count   bigint,
  pending_approval_total   numeric,
  bank_unmatched_count     bigint,
  bank_unmatched_total     numeric,
  close_blocker_count      bigint)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  -- `security definer` RLS'i atlar; yetki kontrolü gövdede olmak zorunda
  -- (AGENTS.md 0049 dersi). Platform yöneticisi de kapsam dışı bırakıldı:
  -- mali veriye erişimi kulüple ilişkisinden gelmeli.
  if not (public.is_club_staff(p_club) or public.is_club_accountant(p_club)) then
    raise exception 'Bu kulübün mali özetini görme yetkiniz yok';
  end if;

  return query
  with
  draft as (
    select count(*) c, coalesce(sum(e.amount), 0) t
      from public.expenses e
     where e.club_id = p_club and e.status = 'draft'),
  pend_pay as (
    select count(*) c, coalesce(sum(p.amount), 0) t
      from public.payments p
     where p.club_id = p_club and p.status = 'pending'),
  overdue as (
    -- Gecikmiş aidat `invoices`'ten geliyor: vade orada tutuluyor.
    -- `payments` tablosunda `due_date` sütunu YOK ve `unpaid` durumu da yok
    -- (`pending|confirmed|rejected`) — ilk taslak oradan okumaya çalışıyordu
    -- ve çağrıldığı anda patlardı.
    select count(*) c, coalesce(sum(i.amount), 0) t
      from public.invoices i
     where i.club_id = p_club and i.status <> 'paid'
       and i.due_date is not null and i.due_date < current_date),
  unlinked_in as (
    select count(*) c, coalesce(sum(x.amount), 0) t from (
      select p.amount from public.payments p
       where p.club_id = p_club and p.status = 'confirmed'
         and p.account_id is null
      union all
      select d.amount from public.donations d
       where d.club_id = p_club and d.status = 'confirmed'
         and d.account_id is null) x),
  unlinked_out as (
    select count(*) c, coalesce(sum(e.amount), 0) t
      from public.expenses e
     where e.club_id = p_club and e.status = 'complete'
       and e.account_id is null),
  neg as (
    -- Bakiye matematiği burada tekrarlanmıyor. `acc_account_balances` gelir
    -- tarafında `confirmed`, gider tarafında `complete` süzüyor; elle
    -- yeniden yazan ilk taslak taslak ve reddedilenleri de sayıyordu.
    select count(*) c, coalesce(sum(b.balance), 0) t
      from public.acc_account_balances(p_club) b
     where b.balance < 0),
  no_receipt as (
    select count(*) c
      from public.expenses e
     where e.club_id = p_club and e.status = 'complete'
       and coalesce(trim(e.receipt_path), '') = ''),
  commit_due as (
    select count(*) c, coalesce(sum(o.amount), 0) t
      from public.recurring_occurrences o
     where o.club_id = p_club and o.status = 'pending'
       and o.due_on <= current_date + 7),
  approvals as (
    select count(*) c, coalesce(sum(e.amount), 0) t
      from public.expenses e
     where e.club_id = p_club and e.approval_status = 'pending'),
  bank as (
    select count(*) c, coalesce(sum(t.amount), 0) t
      from public.bank_transactions t
     where t.club_id = p_club and t.match_status = 'unmatched'),
  blockers as (
    -- Açık dönemin kapanışını engelleyen madde sayısı. Açık dönem yoksa 0.
    select coalesce((
      select count(*) from public.finance_periods fp
      cross join lateral public.period_close_checklist(
        p_club, fp.period_from, fp.period_to) ck
       where fp.club_id = p_club
         and fp.status in ('open', 'preparing', 'review')
         and current_date > fp.period_to
         and ck.blocking and ck.qty > 0), 0) c)
  select d.c, d.t, pp.c, pp.t, ov.c, ov.t, ui.c, ui.t, uo.c, uo.t,
         n.c, n.t, nr.c, cd.c, cd.t, ap.c, ap.t, bk.c, bk.t, bl.c
    from draft d, pend_pay pp, overdue ov, unlinked_in ui, unlinked_out uo,
         neg n, no_receipt nr, commit_due cd, approvals ap, bank bk,
         blockers bl;
end;
$fn$;

revoke execute on function public.acc_operations_summary(uuid) from public, anon;
grant execute on function public.acc_operations_summary(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- KULÜP OPERASYON MERKEZİ
--
-- Yalnızca kulüp personeli. Muhasebeci BU FONKSİYONU ÇAĞIRAMAZ — içinde
-- üyelik, belge ve yoklama sayıları var ve bunlar sportif/kişisel veri.
--
-- BİLİNEN EKSİK — TESİS ÇAKIŞMASI: planda isteniyor ama hesaplanamıyor.
-- Bu şemada tesis rezervasyonu diye bir tablo yok; `facilities` yalnızca ad,
-- tür ve doluluk yüzdesi tutuyor, `events.place` ise serbest metin. Serbest
-- metin eşleştirerek "çakışma" üretmek, olmayan bir çakışmayı varmış gibi
-- göstermenin en kolay yolu olurdu. Rezervasyon tablosu geldiğinde eklenecek.
-- ---------------------------------------------------------------------------
create or replace function public.club_operations_summary(p_club uuid)
returns table (
  pending_membership_count bigint,
  expiring_document_count  bigint,
  unmarked_event_count     bigint,
  low_rsvp_event_count     bigint,
  open_report_count        bigint,
  pending_store_count      bigint)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if not public.is_club_staff(p_club) then
    raise exception 'Bu kulübün operasyon özetini görme yetkiniz yok';
  end if;

  return query
  with
  memberships as (
    select count(*) c from public.club_applications a
     where a.club_id = p_club and a.status = 'pending'),
  docs as (
    select count(*) c from public.documents d
     where d.club_id = p_club
       and d.expires_on is not null
       and d.expires_on between current_date and current_date + 30),
  unmarked as (
    -- Başlamış ama yoklaması hiç alınmamış etkinlikler, son 14 gün.
    select count(*) c from public.events e
     where e.club_id = p_club
       and e.starts_at < now()
       and e.starts_at > now() - interval '14 days'
       and not exists (select 1 from public.attendance a
                        where a.event_id = e.id)),
  low_rsvp as (
    -- Yaklaşan antrenmanlarda yanıt oranı %50'nin altında. Kadrosu boş
    -- takımlar sayılmıyor: sıfıra bölme ve anlamsız uyarı üretiyordu.
    select count(*) c from public.events e
     where e.club_id = p_club
       and e.starts_at between now() and now() + interval '3 days'
       and e.team_id is not null
       and (select count(*) from public.team_memberships tm
             where tm.team_id = e.team_id) > 0
       and (select count(*) from public.event_rsvps r
             where r.event_id = e.id)::numeric
           < 0.5 * (select count(*) from public.team_memberships tm
                     where tm.team_id = e.team_id)::numeric),
  reports as (
    select count(*) c from public.content_reports r
     where r.status = 'open'
       and public.is_platform_admin()),
  stores as (
    select count(*) c from public.stores s
     where s.status = 'pending'
       and public.is_platform_admin())
  select m.c, d.c, u.c, l.c, rp.c, st.c
    from memberships m, docs d, unmarked u, low_rsvp l, reports rp, stores st;
end;
$fn$;

revoke execute on function public.club_operations_summary(uuid) from public, anon;
grant execute on function public.club_operations_summary(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- BİLDİRİM ROTALARI
--
-- 0052'deki 23 eşlemenin HEPSİ korunuyor, üstüne yedi yeni. Bu fonksiyon beş
-- migration'da baştan yazıldı ve 0039 dört eşlemeyi sessizce düşürdü;
-- belirtisi yok, kullanıcı yanlış ekrana gidiyor. `tools/check_push_routes.py`
-- bunu denetliyor.
-- ---------------------------------------------------------------------------
create or replace function public.push_route(p_kind text, p_entity text)
returns text
language sql
immutable
as $fn$
  select case p_kind
    when 'message'                   then '/mesajlar'
    when 'application'               then '/basvurular'
    when 'offer'                     then '/bildirimler'
    when 'follow'                    then '/bildirimler'
    when 'fee'                       then '/aidatlarim'
    when 'fee_reminder'              then '/aidatlarim'
    when 'payment'                   then '/finans'
    when 'donation'                  then '/bagis'
    when 'attendance'                then '/attendance'
    when 'attendance_reminder'       then '/attendance'
    when 'event'                     then '/calendar'
    when 'announcement'              then '/announcements'
    when 'achievement'               then '/performance-analytics'
    when 'document'                  then '/documents'
    when 'documents'                 then '/documents'
    when 'document_expiry'           then '/documents'
    when 'partner_request'           then '/partner-ara'
    when 'partner_request_accepted'  then '/partner-ara'
    when 'turf_slot_request'         then '/halisahalar'
    when 'turf_field'                then '/halisahalar'
    when 'turf_manager'              then '/halisahalar'
    when 'store_decision'            then '/magaza-basvuru'
    when 'moderation'                then '/pazaryeri'
    -- 0061 — mali operasyon
    when 'expense_approval'          then '/mali-isler'
    when 'expense_rejected'          then '/mali-isler'
    when 'commitment_due'            then '/mali-isler'
    when 'account_negative'          then '/mali-isler'
    when 'bank_unmatched'            then '/mali-isler'
    when 'period_closed'             then '/mali-isler'
    when 'period_blocked'            then '/mali-isler'
    else '/bildirimler'
  end;
$fn$;

-- ---------------------------------------------------------------------------
-- NEGATİF BAKİYE UYARISI
--
-- Günde bir. `reminder_log` tekilliği hesap bazında: aynı hesap için aynı
-- gün ikinci bildirim gitmiyor. Hesap artıya dönerse ertesi gün susuyor.
-- ---------------------------------------------------------------------------
create or replace function public.send_finance_alerts()
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_n int := 0;
begin
  with clubs_with_accounts as (
    select distinct ca.club_id from public.cash_accounts ca where ca.active
  ),
  neg as (
    select c.club_id, b.account_id, b.name, b.balance
      from clubs_with_accounts c
      cross join lateral public.acc_account_balances(c.club_id) b
     where b.balance < 0
  ),
  targets as (
    select distinct n.account_id, n.name, n.balance, m.profile_id
      from neg n
      join public.club_memberships m
        on m.club_id = n.club_id and m.role = 'club_admin'
       and m.status = 'active'
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'account_negative', t.account_id, t.profile_id from targets t
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'account_negative', 'Hesap negatif bakiyede',
           t.name || ' · ' ||
             trim(to_char(t.balance, 'FM999G999G999')) || ' TL',
           'cash_account', f.entity_id
      from fresh f
      join targets t
        on t.account_id = f.entity_id and t.profile_id = f.profile_id
    returning 1
  )
  select count(*) into v_n from sent;

  return v_n;
end;
$fn$;

select cron.schedule(
  'swansport_finance_alerts', '0 8 * * *',
  $cron$select public.send_finance_alerts();$cron$);

-- ---------------------------------------------------------------------------
-- ÖZELLİK BAYRAKLARI — kademeli yayın
--
-- Altısı da `admins`'te başlıyor. Hiçbiri denenmedi; pazaryerinde aynı hata
-- yapıldı (0053 notu) ve bu sefer baştan doğru sıraya konuyor.
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('finance_operations_center', 'admins', 'Mali operasyon merkezi',
   'Mali iş kuyruğu, anonim operasyon özeti ve konsol giriş paneli.'),
  ('recurring_expenses', 'admins', 'Tekrarlayan giderler',
   'Kira, lisans, bakım gibi düzenli giderler ve vade uyarıları.'),
  ('bank_reconciliation', 'admins', 'Banka mutabakatı',
   'CSV ekstre yükleme ve defter kayıtlarıyla eşleştirme.'),
  ('club_budgeting', 'admins', 'Bütçe ve nakit tahmini',
   'Kulüp/takım/tesis/etkinlik bütçesi ve 30-60-90 gün nakit tahmini.'),
  ('period_closing', 'admins', 'Dönem kapanışı',
   'Mali dönem kapanışı, kontrol listesi ve düzeltme kayıtları.'),
  ('club_operations_center', 'admins', 'Kulüp operasyon merkezi',
   'Mali ve sportif bekleyen işlerin tek kuyrukta birleşimi.')
on conflict (key) do nothing;

-- ===========================================================================
-- 0062_social_upgrade.sql
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 0062 — Sosyal katman: görünürlük, çoklu fotoğraf, kaydedilenler, repost,
--        etiketleme ve çocuk gizliliği
--
-- GÜVENLİK NOTU — `posts_read` `using (true)` idi.
--
-- 0006'dan beri giriş yapmış herkes bütün gönderileri okuyabiliyordu. Kulüp
-- içi bir duyuru da, engellediğin kişinin gönderisi de dahil. Bu migration
-- politikayı görünürlük seviyesine ve engelleme durumuna bağlıyor.
-- `community_read` ile aynı hata, aynı düzeltme (0045).
--
-- ÇOCUK GİZLİLİĞİ: reşit olmayan hesaplarda görünürlük varsayılanı `public`
-- değil `followers`. Varsayılanı geniş tutup "isterse daraltır" demek,
-- kararı hiç vermemiş bir çocuğu en açık ayarda bırakırdı.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) GÖRÜNÜRLÜK VE DURUM
-- ---------------------------------------------------------------------------
alter table public.posts
  add column if not exists visibility   text not null default 'public',
  add column if not exists status       text not null default 'active',
  add column if not exists team_id      uuid references public.teams(id) on delete set null,
  add column if not exists repost_of_id uuid references public.posts(id) on delete set null,
  add column if not exists quote_of_id  uuid references public.posts(id) on delete set null,
  add column if not exists like_count   int not null default 0,
  add column if not exists edited_at    timestamptz;

do $blk$ begin
  alter table public.posts add constraint posts_visibility_check
    check (visibility in ('public', 'followers', 'club', 'team', 'private_draft'));
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.posts add constraint posts_status_check
    check (status in ('active', 'comments_closed', 'under_review',
                      'hidden_by_moderation', 'deleted_by_owner'));
exception when duplicate_object then null; end $blk$;

-- Bir gönderi hem repost hem alıntı olamaz: ikisi farklı şeyler ve ikisini
-- birden taşıyan satır hangi kartın çizileceğini belirsiz bırakırdı.
do $blk$ begin
  alter table public.posts add constraint posts_repost_xor_quote
    check (repost_of_id is null or quote_of_id is null);
exception when duplicate_object then null; end $blk$;

-- Kulüp/takım görünürlüğü kimliksiz olamaz; olursa gönderi kimseye
-- görünmez ve yazan kişi sebebini anlamaz.
do $blk$ begin
  alter table public.posts add constraint posts_scope_needs_id
    check (visibility <> 'club' or club_id is not null);
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.posts add constraint posts_team_needs_id
    check (visibility <> 'team' or team_id is not null);
exception when duplicate_object then null; end $blk$;

create index if not exists idx_posts_feed
  on public.posts (created_at desc) where status = 'active';
create index if not exists idx_posts_repost
  on public.posts (repost_of_id) where repost_of_id is not null;

-- Aynı kişi aynı gönderiyi iki kez repost edemez. Alıntı sınırsız —
-- alıntının her biri farklı bir yorum taşıyor, repost yalnızca bir sinyal.
create unique index if not exists idx_posts_repost_once
  on public.posts (author_profile_id, repost_of_id)
  where repost_of_id is not null;

-- ---------------------------------------------------------------------------
-- 2) ÇOCUK GİZLİLİĞİ
--
-- Reşit olmama iki kaynaktan anlaşılıyor:
--   • `guardians` bağlantısı — bu sistemde velisi olan hesap çocuk hesabıdır
--   • `athletes.birth_date` 18 yaşın altı
--
-- İkisi birlikte çünkü tek başına hiçbiri yetmiyor: velisi henüz
-- bağlanmamış bir çocuk da, doğum tarihi girilmemiş bir sporcu da var.
-- ---------------------------------------------------------------------------
create or replace function public.is_minor_profile(p_profile uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1 from public.guardians g where g.profile_id is not null
       and exists (select 1 from public.athletes a
                    where a.id = g.athlete_id and a.profile_id = p_profile))
      or exists (
    select 1 from public.athletes a
     where a.profile_id = p_profile
       and a.birth_date is not null
       and a.birth_date > (current_date - interval '18 years'));
$fn$;

comment on function public.is_minor_profile(uuid) is
  'Reşit olmayan hesap. Sosyal görünürlük varsayılanı bu hesaplarda '
  'daraltılıyor ve dış paylaşım kapalı başlıyor.';

alter table public.profiles
  -- Etiketlenme izni: everyone | following | nobody
  add column if not exists mention_policy text not null default 'everyone',
  -- Dış paylaşım (uygulama dışına link çıkarma). Çocuk hesaplarda kapalı.
  add column if not exists allow_external_share boolean not null default true;

do $blk$ begin
  alter table public.profiles add constraint profiles_mention_policy_check
    check (mention_policy in ('everyone', 'following', 'nobody'));
exception when duplicate_object then null; end $blk$;

-- Yeni gönderide görünürlük varsayılanını çocuk hesaplarda daraltıyor.
create or replace function public.default_post_visibility()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  -- Yalnızca kullanıcı bilinçli bir seçim yapmadıysa (varsayılan `public`
  -- geldiyse) müdahale ediliyor. Açıkça `club` seçen bir çocuk hesabının
  -- tercihi ezilmiyor.
  if new.visibility = 'public'
     and public.is_minor_profile(new.author_profile_id) then
    new.visibility := 'followers';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_post_default_visibility on public.posts;
create trigger trg_post_default_visibility
  before insert on public.posts
  for each row execute function public.default_post_visibility();

-- ---------------------------------------------------------------------------
-- 3) GÖRÜNÜRLÜK KONTROLÜ
--
-- Tek fonksiyon: hem RLS politikası hem paylaşım kartı bunu çağırıyor.
-- İki yerde ayrı kural yazmak, ikisinin ayrışması demek — ve ayrıştığında
-- sızan taraf hep politikanın gevşek olanı oluyor.
-- ---------------------------------------------------------------------------
create or replace function public.can_view_post(p_post uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1
      from public.posts p
     where p.id = p_post
       -- Silinmiş ve moderasyonla gizlenmiş içerik kimseye görünmüyor;
       -- sahibi ve platform yöneticisi hariç.
       and (p.status not in ('deleted_by_owner', 'hidden_by_moderation',
                             'under_review')
            or p.author_profile_id = auth.uid()
            or public.is_platform_admin())
       -- Taslak yalnızca sahibinde.
       and (p.visibility <> 'private_draft'
            or p.author_profile_id = auth.uid())
       -- Engelleme iki yönlü.
       and not public.is_blocked_between(auth.uid(), p.author_profile_id)
       and (
         p.author_profile_id = auth.uid()
         or public.is_platform_admin()
         or (p.visibility = 'public')
         -- `follows` polimorfik: (target_type, target_id). Kulüp takibi de
         -- aynı tabloda, o yüzden `target_type = 'profile'` şart.
         or (p.visibility = 'followers' and exists (
               select 1 from public.follows f
                where f.follower_id = auth.uid()
                  and f.target_type = 'profile'
                  and f.target_id = p.author_profile_id))
         or (p.visibility = 'club' and public.is_club_member(p.club_id))
         or (p.visibility = 'team' and exists (
               select 1 from public.team_memberships tm
                join public.athletes a on a.id = tm.athlete_id
               where tm.team_id = p.team_id and a.profile_id = auth.uid())
             or (p.visibility = 'team' and public.is_club_staff(p.club_id)))
       ));
$fn$;

-- Politikayı sıkılaştır. `using (true)` gitti.
drop policy if exists "posts_read" on public.posts;
create policy "posts_read" on public.posts for select
  to authenticated
  using (
    -- Kendi gönderin her zaman görünür (taslak dahil).
    author_profile_id = auth.uid()
    or public.is_platform_admin()
    or (
      status = 'active'
      and visibility <> 'private_draft'
      and not public.is_blocked_between(auth.uid(), author_profile_id)
      and (
        visibility = 'public'
        or (visibility = 'followers' and exists (
              select 1 from public.follows f
               where f.follower_id = auth.uid()
                 and f.target_type = 'profile'
                 and f.target_id = posts.author_profile_id))
        or (visibility = 'club' and public.is_club_member(posts.club_id))
        or (visibility = 'team' and (
              public.is_club_staff(posts.club_id)
              or exists (select 1 from public.team_memberships tm
                          join public.athletes a on a.id = tm.athlete_id
                         where tm.team_id = posts.team_id
                           and a.profile_id = auth.uid()))))
    ));

-- ---------------------------------------------------------------------------
-- 4) ÇOKLU FOTOĞRAF
--
-- Storage YOLU tutuluyor, URL değil: bucket ya da alan adı değişince
-- saklanmış URL'ler kırılırdı (pazaryerinde aynı karar, 0050).
-- ---------------------------------------------------------------------------
create table if not exists public.post_media (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.posts(id) on delete cascade,
  media_path text not null,
  sort_order int not null default 0,
  width      int,
  height     int,
  created_at timestamptz not null default now(),
  constraint post_media_order_unique unique (post_id, sort_order)
);

do $blk$ begin
  alter table public.post_media add constraint post_media_order_range
    check (sort_order between 0 and 7);
exception when duplicate_object then null; end $blk$;

create index if not exists idx_post_media_post
  on public.post_media (post_id, sort_order);

-- Sekiz görsel sınırı. `sort_order 0-7` kısıtı tek başına yetmiyor:
-- aynı sırayı boşaltıp yeniden kullanan bir istemci sınırı aşabilirdi.
-- Pazaryerinde de aynı ikili koruma var (0050).
create or replace function public.check_post_media_limit()
returns trigger
language plpgsql
as $fn$
begin
  if (select count(*) from public.post_media where post_id = new.post_id) >= 8 then
    raise exception 'Bir gönderiye en fazla 8 fotoğraf eklenebilir';
  end if;
  return new;
end;
$fn$;

drop trigger if exists trg_post_media_limit on public.post_media;
create trigger trg_post_media_limit
  before insert on public.post_media
  for each row execute function public.check_post_media_limit();

alter table public.post_media enable row level security;

drop policy if exists "post_media_read" on public.post_media;
create policy "post_media_read" on public.post_media for select
  to authenticated using (public.can_view_post(post_id));

drop policy if exists "post_media_write" on public.post_media;
create policy "post_media_write" on public.post_media for all
  to authenticated
  using (exists (select 1 from public.posts p
                  where p.id = post_id and p.author_profile_id = auth.uid()))
  with check (exists (select 1 from public.posts p
                       where p.id = post_id and p.author_profile_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- 5) KAYDEDİLENLER
--
-- Tamamen kişiye özel. Gönderi sahibine sosyal sinyal olarak GİTMİYOR:
-- "kim kaydetti" bilgisi, kaydetmeyi kişisel bir yer imi olmaktan çıkarıp
-- kamusal bir beğeniye çevirirdi.
-- ---------------------------------------------------------------------------
create table if not exists public.saved_posts (
  profile_id uuid not null references public.profiles(id) on delete cascade,
  post_id    uuid not null references public.posts(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (profile_id, post_id)
);

create index if not exists idx_saved_posts_profile
  on public.saved_posts (profile_id, created_at desc);

alter table public.saved_posts enable row level security;

-- Yalnızca kendi kayıtların. Başkasınınkini okumanın yolu yok.
drop policy if exists "saved_posts_own" on public.saved_posts;
create policy "saved_posts_own" on public.saved_posts for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 6) ETİKETLEME (@mention)
--
-- Metindeki `@kullanıcıadı` yalnızca görünüm; ilişki profil UUID'siyle
-- saklanıyor. Kullanıcı adını saklasaydık ad değiştiğinde etiket kopardı.
-- ---------------------------------------------------------------------------
create table if not exists public.post_mentions (
  post_id              uuid not null references public.posts(id) on delete cascade,
  mentioned_profile_id uuid not null references public.profiles(id) on delete cascade,
  created_at           timestamptz not null default now(),
  primary key (post_id, mentioned_profile_id)
);

create index if not exists idx_post_mentions_profile
  on public.post_mentions (mentioned_profile_id, created_at desc);

create or replace function public.check_post_mention_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_author uuid;
  v_policy text;
begin
  if (select count(*) from public.post_mentions
       where post_id = new.post_id) >= 10 then
    raise exception 'Bir gönderide en fazla 10 kişi etiketlenebilir';
  end if;

  select author_profile_id into v_author from public.posts
   where id = new.post_id;

  -- Engellenen kişi etiketlenemez ve etiketleyemez.
  if public.is_blocked_between(v_author, new.mentioned_profile_id) then
    raise exception 'Bu kişi etiketlenemez';
  end if;

  select mention_policy into v_policy from public.profiles
   where id = new.mentioned_profile_id;

  if v_policy = 'nobody' and new.mentioned_profile_id <> v_author then
    raise exception 'Bu kişi etiketlenmeyi kapatmış';
  end if;

  if v_policy = 'following' and new.mentioned_profile_id <> v_author
     and not exists (select 1 from public.follows f
                      where f.follower_id = new.mentioned_profile_id
                        and f.target_type = 'profile'
                        and f.target_id = v_author) then
    raise exception 'Bu kişi yalnızca takip ettiklerinin etiketlemesine açık';
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_post_mention_guard on public.post_mentions;
create trigger trg_post_mention_guard
  before insert on public.post_mentions
  for each row execute function public.check_post_mention_limit();

alter table public.post_mentions enable row level security;

drop policy if exists "post_mentions_read" on public.post_mentions;
create policy "post_mentions_read" on public.post_mentions for select
  to authenticated using (public.can_view_post(post_id));

drop policy if exists "post_mentions_write" on public.post_mentions;
create policy "post_mentions_write" on public.post_mentions for all
  to authenticated
  using (exists (select 1 from public.posts p
                  where p.id = post_id and p.author_profile_id = auth.uid()))
  with check (exists (select 1 from public.posts p
                       where p.id = post_id and p.author_profile_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- 7) HASHTAG
--
-- `tr_fold` ile saklanıyor (0048): `#Işıklar` ve `#isiklar` aynı etiket.
-- İstemcideki `trFold` ile aynı davranışta olmalı; ayrışırsa arama sonucu
-- istemci ve sunucuda farklı çıkar.
-- ---------------------------------------------------------------------------
create table if not exists public.post_hashtags (
  post_id    uuid not null references public.posts(id) on delete cascade,
  tag        text not null,
  created_at timestamptz not null default now(),
  primary key (post_id, tag)
);

create index if not exists idx_post_hashtags_tag
  on public.post_hashtags (tag, created_at desc);

alter table public.post_hashtags enable row level security;

drop policy if exists "post_hashtags_read" on public.post_hashtags;
create policy "post_hashtags_read" on public.post_hashtags for select
  to authenticated using (public.can_view_post(post_id));

drop policy if exists "post_hashtags_write" on public.post_hashtags;
create policy "post_hashtags_write" on public.post_hashtags for all
  to authenticated
  using (exists (select 1 from public.posts p
                  where p.id = post_id and p.author_profile_id = auth.uid()))
  with check (exists (select 1 from public.posts p
                       where p.id = post_id and p.author_profile_id = auth.uid()));

-- ---------------------------------------------------------------------------
-- 8) DM'DE ZENGİN İÇERİK
--
-- Mesaj gövdesi düz metin kalıyor; paylaşılan şey ayrı iki sütunda. Kartın
-- görüntüsünü mesaja gömseydik, kaynak silindiğinde eski veri mesajda
-- donmuş olarak kalırdı — planın açıkça istemediği şey.
-- ---------------------------------------------------------------------------
alter table public.direct_messages
  add column if not exists content_type text not null default 'text',
  add column if not exists shared_kind  text,
  add column if not exists shared_id    uuid;

do $blk$ begin
  alter table public.direct_messages add constraint dm_content_type_check
    check (content_type in ('text', 'content_share', 'marketplace_share',
                            'event_share', 'organization_share'));
exception when duplicate_object then null; end $blk$;

-- Paylaşım türü seçildiyse hedef zorunlu; yoksa boş kart çizilirdi.
do $blk$ begin
  alter table public.direct_messages add constraint dm_share_needs_target
    check (content_type = 'text' or shared_id is not null);
exception when duplicate_object then null; end $blk$;

-- Topluluk mesajlarında da aynı yapı.
alter table public.community_messages
  add column if not exists content_type text not null default 'text',
  add column if not exists shared_kind  text,
  add column if not exists shared_id    uuid;

do $blk$ begin
  alter table public.community_messages
    add constraint cm_content_type_check
    check (content_type in ('text', 'content_share', 'marketplace_share',
                            'event_share', 'organization_share'));
exception when duplicate_object then null; end $blk$;

-- ---------------------------------------------------------------------------
-- 9) BEĞENİ SAYACI
--
-- Sayacı satırda tutmak, her akış satırında `count(*)` çalıştırmaktan çok
-- daha ucuz. Tetikleyiciyle güncelleniyor — uygulama koduna bırakılsaydı
-- bir yerde artırılıp başka yerde azaltılmayı unuturdu.
-- ---------------------------------------------------------------------------
create or replace function public.sync_post_like_count()
returns trigger
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if tg_op = 'INSERT' then
    update public.posts set like_count = like_count + 1
     where id = new.post_id;
    return new;
  end if;
  update public.posts set like_count = greatest(like_count - 1, 0)
   where id = old.post_id;
  return old;
end;
$fn$;

drop trigger if exists trg_post_like_count on public.post_likes;
create trigger trg_post_like_count
  after insert or delete on public.post_likes
  for each row execute function public.sync_post_like_count();

-- Mevcut satırları bir kez düzelt.
update public.posts p
   set like_count = coalesce(
     (select count(*) from public.post_likes l where l.post_id = p.id), 0)
 where p.like_count is distinct from coalesce(
     (select count(*) from public.post_likes l where l.post_id = p.id), 0);

-- ===========================================================================
-- 0063_social_rpc.sql
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 0063 — Sosyal katman RPC'leri
--
-- Paylaşım, repost/alıntı, kaydetme, etiket ve **güvenli kart oluşturma**.
--
-- GÜVENLİ KART, BU DOSYANIN EN ÖNEMLİ PARÇASI: paylaşılan kartın içeriği
-- mesaja gömülmüyor, her okumada kaynaktan tazeleniyor. Kaynak silinmiş,
-- moderasyona alınmış ya da izleyen kişi engellenmişse kart eski veriyi
-- göstermek yerine "artık kullanılamıyor" durumuna düşüyor.
--
-- Gömseydik: bir gönderi silindikten sonra bile içeriği, aylar önce
-- paylaşıldığı her sohbette okunmaya devam ederdi.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) GÜVENLİ KART
--
-- `available = false` döndüğünde istemci sabit bir boş kart çiziyor. Başlık
-- ya da görsel **kısmen bile** dönmüyor — "silinmiş gönderinin başlığı"
-- da sızdırılmış içeriktir.
-- ---------------------------------------------------------------------------
create or replace function public.shared_content_card(
  p_kind text, p_id uuid)
returns table (
  available bool,
  title     text,
  subtitle  text,
  image_ref text,
  route     text)
language sql
stable
security definer
set search_path = public
as $card$
  with hit as (
    select true as available, left(p.body, 120) as title,
           coalesce(pr.full_name, 'Bilinmeyen') as subtitle,
           p.image_path as image_ref, '/akis' as route
      from public.posts p
      left join public.profiles pr on pr.id = p.author_profile_id
     where p_kind = 'content_share'
       and p.id = p_id
       and public.can_view_post(p.id)
    union all
    select true, l.title,
           case when l.price is null then 'Fiyat belirtilmemiş'
                else trim(to_char(l.price, 'FM999G999G999')) || ' TL' end,
           null, '/urun'
      from public.listings l
     where p_kind = 'marketplace_share'
       and l.id = p_id
       and l.market_status = 'active'
       -- Engellenen kişinin ilanı görünmüyor (0052 kuralı).
       and not public.is_blocked_between(auth.uid(), l.owner_id)
    union all
    select true, e.title,
           to_char(e.starts_at at time zone 'Europe/Istanbul',
                   'DD.MM.YYYY HH24:MI'),
           null, '/calendar'
      from public.events e
     where p_kind = 'event_share'
       and e.id = p_id
       -- Etkinlik yalnızca kulüp üyesine görünüyor.
       and public.is_club_member(e.club_id)
    union all
    select true, o.name, coalesce(o.city_code, o.kind), null,
           '/organizasyonlar'
      from public.organizations o
     where p_kind = 'organization_share'
       and o.id = p_id
  )
  select h.available, h.title, h.subtitle, h.image_ref, h.route
    from hit h
   where auth.uid() is not null
  union all
  -- Hiçbir satır yoksa: kaynak yok, silinmiş ya da erişim yok. Üç durumun
  -- AYRI mesajı yok — "silinmiş" ile "erişimin yok" arasındaki fark,
  -- olmayan bir içeriğin varlığını doğrulardı.
  select false, null::text, null::text, null::text, null::text
   where auth.uid() is null
      or not exists (select 1 from hit);
$card$;

revoke execute on function public.shared_content_card(text, uuid)
  from public, anon;
grant execute on function public.shared_content_card(text, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 2) DM VE TOPLULUĞA PAYLAŞ
--
-- Tek çağrıda birden çok hedef: sekiz sohbete ayrı ayrı istek atmak, yarısı
-- gidip yarısı gitmeyen bir paylaşım bırakıyordu.
-- ---------------------------------------------------------------------------
create or replace function public.post_share_to_dm(
  p_kind        text,
  p_id          uuid,
  p_recipients  uuid[] default '{}',
  p_communities uuid[] default '{}',
  p_note        text default null)
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_n     int := 0;
  v_target uuid;
  v_body  text := coalesce(nullif(trim(coalesce(p_note, '')), ''), '');
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if p_kind not in ('content_share', 'marketplace_share', 'event_share',
                    'organization_share') then
    raise exception 'Geçersiz paylaşım türü';
  end if;

  -- Paylaşan kişi kaynağı göremiyorsa paylaşamaz da. Aksi halde erişimi
  -- olmayan bir içeriği başkasına iletebilirdi.
  if not exists (select 1 from public.shared_content_card(p_kind, p_id) c
                  where c.available) then
    raise exception 'Bu içeriği paylaşma yetkiniz yok ya da içerik kaldırılmış';
  end if;

  foreach v_target in array coalesce(p_recipients, '{}') loop
    -- Engelleme: `dm_send` politikası zaten kesiyor ama burada da
    -- kontrol ediyoruz ki hata mesajı anlaşılır olsun.
    if not public.is_blocked_between(auth.uid(), v_target) then
      insert into public.direct_messages
        (sender_id, recipient_id, body, content_type, shared_kind, shared_id)
      values (auth.uid(), v_target, v_body, p_kind, p_kind, p_id);
      v_n := v_n + 1;
    end if;
  end loop;

  foreach v_target in array coalesce(p_communities, '{}') loop
    -- Yalnızca üyesi olunan kanala.
    if exists (select 1 from public.community_members m
                where m.community_id = v_target
                  and m.profile_id = auth.uid()) then
      insert into public.community_messages
        (community_id, sender_id, body, content_type, shared_kind, shared_id)
      values (v_target, auth.uid(), v_body, p_kind, p_kind, p_id);
      v_n := v_n + 1;
    end if;
  end loop;

  return v_n;
end;
$fn$;

revoke execute on function public.post_share_to_dm(text, uuid, uuid[], uuid[], text)
  from public, anon;
grant execute on function public.post_share_to_dm(text, uuid, uuid[], uuid[], text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3) REPOST VE ALINTI
--
-- `p_body` boşsa repost, doluysa alıntı. İki ayrı RPC yazmak, ikisinin
-- yetki ve engelleme kontrolünü ayrı ayrı sürdürmek demekti.
-- ---------------------------------------------------------------------------
create or replace function public.create_repost_or_quote(
  p_post uuid,
  p_body text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_src   public.posts%rowtype;
  v_id    uuid;
  v_quote boolean := coalesce(trim(coalesce(p_body, '')), '') <> '';
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_src from public.posts where id = p_post;
  if v_src.id is null or not public.can_view_post(p_post) then
    raise exception 'Bu gönderi artık kullanılamıyor';
  end if;

  -- Kısıtlı görünürlükteki gönderi yeniden paylaşılamaz: takipçilerine özel
  -- yazılmış bir gönderiyi herkese açmak, yazarın kararını iptal ederdi.
  if v_src.visibility <> 'public' then
    raise exception 'Yalnızca herkese açık gönderiler yeniden paylaşılabilir';
  end if;

  -- Repost'un repost'u olmaz; zincir yerine köke bağlanıyor.
  if v_src.repost_of_id is not null then
    p_post := v_src.repost_of_id;
  end if;

  if not v_quote and exists (
       select 1 from public.posts
        where author_profile_id = auth.uid() and repost_of_id = p_post) then
    raise exception 'Bu gönderiyi zaten yeniden paylaştın';
  end if;

  insert into public.posts
    (author_profile_id, body, visibility, status,
     repost_of_id, quote_of_id)
  values (auth.uid(),
          case when v_quote then trim(p_body) else '' end,
          'public', 'active',
          case when v_quote then null else p_post end,
          case when v_quote then p_post else null end)
  returning id into v_id;

  -- Kendi gönderini paylaşınca kendine bildirim gitmiyor.
  if v_src.author_profile_id <> auth.uid() then
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id, actor_id)
    values (v_src.author_profile_id,
            case when v_quote then 'post_quote' else 'post_repost' end,
            case when v_quote then 'Gönderin alıntılandı'
                 else 'Gönderin yeniden paylaşıldı' end,
            left(coalesce(nullif(trim(coalesce(p_body, '')), ''),
                          v_src.body), 100),
            'post', v_id, auth.uid());
  end if;

  return v_id;
end;
$fn$;

revoke execute on function public.create_repost_or_quote(uuid, text)
  from public, anon;
grant execute on function public.create_repost_or_quote(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4) KAYDET / KALDIR
--
-- Bildirim üretmiyor. Kaydetmek kişisel bir yer imi; gönderi sahibine haber
-- vermek onu kamusal bir beğeniye çevirirdi.
-- ---------------------------------------------------------------------------
create or replace function public.toggle_saved_post(p_post uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_saved boolean;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if exists (select 1 from public.saved_posts
              where profile_id = auth.uid() and post_id = p_post) then
    delete from public.saved_posts
     where profile_id = auth.uid() and post_id = p_post;
    return false;
  end if;

  if not public.can_view_post(p_post) then
    raise exception 'Bu gönderi artık kullanılamıyor';
  end if;

  insert into public.saved_posts (profile_id, post_id)
  values (auth.uid(), p_post)
  on conflict do nothing;

  select true into v_saved;
  return coalesce(v_saved, true);
end;
$fn$;

revoke execute on function public.toggle_saved_post(uuid) from public, anon;
grant execute on function public.toggle_saved_post(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) ETİKET VE HASHTAG YAZIMI
--
-- Metni sunucu ayrıştırmıyor: istemci `@ad` ve `#etiket` çözümlemesini
-- yapıp **kimlikleri** gönderiyor. Sunucuda metin ayrıştırmak, kullanıcı
-- adı değişikliklerinde ilişkiyi koparırdı.
-- ---------------------------------------------------------------------------
create or replace function public.set_post_tags(
  p_post     uuid,
  p_mentions uuid[] default '{}',
  p_hashtags text[] default '{}')
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_author uuid;
  v_tag    text;
begin
  select author_profile_id into v_author from public.posts where id = p_post;
  if v_author is null then
    raise exception 'Gönderi bulunamadı';
  end if;
  if v_author <> auth.uid() then
    raise exception 'Yalnızca kendi gönderini etiketleyebilirsin';
  end if;

  delete from public.post_mentions where post_id = p_post;
  delete from public.post_hashtags where post_id = p_post;

  -- Etiket kuralları tetikleyicide (limit, engelleme, izin politikası);
  -- burada tekrarlanmıyor.
  insert into public.post_mentions (post_id, mentioned_profile_id)
  select p_post, m from unnest(coalesce(p_mentions, '{}')) m
  on conflict do nothing;

  foreach v_tag in array coalesce(p_hashtags, '{}') loop
    -- `tr_fold` ile saklanıyor: `#Işıklar` ve `#isiklar` aynı etiket.
    insert into public.post_hashtags (post_id, tag)
    values (p_post, public.tr_fold(trim(both '#' from v_tag)))
    on conflict do nothing;
  end loop;

  -- Etiketlenen kişiye bildirim.
  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id, actor_id)
  select m.mentioned_profile_id, 'mention', 'Bir gönderide etiketlendin',
         left((select body from public.posts where id = p_post), 100),
         'post', p_post, auth.uid()
    from public.post_mentions m
   where m.post_id = p_post
     and m.mentioned_profile_id <> auth.uid();
end;
$fn$;

revoke execute on function public.set_post_tags(uuid, uuid[], text[])
  from public, anon;
grant execute on function public.set_post_tags(uuid, uuid[], text[])
  to authenticated;

-- ---------------------------------------------------------------------------
-- 6) GİZLİLİK TERCİHLERİ
--
-- Çocuk hesaplarda dış paylaşım açılamıyor. Sunucuda kesiliyor çünkü
-- arayüzde düğmeyi gizlemek koruma değil.
-- ---------------------------------------------------------------------------
create or replace function public.set_social_privacy(
  p_mention_policy text default null,
  p_external_share boolean default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if p_external_share is true and public.is_minor_profile(auth.uid()) then
    raise exception 'Reşit olmayan hesaplarda dış paylaşım açılamaz';
  end if;

  update public.profiles
     set mention_policy = coalesce(p_mention_policy, mention_policy),
         allow_external_share =
           coalesce(p_external_share, allow_external_share)
   where id = auth.uid();
end;
$fn$;

revoke execute on function public.set_social_privacy(text, boolean)
  from public, anon;
grant execute on function public.set_social_privacy(text, boolean)
  to authenticated;

-- Çocuk hesaplarda dış paylaşımı bir kez kapat.
update public.profiles p
   set allow_external_share = false
 where p.allow_external_share
   and public.is_minor_profile(p.id);

-- ---------------------------------------------------------------------------
-- 7) KAYDEDİLENLER LİSTESİ
-- ---------------------------------------------------------------------------
create or replace function public.my_saved_posts(
  p_limit int default 30, p_offset int default 0)
returns table (
  post_id    uuid,
  body       text,
  image_path text,
  author     text,
  created_at timestamptz,
  saved_at   timestamptz)
language sql
stable
security definer
set search_path = public
as $fn$
  select p.id, p.body, p.image_path,
         coalesce(pr.full_name, 'Bilinmeyen'), p.created_at, s.created_at
    from public.saved_posts s
    join public.posts p on p.id = s.post_id
    left join public.profiles pr on pr.id = p.author_profile_id
   where s.profile_id = auth.uid()
     -- Kaydettiğin gönderi sonradan silinmiş ya da sana kapanmışsa
     -- listede görünmüyor; kayıt duruyor ama içerik sızmıyor.
     and public.can_view_post(p.id)
   order by s.created_at desc
   limit least(greatest(coalesce(p_limit, 30), 1), 100)
  offset greatest(coalesce(p_offset, 0), 0);
$fn$;

revoke execute on function public.my_saved_posts(int, int) from public, anon;
grant execute on function public.my_saved_posts(int, int) to authenticated;

-- ---------------------------------------------------------------------------
-- 8) BİLDİRİM ROTALARI
--
-- 0061'deki 30 eşlemenin hepsi korunuyor + üç yeni sosyal tür.
-- ---------------------------------------------------------------------------
create or replace function public.push_route(p_kind text, p_entity text)
returns text
language sql
immutable
as $fn$
  select case p_kind
    when 'message'                   then '/mesajlar'
    when 'application'               then '/basvurular'
    when 'offer'                     then '/bildirimler'
    when 'follow'                    then '/bildirimler'
    when 'fee'                       then '/aidatlarim'
    when 'fee_reminder'              then '/aidatlarim'
    when 'payment'                   then '/finans'
    when 'donation'                  then '/bagis'
    when 'attendance'                then '/attendance'
    when 'attendance_reminder'       then '/attendance'
    when 'event'                     then '/calendar'
    when 'announcement'              then '/announcements'
    when 'achievement'               then '/performance-analytics'
    when 'document'                  then '/documents'
    when 'documents'                 then '/documents'
    when 'document_expiry'           then '/documents'
    when 'partner_request'           then '/partner-ara'
    when 'partner_request_accepted'  then '/partner-ara'
    when 'turf_slot_request'         then '/halisahalar'
    when 'turf_field'                then '/halisahalar'
    when 'turf_manager'              then '/halisahalar'
    when 'store_decision'            then '/magaza-basvuru'
    when 'moderation'                then '/pazaryeri'
    when 'expense_approval'          then '/mali-isler'
    when 'expense_rejected'          then '/mali-isler'
    when 'commitment_due'            then '/mali-isler'
    when 'account_negative'          then '/mali-isler'
    when 'bank_unmatched'            then '/mali-isler'
    when 'period_closed'             then '/mali-isler'
    when 'period_blocked'            then '/mali-isler'
    -- 0063 — sosyal
    when 'mention'                   then '/akis'
    when 'post_repost'               then '/akis'
    when 'post_quote'                then '/akis'
    else '/bildirimler'
  end;
$fn$;

-- ---------------------------------------------------------------------------
-- 9) BAYRAKLAR
--
-- Sekizi de `admins`'te. `social_video` bilerek burada: V1'e dahil değil ama
-- anahtarı baştan tanımlı olsun ki açılacağı gün şema değil yalnızca kademe
-- değişsin.
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('social_saved_posts', 'admins', 'Kaydedilen gönderiler',
   'Gönderiyi kişisel listeye kaydetme. Gönderi sahibine bildirilmiyor.'),
  ('social_multi_photo', 'admins', 'Çoklu fotoğraf',
   'Bir gönderide en fazla 8 fotoğraf.'),
  ('social_content_share', 'admins', 'DM ve toplulukta paylaşım',
   'Gönderi, ilan, etkinlik ve organizasyonu sohbete zengin kart olarak '
   'gönderme.'),
  ('social_reposts', 'admins', 'Repost ve alıntı',
   'Yeniden paylaşma ve üzerine yorum yazarak alıntılama.'),
  ('social_mentions', 'admins', 'Etiketleme ve hashtag',
   '@kişi etiketi ve #konu etiketi.'),
  ('social_sports_cards', 'admins', 'Spor kartları',
   'Maç sonucu, takım başarısı ve antrenman özeti kartları.'),
  ('social_external_share', 'admins', 'Dış paylaşım',
   'Uygulama dışına bağlantı paylaşma. Reşit olmayan hesaplarda kapalı.'),
  ('social_video', 'off', 'Video paylaşımı',
   'V1 kapsamında DEĞİL. Dönüştürme, kapak görseli, oynatıcı ve moderasyon '
   'maliyeti tasarlanmadan açılmamalı.')
on conflict (key) do nothing;

-- ===========================================================================
-- 0064_eligibility_gate.sql
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 0064 — Sağlık kısıtı, kulüp personeli yetkileri ve KATI UYGUNLUK KİLİDİ
--
-- Bu dosyadaki tek cümlelik sözleşme:
--
--   **Yönetici dâhil hiç kimse bir sağlık kısıtını düğmeyle kaldıramaz.**
--
-- Kısıt yalnızca yetkili sağlık görevlisinin `health_restrictions` kaydını
-- güncellemesiyle kalkar. Bu bir arayüz kuralı değil: `eligibility_gate`
-- kararı veritabanında veriyor ve kulüp yöneticisine "geçersiz kıl" yolu
-- hiç açılmıyor.
--
-- ŞEMADAN SAPMA — `athlete_id` `profiles` değil `athletes` referansı.
-- Plan `profiles(id)` diyor ama bu depoda sporcu ayrı bir varlık ve
-- `athletes.profile_id` NULLABLE: girişi olmayan sporcular var ve bunlar
-- çoğunlukla küçük yaştakiler. `profiles`'a bağlasaydık kilit tam olarak
-- korunması gereken grubu kapsamazdı.
--
-- YÖNETİCİ TEŞHİS GÖRMÜYOR: `athlete_health_status` yalnızca üç rozet
-- döndürüyor (`eligible` / `restricted` / `awaiting_verification`). Rapor,
-- teşhis ve belge referansı o fonksiyondan hiç çıkmıyor.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) KULÜP PERSONELİ YETKİLERİ
--
-- `unique (club_id, profile_id) where revoked_at is null`: aynı kişiye aynı
-- kulüpte iki aktif yetki satırı olamaz, ama geçmiş (iptal edilmiş) satırlar
-- korunuyor. Kısmi indeks olmasaydı ya geçmişi silmek ya da tekilliği
-- kaybetmek gerekirdi.
-- ---------------------------------------------------------------------------
create table if not exists public.club_staff_permissions (
  id                 uuid primary key default gen_random_uuid(),
  club_id            uuid not null references public.clubs(id) on delete cascade,
  profile_id         uuid not null references public.profiles(id) on delete cascade,
  can_verify_medical boolean not null default false,
  granted_by         uuid references public.profiles(id) on delete set null,
  granted_at         timestamptz not null default now(),
  revoked_by         uuid references public.profiles(id) on delete set null,
  revoked_at         timestamptz,
  note               text
);

create unique index if not exists idx_club_staff_perm_active
  on public.club_staff_permissions (club_id, profile_id)
  where revoked_at is null;

create index if not exists idx_club_staff_perm_profile
  on public.club_staff_permissions (profile_id) where revoked_at is null;

alter table public.club_staff_permissions enable row level security;

drop policy if exists "club_staff_perm_read" on public.club_staff_permissions;
create policy "club_staff_perm_read" on public.club_staff_permissions for select
  to authenticated
  using (public.is_club_staff(club_id) or profile_id = auth.uid());
-- Yazma yalnızca RPC'den.

-- ---------------------------------------------------------------------------
-- YETKİ KONTROLÜ — ÜÇ ŞART
--
-- 1. Yetki satırı var ve `revoked_at` boş
-- 2. `can_verify_medical` açık
-- 3. Kişi hâlâ kulübün AKTİF üyesi
--
-- Üçüncüsü kritik: kulüpten ayrılan biri yetki satırı iptal edilmemişse
-- sağlık kaydına dokunmaya devam ederdi. Yetki iptali ile üyelik sonu iki
-- ayrı olay ve ikisi de yetkiyi anında düşürmeli.
-- ---------------------------------------------------------------------------
create or replace function public.is_authorized_health_officer(p_club uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1
      from public.club_staff_permissions sp
     where sp.club_id = p_club
       and sp.profile_id = auth.uid()
       and sp.revoked_at is null
       and sp.can_verify_medical
       and exists (
         select 1 from public.club_memberships m
          where m.club_id = p_club
            and m.profile_id = auth.uid()
            and m.status = 'active'));
$fn$;

comment on function public.is_authorized_health_officer(uuid) is
  'Üç şart birden: yetki iptal edilmemiş, can_verify_medical açık ve kişi '
  'kulübün aktif üyesi. Kulüpten ayrılmak da yetkiyi anında düşürüyor.';

create or replace function public.set_health_officer(
  p_club    uuid,
  p_profile uuid,
  p_grant   boolean,
  p_note    text default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  -- Sağlık yetkisini yalnızca kulüp yöneticisi atar/iptal eder.
  if not exists (select 1 from public.club_memberships m
                  where m.club_id = p_club and m.profile_id = auth.uid()
                    and m.role = 'club_admin' and m.status = 'active') then
    raise exception 'Sağlık yetkisini yalnızca kulüp yöneticisi yönetebilir';
  end if;

  if p_grant then
    insert into public.club_staff_permissions
      (club_id, profile_id, can_verify_medical, granted_by, note)
    values (p_club, p_profile, true, auth.uid(), p_note)
    on conflict (club_id, profile_id) where revoked_at is null
    do update set can_verify_medical = true, note = excluded.note;
  else
    -- İptal: satır silinmiyor, `revoked_at` işaretleniyor. Geçmiş, kimin
    -- ne zaman yetkili olduğunu göstermeye devam ediyor.
    update public.club_staff_permissions
       set revoked_at = now(), revoked_by = auth.uid(),
           can_verify_medical = false
     where club_id = p_club and profile_id = p_profile
       and revoked_at is null;
  end if;
end;
$fn$;

revoke execute on function public.set_health_officer(uuid, uuid, boolean, text)
  from public, anon;
grant execute on function public.set_health_officer(uuid, uuid, boolean, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 2) SAĞLIK KISITLARI
--
-- Teşhis, rapor metni ve doktor notu bu tabloda TUTULMUYOR. Yalnızca
-- durum, tarihler ve bir belge referansı var. Teşhisi buraya koymak, onu
-- okuyabilecek her rol için ayrı bir gizlilik sorunu açardı.
-- ---------------------------------------------------------------------------
create table if not exists public.health_restrictions (
  id                uuid primary key default gen_random_uuid(),
  athlete_id        uuid not null references public.athletes(id) on delete cascade,
  club_id           uuid not null references public.clubs(id) on delete cascade,
  status            text not null default 'under_review',
  start_date        timestamptz not null default now(),
  reevaluation_date timestamptz,
  end_date          timestamptz,
  -- Kanıt belgesi. Belgenin KENDİSİ burada değil, referansı var.
  evidence_ref      uuid references public.verification_documents(id) on delete set null,
  created_by        uuid not null references public.profiles(id),
  audit_log         jsonb not null default '[]'::jsonb,
  created_at        timestamptz not null default now()
);

do $blk$ begin
  alter table public.health_restrictions add constraint health_status_check
    check (status in ('restricted', 'under_review', 'cleared'));
exception when duplicate_object then null; end $blk$;

create index if not exists idx_health_restriction_athlete
  on public.health_restrictions (athlete_id, status, start_date desc);

-- Aynı sporcuya aynı anda iki aktif kısıt olamaz: hangisinin geçerli
-- olduğu belirsizleşir ve kilit sorgusu rastgele birini okur.
create unique index if not exists idx_health_restriction_one_active
  on public.health_restrictions (athlete_id)
  where status in ('restricted', 'under_review');

alter table public.health_restrictions enable row level security;

-- Okuma: kulüp personeli ve sporcunun kendisi/velisi. Muhasebeci YOK.
drop policy if exists "health_restriction_read" on public.health_restrictions;
create policy "health_restriction_read" on public.health_restrictions for select
  to authenticated
  using (
    public.is_club_staff(club_id)
    or exists (select 1 from public.athletes a
                where a.id = athlete_id and a.profile_id = auth.uid())
    or exists (select 1 from public.guardians g
                where g.athlete_id = health_restrictions.athlete_id
                  and g.profile_id = auth.uid()));
-- Yazma politikası YOK: yalnızca RPC'den ve yalnızca sağlık görevlisi.

-- ---------------------------------------------------------------------------
-- KISIT AÇMA VE KAPAMA
--
-- Açmayı antrenör de talep edebiliyor (`under_review`), ama **kapatmayı
-- yalnızca yetkili sağlık görevlisi** yapabiliyor. İkisi ayrı yetki:
-- şüpheyi herkes dile getirebilmeli, temize çıkarmayı yalnızca yetkili.
-- ---------------------------------------------------------------------------
create or replace function public.open_health_restriction(
  p_athlete uuid,
  p_status  text default 'under_review',
  p_reevaluation timestamptz default null,
  p_evidence uuid default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_club uuid;
  v_id   uuid;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select club_id into v_club from public.athletes where id = p_athlete;
  if v_club is null then
    raise exception 'Sporcu bulunamadı';
  end if;

  if p_status not in ('restricted', 'under_review') then
    raise exception 'Bu fonksiyonla yalnızca kısıt açılır';
  end if;

  -- `restricted` yalnızca sağlık görevlisinden; `under_review` (inceleme
  -- talebi) kulüp personelinin herhangi birinden gelebilir.
  if p_status = 'restricted'
     and not public.is_authorized_health_officer(v_club) then
    raise exception 'Kesin kısıtı yalnızca yetkili sağlık görevlisi koyabilir';
  end if;

  if not public.is_club_staff(v_club) then
    raise exception 'Bu kulüpte işlem yapma yetkiniz yok';
  end if;

  insert into public.health_restrictions
    (athlete_id, club_id, status, reevaluation_date, evidence_ref,
     created_by, audit_log)
  values (p_athlete, v_club, p_status, p_reevaluation, p_evidence, auth.uid(),
          jsonb_build_array(jsonb_build_object(
            'at', now(), 'by', auth.uid(), 'action', 'open',
            'status', p_status)))
  returning id into v_id;

  return v_id;
end;
$fn$;

revoke execute on function public.open_health_restriction(uuid, text, timestamptz, uuid)
  from public, anon;
grant execute on function public.open_health_restriction(uuid, text, timestamptz, uuid)
  to authenticated;

create or replace function public.clear_health_restriction(
  p_restriction uuid,
  p_note        text)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_r public.health_restrictions%rowtype;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  select * into v_r from public.health_restrictions where id = p_restriction;
  if v_r.id is null then
    raise exception 'Kısıt kaydı bulunamadı';
  end if;

  -- KATI KURAL. Kulüp yöneticisi olmak yetmiyor; platform yöneticisi olmak
  -- da yetmiyor. Yalnızca o kulübün yetkili sağlık görevlisi.
  if not public.is_authorized_health_officer(v_r.club_id) then
    raise exception 'Sağlık kısıtını yalnızca yetkili sağlık görevlisi '
                    'kaldırabilir';
  end if;

  if coalesce(trim(coalesce(p_note, '')), '') = '' then
    raise exception 'Kısıt kaldırma gerekçesi zorunlu';
  end if;

  update public.health_restrictions
     set status = 'cleared',
         end_date = now(),
         audit_log = audit_log || jsonb_build_object(
           'at', now(), 'by', auth.uid(), 'action', 'clear', 'note', p_note)
   where id = p_restriction;
end;
$fn$;

revoke execute on function public.clear_health_restriction(uuid, text)
  from public, anon;
grant execute on function public.clear_health_restriction(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3) LİSANS SÜRESİ
--
-- Ayrı sütun: `documents.expires_on` üzerinden çıkarmak, belgenin adına
-- bakarak "bu lisans mı" tahmini yapmayı gerektirirdi. Tahmin, kilit
-- kararını veren bir sorguda kabul edilemez.
-- ---------------------------------------------------------------------------
alter table public.athletes
  add column if not exists license_expires_on date;

create index if not exists idx_athletes_license_expiry
  on public.athletes (license_expires_on)
  where license_expires_on is not null;

-- ---------------------------------------------------------------------------
-- 4) UYGUNLUK KİLİDİ
--
-- İki seviye:
--   KESİN ENGEL  süresi dolmuş lisans veya aktif sağlık kısıtı.
--                Kimse elle açamaz.
--   UYARI        idari eksik (inceleme bekleyen sağlık talebi).
--                Kulüp yöneticisi gerekçeyle geçebilir.
--
-- `blocked` alanı **yalnızca kesin engelde** true. Uyarı durumunda false —
-- ikisini aynı bayrağa toplamak, idari bir eksiği tıbbi bir engel gibi
-- göstermek olurdu.
-- ---------------------------------------------------------------------------
create or replace function public.eligibility_gate(p_athlete uuid)
returns table (
  blocked      boolean,
  status       text,
  reason_code  text,
  reason_label text)
language sql
stable
security definer
set search_path = public
as $fn$
  with a as (
    select * from public.athletes where id = p_athlete
  ),
  active_restriction as (
    select r.status from public.health_restrictions r
     where r.athlete_id = p_athlete
       and r.status in ('restricted', 'under_review')
     limit 1
  )
  select
    -- KESİN ENGEL
    (exists (select 1 from active_restriction where status = 'restricted')
     or exists (select 1 from a
                 where a.license_expires_on is not null
                   and a.license_expires_on < current_date)),
    case
      when exists (select 1 from active_restriction where status = 'restricted')
        then 'restricted'
      when exists (select 1 from a
                    where a.license_expires_on is not null
                      and a.license_expires_on < current_date)
        then 'restricted'
      when exists (select 1 from active_restriction
                    where status = 'under_review')
        then 'awaiting_verification'
      else 'eligible'
    end,
    case
      when exists (select 1 from active_restriction where status = 'restricted')
        then 'health_restriction'
      when exists (select 1 from a
                    where a.license_expires_on is not null
                      and a.license_expires_on < current_date)
        then 'license_expired'
      when exists (select 1 from active_restriction
                    where status = 'under_review')
        then 'health_review'
      else 'ok'
    end,
    case
      when exists (select 1 from active_restriction where status = 'restricted')
        then 'Aktif sağlık kısıtı var'
      when exists (select 1 from a
                    where a.license_expires_on is not null
                      and a.license_expires_on < current_date)
        then 'Lisans süresi dolmuş'
      when exists (select 1 from active_restriction
                    where status = 'under_review')
        then 'Sağlık incelemesi sürüyor'
      else 'Uygun'
    end
  from a;
$fn$;

revoke execute on function public.eligibility_gate(uuid) from public, anon;
grant execute on function public.eligibility_gate(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5) YÖNETİCİ GÖRÜNÜMÜ — teşhissiz
--
-- Yalnızca üç rozet. Ne teşhis, ne rapor, ne belge referansı, ne de kısıtı
-- kimin koyduğu. Yöneticinin ihtiyacı olan tek bilgi "sahaya çıkabilir mi".
-- ---------------------------------------------------------------------------
create or replace function public.club_eligibility_board(p_club uuid)
returns table (
  athlete_id   uuid,
  athlete_ref  text,
  status       text,
  reason_label text)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Bu kulübün uygunluk tablosunu görme yetkiniz yok';
  end if;

  return query
    select a.id,
           -- Kulüp personeli adı görebilir; bu fonksiyon yine de kısaltma
           -- döndürüyor çünkü ekranın işi kimliklendirme değil sayım.
           public.athlete_ref(a.id),
           g.status,
           g.reason_label
      from public.athletes a
      cross join lateral public.eligibility_gate(a.id) g
     where a.club_id = p_club
       and a.status = 'active'
       and g.status <> 'eligible'
     order by (g.status = 'restricted') desc, 2;
end;
$fn$;

revoke execute on function public.club_eligibility_board(uuid) from public, anon;
grant execute on function public.club_eligibility_board(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) DİNAMİK KADRO DENETİMİ
--
-- Kadroya eklendikten sonra etkinlik gününe kadar lisansı dolan sporcular.
-- Günlük tarama; kulüp yöneticisine bildirim.
-- ---------------------------------------------------------------------------
create or replace function public.scan_roster_eligibility()
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_n int := 0;
begin
  with risky as (
    select distinct e.club_id, a.id as athlete_id
      from public.events e
      join public.team_memberships tm on tm.team_id = e.team_id
      join public.athletes a on a.id = tm.athlete_id
     where e.starts_at between now() and now() + interval '7 days'
       and a.license_expires_on is not null
       and a.license_expires_on <= (e.starts_at at time zone 'Europe/Istanbul')::date
  ),
  targets as (
    select distinct r.athlete_id, m.profile_id, r.club_id
      from risky r
      join public.club_memberships m
        on m.club_id = r.club_id and m.role = 'club_admin'
       and m.status = 'active'
  ),
  fresh as (
    insert into public.reminder_log (kind, entity_id, profile_id)
    select 'eligibility', t.athlete_id, t.profile_id from targets t
    on conflict do nothing
    returning entity_id, profile_id
  ),
  sent as (
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    select f.profile_id, 'eligibility',
           'Lisans süresi yaklaşan sporcu',
           'Yaklaşan etkinlikte kadroda olan bir sporcunun lisansı o tarihte '
           'dolmuş olacak. Uygunluk tablosundan kontrol et.',
           'athlete', f.entity_id
      from fresh f
    returning 1
  )
  select count(*) into v_n from sent;

  return v_n;
end;
$fn$;

select cron.schedule(
  'swansport_eligibility_scan', '0 4 * * *',
  $cron$select public.scan_roster_eligibility();$cron$);

-- ---------------------------------------------------------------------------
-- 7) BAYRAKLAR
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('eligibility_gate', 'admins', 'Uygunluk kilidi',
   'Lisans ve sağlık kısıtına göre sahaya çıkma engeli. Kesin engeli kimse '
   'elle kaldıramaz.'),
  ('membership_lifecycle', 'admins', 'Üyelik yaşam döngüsü',
   'Başvuru, belge, kabul, takım ataması ve ayrılış akışı.'),
  ('parent_hub', 'admins', 'Veli merkezi',
   'Velinin kendi çocuğunun aidat ve programını isimli görmesi.')
on conflict (key) do nothing;

-- ===========================================================================
-- 0065_attendance_idempotent.sql
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 0065 — Sunucu tarafı idempotent yoklama ve sürüm çakışması
--
-- ÖNCEKİ TASARIMDAN DÖNÜŞ. `docs/offline-attendance-design.md` çakışmayı
-- `marked_at` ile çözüyordu: cihazda en son işaretlenen kazanır. Plan bunu
-- açıkça reddediyor ve haklı:
--
--   • Cihaz saatleri güvenilmez; saati yanlış kurulmuş telefon hep kazanır.
--   • Sessiz ezme, iki antrenörün farklı gördüğü bir gerçeği kimseye
--     sormadan karara bağlıyor.
--
-- Yerine **iyimser sürüm kontrolü**: istemci okuduğu sürümü geri gönderiyor,
-- sürüm değişmişse yazma reddediliyor ve çakışma insana gösteriliyor.
-- Kaybolan veri yok, sessiz karar yok.
--
-- `op_id` TEK TELEFONDA DEĞİL SUNUCUDA: `(actor_id, op_id)` benzersizliği
-- burada. Cihaz verisi silinse bile aynı işlem ikinci kez yazılmıyor.
-- ---------------------------------------------------------------------------

alter table public.attendance
  add column if not exists version   int not null default 1,
  add column if not exists marked_at timestamptz,
  add column if not exists actor_id  uuid references public.profiles(id) on delete set null;

-- ---------------------------------------------------------------------------
-- İŞLEM GÜNLÜĞÜ
--
-- Sonuç `jsonb` olarak saklanıyor: aynı `op_id` ikinci kez geldiğinde işlem
-- tekrarlanmıyor, **ilk seferin sonucu** dönüyor. İkinci çağrıya "başarılı"
-- deyip hiçbir şey döndürmemek, istemcinin kaç satırın yazıldığını
-- bilememesine yol açardı.
-- ---------------------------------------------------------------------------
create table if not exists public.attendance_op_logs (
  id         uuid primary key default gen_random_uuid(),
  actor_id   uuid not null references public.profiles(id) on delete cascade,
  op_id      uuid not null,
  event_id   uuid references public.events(id) on delete set null,
  club_id    uuid references public.clubs(id) on delete cascade,
  result     jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint attendance_op_unique unique (actor_id, op_id)
);

create index if not exists idx_attendance_op_event
  on public.attendance_op_logs (event_id, created_at desc);

alter table public.attendance_op_logs enable row level security;

drop policy if exists "attendance_op_read" on public.attendance_op_logs;
create policy "attendance_op_read" on public.attendance_op_logs for select
  to authenticated
  using (actor_id = auth.uid() or public.is_club_staff(club_id));
-- Yazma yalnızca RPC'den.

-- ---------------------------------------------------------------------------
-- TOPLU YOKLAMA KAYDI
--
-- `p_marks` biçimi:
--   [{"athlete_id": "...", "status": "present", "version": 3,
--     "marked_at": "2026-09-02T10:05:00Z"}, ...]
--
-- `version` istemcinin okuduğu sürüm. Kayıt yoksa 0 gönderilir.
--
-- Dönüş:
--   {"applied": 12, "conflicts": [{...}], "replayed": false}
--
-- ÇAKIŞMA SESSİZ GEÇİLMİYOR. Uyuşmayan satır yazılmıyor ve mevcut değeriyle
-- birlikte geri dönüyor; istemci antrenöre "sen X dedin, şu an Y yazıyor"
-- diyebiliyor. Bu, tasarımın tamamının sebebi.
-- ---------------------------------------------------------------------------
create or replace function public.save_attendance_ops(
  p_event uuid,
  p_op_id uuid,
  p_marks jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_club      uuid;
  v_cached    jsonb;
  v_applied   int := 0;
  v_conflicts jsonb := '[]'::jsonb;
  v_mark      jsonb;
  v_athlete   uuid;
  v_status    text;
  v_ver       int;
  v_cur_ver   int;
  v_cur_stat  text;
  v_result    jsonb;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if p_op_id is null then
    raise exception 'İşlem kimliği (op_id) zorunlu';
  end if;

  select club_id into v_club from public.events where id = p_event;
  if v_club is null then
    raise exception 'Etkinlik bulunamadı';
  end if;

  if not public.is_club_staff(v_club) then
    raise exception 'Bu kulüpte yoklama alma yetkiniz yok';
  end if;

  -- TEKRAR GÖNDERİM: ilk seferin sonucunu döndür, hiçbir şey yazma.
  select result into v_cached
    from public.attendance_op_logs
   where actor_id = auth.uid() and op_id = p_op_id;

  if v_cached is not null then
    return v_cached || jsonb_build_object('replayed', true);
  end if;

  for v_mark in select * from jsonb_array_elements(coalesce(p_marks, '[]'::jsonb))
  loop
    v_athlete := (v_mark ->> 'athlete_id')::uuid;
    v_status  := v_mark ->> 'status';
    v_ver     := coalesce((v_mark ->> 'version')::int, 0);

    select a.version, a.status::text into v_cur_ver, v_cur_stat
      from public.attendance a
     where a.event_id = p_event and a.athlete_id = v_athlete;

    if v_cur_ver is null then
      -- Kayıt yok: istemci de yok sanıyorsa yaz.
      if v_ver = 0 then
        insert into public.attendance
          (club_id, event_id, athlete_id, status, marked_at, actor_id, version)
        values (v_club, p_event, v_athlete,
                -- `status` bir enum (attendance_status); text atamak
                -- "column is of type ... but expression is of type text"
                -- hatası verir.
                v_status::public.attendance_status,
                coalesce((v_mark ->> 'marked_at')::timestamptz, now()),
                auth.uid(), 1);
        v_applied := v_applied + 1;
      else
        -- İstemci bir sürüm biliyor ama kayıt yok: arada silinmiş.
        v_conflicts := v_conflicts || jsonb_build_object(
          'athlete_id', v_athlete, 'reason', 'deleted',
          'sent_version', v_ver, 'current_version', null,
          'current_status', null);
      end if;

    elsif v_cur_ver = v_ver then
      update public.attendance
         set status = v_status::public.attendance_status,
             marked_at = coalesce((v_mark ->> 'marked_at')::timestamptz, now()),
             actor_id = auth.uid(),
             version = version + 1
       where event_id = p_event and athlete_id = v_athlete;
      v_applied := v_applied + 1;

    else
      -- SÜRÜM ÇAKIŞMASI. Yazmıyoruz; mevcut değeri geri veriyoruz.
      v_conflicts := v_conflicts || jsonb_build_object(
        'athlete_id', v_athlete, 'reason', 'version_mismatch',
        'sent_version', v_ver, 'sent_status', v_status,
        'current_version', v_cur_ver, 'current_status', v_cur_stat);
    end if;

    v_cur_ver := null;
    v_cur_stat := null;
  end loop;

  v_result := jsonb_build_object(
    'applied', v_applied,
    'conflicts', v_conflicts,
    'replayed', false);

  insert into public.attendance_op_logs
    (actor_id, op_id, event_id, club_id, result)
  values (auth.uid(), p_op_id, p_event, v_club, v_result);

  return v_result;
end;
$fn$;

revoke execute on function public.save_attendance_ops(uuid, uuid, jsonb)
  from public, anon;
grant execute on function public.save_attendance_ops(uuid, uuid, jsonb)
  to authenticated;

-- ---------------------------------------------------------------------------
-- SÜRÜMLÜ KADRO OKUMA
--
-- `event_roster` sürüm taşımıyordu; istemci geri gönderecek bir şey
-- bulamazdı. Yeni fonksiyon, imza değiştirmek yerine ayrı adla yazıldı —
-- `create or replace` yalnızca aynı imzayı değiştiriyor ve eski sürüm
-- kalsaydı PostgREST 300 dönerdi (AGENTS.md).
-- ---------------------------------------------------------------------------
create or replace function public.event_roster_versioned(p_event uuid)
returns table (
  athlete_id  uuid,
  full_name   text,
  status      text,
  version     int,
  rsvp_status text,
  eligibility text)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_club uuid;
begin
  select club_id into v_club from public.events where id = p_event;
  if v_club is null then
    raise exception 'Etkinlik bulunamadı';
  end if;

  if not public.is_club_staff(v_club) then
    raise exception 'Bu etkinliğin kadrosunu görme yetkiniz yok';
  end if;

  return query
    select a.id,
           a.first_name || ' ' || a.last_name,
           at.status::text,
           coalesce(at.version, 0),
           r.status,
           g.status
      from public.events e
      join public.team_memberships tm on tm.team_id = e.team_id
      join public.athletes a on a.id = tm.athlete_id
      left join public.attendance at
        on at.event_id = e.id and at.athlete_id = a.id
      left join public.event_rsvps r
        on r.event_id = e.id and r.athlete_id = a.id
      cross join lateral public.eligibility_gate(a.id) g
     where e.id = p_event
       and a.status = 'active'
     order by 2;
end;
$fn$;

revoke execute on function public.event_roster_versioned(uuid) from public, anon;
grant execute on function public.event_roster_versioned(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- BAYRAK
--
-- `offline_attendance` bilerek `off`. Diğerleri `admins`'te başlıyor ama bu
-- özellik yanlış çalıştığında **veri kaybettiriyor**; pilot antrenörlere
-- açılmadan önce çakışma çözme ekranı yazılmalı ve gerçek cihazda
-- denenmeli.
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('offline_attendance', 'off', 'Çevrimdışı yoklama',
   'Sunucu tarafı idempotent yoklama. Çakışma çözme ekranı hazır olmadan '
   'AÇILMAMALI — yanlış çalıştığında veri kaybettirir.'),
  ('coach_workspace', 'admins', 'Antrenör çalışma alanı',
   'Antrenörün yoklama, kadro ve program işlerinin tek ekranda toplanması.')
on conflict (key) do nothing;

-- ===========================================================================
-- 0066_support_risk_retention.sql
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 0066 — Destek merkezi, açıklanabilir operasyon riski, bildirim tercihleri,
--        içe aktarma partileri ve veri saklama politikası
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) HASSAS VERİ AYIKLAMA
--
-- Destek talebine otomatik eklenen bağlam token, şifre, IBAN ve sağlık notu
-- taşıyabiliyor. İstemci de ayıklıyor ama **sunucu son savunma**: istemciye
-- güvenmek, eski bir uygulama sürümünün ham veri göndermesini engellemiyor.
--
-- Ayıklama kusursuz değil ve öyle olduğunu iddia etmiyor: serbest metinde
-- her şey yazılabilir. Amaç, otomatik toplanan bağlamın kazara sır
-- taşımasını zorlaştırmak.
-- ---------------------------------------------------------------------------
create or replace function public.sanitize_support_text(p_text text)
returns text
language sql
immutable
as $fn$
  select case when p_text is null then null else
    regexp_replace(
      regexp_replace(
        regexp_replace(
          regexp_replace(p_text,
            -- IBAN
            '(TR)[0-9]{2}[0-9 ]{16,}', '[IBAN]', 'gi'),
          -- Bearer / token / apikey / password anahtar-değer çiftleri
          '(?i)(bearer|token|apikey|api_key|password|secret|passwd)\s*[:=]?\s*\S+',
          '\1 [GIZLI]', 'g'),
        -- JWT benzeri uzun noktalı diziler
        '[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}',
        '[TOKEN]', 'g'),
      -- 7+ haneli rakam dizileri (kart, TC, telefon)
      '[0-9]{7,}', '[RAKAM]', 'g')
  end;
$fn$;

-- ---------------------------------------------------------------------------
-- 2) DESTEK MERKEZİ
-- ---------------------------------------------------------------------------
create table if not exists public.support_tickets (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  club_id     uuid references public.clubs(id) on delete set null,
  subject     text not null,
  body        text not null,
  -- Otomatik bağlam: hangi ekran, hangi sürüm. Ayıklanmış hâlde saklanıyor.
  context     jsonb not null default '{}'::jsonb,
  status      text not null default 'new',
  assigned_to uuid references public.profiles(id) on delete set null,
  resolved_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

do $blk$ begin
  alter table public.support_tickets add constraint support_status_check
    check (status in ('new', 'under_review', 'awaiting_user_response',
                      'resolved', 'closed'));
exception when duplicate_object then null; end $blk$;

create index if not exists idx_support_status
  on public.support_tickets (status, created_at desc);
create index if not exists idx_support_profile
  on public.support_tickets (profile_id, created_at desc);

alter table public.support_tickets enable row level security;

drop policy if exists "support_read" on public.support_tickets;
create policy "support_read" on public.support_tickets for select
  to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

drop policy if exists "support_admin" on public.support_tickets;
create policy "support_admin" on public.support_tickets for update
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());
-- Oluşturma RPC'den: ayıklama atlanamasın.

create table if not exists public.support_messages (
  id         uuid primary key default gen_random_uuid(),
  ticket_id  uuid not null references public.support_tickets(id) on delete cascade,
  sender_id  uuid references public.profiles(id) on delete set null,
  body       text not null,
  is_staff   boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_support_msg
  on public.support_messages (ticket_id, created_at);

alter table public.support_messages enable row level security;

drop policy if exists "support_msg_read" on public.support_messages;
create policy "support_msg_read" on public.support_messages for select
  to authenticated
  using (exists (select 1 from public.support_tickets t
                  where t.id = ticket_id
                    and (t.profile_id = auth.uid()
                         or public.is_platform_admin())));

create or replace function public.open_support_ticket(
  p_subject text,
  p_body    text,
  p_context jsonb default '{}'::jsonb,
  p_club    uuid default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_id  uuid;
  v_ctx jsonb := '{}'::jsonb;
  v_k   text;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if coalesce(trim(coalesce(p_subject, '')), '') = '' then
    raise exception 'Konu zorunlu';
  end if;

  -- Bağlamın her metin alanı ayıklanıyor. Anahtarlar korunuyor,
  -- değerler temizleniyor.
  for v_k in select jsonb_object_keys(coalesce(p_context, '{}'::jsonb)) loop
    v_ctx := v_ctx || jsonb_build_object(
      v_k,
      public.sanitize_support_text(p_context ->> v_k));
  end loop;

  insert into public.support_tickets
    (profile_id, club_id, subject, body, context)
  values (auth.uid(), p_club,
          public.sanitize_support_text(trim(p_subject)),
          public.sanitize_support_text(trim(p_body)),
          v_ctx)
  returning id into v_id;

  return v_id;
end;
$fn$;

revoke execute on function public.open_support_ticket(text, text, jsonb, uuid)
  from public, anon;
grant execute on function public.open_support_ticket(text, text, jsonb, uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3) BİLDİRİM TERCİHLERİ
--
-- Kanal bazlı. Varsayılan hepsi açık: kapalı başlatmak, kullanıcının hiç
-- haberdar olmadığı bir sessizlik üretirdi.
--
-- DM ve resmî duyuru **kapatılamıyor**: birinde kişisel bir mesaj, ötekinde
-- kulübün resmî bildirimi var ve ikisi de kaçırılmamalı.
-- ---------------------------------------------------------------------------
create table if not exists public.notification_preferences (
  profile_id     uuid primary key references public.profiles(id) on delete cascade,
  team_channel   boolean not null default true,
  social         boolean not null default true,
  marketplace    boolean not null default true,
  finance        boolean not null default true,
  guardian_only  boolean not null default false,
  quiet_from     time,
  quiet_to       time,
  updated_at     timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

drop policy if exists "notif_pref_own" on public.notification_preferences;
create policy "notif_pref_own" on public.notification_preferences for all
  to authenticated
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- ---------------------------------------------------------------------------
-- 4) İÇE AKTARMA PARTİLERİ
--
-- HMAC parmak izi Vault sırrıyla üretiliyor ve **ham kişisel/sağlık verisi
-- imzaya girmiyor**: imza yalnızca `club_id`, `record_type`, `created_at` ve
-- anahtar sürümü üzerinden hesaplanıyor. Amaç aynı satırın iki kez
-- yazılmasını yakalamak, içeriği kanıtlamak değil.
--
-- Parmak izi ÜRETİMİ istemcide değil sunucuda olmalı; bu migration tabloyu
-- kuruyor, HMAC hesabı Vault sırrına eriştiği için ayrı bir adımda
-- eklenecek (sır tanımlanmadan fonksiyon yazmak, çalışmayan kod bırakır).
-- ---------------------------------------------------------------------------
create table if not exists public.import_batches (
  id           uuid primary key default gen_random_uuid(),
  club_id      uuid not null references public.clubs(id) on delete cascade,
  record_type  text not null,
  file_name    text,
  file_hash    text not null,
  key_version  int not null default 1,
  total_rows   int not null default 0,
  ok_rows      int not null default 0,
  failed_rows  int not null default 0,
  error_report jsonb not null default '[]'::jsonb,
  status       text not null default 'pending',
  created_by   uuid references public.profiles(id) on delete set null,
  created_at   timestamptz not null default now(),
  -- 90 gün sonra otomatik siliniyor (veri saklama politikası).
  purge_after  timestamptz not null default now() + interval '90 days',
  constraint import_batch_unique unique (club_id, file_hash)
);

do $blk$ begin
  alter table public.import_batches add constraint import_status_check
    check (status in ('pending', 'applied', 'failed', 'rolled_back'));
exception when duplicate_object then null; end $blk$;

create index if not exists idx_import_purge
  on public.import_batches (purge_after);

alter table public.import_batches enable row level security;

drop policy if exists "import_batch_read" on public.import_batches;
create policy "import_batch_read" on public.import_batches for select
  to authenticated using (public.is_club_staff(club_id));

drop policy if exists "import_batch_write" on public.import_batches;
create policy "import_batch_write" on public.import_batches for all
  to authenticated
  using (public.is_club_staff(club_id))
  with check (public.is_club_staff(club_id));

-- ---------------------------------------------------------------------------
-- 5) AÇIKLANABİLİR OPERASYON RİSKİ
--
-- Tek bir puan DEĞİL, gerekçe listesi. "Risk: 72" kimseye ne yapacağını
-- söylemiyor; "4 hesapsız mali hareket var" söylüyor.
--
-- Erişilebilirlik: seviye hem metin etiketi hem kod olarak dönüyor. Renk
-- istemcide ekleniyor ve **tek başına bilgi taşımıyor**.
--
-- MUHASEBECİ: yalnızca mali gerekçeleri görüyor. Lisans, sağlık ve yoklama
-- satırları onun sonucuna hiç girmiyor.
-- ---------------------------------------------------------------------------
create or replace function public.club_operational_risk(p_club uuid)
returns table (
  code        text,
  label       text,
  severity    text,
  qty         bigint,
  route       text)
language plpgsql
stable
security definer
set search_path = public
as $fn$
declare
  v_staff boolean := public.is_club_staff(p_club);
  v_acc   boolean := public.is_club_accountant(p_club);
begin
  if not (v_staff or v_acc) then
    raise exception 'Bu kulübün risk tablosunu görme yetkiniz yok';
  end if;

  return query
  -- Mali gerekçeler: ikisine de açık.
  select 'unlinked_movement', 'Hesaba bağlanmamış mali hareket',
         case when count(*) > 0 then 'dikkat' else 'dusuk' end,
         count(*), '/kasa'
    from (
      select 1 from public.payments p
       where p.club_id = p_club and p.status = 'confirmed'
         and p.account_id is null
      union all
      select 1 from public.expenses e
       where e.club_id = p_club and e.status = 'complete'
         and e.account_id is null) x
  union all
  select 'negative_account', 'Negatif bakiyeli hesap',
         case when count(*) > 0 then 'kritik' else 'dusuk' end,
         count(*), '/kasa'
    from public.acc_account_balances(p_club) b
   where b.balance < 0
  union all
  select 'pending_approval', 'Onay bekleyen gider',
         case when count(*) > 2 then 'dikkat' else 'dusuk' end,
         count(*), '/mali-isler'
    from public.expenses e
   where e.club_id = p_club and e.approval_status = 'pending'
  union all
  -- Sportif gerekçeler: YALNIZCA kulüp personeline. Muhasebeci için
  -- adet sıfır dönüyor, satır hiç gelmiyor.
  select 'license_expiring', 'Lisansı 30 gün içinde dolan sporcu',
         case when count(*) > 0 then 'kritik' else 'dusuk' end,
         count(*), '/sporcular'
    from public.athletes a
   where v_staff and a.club_id = p_club and a.status = 'active'
     and a.license_expires_on is not null
     and a.license_expires_on between current_date and current_date + 30
  union all
  select 'health_restricted', 'Sağlık kısıtı olan sporcu',
         case when count(*) > 0 then 'dikkat' else 'dusuk' end,
         count(*), '/sporcular'
    from public.health_restrictions h
   where v_staff and h.club_id = p_club and h.status = 'restricted'
  union all
  select 'unmarked_attendance', 'Yoklaması alınmamış antrenman',
         case when count(*) > 2 then 'dikkat' else 'dusuk' end,
         count(*), '/yoklama'
    from public.events e
   where v_staff and e.club_id = p_club
     and e.starts_at < now() and e.starts_at > now() - interval '14 days'
     and not exists (select 1 from public.attendance a where a.event_id = e.id);
end;
$fn$;

revoke execute on function public.club_operational_risk(uuid) from public, anon;
grant execute on function public.club_operational_risk(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6) VERİ SAKLAMA
--
-- Süresi dolan kayıtlar siliniyor. Sağlık kısıt geçmişi BU İŞE DAHİL DEĞİL:
-- kulüp mevzuatına göre yıllarca saklanması gerekiyor ve otomatik silmek
-- geri alınamaz bir karar. Onun arşivlenmesi ayrı bir iş.
-- ---------------------------------------------------------------------------
create or replace function public.purge_expired_records()
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_n int := 0;
  v_x int;
begin
  -- İçe aktarma hata logları: 90 gün.
  delete from public.import_batches where purge_after < now();
  get diagnostics v_x = row_count; v_n := v_n + v_x;

  -- Çözülmüş destek talepleri: 180 gün.
  delete from public.support_tickets
   where status in ('resolved', 'closed')
     and resolved_at is not null
     and resolved_at < now() - interval '180 days';
  get diagnostics v_x = row_count; v_n := v_n + v_x;

  -- Hatırlatma günlüğü: 1 yıl. Tekillik için tutuluyor, tarihsel değeri yok.
  delete from public.reminder_log
   where sent_on < current_date - 365;
  get diagnostics v_x = row_count; v_n := v_n + v_x;

  return v_n;
end;
$fn$;

select cron.schedule(
  'swansport_retention_purge', '0 3 * * 0',
  $cron$select public.purge_expired_records();$cron$);

-- ---------------------------------------------------------------------------
-- 7) BAYRAKLAR
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('support_center', 'admins', 'Destek merkezi',
   'Hassas veriden arındırılmış otomatik bağlamla destek talebi.'),
  ('club_operational_risk', 'admins', 'Operasyon riski',
   'Açıklanabilir risk: tek puan değil gerekçe listesi.'),
  ('notification_preferences', 'admins', 'Bildirim tercihleri',
   'Kanal bazlı bildirim ayarı. DM ve resmî duyuru kapatılamıyor.'),
  ('club_csv_import', 'admins', 'CSV içe aktarma',
   'Kulüp verisinin toplu aktarımı, çakışma çözme ve geri alma.'),
  ('club_onboarding', 'admins', 'Kulüp kurulum sihirbazı',
   'On adımlı kulüp kurulumu.'),
  ('facility_conflicts', 'admins', 'Tesis çakışma denetimi',
   'Aynı tesis/antrenör/takım saatinde çakışma uyarısı.'),
  ('operations_analytics', 'admins', 'Operasyon analitiği',
   'Yönetim panosu ve eğilim grafikleri.'),
  ('tournament_hub', 'admins', 'Turnuva merkezi',
   'Turnuva kadrosu, belge kontrolü ve uygunluk kilidi.')
on conflict (key) do nothing;


commit;

-- ===========================================================================
-- DOGRULAMA (ayri calistir, commit'ten sonra)
--
-- 1) Bayraklar geldi mi — 33 satir donmeli:
--
--   select key, audience from public.feature_flags order by key;
--
-- 2) Cift imza kalmadi mi (HTTP 300 tuzagi) — bos donmeli:
--
--   select p.proname, count(*)
--     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and p.proname in ('acc_operations_summary', 'push_route',
--                        'shared_content_card', 'eligibility_gate')
--    group by 1 having count(*) > 1;
--
-- 3) Zamanlanmis isler kuruldu mu — 6 YENI is eklendi
--    (recurring_generate, commitment_reminders, approval_reminders,
--     finance_alerts, eligibility_scan, retention_purge):
--
--   select jobname, schedule from cron.job
--    where jobname like 'swansport_%' order by jobname;
--
-- NOT: `auth.uid()` kullanan fonksiyonlar SQL Editor'den test EDILEMEZ.
-- Orada oturum yoktur, `auth.uid()` NULL doner ve fonksiyon bos/hata verir.
-- Bu bir hata degil. Yetki gerektiren seyleri urunun kendisinden test et.
-- ===========================================================================
