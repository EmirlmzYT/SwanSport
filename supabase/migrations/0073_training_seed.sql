-- ---------------------------------------------------------------------------
-- 0073 — Antrenman oturum motoru: hazır şablonlar, bayrak, yardım, bildirim
--
-- Dört okçuluk şablonu platform şablonu olarak (club_id null) geliyor: yeni
-- bir kulüp motoru boş bir şablon listesiyle karşılamasın. Antrenör kendi
-- şablonunu `create_training_protocol` ile yazıyor.
--
-- SSS KAYDI ZORUNLU: 0070'teki `trg_faq_before_release`, bir bayrağı
-- `testers` ya da `everyone` yapmayı o anahtara bağlı aktif bir SSS kaydı
-- yoksa reddediyor. Bayrağı ve yardımını aynı dosyada yazıyoruz — ayrı
-- dosyaya bırakılsaydı yayın günü kapıya takılırdı.
-- ---------------------------------------------------------------------------

-- ---------------------------------------------------------------------------
-- 1) Okçuluk hazır şablonları
--
-- Süreler World Archery ritmine yakın tutuldu ama bağlayıcı değil: antrenör
-- kendi şablonunu üretebiliyor. `units_per_set` = set başına ok.
-- ---------------------------------------------------------------------------
insert into public.training_protocols
  (club_id, sport_code, name, description, version, config, published)
select null, 'okculuk', v.name, v.description, 1, v.config, true
  from (values
    ('Başlangıç çalışması',
     'Yeni başlayanlar için kısa setler ve uzun hazırlık süresi. Skor set toplamı olarak giriliyor.',
     '{"set_count":6,"units_per_set":3,"prep_seconds":30,"shoot_seconds":120,
       "collect_seconds":60,"rest_seconds":60,"max_unit_score":10,
       "entry_mode":"simple","mode":"technique"}'::jsonb),
    ('Teknik çalışma',
     'Duruş ve salıverme üzerine yoğunlaşan orta uzunlukta oturum. Her ok tek tek giriliyor.',
     '{"set_count":8,"units_per_set":6,"prep_seconds":20,"shoot_seconds":180,
       "collect_seconds":50,"rest_seconds":45,"max_unit_score":10,
       "entry_mode":"detailed","mode":"technique"}'::jsonb),
    ('Puanlı set',
     'Puan takibi olan standart antrenman. Set ilerleyişi ve puan dağılımı çıkarılıyor.',
     '{"set_count":10,"units_per_set":3,"prep_seconds":10,"shoot_seconds":120,
       "collect_seconds":45,"rest_seconds":30,"max_unit_score":10,
       "entry_mode":"detailed","mode":"scored"}'::jsonb),
    ('Müsabaka simülasyonu',
     'Yarışma ritmi: kısa dinlenme, uzun seri. Baskı altında tutarlılığı ölçer.',
     '{"set_count":12,"units_per_set":6,"prep_seconds":10,"shoot_seconds":240,
       "collect_seconds":60,"rest_seconds":20,"max_unit_score":10,
       "entry_mode":"detailed","mode":"simulation"}'::jsonb)
  ) as v(name, description, config)
 where not exists (
   select 1 from public.training_protocols p
    where p.club_id is null and p.sport_code = 'okculuk' and p.name = v.name);

-- ---------------------------------------------------------------------------
-- 2) Özellik bayrağı
--
-- `admins` ile başlıyor. Kademeli yayın: off → admins → testers → everyone.
-- ---------------------------------------------------------------------------
insert into public.feature_flags (key, audience, label, description)
values ('sport_training_sessions', 'admins', 'Antrenman oturumları',
        'Branşa özel canlı antrenman oturumu: set, süre, skor ve antrenör onayı. İlk branş okçuluk.')
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- 3) Yardım içeriği
--
-- 0070'in kapısı bunu zorunlu kılıyor; ama asıl sebep şu: bu özellik sahada,
-- elde telefonla, sayaç işlerken kullanılıyor. "Nasıl çalışıyor" sorusunun
-- cevabı uygulamanın içinde olmalı.
-- ---------------------------------------------------------------------------
insert into public.faq_entries
  (question, answer, category, audience, feature, route, sort_order)
