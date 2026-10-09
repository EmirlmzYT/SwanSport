const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
};

export const MAX_IMAGE_BYTES = 5 * 1024 * 1024; // 5 MB
export const TIMEOUT_MS = 8000;
export const MAX_REDIRECTS = 5;

export const ALLOWED_IMAGE_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
  'image/gif',
  'image/avif',
]);

export function parseIpv4Octets(str) {
  if (!str) return null;
  const m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(str);
  if (m) {
    const [_, a, b, c, d] = m.map(Number);
    if (a <= 255 && b <= 255 && c <= 255 && d <= 255) {
      return [a, b, c, d];
    }
  }
  return null;
}

export function isPrivateIpv4(a, b, c, d) {
  if (a === 0) return true; // 0.0.0.0/8
  if (a === 10) return true; // 10.0.0.0/8
  if (a === 127) return true; // 127.0.0.0/8
  if (a === 100 && b >= 64 && b <= 127) return true; // 100.64.0.0/10 (CGNAT)
  if (a === 169 && b === 254) return true; // 169.254.0.0/16 (Link-local)
  if (a === 172 && b >= 16 && b <= 31) return true; // 172.16.0.0/12
  if (a === 192 && b === 0 && c === 0) return true; // 192.0.0.0/24
  if (a === 192 && b === 0 && c === 2) return true; // 192.0.2.0/24 (TEST-NET-1)
  if (a === 192 && b === 88 && c === 99) return true; // 192.88.99.0/24
  if (a === 192 && b === 168) return true; // 192.168.0.0/16
  if (a === 198 && (b === 18 || b === 19)) return true; // 198.18.0.0/15
  if (a === 198 && b === 51 && c === 100) return true; // 198.51.100.0/24 (TEST-NET-2)
  if (a === 203 && b === 0 && c === 113) return true; // 203.0.113.0/24 (TEST-NET-3)
  if (a >= 224 && a <= 239) return true; // 224.0.0.0/4 (Multicast)
  if (a >= 240) return true; // 240.0.0.0/4 (Reserved)
  if (a === 255 && b === 255 && c === 255 && d === 255) return true; // Broadcast
  return false;
}

export function extractEmbeddedIpv4(host) {
  // 1. Dotted decimal e.g. ::ffff:127.0.0.1 or 64:ff9b::10.0.0.1
  const dottedMatch = /(?:^|:)(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})$/.exec(host);
  if (dottedMatch) {
    return parseIpv4Octets(dottedMatch[1]);
  }

  // 2. Hexadecimal IPv4-mapped / translated e.g. ::ffff:7f00:1 or 64:ff9b::7f00:1
  const hexMapped = /(?:^|:)(?:ffff|64:ff9b|0):([0-9a-f]{1,4}):([0-9a-f]{1,4})$/i.exec(host);
  if (hexMapped) {
    const high = parseInt(hexMapped[1], 16);
    const low = parseInt(hexMapped[2], 16);
    return [
      (high >> 8) & 0xff,
      high & 0xff,
      (low >> 8) & 0xff,
      low & 0xff,
    ];
  }

  // 3. IPv4-compatible (::h1:h2)
  const compatMatch = /^::([0-9a-f]{1,4}):([0-9a-f]{1,4})$/i.exec(host);
  if (compatMatch) {
    const high = parseInt(compatMatch[1], 16);
    const low = parseInt(compatMatch[2], 16);
    return [
      (high >> 8) & 0xff,
      high & 0xff,
      (low >> 8) & 0xff,
      low & 0xff,
    ];
  }

  return null;
}

export function isPrivateOrLocalHost(hostname) {
  if (!hostname) return true;
  let host = hostname.toLowerCase().trim();
  // Strip IPv6 square brackets e.g. [::1] -> ::1
  if (host.startsWith('[') && host.endsWith(']')) {
    host = host.slice(1, -1);
  }

  if (
    host === 'localhost' ||
    host.endsWith('.localhost') ||
    host.endsWith('.local') ||
    host === '127.0.0.1' ||
    host === '::1' ||
    host === '0.0.0.0' ||
    host === '::'
  ) {
    return true;
  }

  // IPv6 Unique Local Addresses (fc00::/7) or Link-Local (fe80::/10)
  if (/^f[cd][0-9a-f]{2}:/i.test(host) || /^fe[89ab][0-9a-f]:/i.test(host)) {
    return true;
  }

  // Check embedded IPv4 (e.g. ::ffff:127.0.0.1, ::ffff:7f00:1, ::ffff:10.0.0.5)
  const embeddedIpv4 = extractEmbeddedIpv4(host);
  if (embeddedIpv4) {
    const [a, b, c, d] = embeddedIpv4;
    return isPrivateIpv4(a, b, c, d);
  }

  // Check pure IPv4
  const ipv4 = parseIpv4Octets(host);
  if (ipv4) {
    const [a, b, c, d] = ipv4;
    return isPrivateIpv4(a, b, c, d);
  }

  return false;
}

