-- ---------------------------------------------------------------------------
-- 0076 — Sporcu kaydını gerçek hesaba bağlama
--
-- KÖK NEDEN: `athletes.profile_id` kod tabanında **dört yerde okunuyor,
-- hiçbir yerde yazılmıyor**. `addAthlete` yalnızca ad-soyad yazıyor,
-- `review_club_application` yalnızca `club_memberships` satırı üretiyor.
-- İkisini bağlayan tek bir satır yok.
--
-- Sonucu: kulübün birbirine bağlı olmayan iki listesi oluyor —
--   club_memberships (role='athlete')  giriş yapabilen gerçek insanlar
--   athletes                            ad-soyaddan ibaret kadro kayıtları
--
-- Ve `profile_id` boş kaldığı için o sporcu kendi kartını göremiyor, kendi
-- geçmişini göremiyor, antrenman oturumuna katılamıyor (0072
-- `join_training_session` `profile_id = auth.uid()` arıyor) ve bildirim
-- alamıyor (0075 profilsiz sporcuya gönderemiyor).
--
-- HESAPSIZ SPORCU HÂLÂ MÜMKÜN ve öyle kalmalı: küçük yaştaki sporcuların
-- giriş profili olmayabiliyor, şema 0001'den beri `profile_id` nullable.
-- Bu migration bağlamayı **mümkün** kılıyor, zorunlu değil.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) Bir hesap aynı kulüpte iki sporcu olamaz
--
-- Kısmi indeks: `profile_id` null olanlar kapsam dışı, yani hesapsız
-- sporcular birbirini engellemiyor.
--
-- Mevcut veriyi kırmıyor: bugüne kadar hiçbir yer `profile_id` yazmadığı
-- için tüm satırlar null, çakışma üretecek satır yok.
-- ---------------------------------------------------------------------------
create unique index if not exists uq_athlete_profile_per_club
  on public.athletes (club_id, profile_id)
  where profile_id is not null;

-- ---------------------------------------------------------------------------
-- 2) Ad bölme
--
-- `profiles.full_name` tek alan, `athletes` ise ad ve soyadı ayrı istiyor.
-- Kural: **son kelime soyad**, kalanı ad. "Ahmet Can Demir" → "Ahmet Can" +
-- "Demir". Türkçede iki göbek ad yaygın, ilk kelimeyi ad saymak yanlış olurdu.
--
-- Tek kelimelik adda soyad boş dizi oluyor — `last_name` not null ama boş
-- dizeye izin veriyor. Antrenör isterse RPC'de elle düzeltebiliyor.
-- ---------------------------------------------------------------------------
create or replace function public.split_full_name(p_full text)
returns table (first_name text, last_name text)
language sql
immutable
as $fn$
  with w as (
    select string_to_array(
             regexp_replace(trim(coalesce(p_full, '')), '\s+', ' ', 'g'), ' ') as parts
  )
  select case
           when array_length(w.parts, 1) is null or w.parts[1] = '' then ''
           when array_length(w.parts, 1) = 1 then w.parts[1]
           else array_to_string(w.parts[1:array_length(w.parts, 1) - 1], ' ')
         end,
         case
           when array_length(w.parts, 1) is null or array_length(w.parts, 1) < 2
             then ''
           else w.parts[array_length(w.parts, 1)]
         end
  from w;
$fn$;

-- ---------------------------------------------------------------------------
-- 3) Kadro kaydı olmayan kulüp üyeleri
--
-- "Sporcu ekle" ekranının kaynağı bu. Kulübe **zaten katılmış** (başvurusu
-- onaylanmış ya da davet edilmiş) ama kadroda karşılığı olmayan kişiler.
--
-- NEDEN TÜM PROFİLLERDE ARAMA YOK: kulüp yöneticisine platformdaki herhangi
-- bir hesabı kendi kulübüne sporcu diye ekleme yetkisi vermek olurdu.
-- Burada rıza zaten alınmış — kişi kulübe kendisi başvurup onaylanmış.
-- ---------------------------------------------------------------------------
create or replace function public.club_members_without_athlete(p_club uuid)
returns table (
  profile_id uuid,
  full_name  text,
  avatar_url text,
  role       text,
  joined_at  timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Bu kulübün üyelerini görme yetkin yok';
  end if;

  return query
  select m.profile_id,
         p.full_name,
         p.avatar_url,
         m.role::text,
         m.created_at
    from public.club_memberships m
    join public.profiles p on p.id = m.profile_id
   where m.club_id = p_club
     and m.status = 'active'
     and m.role = 'athlete'
     and not exists (select 1 from public.athletes a
                      where a.club_id = p_club
                        and a.profile_id = m.profile_id)
   order by p.full_name;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 4) Üyeden kadro kaydı oluştur
