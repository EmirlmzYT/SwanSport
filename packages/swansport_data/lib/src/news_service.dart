import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Spor haberleri — platform yöneticisinin yönettiği RSS kaynakları.
///
/// Tarayıcı RSS adreslerini doğrudan çekemediği için (CORS) akışlar kendi
/// alan adımızdaki `/api/rss` köprüsü üzerinden alınır.
/// ---------------------------------------------------------------------------

/// RSS köprüsünün adresi. Yayındaki site üzerinden servis edilir.
const String kRssBridge = 'https://swansport.pages.dev/api/rss';
const String kRssIconBridge = 'https://swansport.pages.dev/api/rss-icon';

class RssSource {
  const RssSource({
    required this.id,
    required this.name,
    required this.url,
    required this.active,
  });

  final String id;
  final String name;
  final String url;
  final bool active;

  factory RssSource.fromMap(Map<String, dynamic> m) => RssSource(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        url: (m['url'] as String?) ?? '',
        active: (m['active'] as bool?) ?? true,
      );
}

class NewsItem {
  const NewsItem({
    required this.title,
    required this.sourceName,
    required this.publishedAt,
    this.summary,
    this.link,
    this.imageUrl,
    this.sourceIconUrl,
  });

  final String title;
  final String sourceName;
  final DateTime publishedAt;
  final String? summary;
  final String? link;
  final String? imageUrl;
  final String? sourceIconUrl;
}

class NewsService {
  NewsService(this._c);
  final SupabaseClient _c;

  /// Veritabanı boşsa veya erişilemezse devreye giren canlı Türkiye spor RSS kaynakları.
  static const List<RssSource> defaultSources = [
    RssSource(
      id: 'default-hurriyet-spor',
      name: 'Hürriyet Spor',
      url: 'https://www.hurriyet.com.tr/rss/spor',
      active: true,
    ),
    RssSource(
      id: 'default-cnnturk-spor',
      name: 'CNN Türk Spor',
      url: 'https://www.cnnturk.com/feed/rss/spor/news',
      active: true,
    ),
    RssSource(
      id: 'default-sabah-spor',
      name: 'Sabah Spor',
      url: 'https://www.sabah.com.tr/rss/spor.xml',
      active: true,
    ),
  ];

