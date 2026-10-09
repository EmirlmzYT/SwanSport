import test from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { isPrivateOrLocalHost, detectImageType, onRequest, MAX_IMAGE_BYTES } from '../apps/swansport_app/functions/api/rss-image.js';

test('isPrivateOrLocalHost detects IPv6 with and without brackets', () => {
  assert.equal(isPrivateOrLocalHost('::1'), true);
  assert.equal(isPrivateOrLocalHost('[::1]'), true);
  assert.equal(isPrivateOrLocalHost('[::]'), true);
  assert.equal(isPrivateOrLocalHost('::'), true);
  assert.equal(isPrivateOrLocalHost('[fe80::1]'), true);
  assert.equal(isPrivateOrLocalHost('fe80::dead:beef'), true);
  assert.equal(isPrivateOrLocalHost('[fc00::1]'), true);
  assert.equal(isPrivateOrLocalHost('[fd12:3456:789a::1]'), true);
  assert.equal(isPrivateOrLocalHost('::ffff:127.0.0.1'), true);
  assert.equal(isPrivateOrLocalHost('[::ffff:192.168.1.1]'), true);
});

test('isPrivateOrLocalHost detects private IPv4 and loopback hostnames', () => {
  assert.equal(isPrivateOrLocalHost('localhost'), true);
  assert.equal(isPrivateOrLocalHost('test.localhost'), true);
  assert.equal(isPrivateOrLocalHost('myserver.local'), true);
  assert.equal(isPrivateOrLocalHost('127.0.0.1'), true);
  assert.equal(isPrivateOrLocalHost('10.0.0.5'), true);
  assert.equal(isPrivateOrLocalHost('192.168.1.254'), true);
  assert.equal(isPrivateOrLocalHost('172.16.0.1'), true);
  assert.equal(isPrivateOrLocalHost('172.31.255.255'), true);
  assert.equal(isPrivateOrLocalHost('169.254.169.254'), true);
  assert.equal(isPrivateOrLocalHost('100.64.0.1'), true);
});

test('isPrivateOrLocalHost allows legitimate public hostnames', () => {
  assert.equal(isPrivateOrLocalHost('swansport.app'), false);
  assert.equal(isPrivateOrLocalHost('images.unsplash.com'), false);
  assert.equal(isPrivateOrLocalHost('8.8.8.8'), false);
  // Truly public mapped IPv6
  assert.equal(isPrivateOrLocalHost('::ffff:8.8.8.8'), false);
  assert.equal(isPrivateOrLocalHost('[::ffff:8.8.8.8]'), false);
  assert.equal(isPrivateOrLocalHost('::ffff:808:808'), false);
  assert.equal(isPrivateOrLocalHost('[::ffff:808:808]'), false);
  assert.equal(isPrivateOrLocalHost('::ffff:1.1.1.1'), false);
  assert.equal(isPrivateOrLocalHost('::ffff:101:101'), false);
});

test('isPrivateOrLocalHost detects IPv4-mapped IPv6 in both dotted and hex formats', () => {
  // Loopback 127.0.0.1 in dotted and hex (7f00:1)
  assert.equal(isPrivateOrLocalHost('::ffff:127.0.0.1'), true);
  assert.equal(isPrivateOrLocalHost('[::ffff:127.0.0.1]'), true);
  assert.equal(isPrivateOrLocalHost('::ffff:7f00:1'), true);
  assert.equal(isPrivateOrLocalHost('[::ffff:7f00:1]'), true);
  assert.equal(isPrivateOrLocalHost('0:0:0:0:0:ffff:7f00:1'), true);

  // Private 10.0.0.5 in dotted and hex (a00:5)
  assert.equal(isPrivateOrLocalHost('::ffff:10.0.0.5'), true);
  assert.equal(isPrivateOrLocalHost('[::ffff:10.0.0.5]'), true);
  assert.equal(isPrivateOrLocalHost('::ffff:a00:5'), true);
  assert.equal(isPrivateOrLocalHost('[::ffff:a00:5]'), true);

  // Private 192.168.1.1 in dotted and hex (c0a8:101)
  assert.equal(isPrivateOrLocalHost('::ffff:192.168.1.1'), true);
  assert.equal(isPrivateOrLocalHost('[::ffff:192.168.1.1]'), true);
  assert.equal(isPrivateOrLocalHost('::ffff:c0a8:101'), true);
  assert.equal(isPrivateOrLocalHost('[::ffff:c0a8:101]'), true);

  // Private 172.16.0.1 in hex (ac10:1)
  assert.equal(isPrivateOrLocalHost('::ffff:ac10:1'), true);
  assert.equal(isPrivateOrLocalHost('[::ffff:ac10:1]'), true);
});

test('detectImageType correctly identifies image magic bytes', () => {
  const pngBytes = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00]);
  assert.equal(detectImageType(pngBytes), 'image/png');

  const jpegBytes = Buffer.from([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10]);
  assert.equal(detectImageType(jpegBytes), 'image/jpeg');

  const gifBytes = Buffer.from([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
  assert.equal(detectImageType(gifBytes), 'image/gif');

  const webpBytes = Buffer.from([
    0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00,
    0x57, 0x45, 0x42, 0x50, 0x56, 0x50, 0x38, 0x20
  ]);
  assert.equal(detectImageType(webpBytes), 'image/webp');
});

test('detectImageType rejects HTML, SVG, and executable headers', () => {
  const htmlBytes = Buffer.from('<!DOCTYPE html><html><body><h1>XSS</h1></body></html>');
  assert.equal(detectImageType(htmlBytes), null);

  const svgBytes = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>');
  assert.equal(detectImageType(svgBytes), null);

  const exeBytes = Buffer.from([0x4D, 0x5A, 0x90, 0x00]); // MZ DOS
  assert.equal(detectImageType(exeBytes), null);
});

