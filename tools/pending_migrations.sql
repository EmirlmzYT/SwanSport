-- ===========================================================================
-- SwanSport — bekleyen migration'lar (0069-0070): SSS ve destek
--
-- 0053-0068 CANLIDA (2026-09-02 dogrulandi). Bu dosyada iki migration var:
--   0069  SSS + destek yazismasi
--   0070  SSS OZELLIGI TAKIP ETSIN — yardimsiz yayin yok
--
-- ---------------------------------------------------------------------------
-- KILIT CAKISMASI (40P01 deadlock) YASANDIYSA
--
-- Bu dosya once TEK bir islemdi ve butun kilitler sonuna kadar tutuluyordu.
-- `alter table` AccessExclusiveLock istiyor; ayni anda calisan bir sey
-- (pg_cron isi, acik uygulama sekmesi, PostgREST sema yenilemesi) o tabloyu
-- okuyorsa iki taraf birbirini bekleyip deadlock veriyor.
--
-- Simdi IKI AYRI ISLEM var ve her birinde `lock_timeout` tanimli:
--   * kilit 15 saniyede gelmezse islem TEMIZ SEKILDE dusuyor (55P03),
--     deadlock yerine anlasilir bir hata veriyor
--   * 0067 gecip 0068 duserse yalnizca 0068 tekrar calistirilir
--
-- CALISTIRMADAN ONCE:
--   1. Uygulamayi ve konsolu acik sekmelerde KAPAT (acik sekme sorgu atiyor)
--   2. Hata alirsan bekleyip TEKRAR DENE — deadlock geciciddir
--
-- Hangi tablolarin cakistigini gormek icin (hata mesajindaki sayilarla):
--   select 17294::regclass, 21547::regclass;
--
-- Zamanlanmis isler cakisiyorsa gecici olarak durdurulabilir:
--   select cron.unschedule(jobname) from cron.job
--    where jobname like 'swansport_%';
--   -- ... migration'i calistir, sonra 0056/0057/0061/0064/0066'yi
--   -- tekrar calistirarak isleri geri kur.
--
-- ---------------------------------------------------------------------------
-- NE GETIRIYOR
--
--   faq_entries          SSS icerigi VERITABANINDA — yeni soru icin APK
--                        yayinlamak gerekmiyor, konsoldan yazilir
--   search_faq()         tr_contains ile arama; "aidat" ve "AIDAT" ayni
--   reply_support_ticket()  0066 talep ACMAYI getirmisti ama YANIT YAZMANIN
--                        yolu yoktu: support_messages'ta yalnizca okuma
--                        politikasi vardi. Talep aciliyordu, kimse
--                        cevaplayamiyordu.
--   set_support_status() kullanici kendi talebini KAPATABILIYOR, ama
--                        'cozuldu' isaretlemek yetkilinin isi
--   support_queue()      platform yoneticisi kuyrugu; EN ESKI ONCE
--
--   13 baslangic sorusu ekleniyor (aidat, bildirim, kort, gizlilik, veli,
--   mali). Bos bir SSS ekrani, hic SSS olmamasindan kotu.
--
--   push_route: 33 -> 35. 'eligibility' turu 0064'ten beri ROTASIZDI ve
--   /bildirimler'e dusuyordu; artik /athletes'e gidiyor.
--
--   0070 — SSS ARTIK OZELLIGI TAKIP EDIYOR:
--   faq_entries.feature  bir bayrak anahtarina baglaniyor
--   trg_faq_before_release  bir bayragi testers/everyone yapmayi, o
--                        anahtara bagli aktif SSS satiri yoksa REDDEDIYOR.
--                        Geri cekmek (off/admins) kontrolsuz.
--   faq_coverage()       hangi ozelligin yardimi eksik
--   search_faq()         imza degisti (ucuncu parametre), eski surum
--                        dusuruluyor — HTTP 300 tuzagi
--   34 bayragin HEPSININ yardimi yaziliyor; kapi bugun konsaydi hicbir
--   ozellik yayinlanamazdi.
--
-- TEKRAR CALISTIRILABILIR: `create or replace`, `if not exists`,
-- `on conflict do nothing`. Emin degilsen tekrar calistir.
-- ===========================================================================


