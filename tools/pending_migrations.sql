-- ===========================================================================
-- SwanSport — bekleyen migration'lar (0067-0068)
--
-- Supabase SQL Editor'e yapistir, tek seferde calistir.
--
-- 0053-0066 CANLIDA (2026-09-02 dogrulandi). Bu dosyada iki migration var:
--   0067  etiket secici (@kisi, #etiket)
--   0068  kimlik ozellestirme (kapak, marka rengi, avatar tonu, vitrin)
--
-- NE GETIRIYOR
--   can_mention()          etiketleme izni tek yerde: engelleme + politika
--   search_mentionable()   secicide YALNIZCA etiketlenmeyi kabul edenler
--   search_hashtags()      tr_fold ile arama ("#Isiklar" bulunabilsin)
--   set_post_tags()        artik TOLERANSLI ve kac kisinin etiketlendigini
--                          donuyor
--
-- NEDEN GEREKLI
--   Eskiden secici profiles tablosunu duz sorguluyordu: etiketlenmeyi
--   kapatmis ve engellenmis kisiler de listeleniyordu. Kullanici onlari
--   seciyor, sonra etiketleme reddediliyordu — ve tek kotu etiket BUTUN
--   etiketlemeyi dusuruyordu.
--
--   set_post_tags imzasi AYNI kaldi (uuid, uuid[], text[]), yalnizca donus
--   tipi void'den int'e gecti; ayni imza oldugu icin "create or
--   replace" yeterli ve HTTP 300 tuzagi acilmiyor.
--
-- CALISTIRILMAZSA: secici hic acilmiyor (hata gostermiyor, sessizce bos),
-- hashtag yazan kullanici "etiketler eklenemedi" uyarisi aliyor. Gonderi
-- yine paylasiliyor.
-- ===========================================================================

begin;


-- ===========================================================================
-- 0067_mention_picker.sql
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 0067 — Etiket seçici
--
-- İKİ SORUNU ÇÖZÜYOR:
--
-- 1. **Seçicide kimi göstereceğiz.** İstemcinin `profiles` tablosunu düz
--    sorgulaması, etiketlenmeyi kapatmış ve engellenmiş kişileri de
--    listeliyordu. Kullanıcı onları seçebiliyor, sonra etiketleme
--    reddediliyordu.
--
-- 2. **Tek kötü etiket bütün etiketlemeyi düşürüyordu.** `set_post_tags`
--    doğrudan insert yapıyor ve `trg_post_mention_guard` reddedince
--    fonksiyonun tamamı hata veriyordu — on kişiden biri etiketlenmeyi
--    kapatmışsa diğer dokuzu da yazılmıyordu.
--
-- Çözüm ikisi için de aynı: **kuralı tek yerde topla** ve hem seçici hem
-- yazma onu kullansın. Tetikleyici yerinde kalıyor; artık son savunma,
-- birinci savunma değil.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) ETİKETLENEBİLİR Mİ
--
-- Tek kaynak. `trg_post_mention_guard` ile aynı üç kuralı uyguluyor:
-- engelleme, `nobody`, ve `following` durumunda takip ilişkisi.
-- ---------------------------------------------------------------------------
create or replace function public.can_mention(p_author uuid, p_target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select case
    -- Kendini her zaman etiketleyebilirsin.
    when p_author = p_target then true
    when public.is_blocked_between(p_author, p_target) then false
    else coalesce((
      select case pr.mention_policy
        when 'nobody' then false
        when 'following' then exists (
          select 1 from public.follows f
           where f.follower_id = p_target
             and f.target_type = 'profile'
             and f.target_id = p_author)
        else true
      end
      from public.profiles pr where pr.id = p_target), false)
  end;
$fn$;

revoke execute on function public.can_mention(uuid, uuid) from public, anon;
grant execute on function public.can_mention(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 2) SEÇİCİ ARAMASI
--
-- Türkçe arama `tr_contains` ile (0048): "isiklar" yazınca "Işıklar"
-- bulunuyor. Düz `ilike` bunu bulmuyor ve bu depoda beş ekranda hâlâ öyle.
--
-- Etiketlenmeyi kapatmış kişi listede **hiç görünmüyor**. Bu bir sızıntı
-- değil: "bu kişi etiketlenmeyi kapatmış" diye bir mesaj göstermiyoruz,
-- kişi yalnızca sonuçlarda yok.
-- ---------------------------------------------------------------------------
create or replace function public.search_mentionable(
  p_query text default null,
  p_limit int default 8)
returns table (
  profile_id uuid,
  full_name  text,
  username   text,
  avatar_path text)
language sql
stable
security definer
set search_path = public
as $fn$
  select p.id, p.full_name, p.username, p.avatar_path
    from public.profiles p
   where auth.uid() is not null
     and p.id <> auth.uid()
     and public.can_mention(auth.uid(), p.id)
     and (coalesce(trim(p_query), '') = ''
          or public.tr_contains(p.full_name, p_query)
          or public.tr_contains(coalesce(p.username, ''), p_query))
   -- Takip ettiklerin önce: etiketlemek istediğin kişi büyük ihtimalle
   -- tanıdığın biri.
   order by exists (
     select 1 from public.follows f
      where f.follower_id = auth.uid()
        and f.target_type = 'profile'
        and f.target_id = p.id) desc,
     p.full_name
   limit least(greatest(coalesce(p_limit, 8), 1), 25);
$fn$;

revoke execute on function public.search_mentionable(text, int)
  from public, anon;
grant execute on function public.search_mentionable(text, int)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3) ETİKET YAZMA — artık toleranslı
--
-- Aynı imza, bu yüzden `create or replace` yeterli (HTTP 300 tuzağı yok).
--
-- Değişen: izin vermeyen kişiler **atlanıyor**, hata verilmiyor. Eskiden
-- tek bir uygunsuz etiket bütün etiketlemeyi düşürüyordu ve kullanıcı
-- gönderisini paylaştıktan sonra "etiketler yazılamadı" hatası alıyordu.
--
-- Sınır aşımı hâlâ hata: on kişiden fazlasını sessizce kırpmak, kullanıcının
-- seçtiği birinin kaybolması demek.
-- ---------------------------------------------------------------------------
create or replace function public.set_post_tags(
  p_post     uuid,
  p_mentions uuid[] default '{}',
  p_hashtags text[] default '{}')
