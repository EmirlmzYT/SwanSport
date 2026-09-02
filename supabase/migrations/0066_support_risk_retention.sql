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
