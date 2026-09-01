import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Şehir bazlı antrenör toplulukları.
///
/// Üyelik otomatik: doğrulanmış bir antrenörün şehri neresiyse o ilin grubuna
/// kendiliğinden girer. Çıkan kişi `state='left'` olarak işaretlenir ve otomatik
/// katılım onu bir daha geri sokmaz.
/// ---------------------------------------------------------------------------

/// İl listesi öğesi (81 il veritabanından gelir — tek kaynak).
class CityRow {
  const CityRow({required this.code, required this.name});
  final String code;
  final String name;
}

class CommunityRow {
  const CommunityRow({
    required this.id,
    required this.name,
    required this.cityName,
    required this.memberCount,
    required this.unread,
    required this.joined,
    this.kind = 'city_coach',
    this.canWrite = true,
    this.lastBody,
    this.lastAt,
  });

  final String id;
  final String name;
  final String cityName;
  final int memberCount;
  final int unread;
  final bool joined;

  /// 'city_coach' (herkes yazar) | 'federation' (duyuru kanalı)
  final String kind;

  /// Ana akışa yazabilir mi? Federasyon kanalında yalnızca yetkili yazabilir.
  final bool canWrite;

  final String? lastBody;
  final DateTime? lastAt;

  bool get isFederation => kind == 'federation';

  factory CommunityRow.fromMap(Map<String, dynamic> m) => CommunityRow(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        cityName: (m['city_name'] as String?) ?? '',
        memberCount: (m['member_count'] as int?) ?? 0,
        unread: (m['unread'] as int?) ?? 0,
        joined: (m['joined'] as bool?) ?? false,
        kind: (m['kind'] as String?) ?? 'city_coach',
        canWrite: (m['can_write'] as bool?) ?? true,
        lastBody: m['last_body'] as String?,
        lastAt: m['last_at'] == null
            ? null
            : DateTime.tryParse('${m['last_at']}')?.toLocal(),
      );
}