  // ----------------------------- kaynaklar -----------------------------
  Future<List<RssSource>> sources({bool onlyActive = true}) async {
    try {
      List<RssSource> loaded;
      if (onlyActive) {
        try {
          final rows = await _c.rpc<List<dynamic>>('public_news_sources');
          loaded = rows
              .map((r) => RssSource.fromMap(Map<String, dynamic>.from(r as Map)))
              .toList();
        } catch (_) {
          final rows = await _c
              .from('rss_sources')
              .select('id, name, url, active')
              .eq('active', true)
              .order('name');
          loaded = (rows as List)
              .map((r) => RssSource.fromMap((r as Map).cast<String, dynamic>()))
              .toList();
        }
        // Yanıt vermeyen eski AA RSS adresini filtrele ve canlı yedek kaynaklarla tamamla.
        final filtered = loaded
            .where((s) => !s.url.contains('aa.com.tr/tr/rss/default'))
            .toList();
        final urls = filtered.map((s) => s.url).toSet();
        for (final fallback in defaultSources) {
          if (!urls.contains(fallback.url)) {
            filtered.add(fallback);
          }
        }
        return filtered.isEmpty ? defaultSources : filtered;
      }

      var q = _c.from('rss_sources').select('id, name, url, active');
      final rows = await q.order('name');
      return (rows as List)
          .map((r) => RssSource.fromMap((r as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return onlyActive ? defaultSources : const [];
    }
  }

  Future<void> addSource(String name, String url) async {
    await _c.from('rss_sources').insert({
      'name': name.trim(),
      'url': url.trim(),
      'created_by': _c.auth.currentUser?.id,
    });
  }

  Future<void> setActive(String id, bool active) async {
    await _c.from('rss_sources').update({'active': active}).eq('id', id);
  }

  Future<void> removeSource(String id) async {
    await _c.from('rss_sources').delete().eq('id', id);
  }

  // ----------------------------- haberler ------------------------------

  /// Tüm aktif kaynaklardan haberleri toplar, en yeniden eskiye sıralar.
  Future<List<NewsItem>> latest({int perSource = 6}) async {
    final list = await sources();
    if (list.isEmpty) return const [];

    final results = await Future.wait(
      list.map((s) => _fetch(s, perSource)),
      eagerError: false,
    );

    final all = <NewsItem>[];
    for (final r in results) {
      all.addAll(r);
    }
    all.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return all;
  }

  Future<List<NewsItem>> _fetch(RssSource source, int limit) async {
    // Mobil (iOS/Android) ortamda CORS engeli yoktur ve *.pages.dev bazı
    // operatörlerde zaman aşımına uğrayabilir; bu yüzden önce doğrudan XML çekilir.
    if (!kIsWeb) {
      final direct = await _fetchDirectXml(source, limit);
      if (direct.isNotEmpty) return direct;
      return _fetchViaBridge(source, limit);
    }
    final bridged = await _fetchViaBridge(source, limit);
    if (bridged.isNotEmpty) return bridged;
    return _fetchDirectXml(source, limit);
  }

  Future<List<NewsItem>> _fetchDirectXml(RssSource source, int limit) async {
    try {
      final uri = Uri.tryParse(source.url.trim());
      if (uri == null || (!uri.isScheme('https') && !uri.isScheme('http'))) {
        return const [];
      }
      final res = await http.get(
        uri,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (compatible; SwanSport/1.0)',
          'Accept': 'application/rss+xml, application/xml, text/xml, */*',
        },
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return const [];
      final xml = utf8.decode(res.bodyBytes, allowMalformed: true);
      return parseRssFeedXml(xml, source, limit: limit);
    } catch (error) {
      debugPrint('SwanSport: doğrudan RSS okunamadı (${source.name}) — $error');
      return const [];
    }
  }

  Future<List<NewsItem>> _fetchViaBridge(RssSource source, int limit) async {
    try {
      final uri = Uri.parse(
        '$kRssBridge?v=4&url=${Uri.encodeComponent(source.url)}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return const [];

      final body = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
      if (body is! Map || body['items'] is! List) return const [];

      final out = <NewsItem>[];
      for (final raw in (body['items'] as List).take(limit)) {
        if (raw is! Map) continue;
        final title = (raw['title'] as String?)?.trim();
        if (title == null || title.isEmpty) continue;
        final link = raw['link'] as String?;
        out.add(
          NewsItem(
            title: title,
            sourceName: source.name,
            summary: (raw['summary'] as String?)?.trim(),
            link: link,
            imageUrl: _imageProxy(raw['image'] as String?),
            sourceIconUrl: _sourceIcon(link ?? source.url),
            publishedAt: _parseDate(raw['published'] as String?),
          ),
        );
      }
      return out;
    } catch (error) {
      debugPrint('SwanSport: haber köprüsü okunamadı (${source.name}) — $error');
      return const [];
    }
  }

  /// RSS 2.0 ve Atom XML akışlarını doğrudan Dart içinde ayrıştırır.
  static List<NewsItem> parseRssFeedXml(
    String xml,
    RssSource source, {
    int limit = 6,
  }) {
    final itemMatches = RegExp(
      r'<(?:item|entry)[\s>][\s\S]*?<\/(?:item|entry)>',
      caseSensitive: false,
    ).allMatches(xml);

    final out = <NewsItem>[];
    for (final match in itemMatches) {
      if (out.length >= limit) break;
      final block = match.group(0) ?? '';
      final title = _cleanXmlText(_extractTag(block, 'title'));
      if (title.isEmpty) continue;

      var link = _cleanXmlText(_extractTag(block, 'link'));
      if (link.isEmpty) {
        for (final el in RegExp(r'<link\b[^>]*>', caseSensitive: false)
            .allMatches(block)) {
          final attrs = _parseAttrs(el.group(0) ?? '');
          final href = attrs['href'];
          final rel = attrs['rel'];
          if (href != null &&
              href.isNotEmpty &&
              (rel == null || rel == 'alternate')) {
            link = href;
            break;
          }
        }
      }
      final resolvedLink = _resolveHttpUrl(link, source.url);

      var summary = _cleanXmlText(
        _firstNonEmpty([
          _extractTag(block, 'description'),
          _extractTag(block, 'summary'),
          _extractTag(block, 'content:encoded'),
          _extractTag(block, 'content'),
        ]),
      );
      summary = summary
          .replaceAll(
            RegExp(r'\s*Devamı için tıklayınız\.?\s*$', caseSensitive: false),
            '',
          )
          .trim();
      if (summary.length > 320) {
        summary = '${summary.substring(0, 317).trimRight()}...';
      }

      final published = _firstNonEmpty([
        _extractTag(block, 'pubDate'),
        _extractTag(block, 'published'),
        _extractTag(block, 'updated'),
        _extractTag(block, 'dc:date'),
      ]);

      String? imageUrl;
      for (final el in RegExp(
        r'<(?:enclosure|media:content|media:thumbnail|link)\b[^>]*>',
        caseSensitive: false,
      ).allMatches(block)) {
        final rawEl = el.group(0) ?? '';
        final attrs = _parseAttrs(rawEl);
        final candidate = attrs['url'] ?? attrs['href'];
        final type = (attrs['type'] ?? '').toLowerCase();
        final medium = (attrs['medium'] ?? '').toLowerCase();
        final lowerEl = rawEl.toLowerCase();
        final isImage = lowerEl.startsWith('<media:thumbnail') ||
            (lowerEl.startsWith('<media:content') &&
                type.isEmpty &&
                medium.isEmpty) ||
            medium == 'image' ||
            type.startsWith('image/') ||
            (type.isEmpty &&
                candidate != null &&
                RegExp(
                  r'\.(?:jpe?g|png|webp|gif|avif)(?:[?#]|$)',
                  caseSensitive: false,
                ).hasMatch(candidate));
        if (isImage) {
          imageUrl = _resolveHttpUrl(candidate, resolvedLink ?? source.url);
          if (imageUrl != null) break;
        }
      }

      if (imageUrl == null) {
        final decodedBlock = _decodeHtmlEntities(block);
        for (final el
            in RegExp(r'<img\b[^>]*>', caseSensitive: false).allMatches(
          decodedBlock,
        )) {
          final attrs = _parseAttrs(el.group(0) ?? '');
          final src =
              attrs['data-src'] ?? attrs['data-original'] ?? attrs['src'];
          imageUrl = _resolveHttpUrl(src, resolvedLink ?? source.url);
          if (imageUrl != null) break;
        }
      }

      imageUrl ??= _resolveHttpUrl(
        _cleanXmlText(_extractTag(block, 'image')),
        resolvedLink ?? source.url,
      );
      imageUrl ??= _resolveHttpUrl(
        _cleanXmlText(_extractTag(block, 'url')),
        resolvedLink ?? source.url,
      );

      out.add(
        NewsItem(
          title: title,
          sourceName: source.name,
          summary: summary.isEmpty ? null : summary,
          link: resolvedLink,
          imageUrl: _imageProxy(imageUrl),
          sourceIconUrl: _sourceIcon(resolvedLink ?? source.url),
          publishedAt: _parseDate(published),
        ),
      );
    }
    return out;
  }

  static String _firstNonEmpty(List<String> values) {
    for (final v in values) {
      if (v.trim().isNotEmpty) return v;
    }
    return '';
  }

  static String _extractTag(String block, String name) {
    final escaped = RegExp.escape(name);
    final m = RegExp(
      '<$escaped(?:\\s[^>]*)?>([\\s\\S]*?)<\\/$escaped>',
      caseSensitive: false,
    ).firstMatch(block);
    return m?.group(1) ?? '';
  }

  static Map<String, String> _parseAttrs(String element) {
    final out = <String, String>{};
    for (final m in RegExp(r'''([\w:-]+)\s*=\s*(["'])([\s\S]*?)\2''')
        .allMatches(element)) {
      final key = m.group(1)?.toLowerCase();
      final val = m.group(3);
      if (key != null && val != null) {
        out[key] = val;
      }
    }
    return out;
  }

  static String _cleanXmlText(String value) {
    if (value.isEmpty) return '';
    final withoutCdata = value.replaceAllMapped(
      RegExp(r'<!\[CDATA\[([\s\S]*?)\]\]>'),
      (m) => m.group(1) ?? '',
    );
    return _decodeHtmlEntities(withoutCdata)
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _decodeHtmlEntities(String value) {
    return value
        .replaceAll(RegExp(r'&nbsp;', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&')
        .replaceAll(RegExp(r'&lt;', caseSensitive: false), '<')
        .replaceAll(RegExp(r'&gt;', caseSensitive: false), '>')
        .replaceAll(RegExp(r'&quot;', caseSensitive: false), '"')
        .replaceAll(RegExp(r'&apos;|&#39;', caseSensitive: false), "'")
        .replaceAllMapped(
          RegExp(r'&#(x[0-9a-f]+|\d+);', caseSensitive: false),
          (m) {
            final raw = m.group(1) ?? '';
            final code = raw.toLowerCase().startsWith('x')
                ? int.tryParse(raw.substring(1), radix: 16)
                : int.tryParse(raw);
            if (code != null && code > 0 && code <= 0x10ffff) {
              return String.fromCharCode(code);
            }
            return m.group(0) ?? '';
          },
        );
  }

  static String? _resolveHttpUrl(String? raw, String base) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final baseUri = Uri.parse(base);
      final resolved = baseUri.resolve(_decodeHtmlEntities(raw).trim());
      if (resolved.isScheme('https') || resolved.isScheme('http')) {
        return resolved.toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static String? _imageProxy(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final trimmed = value.trim();
    if (!kIsWeb) return trimmed;
    return '$kRssBridge-image?url=${Uri.encodeComponent(trimmed)}';
  }

  static String? _sourceIcon(String sourceUrl) {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || uri.host.isEmpty) return null;
    if (!kIsWeb) {
      return '${uri.scheme}://${uri.host}/favicon.ico';
    }
    return '$kRssIconBridge?url=${Uri.encodeComponent(uri.toString())}';
  }

  /// RSS tarih biçimleri çeşitlidir; çözülemezse "şimdi" sayılır.
  static DateTime _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return DateTime.now();
    final s = raw.trim();

    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.toLocal();

    // RFC 822: "Sat, 23 Aug 2026 14:05:00 +0300"
    final m = RegExp(
      r'(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(s);
    if (m != null) {
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final mon = months[m.group(2)!.toLowerCase()];
      if (mon != null) {
        return DateTime(
          int.parse(m.group(3)!),
          mon,
          int.parse(m.group(1)!),
          int.parse(m.group(4)!),
          int.parse(m.group(5)!),
          int.parse(m.group(6) ?? '0'),
        );
      }
    }
    return DateTime.now();
  }
}

// =============================== Provider'lar ==============================

final newsServiceProvider = Provider<NewsService>((ref) {
  return NewsService(ref.watch(supabaseClientProvider));
});

/// Akışta gösterilecek haberler.
final newsProvider = FutureProvider.autoDispose<List<NewsItem>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(newsServiceProvider).latest();
});

/// Yönetim paneli için tüm kaynaklar (pasifler dahil).
final rssSourcesProvider = FutureProvider.autoDispose<List<RssSource>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(newsServiceProvider).sources(onlyActive: false);
});
