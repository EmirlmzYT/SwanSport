import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
import { test } from 'node:test';

const source = await readFile(new URL('../apps/swansport_app/functions/api/rss.js', import.meta.url), 'utf8');
const { parseFeed } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`);
const parse = (body) => parseFeed(`<rss><channel><item><title>Haber</title><link>https://news.example/sport/story</link>${body}</item></channel></rss>`, 'https://news.example/feed')[0];

test('enclosure attributes may appear in any order and entities are decoded', () => {
  assert.equal(parse('<enclosure type="image/jpeg" url="/photo.jpg?a=1&amp;b=2"/>').image,
    'https://news.example/photo.jpg?a=1&b=2');
});

test('video media is skipped in favor of its thumbnail', () => {
  assert.equal(parse('<media:content url="/clip.mp4" type="video/mp4"/><media:thumbnail url="//cdn.example/photo"/>').image,
    'https://cdn.example/photo');
});

test('escaped content:encoded supplies a relative lazy image and plain summary', () => {
  const item = parse('<content:encoded>&lt;p&gt;Spor &#351;enliği&lt;/p&gt;&lt;img data-src="../photo.jpg"&gt;</content:encoded>');
  assert.equal(item.image, 'https://news.example/photo.jpg');
  assert.equal(item.summary, 'Spor şenliği');
});

test('CDATA images work and unsafe URLs are skipped', () => {
  assert.equal(parse('<description><![CDATA[<img src="javascript:alert(1)"><img src="/ok.webp">]]></description>').image,
    'https://news.example/ok.webp');
  assert.equal(parse('<description>Yalnızca metin</description>').image, null);
});

test('Atom enclosure and alternate link are supported', () => {
  const [item] = parseFeed('<feed><entry><title>Atom</title><link href="/story"/><link rel="enclosure" type="image/png" href="/image.png"/><summary>Özet</summary></entry></feed>', 'https://news.example/feed');
  assert.equal(item.link, 'https://news.example/story');
  assert.equal(item.image, 'https://news.example/image.png');
});
