import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import 'workout_builder_screen.dart';

/// Antrenman şablonları, makrodöngü takibi ve dril kütüphanesi.
///
/// Stitch "antrenman_program_ve_driller" tasarımını tam uygular:
/// - Aktif Makrodöngü durumu (Hafta 7/12 - 2025 Bahar)
/// - Haftalık Hedef Hacim ve ilerleme çubuğu (%78, 1.200 Ok / 14 Saat)
/// - Hızlı eylem ribbon'ı (Yeni Özel Dril Ekle, Takıma Ata)
/// - Arama çubuğu ve yatay kategori filtreleme
/// - Dril kartları (video önizleme / rozetler / süre & set / antrenör bilgisi / oturum başlatma)
class ProtocolListScreen extends ConsumerStatefulWidget {
  const ProtocolListScreen({super.key});

  @override
  ConsumerState<ProtocolListScreen> createState() => _ProtocolListScreenState();
}

class _ProtocolListScreenState extends ConsumerState<ProtocolListScreen> {
  String _selectedCategory = 'Tümü';
  final _searchController = TextEditingController();

  final List<String> _categories = const [
    'Tümü',
    'Teknik & Duruş',
    'Kondisyon & Güç',
    'Zihinsel & Odak',
    'Müsabaka Simülasyonu',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final protocolsAsync = ref.watch(trainingProtocolsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                SwanSpace.md,
                SwanSpace.sm,
                SwanSpace.md,
                110,
              ),
              children: [
                // Top bar
                _buildHeader(c),
                const SizedBox(height: SwanSpace.md),

                // 1. Period Context & Status Header
                _buildMacrocycleBanner(c),
                const SizedBox(height: SwanSpace.md),

                // 2. Weekly Routine Volume Card
                _buildVolumeCard(c),
                const SizedBox(height: SwanSpace.md),

                // 3. Primary Action Ribbon
                _buildActionRibbon(c),
                const SizedBox(height: SwanSpace.md),

                // 4. Search Bar
                _buildSearchBar(c),
                const SizedBox(height: SwanSpace.sm),

                // 5. Filter Pills
                _buildFilterChips(c),
                const SizedBox(height: SwanSpace.md),

                // 6. Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ÖNERİLEN DRİLLER',
                      style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                    ),
                    Text(
                      'Sırala: Öncelik',
                      style: SwanType.caption(c.accent, w: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: SwanSpace.sm),

                // 7. Protocols List
                protocolsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(SwanSpace.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(SwanSpace.md),
                    child: Text('Şablonlar yüklenemedi: $e', style: SwanType.bodySm(c.danger)),
                  ),
                  data: (list) {
                    final query = _searchController.text.trim().toLowerCase();
                    final filtered = list.where((p) {
                      if (query.isEmpty) return true;
                      return p.name.toLowerCase().contains(query) ||
                          (p.description?.toLowerCase().contains(query) ?? false);
                    }).toList();

                    return Column(
                      children: [
                        if (filtered.isEmpty)
                          _buildEmptyOrDemoNotice(c, list.isEmpty)
                        else
                          for (final p in filtered)
                            _buildProtocolCard(context, c, p),

                        // Preset Curated Drills from Stitch
                        const SizedBox(height: SwanSpace.sm),
                        _buildCuratedDrillCards(c),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildHeader(SwanPalette c) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: c.ink),
          tooltip: 'Geri',
        ),
        const SizedBox(width: SwanSpace.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SWANSPORT',
                style: SwanType.caption(c.accent, w: FontWeight.w700),
              ),
              Text(
                'Antrenman',
                style: SwanType.h2(c.ink),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Bildirimler',
          icon: Icon(Icons.notifications_none_rounded, color: c.ink),
          onPressed: () => Navigator.pushNamed(context, '/bildirimler'),
        ),
        CircleAvatar(
          radius: 16,
          backgroundColor: c.accent,
          child: const Icon(Icons.person_rounded, size: 18, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildMacrocycleBanner(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: c.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: SwanSpace.xs),
                  Text(
                    'AKTİF MAKRODÖNGÜ',
                    style: SwanType.caption(c.accent, w: FontWeight.w700),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: c.line),
                ),
                child: Text(
                  'Hafta 7/12',
                  style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '2025 Bahar',
                style: SwanType.h2(c.ink),
              ),
              Text(
                'Müsabaka Öncesi Yüklenme',
                style: SwanType.caption(c.inkMuted, w: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeCard(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.track_changes_rounded, size: 20, color: c.accent),
              ),
              const SizedBox(width: SwanSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HAFTALIK HEDEF HACİM',
                      style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '1.200 Ok • 14 Saat',
                      style: SwanType.h3(c.ink),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '%78',
                    style: SwanType.h2(c.accent),
                  ),
                  Text(
                    'Tamamlandı',
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: 0.78,
              minHeight: 8,
              backgroundColor: c.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(c.accent),
            ),
          ),
          const SizedBox(height: SwanSpace.md),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(SwanSpace.sm),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.adjust_rounded, size: 18, color: c.accent),
                      const SizedBox(width: SwanSpace.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Atılan Ok Sayısı',
                              style: SwanType.caption(c.inkMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '936 / 1.200',
                              style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(SwanSpace.sm),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.timer_outlined, size: 18, color: c.accent),
                      const SizedBox(width: SwanSpace.xs),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Kuvvet & Kondisyon',
                              style: SwanType.caption(c.inkMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '11.2 / 14 Sa',
                              style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                            ),
                          ],
                        ),
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

  Widget _buildActionRibbon(SwanPalette c) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkoutProtocolBuilderScreen(),
                ),
              );
            },
            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
            label: const Text('Yeni Özel Dril'),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: SwanSpace.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(width: SwanSpace.sm),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Takım dril atama paneli hazırlanıyor...')),
              );
            },
            icon: Icon(Icons.groups_outlined, size: 18, color: c.ink),
            label: Text('Takıma Ata', style: SwanType.bodySm(c.ink, w: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.line),
              backgroundColor: c.surfaceAlt,
              padding: const EdgeInsets.symmetric(vertical: SwanSpace.sm),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(SwanPalette c) {
    return Container(
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        style: SwanType.body(c.ink),
        decoration: InputDecoration(
          hintText: 'Dril, teknik odak veya antrenör ara...',
          hintStyle: SwanType.bodySm(c.inkMuted),
          prefixIcon: Icon(Icons.search_rounded, color: c.inkMuted, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SwanSpace.md,
            vertical: SwanSpace.sm,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(SwanPalette c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _categories.map((cat) {
          final isSelected = _selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: SwanSpace.xs),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() => _selectedCategory = cat);
              },
              selectedColor: c.accent,
              backgroundColor: c.surfaceAlt,
              labelStyle: SwanType.caption(
                isSelected ? Colors.white : c.ink,
                w: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              side: BorderSide(
                color: isSelected ? c.accent : c.line,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyOrDemoNotice(SwanPalette c, bool isTotallyEmpty) {
    if (isTotallyEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: SwanSpace.md),
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: Text(
          'Kulübünüze ait özel şablon bulunamadı. Aşağıdaki hazır müfredat drillerini doğrudan başlatabilirsiniz.',
          style: SwanType.bodySm(c.inkMuted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SwanSpace.lg),
      child: Text('Arama kriterine uygun dril bulunamadı.', style: SwanType.bodySm(c.inkMuted)),
    );
  }

  Widget _buildProtocolCard(BuildContext context, SwanPalette c, TrainingProtocol p) {
    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.sm),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.name, style: SwanType.h3(c.ink)),
              ),
              if (p.isPlatformTemplate)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                  ),
                  child: Text('Hazır', style: SwanType.caption(c.accent, w: FontWeight.w600)),
                ),
            ],
          ),
          if (p.description != null) ...[
            const SizedBox(height: SwanSpace.xs),
            Text(p.description!, style: SwanType.bodySm(c.inkMuted)),
          ],
          const SizedBox(height: SwanSpace.sm),
          Text(_summary(p), style: SwanType.caption(c.inkMuted)),
          const SizedBox(height: SwanSpace.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                unawaited(_start(context, p));
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: const Text('Oturumu Başlat'),
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCuratedDrillCards(SwanPalette c) {
    return Column(
      children: [
        // Drill Card 1: Bant ile Dinamik Bırakış & Yay Çekişi Drili
        _buildDrillItem(
          c: c,
          tag: 'Teknik',
          level: 'Orta Seviye',
          title: 'Bant ile Dinamik Bırakış & Yay Çekişi Drili',
          duration: '25 dk',
          reps: '4 Set × 15 Tekrar',
          coach: 'Ahmet K. • Başantrenör',
          thumbnailIcon: Icons.play_arrow_rounded,
          onTapStart: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bant drili kılavuzu ve sayaç başlatılıyor...')),
            );
          },
        ),
        const SizedBox(height: SwanSpace.sm),

        // Drill Card 2: 70 Metre Rüzgarlı Saha Simülasyonu
        _buildDrillItem(
          c: c,
          tag: 'Müsabaka',
          level: 'İleri Seviye',
          title: '70 Metre Rüzgarlı Saha Simülasyonu',
          description: 'Yan rüzgar hamlelerine karşı zamanlama kalibrasyonu ve puan hassasiyet takip adaptasyonu.',
          duration: '60 dk',
          reps: '12 Seri × 6 Ok',
          badgeText: '70m • Rüzgar Skoru',
          coach: 'Müsabaka Komitesi',
          thumbnailIcon: Icons.air_rounded,
          onTapStart: () => Navigator.pushNamed(context, '/musabaka-simulasyonu'),
        ),
        const SizedBox(height: SwanSpace.sm),

        // Drill Card 3: Clicker Kontrolü ve Kör Atış
        _buildDrillItem(
          c: c,
          tag: 'Zihinsel & Odak',
          level: 'Tüm Düzeyler',
          title: 'Clicker Kontrolü ve Kör Atış (Göz Kapalı)',
          description: '5 metre mesafede hedefsiz minder önünde işitsel ve kinestetik geri bildirim entegrasyonu.',
          duration: '30 dk',
          reps: '6 Seri × 6 Ok',
          coach: 'Dr. Selin Y. • Spor Psikolojisi',
          thumbnailIcon: Icons.visibility_off_rounded,
          onTapStart: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Kör atış ve clicker zamanlama seansı açılıyor...')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDrillItem({
    required SwanPalette c,
    required String tag,
    required String level,
    required String title,
    String? description,
    required String duration,
    required String reps,
    String? badgeText,
    required String coach,
    required IconData thumbnailIcon,
    required VoidCallback onTapStart,
  }) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(SwanRadius.sm),
                          ),
                          child: Text(
                            tag,
                            style: SwanType.caption(c.accent, w: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: SwanSpace.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius: BorderRadius.circular(SwanRadius.sm),
                          ),
                          child: Text(
                            level,
                            style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SwanSpace.xs),
                    Text(
                      title,
                      style: SwanType.h3(c.ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: SwanSpace.sm),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.surfaceAlt,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                  border: Border.all(color: c.line),
                ),
                child: Icon(thumbnailIcon, size: 24, color: c.accent),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: SwanSpace.xs),
            Text(
              description,
              style: SwanType.caption(c.inkMuted),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: SwanSpace.sm),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: c.accent),
              const SizedBox(width: 4),
              Text(duration, style: SwanType.caption(c.ink)),
              const SizedBox(width: SwanSpace.md),
              Icon(Icons.repeat_rounded, size: 16, color: c.accent),
              const SizedBox(width: 4),
              Text(reps, style: SwanType.caption(c.ink)),
              if (badgeText != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                  ),
                  child: Text(badgeText, style: SwanType.caption(c.inkMuted, w: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: SwanSpace.sm),
          Divider(color: c.line, height: 1),
          const SizedBox(height: SwanSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: c.surfaceAlt,
                    child: Text(
                      coach.substring(0, 1),
                      style: SwanType.caption(c.ink, w: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: SwanSpace.xs),
                  Text(
                    coach,
                    style: SwanType.caption(c.inkMuted),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: onTapStart,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Başlat'),
                style: TextButton.styleFrom(
                  foregroundColor: c.accent,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _summary(TrainingProtocol p) {
    final cfg = p.config;
    final unit = (p.branch as ArcheryDefinition?)?.unitLabel ?? 'tekrar';
    return '${cfg.setCount} set × ${cfg.unitsPerSet} $unit  ·  en fazla ${cfg.maxUnitScore} puan  ·  ${cfg.mode.label}';
  }

  Future<void> _start(BuildContext context, TrainingProtocol p) async {
    final rhythm = await showModalBottomSheet<SessionRhythm>(
      context: context,
      builder: (ctx) {
        final c = ctx.swan;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(SwanSpace.lg),
                child: Text('Katılım biçimi', style: SwanType.h3(c.ink)),
              ),
              for (final r in SessionRhythm.values)
                ListTile(
                  title: Text(r.label, style: SwanType.body(c.ink)),
                  subtitle: Text(_rhythmHint(r), style: SwanType.caption(c.inkMuted)),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              const SizedBox(height: SwanSpace.md),
            ],
          ),
        );
      },
    );
    if (rhythm == null) return;

    final club = await ref.read(activeClubProvider.future);
    if (club == null) return;

    try {
      final res = await ref.read(trainingSessionServiceProvider).startClubSession(
            clubId: club.id,
            protocolId: p.id,
            rhythm: rhythm,
          );
      if (context.mounted) {
        unawaited(
          Navigator.pushNamed(
            context,
            '/antrenman-oturumu',
            arguments: {'id': res.id},
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  static String _rhythmHint(SessionRhythm r) => switch (r) {
        SessionRhythm.shared => 'Aşamaları sen başlatırsın, herkes aynı sayaçla ilerler',
        SessionRhythm.individual => 'Sporcu kendi setini ve sayacını kendi başlatır',
        SessionRhythm.mixed => 'Aşamayı sen başlatırsın, sporcu kendi setini tamamlar',
      };
}
