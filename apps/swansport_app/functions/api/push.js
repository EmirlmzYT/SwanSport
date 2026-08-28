/**
 * SwanSport — Web Push gönderici (Cloudflare Pages Function).
 *
 * Veritabanı tarafındaki `notifications` tetikleyicisi buraya POST atar; bu
 * fonksiyon aboneliklere şifreli bildirimi iletir.
 *
 * Neden burada: tarayıcı push servisleri (FCM/Mozilla/Apple) yalnızca VAPID
 * ile imzalanmış ve RFC 8291'e göre şifrelenmiş istek kabul eder. İmza için
 * gereken özel anahtar istemciye asla verilemez, o yüzden iş sunucuda yapılır.
 *
 * Beklenen gövde:
 *   { title, body, url, subs: [{ endpoint, p256dh, auth }] }
 * Abonelikleri veritabanı tetikleyicisi hazır gönderir — böylece bu fonksiyonun
 * Supabase'e hiç erişmesi gerekmez (service_role anahtarı burada tutulmaz).
 *
 * Ortam değişkenleri: PUSH_SECRET, VAPID_PUBLIC, VAPID_PRIVATE, VAPID_SUBJECT
 */

// --------------------------------------------------------------- yardımcılar
const enc = new TextEncoder();

function b64urlToBytes(s) {
  const pad = s.replace(/-/g, '+').replace(/_/g, '/');
  const bin = atob(pad + '='.repeat((4 - (pad.length % 4)) % 4));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function bytesToB64url(b) {
  let s = '';
  const a = new Uint8Array(b);
  for (let i = 0; i < a.length; i++) s += String.fromCharCode(a[i]);
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function concat(...arrays) {
  const total = arrays.reduce((n, a) => n + a.length, 0);
  const out = new Uint8Array(total);
  let o = 0;
  for (const a of arrays) {
    out.set(a, o);
    o += a.length;
  }
  return out;
}

/** HKDF'in tek adımlık hali — çıktı 32 baytı geçmediği için tek blok yeter. */
async function hkdf(salt, ikm, info, length) {
  const prkKey = await crypto.subtle.importKey(
    'raw', salt, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const prk = new Uint8Array(await crypto.subtle.sign('HMAC', prkKey, ikm));

  const expandKey = await crypto.subtle.importKey(
    'raw', prk, { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const out = new Uint8Array(
    await crypto.subtle.sign('HMAC', expandKey, concat(info, new Uint8Array([1]))));
  return out.slice(0, length);
}

// ------------------------------------------------------------------- VAPID
/** VAPID özel anahtarını JWK olarak içe alır (x,y açık anahtardan türetilir). */
async function importVapidKey(publicB64, privateB64) {
  const pub = b64urlToBytes(publicB64); // 0x04 | x(32) | y(32)
  return crypto.subtle.importKey(
    'jwk',
    {
      kty: 'EC',
      crv: 'P-256',
      d: privateB64,
      x: bytesToB64url(pub.slice(1, 33)),
      y: bytesToB64url(pub.slice(33, 65)),
      ext: true,
    },
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
}

/** Push servisi için ES256 imzalı JWT üretir (RFC 8292). */
async function vapidHeader(endpoint, env) {
  const aud = new URL(endpoint).origin;
  const header = bytesToB64url(enc.encode(JSON.stringify({ typ: 'JWT', alg: 'ES256' })));
  const payload = bytesToB64url(enc.encode(JSON.stringify({
    aud,
    exp: Math.floor(Date.now() / 1000) + 12 * 3600,
    sub: env.VAPID_SUBJECT || 'mailto:destek@swansport.app',
  })));

  const key = await importVapidKey(env.VAPID_PUBLIC, env.VAPID_PRIVATE);
  const sig = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' }, key, enc.encode(`${header}.${payload}`));

  return `vapid t=${header}.${payload}.${bytesToB64url(sig)}, k=${env.VAPID_PUBLIC}`;
}

// -------------------------------------------------------------- şifreleme
/** Yükü aes128gcm ile şifreler (RFC 8291 + RFC 8188). */
async function encryptPayload(plaintext, p256dhB64, authB64) {
  const uaPublic = b64urlToBytes(p256dhB64);
  const authSecret = b64urlToBytes(authB64);

  // Gönderici için tek kullanımlık ECDH anahtar çifti.
  const eph = await crypto.subtle.generateKey(
    { name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
  const asPublic = new Uint8Array(await crypto.subtle.exportKey('raw', eph.publicKey));

  const uaKey = await crypto.subtle.importKey(
    'raw', uaPublic, { name: 'ECDH', namedCurve: 'P-256' }, false, []);
  const shared = new Uint8Array(await crypto.subtle.deriveBits(
    { name: 'ECDH', public: uaKey }, eph.privateKey, 256));

  // IKM: paylaşılan sırdan, iki tarafın açık anahtarı bağlanarak türetilir.
  const keyInfo = concat(enc.encode('WebPush: info\0'), uaPublic, asPublic);
  const ikm = await hkdf(authSecret, shared, keyInfo, 32);

  const salt = crypto.getRandomValues(new Uint8Array(16));
  const cek = await hkdf(salt, ikm, enc.encode('Content-Encoding: aes128gcm\0'), 16);
  const nonce = await hkdf(salt, ikm, enc.encode('Content-Encoding: nonce\0'), 12);

  const aesKey = await crypto.subtle.importKey('raw', cek, 'AES-GCM', false, ['encrypt']);
  // 0x02: tek ve son kayıt olduğunu belirten dolgu baytı.
  const padded = concat(enc.encode(plaintext), new Uint8Array([2]));
  const cipher = new Uint8Array(await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv: nonce }, aesKey, padded));

  // Başlık: salt(16) | kayıt boyu(4) | anahtar uzunluğu(1) | açık anahtar(65)
  const rs = new Uint8Array([0, 0, 0x10, 0]); // 4096
  return concat(salt, rs, new Uint8Array([asPublic.length]), asPublic, cipher);
}

// --------------------------------------------------------------------- FCM
//
// Android'de tarayıcı yok, dolayısıyla RFC 8291 şifrelemesi de yok. FCM tek
// bir cihaz token'ı veriyor; şifrelemeyi ve teslimatı Google üstleniyor.
//
// Yetkilendirme VAPID'den farklı: orada isteği kendi anahtarımızla
// imzalıyorduk, burada önce servis hesabıyla bir OAuth2 erişim token'ı alıp
// onu taşıyoruz. İmza da ES256 değil RS256 — aynı teknik, farklı algoritma.

/** Servis hesabının PEM özel anahtarını WebCrypto'ya alır. */
async function importServiceAccountKey(pem) {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8', der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false, ['sign'],
  );
}

/**
 * Google'dan erişim token'ı alır.
 *
 * Token bir saat geçerli; her bildirimde yeniden almak gereksiz gecikme
 * olurdu. İstek başına bir kez alınıp aynı çağrıdaki tüm cihazlarda
 * kullanılıyor.
 */
async function fcmAccessToken(env) {
  const sa = JSON.parse(env.FCM_SERVICE_ACCOUNT);
  const now = Math.floor(Date.now() / 1000);

  const header = b64url(new TextEncoder().encode(
    JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claim = b64url(new TextEncoder().encode(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: sa.token_uri,
    iat: now,
    exp: now + 3600,
  })));

  const key = await importServiceAccountKey(sa.private_key);
  const sig = new Uint8Array(await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(`${header}.${claim}`)));

  const res = await fetch(sa.token_uri, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${header}.${claim}.${b64url(sig)}`,
    }),
  });
  if (!res.ok) throw new Error(`token alınamadı: ${res.status}`);
  return { token: (await res.json()).access_token, projectId: sa.project_id };
}

/** Tek bir Android cihazına bildirim gönderir. */
async function sendFcm(token, projectId, sub, job) {
  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token: sub.endpoint,
          notification: {
            title: job.title || 'SwanSport',
            body: job.body || '',
          },
          // Uygulama açıkken hangi sayfaya gidileceği; bildirim gövdesi
          // değil veri alanı taşır, çünkü ikisi farklı işleniyor.
          data: { url: job.url || '/bildirimler' },
          android: {
            priority: 'high',
            notification: { channel_id: 'swansport_default' },
          },
        },
      }),
    },
  );
  // 404: token artık geçerli değil (uygulama silinmiş).
  return { endpoint: sub.endpoint, status: res.status, gone: res.status === 404 };
}

// ------------------------------------------------------------------ handler
export async function onRequestPost({ request, env }) {
  if (!env.VAPID_PRIVATE || !env.PUSH_SECRET) {
    return new Response('yapılandırma eksik', { status: 500 });
  }
  if (request.headers.get('x-push-secret') !== env.PUSH_SECRET) {
    return new Response('yetkisiz', { status: 401 });
  }

  let job;
  try {
    job = await request.json();
  } catch {
    return new Response('geçersiz gövde', { status: 400 });
  }

  const subs = Array.isArray(job.subs) ? job.subs : [];
  const payload = JSON.stringify({
    title: job.title || 'SwanSport',
    body: job.body || '',
    url: job.url || '/bildirimler',
  });

  // Android cihaz varsa erişim token'ını bir kez al — her cihaz için ayrı
  // token istemek Google'a gereksiz tur atmak olurdu.
  const hasFcm = subs.some((s) => s.kind === 'fcm');
  let fcm = null;
  if (hasFcm && env.FCM_SERVICE_ACCOUNT) {
    try {
      fcm = await fcmAccessToken(env);
    } catch (e) {
      // Token alınamazsa Android cihazlar atlanır; web tarafı yine gitsin.
      fcm = { error: String(e) };
    }
  }

  const results = await Promise.all(subs.map(async (s) => {
    try {
      if (s.kind === 'fcm') {
        if (!env.FCM_SERVICE_ACCOUNT) {
          return { endpoint: s.endpoint, status: 0, error: 'FCM yapılandırılmamış' };
        }
        if (!fcm || fcm.error) {
          return { endpoint: s.endpoint, status: 0, error: fcm?.error || 'token yok' };
        }
        return await sendFcm(fcm.token, fcm.projectId, s, job);
      }

      const body = await encryptPayload(payload, s.p256dh, s.auth);
      const res = await fetch(s.endpoint, {
        method: 'POST',
        headers: {
          Authorization: await vapidHeader(s.endpoint, env),
          'Content-Encoding': 'aes128gcm',
          'Content-Type': 'application/octet-stream',
          TTL: '86400',
          Urgency: 'normal',
        },
        body,
      });
      // 404/410: abonelik ölmüş — istemci bir sonraki açılışta yenisini yazar.
      return { endpoint: s.endpoint, status: res.status, gone: res.status === 404 || res.status === 410 };
    } catch (e) {
      return { endpoint: s.endpoint, status: 0, error: String(e) };
    }
  }));

  // Web push 201, FCM 200 döndürüyor — ikisi de başarı.
  const sent = results.filter((r) => r.status === 201 || r.status === 200).length;
  return Response.json({ sent, results });
}
