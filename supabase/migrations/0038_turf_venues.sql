-- ---------------------------------------------------------------------------
-- 0038 — Halı saha doluluk panosu
--
-- Halı saha işletmeleri kortlardan temelde farklı: sahibi var, ücretli,
-- rezervasyon telefonla/yerinde yapılıyor. Bu yüzden courts'un aksine
-- gerçek rezervasyon kilidi ya da ödeme YOK — yalnızca bir ilan panosu:
-- işletme hangi saatlerin dolu olduğunu işaretliyor, oyuncu görüp telefonla
-- arayıp anlaşıyor, döndüğünde işaretliyor.
--
-- courts'tan kasıtlı olarak daha hafif: yazan tek bir yetkili kişi, kimseyle
-- yarışmıyor, sadece bir gerçeği kaydediyor. claim_slot gibi bir RPC yok —
-- RLS kuralı yetkiyi kapıda kesiyor.
-- ---------------------------------------------------------------------------

-- ============================ 1. Sahalar ====================================

-- `courts.venue` gibi serbest metin bir grup etiketi (`venue_name`) —
-- courts'taki gibi ayrı bir "tesis" tablosu açılmıyor.
create table if not exists public.turf_fields (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,               -- "Saha 1"
  venue_name text not null,                -- "Yıldız Halı Saha"
  phone      text,
  city_code  text references public.cities(code),
  district   text,
  sport_code text references public.sports(code) default 'futbol',
  lat        numeric(9,6),
  lng        numeric(9,6),
  opens_at   time not null default '08:00',
  closes_at  time not null default '24:00',
  active     boolean not null default true,
  created_at timestamptz not null default now(),

  constraint turf_field_hours_sane check (closes_at > opens_at)
);

create index if not exists idx_turf_field_active
  on public.turf_fields (active, city_code);

-- ======================= 2. Yöneticiler ======================================

-- `club_accountants` (0030) ile birebir aynı şekil — "birinin bir varlığı
-- dışarıdan yönettiği" ilişkisi bu projede bir kez çözülmüş.
create table if not exists public.turf_field_managers (
  field_id   uuid not null references public.turf_fields(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  status     text not null default 'active',   -- active | revoked
  added_by   uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (field_id, profile_id)
);

create or replace function public.is_turf_manager(p_field uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.turf_field_managers
                  where field_id = p_field and profile_id = auth.uid()
                    and status = 'active');
$$;

-- ============================ 3. Doluluk =====================================

-- Ayrı bir `status` sütunu yok: satır VARSA dolu, YOKSA boş. claim_slot'tan
-- kasıtlı olarak daha basit — orada rekabet eden birden fazla oyuncu vardı,
-- burada tek yetkili kişi bir gerçeği yazıyor; unique kısıt dışında yarış
-- durumu koruması gerekmiyor.
create table if not exists public.turf_occupancy (
  id         uuid primary key default gen_random_uuid(),
  field_id   uuid not null references public.turf_fields(id) on delete cascade,
  starts_at  timestamptz not null,
  note       text,                        -- "Ahmet - haftalık" gibi serbest not
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),

  constraint turf_occupancy_unique unique (field_id, starts_at)
);

create index if not exists idx_turf_occupancy_field
  on public.turf_occupancy (field_id, starts_at);

-- ============================ 4. RLS =========================================

alter table public.turf_fields enable row level security;
alter table public.turf_field_managers enable row level security;
alter table public.turf_occupancy enable row level security;

drop policy if exists "turf_field_read" on public.turf_fields;
create policy "turf_field_read" on public.turf_fields
  for select to anon, authenticated using (active or public.is_platform_admin());

drop policy if exists "turf_field_admin" on public.turf_fields;
create policy "turf_field_admin" on public.turf_fields
  for all to authenticated
  using (public.is_platform_admin()) with check (public.is_platform_admin());

drop policy if exists "turf_manager_self" on public.turf_field_managers;
create policy "turf_manager_self" on public.turf_field_managers
  for select to authenticated
  using (profile_id = auth.uid() or public.is_platform_admin());

-- Herkese açık: doluluk bilgisi zaten bir ilan panosu, giriş yapmamış biri
-- de görebilmeli.
drop policy if exists "turf_occupancy_read" on public.turf_occupancy;
create policy "turf_occupancy_read" on public.turf_occupancy
  for select to anon, authenticated using (true);

-- Yazma yalnızca o sahanın yetkili yöneticisine açık. RPC yok — RLS yeterli.
drop policy if exists "turf_occupancy_manage" on public.turf_occupancy;
create policy "turf_occupancy_manage" on public.turf_occupancy
  for all to authenticated
  using (public.is_turf_manager(field_id))
  with check (public.is_turf_manager(field_id));

