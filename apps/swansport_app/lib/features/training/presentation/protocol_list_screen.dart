import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_core/swansport_core.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Şablonları mevcut kayıtlardan okur ve gerçek oturum başlatır.
class ProtocolListScreen extends ConsumerStatefulWidget {
  const ProtocolListScreen({super.key, this.initialMode});
  final TrainingMode? initialMode;

  @override
  ConsumerState<ProtocolListScreen> createState() => _ProtocolListScreenState();
}

class _ProtocolListScreenState extends ConsumerState<ProtocolListScreen> {
  String _selectedCategory = 'Tümü';

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialMode?.label ?? 'Tümü';
  }

  final _searchController = TextEditingController();

  final List<String> _categories = const [
    'Tümü',
    'Teknik',
    'Puanlı',
    'Müsabaka',
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
                      'ANTRENMAN ŞABLONLARI',
                      style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                    ),
                    Text(
                      'Ada göre',
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
                    child: Text('Şablonlar yüklenemedi: $e',
                        style: SwanType.bodySm(c.danger)),
                  ),
                  data: (list) {
                    final query = _searchController.text.trim();
                    final filtered = list.where((p) {
                      if (_selectedCategory != 'Tümü' &&
                          p.config.mode.label != _selectedCategory)
                        return false;
                      return trContains(p.name, query) ||
                          trContains(p.description ?? '', query);
                    }).toList();

                    return Column(
                      children: [
                        if (filtered.isEmpty)
                          _buildEmptyNotice(c, list.isEmpty)
                        else
                          for (final p in filtered)
                            _buildProtocolCard(context, c, p),

                        // Kayıt listesinin alt boşluğu
                        const SizedBox(height: SwanSpace.sm),
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
        if (ref.watch(swanAccessProvider).isClubStaff)
          IconButton(
            tooltip: 'Şablon oluştur',
            icon: Icon(Icons.add_rounded, color: c.accent),
            onPressed: () => Navigator.pushNamed(context, '/antrenman-olustur'),
          ),
        IconButton(
          tooltip: 'Bildirimler',
          icon: Icon(Icons.notifications_none_rounded, color: c.ink),
          onPressed: () => Navigator.pushNamed(context, '/bildirimler'),
        ),
        CircleAvatar(
          radius: 16,
          backgroundColor: c.accent,
          child:
              const Icon(Icons.person_rounded, size: 18, color: Colors.white),
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
          hintText: 'Şablon adı veya açıklama ara…',
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

  Widget _buildEmptyNotice(SwanPalette c, bool isTotallyEmpty) {
    if (isTotallyEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: SwanSpace.md),
        padding: const EdgeInsets.all(SwanSpace.md),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(SwanRadius.md),
        ),
        child: Text(
          'Henüz kullanabileceğin bir antrenman şablonu yok. Kulüp personeli yeni şablon oluşturabilir.',
          style: SwanType.bodySm(c.inkMuted),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SwanSpace.lg),
      child: Text('Arama kriterine uygun dril bulunamadı.',
          style: SwanType.bodySm(c.inkMuted)),
    );
  }

  Widget _buildProtocolCard(
      BuildContext context, SwanPalette c, TrainingProtocol p) {
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                  ),
                  child: Text('Hazır',
                      style: SwanType.caption(c.accent, w: FontWeight.w600)),
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
                  subtitle:
                      Text(_rhythmHint(r), style: SwanType.caption(c.inkMuted)),
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
      final res =
          await ref.read(trainingSessionServiceProvider).startClubSession(
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  static String _rhythmHint(SessionRhythm r) => switch (r) {
        SessionRhythm.shared =>
          'Aşamaları sen başlatırsın, herkes aynı sayaçla ilerler',
        SessionRhythm.individual =>
          'Sporcu kendi setini ve sayacını kendi başlatır',
        SessionRhythm.mixed =>
          'Aşamayı sen başlatırsın, sporcu kendi setini tamamlar',
      };
  static String _summary(TrainingProtocol p) =>
      '${p.config.setCount} set · ${p.config.unitsPerSet} tekrar/set · ${p.config.mode.label}';
}
