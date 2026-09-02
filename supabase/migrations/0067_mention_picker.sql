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
-- Değişen: izin vermeyen kişiler **atlanıyor**, hata verilmiyor. Eskiden
-- tek bir uygunsuz etiket bütün etiketlemeyi düşürüyordu ve kullanıcı
-- gönderisini paylaştıktan sonra "etiketler yazılamadı" hatası alıyordu.
--
-- Sınır aşımı hâlâ hata: on kişiden fazlasını sessizce kırpmak, kullanıcının
-- seçtiği birinin kaybolması demek.
-- ---------------------------------------------------------------------------
-- DÖNÜŞ TİPİ DEĞİŞİYOR: 0063'te `returns void` idi, burada `returns int`.
-- `create or replace function` **dönüş tipini değiştiremez** — argüman imzası
-- aynı olsa bile `42P13: cannot change return type of existing function`
-- veriyor. Önce düşürmek şart.
--
-- Bu dosyanın ilk sürümünde başlığa "aynı imza, create or replace yeterli"
-- yazmıştım; yanlıştı. Aynı olan argüman imzası, dönüş tipi değil.
drop function if exists public.set_post_tags(uuid, uuid[], text[]);

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
