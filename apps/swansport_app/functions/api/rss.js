/**
 * RSS köprüsü — Cloudflare Pages Function.
 *
 * Tarayıcı, haber sitelerinin RSS adreslerini doğrudan çekemez (CORS engeli).
 * Bu uç nokta akışı sunucu tarafında alır, sadeleştirilmiş JSON'a çevirip
 * kendi alan adımızdan servis eder. Gizli anahtar kullanmaz.
 *
 * Kullanım: /api/rss?url=https://ornek.com/feed.xml
 */

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

export async function onRequest(context) {
  const { request } = context;

  if (request.method === 'OPTIONS') {
    return new Response(null, { headers: CORS });
  }

  const target = new URL(request.url).searchParams.get('url');
  if (!target) {
    return json({ error: 'url parametresi gerekli' }, 400);
  }

  let parsed;
  try {
    parsed = new URL(target);
  } catch {
    return json({ error: 'geçersiz url' }, 400);
  }
  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:') {
    return json({ error: 'yalnızca http(s) desteklenir' }, 400);
  }

  try {
    const res = await fetch(parsed.toString(), {
      headers: { 'User-Agent': 'SwanSport/1.0 (+https://swansport.pages.dev)' },
      cf: { cacheTtl: 900, cacheEverything: true },
    });
    if (!res.ok) {
      return json({ error: `kaynak yanıt vermedi (${res.status})` }, 502);
    }
    const xml = await res.text();
    const items = parseFeed(xml, res.url || parsed.toString());
    await enrichMissingImages(items, res.url || parsed.toString());
    return json({ items }, 200, {
      // 15 dakika önbellek — her açılışta kaynağı yormayalım.
      'Cache-Control': 'public, max-age=900',
    });
  } catch (e) {
    return json({ error: 'kaynak alınamadı' }, 502);
  }
}

function json(body, status = 200, extra = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', ...CORS, ...extra },
  });
}

/** RSS 2.0 ve Atom akışlarını ortak bir biçime indirger. */
export function parseFeed(xml, feedUrl) {
  const blocks = [
    ...matchAll(xml, /<item[\s>][\s\S]*?<\/item>/gi),
    ...matchAll(xml, /<entry[\s>][\s\S]*?<\/entry>/gi),
  ];

  const items = [];
  for (const block of blocks.slice(0, 40)) {
    const title = clean(tag(block, 'title'));
    if (!title) continue;

    // Atom'da bağlantı özniteliktedir.
    let link = clean(tag(block, 'link'));
    if (!link) {
      for (const element of matchAll(block, /<link\b[^>]*>/gi)) {
        const attrs = attributes(element);
        if (attrs.href && (!attrs.rel || attrs.rel === 'alternate')) {
          link = attrs.href;
          break;
        }
      }
    }
    link = webUrl(link, feedUrl);

    const summary = clean(
      tag(block, 'description') || tag(block, 'summary') ||
      tag(block, 'content:encoded') || tag(block, 'content')
    );

    const published =
      tag(block, 'pubDate') ||
      tag(block, 'published') ||
      tag(block, 'updated') ||
      tag(block, 'dc:date');

    // Görsel: enclosure, media:content/thumbnail ya da içerikteki ilk <img>
    let image = null;
    for (const element of matchAll(block, /<(?:enclosure|media:content|media:thumbnail|link)\b[^>]*>/gi)) {
      const attrs = attributes(element);
      const url = attrs.url || attrs.href;
      const isImage = element.toLowerCase().startsWith('<media:thumbnail') ||
        (element.toLowerCase().startsWith('<media:content') && !attrs.type && !attrs.medium) ||
        attrs.medium === 'image' || /^image\//i.test(attrs.type || '') ||
        (!attrs.type && /\.(?:jpe?g|png|webp|gif|avif)(?:[?#]|$)/i.test(url || ''));
      if (isImage && (image = webUrl(url, link || feedUrl))) break;
    }
    if (!image) {
      const html = decodeEntities(block);
      for (const element of matchAll(html, /<img\b[^>]*>/gi)) {
        const attrs = attributes(element);
        image = webUrl(attrs['data-src'] || attrs['data-original'] || attrs.src, link || feedUrl);
        if (image) break;
      }
    }
    // AA gibi bazı sağlayıcılar doğrudan <image>URL</image>, bazılarıysa
    // <image><url>URL</url></image> kullanır.
    if (!image) image = webUrl(clean(tag(block, 'image')), link || feedUrl);
    if (!image) image = webUrl(clean(tag(block, 'url')), link || feedUrl);

    items.push({
      title,
      link: link || null,
      summary: summary ? summary.slice(0, 400) : null,
      published: published ? published.trim() : null,
      image,
    });
  }
  return items;
}

function matchAll(text, re) {
  const out = [];
  let m;
  while ((m = re.exec(text)) !== null) {
    out.push(m[0]);
    if (out.length > 60) break;
  }
  return out;
}

function tag(block, name) {
  const re = new RegExp(`<${name}(?:\\s[^>]*)?>([\\s\\S]*?)<\\/${name}>`, 'i');
  const m = block.match(re);
  return m ? m[1] : '';
}

/** CDATA, HTML etiketleri ve varlıkları temizler. */
function clean(value) {
  if (!value) return '';
  return decodeEntities(value.replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1'))
    .replace(/<[^>]+>/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

/** RSS görsel vermiyorsa aynı sitedeki haber sayfasının sosyal kapak görselini alır. */
async function enrichMissingImages(items, feedUrl) {
  let feedOrigin;
  try { feedOrigin = new URL(feedUrl).origin; } catch { return; }

  const missing = items.filter((item) => !item.image && item.link).slice(0, 12);
  await Promise.allSettled(missing.map(async (item) => {
    const article = new URL(item.link);
    if (article.origin !== feedOrigin) return;
    const response = await fetch(article, {
      headers: { 'User-Agent': 'SwanSport/1.0 (+https://swansport.pages.dev)' },
      cf: { cacheTtl: 3600, cacheEverything: true },
    });
    if (!response.ok) return;
    const type = response.headers.get('content-type') || '';
    if (!type.includes('text/html')) return;
    item.image = articleImage((await response.text()).slice(0, 400000), article.href);
  }));
}

export function articleImage(html, pageUrl) {
  for (const element of matchAll(html, /<(?:meta|link)\b[^>]*>/gi)) {
    const attrs = attributes(element);
    const key = (attrs.property || attrs.name || attrs.rel || '').toLowerCase();
    if (!['og:image', 'og:image:url', 'twitter:image', 'twitter:image:src', 'image_src'].includes(key)) continue;
    const image = webUrl(attrs.content || attrs.href, pageUrl);
    if (image) return image;
  }
  return null;
}

function attributes(element) {
  return Object.fromEntries([...element.matchAll(/([\w:-]+)\s*=\s*(["'])([\s\S]*?)\2/g)]
    .map((m) => [m[1].toLowerCase(), m[3]]));
}

function webUrl(value, base) {
  if (!value) return null;
  try {
    const url = new URL(decodeEntities(value).trim(), base);
    return ['https:', 'http:'].includes(url.protocol) ? url.href : null;
  } catch { return null; }
}

function decodeEntities(value) {
  return value
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&#(x[0-9a-f]+|\d+);/gi, (match, code) => {
      const n = code[0].toLowerCase() === 'x' ? parseInt(code.slice(1), 16) : Number(code);
      return n > 0 && n <= 0x10ffff ? String.fromCodePoint(n) : match;
    });
}
