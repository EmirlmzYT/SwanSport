import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Destek taleplerim.
///
/// Talep gövdesi ve otomatik bağlam **sunucuda ayıklanıyor**: token, şifre,
/// IBAN ve uzun rakam dizileri temizleniyor. İstemcide de temizlemek
/// mümkündü ama son savunma sunucuda, çünkü eski bir uygulama sürümü ham
/// veri gönderebilir.
class SupportScreen extends ConsumerWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final tickets = ref.watch(myTicketsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: c.accentFill,
        onPressed: () => _newTicket(context, ref),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: Text('Yeni talep',
            style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
      ),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.md,
                    SwanSpace.lg, SwanSpace.md),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                          border: Border.all(color: c.line)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: c.ink),
                    ),
                  ),
                  const SizedBox(width: SwanSpace.md),
                  Text('Destek', style: SwanType.h2(c.ink)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/yardim'),
                    child: Text('SSS',
                        style: SwanType.bodySm(c.accent, w: FontWeight.w800)),
                  ),
                ]),
              ),
              Expanded(
                child: tickets.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (list) => list.isEmpty
                      ? premiumEmpty(
                          context,
                          icon: Icons.support_agent_rounded,
                          title: 'Destek talebin yok',
                          subtitle: 'Bir sorunla karşılaşırsan buradan yaz. '
                              'Önce SSS\'ye bakmanı öneririz — çoğu sorunun '
                              'cevabı orada.',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                              SwanSpace.lg, 0, SwanSpace.lg, 132),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _TicketTile(t: list[i]),
                        ),
                ),
              ),
            ]),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.t});

  final SupportTicket t;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;

    // Renk tek başına bilgi taşımıyor: durum metni de yazılı.
    final tone = switch (t.status) {
      'resolved' || 'closed' => c.inkMuted,
      'awaiting_user_response' => c.warning,
      _ => c.accent,
    };

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => TicketThreadScreen(ticket: t)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: SwanSpace.sm),
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          border: Border.all(color: c.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(t.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
            ),
            const SizedBox(width: SwanSpace.sm),
            Text(t.statusLabel, style: SwanType.caption(tone)),
          ]),
          const SizedBox(height: 2),
          Text(fmtDate(t.createdAt), style: SwanType.caption(c.inkMuted)),
        ]),
      ),
    );
  }
}

/// Tek talebin yazışması.
class TicketThreadScreen extends ConsumerStatefulWidget {
  const TicketThreadScreen({super.key, required this.ticket});

  final SupportTicket ticket;

  @override
  ConsumerState<TicketThreadScreen> createState() =>
      _TicketThreadScreenState();
}