-- ===========================================================================
-- 1/2  0069_faq_and_support.sql
-- ===========================================================================

begin;

-- Kilit 15 saniyede gelmezse islem temiz dusuyor: deadlock
-- yerine anlasilir bir hata (55P03 lock_not_available).
set local lock_timeout = '15s';

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

commit;

-- ===========================================================================
-- 2/2  0070_faq_follows_features.sql
-- ===========================================================================

begin;

-- Kilit 15 saniyede gelmezse islem temiz dusuyor: deadlock
-- yerine anlasilir bir hata (55P03 lock_not_available).
set local lock_timeout = '15s';

-- ---------------------------------------------------------------------------
-- 0070 — SSS özelliği takip etsin
--
-- SORUN: SSS bir kez dolduruldu (0069) ve oradan sonra arkada kalacaktı.
-- Bu depoda aynı şey iki kez yaşandı — `push_route` eşlemeleri iki kez
-- sessizce düştü, AGENTS.md bir süre olmayan bir fonksiyondan bahsetti.
-- "Özellik ekleyince SSS'yi de güncelle" bir niyet; niyetler eskiyor.
--
-- ÇÖZÜM: kuralı veritabanına koy. Bir özelliği `admins`'ten ileri taşımak
-- (yani gerçek kullanıcılara açmak) **yardımı yazılmadan mümkün olmasın.**
--
-- Neden tam o an: `admins` kademesi senin kendi denemen, yardım gerekmiyor.
-- `testers` ve `everyone` ise başkalarının kullanması demek ve yardıma tam
-- o an ihtiyaç doğuyor.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) SSS ↔ ÖZELLİK BAĞI
--
-- `feature` null ise soru genel (ör. "kulübe nasıl katılırım"). Dolu ise
-- yalnızca o özellik kullanıcıya açıkken görünüyor: kapalı bir özelliğin
-- yardımını göstermek, olmayan bir düğmeyi tarif etmek olurdu.
-- ---------------------------------------------------------------------------
alter table public.faq_entries
  add column if not exists feature text
    references public.feature_flags(key) on delete set null;

create index if not exists idx_faq_feature
  on public.faq_entries (feature) where feature is not null;

-- ---------------------------------------------------------------------------
-- 2) KAPI: yardımsız yayın yok
--
-- `feature_flags.audience` `testers` ya da `everyone` yapılırken o anahtara
-- bağlı **aktif** bir SSS kaydı yoksa değişiklik reddediliyor.
--
-- Geri çekmek her zaman serbest: `off` ve `admins`'e dönüş kontrolsüz.
-- Bir sorunu geri almak, yardım yazmayı beklememeli.
-- ---------------------------------------------------------------------------
create or replace function public.require_faq_before_release()
returns trigger
language plpgsql
as $fn$
begin
  -- Yalnızca ileri gidişte kontrol.
  if new.audience not in ('testers', 'everyone') then
    return new;
  end if;

  -- Zaten yayındaysa ve kademe değişmiyorsa dokunma.
  if tg_op = 'UPDATE' and old.audience = new.audience then
    return new;
  end if;

  if not exists (
    select 1 from public.faq_entries f
     where f.feature = new.key and f.active) then
    raise exception
      'Bu özellik yardımı yazılmadan yayınlanamaz: "%" anahtarına bağlı '
      'aktif bir SSS kaydı yok. Konsol > Yardım içeriği ekranından en az '
      'bir soru ekle, sonra kademeyi ilerlet.', new.key
      using errcode = 'check_violation';
  end if;

  return new;
end;
$fn$;

drop trigger if exists trg_faq_before_release on public.feature_flags;
create trigger trg_faq_before_release
  before insert or update of audience on public.feature_flags
  for each row execute function public.require_faq_before_release();

-- ---------------------------------------------------------------------------
-- 3) KAPSAM RAPORU
--
-- Hangi özelliğin yardımı eksik. Konsolda uyarı olarak gösteriliyor;
-- kademeyi ilerletmeye çalışıp hata almadan önce görülsün.
-- ---------------------------------------------------------------------------
create or replace function public.faq_coverage()
returns table (
  feature      text,
  label        text,
  audience     text,
  entry_count  bigint,
  blocks_release boolean)
