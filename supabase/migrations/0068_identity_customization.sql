-- ---------------------------------------------------------------------------
-- 0068 — Kimlik özelleştirme: kapak, marka rengi, avatar tonu, vitrin
--
-- Bugün uygulamada herkes birbirine benziyor. Kişide yalnızca avatar, kulüpte
-- yalnızca logo var; kapak ve renk hiç yok. Avatar arka planı bile kullanıcının
-- seçimi değil — adın harf sayısından üretiliyor (`name.length % 4`).
--
-- MARKA RENGİ `accent`'İN YERİNE GEÇMİYOR. `AGENTS.md`: teal yalnızca birincil
-- aksiyon ve aktif durum için. Kırmızı markalı bir kulüpte "Kaydet" düğmesi
-- kırmızı olsaydı `danger` ile aynı görünürdü ve kullanıcı silmeyle kaydetmeyi
-- renkten ayırt edemezdi. Marka rengi yalnızca kimlik yüzeylerinde: kapak
-- bandı, profil şeridi, rozet.
--
-- YENİ POLİTİKA GEREKMİYOR: `clubs` güncellemesi zaten `is_club_admin(id)` ile
-- kısıtlı (0002), `profiles` da kendi satırına. Yeni sütunlar bunlara tabi.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) KİŞİ
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists cover_path     text,
  add column if not exists brand_color    text,
  -- Avatar arka plan tonu. **Nullable ve varsayılan null** — null olduğunda
  -- istemci bugünkü `name.length % 4` davranışını sürdürüyor. Varsayılan 0
  -- koysaydık herkesin avatarı bir gecede renk değiştirirdi.
  add column if not exists avatar_tint    int,
  add column if not exists pinned_post_id uuid references public.posts(id) on delete set null;

-- `on delete set null` şart: sabitlenen gönderi silinince profil kırılmamalı.

do $blk$ begin
  alter table public.profiles add constraint profiles_brand_color_check
    check (brand_color is null or brand_color ~ '^#[0-9A-Fa-f]{6}$');
exception when duplicate_object then null; end $blk$;

do $blk$ begin
  alter table public.profiles add constraint profiles_avatar_tint_check
    check (avatar_tint is null or avatar_tint between 0 and 7);
exception when duplicate_object then null; end $blk$;

-- ---------------------------------------------------------------------------
-- 2) KULÜP
--
-- `sections`: profilde hangi bölümler, hangi sırayla görünecek. **null =
-- varsayılan sıra** — kulüp dokunmadıysa hiçbir şey değişmiyor. Boş dizi ile
-- null farklı: boş dizi "hiçbir bölüm gösterme" demek ve bu geçerli bir
-- tercih.
-- ---------------------------------------------------------------------------
alter table public.clubs
  add column if not exists cover_path  text,
  add column if not exists brand_color text,
  add column if not exists sections    text[];

do $blk$ begin
  alter table public.clubs add constraint clubs_brand_color_check
    check (brand_color is null or brand_color ~ '^#[0-9A-Fa-f]{6}$');
exception when duplicate_object then null; end $blk$;

-- Bilinmeyen bölüm anahtarı, istemcide sessizce yok sayılacak bir satır
-- demek; şemada kesmek daha dürüst.
do $blk$ begin
  alter table public.clubs add constraint clubs_sections_check
    check (sections is null or sections <@ array[
      'about', 'teams', 'roster', 'achievements', 'announcements', 'contact'
    ]::text[]);
exception when duplicate_object then null; end $blk$;

