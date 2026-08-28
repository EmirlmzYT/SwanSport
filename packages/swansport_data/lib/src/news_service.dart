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
  });

  final String title;
  final String sourceName;
  final DateTime publishedAt;
  final String? summary;
  final String? link;
  final String? imageUrl;
}

class NewsService {
  NewsService(this._c);
  final SupabaseClient _c;

  // ----------------------------- kaynaklar -----------------------------
  Future<List<RssSource>> sources({bool onlyActive = true}) async {
    var q = _c.from('rss_sources').select('id, name, url, active');
    if (onlyActive) q = q.eq('active', true);
    final rows = await q.order('name');
    return (rows as List)
        .map((r) => RssSource.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
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
    try {
      final uri = Uri.parse('$kRssBridge?url=${Uri.encodeComponent(source.url)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return const [];

      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is! Map || body['items'] is! List) return const [];

      final out = <NewsItem>[];
      for (final raw in (body['items'] as List).take(limit)) {
        if (raw is! Map) continue;
        final title = (raw['title'] as String?)?.trim();
        if (title == null || title.isEmpty) continue;
        out.add(NewsItem(
          title: title,
          sourceName: source.name,
          summary: (raw['summary'] as String?)?.trim(),
          link: raw['link'] as String?,
          imageUrl: raw['image'] as String?,
          publishedAt: _parseDate(raw['published'] as String?),
        ));
      }
      return out;
    } catch (error) {
      // Tek kaynak düşerse akışın tamamı bozulmasın.
      debugPrint('SwanSport: haber kaynağı okunamadı — $error');
      return const [];
    }
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
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
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