class _TicketThreadScreenState extends ConsumerState<TicketThreadScreen> {
  final _body = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _body.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(clubLifecycleServiceProvider)
          .replyTicket(widget.ticket.id, text);
      _body.clear();
      ref.invalidate(ticketMessagesProvider(widget.ticket.id));
      ref.invalidate(myTicketsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final msgs = ref.watch(ticketMessagesProvider(widget.ticket.id));
    final closed = widget.ticket.status == 'closed';

    return Scaffold(
      backgroundColor: c.bg,
      // Klavye dolgusu Scaffold'a bırakılıyor; `viewInsets` eklemek aynı
      // boşluğu iki kez sayardı (AGENTS.md'deki sohbet tuzağı).
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(SwanSpace.lg),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                          border: Border.all(color: c.line)),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 15, color: c.ink),
                    ),
                  ),
                  const SizedBox(width: SwanSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.ticket.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.bodySm(c.ink, w: FontWeight.w800)),
                        Text(widget.ticket.statusLabel,
                            style: SwanType.caption(c.inkMuted)),
                      ],
                    ),
                  ),
                  if (!closed)
                    GestureDetector(
                      onTap: _close,
                      child: Text('Kapat',
                          style: SwanType.caption(c.inkMuted,
                              w: FontWeight.w700)),
                    ),
                ]),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      SwanSpace.lg, 0, SwanSpace.lg, SwanSpace.lg),
                  children: [
                    // İlk mesaj talebin kendi gövdesi.
                    if ((widget.ticket.body ?? '').isNotEmpty)
                      _bubble(c, widget.ticket.body!, false,
                          widget.ticket.createdAt),
                    ...msgs.maybeWhen(
                      orElse: () => <Widget>[],
                      data: (list) => [
                        for (final m in list)
                          _bubble(c, m.body, m.isStaff, m.createdAt),
                      ],
                    ),
                  ],
                ),
              ),
              if (closed)
                Padding(
                  padding: const EdgeInsets.all(SwanSpace.lg),
                  child: Text('Bu talep kapatıldı.',
                      style: SwanType.caption(c.inkMuted)),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(SwanSpace.lg, 0,
                      SwanSpace.lg, SwanSpace.lg),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _body,
                        minLines: 1,
                        maxLines: 4,
                        style: SwanType.bodySm(c.ink),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Yanıt yaz…',
                          hintStyle: SwanType.bodySm(c.inkMuted),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(SwanRadius.sm),
                            borderSide: BorderSide(color: c.line),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: SwanSpace.sm),
                    GestureDetector(
                      onTap: _busy ? null : _send,
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.accentFill,
                          borderRadius: BorderRadius.circular(SwanRadius.sm),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded,
                                size: 18, color: Colors.white),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _close() async {
    try {
      await ref
          .read(clubLifecycleServiceProvider)
          .setTicketStatus(widget.ticket.id, 'closed');
      ref.invalidate(myTicketsProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _bubble(SwanPalette c, String body, bool isStaff, DateTime at) =>
      Align(
        alignment: isStaff ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.only(bottom: SwanSpace.sm),
          padding: const EdgeInsets.all(SwanSpace.md),
          decoration: BoxDecoration(
            color: isStaff ? c.surface : c.accentFill,
            borderRadius: BorderRadius.circular(SwanRadius.md),
            border: isStaff ? Border.all(color: c.line) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isStaff)
                Text('SwanSport ekibi',
                    style: SwanType.caption(c.accent, w: FontWeight.w800)),
              Text(body,
                  style: SwanType.bodySm(isStaff ? c.ink : Colors.white)
                      .copyWith(height: 1.4)),
              const SizedBox(height: 2),
              Text(fmtDate(at),
                  style: SwanType.caption(
                      isStaff ? c.inkMuted : Colors.white70)),
            ],
          ),
        ),
      );
}

/// Yeni talep sayfası.
///
/// Otomatik bağlam eklenir: uygulama sürümü ve platform. Kullanıcıdan
/// istemek yerine toplamak, "hangi sürümü kullanıyorsun" diye sorup
/// bekleme turunu ortadan kaldırıyor. İçerik sunucuda ayıklanıyor.
Future<void> _newTicket(BuildContext context, WidgetRef ref) async {
  final subject = TextEditingController();
  final body = TextEditingController();

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final c = ctx.swan;
      return Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(SwanSpace.lg),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text('Yeni destek talebi', style: SwanType.h3(c.ink)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, true),
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(
                        horizontal: SwanSpace.lg),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c.accentFill,
                      borderRadius: BorderRadius.circular(SwanRadius.sm),
                    ),
                    child: Text('Gönder',
                        style: SwanType.caption(Colors.white,
                            w: FontWeight.w800)),
                  ),
                ),
              ]),
              const SizedBox(height: SwanSpace.md),
              TextField(
                controller: subject,
                autofocus: true,
                style: SwanType.bodySm(c.ink),
                decoration: InputDecoration(
                  labelText: 'Konu',
                  hintText: 'Aidatım görünmüyor',
                  labelStyle: SwanType.caption(c.inkMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                    borderSide: BorderSide(color: c.line),
                  ),
                ),
              ),
              const SizedBox(height: SwanSpace.md),
              TextField(
                controller: body,
                minLines: 4,
                maxLines: 8,
                style: SwanType.bodySm(c.ink),
                decoration: InputDecoration(
                  labelText: 'Ne oldu?',
                  hintText: 'Ne yaptın, ne bekliyordun, ne oldu?',
                  labelStyle: SwanType.caption(c.inkMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                    borderSide: BorderSide(color: c.line),
                  ),
                ),
              ),
              const SizedBox(height: SwanSpace.sm),
              Text(
                'Şifre, kart numarası ve IBAN yazma — yazsan bile sunucuda '
                'otomatik ayıklanıyor.',
                style: SwanType.caption(c.inkMuted),
              ),
            ]),
          ),
        ),
      );
    },
  );

  if (ok != true) return;
  if (subject.text.trim().isEmpty || body.text.trim().isEmpty) return;

  final club = await ref.read(activeClubProvider.future);
  try {
    await ref.read(clubLifecycleServiceProvider).openTicket(
          subject: subject.text.trim(),
          body: body.text.trim(),
          clubId: club?.id,
          context: {
            'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
            'screen': '/destek',
          },
        );
    ref.invalidate(myTicketsProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Talebin alındı')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
