import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Sosyal katmanın paylaşım, kaydetme ve etiketleme yetenekleri.
///
/// `social_service.dart` akışı ve profili taşıyor; burası **gönderiyle ne
/// yapıldığı**: sohbete paylaşma, yeniden paylaşma, kaydetme, etiketleme.
/// İkinci bir akış servisi yazılmadı — `PostRow`, `feedProvider` ve
/// `SocialService` olduğu gibi kullanılıyor.
///
/// GÜVENLİ KART BURADAN GEÇİYOR: paylaşılan içeriğin görüntüsü mesaja
/// gömülmüyor, her okumada `shared_content_card` ile kaynaktan tazeleniyor.
/// Kaynak silinmiş ya da erişim kapanmışsa kart eski veriyi göstermek yerine
/// [SharedCard.unavailable] durumuna düşüyor.
/// ---------------------------------------------------------------------------

/// Sohbette çizilen paylaşım kartı.
///
/// [available] false ise **hiçbir alan dolu değil**: başlık bile dönmüyor.
/// "Silinmiş gönderinin başlığı" da sızdırılmış içeriktir.
class SharedCard {
  const SharedCard({
    required this.available,
    this.title,
    this.subtitle,
    this.imageRef,
    this.route,
  });

  const SharedCard.unavailable()
      : available = false,
        title = null,
        subtitle = null,
        imageRef = null,
        route = null;

  final bool available;
  final String? title;
  final String? subtitle;
  final String? imageRef;
  final String? route;

  /// Kullanıcıya gösterilecek tek metin. Kaynak neden yok — silinmiş mi,
  /// erişimin mi yok — **söylenmiyor**: fark, olmayan bir içeriğin varlığını
  /// doğrulardı.
  String get fallbackLabel => 'Bu içerik artık kullanılamıyor';

  factory SharedCard.fromMap(Map<String, dynamic> m) {
    final ok = (m['available'] as bool?) ?? false;
    if (!ok) return const SharedCard.unavailable();
    return SharedCard(
      available: true,
      title: m['title'] as String?,
      subtitle: m['subtitle'] as String?,
      imageRef: m['image_ref'] as String?,
      route: m['route'] as String?,
    );
  }
}

/// Paylaşılabilir içerik türleri. Sunucudaki `content_type` ile birebir.
class ShareKind {
  const ShareKind._();

  static const post = 'content_share';
  static const listing = 'marketplace_share';
  static const event = 'event_share';
  static const organization = 'organization_share';

  static const all = [post, listing, event, organization];
}

/// Gönderi görünürlüğü.
enum PostVisibility { public, followers, club, team, privateDraft }

String visibilityKey(PostVisibility v) => switch (v) {
      PostVisibility.public => 'public',
      PostVisibility.followers => 'followers',
      PostVisibility.club => 'club',
      PostVisibility.team => 'team',
      PostVisibility.privateDraft => 'private_draft',
    };

PostVisibility visibilityFrom(String? v) => switch (v) {
      'followers' => PostVisibility.followers,
      'club' => PostVisibility.club,
      'team' => PostVisibility.team,
      'private_draft' => PostVisibility.privateDraft,
      _ => PostVisibility.public,
    };

String visibilityLabel(PostVisibility v) => switch (v) {
      PostVisibility.public => 'Herkese açık',
      PostVisibility.followers => 'Takipçiler',
      PostVisibility.club => 'Kulüp',
      PostVisibility.team => 'Takım',
      PostVisibility.privateDraft => 'Taslak',
    };

/// Kaydedilen gönderi satırı.
class SavedPost {
  const SavedPost({
    required this.postId,
    required this.body,
    required this.author,
    required this.createdAt,
    required this.savedAt,
    this.imagePath,
  });

  final String postId;
  final String body;
  final String author;
  final String? imagePath;
  final DateTime createdAt;
  final DateTime savedAt;

