-- ---------------------------------------------------------------------------
-- 0069 — Sıkça sorulan sorular ve destek yazışması
--
-- 0066 destek talebi **açmayı** getirmişti ama yanıt yazmanın yolu yoktu:
-- `support_messages` tablosunda yalnızca okuma politikası vardı, insert
-- politikası da RPC de yoktu. Yani talep açılıyor, kimse cevaplayamıyordu.
--
-- SSS bugüne kadar hiç yoktu. Uygulamada tek yardım yüzeyi, ekranlardaki
-- açıklama metinleriydi.
--
-- SSS NEDEN VERİTABANINDA: koda gömseydik her yeni soru için yeni bir APK
-- ve web dağıtımı gerekirdi. Yardım içeriği ürünün en sık değişen parçası;
-- platform yöneticisi konsoldan yazabilmeli.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) SSS
--
-- `audience`: soruyu kimin göreceği. Veli "antrenör kademem neden
-- görünmüyor" sorusunu görmemeli — ilgisiz yardım içeriği, yardımı
-- okunmaz yapıyor.
-- ---------------------------------------------------------------------------
create table if not exists public.faq_entries (
  id         uuid primary key default gen_random_uuid(),
  question   text not null,
  answer     text not null,
  category   text not null default 'genel',
  audience   text not null default 'everyone',
  sort_order int not null default 0,
  active     boolean not null default true,
  -- İlgili ekrana götüren rota. Cevabın sonunda "oraya git" düğmesi olarak
  -- çiziliyor; kullanıcıyı menüde aratmaktan iyi.
  route      text,
  updated_by uuid references public.profiles(id) on delete set null,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

do $blk$ begin
  alter table public.faq_entries add constraint faq_audience_check
    check (audience in ('everyone', 'athlete', 'parent', 'coach',
                        'club_staff', 'accountant'));
exception when duplicate_object then null; end $blk$;

create index if not exists idx_faq_active
  on public.faq_entries (active, category, sort_order);

alter table public.faq_entries enable row level security;

-- Okuma **anon'a da açık**: giriş yapmadan da yardım okunabilmeli.
-- Uygulamayı ilk açan kişinin sorusu tam da o an oluşuyor.
drop policy if exists "faq_read" on public.faq_entries;
create policy "faq_read" on public.faq_entries for select
  to anon, authenticated using (active);

drop policy if exists "faq_admin" on public.faq_entries;
create policy "faq_admin" on public.faq_entries for all
  to authenticated
  using (public.is_platform_admin())
  with check (public.is_platform_admin());

-- ---------------------------------------------------------------------------
-- SSS ARAMASI
--
-- `tr_contains` ile (0048): "aidat" ve "AİDAT" aynı sonucu veriyor,
-- "isiklar" yazınca "Işıklar" bulunuyor. Düz `ilike` bunu bulmuyor ve bu
-- depoda beş ekran hâlâ o hatayı taşıyor.
-- ---------------------------------------------------------------------------
create or replace function public.search_faq(
  p_query    text default null,
  p_audience text[] default null)
returns table (
  id       uuid,
  question text,
  answer   text,
  category text,
  route    text)
language sql
stable
security definer
set search_path = public
as $fn$
  select f.id, f.question, f.answer, f.category, f.route
    from public.faq_entries f
   where f.active
     -- Kitle süzgeci: null geçilirse yalnızca herkese açık olanlar.
     and (f.audience = 'everyone'
          or (p_audience is not null and f.audience = any (p_audience)))
     and (coalesce(trim(p_query), '') = ''
          or public.tr_contains(f.question, p_query)
          or public.tr_contains(f.answer, p_query))
   order by f.category, f.sort_order, f.question;
$fn$;

revoke execute on function public.search_faq(text, text[]) from public;
grant execute on function public.search_faq(text, text[]) to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2) DESTEK YAZIŞMASI
--
-- Yanıt da RPC'den, doğrudan insert'ten değil: gövde **sunucuda**
-- ayıklanıyor. İstemciye güvenmek, eski bir uygulama sürümünün ham veri
-- göndermesini engellemiyor (0066'daki aynı gerekçe).
--
-- `is_staff` istemciden GELMİYOR, sunucu belirliyor. İstemciden alsaydık
-- herhangi biri kendi mesajını "yetkili" gibi gösterebilirdi.
-- ---------------------------------------------------------------------------
create or replace function public.reply_support_ticket(
  p_ticket uuid,
  p_body   text)
returns uuid
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_t     public.support_tickets%rowtype;
  v_staff boolean;
  v_id    uuid;
begin
  if auth.uid() is null then
    raise exception 'Giriş yapılmamış';
  end if;

  if coalesce(trim(coalesce(p_body, '')), '') = '' then
    raise exception 'Mesaj boş olamaz';
  end if;

  select * into v_t from public.support_tickets where id = p_ticket;
  if v_t.id is null then
    raise exception 'Destek talebi bulunamadı';
  end if;

  v_staff := public.is_platform_admin();

  if not v_staff and v_t.profile_id <> auth.uid() then
    raise exception 'Bu talebe yanıt verme yetkiniz yok';
  end if;

  if v_t.status = 'closed' then
    raise exception 'Kapatılmış talebe yanıt yazılamaz';
  end if;

  insert into public.support_messages (ticket_id, sender_id, body, is_staff)
  values (p_ticket, auth.uid(),
          public.sanitize_support_text(trim(p_body)), v_staff)
  returning id into v_id;

  -- Durum yazışmaya göre kendiliğinden ilerliyor. Elle durum değiştirmeyi
  -- zorunlu kılmak, kimsenin yapmadığı bir adım olurdu.
  update public.support_tickets
     set status = case
           when v_staff then 'awaiting_user_response'
           when v_t.status in ('awaiting_user_response', 'resolved')
             then 'under_review'
           else v_t.status
         end,
         updated_at = now()
   where id = p_ticket;

  -- Karşı tarafa bildirim.
  if v_staff then
    insert into public.notifications
      (profile_id, kind, title, body, entity_type, entity_id)
    values (v_t.profile_id, 'support', 'Destek talebine yanıt geldi',
            left(v_t.subject, 100), 'support_ticket', p_ticket);
  end if;

  return v_id;
end;
$fn$;

revoke execute on function public.reply_support_ticket(uuid, text)
  from public, anon;
grant execute on function public.reply_support_ticket(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- DURUM DEĞİŞTİRME
--
-- Kullanıcı kendi talebini **kapatabiliyor** (sorunu kendi çözmüş olabilir),
-- ama `resolved` işaretlemek yalnızca yetkilinin işi: kendi talebini
-- "çözüldü" yapmak istatistiği anlamsızlaştırırdı.
-- ---------------------------------------------------------------------------
create or replace function public.set_support_status(
  p_ticket uuid,
  p_status text)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_t     public.support_tickets%rowtype;
  v_staff boolean;
begin
  select * into v_t from public.support_tickets where id = p_ticket;
  if v_t.id is null then
    raise exception 'Destek talebi bulunamadı';
  end if;

  v_staff := public.is_platform_admin();

  if not v_staff then
    if v_t.profile_id <> auth.uid() then
      raise exception 'Bu talebi değiştirme yetkiniz yok';
    end if;
    if p_status <> 'closed' then
      raise exception 'Kendi talebinizde yalnızca kapatma yapabilirsiniz';
    end if;
  end if;

  update public.support_tickets
     set status = p_status,
         resolved_at = case
           when p_status in ('resolved', 'closed') then now()
           else null
         end,
         updated_at = now()
   where id = p_ticket;
end;
$fn$;

revoke execute on function public.set_support_status(uuid, text)
  from public, anon;
grant execute on function public.set_support_status(uuid, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- DESTEK KUYRUĞU — platform yöneticisi
-- ---------------------------------------------------------------------------
create or replace function public.support_queue(
  p_status text default null,
  p_limit  int default 50)
returns table (
  ticket_id    uuid,
  subject      text,
  status       text,
  requester    text,
  club_name    text,
  message_count bigint,
  last_activity timestamptz,
  created_at    timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $fn$
begin
  if not public.is_platform_admin() then
    raise exception 'Destek kuyruğu yalnızca platform yöneticisine açık';
  end if;

  return query
    select t.id, t.subject, t.status,
           coalesce(p.full_name, 'Bilinmiyor'),
           c.name,
           (select count(*) from public.support_messages m
             where m.ticket_id = t.id),
           greatest(t.updated_at,
                    coalesce((select max(m.created_at)
                                from public.support_messages m
                               where m.ticket_id = t.id), t.created_at)),
           t.created_at
      from public.support_tickets t
      left join public.profiles p on p.id = t.profile_id
      left join public.clubs c on c.id = t.club_id
     where (p_status is null or p_status = 'all' or t.status = p_status)
     -- Açık talepler önce; içlerinde en eski önce, çünkü en uzun bekleyen
     -- kişi en çok hak edendir.
     order by (t.status in ('resolved', 'closed')),
              t.created_at
     limit least(greatest(coalesce(p_limit, 50), 1), 200);
end;
$fn$;

revoke execute on function public.support_queue(text, int) from public, anon;
grant execute on function public.support_queue(text, int) to authenticated;

-- ---------------------------------------------------------------------------
-- 3) BAŞLANGIÇ İÇERİĞİ
--
-- Gerçek sorular. Boş bir SSS ekranı, hiç SSS olmamasından kötü: kullanıcı
-- bir kez bakıp bir daha açmıyor.
--
-- `on conflict do nothing` yok çünkü tekillik anahtarı yok; bunun yerine
-- `where not exists` ile tekrar çalıştırmada çoğalması engelleniyor.
-- ---------------------------------------------------------------------------
insert into public.faq_entries (question, answer, category, audience, sort_order, route)
select * from (values
  ('Kulübe nasıl katılırım?',
   'Keşfet sekmesinden kulübü bul, profiline gir ve "Başvur" düğmesine bas. '
   'Kulüp yöneticisi başvurunu görüp onayladığında kadroya eklenirsin. '
   'Onaylanana kadar kulüp içeriğini göremezsin.',
   'Başlangıç', 'everyone', 10, '/kulupler'),

  ('Antrenör kademem neden görünmüyor?',
   'Kademe beyanla değil, onaylanmış belgeyle belirleniyor. Profil > '
   'Doğrulama''dan antrenörlük belgeni yükle; platform yöneticisi '
   'onayladığında kademen ve branşın profiline işlenir.',
   'Başlangıç', 'everyone', 20, '/dogrulama'),

  ('Aidatımı ödedim ama borcum duruyor.',
   'Ödeme bildirimin kulüp yöneticisinin onayını bekliyor olabilir. '
   'Aidatlarım ekranında bildirim "onay bekliyor" görünüyorsa yapman '
   'gereken bir şey yok. Bir gün içinde onaylanmadıysa kulübünle iletişime '
   'geç.',
   'Aidat', 'everyone', 30, '/aidatlarim'),

  ('Veli olarak çocuğumu nasıl bağlarım?',
   'Kulüpten aldığın davet kodunu Profil > Veli bağlantısı ekranına gir. '
   'Bağlantı kurulduğunda çocuğunun aidatını, programını ve yoklamasını '
   'isimli olarak görürsün.',
   'Veli', 'everyone', 40, '/veli-bagla'),

  ('Bildirim gelmiyor.',
   'Önce telefonun ayarlarından SwanSport bildirimlerinin açık olduğunu '
   'kontrol et. Uygulama içinde de Ayarlar > Bildirimler''den kapatılmış '
   'olabilir. Doğrudan mesaj ve resmî duyuru bildirimleri kapatılamaz; '
   'gelmiyorsa uygulamayı kapatıp yeniden aç.',
   'Bildirim', 'everyone', 50, '/settings'),

  ('Gönderimi kimler görüyor?',
   'Gönderi yazarken görünürlük seçebilirsin: Herkese açık, Takipçiler ya '
   'da Kulüp. Reşit olmayan hesaplarda varsayılan olarak Takipçiler '
   'seçilidir. Kulüp adına paylaşımlar zaten yalnızca kulüp kitlesine '
   'gider.',
   'Sosyal', 'everyone', 60, '/akis'),

  ('Beni kimse etiketlemesin istiyorum.',
   'Gizlilik ve Hesap > Etiketlenme''den "Kimse etiketleyemez" seçeneğini '
   'işaretle. Engellediğin kişiler zaten hiçbir durumda seni '
   'etiketleyemiyor.',
   'Sosyal', 'everyone', 70, '/gizlilik'),

  ('Kaydettiğim gönderileri kim görüyor?',
   'Sadece sen. Kaydetmek kişisel bir yer imi; gönderi sahibine bildirim '
   'gitmiyor ve kaç kişinin kaydettiği hiçbir yerde gösterilmiyor.',
   'Sosyal', 'everyone', 80, '/kaydedilenler'),

  ('Kulübümün rengini ve kapağını nasıl değiştiririm?',
   'Ayarlar > Kulüp profili''nden logo, kapak, renk, iletişim bilgileri ve '
   'profil bölümlerinin sırasını düzenleyebilirsin. Bu ekran yalnızca kulüp '
   'yöneticisine açık.',
   'Kulüp', 'club_staff', 90, '/settings'),

  ('Kort sırasını nasıl alırım?',
   'Sahalar > Kortlar''dan kortu seç ve boş bir saati al. Sıranı '
   'koruyabilmek için saatinde kortta olup konum doğrulaması yapman '
   'gerekiyor; on dakika içinde doğrulamazsan saat düşer.',
   'Kort', 'everyone', 100, '/kortlar'),

  ('Uygulama güncellemesi nasıl geliyor?',
   'SwanSport Play Store''da değil. Yeni sürüm çıktığında uygulamayı '
   'açtığında üstte bir uyarı görürsün ve "Güncelle" dediğinde indirme '
   'uygulama içinde yapılır. Android kurulum onayı isteyecektir, bu normal.',
   'Genel', 'everyone', 110, null),

  ('Taslak giderim rapora girmiyor.',
   'Mobilden fişle girilen gider "taslak" olarak kaydediliyor ve bilerek '
   'bakiyeye, bütçeye ve rapora girmiyor. Konsolda Gelir–Gider ekranından '
   'kategori ve hesap seçip tamamladığında deftere işleniyor.',
   'Mali', 'club_staff', 120, '/mali-isler'),

  ('Muhasebecim sporcuların adını görüyor mu?',
   'Hayır. Dış muhasebeciye sporcu tablosuna erişim verilmiyor ve mali '
   'ekranlarda isim yerine #A3F91C biçiminde anonim bir referans kodu '
   'görünüyor. Bu bir arayüz tercihi değil, veritabanı kuralı.',
   'Mali', 'club_staff', 130, null)
) as v(question, answer, category, audience, sort_order, route)
where not exists (
  select 1 from public.faq_entries f where f.question = v.question);

-- ---------------------------------------------------------------------------
-- 4) BİLDİRİM ROTASI
--
-- 0063'teki 33 eşlemenin hepsi korunuyor + `support`.
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
    when 'mention'                   then '/akis'
    when 'post_repost'               then '/akis'
    when 'post_quote'                then '/akis'
    -- 0069
    when 'support'                   then '/destek'
    when 'eligibility'               then '/athletes'
    else '/bildirimler'
  end;
$fn$;
