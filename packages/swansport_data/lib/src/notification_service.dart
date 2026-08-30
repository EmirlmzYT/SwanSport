import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_scope.dart';

/// ---------------------------------------------------------------------------
/// Bildirimler ve birebir mesajlaşma.
/// ---------------------------------------------------------------------------

class NotificationRow {
  const NotificationRow({
    required this.id,
    required this.kind,
    required this.title,
    required this.createdAt,
    this.body,
    this.actorId,
    this.entityType,
    this.entityId,
    this.readAt,
  });

  final String id;
  final String kind; // like | comment | follow | application | offer | review
  final String title;
  final DateTime createdAt;
  final String? body;
  final String? actorId;
  final String? entityType;
  final String? entityId;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory NotificationRow.fromMap(Map<String, dynamic> m) => NotificationRow(
        id: m['id'] as String,
        kind: (m['kind'] as String?) ?? 'review',
        title: (m['title'] as String?) ?? '',
        body: m['body'] as String?,
        actorId: m['actor_id'] as String?,
        entityType: m['entity_type'] as String?,
        entityId: m['entity_id'] as String?,
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ??
            DateTime.now(),
        readAt: m['read_at'] == null
            ? null
            : DateTime.tryParse('${m['read_at']}')?.toLocal(),
      );
}

class ConversationRow {
  const ConversationRow({
    required this.otherId,
    required this.otherName,
    required this.lastBody,
    required this.lastAt,
    required this.unread,
    this.otherAvatarUrl,
  });

  final String otherId;
  final String otherName;
  final String lastBody;
  final DateTime lastAt;
  final int unread;
  final String? otherAvatarUrl;

  String get initials {
    final parts = otherName.trim().split(RegExp(r'\s+'));
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final res = '$a$b'.toUpperCase();
    return res.isEmpty ? '?' : res;
  }
}

class MessageRow {
  const MessageRow({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.isMine,
  });

  final String id;
  final String body;
  final DateTime createdAt;
  final bool isMine;
}


/// Velinin bir çocuğuna ait özet.
///
/// Veri modeli çoklu çocuğu zaten destekliyordu; eksik olan, çocukların farklı
/// kulüplerde olabildiği durumdu — uygulama tek "aktif kulüp" varsayıyordu.
class ChildOverview {
  const ChildOverview({
    required this.athleteId,
    required this.name,
    required this.attendanceRate,
    required this.openFeeCount,
    required this.openFeeTotal,
    required this.healthStatus,
    this.clubId,
    this.clubName,
    this.branch,
    this.nextEventAt,
    this.nextEvent,
  });

  final String athleteId;
  final String name;
  final int attendanceRate;
  final int openFeeCount;
  final num openFeeTotal;
  final String healthStatus;
  final String? clubId;
  final String? clubName;
  final String? branch;
  final DateTime? nextEventAt;
  final String? nextEvent;

  bool get hasDebt => openFeeCount > 0;
  bool get isInjured => healthStatus == 'injured';

  String get initials => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  factory ChildOverview.fromMap(Map<String, dynamic> m) => ChildOverview(
        athleteId: m['athlete_id'] as String,
        name: ((m['full_name'] as String?) ?? '').trim().isEmpty
            ? 'Sporcu'
            : (m['full_name'] as String).trim(),
        clubId: m['club_id'] as String?,
        clubName: m['club_name'] as String?,
        branch: m['branch'] as String?,
        attendanceRate: (m['attendance_rate'] as int?) ?? 0,
        openFeeCount: (m['open_fee_count'] as int?) ?? 0,
        openFeeTotal: (m['open_fee_total'] as num?) ?? 0,
        nextEventAt: m['next_event_at'] == null
            ? null
            : DateTime.tryParse('${m['next_event_at']}')?.toLocal(),
        nextEvent: m['next_event'] as String?,
        healthStatus: (m['health_status'] as String?) ?? 'fit',
      );
}

/// Bildirim kategorisi tercihi.
class NotificationPref {
  const NotificationPref({required this.category, required this.enabled});
  final String category;
  final bool enabled;

  String get label => switch (category) {
        'kritik' => 'Kritik',
        'kulup' => 'Kulüp',
        'antrenman' => 'Antrenman',
        'musabaka' => 'Müsabaka',
        'aidat' => 'Aidat',
        'federasyon' => 'Federasyon',
        _ => 'Sosyal',
      };

  String get hint => switch (category) {
        'kritik' => 'Onay sonuçları, belge süresi',
        'kulup' => 'Başvuru, teklif, bağış',
        'antrenman' => 'Yoklama hatırlatmaları',
        'musabaka' => 'Maç ve fikstür',
        'aidat' => 'Ödeme ve borç hatırlatmaları',
        'federasyon' => 'Resmî duyurular',
        _ => 'Beğeni, yorum, takip, mesaj',
      };
}

class NotificationService {
  NotificationService(this._c);
  final SupabaseClient _c;

  String? get _uid => _c.auth.currentUser?.id;

