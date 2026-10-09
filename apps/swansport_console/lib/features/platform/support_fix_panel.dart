import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/modules/console_module.dart';

class SupportFixPanel extends ConsumerStatefulWidget {
  const SupportFixPanel({super.key, required this.ticketId});
  final String ticketId;
  @override
  ConsumerState<SupportFixPanel> createState() => _SupportFixPanelState();
}

class _SupportFixPanelState extends ConsumerState<SupportFixPanel> {
  final _issue = TextEditingController();
  bool _busy = false;
  @override
  void dispose() {
    _issue.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    if (_busy ||
        !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
            .hasMatch(_issue.text.trim())) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(diagnosticsServiceProvider)
          .linkIssue(widget.ticketId, _issue.text.trim());
      ref.invalidate(supportFixProvider(widget.ticketId));
      ref.invalidate(supportQueueProvider);
      ref.invalidate(ticketMessagesProvider(widget.ticketId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Hata bağlantısı kaydedilemedi. Kimliği ve açık talebi kontrol et.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _unlink(DiagnosticFixContext fix) async {
    final accepted = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Hata bağlantısını kaldır?'),
                  content: const Text(
                      'Önceki yazışmalar korunur. Bu düzeltmenin teyidi kapanır; açık talep yeniden incelemeye alınır.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Vazgeç')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Bağlantıyı kaldır'))
                  ],
                )) ??
        false;
    if (!accepted || !mounted || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(diagnosticsServiceProvider)
          .unlinkIssue(widget.ticketId, fix.issueId);
      ref.invalidate(supportFixProvider(widget.ticketId));
      ref.invalidate(supportQueueProvider);
      ref.invalidate(ticketMessagesProvider(widget.ticketId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bağlantı kaldırılamadı. Güncel talebi yenile.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(consoleAccessProvider).isPlatformAdmin) {
      return const SizedBox.shrink();
    }
    return ref.watch(supportFixProvider(widget.ticketId)).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => TextButton(
              onPressed: () =>
                  ref.invalidate(supportFixProvider(widget.ticketId)),
              child: const Text('Düzeltme takibini yeniden yükle')),
          data: (fix) {
            if (fix == null) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                        'Hata merkezindeki kaydı bu destek talebine bağla.'),
                    TextField(
                        controller: _issue,
                        decoration:
                            const InputDecoration(labelText: 'Hata kimliği'),
                        onChanged: (_) => setState(() {})),
                    TextButton(
                        onPressed: _busy ||
                                !RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
                                    .hasMatch(_issue.text.trim())
                            ? null
                            : _link,
                        child: const Text('Hataya bağla')),
                  ]);
            }
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText('Bağlı hata: ${fix.issueId}'),
                  TextButton(
                      onPressed: _busy ? null : () => _unlink(fix),
                      child: const Text('Hata bağlantısını kaldır')),
                  Text(fix.fixId == null
                      ? 'Düzeltme sürümü bekleniyor.'
                      : 'Düzeltme: ${fix.release} · ${fix.platform}'),
                  Text(switch (fix.response) {
                    'confirmed' => 'Kullanıcı çözümü teyit etti.',
                    'still_failing' => 'Kullanıcı sorunun sürdüğünü bildirdi.',
                    _ => 'Kullanıcı teyidi bekleniyor.'
                  }),
                  if (fix.fixId != null)
                    Text(
                        '${fix.regressionCount} teknik tekrar; hata durumu: ${fix.issueState}'),
                  TextButton(
                      onPressed: () =>
                          ref.invalidate(supportFixProvider(widget.ticketId)),
                      child: const Text('Teyit durumunu yenile')),
                ]);
          },
        );
  }
}
