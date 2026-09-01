-- Bildirim neden telefona düşmüyor? Supabase SQL Editor'e yapıştır.
--
-- Zincir: notifications satırı -> trg_push_on_notification -> net.http_post
--         -> Cloudflare /api/push -> FCM -> telefon
--
-- Tetikleyici bütün hataları `when others then return new` ile YUTUYOR,
-- o yüzden hiçbir yerde iz kalmıyor. pg_net ise isteklerin sonucunu
-- kendi tablosunda tutuyor; kopmanın yeri orada görünür.

-- 1) pg_net kurulu mu? Kurulu değilse `net.http_post` hiç çalışmamıştır.
select 'pg_net eklentisi' as kontrol,
       coalesce((select extversion from pg_extension where extname = 'pg_net'),
                'KURULU DEGIL - bildirim hic gonderilmiyor') as sonuc

union all

-- 2) Cihaz kayıtlı mı, hangi tür?
select 'kayitli cihaz',
       coalesce((select string_agg(kind || ':' || count(*)::text, ', ')
                   from (select kind, count(*) as count
                           from public.push_subscriptions group by kind) t
                  group by 1), 'HIC CIHAZ YOK')

union all

-- 3) Son bildirimler gerçekten oluşmuş mu?
select 'son 1 saatte bildirim',
       (select count(*)::text from public.notifications
         where created_at > now() - interval '1 hour');

-- 4) ASIL CEVAP: pg_net istekleri ne sonuç verdi?
--    Boş dönerse istek hiç çıkmamış (tetikleyici patlamış ve yutulmuş).
--    status_code 401 -> PUSH_SECRET uyuşmuyor
--    status_code 500 -> Cloudflare'de yapılandırma eksik
--    status_code 200 -> Cloudflare tamam, sorun FCM/cihaz tarafında
--    error_msg dolu -> istek hiç ulaşmamış (ağ/DNS)
select id, status_code, left(coalesce(error_msg, ''), 120) as hata,
       left(coalesce(content, ''), 300) as cevap, created
  from net._http_response
 order by created desc
 limit 10;
