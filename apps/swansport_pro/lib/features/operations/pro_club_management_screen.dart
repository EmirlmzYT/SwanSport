import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../widgets/pro_ui_components.dart';
import 'pro_club_settings_view.dart';

/// Kulüp operasyonlarının sosyal uygulamadan Pro'ya taşınan ilk bölümü.
class ProClubManagementScreen extends ConsumerWidget {
  const ProClubManagementScreen({this.initialTab = 0, super.key});

  final int initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applications = ref.watch(clubPendingApplicationsProvider);
    final announcements = ref.watch(announcementsProvider);
    final documents = ref.watch(clubDocumentsProvider);
    return DefaultTabController(
      length: 4,
      initialIndex: initialTab.clamp(0, 3),
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
                            onTap: () => _openApplication(context, ref, row),
                            title: Text(row.personName ?? 'Başvuru sahibi'),
                            subtitle: Text(
                              '${row.roleLabel}\n${row.message ?? ''}',
                            ),
                            isThreeLine: row.message?.isNotEmpty ?? false,
                            trailing: const Icon(Icons.chevron_right_rounded),
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
                      subtitle: Text(
                        '${row.sizeLabel ?? row.kind} · v${row.version}'
                        '${row.validUntil == null ? '' : ' · ${row.validUntil!.toIso8601String().substring(0, 10)} tarihine kadar'}',
                      ),
                      onTap: row.hasFile
                          ? () => _previewDocument(context, ref, row)
                          : null,
                      trailing: Wrap(
                        children: [
                          if (row.hasFile)
                            IconButton(
                              tooltip: 'Belgeyi önizle',
                              icon: const Icon(Icons.open_in_new_rounded),
                              onPressed: () =>
                                  _previewDocument(context, ref, row),
                            ),
                          IconButton(
                            tooltip: 'Belgeyi arşivle',
                            icon: const Icon(Icons.archive_outlined),
                            onPressed: () =>
                                _archiveDocument(context, ref, row),
                          ),
                        ],
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
      BuildContext context, WidgetRef ref, ClubApplicationRow row, bool accept,
      {String? note, int? coachLevel, String? supervisorId}) async {
    try {
      await ref.read(clubApplicationServiceProvider).review(
            row.id,
            accept,
            note: note,
            coachLevel: coachLevel,
            supervisorId: supervisorId,
          );
      ref.invalidate(clubPendingApplicationsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('İşlem tamamlanamadı: $error')));
      }
    }
  }

  Future<void> _openApplication(
    BuildContext context,
    WidgetRef ref,
    ClubApplicationRow row,
  ) async {
    final note = TextEditingController();
    var coachLevel = row.desiredRole == 'coach' ? 1 : null;
    String? supervisorId;
    final supervisors = row.desiredRole == 'coach'
        ? ref
            .read(clubApplicationServiceProvider)
            .eligibleSupervisors(row.clubId)
        : Future.value(const <({String profileId, String name, int level})>[]);
    final decision = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Üyelik başvurusu',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(row.personName ?? 'Başvuru sahibi'),
                  subtitle: Text(
                    '${row.roleLabel} · ${row.createdAt.toLocal().toString().split('.').first}',
                  ),
                ),
                if (row.message?.trim().isNotEmpty ?? false) ...[
                  Text('Başvuru notu',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  Text(row.message!.trim()),
                  const SizedBox(height: 16),
                ],
                if (row.desiredRole == 'coach') ...[
                  DropdownButtonFormField<int>(
                    key: const Key('club-application-coach-level'),
                    initialValue: coachLevel,
                    decoration: const InputDecoration(labelText: 'Kademe'),
                    items: [
                      for (var level = 1; level <= 5; level++)
                        DropdownMenuItem(
                            value: level, child: Text('$level. kademe')),
                    ],
                    onChanged: (value) => setSheetState(() {
                      coachLevel = value;
                      if (value != 1) supervisorId = null;
                    }),
                  ),
                  if (coachLevel == 1)
                    FutureBuilder<
                        List<({String profileId, String name, int level})>>(
                      future: supervisors,
                      builder: (context, snapshot) =>
                          DropdownButtonFormField<String>(
                        key: const Key('club-application-supervisor'),
                        initialValue: supervisorId,
                        decoration: const InputDecoration(
                          labelText: 'Sorumlu antrenör',
                          helperText: '1. kademe kabulünde zorunludur.',
                        ),
                        items: [
                          for (final item in snapshot.data ?? const [])
                            DropdownMenuItem(
                              value: item.profileId,
                              child:
                                  Text('${item.name} · ${item.level}. kademe'),
                            ),
                        ],
                        onChanged: snapshot.hasData
                            ? (value) =>
                                setSheetState(() => supervisorId = value)
                            : null,
                      ),
                    ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  key: const Key('club-application-review-note'),
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Karar notu',
                    helperText: 'Ret işleminde gerekçe zorunludur.',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('club-application-reject'),
                        onPressed: () {
                          if (note.text.trim().isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                  content: Text('Ret gerekçesi gerekli.')),
                            );
                            return;
                          }
                          Navigator.pop(sheetContext, false);
                        },
                        child: const Text('Reddet'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('club-application-accept'),
                        onPressed: row.desiredRole == 'coach' &&
                                coachLevel == 1 &&
                                supervisorId == null
                            ? null
                            : () => Navigator.pop(sheetContext, true),
                        child: const Text('Kabul et'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (decision == null || !context.mounted) return;
    await _review(
      context,
      ref,
      row,
      decision,
      note: note.text.trim(),
      coachLevel: decision ? coachLevel : null,
      supervisorId: decision ? supervisorId : null,
    );
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
    final version = TextEditingController(text: '1');
    DateTime? validUntil;
    PlatformFile? selectedFile;
    Uint8List? selectedBytes;
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Kulüp evrakı yükle'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Belge adı'),
                ),
                TextField(
                  controller: version,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sürüm'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(selectedFile?.name ?? 'PDF, JPG veya PNG seçin'),
                  trailing: const Icon(Icons.attach_file_rounded),
                  onTap: () async {
                    final result = await FilePicker.pickFile(
                      type: FileType.custom,
                      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
                    );
                    if (result != null) {
                      final bytes = await result.readAsBytes();
                      setDialogState(() {
                        selectedFile = result;
                        selectedBytes = bytes;
                      });
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    validUntil == null
                        ? 'Geçerlilik tarihi yok'
                        : 'Geçerli: ${validUntil!.toIso8601String().substring(0, 10)}',
                  ),
                  trailing: const Icon(Icons.event_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (picked != null) {
                      setDialogState(() => validUntil = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yükle'),
            ),
          ],
        ),
      ),
    );
    final file = selectedFile;
    final parsedVersion = int.tryParse(version.text);
    if (save != true ||
        name.text.trim().isEmpty ||
        selectedBytes == null ||
        parsedVersion == null ||
        parsedVersion < 1) {
      return;
    }
    final club = await ref.read(activeClubProvider.future);
    if (club == null) return;
    try {
      await ref.read(clubOpsServiceProvider).uploadClubDocument(
            clubId: club.id,
            name: name.text.trim(),
            fileName: file!.name,
            bytes: selectedBytes!,
            validUntil: validUntil,
            version: parsedVersion,
          );
      ref.invalidate(clubDocumentsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Belge yüklenemedi: $error')),
        );
      }
    }
  }

  Future<void> _previewDocument(
    BuildContext context,
    WidgetRef ref,
    DocumentRow row,
  ) async {
    try {
      final url =
          await ref.read(clubOpsServiceProvider).signedClubDocumentUrl(row.id);
      final opened = await launchUrl(Uri.parse(url));
      if (!opened) throw StateError('Tarayıcı belgeyi açmadı.');
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Belge açılamadı: $error')),
        );
      }
    }
  }

  Future<void> _archiveDocument(
    BuildContext context,
    WidgetRef ref,
    DocumentRow row,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Belge arşivlensin mi?'),
        content: Text(row.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Arşivle'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(clubOpsServiceProvider).archiveDocument(row.id);
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