language sql
stable
security definer
set search_path = public
as $fn$
  select ff.key, ff.label, ff.audience,
         count(f.id),
         -- Yayına engel: henüz açılmamış ama yardımı da yok.
         (count(f.id) = 0 and ff.audience in ('off', 'admins'))
    from public.feature_flags ff
    left join public.faq_entries f
      on f.feature = ff.key and f.active
   group by ff.key, ff.label, ff.audience
   order by (count(f.id) = 0) desc, ff.key;
$fn$;

revoke execute on function public.faq_coverage() from public, anon;
grant execute on function public.faq_coverage() to authenticated;

-- ---------------------------------------------------------------------------
-- 4) SSS OKUMASI — özellik süzgeci
--
-- İmza değişiyor (üçüncü parametre), o yüzden eski sürüm düşürülüyor:
-- `create or replace` yalnızca aynı imzayı değiştirir ve eski imza kalırsa
-- PostgREST HTTP 300 döner.
-- ---------------------------------------------------------------------------
drop function if exists public.search_faq(text, text[]);

create or replace function public.search_faq(
  p_query    text default null,
  p_audience text[] default null,
  p_features text[] default null)
returns table (
  id       uuid,
  question text,
  answer   text,
  category text,
  route    text,
  feature  text)
language sql
stable
security definer
set search_path = public
as $fn$
  select f.id, f.question, f.answer, f.category, f.route, f.feature
    from public.faq_entries f
   where f.active
     and (f.audience = 'everyone'
          or (p_audience is not null and f.audience = any (p_audience)))
     -- Kapalı bir özelliğin yardımını göstermek, olmayan bir düğmeyi
     -- tarif etmek olurdu.
     and (f.feature is null
          or (p_features is not null and f.feature = any (p_features)))
     and (coalesce(trim(p_query), '') = ''
          or public.tr_contains(f.question, p_query)
          or public.tr_contains(f.answer, p_query))
   order by f.category, f.sort_order, f.question;
$fn$;

revoke execute on function public.search_faq(text, text[], text[]) from public;
grant execute on function public.search_faq(text, text[], text[])
  to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 5) MEVCUT ÖZELLİKLERİN YARDIMI
--
-- Otuz dört bayrak var ve hiçbirinin yardımı yoktu. Kapı bugün konsaydı
-- hiçbir özellik yayınlanamazdı — o yüzden hepsi burada yazılıyor.
--
-- Kısa tutuldu: SSS'nin işi kullanıcıyı doğru ekrana götürmek, kılavuz
-- yazmak değil.
-- ---------------------------------------------------------------------------
insert into public.faq_entries
  (question, answer, category, audience, sort_order, route, feature)
