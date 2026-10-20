import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_scope.dart';

class AnnouncementDetail {
  const AnnouncementDetail(
      {required this.id,
      required this.title,
      required this.body,
      required this.version,
      this.readAt,
      this.acknowledgedAt,
      this.readCount,
      this.acknowledgedCount});
  final String id, title, body, version;
  final DateTime? readAt, acknowledgedAt;
  final int? readCount, acknowledgedCount;
  factory AnnouncementDetail.fromMap(Map<String, dynamic> m) =>
      AnnouncementDetail(
          id: m['id'] as String,
          title: m['title'] as String,
          body: m['body'] as String,
          version: m['version'] as String,
          readAt: DateTime.tryParse('${m['read_at']}'),
          acknowledgedAt: DateTime.tryParse('${m['acknowledged_at']}'),
          readCount: (m['read_count'] as num?)?.toInt(),
          acknowledgedCount: (m['acknowledged_count'] as num?)?.toInt());
}

class AnnouncementReceiptService {
  AnnouncementReceiptService(this._client);
  final SupabaseClient _client;
  Future<AnnouncementDetail> load(String id) async =>
      AnnouncementDetail.fromMap(Map<String, dynamic>.from(await _client
          .rpc<Map<String, dynamic>>('announcement_detail',
              params: {'p_id': id})));
  Future<AnnouncementDetail> record(AnnouncementDetail detail,
          {required bool acknowledge}) async =>
      AnnouncementDetail.fromMap(Map<String, dynamic>.from(await _client
          .rpc<Map<String, dynamic>>('record_announcement_receipt', params: {
        'p_id': detail.id,
        'p_version': detail.version,
        'p_acknowledge': acknowledge
      })));
}

final announcementReceiptServiceProvider = Provider<AnnouncementReceiptService>(
    (ref) => AnnouncementReceiptService(ref.watch(supabaseClientProvider)));