returns int
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_author uuid;
  v_tag    text;
  v_n      int := 0;
begin
  select author_profile_id into v_author from public.posts where id = p_post;
  if v_author is null then
    raise exception 'Gönderi bulunamadı';
  end if;
  if v_author <> auth.uid() then
    raise exception 'Yalnızca kendi gönderini etiketleyebilirsin';
  end if;

  if coalesce(array_length(p_mentions, 1), 0) > 10 then
    raise exception 'Bir gönderide en fazla 10 kişi etiketlenebilir';
  end if;

  delete from public.post_mentions where post_id = p_post;
  delete from public.post_hashtags where post_id = p_post;

  -- İzin vermeyenler atlanıyor. Tetikleyici yine de yerinde: doğrudan
  -- insert eden bir yol kalırsa o da kesiliyor.
  insert into public.post_mentions (post_id, mentioned_profile_id)
  select p_post, m
    from unnest(coalesce(p_mentions, '{}')) m
   where public.can_mention(v_author, m)
  on conflict do nothing;

  get diagnostics v_n = row_count;

  foreach v_tag in array coalesce(p_hashtags, '{}') loop
    if coalesce(trim(both '#' from trim(v_tag)), '') <> '' then
      insert into public.post_hashtags (post_id, tag)
      values (p_post, public.tr_fold(trim(both '#' from trim(v_tag))))
      on conflict do nothing;
    end if;
  end loop;

  -- Etiketlenene bildirim. Kendine etiket bildirim üretmiyor.
  insert into public.notifications
    (profile_id, kind, title, body, entity_type, entity_id, actor_id)
  select m.mentioned_profile_id, 'mention', 'Bir gönderide etiketlendin',
         left((select body from public.posts where id = p_post), 100),
         'post', p_post, auth.uid()
    from public.post_mentions m
   where m.post_id = p_post
     and m.mentioned_profile_id <> auth.uid();

  -- Kaç kişinin gerçekten etiketlendiği. İstemci bunu gönderilen sayıyla
  -- karşılaştırıp "2 kişi etiketlenemedi" diyebiliyor.
  return v_n;
end;
$fn$;

revoke execute on function public.set_post_tags(uuid, uuid[], text[])
  from public, anon;
grant execute on function public.set_post_tags(uuid, uuid[], text[])
  to authenticated;

-- ---------------------------------------------------------------------------
-- 4) HASHTAG ARAMASI
--
-- Etiketler `tr_fold` ile saklanıyor, arama da öyle yapılmalı; yoksa
-- "#Işıklar" yazan kişi kendi etiketini bulamıyor.
-- ---------------------------------------------------------------------------
create or replace function public.search_hashtags(
  p_query text default null,
  p_limit int default 8)
returns table (tag text, post_count bigint)
language sql
stable
security definer
set search_path = public
as $fn$
  select h.tag, count(*)
    from public.post_hashtags h
    join public.posts p on p.id = h.post_id
   where auth.uid() is not null
     and p.status = 'active'
     and (coalesce(trim(p_query), '') = ''
          or h.tag like public.tr_fold(trim(both '#' from p_query)) || '%')
   group by h.tag
   order by 2 desc, 1
   limit least(greatest(coalesce(p_limit, 8), 1), 25);
$fn$;

revoke execute on function public.search_hashtags(text, int) from public, anon;
grant execute on function public.search_hashtags(text, int) to authenticated;

-- ===========================================================================
-- 0068_identity_customization.sql
-- ===========================================================================

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


commit;

-- ===========================================================================
-- DOGRULAMA (ayri calistir)
--
--   select proname, pronargs from pg_proc p
--     join pg_namespace n on n.oid = p.pronamespace
--    where n.nspname = 'public'
--      and proname in ('can_mention','search_mentionable','search_hashtags',
--                      'set_post_tags')
--    order by 1;
--
-- Dort satir donmeli ve set_post_tags TEK satir olmali. Iki satir cikarsa
-- eski imza dusmemis demektir ve PostgREST HTTP 300 doner.
-- ===========================================================================
