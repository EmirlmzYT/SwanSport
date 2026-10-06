import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/media/image_pick.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/quick_form.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';

/// Gerçek belge listesi, yetkiye göre yükleme ve doğrulama akışları.
class DocumentVaultScreen extends ConsumerStatefulWidget {
  const DocumentVaultScreen({super.key});

  @override
  ConsumerState<DocumentVaultScreen> createState() =>
      _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends ConsumerState<DocumentVaultScreen> {
  String _selectedCategory = 'all'; // all | lisans | saglik | club | other
  bool _sortByDateDesc = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;
    final bg = palette.bg;

    final asyncDocs = ref.watch(vaultDocsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                _buildHeader(context, palette),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(vaultDocsProvider);
                      await ref.read(vaultDocsProvider.future);
                    },
                    child: asyncDocs.when(
                      loading: () => ListView(children: [premiumLoading()]),
                      error: (e, _) =>
                          ListView(children: [premiumError(context, '$e')]),
                      data: (allDocs) =>
                          _buildContent(allDocs, palette, isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildHeader(BuildContext context, SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: palette.line.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.line),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: palette.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Belgeler & Rapor Arşivi',
                    style: SwanType.h3(palette.ink),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Kulüp belge arşivi',
                        style: SwanType.caption(palette.inkMuted,
                            w: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _add,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: palette.accent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: palette.accent.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'Yükle',
                        style:
                            SwanType.caption(Colors.white, w: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    List<VaultDoc> allDocs,
    SwanPalette palette,
    bool isDark,
  ) {
    // Filter documents
    final filteredDocs = allDocs.where((d) {
      if (_selectedCategory == 'lisans')
        return d.docType == 'lisans' && d.ownerType != 'club';
      if (_selectedCategory == 'saglik')
        return d.docType == 'saglik' && d.ownerType != 'club';
      if (_selectedCategory == 'club') return d.ownerType == 'club';
      if (_selectedCategory == 'expiring') return d.isExpired || d.isExpiring;
      if (_selectedCategory == 'other') {
        return d.docType != 'lisans' &&
            d.docType != 'saglik' &&
            d.ownerType != 'club';
      }
      return true;
    }).toList();

    // Sort documents
    filteredDocs.sort((a, b) {
      if (_sortByDateDesc) {
        return b.createdAt.compareTo(a.createdAt);
      } else {
        return a.createdAt.compareTo(b.createdAt);
      }
    });

    final lisansCount = allDocs
        .where((d) => d.docType == 'lisans' && d.ownerType != 'club')
        .length;
    final saglikCount = allDocs
        .where((d) => d.docType == 'saglik' && d.ownerType != 'club')
        .length;
    final clubCount = allDocs.where((d) => d.ownerType == 'club').length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        // Stitch 2x2 Archive Folders Grid
        _buildArchiveFoldersGrid(
          lisansCount: lisansCount,
          saglikCount: saglikCount,
          clubCount: clubCount,
          otherCount: (allDocs.length - lisansCount - saglikCount - clubCount)
              .clamp(0, 99999),
          palette: palette,
          isDark: isDark,
        ),
        const SizedBox(height: 16),

        // Filter Pills (Horizontal Scroll)
        _buildCategoryPills(allDocs, palette, isDark),
        const SizedBox(height: 14),

        // Section Title & Sort Action
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedCategory == 'all'
                  ? 'Son İşlem Gören Belgeler'
                  : 'Filtrelenen Evraklar (${filteredDocs.length})',
              style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _sortByDateDesc = !_sortByDateDesc);
              },
              child: Row(
                children: [
                  Text(
                    _sortByDateDesc ? 'Yeniye Göre' : 'Eskiye Göre',
                    style: SwanType.caption(palette.accent, w: FontWeight.w600),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.unfold_more_rounded,
                    size: 14,
                    color: palette.accent,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (filteredDocs.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.line),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 42,
                  color: palette.inkMuted,
                ),
                const SizedBox(height: 12),
                Text(
                  'Bu kategoride belge bulunamadı',
                  style: SwanType.body(palette.ink, w: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'Lisans, sağlık raporu veya kulüp evrakları ekleyerek arşivi güncel tutabilirsiniz.',
                  style: SwanType.caption(palette.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          for (final doc in filteredDocs)
            _buildDocumentItem(doc, palette, isDark),

        const SizedBox(height: 14),
        // Fast Upload Box
        _buildUploadArea(palette, isDark),
      ],
    );
  }

  Widget _buildArchiveFoldersGrid({
    required int lisansCount,
    required int saglikCount,
    required int clubCount,
    required int otherCount,
    required SwanPalette palette,
    required bool isDark,
  }) {
    final folders = [
      (
        'Lisans Belgeleri',
        '$lisansCount Dosya',
        Icons.assignment_ind_rounded,
        palette.accent,
        'lisans',
      ),
      (
        'Sağlık Belgeleri',
        '$saglikCount Dosya',
        Icons.medical_services_rounded,
        palette.warning,
        'saglik',
      ),
      (
        'Kulüp Belgeleri',
        '$clubCount Dosya',
        Icons.receipt_long_rounded,
        Colors.blue,
        'club',
      ),
      (
        'Diğer Belgeler',
        '$otherCount Dosya',
        Icons.stadium_rounded,
        Colors.purple,
        'other',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Arşiv Klasörleri',
          style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: folders.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.1,
          ),
          itemBuilder: (context, i) {
            final f = folders[i];
            final isSelected = _selectedCategory == f.$5;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = _selectedCategory == f.$5 ? 'all' : f.$5;
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? f.$4.withValues(alpha: 0.12)
                      : palette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? f.$4 : palette.line,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: f.$4.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(f.$3, size: 18, color: f.$4),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.$1,
                            style: SwanType.caption(palette.ink,
                                w: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            f.$2,
                            style: SwanType.caption(palette.inkMuted)
                                .copyWith(fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryPills(
    List<VaultDoc> allDocs,
    SwanPalette palette,
    bool isDark,
  ) {
    final lisansCount = allDocs
        .where((d) => d.docType == 'lisans' && d.ownerType != 'club')
        .length;
    final saglikCount = allDocs
        .where((d) => d.docType == 'saglik' && d.ownerType != 'club')
        .length;
    final clubCount = allDocs.where((d) => d.ownerType == 'club').length;

    final categories = [
      ('all', 'Tümü (${allDocs.length})'),
      ('lisans', 'Lisanslar & Vizeler ($lisansCount)'),
      ('saglik', 'Sağlık Raporları ($saglikCount)'),
      ('club', 'Kulüp Evrakları ($clubCount)'),
      ('other', 'Diğer'),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = categories[i];
          final isSelected = _selectedCategory == cat.$1;

          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat.$1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? palette.accent : palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? palette.accent : palette.line,
                ),
              ),
              child: Center(
                child: Text(
                  cat.$2,
                  style: SwanType.caption(
                    isSelected ? Colors.white : palette.inkMuted,
                    w: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDocumentItem(
    VaultDoc doc,
    SwanPalette palette,
    bool isDark,
  ) {
    final (icon, iconColor) = switch (doc.docType) {
      'lisans' => (Icons.badge_rounded, palette.accent),
      'saglik' => (Icons.medical_services_rounded, palette.warning),
      'tescil' || 'sozlesme' => (
          Icons.assignment_turned_in_rounded,
          Colors.blue
        ),
      _ => (Icons.description_rounded, palette.ink),
    };

    final (statusLabel, statusBg, statusColor, statusIcon) = doc.isExpired
        ? (
            'Süresi Doldu',
            palette.danger.withValues(alpha: 0.1),
            palette.danger,
            Icons.cancel_rounded,
          )
        : doc.isExpiring
            ? (
                'Vize Yaklaşıyor (${doc.daysLeft ?? 0} Gün)',
                palette.warning.withValues(alpha: 0.1),
                palette.warning,
                Icons.schedule_rounded,
              )
            : doc.verified
                ? (
                    'Onaylandı',
                    palette.success.withValues(alpha: 0.1),
                    palette.success,
                    Icons.check_circle_rounded,
                  )
                : (
                    'İnceleme Bekliyor',
                    palette.warning.withValues(alpha: 0.1),
                    palette.warning,
                    Icons.hourglass_empty_rounded,
                  );

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: doc.isExpired
              ? palette.danger.withValues(alpha: 0.4)
              : palette.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            doc.name,
                            style: SwanType.bodySm(
                              palette.ink,
                              w: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _actions(doc),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.more_horiz_rounded,
                              size: 20,
                              color: palette.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${doc.ownerLabel} · ${doc.typeLabel}',
                      style: SwanType.caption(palette.inkMuted),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          doc.storagePath != null
                              ? 'PDF • Dosya Yüklü'
                              : 'Kayıt • Dosya Eklenmedi',
                          style: SwanType.caption(palette.inkMuted),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          width: 3,
                          height: 3,
                          decoration: BoxDecoration(
                            color: palette.inkMuted,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          '${doc.createdAt.day}.${doc.createdAt.month}.${doc.createdAt.year}',
                          style: SwanType.caption(palette.inkMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: palette.line.withValues(alpha: 0.6),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style:
                            SwanType.caption(statusColor, w: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Text(
                  doc.expiresOn != null
                      ? 'Geçerlilik: ${doc.expiresOn!.day}.${doc.expiresOn!.month}.${doc.expiresOn!.year}'
                      : 'Süresiz Evrak',
                  style: SwanType.caption(palette.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadArea(SwanPalette palette, bool isDark) {
    return GestureDetector(
      onTap: _add,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: palette.accent.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.cloud_upload_rounded,
                size: 20,
                color: palette.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Yeni Belge Yükle',
                    style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                  ),
                  Text(
                    'PDF, Görsel ve Tescil Belgeleri (Maks. 10MB)',
                    style: SwanType.caption(palette.inkMuted),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: palette.inkMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------- Eylemler --------------------------------
  Future<void> _add() async {
    final club = ref.read(activeClubProvider).valueOrNull;
    if (club == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

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
          20,
          18,
          20,
          20 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Belge türü', style: SwanType.h3(ink)),
            const SizedBox(height: 8),
            for (final e in kDocTypes.entries)
              ListTile(
                dense: true,
                title: Text(
                  e.value,
                  style: SwanType.bodySm(ink, w: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
          ],
        ),
      ),
    );
    if (type == null) return;

    // 2) Sahibi — sporcu belgesi ise hangi sporcu
    String ownerType = 'club';
    String? ownerId;
    if (type == 'lisans' || type == 'saglik') {
      final athletes = ref.read(clubAthletesProvider).valueOrNull ?? const [];
      if (athletes.isNotEmpty) {
        if (!mounted) return;
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
            child: Column(
              children: [
                Text('Kimin belgesi?', style: SwanType.h3(ink)),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        title: Text(
                          'Kulübe ait',
                          style: SwanType.bodySm(ink, w: FontWeight.w600),
                        ),
                        onTap: () => Navigator.pop(ctx, ''),
                      ),
                      for (final a in athletes)
                        ListTile(
                          title: Text(
                            a.fullName,
                            style: SwanType.bodySm(ink, w: FontWeight.w600),
                          ),
                          onTap: () => Navigator.pop(ctx, a.id),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        if (picked == null) return;
        if (picked.isNotEmpty) {
          ownerType = 'athlete';
          ownerId = picked;
        }
      }
    }

    // 3) Dosya
    String? path;
    String fileLabel = '';
    final picked = await pickImage();
    if (picked != null) {
      try {
        path = await ref
            .read(vaultServiceProvider)
            .upload(picked.bytes, picked.name);
        fileLabel = picked.name;
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dosya yüklenemedi: $e'),
              backgroundColor: SwanPalette.light.danger,
            ),
          );
        }
      }
    }

    // 4) Künye
    final name = FormField_('Belge adı', hint: kDocTypes[type] ?? 'Belge')
      ..controller.text = kDocTypes[type] ?? '';
    final expires = FormField_(
      'Geçerlilik bitişi (GG.AA.YYYY)',
      hint: '31.12.2026',
      required: false,
    );

    if (!mounted) return;
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Belge eklendi'),
                backgroundColor: kTeal,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Eklenemedi: $e'),
                backgroundColor: SwanPalette.light.danger,
              ),
            );
          }
        }
      },
    );
  }

  DateTime? _parseDate(String s) {
    final p = s.trim().split(RegExp(r'[./-]'));
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> _actions(VaultDoc d) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.of(ctx).padding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(d.name, style: SwanType.h3(ink)),
            Text(
              '${d.typeLabel} · ${d.ownerLabel}',
              style: SwanType.caption(
                SwanColors.textSecondary,
                w: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            if (d.storagePath != null)
              ListTile(
                dense: true,
                leading: const Icon(
                  Icons.open_in_new_rounded,
                  size: 20,
                  color: kTeal,
                ),
                title: Text(
                  'Bağlantıyı kopyala',
                  style: SwanType.bodySm(ink, w: FontWeight.w600),
                ),
                subtitle: Text(
                  '1 saat geçerli, tarayıcıda aç',
                  style: SwanType.caption(SwanColors.textSecondary),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final url = await ref
                        .read(vaultServiceProvider)
                        .signedUrl(d.storagePath!);
                    await Clipboard.setData(ClipboardData(text: url));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bağlantı kopyalandı'),
                          backgroundColor: kTeal,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Bağlantı alınamadı: $e'),
                          backgroundColor: SwanPalette.light.danger,
                        ),
                      );
                    }
                  }
                },
              ),
            ListTile(
              dense: true,
              leading: Icon(
                d.verified ? Icons.gpp_bad_rounded : Icons.verified_rounded,
                size: 20,
                color: d.verified ? SwanColors.textSecondary : kTeal,
              ),
              title: Text(
                d.verified ? 'Doğrulamayı kaldır' : 'Doğrula',
                style: SwanType.bodySm(ink, w: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _guard(
                  () async {
                    await ref
                        .read(vaultServiceProvider)
                        .verify(d.id, !d.verified);
                    ref.invalidate(vaultDocsProvider);
                  },
                  d.verified ? 'Doğrulama kaldırıldı' : 'Belge doğrulandı',
                );
              },
            ),
            ListTile(
              dense: true,
              leading: Icon(
                Icons.delete_outline_rounded,
                size: 20,
                color: SwanPalette.light.danger,
              ),
              title: Text(
                'Belgeyi sil',
                style: SwanType.bodySm(
                  SwanPalette.light.danger,
                  w: FontWeight.w700,
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _guard(
                  () async {
                    await ref.read(vaultServiceProvider).remove(d.id);
                    ref.invalidate(vaultDocsProvider);
                  },
                  'Belge silindi',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guard(Future<void> Function() task, String ok) async {
    try {
      await task();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ok), backgroundColor: kTeal),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem başarısız: $e'),
            backgroundColor: SwanPalette.light.danger,
          ),
        );
      }
    }
  }
}
