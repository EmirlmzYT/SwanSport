// No public/mock provider can attest a person's identity. The approved KPS
// contract (authentication, SOAP operation, serial-number requirements) must
// be implemented here after institutional access is obtained.
export function resolveKpsProvider(env) {
  return {
    available: false,
    reason: env.KPS_ENDPOINT && env.KPS_CREDENTIALS
      ? 'Kurumsal KPS servis adaptörü henüz etkin değil. Kimlik belgenizi incelemeye gönderebilirsiniz.'
      : 'Otomatik kimlik doğrulama henüz etkin değil. Kimlik belgenizi incelemeye gönderebilirsiniz.',
  };
}

const allowedOrigins = new Set(['https://swansport.pages.dev', 'https://swansport.com.tr', 'https://www.swansport.com.tr']);
export function withIdentityCors(handler) {
  return async context => {
    const origin = context.request.headers.get('Origin');
    if (origin && !allowedOrigins.has(origin)) return response(403, 'origin', 'Bu kaynaktan erişim kapalı.');
    const result = context.request.method === 'OPTIONS'
      ? new Response(null, { status: 204 }) : await handler(context);
    const headers = new Headers(result.headers);
    headers.set('Cache-Control', 'no-store'); headers.set('Vary', 'Origin');
    if (origin) {
      headers.set('Access-Control-Allow-Origin', origin);
      headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      headers.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
    }
    return new Response(result.body, { status: result.status, headers });
  };
}

export function validNationalId(value) {
  if (typeof value !== 'string' || !/^[1-9][0-9]{10}$/.test(value)) return false;
  const d = [...value].map(Number);
  const odd = d[0] + d[2] + d[4] + d[6] + d[8];
  const even = d[1] + d[3] + d[5] + d[7];
  return ((odd * 7 - even) % 10 + 10) % 10 === d[9]
    && (odd + even + d[9]) % 10 === d[10];
}

export function toTurkishUpper(value) {
  return value.normalize('NFC').trim().replace(/\s+/gu, ' ').toLocaleUpperCase('tr-TR');
}

function response(status, code, error, success = false) {
  return Response.json(success ? { success: true } : { success: false, code, error }, {
    status,
    headers: { 'Cache-Control': 'no-store', 'Pragma': 'no-cache', 'X-Content-Type-Options': 'nosniff' },
  });
}

async function jsonFetch(fetchImpl, url, init) {
  const res = await fetchImpl(url, { ...init, redirect: 'error', signal: AbortSignal.timeout(10000) });
  // Never return upstream bodies/errors: they may contain identity data/keys.
  let body;
  try { body = await res.json(); } catch { body = null; }
  return { ok: res.ok, status: res.status, body };
}

async function readBody(request) {
  if (!request.headers.get('Content-Type')?.toLowerCase().startsWith('application/json')) throw new Error('body');
  const reader = request.body?.getReader();
  if (!reader) throw new Error('body');
  const chunks = []; let length = 0;
  let timer;
  const timeout = new Promise((_, reject) => {
    timer = setTimeout(() => reject(new Error('body timeout')), 3000);
  });
  try {
    while (true) {
      const { value, done } = await Promise.race([reader.read(), timeout]);
      if (done) break;
      length += value.byteLength;
      if (length > 4096) { await reader.cancel(); throw new Error('body'); }
      chunks.push(value);
    }
  } finally { clearTimeout(timer); void reader.cancel().catch(() => {}); reader.releaseLock(); }
  const bytes = new Uint8Array(length); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
}

