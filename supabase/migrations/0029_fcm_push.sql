-- =============================================================================
-- SwanSport — 0029: ANDROID BİLDİRİMİ (FCM) + PUSH SECRET'IN KODDAN ÇIKARILMASI
--
-- İki iş yapar:
--   1. push_subscriptions tablosunu FCM cihaz token'ı da tutabilecek hale getirir
--   2. Gönderim anahtarını SQL'in içinden çıkarıp veritabanı ayarına taşır
--
-- Tekrar çalıştırılabilir.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- 1) ABONELİK TABLOSU — iki taşıyıcı birden
-- ---------------------------------------------------------------------------
-- Tablo tarayıcıya göre tasarlanmıştı: endpoint + p256dh + auth üçlüsü, üçü de
-- zorunlu. Android'de bunların hiçbiri yok — FCM tek bir opak cihaz token'ı
-- veriyor ve şifrelemeyi Google yapıyor.
--
-- Ayrı tablo açmak yerine aynı tabloyu genişletiyoruz: gönderim tetikleyicisi
-- kişinin TÜM cihazlarını tek sorguda toplayabilsin. Ayrı tablo olsaydı her
-- bildirimde iki sorgu ve iki HTTP isteği gerekirdi.
--
-- `endpoint` her iki taşıyıcıda da cihazın adresi: tarayıcıda push servisinin
-- URL'i, Android'de FCM token'ı. Tekil olması ikisinde de doğru.

alter table public.push_subscriptions
  add column if not exists kind text not null default 'web';

do $$ begin
  alter table public.push_subscriptions
    add constraint push_subscriptions_kind_check
    check (kind in ('web', 'fcm'));
exception when duplicate_object then null; end $$;

-- Tarayıcıya özel alanlar artık isteğe bağlı.
alter table public.push_subscriptions alter column p256dh drop not null;
alter table public.push_subscriptions alter column auth   drop not null;

-- Ama web aboneliğinde hâlâ zorunlu olmalılar; yoksa şifreleme yapılamaz.
do $$ begin
  alter table public.push_subscriptions
    add constraint push_subscriptions_web_keys_check
    check (kind <> 'web' or (p256dh is not null and auth is not null));
exception when duplicate_object then null; end $$;

create index if not exists idx_push_kind
  on public.push_subscriptions (profile_id, kind);


-- ---------------------------------------------------------------------------
-- 2) GÖNDERİM ANAHTARI — koddan çıkarıldı
-- ---------------------------------------------------------------------------
-- Anahtar `push_on_notification` içine düz metin gömülüydü ve bu dosya public
-- bir depoda duruyor. Elinde olan herkes uygulamanın bütün kullanıcılarına
-- bildirim gönderebilirdi.
--
-- Artık Supabase Vault'ta şifreli duruyor. İlk tercih `alter database ... set`
-- idi ama Supabase'de `postgres` rolü gerçek superuser değil ve o komut
-- "permission denied to set parameter" veriyor. Vault zaten tam bu iş için:
-- değer diskte şifreli, yalnızca yetkili rol okuyabiliyor.
--
-- Değer bir kez şöyle yazılır (ayrı dosyada verildi):
--   select vault.create_secret('ANAHTAR', 'push_secret', 'Cloudflare /api/push');
--
-- Aynı değer Cloudflare'de PUSH_SECRET olarak da bulunmalı.

create or replace function public.push_secret()
returns text language sql stable security definer set search_path = public as $$
  select decrypted_secret
    from vault.decrypted_secrets
   where name = 'push_secret'
   limit 1;
$$;

-- Bu fonksiyon sırrı düz metin döndürüyor; yalnızca tetikleyici içinden,
-- tanımlayanın yetkisiyle çağrılmalı. Kullanıcı rollerine kapalı.
revoke execute on function public.push_secret() from public, anon, authenticated;


-- ---------------------------------------------------------------------------
-- 3) TETİKLEYİCİ — taşıyıcıyı da bildiriyor
-- ---------------------------------------------------------------------------
create or replace function public.push_on_notification()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_subs   jsonb;
  v_secret text;
begin
  if not public.push_allowed(new.profile_id, new.kind) then
    return new;
  end if;

  v_secret := public.push_secret();
  -- Anahtar tanımlı değilse sessizce çık: yanlış anahtarla istek atmak
  -- Cloudflare tarafında 401 yığını üretirdi.
  if v_secret is null or v_secret = '' then
    return new;
  end if;

  -- Her cihaz kendi taşıyıcısıyla birlikte gidiyor; sunucu hangi yolu
  -- kullanacağını satır satır seçiyor.
  select coalesce(jsonb_agg(jsonb_build_object(
           'kind',     s.kind,
           'endpoint', s.endpoint,
           'p256dh',   s.p256dh,
           'auth',     s.auth)), '[]'::jsonb)
    into v_subs
    from public.push_subscriptions s
   where s.profile_id = new.profile_id;

  if jsonb_array_length(v_subs) = 0 then
    return new;
  end if;

  perform net.http_post(
    url     := 'https://swansport.pages.dev/api/push',
    headers := jsonb_build_object(
                 'Content-Type', 'application/json',
                 'x-push-secret', v_secret),
    body    := jsonb_build_object(
                 'title', new.title,
                 'body',  coalesce(new.body, ''),
                 'url',   public.push_route(new.kind, new.entity_type),
                 'subs',  v_subs)
  );

  return new;
exception
  when others then return new;
end; $$;


-- ---------------------------------------------------------------------------
-- 4) ÖLÜ ABONELİK TEMİZLİĞİ
-- ---------------------------------------------------------------------------
-- Kullanıcı uygulamayı silince FCM token'ı geçersizleşir; sunucu 404/410
-- döner. Bu fonksiyon o adresleri siler — sürekli ölü cihaza gönderim
-- denemek hem yavaş hem gereksiz.
create or replace function public.drop_push_subscription(p_endpoint text)
returns void language sql security definer set search_path = public as $$
  delete from public.push_subscriptions where endpoint = p_endpoint;
$$;

revoke execute on function public.drop_push_subscription(text)
  from public, anon, authenticated;