  factory SavedPost.fromMap(Map<String, dynamic> m) => SavedPost(
        postId: (m['post_id'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        author: (m['author'] as String?) ?? 'Bilinmeyen',
        imagePath: m['image_path'] as String?,
        createdAt: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
        savedAt: DateTime.tryParse('${m['saved_at']}') ?? DateTime.now(),
      );
}

/// Paylaşım sayfasında listelenen hedef (sohbet ya da kanal).
class ShareTarget {
  const ShareTarget({
    required this.id,
    required this.name,
    required this.isCommunity,
  });

  final String id;
  final String name;
  final bool isCommunity;
}

/// Etiketlenme izni.
enum MentionPolicy { everyone, following, nobody }

String mentionPolicyKey(MentionPolicy p) => switch (p) {
      MentionPolicy.everyone => 'everyone',
      MentionPolicy.following => 'following',
      MentionPolicy.nobody => 'nobody',
    };

MentionPolicy mentionPolicyFrom(String? v) => switch (v) {
      'following' => MentionPolicy.following,
      'nobody' => MentionPolicy.nobody,
      _ => MentionPolicy.everyone,
    };

String mentionPolicyLabel(MentionPolicy p) => switch (p) {
      MentionPolicy.everyone => 'Herkes etiketleyebilir',
      MentionPolicy.following => 'Yalnızca takip ettiklerim',
      MentionPolicy.nobody => 'Kimse etiketleyemez',
    };

// ================================= Servis ==================================

class SocialShareService {
  SocialShareService(this._c);

  final SupabaseClient _c;

  /// Paylaşılan içeriğin **güncel** kartı.
  ///
  /// Her okumada çağrılıyor; sonuç önbelleğe alınmıyor. Önbelleğe alsaydık
  /// silinmiş bir içerik oturum boyunca görünmeye devam ederdi.
  Future<SharedCard> card(String kind, String id) async {
    try {
      final rows = await _c.rpc<List<dynamic>>('shared_content_card',
          params: {'p_kind': kind, 'p_id': id});
      if (rows.isEmpty) return const SharedCard.unavailable();
      return SharedCard.fromMap((rows.first as Map).cast<String, dynamic>());
    } catch (_) {
      // Hata da "gösterme" anlamına geliyor: kısmi veri göstermektense
      // kartı boş bırakmak doğru taraf.
      return const SharedCard.unavailable();
    }
  }

  /// Sohbetlere ve kanallara paylaş. Dönen sayı kaç hedefe gittiği.
  Future<int> share({
    required String kind,
    required String id,
    List<String> recipients = const [],
    List<String> communities = const [],
    String? note,
  }) =>
      _c.rpc<int>('post_share_to_dm', params: {
        'p_kind': kind,
        'p_id': id,
        'p_recipients': recipients,
        'p_communities': communities,
        'p_note': note,
      });

  /// [body] boşsa repost, doluysa alıntı. Yeni gönderinin kimliğini döner.
  Future<String> repostOrQuote(String postId, {String? body}) =>
      _c.rpc<String>('create_repost_or_quote',
          params: {'p_post': postId, 'p_body': body});

  /// Kaydet/kaldır. Dönen değer son durum.
  Future<bool> toggleSaved(String postId) =>
      _c.rpc<bool>('toggle_saved_post', params: {'p_post': postId});

  Future<List<SavedPost>> savedPosts({int limit = 30, int offset = 0}) async {
    final rows = await _c.rpc<List<dynamic>>('my_saved_posts',
        params: {'p_limit': limit, 'p_offset': offset});
    return rows
        .map((e) => SavedPost.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Etiket ve hashtag'leri yazar.
  ///
  /// Metin **istemcide** ayrıştırılıyor ve buraya kimlikler geliyor. Sunucuda
  /// metin ayrıştırmak, kullanıcı adı değişince ilişkiyi koparırdı.
  Future<void> setTags(String postId,
          {List<String> mentions = const [],
          List<String> hashtags = const []}) =>
      _c.rpc<void>('set_post_tags', params: {
        'p_post': postId,
        'p_mentions': mentions,
        'p_hashtags': hashtags,
      });

  Future<void> setPrivacy({MentionPolicy? mention, bool? externalShare}) =>
      _c.rpc<void>('set_social_privacy', params: {
        'p_mention_policy': mention == null ? null : mentionPolicyKey(mention),
        'p_external_share': externalShare,
      });

  /// Gönderiye ait fotoğraf yolları, sırasıyla.
  Future<List<String>> media(String postId) async {
    final rows = await _c
        .from('post_media')
        .select('media_path, sort_order')
        .eq('post_id', postId)
        .order('sort_order');
    return rows.map((e) => (e as Map)['media_path'] as String).toList();
  }

  /// Paylaşım sayfası için hedef listesi: son sohbetler + üye olunan kanallar.
  Future<List<ShareTarget>> shareTargets() async {
    final me = _c.auth.currentUser?.id;
    if (me == null) return const [];

    final dms = await _c
        .from('direct_messages')
        .select('sender_id, recipient_id, created_at, '
            'sender:profiles!direct_messages_sender_id_fkey(full_name), '
            'recipient:profiles!direct_messages_recipient_id_fkey(full_name)')
        .or('sender_id.eq.$me,recipient_id.eq.$me')
        .order('created_at', ascending: false)
        .limit(60);

    final seen = <String>{};
    final out = <ShareTarget>[];
    for (final r in dms) {
      final m = (r as Map).cast<String, dynamic>();
      final isMine = m['sender_id'] == me;
      final other = (isMine ? m['recipient_id'] : m['sender_id']) as String?;
      if (other == null || other == me || !seen.add(other)) continue;
      final p = (isMine ? m['recipient'] : m['sender']);
      out.add(ShareTarget(
          id: other,
          name: (p is Map ? p['full_name'] as String? : null) ?? 'Kişi',
          isCommunity: false));
      if (out.length >= 12) break;
    }

    final channels = await _c
        .from('community_members')
        .select('community_id, communities(name)')
        .eq('profile_id', me)
        .limit(20);
    for (final r in channels) {
      final m = (r as Map).cast<String, dynamic>();
      final c = m['communities'];
      out.add(ShareTarget(
          id: m['community_id'] as String,
          name: (c is Map ? c['name'] as String? : null) ?? 'Kanal',
          isCommunity: true));
    }

    return out;
  }
}

// =============================== Provider'lar ==============================

final socialShareServiceProvider = Provider<SocialShareService>((ref) {
  return SocialShareService(ref.watch(supabaseClientProvider));
});

/// Paylaşılan içeriğin kartı. `family` anahtarı `"kind|id"`.
///
/// `autoDispose` **değil değil** — autoDispose: sohbetten çıkınca kart
/// önbellekte kalmamalı, silinmiş bir içerik yeniden açıldığında tazelensin.
final sharedCardProvider = FutureProvider.autoDispose
    .family<SharedCard, String>((ref, key) async {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return const SharedCard.unavailable();
  }
  final i = key.indexOf('|');
  if (i <= 0) return const SharedCard.unavailable();
  return ref
      .watch(socialShareServiceProvider)
      .card(key.substring(0, i), key.substring(i + 1));
});

final savedPostsProvider =
    FutureProvider.autoDispose<List<SavedPost>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(socialShareServiceProvider).savedPosts();
});

final shareTargetsProvider =
    FutureProvider.autoDispose<List<ShareTarget>>((ref) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(socialShareServiceProvider).shareTargets();
});

final postMediaProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, postId) async {
  if (!ref.watch(isSupabaseEnabledProvider)) return const [];
  return ref.watch(socialShareServiceProvider).media(postId);
});
