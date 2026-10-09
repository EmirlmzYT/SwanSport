import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_page_header.dart';
import '../../documents/presentation/screens/document_vault_screen.dart';
import '../../support/presentation/support_screen.dart';

/// Keep the legacy route /veli-izinleri; RSVP is not a legal consent.
class ParentConsentCenterScreen extends ConsumerStatefulWidget {
  const ParentConsentCenterScreen({super.key});
  @override
  ConsumerState<ParentConsentCenterScreen> createState() =>
      _ParentConsentCenterScreenState();
}

class _ParentConsentCenterScreenState
    extends ConsumerState<ParentConsentCenterScreen> {
  String? _childId;
  String? _busy;
  Future<void> _refresh() async {
    ref.invalidate(parentActionsProvider);
    try {
      await ref.read(parentActionsProvider.future);
    } catch (_) {/* error is displayed by the provider */}
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final enabled = ref.watch(featureEnabledProvider(FeatureFlags.parentHub));
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                SwanPageHeader(
                  title: 'Veli İşlem Merkezi',
                  onBack: () => Navigator.maybePop(context),
                ),
                Expanded(
                  child: !enabled
                      ? Center(
                          child: Text(
                            'Bu özellik şu anda hesabına açık değil.',
                            style: SwanType.body(c.inkMuted),
                          ),
                        )
                      : ref.watch(parentActionsProvider).when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (_, __) => Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'İşler yüklenemedi.',
                                    style: SwanType.body(c.ink),
                                  ),
                                  TextButton(
                                    onPressed: _refresh,
                                    child: const Text('Tekrar dene'),
                                  ),
                                ],
                              ),
                            ),
                            data: (data) => RefreshIndicator(
                              onRefresh: _refresh,
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.all(
                                  SwanSpace.lg,
                                ),
                                children: _content(data, c),
                              ),
                            ),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(ParentActions data, SwanPalette c) {
    if (data.children.isEmpty) {
      return [
        Text('Henüz bağlı çocuğun yok.', style: SwanType.h3(c.ink)),
        TextButton(
          onPressed: () async {
            await Navigator.pushNamed(context, '/veli-bagla');
            if (mounted) await _refresh();
          },
          child: const Text('Davet koduyla çocuk bağla'),
        ),
      ];
    }
    final selected =
        data.children.any((child) => child.id == _childId) ? _childId : null;
    final events = data.events
        .where((e) => selected == null || e.childId == selected)
        .toList();
    final documents = data.documents
        .where((d) => selected == null || d.ownerId == selected)
        .toList();
    return [
      Text(
        'Etkinlik yanıtları, belge tarihleri ve kendi destek taleplerin.',
        style: SwanType.body(c.inkMuted),
      ),
      const SizedBox(height: SwanSpace.md),
      DropdownButtonFormField<String>(
        key: ValueKey(selected),
        initialValue: selected ?? '',
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Çocuk'),
        items: [
          const DropdownMenuItem(value: '', child: Text('Tüm çocuklar')),
          for (final child in data.children)
            DropdownMenuItem(
              value: child.id,
              child: Text(
                '${child.name} · ${child.clubName}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: (v) => setState(() => _childId = v == '' ? null : v),
      ),
      const SizedBox(height: SwanSpace.lg),
      if (events.isEmpty && documents.isEmpty && data.tickets.isEmpty)
        Text('Şu anda işlem bekleyen iş yok.', style: SwanType.body(c.ink)),
      if (events.isNotEmpty) ...[
        Text(
          'Etkinlik yanıtları (${events.length})',
          style: SwanType.h3(c.ink),
        ),
        Text(
          'Önümüzdeki 60 gün. Katılım yanıtı yoklama veya hukuki izin değildir.',
          style: SwanType.caption(c.inkMuted),
        ),
        for (final event in events) _event(event, c),
      ],
      if (documents.isNotEmpty) ...[
        const SizedBox(height: SwanSpace.lg),
        Text(
          'Belge uyarıları (${documents.length})',
          style: SwanType.h3(c.ink),
        ),
        Text(
          'Süresi dolan veya 30 gün içinde dolacak belgeler.',
          style: SwanType.caption(c.inkMuted),
        ),
        for (final doc in documents)
          _box(
            c,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.name, style: SwanType.body(c.ink, w: FontWeight.w700)),
                Text(
                  '${doc.ownerName} · ${doc.state} · ${_date(doc.expiresOn!)}',
                  style: SwanType.caption(c.inkMuted),
                ),
                TextButton(
                  onPressed: () async {
                    final child = data.children
                        .firstWhere((child) => child.id == doc.ownerId);
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: '/documents'),
                        builder: (_) => DocumentVaultScreen(child: child),
                      ),
                    );
                    if (mounted) await _refresh();
                  },
                  child: const Text('Çocuğun belgelerini aç'),
                ),
              ],
            ),
          ),
      ],
      if (data.tickets.isNotEmpty) ...[
        const SizedBox(height: SwanSpace.lg),
        Text(
          'Kendi destek yanıtların (${data.tickets.length})',
          style: SwanType.h3(c.ink),
        ),
        for (final ticket in data.tickets)
          _box(
            c,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ticket.subject,
                  style: SwanType.body(c.ink, w: FontWeight.w700),
                ),
                Text(
                  'SwanSport ekibi yanıtını bekliyor.',
                  style: SwanType.caption(c.inkMuted),
                ),
                TextButton(
                  onPressed: () => _openTicket(ticket),
                  child: const Text('Talebi aç ve yanıtla'),
                ),
              ],
            ),
          ),
      ],
      const SizedBox(height: SwanSpace.lg),
      TextButton(
        onPressed: () async {
          await Navigator.pushNamed(context, '/veli-bagla');
          if (mounted) await _refresh();
        },
        child: const Text('Başka çocuk bağla'),
      ),
    ];
  }

  Widget _box(SwanPalette c, Widget child) => Container(
        margin: const EdgeInsets.only(top: SwanSpace.md),
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: c.line),
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: child,
      );
  Widget _event(GuardianEventAction e, SwanPalette c) => _box(
        c,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.title, style: SwanType.body(c.ink, w: FontWeight.w700)),
            Text(
              '${e.childName} · ${e.clubName}',
              style: SwanType.caption(c.inkMuted),
            ),
            Text(
              '${_date(e.startsAt)} ${e.startsAt.hour.toString().padLeft(2, '0')}:${e.startsAt.minute.toString().padLeft(2, '0')}${e.place == null ? '' : ' · ${e.place}'}',
              style: SwanType.bodySm(c.inkMuted),
            ),
            Text(
              e.response == 'uncertain'
                  ? 'Önceki yanıt: Belirsiz'
                  : 'Henüz yanıt verilmedi',
              style: SwanType.caption(c.inkMuted),
            ),
            Wrap(
              spacing: SwanSpace.sm,
              children: [
                for (final entry in const {
                  'attending': 'Katılacak',
                  'unavailable': 'Katılamayacak',
                  'uncertain': 'Belirsiz',
                }.entries)
                  TextButton(
                    onPressed:
                        _busy != null ? null : () => _respond(e, entry.key),
                    child: Text(entry.value),
                  ),
              ],
            ),
            if (_busy == '${e.id}:${e.childId}')
              const LinearProgressIndicator(),
          ],
        ),
      );
  Future<void> _respond(GuardianEventAction event, String status) async {
    setState(() => _busy = '${event.id}:${event.childId}');
    try {
      await ref.read(parentActionServiceProvider).respond(event, status);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Katılım yanıtı kaydedildi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Yanıt kaydedilemedi. Listeyi yenileyip kontrol et. $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = null);
        await _refresh();
      }
    }
  }

  Future<void> _openTicket(SupportTicket ticket) async {
    final subscription = ref.listenManual(myTicketsProvider, (_, __) {});
    try {
      ref.invalidate(myTicketsProvider);
      final tickets = await ref.read(myTicketsProvider.future);
      final current = tickets.where((t) => t.id == ticket.id).firstOrNull;
      if (!mounted) return;
      if (current == null) {
        await _refresh();
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/destek'),
          builder: (_) => TicketThreadScreen(ticket: current),
        ),
      );
      if (mounted) await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talep açılamadı. Tekrar dene.')),
        );
      }
    } finally {
      subscription.close();
    }
  }

  String _date(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}