export function detectImageType(buffer) {
  if (!buffer || buffer.byteLength < 4) return null;
  const bytes = new Uint8Array(buffer);

  // JPEG: FF D8 FF
  if (bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) {
    return 'image/jpeg';
  }

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (bytes.length >= 8 &&
      bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47 &&
      bytes[4] === 0x0D && bytes[5] === 0x0A && bytes[6] === 0x1A && bytes[7] === 0x0A) {
    return 'image/png';
  }

  // GIF: GIF87a or GIF89a (47 49 46 38)
  if (bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x38) {
    return 'image/gif';
  }

  // WebP: RIFF (0-3) and WEBP (8-11)
  if (bytes.length >= 12 &&
      bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
      bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) {
    return 'image/webp';
  }

  // AVIF: bytes 4-7 are 'ftyp', bytes 8-11 are 'avif' or 'avis'
  if (bytes.length >= 12 &&
      bytes[4] === 0x66 && bytes[5] === 0x74 && bytes[6] === 0x79 && bytes[7] === 0x70 &&
      bytes[8] === 0x61 && bytes[9] === 0x76 && bytes[10] === 0x69 &&
      (bytes[11] === 0x66 || bytes[11] === 0x73)) {
    return 'image/avif';
  }

  return null;
}

export async function onRequest({ request }) {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: CORS });
  }

  const raw = new URL(request.url).searchParams.get('url');
  if (!raw) return new Response('url gerekli', { status: 400, headers: CORS });

  let currentUrl = raw;
  const controller = new AbortController();
  // Single total timeout spanning connection, redirects, and body download
  const timeoutId = setTimeout(() => controller.abort(), TIMEOUT_MS);

  try {
    let redirectsRemaining = MAX_REDIRECTS;
    let upstream;

    while (true) {
      let target;
      try {
        target = new URL(currentUrl);
      } catch {
        return new Response('gecersiz url', { status: 400, headers: CORS });
      }

      if (!['http:', 'https:'].includes(target.protocol)) {
        return new Response('protokol desteklenmiyor', { status: 400, headers: CORS });
      }

      if (isPrivateOrLocalHost(target.hostname)) {
        return new Response('ozel ag adresleri desteklenmiyor', { status: 403, headers: CORS });
      }

      upstream = await fetch(target.toString(), {
        headers: {
          'User-Agent': 'SwanSport/1.0',
          'Accept': 'image/jpeg,image/png,image/webp,image/gif,image/avif;q=0.9,*/*;q=0.1',
        },
        redirect: 'manual',
        signal: controller.signal,
        cf: { cacheTtl: 86400, cacheEverything: true },
      });

      // Handle redirect
      if (upstream.status >= 300 && upstream.status < 400) {
        const location = upstream.headers.get('location');
        if (!location) {
          return new Response('yonlendirme adresi eksik', { status: 502, headers: CORS });
        }
        if (--redirectsRemaining < 0) {
          return new Response('cok fazla yonlendirme', { status: 502, headers: CORS });
        }
        // Resolve relative redirects against current target URL
        currentUrl = new URL(location, target).toString();
        continue;
      }

      break;
    }

    if (!upstream.ok) {
      return new Response(null, { status: upstream.status, headers: CORS });
    }

    const declaredContentType = (upstream.headers.get('content-type') || '').toLowerCase().split(';')[0].trim();
    if (
      declaredContentType === 'text/html' ||
      declaredContentType.includes('xml') ||
      declaredContentType.includes('javascript') ||
      declaredContentType === 'image/svg+xml'
    ) {
      return new Response('guvensiz veya desteklenmeyen icerik tipi', { status: 415, headers: CORS });
    }

    const contentLength = Number(upstream.headers.get('content-length'));
    if (contentLength && contentLength > MAX_IMAGE_BYTES) {
      return new Response('gorsel boyutu siniri asildi (maksimum 5MB)', { status: 413, headers: CORS });
    }

    // Stream body chunks with strict byte limit
    let bodyBuffer;
    if (upstream.body && typeof upstream.body.getReader === 'function') {
      const reader = upstream.body.getReader();
      const chunks = [];
      let totalBytes = 0;

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        totalBytes += value.length;
        if (totalBytes > MAX_IMAGE_BYTES) {
          try {
            await reader.cancel();
          } catch (_) {}
          return new Response('gorsel boyutu siniri asildi (maksimum 5MB)', { status: 413, headers: CORS });
        }
        chunks.push(value);
      }

      const fullBytes = new Uint8Array(totalBytes);
      let offset = 0;
      for (const chunk of chunks) {
        fullBytes.set(chunk, offset);
        offset += chunk.length;
      }
      bodyBuffer = fullBytes;
    } else {
      bodyBuffer = new Uint8Array(await upstream.arrayBuffer());
      if (bodyBuffer.byteLength > MAX_IMAGE_BYTES) {
        return new Response('gorsel boyutu siniri asildi (maksimum 5MB)', { status: 413, headers: CORS });
      }
    }

    const detectedType = detectImageType(bodyBuffer);
    if (!detectedType || !ALLOWED_IMAGE_TYPES.has(detectedType)) {
      return new Response('gecersiz veya desteklenmeyen gorsel formati', { status: 415, headers: CORS });
    }

    const headers = new Headers(CORS);
    headers.set('Content-Type', detectedType);
    headers.set('X-Content-Type-Options', 'nosniff');
    headers.set('Content-Security-Policy', "default-src 'none'");
    headers.set('Cache-Control', 'public, max-age=86400, s-maxage=86400');

    return new Response(bodyBuffer, { status: 200, headers });
  } catch (err) {
    if (err && err.name === 'AbortError') {
      return new Response('istek zaman asimina ugradi', { status: 504, headers: CORS });
    }
    return new Response(null, { status: 502, headers: CORS });
  } finally {
    clearTimeout(timeoutId);
  }
}
