const CORS = { 'Access-Control-Allow-Origin': '*' };

export async function onRequest({ request }) {
  const raw = new URL(request.url).searchParams.get('url');
  if (!raw) return new Response('url gerekli', { status: 400, headers: CORS });
  let target;
  try { target = new URL(raw); } catch { return new Response('geçersiz url', { status: 400, headers: CORS }); }
  if (!['http:', 'https:'].includes(target.protocol)) return new Response('protokol desteklenmiyor', { status: 400, headers: CORS });
  try {
    const upstream = await fetch(target, { headers: { 'User-Agent': 'SwanSport/1.0' }, cf: { cacheTtl: 86400, cacheEverything: true } });
    if (!upstream.ok) return new Response(null, { status: upstream.status, headers: CORS });
    const headers = new Headers(CORS);
    headers.set('Content-Type', upstream.headers.get('content-type') || 'image/jpeg');
    headers.set('Cache-Control', 'public, max-age=86400, immutable');
    return new Response(upstream.body, { status: 200, headers });
  } catch { return new Response(null, { status: 502, headers: CORS }); }
}
