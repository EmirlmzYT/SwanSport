import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import '../../app/widgets/status_pill.dart';

/// Onay kuyruğunda seçili kalem.
///
/// Kulüp başvurusu ile kimlik başvurusu tek kuyrukta akıyor; yönetici için
/// ikisi de aynı iş: belgeye bak, karar ver.
class _QueueItem {
  const _QueueItem.club(PendingClub c)
      : id = '',
        club = c,
        credential = null;
  const _QueueItem.credential(CredentialRow c)
      : id = '',
        club = null,
        credential = c;

  final String id;
  final PendingClub? club;
  final CredentialRow? credential;

  bool get isClub => club != null;
  String get key => isClub ? 'club:${club!.id}' : 'cred:${credential!.id}';
  String get ownerId => isClub ? club!.id : credential!.id;
  String get ownerType => isClub ? 'club' : 'credential';
  String get title => isClub ? club!.name : (credential!.personName ?? 'Kişi');
  String get subtitle =>
      isClub ? (club!.city ?? 'Şehir belirtilmemiş') : credential!.label;
}

final _selectedApprovalProvider = StateProvider<String?>((ref) => null);

/// Belgeleri ve başvuruyu **yan yana** gösteren onay ekranı.
///
/// Mobilde belge görmek için ayrı bir sayfaya gidilip geri dönülüyor; karar
/// verirken belgeyi hatırlamak gerekiyordu. Burada belge sağda açık dururken
/// karar solda veriliyor.
class ApprovalsScreen extends ConsumerWidget {
  const ApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final clubs = ref.watch(pendingClubsProvider);
    final creds = ref.watch(pendingCredentialsProvider);

    final items = <_QueueItem>[
      for (final c in clubs.valueOrNull ?? const []) _QueueItem.club(c),
      for (final c in creds.valueOrNull ?? const []) _QueueItem.credential(c),
    ];

    final loading = clubs.isLoading || creds.isLoading;
    final error = clubs.error ?? creds.error;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 380,
          child: _Queue(items: items, loading: loading, error: error),
        ),
        VerticalDivider(width: 1, color: t.colorScheme.outline),
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              final key = ref.watch(_selectedApprovalProvider);
              final item = items.where((i) => i.key == key).firstOrNull;
              if (item == null) {
                return Center(
                  child: Text(
                    items.isEmpty
                        ? 'Bekleyen başvuru yok.'
                        : 'Soldan bir başvuru seç.',
                    style: t.textTheme.bodySmall,
                  ),
                );
              }
              return _Detail(item: item);
            },
          ),
        ),
      ],
    );
  }
}

class _Queue extends ConsumerWidget {
  const _Queue({required this.items, required this.loading, this.error});