select * from (values
  ('Pazaryerinde nasıl ilan veririm?',
   'Keşfet > Pazaryeri''ne git ve "İlan ver" düğmesine bas. Bireysel '
   'ilanlarda 24 saatte en fazla 5 ilan verebilirsin. Sıfır ürün ilanı '
   'yalnızca onaylı mağazalardan açılabiliyor.',
   'Pazaryeri', 'everyone', 200, '/pazaryeri', 'marketplace'),

  ('Halka açık kortlarda sıra nasıl işliyor?',
   'Sahadaki kural aynı: orada olan oynar. Uygulama yalnızca beklemeyi '
   'evine taşıyor. En fazla 3 saat ileri saat alabilirsin, kişi başına tek '
   'aktif saat var ve sıran gelince kortta konum doğrulaman gerekiyor.',
   'Kort', 'everyone', 210, '/kortlar', 'courts'),

  ('Partner nasıl bulurum?',
   'Sahalar > Partner Bul''dan branşını seç ve "Partner arıyorum" de. '
   'Aynı şehirdeki, o branşla ilgilenen doğrulanmış kişilere bildirim '
   'gidiyor. Kabul eden çıkarsa sohbet açılıyor.',
   'Kort', 'everyone', 220, '/partner-ara', 'partner_search'),

  ('Halı saha doluluğu nasıl görünüyor?',
   'Sahalar > Halı Sahalar''da haftalık doluluk panosu var. Bu bir '
   'rezervasyon sistemi değil: işletme hangi saatlerin dolu olduğunu '
   'işaretliyor, sen görüp telefonla anlaşıyorsun.',
   'Kort', 'everyone', 230, '/halisahalar', 'turf_fields'),

  ('Takım sayfasında neler var?',
   'Takım merkezinde beş bölüm var: Özet, Program, Kadro, Sohbet ve '
   'Gelişim. Sohbet yalnızca takımın kendi kanalı; kadro dışındakiler '
   'göremiyor.',
   'Kulüp', 'everyone', 240, '/teams', 'team_hub'),

  ('Antrenör nasıl bulurum?',
   'Keşfet > Antrenör bul''dan branş ve isimle arayabilirsin. Listede '
   'yalnızca belgesi onaylanmış ve görünmeyi kabul etmiş antrenörler var; '
   'iletişim mevcut mesajlaşma üzerinden.',
   'Antrenör', 'everyone', 250, '/antrenor-bul', 'coach_discovery'),

  ('Gönderi kaydetmek ne işe yarıyor?',
   'Kaydettiğin gönderiler Profil > Kaydedilenler''de birikiyor ve '
   'yalnızca sen görüyorsun. Gönderi sahibine bildirim gitmiyor, kaç '
   'kişinin kaydettiği hiçbir yerde gösterilmiyor.',
   'Sosyal', 'everyone', 260, '/kaydedilenler', 'social_saved_posts'),

  ('Bir gönderiye kaç fotoğraf ekleyebilirim?',
   'En fazla 8. İlki büyük önizleme olarak, gerisi altında şerit halinde '
   'görünüyor ve tek tek silinebiliyor.',
   'Sosyal', 'everyone', 270, '/akis', 'social_multi_photo'),

  ('Bir gönderiyi arkadaşıma nasıl gönderirim?',
   'Gönderi kartındaki "Gönder" düğmesine bas ve sohbet ya da kanal seç. '
   'Birden çok hedef seçebilirsin. Kaynak gönderi sonradan silinirse '
   'sohbetteki kart "artık kullanılamıyor" durumuna düşüyor.',
   'Sosyal', 'everyone', 280, '/akis', 'social_content_share'),

  ('Yeniden paylaşmakla alıntılamak arasındaki fark ne?',
   '"Paylaş" düğmesinde bir şey yazmazsan gönderi olduğu gibi yeniden '
   'paylaşılıyor. Bir şey yazarsan alıntı oluyor ve senin yorumun üstte '
   'görünüyor. Aynı gönderiyi bir kez yeniden paylaşabilirsin, alıntı '
   'sınırsız.',
   'Sosyal', 'everyone', 290, '/akis', 'social_reposts'),

  ('Birini nasıl etiketlerim?',
   'Gönderi yazarken @ yazınca kişi listesi açılıyor. Listede yalnızca '
   'etiketlenmeyi kabul edenler var. Etiketi metinden silersen etiket de '
   'düşüyor. Bir gönderide en fazla 10 kişi.',
   'Sosyal', 'everyone', 300, '/akis', 'social_mentions'),

  ('Spor kartları nedir?',
   'Maç sonucu, takım başarısı ve antrenman özeti gibi yapılandırılmış '
   'paylaşım kartları. Sağlık verisi, konum ve lisans numarası bu '
   'kartlara girmiyor.',
   'Sosyal', 'everyone', 310, '/akis', 'social_sports_cards'),

  ('Uygulama dışına paylaşabiliyor muyum?',
   'Evet, ama reşit olmayan hesaplarda kapalı ve açılamıyor. Ayarı '
   'Gizlilik ve Hesap ekranından yönetiyorsun.',
   'Sosyal', 'everyone', 320, '/gizlilik', 'social_external_share'),

  ('Video paylaşabilir miyim?',
   'Henüz hayır. Video dönüştürme, kapak görseli, oynatıcı ve moderasyon '
   'tarafı tasarlanmadan açılmayacak. Şimdilik gönderi başına 8 fotoğraf '
   'destekleniyor.',
   'Sosyal', 'everyone', 330, null, 'social_video'),

  ('Profilimin kapağını ve rengini nasıl değiştiririm?',
   'Profilini düzenle ekranından kapak görseli, renk ve avatar arka planı '
   'seçebilirsin. Kulüp için Ayarlar > Kulüp profili. Renk yalnızca kapak '
   've rozetlerde görünüyor; düğmeler uygulamanın kendi renginde kalıyor.',
   'Görünüm', 'everyone', 340, '/profil', 'identity_customization'),

  ('Destek talebimi nasıl takip ederim?',
   'Ayarlar > Yardım > Destek talebi''nden taleplerini ve yanıtları '
   'görürsün. Ekip yanıt yazdığında bildirim geliyor. Sorunun çözüldüyse '
   'talebi kendin kapatabilirsin.',
   'Genel', 'everyone', 350, '/destek', 'support_center'),

  ('Veli olarak neleri görebiliyorum?',
   'Bağlı olduğun çocuğun aidatını, programını, yoklamasını ve gelişim '
   'kayıtlarını isimli olarak görüyorsun. Birden fazla çocuk bağlıysa her '
   'birinin verisi ayrı duruyor.',
   'Veli', 'everyone', 360, '/aidatlarim', 'parent_hub'),

  ('Antrenör çalışma alanı nedir?',
   'Yoklama, kadro ve program işlerinin tek ekranda toplandığı yer. '
   'Antrenör panelinden açılıyor.',
   'Antrenör', 'coach', 370, '/dashboard', 'coach_workspace'),

  ('İnternet yokken yoklama alabilir miyim?',
   'Bu özellik henüz açık değil. Sunucu tarafı hazır ama çakışma çözme '
   'ekranı yazılmadan açılmayacak: yanlış çalıştığında yoklama verisi '
   'kaybolur.',
   'Antrenör', 'coach', 380, '/attendance', 'offline_attendance'),

  ('Mali iş kuyruğu ne gösteriyor?',
   'Kapanışa ve günlük takibe takılan kayıtları: taslak giderler, onay '
   'bekleyen ödemeler, hesaba bağlanmamış hareketler, gecikmiş aidatlar. '
   'Özet sporcu adı içermiyor.',
   'Mali', 'club_staff', 390, '/mali-isler', 'finance_operations_center'),

  ('Kira gibi düzenli giderleri nasıl takip ederim?',
   'Konsolda Tedarikçi ve Taahhüt ekranından tanımlıyorsun. Vade geldiğinde '
   'gider otomatik yazılmıyor — "ödendi" dediğinde oluşuyor. Vadeye bir '
   'hafta ve üç gün kala bildirim geliyor.',
   'Mali', 'club_staff', 400, null, 'recurring_expenses'),

  ('Banka ekstresini nasıl eşleştiririm?',
   'Konsolda Banka Mutabakatı ekranından CSV yüklüyorsun. Sistem tutar, '
   'yön ve tarihe göre öneri veriyor ama **kararı sen veriyorsun** — '
   'otomatik defter kaydı oluşmuyor.',
   'Mali', 'club_staff', 410, null, 'bank_reconciliation'),

  ('Nakit tahminindeki üç sütun ne demek?',
   'Onaylı: parası var, yeri belli. Beklenen: olması beklenen ama '
   'gerçekleşmemiş. Belirsiz: bütçelenmiş ama taahhüt edilmemiş ve '
   'tahmine dahil değil. Tek bir sayı vermiyoruz çünkü olmayan parayı var '
   'sanmak en pahalı hata.',
   'Mali', 'club_staff', 420, null, 'club_budgeting'),

  ('Mali dönemi kapatınca ne oluyor?',
   'Kapanan dönemde gider, ödeme ve bağış değiştirilemiyor — bu bir '
   'arayüz kısıtı değil, veritabanı kilidi. Düzeltme için geçmişe '
   'dokunulmuyor, bugüne ters kayıt yazılıyor.',
   'Mali', 'club_staff', 430, null, 'period_closing'),

  ('Kulüp operasyon merkezi ne işe yarıyor?',
   'Mali ve sportif bekleyen işleri tek kuyrukta topluyor: onay bekleyen '
   'üyelikler, süresi dolan belgeler, yoklaması alınmamış antrenmanlar, '
   'gecikmiş aidatlar. Karta dokununca ilgili ekrana gidiyorsun.',
   'Kulüp', 'club_staff', 440, null, 'club_operations_center'),

  ('Sporcu neden sahaya çıkamıyor görünüyor?',
   'İki sebep olabilir: lisans süresi dolmuş ya da aktif bir sağlık kısıtı '
   'var. **Bu engeli yönetici dahil kimse düğmeyle kaldıramıyor**; yalnızca '
   'yetkili sağlık görevlisi kendi kaydını güncelleyerek kaldırabiliyor.',
   'Kulüp', 'club_staff', 450, '/athletes', 'eligibility_gate'),

  ('Üyelik başvurularını nerede görüyorum?',
   'Konsolda Onaylar ekranında. Kabul ettiğinde sporcu kadroya ekleniyor ve '
   'kulüp içeriğini görmeye başlıyor.',
   'Kulüp', 'club_staff', 460, '/onay-paneli', 'membership_lifecycle'),

  ('Tesis çakışması uyarısı çalışıyor mu?',
   'Henüz hayır. Şemada tesis rezervasyonu tutan bir tablo yok ve '
   'etkinliğin yeri serbest metin; metin eşleştirip sahte çakışma '
   'üretmek yerine bu özellik bekletiliyor.',
   'Kulüp', 'club_staff', 470, '/tesisler', 'facility_conflicts'),

  ('Hangi bildirimleri kapatabilirim?',
   'Takım kanalı, sosyal, pazaryeri ve mali bildirimleri kapatabilirsin. '
   'Doğrudan mesaj ve resmî kulüp duyurusu kapatılamıyor — ikisi de '
   'kaçırılmaması gereken bildirimler.',
   'Bildirim', 'everyone', 480, '/settings', 'notification_preferences'),

  ('Operasyon analitiği nerede?',
   'Konsolda Metrikler ekranında. Kulübün katılım, tahsilat ve kullanım '
   'eğilimlerini gösteriyor.',
   'Kulüp', 'club_staff', 490, '/metrikler', 'operations_analytics'),

  ('Operasyon riski nasıl hesaplanıyor?',
   'Tek bir puan yok. Hangi gerekçenin kaç kayıttan geldiği yazılı: '
   '"4 hesapsız mali hareket", "7 lisans 30 gün içinde doluyor" gibi. '
   'Karta dokununca ilgili ekrana gidiyorsun.',
   'Kulüp', 'club_staff', 500, '/uygunluk', 'club_operational_risk'),

  ('Turnuva merkezi ne yapıyor?',
   'Turnuva kadrosu seçimi, belge kontrolü ve uygunluk kilitleri. Lisansı '
   'dolmuş ya da sağlık kısıtı olan sporcu kadroya alınamıyor.',
   'Kulüp', 'club_staff', 510, '/organizasyonlar', 'tournament_hub'),

  ('Kulübü nasıl kurarım?',
   'Kurulum sihirbazı kulüp bilgileri, branşlar, tesisler, takımlar, '
   'antrenörler, sporcular, veliler, aidat planları ve takvimi sırayla '
   'soruyor. Yarıda bırakıp sonra devam edebilirsin.',
   'Kulüp', 'club_staff', 520, null, 'club_onboarding'),

  ('Sporcuları toplu nasıl aktarırım?',
   'Konsoldan CSV yüklüyorsun. Aynı dosya iki kez yüklenemiyor ve '
   'e-posta/telefon çakışmasında otomatik ezme yapılmıyor — çakışmayı sen '
   'çözüyorsun. Hata raporu 90 gün saklanıyor.',
   'Kulüp', 'club_staff', 530, null, 'club_csv_import')
) as v(question, answer, category, audience, sort_order, route, feature)
where not exists (
  select 1 from public.faq_entries f where f.question = v.question);

commit;