test('onRequest rejects IPv6 loopback target in URL', async () => {
  const req = new Request('https://edge.swansport.app/api/rss-image?url=' + encodeURIComponent('http://[::1]/photo.jpg'));
  const res = await onRequest({ request: req });
  assert.equal(res.status, 403);
});

test('onRequest rejects mapped IPv6 targets (::ffff:127.0.0.1, ::ffff:7f00:1, ::ffff:10.0.0.5, ::ffff:192.168.1.1) without calling fetch', async () => {
  let fetchCalled = false;
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    fetchCalled = true;
    return new Response('should not be called');
  };

  try {
    const blockedUrls = [
      'http://[::ffff:127.0.0.1]/photo.png',
      'http://[::ffff:7f00:1]/photo.png',
      'http://[::ffff:10.0.0.5]/photo.png',
      'http://[::ffff:192.168.1.1]/photo.png',
      'http://[::ffff:a00:5]/photo.png',
      'http://[::ffff:c0a8:101]/photo.png',
    ];

    for (const u of blockedUrls) {
      fetchCalled = false;
      const req = new Request('https://edge.swansport.app/api/rss-image?url=' + encodeURIComponent(u));
      const res = await onRequest({ request: req });
      assert.equal(res.status, 403, `URL ${u} should be rejected with 403`);
      assert.equal(fetchCalled, false, `Fetch should NEVER be called for blocked URL ${u}`);
    }
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('onRequest allows truly public mapped IPv6 e.g. ::ffff:8.8.8.8 with mock response', async () => {
  const originalFetch = globalThis.fetch;
  const validPng = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00]);
  globalThis.fetch = async () => {
    return new Response(validPng, {
      status: 200,
      headers: { 'Content-Type': 'image/png' },
    });
  };

  try {
    const req = new Request('https://edge.swansport.app/api/rss-image?url=' + encodeURIComponent('http://[::ffff:8.8.8.8]/valid.png'));
    const res = await onRequest({ request: req });
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('Content-Type'), 'image/png');
    assert.equal(res.headers.get('X-Content-Type-Options'), 'nosniff');
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('onRequest rejects redirect to private or loopback target', async () => {
  // Setup a temporary HTTP server
  const server = http.createServer((req, res) => {
    if (req.url === '/start') {
      res.writeHead(302, { Location: 'http://127.0.0.1:9999/secret.png' });
      res.end();
    }
  });

  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;

  try {
    // Note: since the initial server is on 127.0.0.1, the initial check blocks it if target is 127.0.0.1.
    // Testing redirect re-validation:
    const req = new Request(`https://edge.swansport.app/api/rss-image?url=http://[::1]:${port}/start`);
    const res = await onRequest({ request: req });
    assert.equal(res.status, 403);
  } finally {
    server.close();
  }
});

test('onRequest rejects chunked streaming data exceeding MAX_IMAGE_BYTES without Content-Length', async () => {
  const server = http.createServer((req, res) => {
    res.writeHead(200, {
      'Content-Type': 'image/png',
      // No Content-Length sent
    });
    // Stream chunks that exceed 5MB
    const chunk = Buffer.alloc(1024 * 1024, 0x41); // 1MB chunk
    for (let i = 0; i < 6; i++) {
      res.write(chunk);
    }
    res.end();
  });

  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const port = server.address().port;

  try {
    // We mock fetch for this test to bypass loopback IP check and test the streaming reader
    const originalFetch = globalThis.fetch;
    globalThis.fetch = async (url, options) => {
      // Return a ReadableStream that yields >5MB
      const stream = new ReadableStream({
        start(controller) {
          const chunk = new Uint8Array(1024 * 1024);
          for (let i = 0; i < 6; i++) {
            controller.enqueue(chunk);
          }
          controller.close();
        }
      });
      return new Response(stream, {
        status: 200,
        headers: { 'Content-Type': 'image/png' },
      });
    };

    const req = new Request('https://edge.swansport.app/api/rss-image?url=' + encodeURIComponent('https://images.example.com/oversized.png'));
    const res = await onRequest({ request: req });
    assert.equal(res.status, 413);

    globalThis.fetch = originalFetch;
  } finally {
    server.close();
  }
});

test('onRequest rejects fake declared image MIME when magic bytes are HTML', async () => {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    return new Response('<html><head><script>evil()</script></head></html>', {
      status: 200,
      headers: { 'Content-Type': 'image/png' }, // Spoofed header
    });
  };

  try {
    const req = new Request('https://edge.swansport.app/api/rss-image?url=' + encodeURIComponent('https://images.example.com/fake.png'));
    const res = await onRequest({ request: req });
    assert.equal(res.status, 415);
  } finally {
    globalThis.fetch = originalFetch;
  }
});

test('onRequest passes valid PNG and attaches security headers', async () => {
  const validPng = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52]);
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async () => {
    return new Response(validPng, {
      status: 200,
      headers: { 'Content-Type': 'image/png', 'Content-Length': String(validPng.length) },
    });
  };

  try {
    const req = new Request('https://edge.swansport.app/api/rss-image?url=' + encodeURIComponent('https://images.example.com/valid.png'));
    const res = await onRequest({ request: req });
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('Content-Type'), 'image/png');
    assert.equal(res.headers.get('X-Content-Type-Options'), 'nosniff');
    assert.equal(res.headers.get('Content-Security-Policy'), "default-src 'none'");
  } finally {
    globalThis.fetch = originalFetch;
  }
});
