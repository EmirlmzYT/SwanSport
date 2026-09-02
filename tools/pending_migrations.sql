-- ===========================================================================
-- SwanSport — bekleyen migration (0070): SSS ozelligi takip etsin
--
-- 0053-0069 CANLIDA. 0069 dogrulandi: faq_entries tablosu, support_queue ve
-- reply_support_ticket yerinde. Bu dosyada YALNIZCA 0070 var — o
-- calistirilmamis: faq_entries.feature sutunu ve faq_coverage() yok.
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
-- 1/1  0070_faq_follows_features.sql
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
