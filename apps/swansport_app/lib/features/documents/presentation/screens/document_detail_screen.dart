import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../routing/document_detail_route_args.dart';

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({required this.args, super.key});
  const DocumentDetailScreen.invalidRoute({super.key}) : args = null;
  final DocumentDetailRouteArgs? args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Belge Ayrıntısı')),
      body: args == null
          ? const Center(
              child: Text('Geçersiz belge bağlantısı.',
                  key: Key('document-invalid-route')))
          : ref.watch(vaultDocsProvider).when(
                loading: premiumLoading,
                error: (e, _) => premiumError(context, '$e'),
                data: (docs) {
                  VaultDoc? doc;
                  for (final d in docs) {
                    if (d.id == args!.documentId.value) doc = d;
                  }
                  if (doc == null)
                    return const Center(
                        child: Text('Belge bulunamadı.',
                            key: Key('document-not-found')));
                  final d = doc;
                  return ListView(
                      padding: const EdgeInsets.all(SwanSpace.lg),
                      children: [
                        Text(d.name,
                            key: const Key('document-detail-title'),
                            style: SwanType.h2(c.ink)),
                        const SizedBox(height: SwanSpace.md),
                        Text(d.typeLabel, style: SwanType.body(c.ink)),
                        Text('Sahip: ${d.ownerLabel}',
                            style: SwanType.bodySm(c.inkMuted)),
                        Text('Durum: ${d.state}',
                            style: SwanType.bodySm(c.inkMuted)),
                        Text(d.verified ? 'Doğrulanmış' : 'Doğrulanmamış',
                            style: SwanType.bodySm(c.inkMuted)),
                        if (d.storagePath != null) ...[
                          const SizedBox(height: SwanSpace.lg),
                          FilledButton.icon(
                              onPressed: () => _open(context, ref, d),
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('Dosyayı aç')),
                        ],
                      ]);
                },
              ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, VaultDoc doc) async {
    try {
      final url =
          await ref.read(vaultServiceProvider).signedUrl(doc.storagePath!);
      if (!await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication)) {
        throw StateError('Dosya bağlantısı açılamadı.');
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Dosya açılamadı: $e')));
    }
  }
}