  // ----------------------------- bildirimler ---------------------------
  Future<List<NotificationRow>> list({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _c
        .from('notifications')
        .select('id, kind, title, body, actor_id, entity_type, entity_id, '
            'read_at, created_at')
        .eq('profile_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => NotificationRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  /// Zil rozeti — okunmamış bildirimler, **mesajlar hariç**.
  ///
  /// 0040'tan beri her doğrudan mesaj bir `notifications` satırı da üretiyor
  /// (`trg_notify_direct_message`). Mesajlar burada sayılsaydı aynı mesaj
  /// hem zilde hem mesaj ikonunda görünür, kullanıcı iki yerde okunmamış
  /// sanırdı. İki sayaç birbirini dışlıyor: mesajlar [unreadMessageCount].
  Future<int> unreadCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final rows = await _c
        .from('notifications')
        .select('id')
        .eq('profile_id', uid)
        .neq('kind', 'message')
        .isFilter('read_at', null);
    return (rows as List).length;
  }

  /// Mesaj rozeti — okunmamış doğrudan mesajlar.
  ///
  /// `notifications` yerine doğrudan `direct_messages` sayılıyor: sohbet
  /// okunduğunda `mark_conversation_read` bu tabloyu güncelliyor, bildirim
  /// satırını değil. Kaynak neyse sayaç orada olmalı.
  Future<int> unreadMessageCount() async {
    final uid = _uid;
    if (uid == null) return 0;
    final rows = await _c
        .from('direct_messages')
        .select('id')
        .eq('recipient_id', uid)
        .isFilter('read_at', null);
    return (rows as List).length;
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    await _c
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('profile_id', uid)
        .isFilter('read_at', null);
  }

  // ----------------------------- mesajlar ------------------------------

  /// Velinin çocuklarının özeti — her biri kendi kulübüyle.
  Future<List<ChildOverview>> childrenOverview() async {
    final rows = await _c.rpc<List<dynamic>>('my_children_overview');
    return rows
        .map((r) => ChildOverview.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<NotificationPref>> prefs() async {
    final rows = await _c.rpc<List<dynamic>>('my_notification_prefs');
    return rows.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return NotificationPref(
        category: (m['category'] as String?) ?? 'sosyal',
        enabled: (m['enabled'] as bool?) ?? true,
      );
    }).toList();
  }

  Future<void> setPref(String category, bool enabled) =>
      _c.rpc<void>('set_notification_pref',
          params: {'p_category': category, 'p_enabled': enabled});

  /// Kategoriye göre bildirimler (boş kategori = hepsi).
  Future<List<NotificationRow>> byCategory(String category) async {
    final rows = await _c.rpc<List<dynamic>>('my_notifications',
        params: {if (category.isNotEmpty) 'p_category': category});
    return rows
        .map((r) => NotificationRow.fromMap((r as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<ConversationRow>> conversations() async {
    final res = await _c.rpc<List<dynamic>>('my_conversations');
    return res.map((r) {
      final m = (r as Map).cast<String, dynamic>();
      final avatar = m['other_avatar'] as String?;
      return ConversationRow(
        otherId: m['other_id'] as String,
        otherName: ((m['other_name'] as String?) ?? '').trim().isEmpty
            ? 'Kullanıcı'
            : m['other_name'] as String,
        lastBody: (m['last_body'] as String?) ?? '',
        lastAt: DateTime.tryParse('${m['last_at']}')?.toLocal() ??
            DateTime.now(),
        unread: (m['unread'] as int?) ?? 0,
        otherAvatarUrl: (avatar == null || avatar.isEmpty)
            ? null
            : _c.storage.from('post-media').getPublicUrl(avatar),
      );
    }).toList();
  }

  Future<List<MessageRow>> messagesWith(String otherId) async {
    final uid = _uid;
    if (uid == null) return const [];
    final rows = await _c
        .from('direct_messages')
        .select('id, sender_id, body, created_at')
        .or('and(sender_id.eq.$uid,recipient_id.eq.$otherId),'
            'and(sender_id.eq.$otherId,recipient_id.eq.$uid)')
        .order('created_at');
    return (rows as List).map((r) {
      final m = (r as Map).cast<String, dynamic>();
      return MessageRow(
        id: m['id'] as String,
        body: (m['body'] as String?) ?? '',
        createdAt: DateTime.tryParse('${m['created_at']}')?.toLocal() ??
            DateTime.now(),
        isMine: m['sender_id'] == uid,
      );
    }).toList();
  }

  Future<void> send(String otherId, String body) async {
    final uid = _uid;
    if (uid == null || body.trim().isEmpty) return;
    await _c.from('direct_messages').insert({
      'sender_id': uid,
      'recipient_id': otherId,
      'body': body.trim(),
    });
  }

  Future<void> markConversationRead(String otherId) async {
    await _c.rpc<void>('mark_conversation_read', params: {'p_other': otherId});
  }
}

// =============================== Provider'lar ==============================

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.watch(supabaseClientProvider));
});

final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(notificationServiceProvider).list();
});

final unreadNotificationsProvider = FutureProvider.autoDispose<int>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(0);
  return ref.watch(notificationServiceProvider).unreadCount();
});

final unreadMessagesProvider = FutureProvider.autoDispose<int>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(0);
  return ref.watch(notificationServiceProvider).unreadMessageCount();
});


final childrenOverviewProvider =
    FutureProvider.autoDispose<List<ChildOverview>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <ChildOverview>[]);
  }
  return ref.watch(notificationServiceProvider).childrenOverview();
});

final notificationPrefsProvider =
    FutureProvider.autoDispose<List<NotificationPref>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <NotificationPref>[]);
  }
  return ref.watch(notificationServiceProvider).prefs();
});

/// Kategoriye göre bildirim listesi.
final categorizedNotificationsProvider = FutureProvider.autoDispose
    .family<List<NotificationRow>, String>((ref, category) {
  if (!ref.watch(isSupabaseEnabledProvider)) {
    return Future.value(const <NotificationRow>[]);
  }
  return ref.watch(notificationServiceProvider).byCategory(category);
});

final conversationsProvider =
    FutureProvider.autoDispose<List<ConversationRow>>((ref) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(notificationServiceProvider).conversations();
});

final messagesProvider =
    FutureProvider.autoDispose.family<List<MessageRow>, String>((ref, otherId) {
  if (!ref.watch(isSupabaseEnabledProvider)) return Future.value(const []);
  return ref.watch(notificationServiceProvider).messagesWith(otherId);
});
