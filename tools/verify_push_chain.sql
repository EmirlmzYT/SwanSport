-- Bildirim neden telefona düşmüyor? Supabase SQL Editor'e yapıştır.
--
-- Zincir: notifications satırı -> trg_push_on_notification -> net.http_post
--         -> Cloudflare /api/push -> FCM -> telefon
--
-- Tetikleyici bütün hataları `when others then return new` ile YUTUYOR,
-- o yüzden hiçbir yerde iz kalmıyor. pg_net isteklerin sonucunu kendi
-- tablosunda tutuyor; kopmanın yeri orada görünür.
--
-- Sorgular ayrı ayrı; birini çalıştır, sonucu gör, diğerine geç.


-- 1) pg_net kurulu mu?  Boş dönerse `net.http_post` hiç çalışmamıştır.
select extname, extversion
  from pg_extension
 where extname = 'pg_net';


-- 2) Kayıtlı cihazlar — 'fcm' türünde satır olmalı.
select kind, count(*) as adet
  from public.push_subscriptions
 group by kind;


-- 3) Son bir saatte bildirim oluşmuş mu?
select count(*) as son_1_saat
  from public.notifications
 where created_at > now() - interval '1 hour';


-- 4) ASIL CEVAP — pg_net istekleri ne sonuç verdi?
--
--    "relation net._http_response does not exist" hatası alırsan cevap bu:
--    pg_net kurulu değil, bildirim hiç gönderilmiyor.
--
--    Boş dönerse      -> istek hiç çıkmamış (tetikleyici patlamış, yutulmuş)
--    status_code 401  -> PUSH_SECRET uyuşmuyor
--    status_code 500  -> Cloudflare'de yapılandırma eksik
--    status_code 200  -> Cloudflare tamam, sorun FCM/cihaz tarafında
--    error_msg dolu   -> istek ağdan çıkamamış
select id,
       status_code,
       left(coalesce(error_msg, ''), 150) as hata,
       left(coalesce(content, ''), 400)   as cevap,
       created
  from net._http_response
 order by created desc
 limit 10;
