import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../application/document_detail_controller.dart';
import '../../domain/models/document_vault.dart';
import '../routing/document_detail_route_args.dart';

class DocumentDetailScreen extends ConsumerWidget {
  const DocumentDetailScreen({required this.args, super.key});
  const DocumentDetailScreen.invalidRoute({super.key}) : args = null;
  final DocumentDetailRouteArgs? args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (args == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Geçersiz belge bağlantısı.',
            key: Key('document-invalid-route'),
          ),
        ),
      );
    }
    final state = ref.watch(documentDetailControllerProvider(args!.documentId));
    return Scaffold(
      appBar: AppBar(title: const Text('Belge Ayrıntısı')),
      body: switch (state.status) {
        DocumentDetailStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        DocumentDetailStatus.notFound => const Center(
            child: Text('Belge bulunamadı.', key: Key('document-not-found')),
          ),
        DocumentDetailStatus.permissionDenied =>
          const Center(child: Text('Bu belgeyi görüntüleme yetkiniz yok.')),
        DocumentDetailStatus.unavailable =>
          const Center(child: Text('Bu belge artık kullanılamıyor.')),
        DocumentDetailStatus.loaded =>
          _Detail(document: state.document!, permissions: state.permissions),
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.document, required this.permissions});
  final VaultDocument document;
  final DocumentPermissionSet permissions;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text(document.category.name)),
                  Chip(label: Text(document.status.name)),
                  if (document.isPinned) const Chip(label: Text('Sabitlendi')),
                  if (document.isFavorite) const Chip(label: Text('Favori')),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                document.filename,
                key: const Key('document-detail-title'),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text('Sahip: ${document.owner}'),
              Text('Yükleyen: ${document.uploader}'),
              Text(
                'Sporcu: ${document.athlete.isEmpty ? "—" : document.athlete}',
              ),
              Text('Takım: ${document.team} • Sezon: ${document.season}'),
              if (document.expiresAt case final expiry?)
                Text(
                  'Son geçerlilik: ${expiry.day}.${expiry.month}.${expiry.year}',
                  style: TextStyle(
                    color: document.status == DocumentStatus.expired
                        ? SwanColors.warning
                        : null,
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                children: document.tags
                    .map((tag) => Chip(label: Text('#$tag')))
                    .toList(),
              ),
              const SizedBox(height: 20),
              const Text(
                'Hızlı İşlemler',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if (permissions.canDownload)
                    const OutlinedButton(onPressed: null, child: Text('İndir')),
                  if (permissions.canUpdate)
                    const OutlinedButton(
                      onPressed: null,
                      child: Text('Güncelle'),
                    ),
                  if (permissions.canArchive)
                    const OutlinedButton(
                      onPressed: null,
                      child: Text('Arşivle'),
                    ),
                  if (permissions.canDelete)
                    const OutlinedButton(onPressed: null, child: Text('Sil')),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Sürüm Geçmişi',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              ...document.versions.map(
                (version) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    version.isCurrent ? Icons.check_circle : Icons.history,
                  ),
                  title: Text(
                    'Sürüm ${version.number}${version.isCurrent ? " • Güncel" : ""}',
                  ),
                  subtitle: Text('${version.uploader} • ${version.summary}'),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'İlişkili Belgeler',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              if (document.related.isEmpty) const Text('İlişkili belge yok.'),
              ...document.related.map(
                (related) => ListTile(
                  key: Key('related-document-${related.documentId.value}'),
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    related.isMissing
                        ? Icons.warning_amber_rounded
                        : Icons.link_rounded,
                    color: related.isMissing ? SwanColors.warning : null,
                  ),
                  title: Text(related.label),
                  subtitle: Text(
                    related.isMissing
                        ? 'Eksik belge • ${related.relationship}'
                        : 'Tamamlandı • ${related.relationship}',
                  ),
                  onTap: related.isMissing
                      ? null
                      : () => Navigator.pushNamed(
                            context,
                            '/document-detail',
                            arguments: DocumentDetailRouteArgs(
                              documentId: related.documentId,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      );
}
