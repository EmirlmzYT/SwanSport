import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';

/// UI-only adapter. Domain and wire models remain unchanged.
class ChatItem {
  const ChatItem(
      {required this.message,
      required this.senderId,
      this.senderName,
      this.avatarUrl});
  final MessageRow message;
  final String senderId;
  final String? senderName;
  final String? avatarUrl;
}

List<ChatItem> orderedChatItems(Iterable<ChatItem> items) {
  final unique = <String, ChatItem>{
    for (final item in items) item.message.id: item
  };
  return unique.values.toList()
    ..sort((a, b) {
      final at = a.message.createdAt.compareTo(b.message.createdAt);
      return at == 0 ? a.message.id.compareTo(b.message.id) : at;
    });
}

bool sameChatDay(DateTime a, DateTime b) {
  a = a.toLocal();
  b = b.toLocal();
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool groupsWith(ChatItem previous, ChatItem current) =>
    previous.senderId == current.senderId &&
    !previous.message.isShare &&
    !current.message.isShare &&
    sameChatDay(previous.message.createdAt, current.message.createdAt) &&
    current.message.createdAt.difference(previous.message.createdAt) >=
        Duration.zero &&
    current.message.createdAt.difference(previous.message.createdAt) <=
        const Duration(minutes: 5);

String chatDayLabel(DateTime at, {DateTime? now}) {
  final local = at.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  if (sameChatDay(local, today)) return 'Bugün';
  if (sameChatDay(local, DateTime(today.year, today.month, today.day - 1)))
    return 'Dün';
  const months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık'
  ];
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}

String chatTime(DateTime at) {
  final local = at.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String chatStatus(MessageRow message) => switch (message.status) {
      MessageStatus.sending => 'Gönderiliyor',
      MessageStatus.failed => 'Gönderilemedi',
      MessageStatus.sent => message.isRead ? 'Okundu' : 'Gönderildi',
    };

/// Preserve UTF-16 offsets even if a Unicode lower-case mapping expands.
List<(int, int)> chatMatchRanges(String body, String query) {
  if (query.trim().isEmpty) return const [];
  final folded = StringBuffer();
  final starts = <int>[];
  final ends = <int>[];
  var offset = 0;
  for (final rune in body.runes) {
    final original = String.fromCharCode(rune);
    final normalized = trFold(original);
    folded.write(normalized);
    for (var i = 0; i < normalized.length; i++) {
      starts.add(offset);
      ends.add(offset + original.length);
    }
    offset += original.length;
  }
  final needle = trFold(query.trim());
  final text = folded.toString();
  final result = <(int, int)>[];
  var from = 0;
  while (from < text.length) {
    final index = text.indexOf(needle, from);
    if (index < 0) break;
    result.add((starts[index], ends[index + needle.length - 1]));
    from = index + needle.length;
  }
  return result;
}
