/**
 * Haber kaynağı ikonu çözümleyicisi.
 *
 * RSS adresi çoğu zaman yayıncının ana alan adı değildir; ayrıca birçok site
 * ikonunu /favicon.ico yerine <link rel="icon">, manifest veya Apple touch
 * icon ile ilan eder. İkonu haberin açıldığı sitenin kökünden keşfedip görsel
 * olarak döndürürüz. Bulunamazsa 404 döner; istemci harf avatarına düşer.
 */
const CORS = { 'Access-Control-Allow-Origin': '*' };
const AGENT = 'SwanSport/1.0 (+https://swansport.pages.dev)';

export async function onRequest({ request }) {
  const raw = new URL(request.url).searchParams.get('url');
  if (!raw) return fail(400, 'url gerekli');

  let page;
  try {
    page = new URL(raw);
  } catch {
    return fail(400, 'geçersiz url');
  }
  if (!isWebUrl(page)) return fail(400, 'protokol desteklenmiyor');

  const root = new URL('/', page);
  const candidates = [];
  try {
    const response = await fetch(root, requestOptions(21600));
    if (response.ok && (response.headers.get('content-type') || '').includes('text/html')) {
      const html = (await response.text()).slice(0, 300000);
      const base = response.url || root.href;
      candidates.push(...declaredIcons(html, base));
      const manifest = declaredManifest(html, base);
      if (manifest) candidates.push(...await manifestIcons(manifest));
    }
  } catch {
    // Ana sayfa engellense de aşağıdaki standart yolları denemeye devam et.
  }

  candidates.push(
    new URL('/favicon.ico', root).href,
    new URL('/favicon.png', root).href,
    new URL('/apple-touch-icon.png', root).href,
  );

  for (const url of unique(candidates)) {
    // ICO dosyaları tarayıcıda görünse bile Flutter'ın web görüntü çözücüsünde
    // tutarlı değil. Sitenin kendi PNG/SVG ikonunu önce tutarız; yalnız ICO
    // kalırsa aynı alan adı için raster favicon yedeğine düşeriz.
    const icon = await imageResponse(url, page.hostname);
    if (icon) return icon;
  }
  return fail(404, 'ikon bulunamadı');
}

function declaredIcons(html, base) {
  const out = [];
  for (const element of html.match(/<link\b[^>]*>/gi) || []) {
    const attrs = attributes(element);
    const rel = (attrs.rel || '').toLowerCase();
    if (!/(^|\s)(icon|shortcut icon|apple-touch-icon|mask-icon)(\s|$)/.test(rel)) continue;
    const icon = webUrl(attrs.href, base);
    if (icon) out.push(icon);
  }
  return out;
}

function declaredManifest(html, base) {
  for (const element of html.match(/<link\b[^>]*>/gi) || []) {
    const attrs = attributes(element);
    if ((attrs.rel || '').toLowerCase().split(/\s+/).includes('manifest')) {
      return webUrl(attrs.href, base);
    }
  }
  return null;
}

async function manifestIcons(url) {
  try {
    const response = await fetch(url, requestOptions(21600));
    if (!response.ok) return [];
    const manifest = await response.json();
    if (!Array.isArray(manifest.icons)) return [];
    return manifest.icons
      .map((icon) => webUrl(icon?.src, response.url || url))
      .filter(Boolean);
  } catch {
    return [];
  }
}

async function imageResponse(url, rasterFallbackHost = null) {
  let response;
  try {
    response = await fetch(url, requestOptions(86400));
  } catch {
    return null;
  }
  const type = response.headers.get('content-type') || '';
  if (!response.ok || !isImage(type)) return null;

  // AA gibi image/x-icon veren sitelerde raster yanıt, Flutter Web için daha
  // güvenilir. Dış servis yalnız biçim uyumluluğu için devreye giriyor.
  if (rasterFallbackHost && isIco(type)) {
    const raster = await imageResponse(
      `https://www.google.com/s2/favicons?domain=${encodeURIComponent(rasterFallbackHost)}&sz=64`,
    );
    if (raster) return raster;
  }

  const headers = new Headers(CORS);
  headers.set('Content-Type', response.headers.get('content-type'));
  headers.set('Cache-Control', 'public, max-age=86400, immutable');
  return new Response(response.body, { status: 200, headers });
}

function requestOptions(cacheTtl) {
  return {
    headers: { 'User-Agent': AGENT },
    cf: { cacheTtl, cacheEverything: true },
  };
}

function isWebUrl(url) {
  return url.protocol === 'https:' || url.protocol === 'http:';
}

function isImage(value) {
  const type = (value || '').toLowerCase();
  return type.startsWith('image/') || type.includes('svg+xml') || type.includes('x-icon');
}

function isIco(value) {
  const type = (value || '').toLowerCase();
  return type.includes('x-icon') || type.includes('vnd.microsoft.icon');
}

function webUrl(value, base) {
  if (!value) return null;
  try {
    const url = new URL(value.trim(), base);
    return isWebUrl(url) ? url.href : null;
  } catch {
    return null;
  }
}

function attributes(element) {
  return Object.fromEntries([...element.matchAll(/([\w:-]+)\s*=\s*(["'])([\s\S]*?)\2/g)]
    .map((m) => [m[1].toLowerCase(), m[3]]));
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function fail(status, message) {
  return new Response(message, { status, headers: CORS });
}