-- ---------------------------------------------------------------------------
-- 3) SABİTLENMİŞ GÖNDERİ
--
-- RPC, çünkü doğrulama gerekiyor: yalnızca **kendi** ve **yayında** olan bir
-- gönderi sabitlenebilir. `check` kısıtı alt sorgu yapamıyor; tetikleyici de
-- olurdu ama tek bir yazma noktası varken RPC daha okunur.
-- ---------------------------------------------------------------------------
create or replace function public.set_pinned_post(p_post uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  -- null = sabitlemeyi kaldır.
  if p_post is not null then
    if not exists (
      select 1 from public.posts
       where id = p_post
         and author_profile_id = auth.uid()
         and status = 'active'
         -- Taslak sabitlenemez: profilde görünen ama kimsenin açamadığı bir
         -- kart olurdu.
         and visibility <> 'private_draft') then
      raise exception 'Yalnızca kendi yayındaki gönderini sabitleyebilirsin';
    end if;
  end if;

  update public.profiles set pinned_post_id = p_post where id = auth.uid();
end;
$fn$;

revoke execute on function public.set_pinned_post(uuid) from public, anon;
grant execute on function public.set_pinned_post(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 4) KULÜP KİMLİĞİNİ GÜNCELLE
--
-- `clubs` tablosuna doğrudan `update` zaten `is_club_admin` ile korunuyor ve
-- mobil onu kullanacak. Bu RPC yalnızca **kapak/logo yolu** için: Storage'a
-- yükleme istemcide yapılıyor ama yolun kulübün klasörüne yazıldığından emin
-- olmak sunucunun işi.
--
-- Yolu doğrulamasaydık, bir kulüp yöneticisi başka kulübün görselini kendi
-- kapağı olarak gösterebilirdi — zararı sınırlı ama şaşırtıcı.
-- ---------------------------------------------------------------------------
create or replace function public.set_club_media(
  p_club  uuid,
  p_logo  text default null,
  p_cover text default null)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if not public.is_club_admin(p_club) then
    raise exception 'Kulüp görselini yalnızca kulüp yöneticisi değiştirebilir';
  end if;

  if p_logo is not null and p_logo not like 'club/' || p_club::text || '/%' then
    raise exception 'Logo yolu bu kulübe ait değil';
  end if;

  if p_cover is not null and p_cover not like 'club/' || p_club::text || '/%' then
    raise exception 'Kapak yolu bu kulübe ait değil';
  end if;

  update public.clubs
     set logo_path  = coalesce(p_logo, logo_path),
         cover_path = coalesce(p_cover, cover_path),
         updated_at = now()
   where id = p_club;
end;
$fn$;

revoke execute on function public.set_club_media(uuid, text, text)
  from public, anon;
grant execute on function public.set_club_media(uuid, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5) STORAGE — kulüp görselleri
--
-- Kapak ve logo `post-media` bucket'ında; o bucket zaten **public** (0006) ve
-- avatar/logo oradan servis ediliyor. Kimlik görselleri profili görebilen
-- herkese açık; özel bucket + imzalı URL burada koruma değil, gereksiz
-- gecikme olurdu.
--
-- Mevcut yazma politikası `auth.uid()` klasörüne izin veriyor; kulüp
-- klasörü (`club/<id>/...`) için ek politika gerekiyor.
-- ---------------------------------------------------------------------------
drop policy if exists "club_media_write" on storage.objects;
create policy "club_media_write" on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = 'club'
    and public.is_club_admin(((storage.foldername(name))[2])::uuid)
  );

drop policy if exists "club_media_update" on storage.objects;
create policy "club_media_update" on storage.objects for update
  to authenticated
  using (
    bucket_id = 'post-media'
    and (storage.foldername(name))[1] = 'club'
    and public.is_club_admin(((storage.foldername(name))[2])::uuid)
  );

-- ---------------------------------------------------------------------------
-- 6) BAYRAK
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description) values
  ('identity_customization', 'admins', 'Kimlik özelleştirme',
   'Kapak görseli, marka rengi, avatar tonu ve kulüp vitrini. Marka rengi '
   'yalnızca kimlik yüzeylerinde; düğmeler ve aktif durumlar teal kalıyor.')
on conflict (key) do nothing;