select v.q, v.a, v.c, v.aud, 'sport_training_sessions', v.r, v.so
  from (values
    ('Antrenman oturumu nedir?',
     'Antrenör bir antrenmanı canlı olarak başlatır; sen telefonundan setlerini, sürelerini ve skorunu takip edersin. Oturum bitince antrenör sonuçları inceleyip onaylar.',
     'Antrenman', 'everyone', '/antrenman-oturumu', 10),
    ('Oturuma nasıl katılırım?',
     'Antrenörün ekranındaki 6 haneli kodu uygulamaya yaz. Kodu okutmak istersen telefonunun kamerasıyla ekrandaki karekodu okutman da yeterli. Kod yalnızca kendi kulübünün oturumunda çalışır.',
     'Antrenman', 'athlete', '/antrenman-oturumu', 20),
    ('Oturuma katılınca yoklamam otomatik alınıyor mu?',
     'Hayır. Oturuma katılmak yoklama değildir; antrenörün yoklama ekranında yalnızca bir ipucu olarak görünür. Resmî yoklamayı antrenör kendi işaretler.',
     'Antrenman', 'everyone', '/attendance', 30),
    ('Bir seti atlarsam sıfır mı yazılıyor?',
     'Hayır. Girilmeyen set "eksik" olarak görünür, sıfır puan olarak yazılmaz. Sıfır yazmak seni kötü atmış gibi gösterirdi.',
     'Antrenman', 'everyone', '/antrenman-oturumu', 40),
    ('Girdiğim skoru sonradan düzeltebilir miyim?',
     'Antrenör onaylayana kadar evet. Onaydan sonra sonuç kilitlenir; düzeltmeyi yalnızca yetkili antrenör, gerekçe yazarak yapabilir ve bu değişiklik kayda geçer.',
     'Antrenman', 'everyone', '/antrenman-oturumu', 50),
    ('Uygulamayı kapatırsam sayaç bozulur mu?',
     'Hayır. Sayaç, aşamanın başlangıç ve bitiş saatinden hesaplanır; uygulamayı kapatıp açsan da doğru kalır. Süre dolmuşsa sistem kendiliğinden ilerlemez, devam etme kararını sen ya da antrenörün verir.',
     'Antrenman', 'everyone', '/antrenman-oturumu', 60),
    ('Kendi başıma yaptığım antrenmanı kim görüyor?',
     'Yalnızca sen. Bireysel antrenman kaydın kişisel geçmişinde durur; antrenörün, kulüp yöneticin ve velin bunu görmez.',
     'Antrenman', 'everyone', '/antrenmanlarim', 70),
    ('Kulvarımı ben mi seçiyorum?',
     'Hayır. Kulvar isteğe bağlıdır ve antrenör atar; atamadıysa oturum yalnızca katılımcı listesiyle çalışır.',
     'Antrenman', 'everyone', '/antrenman-oturumu', 80),
    ('Antrenman sonundaki zorluk sorusu zorunlu mu?',
     'Hayır. Zorluk puanı, etiketler ve not tamamen isteğe bağlıdır; boş bırakırsan antrenman kaydın yine tamamlanır.',
     'Antrenman', 'everyone', '/antrenmanlarim', 90),
    ('Şablonu değiştirirsem eski antrenmanlarım değişir mi?',
     'Hayır. Şablon düzenlendiğinde yeni bir sürüm oluşur; geçmiş oturumlar başladıkları sürüme bağlı kalır, sonuçlarının anlamı değişmez.',
     'Antrenman', 'coach', '/antrenman-sablonlari', 100)
  ) as v(q, a, c, aud, r, so)
 where not exists (
   select 1 from public.faq_entries f where f.question = v.q);

-- ---------------------------------------------------------------------------
-- 4) Bildirim rotaları
--
-- DİKKAT: bu fonksiyon migration'larda ALTI kez baştan yazıldı ve bir kez
-- gerçekten eşleme kaybedildi (0022'nin eklediği üç eşleme 0039'da düştü).
-- Aşağıdaki liste 0069'daki 35 eşlemenin TAMAMINI taşıyor, üstüne ikisini
-- ekliyor. `python tools/check_push_routes.py` bunu doğruluyor.
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
    when 'support'                   then '/destek'
    when 'eligibility'               then '/athletes'
    -- 0073
    when 'training_session'          then '/antrenman-oturumu'
    when 'training_result'           then '/antrenman-sonuc'
    else '/bildirimler'
  end;
$fn$;
