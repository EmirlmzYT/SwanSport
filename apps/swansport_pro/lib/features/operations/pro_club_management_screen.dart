import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../widgets/pro_ui_components.dart';
import 'pro_club_settings_view.dart';

/// Kulüp operasyonlarının sosyal uygulamadan Pro'ya taşınan ilk bölümü.
class ProClubManagementScreen extends ConsumerWidget {
  const ProClubManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(clubPendingApplicationsProvider);
    final announcements = ref.watch(announcementsProvider);
    final documents = ref.watch(clubDocumentsProvider);
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Kulüp Yönetimi'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Başvurular'),
              Tab(text: 'Duyurular'),
              Tab(text: 'Belgeler'),
              Tab(text: 'Ayarlar'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            applications.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ProErrorState(
                message: 'Başvurular yüklenemedi: $error',
                onRetry: () => ref.invalidate(clubPendingApplicationsProvider),
              ),
              data: (rows) => rows.isEmpty
                  ? const ProEmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'Bekleyen başvuru yok',
                      subtitle: 'Yeni kulüp başvuruları burada görünür.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return Card(
                          child: ListTile(
                            title: Text(row.personName ?? 'Başvuru sahibi'),
                            subtitle: Text(
                              '${row.roleLabel}\n${row.message ?? ''}',
                            ),
                            isThreeLine: row.message?.isNotEmpty ?? false,
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                IconButton(
                                  tooltip: 'Reddet',
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () =>
                                      _review(context, ref, row, false),
                                ),
                                IconButton(
                                  tooltip: 'Kabul et',
                                  icon: const Icon(Icons.check_rounded),
                                  onPressed: () =>
                                      _review(context, ref, row, true),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            announcements.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ProErrorState(
                message: 'Duyurular yüklenemedi: $error',
                onRetry: () => ref.invalidate(announcementsProvider),
              ),
              data: (rows) => _AnnouncementList(
                rows: rows,
                onAdd: () => _addAnnouncement(context, ref),
              ),
            ),
            documents.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => ProErrorState(
                message: 'Belgeler yüklenemedi: $error',
                onRetry: () => ref.invalidate(clubDocumentsProvider),
              ),
              data: (rows) => ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _addDocument(context, ref),
                      icon: const Icon(Icons.note_add_outlined),
                      label: const Text('Belge Ekle'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (rows.isEmpty)
                    const ProEmptyState(
                      icon: Icons.folder_open_outlined,
                      title: 'Belge yok',
                      subtitle: 'Kulüp belgeleri burada listelenir.',
                    ),
                  for (final row in rows)
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(row.name),
                      subtitle: Text(row.sizeLabel ?? row.kind),
                      trailing: IconButton(
                        tooltip: 'Belgeyi sil',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _removeDocument(context, ref, row),
                      ),
                    ),
                ],
              ),
            ),
            const ProClubSettingsView(),
          ],
        ),
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    ClubApplicationRow row,
    bool accept,
  ) async {
    try {
      await ref.read(clubApplicationServiceProvider).review(row.id, accept);
      ref.invalidate(clubPendingApplicationsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('İşlem tamamlanamadı: $error')));
      }
    }
  }

  Future<void> _addAnnouncement(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final body = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Duyuru Oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            TextField(
              controller: body,
              decoration: const InputDecoration(labelText: 'Duyuru'),
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Yayımla'),
          ),
        ],
      ),
    );
    if (save != true || title.text.trim().isEmpty || body.text.trim().isEmpty) {
      return;
    }
    final club = await ref.read(activeClubProvider.future);
    if (club == null) return;
    await ref
        .read(clubDataServiceProvider)
        .addAnnouncement(club.id, title.text.trim(), body.text.trim(), false);
    ref.invalidate(announcementsProvider);
  }

  Future<void> _addDocument(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Belge Kaydı Ekle'),
        content: TextField(
          controller: name,
          decoration: const InputDecoration(labelText: 'Belge adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
    if (save != true || name.text.trim().isEmpty) return;
    final club = await ref.read(activeClubProvider.future);
    if (club == null) return;
    await ref
        .read(clubOpsServiceProvider)
        .addDocument(club.id, name.text.trim());
    ref.invalidate(clubDocumentsProvider);
  }

  Future<void> _removeDocument(
    BuildContext context,
    WidgetRef ref,
    DocumentRow row,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Belge kaydı silinsin mi?'),
        content: Text(row.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(clubOpsServiceProvider).removeDocument(row.id);
    ref.invalidate(clubDocumentsProvider);
  }
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({required this.rows, required this.onAdd});
  final List<AnnouncementRow> rows;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.campaign_outlined),
              label: const Text('Duyuru Oluştur'),
            ),
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const ProEmptyState(
              icon: Icons.campaign_outlined,
              title: 'Duyuru yok',
              subtitle: 'Kulüp duyuruları burada görünür.',
            ),
          for (final row in rows)
            ListTile(
              leading: Icon(
                row.pinned ? Icons.push_pin_rounded : Icons.campaign_outlined,
              ),
              title: Text(row.title),
              subtitle: Text(row.body),
            ),
        ],
      );
}