--
-- Ad ve soyad profilden geliyor; antrenör isterse elle geçebiliyor
-- (`p_first_name`/`p_last_name` verilirse onlar kullanılıyor). Profilde ad
-- boşsa ikisi de boş kalır — o zaman antrenörün yazması gerekir.
-- ---------------------------------------------------------------------------
create or replace function public.create_athlete_from_member(
  p_club uuid,
  p_profile uuid,
  p_first_name text default null,
  p_last_name text default null,
  p_position text default null)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare v_first text;
        v_last  text;
        v_full  text;
        v_id    uuid;
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Sporcu eklemek için kulüp yetkilisi olmalısın';
  end if;

  -- RIZA SINIRI: yalnızca bu kulübün aktif üyesi bağlanabiliyor.
  if not exists (select 1 from public.club_memberships m
                  where m.club_id = p_club
                    and m.profile_id = p_profile
                    and m.status = 'active') then
    raise exception 'Bu kişi kulübünün aktif üyesi değil';
  end if;

  if exists (select 1 from public.athletes a
              where a.club_id = p_club and a.profile_id = p_profile) then
    raise exception 'Bu hesabın kulübünde zaten bir sporcu kaydı var';
  end if;

  select p.full_name into v_full from public.profiles p where p.id = p_profile;
  select s.first_name, s.last_name into v_first, v_last
    from public.split_full_name(v_full) s;

  insert into public.athletes
    (club_id, profile_id, first_name, last_name, position, status)
  values (
    p_club,
    p_profile,
    coalesce(nullif(trim(coalesce(p_first_name, '')), ''), v_first),
    coalesce(nullif(trim(coalesce(p_last_name, '')), ''), v_last),
    nullif(trim(coalesce(p_position, '')), ''),
    'active')
  returning id into v_id;

  return v_id;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 5) Var olan kopuk kaydı hesaba bağla
--
-- Kayıt SİLİNİP yeniden oluşturulmuyor: yoklama, aidat, performans testi ve
-- gelişim hedefleri `athlete_id`'ye bağlı. Silmek o geçmişi kaybettirirdi.
--
-- Zaten bağlı bir kaydı yeniden bağlamak REDDEDİLİYOR. Sessizce üzerine
-- yazmak, bir sporcunun geçmişini başka birinin hesabına devretmek olurdu;
-- çözmek gerekiyorsa önce bağın kaldırılması bilinçli bir adım olmalı.
-- ---------------------------------------------------------------------------
create or replace function public.link_athlete_to_member(
  p_athlete uuid, p_profile uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare v_club uuid;
        v_cur  uuid;
begin
  select a.club_id, a.profile_id into v_club, v_cur
    from public.athletes a where a.id = p_athlete;
  if v_club is null then
    raise exception 'Sporcu bulunamadı';
  end if;
  if not public.is_club_staff(v_club) then
    raise exception 'Bu sporcuyu düzenleme yetkin yok';
  end if;
  if v_cur is not null then
    raise exception 'Bu sporcu zaten bir hesaba bağlı';
  end if;

  if not exists (select 1 from public.club_memberships m
                  where m.club_id = v_club
                    and m.profile_id = p_profile
                    and m.status = 'active') then
    raise exception 'Bu kişi kulübünün aktif üyesi değil';
  end if;

  if exists (select 1 from public.athletes a
              where a.club_id = v_club and a.profile_id = p_profile) then
    raise exception 'Bu hesabın kulübünde zaten bir sporcu kaydı var';
  end if;

  update public.athletes
     set profile_id = p_profile, updated_at = now()
   where id = p_athlete;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 6) Kadroda kaç kayıt hesaba bağlı değil
--
-- Kadro listesindeki "hesaba bağlı değil" rozetinin kaynağı. Sayı tek
-- başına da anlamlı: kulüp yöneticisi kaç sporcusunun uygulamayı hiç
-- kullanamadığını görüyor.
-- ---------------------------------------------------------------------------
create or replace function public.club_unlinked_athletes(p_club uuid)
returns table (
  athlete_id uuid,
  first_name text,
  last_name  text,
  status     text)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if not public.is_club_staff(p_club) then
    raise exception 'Bu kulübün kadrosunu görme yetkin yok';
  end if;

  return query
  select a.id, a.first_name, a.last_name, a.status::text
    from public.athletes a
   where a.club_id = p_club
     and a.profile_id is null
   order by a.first_name, a.last_name;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- 7) İzinler — 0074'ün dersi, `PUBLIC` ayrı ele alınıyor
-- ---------------------------------------------------------------------------
revoke execute on function public.split_full_name(text) from public, anon;
revoke execute on function public.club_members_without_athlete(uuid) from public, anon;
revoke execute on function public.create_athlete_from_member(uuid, uuid, text, text, text) from public, anon;
revoke execute on function public.link_athlete_to_member(uuid, uuid) from public, anon;
revoke execute on function public.club_unlinked_athletes(uuid) from public, anon;

grant execute on function public.split_full_name(text) to authenticated;
grant execute on function public.club_members_without_athlete(uuid) to authenticated;
grant execute on function public.create_athlete_from_member(uuid, uuid, text, text, text) to authenticated;
grant execute on function public.link_athlete_to_member(uuid, uuid) to authenticated;
grant execute on function public.club_unlinked_athletes(uuid) to authenticated;
