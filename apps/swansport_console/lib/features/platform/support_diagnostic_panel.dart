import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

final supportDiagnosticProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, ticket) {
  if (!ref.watch(isSupabaseEnabledProvider)) return null;
  return ref.watch(diagnosticsServiceProvider).ticketDiagnostics(ticket);
});
final diagnosticScreenshotProvider = FutureProvider.autoDispose
    .family<String, String>((ref, path) =>
        ref.watch(diagnosticsServiceProvider).screenshotUrl(path));

class SupportDiagnosticPanel extends ConsumerWidget {
  const SupportDiagnosticPanel({super.key, required this.ticketId});
  final String ticketId;
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ref.watch(supportDiagnosticProvider(ticketId)).when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => const Text('Teknik ekler alınamadı.'),
          data: (data) {
            if (data == null) return const SizedBox.shrink();
            final path = data['attachment_path'] as String?;
            return ExpansionTile(
                title: const Text('Kullanıcının paylaştığı teknik bilgiler'),
                children: [
                  SelectableText(const JsonEncoder.withIndent('  ')
                      .convert(data['snapshot'])),
                  if (path != null)
                    ref.watch(diagnosticScreenshotProvider(path)).when(
                        loading: () => const CircularProgressIndicator(),
                        error: (_, __) => TextButton(
                            onPressed: () => ref
                                .invalidate(diagnosticScreenshotProvider(path)),
                            child: const Text('Görseli tekrar yükle')),
                        data: (url) => Image.network(url,
                            height: 300,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => TextButton(
                                onPressed: () => ref.invalidate(
                                    diagnosticScreenshotProvider(path)),
                                child:
                                    const Text('Görsel bağlantısını yenile'))))
                ]);
          });
}
