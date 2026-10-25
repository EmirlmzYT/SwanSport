import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/action_gate.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_scaffold.dart';
import '../../social/presentation/widgets/social_widgets.dart';

class CommunityChatScreen extends ConsumerStatefulWidget {
  const CommunityChatScreen({
    required this.communityId,
    required this.title,
    super.key,
  });

  final String communityId;
  final String title;

  @override
  ConsumerState<CommunityChatScreen> createState() =>
      _CommunityChatScreenState();
}

class _CommunityChatScreenState extends ConsumerState<CommunityChatScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Future<void> _sendQueue = Future.value();
  bool _checkingSend = false;
  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref.read(communityServiceProvider).markRead(widget.communityId);
        if (mounted) ref.invalidate(communityListProvider);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_checkingSend || _ctrl.text.trim().isEmpty) return;
    _checkingSend = true;
    try {
      if (!await requireSwanAction(context, ref, SwanAction.message) ||
          !mounted) return;
      final text = _ctrl.text.trim();
      if (text.isEmpty) return;
      _ctrl.clear();
      _sendQueue = _sendQueue.then((_) async {
        try {
          await ref
              .read(communityServiceProvider)
              .send(widget.communityId, text);
          if (mounted) ref.invalidate(communityListProvider);
        } catch (_) {
          if (!mounted) return;
          _ctrl.text = _ctrl.text.isEmpty ? text : '$text\n${_ctrl.text}';
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Mesaj gönderilemedi. Metin geri getirildi.'),
          ));
        }
      });
    } finally {
      _checkingSend = false;
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
    });
  }

  Future<void> _leave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruptan çık'),
        content: Text('${widget.title} grubundan çıkmak istiyor musun?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Gruptan çık')),
        ],
      ),
    );
    if (leave != true) return;
    try {
      await ref.read(communityServiceProvider).leave(widget.communityId);
      ref.invalidate(communityListProvider);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gruptan çıkılamadı. Tekrar deneyin.')),
        );
      }
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 1));
    if (_sameDay(date, now)) return 'Bugün';
    if (_sameDay(date, yesterday)) return 'Dün';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final messages = ref.watch(communityMessagesProvider(widget.communityId));
    final members =
        ref.watch(communityMembersProvider(widget.communityId)).valueOrNull ??
            const <String, CommunityMember>{};

    return SwanScaffold(
      backgroundColor: c.surfaceAlt,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(children: [
              _header(c, members.length),
              Expanded(
                child: messages.when(
                  loading: premiumLoading,
                  error: (_, __) => Center(
                    child: TextButton.icon(
                      onPressed: () => ref.invalidate(
                          communityMessagesProvider(widget.communityId)),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Mesajları yeniden yükle'),
                    ),
                  ),
                  data: (list) {
                    final ordered = [...list]..sort((a, b) {
                        final byTime = a.createdAt.compareTo(b.createdAt);
                        return byTime != 0 ? byTime : a.id.compareTo(b.id);
                      });
                    if (ordered.length > _messageCount) _scrollToEnd();
                    _messageCount = ordered.length;
                    if (ordered.isEmpty) return _empty(c);
                    return ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                      itemCount: ordered.length,
                      itemBuilder: (context, index) {
                        final message = ordered[index];
                        final previous = index == 0 ? null : ordered[index - 1];
                        final compact = previous?.senderId ==
                                message.senderId &&
                            _sameDay(previous!.createdAt, message.createdAt);
                        final showDay = previous == null ||
                            !_sameDay(previous.createdAt, message.createdAt);
                        return Column(children: [
                          if (showDay) _dateChip(c, message.createdAt),
                          _bubble(c, message, members[message.senderId],
                              compact: compact),
                        ]);
                      },
                    );
                  },
                ),
              ),
              _composer(c),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _header(SwanPalette c, int memberCount) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.line))),
        child: Row(children: [
          IconButton(
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              tooltip: 'Geri'),
          CircleAvatar(
              radius: 20,
              backgroundColor: c.accent.withValues(alpha: .12),
              child: Icon(Icons.groups_rounded, color: c.accent)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SwanType.body(c.ink, w: FontWeight.w700)),
                Text(memberCount == 0 ? 'Grup sohbeti' : '$memberCount üye',
                    style: SwanType.caption(c.inkMuted)),
              ])),
          PopupMenuButton<String>(
            tooltip: 'Grup seçenekleri',
            onSelected: (value) {
              if (value == 'leave') _leave();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'leave', child: Text('Gruptan çık'))
            ],
          ),
        ]),
      );

  Widget _empty(SwanPalette c) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.forum_outlined, size: 42, color: c.accent),
        const SizedBox(height: 12),
        Text('Sohbeti başlat', style: SwanType.h3(c.ink)),
        const SizedBox(height: 5),
        Text('Takım arkadaşlarınla ilk mesajı paylaş.',
            style: SwanType.bodySm(c.inkMuted)),
      ]));

  Widget _dateChip(SwanPalette c, DateTime date) => Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
            color: c.surface, borderRadius: BorderRadius.circular(16)),
        child: Text(_dayLabel(date), style: SwanType.caption(c.inkMuted)),
      );

  Widget _bubble(
      SwanPalette c, CommunityMessageRow message, CommunityMember? sender,
      {required bool compact}) {
    return Padding(
      padding: EdgeInsets.only(top: compact ? 2 : 8),
      child: Row(
        mainAxisAlignment:
            message.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isMine) ...[
            SizedBox(
                width: 30,
                child: compact
                    ? null
                    : SocialAvatar(
                        initials: sender?.initials ?? '?',
                        size: 28,
                        gradientIndex: message.senderId.hashCode.abs() % 4)),
            const SizedBox(width: 7),
          ],
          Flexible(
              child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: message.isMine ? c.accentFill : c.surface,
              border: message.isMine ? null : Border.all(color: c.line),
              borderRadius: BorderRadius.circular(18),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!message.isMine && !compact) ...[
                Text(sender?.name ?? 'Üye',
                    style: SwanType.caption(c.accent, w: FontWeight.w800)),
                const SizedBox(height: 3),
              ],
              Text(message.body,
                  style: SwanType.bodySm(message.isMine ? c.onAccent : c.ink)
                      .copyWith(height: 1.35)),
              const SizedBox(height: 3),
              Text(
                  '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                  style: SwanType.caption(message.isMine
                      ? c.onAccent.withValues(alpha: .72)
                      : c.inkMuted)),
            ]),
          )),
        ],
      ),
    );
  }

  Widget _composer(SwanPalette c) => Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        decoration: BoxDecoration(
            color: c.surface, border: Border(top: BorderSide(color: c.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
              child: TextField(
            controller: _ctrl,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: 'Mesaj yaz…',
              filled: true,
              fillColor: c.surfaceAlt,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
            ),
          )),
          const SizedBox(width: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _ctrl,
            builder: (context, value, _) => IconButton.filled(
              tooltip: 'Gönder',
              onPressed: value.text.trim().isEmpty ? null : _send,
              icon: const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                  backgroundColor: c.accentFill, foregroundColor: c.onAccent),
            ),
          ),
        ]),
      );
}