  final List<_QueueItem> items;
  final bool loading;
  final Object? error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final selected = ref.watch(_selectedApprovalProvider);

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ConsoleDensity.xl),
          child: SelectableText('Kuyruk yüklenemedi: $error',
              style: t.textTheme.bodySmall),
        ),
      );
    }
    if (loading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(ConsoleDensity.xl),
          child: Text('Bekleyen başvuru yok.\nKuyruk temiz.',
              textAlign: TextAlign.center, style: t.textTheme.bodySmall),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: t.colorScheme.outline),
      itemBuilder: (_, i) {
        final it = items[i];
        final isSelected = it.key == selected;
        return InkWell(
          onTap: () =>
              ref.read(_selectedApprovalProvider.notifier).state = it.key,
          child: Container(
            padding: const EdgeInsets.all(ConsoleDensity.lg),
            color: isSelected
                ? t.colorScheme.primary.withValues(alpha: .08)
                : Colors.transparent,
            child: Row(
              children: [
                Icon(
                  it.isClub ? Icons.shield_rounded : Icons.badge_rounded,
                  size: 18,
                  color: t.colorScheme.outline,
                ),
                const SizedBox(width: ConsoleDensity.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.title,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(it.subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: t.textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusPill(
                  label: it.isClub ? 'Kulüp' : 'Kimlik',
                  tone: it.isClub ? PillTone.info : PillTone.warning,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Detail extends ConsumerStatefulWidget {
  const _Detail({required this.item});

  final _QueueItem item;

  @override
  ConsumerState<_Detail> createState() => _DetailState();
}

class _DetailState extends ConsumerState<_Detail> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final it = widget.item;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(ConsoleDensity.xl),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.title, style: t.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(it.subtitle, style: t.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: t.colorScheme.outline),
        Expanded(
          child: _Documents(ownerType: it.ownerType, ownerId: it.ownerId),
        ),
        Divider(height: 1, color: t.colorScheme.outline),
        Padding(
          padding: const EdgeInsets.all(ConsoleDensity.lg),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                      labelText: 'Not (ret sebebi vb.)'),
                ),
              ),
              const SizedBox(width: ConsoleDensity.md),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _decide(false),
                icon: const Icon(Icons.close_rounded, size: 17),
                label: const Text('Reddet'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: t.colorScheme.error),
              ),
              const SizedBox(width: ConsoleDensity.sm),
              FilledButton.icon(
                onPressed: _busy ? null : () => _decide(true),
                icon: const Icon(Icons.check_rounded, size: 17),
                label: Text(_busy ? 'Kaydediliyor…' : 'Onayla'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _decide(bool approve) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = Theme.of(context).colorScheme.error;
    final it = widget.item;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();

    try {
      final svc = ref.read(verificationServiceProvider);
      if (it.isClub) {
        if (approve) {
          await svc.approveClub(it.club!.id);
        } else {
          await svc.rejectClub(it.club!.id, note: note);
        }
      } else {
        await svc.reviewCredential(it.credential!.id, approve, note: note);
      }

      ref
        ..invalidate(pendingClubsProvider)
        ..invalidate(pendingCredentialsProvider)
        ..read(_selectedApprovalProvider.notifier).state = null;

      messenger.showSnackBar(SnackBar(
        content: Text(approve ? 'Onaylandı.' : 'Reddedildi.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('İşlem yapılamadı: $e'),
        backgroundColor: errorColor,
      ));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// Başvuruya bağlı belgeler.
///
/// URL'ler imzalı ve bir saat geçerli — belge dosyaları özel bucket'ta durur,
/// herkese açık bağlantı üretilmez.
class _Documents extends ConsumerWidget {
  const _Documents({required this.ownerType, required this.ownerId});

  final String ownerType;
  final String ownerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final async = ref.watch(_documentsProvider((ownerType, ownerId)));

    return async.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(ConsoleDensity.xl),
          child: SelectableText('Belgeler alınamadı: $e',
              textAlign: TextAlign.center, style: t.textTheme.bodySmall),
        ),
      ),
      data: (docs) {
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(ConsoleDensity.xl),
              child: Text(
                'Bu başvuruya belge eklenmemiş.\n'
                'Belgesiz onaylamadan önce iki kez düşün.',
                textAlign: TextAlign.center,
                style: t.textTheme.bodySmall,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(ConsoleDensity.lg),
          itemCount: docs.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: ConsoleDensity.md),
          itemBuilder: (_, i) {
            final d = docs[i];
            return _DocumentCard(docType: d.docType, url: d.url);
          },
        );
      },
    );
  }
}

final _documentsProvider = FutureProvider.autoDispose
    .family<List<({String docType, String url})>, (String, String)>(
        (ref, key) async {
  return ref
      .watch(verificationServiceProvider)
      .documentsFor(key.$1, key.$2);
});

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.docType, required this.url});

  final String docType;
  final String url;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isImage = RegExp(r'\.(png|jpe?g|webp|gif)(\?|$)', caseSensitive: false)
        .hasMatch(url);

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: t.colorScheme.outline),
        borderRadius: BorderRadius.circular(ConsoleDensity.radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(ConsoleDensity.md),
            child: Row(
              children: [
                Icon(isImage ? Icons.image_rounded : Icons.description_rounded,
                    size: 17, color: t.colorScheme.outline),
                const SizedBox(width: ConsoleDensity.sm),
                Expanded(
                  child: Text(_label(docType), style: t.textTheme.bodyMedium),
                ),
                SelectableText(
                  'Bağlantı 1 saat geçerli',
                  style: t.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (isImage)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Padding(
                  padding: const EdgeInsets.all(ConsoleDensity.xl),
                  child: Text('Görsel yüklenemedi.',
                      style: t.textTheme.bodySmall),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(ConsoleDensity.lg),
              child: SelectableText(url, style: t.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  static String _label(String type) => switch (type) {
        'kademe_belgesi' => 'Kademe belgesi',
        'kimlik' => 'Kimlik',
        'federasyon' => 'Federasyon lisansı',
        'tuzuk' => 'Tüzük',
        'vergi' => 'Vergi levhası',
        _ => type,
      };
}