/// Federasyon duyurusu — ana akıştaki üst düzey mesaj.
class FederationAnnouncement {
  const FederationAnnouncement({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.senderId,
    required this.senderName,
    required this.replyCount,
    this.senderAvatarUrl,
    this.cityName,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String senderId;
  final String senderName;
  final int replyCount;
  final String? senderAvatarUrl;

  /// Duyuru bir ile hedeflendiyse o ilin adı; boşsa tüm Türkiye.
  final String? cityName;
}

/// Duyurunun altındaki soru/yanıt.
class ReplyRow {
  const ReplyRow({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.senderId,
    required this.senderName,
    this.senderAvatarUrl,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final String senderId;
  final String senderName;
  final String? senderAvatarUrl;
}

class CommunityMessageRow {
  const CommunityMessageRow({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool isMine;
}

/// Sohbette gönderenin adını göstermek için üye künyesi.
class CommunityMember {
  const CommunityMember({required this.id, required this.name, this.avatarUrl});
  final String id;
  final String name;
  final String? avatarUrl;

  String get initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return (first + last).toUpperCase();
  }
}

class CommunityService {
  CommunityService(this._c);
  final SupabaseClient _c;

  String? get _uid => _c.auth.currentUser?.id;

  Future<List<CityRow>> sports() async {
    final rows = await _c.from('sports').select('code, name').order('name');
    return (rows as List)
        .map((r) => CityRow(
              code: (r as Map)['code'] as String,
              name: r['name'] as String,
            ))
        .toList();
  }

  Future<List<CityRow>> cities() async {
    final rows = await _c.from('cities').select('code, name').order('name');
    return (rows as List)
        .map((r) => CityRow(
              code: (r as Map)['code'] as String,
              name: r['name'] as String,
            ))
        .toList();
  }

  /// Tüm federasyon kanalları (yönetici ekranı için — üye olmasa da görünür).
  Future<List<CommunityRow>> federationChannels() async {
    final rows = await _c
        .from('communities')
        .select('id, name')
        .eq('kind', 'federation')
        .order('name');
    return (rows as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return CommunityRow(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        cityName: '',
        memberCount: 0,
        unread: 0,
        joined: false,
        kind: 'federation',
      );
    }).toList();
  }

  Future<List<CommunityRow>> list() async {
    final rows = await _c.rpc<List<dynamic>>('my_communities');
    return rows
        .map((r) => CommunityRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Uygun olduğu gruplara sessizce ekler; kaç gruba eklendiğini döner.
  /// Takım kanalını bulur; gerekiyorsa önce üyeliği kurar.
  ///
  /// Kanal `communities` tablosunda `kind = 'team'` satırı olarak yaşıyor
  /// (0045). Yeni bir mesajlaşma mekanizması yazılmadı: topluluk sohbeti
  /// zaten canlı akıyor, okunmamış sayacı tutuyor ve RLS'i üyelik bazlı.
  ///
  /// Önce `ensure_my_team_channels` çağrılıyor çünkü kanalı **görebilmek**
  /// için üye olmak gerekiyor — 0045 sonrası takım kanalları herkese
  /// listelenmiyor. Üye olmayan biri için sorgu boş döner ve `null` alır.
  Future<String?> teamChannel(String teamId) async {
    try {
      await _c.rpc<int>('ensure_my_team_channels');
    } catch (_) {
      // 0045 çalıştırılmadıysa fonksiyon yok. Kanal da yoktur; aşağıdaki
      // sorgu boş döner ve ekran sohbeti gizler. Kırılan bir şey olmuyor.
    }
    final rows = await _c
        .from('communities')
        .select('id')
        .eq('team_id', teamId)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return ((list.first as Map).cast<String, dynamic>())['id'] as String?;
  }

  Future<int> ensureMine() async {
    if (_uid == null) return 0;
    try {
      return await _c.rpc<int>('ensure_my_communities');
    } catch (error) {
      // SQL henüz çalıştırılmamışsa uygulamayı düşürme.
      debugPrint('SwanSport: ensure_my_communities başarısız — $error');
      return 0;
    }
  }

  Future<void> join(String communityId) =>
      _c.rpc<void>('join_community', params: {'p_community': communityId});

  Future<void> leave(String communityId) =>
      _c.rpc<void>('leave_community', params: {'p_community': communityId});

  Future<void> markRead(String communityId) =>
      _c.rpc<void>('mark_community_read', params: {'p_community': communityId});

  Future<void> send(String communityId, String body) async {
    final uid = _uid;
    if (uid == null || body.trim().isEmpty) return;
    await _c.from('community_messages').insert({
      'community_id': communityId,
      'sender_id': uid,
      'body': body.trim(),
    });
  }

  Future<void> removeMessage(String id) async {
    await _c.from('community_messages').delete().eq('id', id);
  }


  // --------------------------- federasyon kanalı ---------------------------

  Future<List<FederationAnnouncement>> announcements(String communityId) async {
    final rows = await _c.rpc<List<dynamic>>('federation_announcements',
        params: {'p_community': communityId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final avatar = m['sender_avatar'] as String?;
      return FederationAnnouncement(
        id: m['id'] as String,
        body: (m['body'] as String?) ?? '',
        createdAt:
            DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
        senderId: m['sender_id'] as String,
        senderName: ((m['sender_name'] as String?) ?? '').trim().isEmpty
            ? 'Federasyon'
            : (m['sender_name'] as String).trim(),
        senderAvatarUrl: (avatar == null || avatar.isEmpty)
            ? null
            : _c.storage.from('post-media').getPublicUrl(avatar),
        cityName: m['city_name'] as String?,
        replyCount: (m['reply_count'] as int?) ?? 0,
      );
    }).toList();
  }

  Future<List<ReplyRow>> replies(String parentId) async {
    final rows =
        await _c.rpc<List<dynamic>>('message_replies', params: {'p_parent': parentId});
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final avatar = m['sender_avatar'] as String?;
      return ReplyRow(
        id: m['id'] as String,
        body: (m['body'] as String?) ?? '',
        createdAt:
            DateTime.tryParse('${m['created_at']}')?.toLocal() ?? DateTime.now(),
        senderId: m['sender_id'] as String,
        senderName: ((m['sender_name'] as String?) ?? '').trim().isEmpty
            ? 'Üye'
            : (m['sender_name'] as String).trim(),
        senderAvatarUrl: (avatar == null || avatar.isEmpty)
            ? null
            : _c.storage.from('post-media').getPublicUrl(avatar),
      );
    }).toList();
  }

  /// Duyuru yayımlar. [cityCode] boşsa tüm Türkiye'ye gider.
  Future<void> publish(String communityId, String body,
      {String? cityCode}) async {
    final uid = _uid;
    if (uid == null || body.trim().isEmpty) return;
    await _c.from('community_messages').insert({
      'community_id': communityId,
      'sender_id': uid,
      'body': body.trim(),
      if (cityCode != null && cityCode.isNotEmpty) 'target_city_code': cityCode,
    });
  }

  /// Bir duyuruyu yanıtlar.
  Future<void> reply(String communityId, String parentId, String body) async {
    final uid = _uid;
    if (uid == null || body.trim().isEmpty) return;
    await _c.from('community_messages').insert({
      'community_id': communityId,
      'sender_id': uid,
      'parent_id': parentId,
      'body': body.trim(),
    });
  }

  /// Platform yöneticisi: federasyon yetkilisi atar/alır.
  Future<void> setStaff(String communityId, String profileId, bool staff) =>
      _c.rpc<void>('set_community_staff', params: {
        'p_community': communityId,
        'p_profile': profileId,
        'p_staff': staff,
      });

  /// Gruptaki kişilerin adı/avatarı — mesaj baloncuklarında gösterilir.
  Future<Map<String, CommunityMember>> members(String communityId) async {
    final rows = await _c
        .from('community_members')
        .select('profile_id, state, profiles!inner(id, full_name, avatar_path)')
        .eq('community_id', communityId)
        .eq('state', 'joined');

    final out = <String, CommunityMember>{};
    for (final r in rows as List) {
      final m = (r as Map).cast<String, dynamic>();
      final p = (m['profiles'] as Map?)?.cast<String, dynamic>();
      if (p == null) continue;
      final avatar = p['avatar_path'] as String?;
      out[p['id'] as String] = CommunityMember(
        id: p['id'] as String,
        name: ((p['full_name'] as String?) ?? '').trim().isEmpty
            ? 'Üye'
            : (p['full_name'] as String).trim(),
        avatarUrl: (avatar == null || avatar.isEmpty)
            ? null
            : _c.storage.from('post-media').getPublicUrl(avatar),
      );
    }
    return out;
  }

  /// Mesaj akışı — yeni mesaj yazıldığı anda ekrana düşer.
  Stream<List<CommunityMessageRow>> messageStream(String communityId) {
    final uid = _uid;
    return _c
        .from('community_messages')
        .stream(primaryKey: ['id'])
        .eq('community_id', communityId)
        .order('created_at')
        .map((rows) => rows.map((m) {
              return CommunityMessageRow(
                id: m['id'] as String,
                senderId: m['sender_id'] as String,
                body: (m['body'] as String?) ?? '',
                createdAt:
                    DateTime.tryParse('${m['created_at']}')?.toLocal() ??
                        DateTime.now(),
                isMine: m['sender_id'] == uid,
              );
            }).toList());
  }
}

// =============================== Provider'lar ==============================

/// Bir takımın sohbet kanalı — yoksa null.
///
/// Null dönebilir: 0045 çalıştırılmadıysa ya da kullanıcı o takımın üyesi
/// değilse. Ekran bu durumda sohbet sekmesini hiç göstermiyor; boş bir
/// sekme açıp "burada bir şey yok" demek daha kötü.
final teamChannelProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, teamId) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(null);
  return ref.watch(communityServiceProvider).teamChannel(teamId);
});

final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService(ref.watch(supabaseClientProvider));
});