-- ======================= 5. Haftalık şerit RPC'si ============================

-- court_timeline'daki generate_series deseninin aynısı, yalnızca 3 saat
-- yerine 7 gün (varsayılan) ileri.
create or replace function public.turf_occupancy_grid(p_field uuid, p_days int default 7)
returns table (starts_at timestamptz, occupied boolean, note text)
language sql stable security definer set search_path = public as $$
  with field as (select * from public.turf_fields where id = p_field and active),
  slots as (
    select (d.day + (h.hr || ' hours')::interval) as local_starts_at
      from field f,
           lateral generate_series(
             date_trunc('day', now() at time zone 'Europe/Istanbul'),
             date_trunc('day', now() at time zone 'Europe/Istanbul')
               + ((greatest(p_days, 1) - 1) || ' days')::interval,
             interval '1 day') as d(day),
           lateral generate_series(
             extract(hour from f.opens_at)::int,
             extract(hour from f.closes_at)::int - 1) as h(hr)
  )
  select (s.local_starts_at at time zone 'Europe/Istanbul'),
         (o.id is not null),
         o.note
    from slots s
    left join public.turf_occupancy o
      on o.field_id = p_field
     and o.starts_at = (s.local_starts_at at time zone 'Europe/Istanbul')
   where (s.local_starts_at at time zone 'Europe/Istanbul') >= now()
   order by 1;
$$;

-- ==================== 6. Davet — mevcut mekanizma genişliyor =================

-- Kulüp muhasebecisi daveti zaten `invite_codes` + `redeem_invite_code`
-- üzerinden çalışıyor (0030). Üçüncü bir dal ekleniyor, ikinci bir
-- mekanizma yazılmıyor.
alter table public.invite_codes
  add column if not exists field_id uuid references public.turf_fields(id) on delete cascade;

-- YALNIZCA PLATFORM YÖNETİCİSİ davet üretebilir — sahalar elle ekleniyor,
-- yöneticisini de yalnızca ekleyen kişi atayabiliyor.
create or replace function public.create_turf_manager_invite(
  p_field uuid, p_email text default null)
returns text language plpgsql security definer set search_path = public as $$
declare v_code text;
begin
  if not public.is_platform_admin() then
    raise exception 'Saha yöneticisi daveti yalnızca platform yöneticisi üretebilir';
  end if;

  if not exists (select 1 from public.turf_fields where id = p_field) then
    raise exception 'Saha bulunamadı';
  end if;

  v_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));

  insert into public.invite_codes
    (code, purpose, field_id, created_by, expires_at, target_email)
  values (v_code, 'turf_manager', p_field, auth.uid(), now() + interval '48 hours',
          nullif(lower(trim(coalesce(p_email, ''))), ''));

  return v_code;
end; $$;

-- `redeem_invite_code`'un tamamı yeniden yazılıyor (create or replace
-- fonksiyonu YAMALAMAZ, TAMAMEN değiştirir) — üçüncü dal: turf_manager.
-- İlk iki dal 0030'daki ile birebir aynı, davranış değişmiyor.
create or replace function public.redeem_invite_code(p_code text)
returns void language plpgsql security definer set search_path = public as $$
declare v_inv public.invite_codes; v_name text;
begin
  if auth.uid() is null then raise exception 'Not authenticated'; end if;

  select * into v_inv from public.invite_codes
    where code = upper(p_code) and used_at is null and expires_at > now()
    limit 1;
  if v_inv.id is null then raise exception 'Kod geçersiz veya süresi dolmuş'; end if;

  if v_inv.target_email is not null then
    if lower((select email from auth.users where id = auth.uid()))
       is distinct from v_inv.target_email then
      raise exception 'Bu davet başka bir hesap için üretilmiş';
    end if;
  end if;

  if v_inv.purpose = 'accountant' then
    insert into public.club_accountants (club_id, profile_id, added_by, status)
    values (v_inv.club_id, auth.uid(), v_inv.created_by, 'active')
    on conflict (club_id, profile_id)
      do update set status = 'active';

  elsif v_inv.purpose = 'turf_manager' then
    insert into public.turf_field_managers (field_id, profile_id, added_by, status)
    values (v_inv.field_id, auth.uid(), v_inv.created_by, 'active')
    on conflict (field_id, profile_id)
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

-- ============================ 7. İzinler =====================================

revoke execute on function public.create_turf_manager_invite(uuid, text) from public, anon;

-- turf_occupancy_grid herkese açık bırakıldı — courts okuması gibi, giriş
-- yapmamış biri de doluluğu görebilmeli.