async function hashKey(secret, kind, value, cryptoImpl) {
  const encoder = new TextEncoder();
  const key = await cryptoImpl.subtle.importKey('raw', encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const digest = await cryptoImpl.subtle.sign('HMAC', key, encoder.encode(`${kind}:${value}`));
  return `${kind}:${[...new Uint8Array(digest)].map(v => v.toString(16).padStart(2, '0')).join('')}`;
}

// Dependency injection is for isolated tests only, never selected by request or
// environment flags. Mock providers cannot reach the completion RPC.
export function createVerifyTcknHandler({ resolveProvider = resolveKpsProvider,
  fetchImpl = fetch, cryptoImpl = crypto } = {}) {
  return async ({ request, env }) => {
    if (request.method !== 'POST' && request.method !== 'GET') return response(405, 'method', 'GET veya POST gerekli.');
    const token = request.headers.get('Authorization');
    if (!token || !/^Bearer [^\s]+$/i.test(token)) return response(401, 'unauthorized', 'Lütfen giriş yapın.');
    let base;
    try {
      base = new URL(env.SUPABASE_URL);
      if (base.protocol !== 'https:' || base.username || base.password || base.search || base.hash
        || base.pathname !== '/') throw new Error('config');
    } catch { return response(503, 'unavailable', 'Doğrulama hizmeti henüz yapılandırılmadı.'); }
    if (!env.SUPABASE_ANON_KEY) return response(503, 'unavailable', 'Doğrulama hizmeti henüz yapılandırılmadı.');
    try {
      const auth = await jsonFetch(fetchImpl, new URL('/auth/v1/user', base), {
        headers: { apikey: env.SUPABASE_ANON_KEY, Authorization: token },
      });
      const uid = auth.body?.id;
      if (auth.status >= 500) return response(503, 'unavailable', 'Oturum hizmeti kullanılamıyor.');
      if (!auth.ok || typeof uid !== 'string' || !/^[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}$/i.test(uid)
        || auth.body?.is_anonymous === true) return response(401, 'unauthorized', 'Lütfen giriş yapın.');
      const provider = resolveProvider(env);
      if (request.method === 'GET') return Response.json({ available: provider.available === true
        && provider.kind === 'institutional-kps' && !!env.SUPABASE_SERVICE_ROLE_KEY
        && typeof env.IDENTITY_RATE_HMAC_SECRET === 'string' && env.IDENTITY_RATE_HMAC_SECRET.length >= 32 },
      { headers: { 'Cache-Control': 'no-store', 'Pragma': 'no-cache' } });
      if (!provider.available || provider.kind !== 'institutional-kps')
        return response(503, 'unavailable', provider.reason || 'Otomatik doğrulama kapalı; belge incelemesini kullanın.');
      if (!env.SUPABASE_SERVICE_ROLE_KEY || typeof env.IDENTITY_RATE_HMAC_SECRET !== 'string'
        || env.IDENTITY_RATE_HMAC_SECRET.length < 32) return response(503, 'unavailable', 'Doğrulama hizmeti henüz yapılandırılmadı.');
      let body;
      try { body = await readBody(request); } catch { return response(400, 'invalid', 'Kimlik bilgilerinizi kontrol edin.'); }
      const { national_id: nationalId, first_name: firstName, last_name: lastName, birth_year: birthYear } = body ?? {};
      if (!validNationalId(nationalId) || !Number.isInteger(birthYear) || birthYear < 1900
        || birthYear > new Date().getUTCFullYear() || typeof firstName !== 'string' || typeof lastName !== 'string')
        return response(400, 'invalid', 'Kimlik bilgilerinizi kontrol edin.');
      const name = toTurkishUpper(firstName), surname = toTurkishUpper(lastName);
      if (!/^[\p{L}\p{M} '-]{1,100}$/u.test(name) || !/^[\p{L}\p{M} '-]{1,100}$/u.test(surname)
        || !/\p{L}/u.test(name) || !/\p{L}/u.test(surname))
        return response(400, 'invalid', 'Ad ve soyad bilgilerinizi kontrol edin.');
      const ip = request.headers.get('CF-Connecting-IP');
      if (!ip || ip.length > 64 || !/^[0-9a-f:.]+$/i.test(ip)) return response(503, 'unavailable', 'Doğrulama hizmeti kullanılamıyor.');
      const headers = { apikey: env.SUPABASE_SERVICE_ROLE_KEY,
        Authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`, 'Content-Type': 'application/json' };
      const [userKey, ipKey] = await Promise.all([
        hashKey(env.IDENTITY_RATE_HMAC_SECRET, 'u', uid, cryptoImpl),
        hashKey(env.IDENTITY_RATE_HMAC_SECRET, 'i', ip, cryptoImpl),
      ]);
      const rate = await jsonFetch(fetchImpl, new URL('/rest/v1/rpc/consume_identity_verification_attempt', base), {
        method: 'POST', headers, body: JSON.stringify({ p_user_key: userKey, p_ip_key: ipKey }),
      });
      if (!rate.ok || (rate.body !== true && rate.body !== false)) return response(503, 'unavailable', 'Doğrulama hizmeti kullanılamıyor.');
      if (!rate.body) return response(429, 'rate_limited', 'Çok fazla deneme yaptınız. Bir dakika sonra tekrar deneyin.');
      const controller = new AbortController();
      let timer;
      const timeout = new Promise((_, reject) => {
        timer = setTimeout(() => { controller.abort(); reject(new Error('Provider timeout')); }, 15000);
      });
      let result;
      try {
        result = await Promise.race([provider.verify({ nationalId, firstName: name, lastName: surname, birthYear },
          { signal: controller.signal }), timeout]);
      } finally { clearTimeout(timer); }
      if (result !== true && result !== false) return response(503, 'unavailable', 'Kimlik servisi geçerli bir yanıt vermedi.');
      if (!result) return response(422, 'mismatch', 'Girilen bilgiler nüfus kütüğüyle uyuşmuyor.');
      const completion = await jsonFetch(fetchImpl, new URL('/rest/v1/rpc/complete_identity_verification', base), {
        method: 'POST', headers, body: JSON.stringify({ p_profile_id: uid, p_national_id: nationalId, p_birth_year: birthYear }),
      });
      if (!completion.ok) {
        if (completion.body?.code === '23505') return response(409, 'identity_conflict', 'Kimlik bu hesapta doğrulanamıyor. Belge incelemesi veya destek yolunu kullanın.');
        return response(503, 'unavailable', 'Onay tamamlanamadı. Belge incelemesini kullanabilir veya tekrar deneyebilirsiniz.');
      }
      return response(200, null, null, true);
    } catch {
      // No console/debug/error reporting of submitted identity fields.
      return response(503, 'unavailable', 'Doğrulama tamamlanamadı. Belge incelemesini kullanabilirsiniz.');
    }
  };
}
