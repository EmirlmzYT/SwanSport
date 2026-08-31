import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/media/image_pick.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/quick_form.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/design/swan_type.dart';

/// Belge Kasası — kulüp ve sporcu evrakları, geçerlilik takibiyle.
///
/// Eskiden yalnızca isim listeliyordu; dosyanın kendisi yoktu. Artık dosya
/// yükleniyor, türü ve geçerlilik tarihi tutuluyor, süresi dolmadan önce
/// hatırlatma gidiyor.
class DocumentVaultScreen extends ConsumerStatefulWidget {
  const DocumentVaultScreen({super.key});

  @override
  ConsumerState<DocumentVaultScreen> createState() =>
      _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends ConsumerState<DocumentVaultScreen> {
  String _filter = ''; // '' | club | athlete | person

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final async = ref.watch(vaultDocsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kulüp', style: SwanType.h3(ink)),
                        const SizedBox(height: 3),
                        Text('Belge Kasası',
                            style: SwanType.h2(ink)),
                      ],
                    ),
                  ),
                  AddButton(onTap: _add, tooltip: 'Belge ekle'),
                ]),
              ),
              _tabs(isDark, ink),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(vaultDocsProvider);
                    await ref.read(vaultDocsProvider.future);
                  },
                  child: async.when(
                    loading: () => ListView(children: [premiumLoading()]),
                    error: (e, _) =>
                        ListView(children: [premiumError(context, '$e')]),
                    data: (all) {
                      final list = _filter.isEmpty
                          ? all
                          : all.where((d) => d.ownerType == _filter).toList();
                      if (list.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.only(top: 40),
                          children: [
                            premiumEmpty(
                              context,
                              icon: Icons.folder_rounded,
                              title: 'Belge yok',
                              subtitle:
                                  'Lisans, sağlık raporu, tescil belgesi ve '
                                  'sertifikaları buraya yükle. Süresi dolmadan '
                                  'önce hatırlatılır.',
                              actionLabel: 'Belge ekle',
                              onAction: _add,
                            ),
                          ],
                        );
                      }
                      final expiring = list
                          .where((d) => d.isExpired || d.isExpiring)
                          .length;
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 132),
                        children: [
                          if (expiring > 0) _warning(isDark, expiring),
                          for (final d in list) _card(isDark, ink, d),
                        ],
                      );
                    },
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

  Widget _tabs(bool isDark, Color ink) {
    const items = [
      ('', 'Tümü'),
      ('club', 'Kulüp'),
      ('athlete', 'Sporcu'),
      ('person', 'Kişisel'),
    ];
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          for (final it in items)
            GestureDetector(
              onTap: () => setState(() => _filter = it.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: _filter == it.$1
                      ? kTeal
                      : (isDark ? const Color(0xFF1A2537) : Colors.white),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                      color: _filter == it.$1
                          ? kTeal
                          : (isDark
                              ? const Color(0xFF233149)
                              : const Color(0xFFEAEEF3))),
                ),
                child: Text(it.$2,
                    style: SwanType.caption(_filter == it.$1 ? Colors.white : ink, w: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _warning(bool isDark, int n) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFD9860B).withValues(alpha: .10),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFFD9860B).withValues(alpha: .35)),
        ),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Color(0xFFD9860B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$n belgenin süresi dolmuş ya da dolmak üzere.',
                style: SwanType.caption(const Color(0xFFD9860B), w: FontWeight.w700)),
          ),
        ]),
      );

  Widget _card(bool isDark, Color ink, VaultDoc d) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final (color, icon) = d.isExpired
        ? (const Color(0xFFF43F5E), Icons.error_rounded)
        : d.isExpiring
            ? (const Color(0xFFD9860B), Icons.schedule_rounded)
            : (kTeal, Icons.description_rounded);

    return GestureDetector(
      onTap: () => _actions(d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: d.isExpired
                  ? const Color(0xFFF43F5E).withValues(alpha: .3)
                  : line),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(ink, w: FontWeight.w800)),
                  ),
                  if (d.verified) ...[
                    const SizedBox(width: 5),
                    const Icon(Icons.verified_rounded, size: 13, color: kTeal),
                  ],
                ]),
                const SizedBox(height: 2),
                Text('${d.typeLabel} · ${d.ownerLabel}',
                    style: SwanType.caption(SwanColors.textSecondary)),
                if (d.expiresOn != null) ...[
                  const SizedBox(height: 3),
                  Text(
                      d.isExpired
                          ? 'Süresi doldu · ${d.expiresOn!.day}.${d.expiresOn!.month}.${d.expiresOn!.year}'
                          : 'Geçerli: ${d.expiresOn!.day}.${d.expiresOn!.month}.${d.expiresOn!.year}'
                              '${d.daysLeft != null && d.daysLeft! <= 30 ? " · ${d.daysLeft} gün" : ""}',
                      style: SwanType.caption(color, w: FontWeight.w700)),
                ],
              ],
            ),
          ),
          if (d.storagePath != null)
            const Icon(Icons.attach_file_rounded,
                size: 15, color: SwanColors.textSecondary),
        ]),
      ),
    );
  }

  // ------------------------------- eylemler --------------------------------
  Future<void> _add() async {
    final club = ref.read(activeClubProvider).valueOrNull;
    if (club == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    // 1) Tür
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Belge türü', style: SwanType.h3(ink)),
          const SizedBox(height: 8),
          for (final e in kDocTypes.entries)
            ListTile(
              dense: true,
              title: Text(e.value, style: SwanType.bodySm(ink, w: FontWeight.w600)),
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ]),
      ),
    );
    if (type == null) return;

    // 2) Sahibi — sporcu belgesi ise hangi sporcu
    String ownerType = 'club';
    String? ownerId;
    if (type == 'lisans' || type == 'saglik') {
      final athletes = ref.read(clubAthletesProvider).valueOrNull ?? const [];
      if (athletes.isNotEmpty) {
        final picked = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => Container(
            height: MediaQuery.of(ctx).size.height * 0.6,
            decoration: BoxDecoration(
              color: surf,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Column(children: [
              Text('Kimin belgesi?', style: SwanType.h3(ink)),
              Expanded(
                child: ListView(children: [
                  ListTile(
                    title: Text('Kulübe ait',
                        style: SwanType.bodySm(ink, w: FontWeight.w600)),
                    onTap: () => Navigator.pop(ctx, ''),
                  ),
                  for (final a in athletes)
                    ListTile(
                      title: Text(a.fullName,
                          style: SwanType.bodySm(ink, w: FontWeight.w600)),
                      onTap: () => Navigator.pop(ctx, a.id),
                    ),
                ]),
              ),
            ]),
          ),
        );
        if (picked == null) return;
        if (picked.isNotEmpty) {
          ownerType = 'athlete';
          ownerId = picked;
        }
      }
    }

    // 3) Dosya (isteğe bağlı ama önerilen)
    String? path;
    String fileLabel = '';
    final picked = await pickImage();
    if (picked != null) {
      try {
        path = await ref.read(vaultServiceProvider).upload(picked.bytes, picked.name);
        fileLabel = picked.name;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Dosya yüklenemedi: $e'),
              backgroundColor: const Color(0xFFF43F5E)));
        }
      }
    }

    // 4) Künye
    final name = FormField_('Belge adı',
        hint: kDocTypes[type] ?? 'Belge')
      ..controller.text = kDocTypes[type] ?? '';
    final expires = FormField_('Geçerlilik bitişi (GG.AA.YYYY)',
        hint: '31.12.2026', required: false);

    await showQuickForm(
      context,
      title: 'Belge ekle',
      note: fileLabel.isEmpty
          ? 'Dosya eklenmedi — sonradan da eklenebilir.'
          : 'Dosya: $fileLabel',
      fields: [name, expires],
      onSubmit: () async {
        try {
          await ref.read(vaultServiceProvider).add(
                clubId: club.id,
                name: name.value,
                ownerType: ownerType,
                ownerId: ownerId,
                docType: type,
                path: path,
                expires: _parseDate(expires.value),
              );
          ref.invalidate(vaultDocsProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Belge eklendi'), backgroundColor: kTeal));
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Eklenemedi: $e'),
                backgroundColor: const Color(0xFFF43F5E)));
          }
        }
      },
    );
  }

  /// "31.12.2026" biçimini tarihe çevirir; tutmazsa null.
  DateTime? _parseDate(String s) {
    final p = s.trim().split(RegExp(r'[./-]'));
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]), m = int.tryParse(p[1]), y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> _actions(VaultDoc d) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(d.name, style: SwanType.h3(ink)),
          Text('${d.typeLabel} · ${d.ownerLabel}',
              style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
          const SizedBox(height: 14),
          if (d.storagePath != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.open_in_new_rounded,
                  size: 20, color: kTeal),
              title: Text('Bağlantıyı kopyala',
                  style: SwanType.bodySm(ink, w: FontWeight.w600)),
              subtitle: Text('1 saat geçerli, tarayıcıda aç',
                  style: SwanType.caption(SwanColors.textSecondary)),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final url = await ref
                      .read(vaultServiceProvider)
                      .signedUrl(d.storagePath!);
                  await Clipboard.setData(ClipboardData(text: url));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Bağlantı kopyalandı'),
                        backgroundColor: kTeal));
                  }
                } catch (e) {
                  // Kullanıcı düğmeye bastı; sessiz kalmak "çalışmıyor" gibi
                  // görünür. Belgeye erişimin neden olmadığını söyle.
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Bağlantı alınamadı: $e'),
                        backgroundColor: const Color(0xFFF43F5E)));
                  }
                }
              },
            ),
          ListTile(
            dense: true,
            leading: Icon(
                d.verified ? Icons.gpp_bad_rounded : Icons.verified_rounded,
                size: 20,
                color: d.verified ? SwanColors.textSecondary : kTeal),
            title: Text(d.verified ? 'Doğrulamayı kaldır' : 'Doğrula',
                style: SwanType.bodySm(ink, w: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              _guard(() async {
                await ref
                    .read(vaultServiceProvider)
                    .verify(d.id, !d.verified);
                ref.invalidate(vaultDocsProvider);
              }, d.verified ? 'Doğrulama kaldırıldı' : 'Belge doğrulandı');
            },
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.delete_outline_rounded,
                size: 20, color: Color(0xFFF43F5E)),
            title: Text('Belgeyi sil',
                style: SwanType.bodySm(const Color(0xFFF43F5E), w: FontWeight.w700)),
            onTap: () {
              Navigator.pop(ctx);
              _guard(() async {
                await ref.read(vaultServiceProvider).remove(d.id);
                ref.invalidate(vaultDocsProvider);
              }, 'Belge silindi');
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _guard(Future<void> Function() task, String ok) async {
    try {
      await task();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(ok), backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }
}