final citiesProvider = FutureProvider<List<CityRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(communityServiceProvider).cities();
});

final federationChannelsProvider =
    FutureProvider.autoDispose<List<CommunityRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(communityServiceProvider).federationChannels();
});

final sportsProvider = FutureProvider<List<CityRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(communityServiceProvider).sports();
});

final federationAnnouncementsProvider = FutureProvider.autoDispose
    .family<List<FederationAnnouncement>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <FederationAnnouncement>[]);
  }
  return ref.watch(communityServiceProvider).announcements(id);
});

final repliesProvider =
    FutureProvider.autoDispose.family<List<ReplyRow>, String>((ref, parentId) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <ReplyRow>[]);
  }
  return ref.watch(communityServiceProvider).replies(parentId);
});

final communityListProvider =
    FutureProvider.autoDispose<List<CommunityRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(communityServiceProvider).list();
});

final communityMembersProvider = FutureProvider.autoDispose
    .family<Map<String, CommunityMember>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <String, CommunityMember>{});
  }
  return ref.watch(communityServiceProvider).members(id);
});

/// Anlık mesaj akışı. Uygulamadaki ilk realtime bağlantısı.
final communityMessagesProvider = StreamProvider.autoDispose
    .family<List<CommunityMessageRow>, String>((ref, id) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Stream.value(const <CommunityMessageRow>[]);
  }
  return ref.watch(communityServiceProvider).messageStream(id);
});

/// Ana ekran açılışında çağrılır — şehri/kademesi uyan gruplara sessizce ekler.
Future<void> ensureMyCommunities(WidgetRef ref) async {
  try {
    final added = await ref.read(communityServiceProvider).ensureMine();
    if (added > 0) ref.invalidate(communityListProvider);
  } catch (_) {
    // Sessiz — kullanıcıyı rahatsız etmez.
  }
}
