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
