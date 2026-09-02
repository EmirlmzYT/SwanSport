import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../finance/work_queue.dart';

/// Destek kuyruğu — platform yöneticisi.
///
/// **Sıralama bilerek en eski önce.** Açık talepler üstte, içlerinde en eski
/// başta: en uzun bekleyen kişi en çok hak edendir. Yeniden eskiye sıralamak
/// eski talepleri kuyruğun dibinde unutturuyordu.
///
/// Gövde ve yanıtlar sunucuda ayıklanmış geliyor (token, IBAN, uzun rakam).
class ConsoleSupportScreen extends ConsumerStatefulWidget {
  const ConsoleSupportScreen({super.key});

  @override
  ConsumerState<ConsoleSupportScreen> createState() =>
      _ConsoleSupportScreenState();
}

class _ConsoleSupportScreenState extends ConsumerState<ConsoleSupportScreen> {
  String _status = 'all';
  SupportQueueItem? _selected;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final queue = ref.watch(supportQueueProvider(_status));

    return ListView(
      padding: const EdgeInsets.all(ConsoleDensity.xl),
      children: [
        const ConsolePageHeader(
          title: 'Destek',
          subtitle: 'Kullanıcı talepleri. En uzun bekleyen üstte — yeniden '
              'eskiye sıralamak eskileri kuyruğun dibinde unutturuyordu.',
        ),
        const SizedBox(height: ConsoleDensity.lg),

        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'all', label: Text('Tümü')),
            ButtonSegment(value: 'new', label: Text('Yeni')),
            ButtonSegment(
                value: 'under_review', label: Text('İnceleniyor')),
            ButtonSegment(
                value: 'awaiting_user_response', label: Text('Yanıt bekliyor')),
          ],
          selected: {_status},
          onSelectionChanged: (s) =>
              setState(() { _status = s.first; _selected = null; }),
        ),
        const SizedBox(height: ConsoleDensity.lg),

        AsyncSection<List<SupportQueueItem>>(
          value: queue,
          errorPrefix: 'Destek kuyruğu alınamadı',
          builder: (list) => list.isEmpty
              ? Text('Bu süzgeçte talep yok.', style: t.textTheme.bodySmall)
              : Column(
                  children: [
                    for (final q in list)
                      _QueueRow(
                        item: q,
                        expanded: _selected?.ticketId == q.ticketId,
                        onTap: () => setState(() =>
                            _selected = _selected?.ticketId == q.ticketId
                                ? null
                                : q),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _QueueRow extends ConsumerStatefulWidget {
  const _QueueRow({
    required this.item,
    required this.expanded,
    required this.onTap,
  });

  final SupportQueueItem item;
  final bool expanded;
  final VoidCallback onTap;

  @override
  ConsumerState<_QueueRow> createState() => _QueueRowState();
}

class _QueueRowState extends ConsumerState<_QueueRow> {
  final _reply = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(clubLifecycleServiceProvider)
          .replyTicket(widget.item.ticketId, text);
      _reply.clear();
      ref.invalidate(ticketMessagesProvider(widget.item.ticketId));
      ref.invalidate(supportQueueProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(String s) async {
    try {
      await ref
          .read(clubLifecycleServiceProvider)
          .setTicketStatus(widget.item.ticketId, s);
      ref.invalidate(supportQueueProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final q = widget.item;
    final age = q.ageInDays(DateTime.now());

    // Yanıtlanmamış ve beklemiş talep kritik. Renk tek başına bilgi
    // taşımıyor: yaş ve durum metni de yazılı.
    final urgent = q.unanswered && age >= 2;

    return Container(
      margin: const EdgeInsets.only(bottom: ConsoleDensity.sm),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
        border: Border.all(
            color: urgent
                ? t.colorScheme.error.withValues(alpha: 0.4)
                : t.colorScheme.outlineVariant),
      ),
      child: Column(children: [
        InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(ConsoleDensity.radius),
          child: Padding(
            padding: const EdgeInsets.all(ConsoleDensity.lg),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.subject, style: t.textTheme.titleSmall),
                    Text(
                      [
                        q.requester,
                        if (q.clubName != null) q.clubName!,
                        age == 0 ? 'bugün' : '$age gün önce',
                        '${q.messageCount} yanıt',
                      ].join(' · '),
                      style: t.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (urgent)
                Padding(
                  padding: const EdgeInsets.only(right: ConsoleDensity.sm),
                  child: Text('Yanıtlanmadı',
                      style: t.textTheme.labelSmall
                          ?.copyWith(color: t.colorScheme.error)),
                ),
              Text(_label(q.status), style: t.textTheme.labelMedium),
              const SizedBox(width: ConsoleDensity.sm),
              Icon(
                  widget.expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18),
            ]),
          ),
        ),
        if (widget.expanded) _thread(context, t, q),
      ]),
    );
  }

  Widget _thread(BuildContext context, ThemeData t, SupportQueueItem q) {
    final msgs = ref.watch(ticketMessagesProvider(q.ticketId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(ConsoleDensity.lg, 0,
          ConsoleDensity.lg, ConsoleDensity.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Divider(height: ConsoleDensity.lg),
        AsyncSection<List<SupportMessage>>(
          value: msgs,
          errorPrefix: 'Yazışma alınamadı',
          builder: (list) => list.isEmpty
              ? Text('Henüz yanıt yok.', style: t.textTheme.bodySmall)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final m in list)
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: ConsoleDensity.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 88,
                              child: Text(m.isStaff ? 'Ekip' : 'Kullanıcı',
                                  style: t.textTheme.labelSmall?.copyWith(
                                      color: m.isStaff
                                          ? t.colorScheme.primary
                                          : t.colorScheme.onSurfaceVariant)),
                            ),
                            Expanded(
                                child: Text(m.body,
                                    style: t.textTheme.bodySmall)),
                            Text(fmtDate(m.createdAt),
                                style: t.textTheme.labelSmall),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: ConsoleDensity.md),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _reply,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Yanıt yaz…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: ConsoleDensity.sm),
          if (_busy)
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            FilledButton(onPressed: _send, child: const Text('Gönder')),
        ]),
        const SizedBox(height: ConsoleDensity.sm),
        Row(children: [
          TextButton(
              onPressed: () => _setStatus('under_review'),
              child: const Text('İncelemeye al')),
          TextButton(
              onPressed: () => _setStatus('resolved'),
              child: const Text('Çözüldü')),
          TextButton(
              onPressed: () => _setStatus('closed'),
              child: const Text('Kapat')),
        ]),
      ]),
    );
  }

  String _label(String s) => switch (s) {
        'new' => 'Yeni',
        'under_review' => 'İnceleniyor',
        'awaiting_user_response' => 'Yanıt bekliyor',
        'resolved' => 'Çözüldü',
        'closed' => 'Kapandı',
        _ => s,
      };
}
