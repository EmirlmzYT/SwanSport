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
