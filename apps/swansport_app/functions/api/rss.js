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
    return json({ items: parseFeed(xml) }, 200, {
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
function parseFeed(xml) {
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
      const m = block.match(/<link[^>]*href=["']([^"']+)["']/i);
      if (m) link = m[1];
    }

    const summary = clean(
      tag(block, 'description') || tag(block, 'summary') || tag(block, 'content')
    );

    const published =
      tag(block, 'pubDate') ||
      tag(block, 'published') ||
      tag(block, 'updated') ||
      tag(block, 'dc:date');

    // Görsel: enclosure, media:content/thumbnail ya da içerikteki ilk <img>
    let image = null;
    const enc = block.match(
      /<enclosure[^>]*url=["']([^"']+)["'][^>]*type=["']image/i
    );
    const media = block.match(
      /<media:(?:content|thumbnail)[^>]*url=["']([^"']+)["']/i
    );
    const img = block.match(/<img[^>]*src=["']([^"']+)["']/i);
    if (enc) image = enc[1];
    else if (media) image = media[1];
    else if (img) image = img[1];

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
  const re = new RegExp(`<${name}[^>]*>([\\s\\S]*?)<\\/${name}>`, 'i');
  const m = block.match(re);
  return m ? m[1] : '';
}

/** CDATA, HTML etiketleri ve varlıkları temizler. */
function clean(value) {
  if (!value) return '';
  return value
    .replace(/<!\[CDATA\[([\s\S]*?)\]\]>/g, '$1')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/\s+/g, ' ')
    .trim();
}
