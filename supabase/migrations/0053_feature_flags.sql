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
