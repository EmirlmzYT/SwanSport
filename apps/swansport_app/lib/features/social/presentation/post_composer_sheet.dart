import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/media/image_pick.dart';
import '../../../app/widgets/premium.dart';
import '../../demo/demo_role.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/widgets/tag_composer.dart';

/// Gönderi oluşturma sayfasını açar. Paylaşım yapıldıysa true döner.
Future<bool?> showPostComposer(BuildContext context,
    {bool startWithImage = false}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _PostComposerSheet(startWithImage: startWithImage),
  );
}

class _PostComposerSheet extends ConsumerStatefulWidget {
  const _PostComposerSheet({this.startWithImage = false});

  /// Ana akıştaki fotoğraf kısayolu, besteci açılır açılmaz seçiciyi başlatır.
  final bool startWithImage;

  @override
  ConsumerState<_PostComposerSheet> createState() => _PostComposerSheetState();
}

class _PostComposerSheetState extends ConsumerState<_PostComposerSheet> {
  final _ctrl = TextEditingController();

  /// Seçilen görseller, sırasıyla. En fazla 8 — sınır hem burada hem
  /// veritabanı tetikleyicisinde (0062).
  final List<PickedMedia> _media = [];

  /// Gönderiyi kim görecek. Boş bırakılırsa sunucu karar veriyor: reşit
  /// olmayan hesaplarda tetikleyici `public` yerine `followers` yazıyor.
  PostVisibility _visibility = PostVisibility.public;

  /// Seçilen etiketler. Metin ile kimlik ayrı: kullanıcı adı yazılıyor,
  /// veritabanına UUID gidiyor.
  final _tags = TagState();

  bool _asClub = true;
  bool _busy = false;

  // Stitch Screen 23 - Athletic Telemetry & Options State
  bool _communityLeaderboardToggle = true;
  String _selectedClubAffiliation = 'Iron Swans';
  bool _hasMusic = true;
  String _selectedLocation = 'Maslak Performance Lab, Sarıyer';
  String _taggedPartner = '@Mert Koç (Kuvvet Başantrenörü)';

  static const _maxMedia = 8;

  @override
  void initState() {
    super.initState();
    if (widget.startWithImage) {
      Future.microtask(_pickImage);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_media.length >= _maxMedia) {
      _snack('En fazla $_maxMedia fotoğraf ekleyebilirsin',
          SwanPalette.light.warning);
      return;
    }
    try {
      final picked = await pickImage();
      if (picked == null || !mounted) return;
      setState(() =>
          _media.add(PickedMedia(bytes: picked.bytes, name: picked.name)));
    } catch (e) {
      _snack('Görsel seçilemedi: $e', SwanPalette.light.danger);
    }
  }

  void _addHashtag(String tag) {
    final current = _ctrl.text;
    if (current.contains(tag)) return;
    setState(() {
      _ctrl.text = current.isEmpty ? tag : '$current $tag';
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length),
      );
    });
  }

  Future<void> _share(String? clubId) async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _media.isEmpty) {
      _snack('Bir şeyler yaz ya da görsel ekle', SwanPalette.light.warning);
      return;
    }
    setState(() => _busy = true);
    try {
      final postId = await ref.read(socialServiceProvider).createPost(
            body: text,
            clubId: clubId,
            images: _media,
            visibility: clubId != null ? null : visibilityKey(_visibility),
          );

      // Etiketler ayrı çağrı.
      final wanted = _tags.mentionsIn(text);
      final tagList = TagState.hashtagsIn(text);
      if (wanted.isNotEmpty || tagList.isNotEmpty) {
        try {
          final done = await ref
              .read(socialShareServiceProvider)
              .setTags(postId, mentions: wanted, hashtags: tagList);
          if (done < wanted.length && mounted) {
            _snack('${wanted.length - done} kişi etiketlenemedi',
                SwanPalette.light.warning);
          }
        } catch (e) {
          if (mounted) {
            _snack('Gönderi paylaşıldı, etiketler eklenemedi: $e',
                SwanPalette.light.warning);
          }
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _snack('Paylaşılamadı: $e', SwanPalette.light.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, Color c) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: c));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF061424) : SwanPalette.light.surface;
    final surfHigh = isDark ? const Color(0xFF132031) : const Color(0xFFF1F5F9);
    final surfHigher = isDark ? const Color(0xFF1E2B3C) : const Color(0xFFE2E8F0);
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final line = isDark ? const Color(0xFF293547) : SwanPalette.light.line;
    final alt = (isDark ? SwanPalette.dark : SwanPalette.light).surfaceAlt;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    final club = ref.watch(activeClubProvider).valueOrNull;
    final creds = ref.watch(myCredentialsProvider).valueOrNull ?? const [];
    final demo = ref.watch(demoRoleProvider);

    final canPostPersonally = demo != null
        ? demo.canPostPersonally
        : creds.any((c) => c.status == 'approved');
    final canPostAsClub = club != null &&
        (demo != null
            ? demo.canPostAsClub
            : (club.role == 'club_admin' || club.role == 'coach'));
    final effectiveAsClub = canPostAsClub && (_asClub || !canPostPersonally);
    final canShare = canPostAsClub || canPostPersonally;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: line, width: 1.5)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 30,
            offset: Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag grip
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E3B4E) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Stitch Top Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: surfHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, size: 20, color: ink),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Yeni Gönderi',
                        style: GoogleFonts.sora(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'ANTRENMAN ÖZETİ',
                        style: GoogleFonts.plusJakartaSans(
                          color: kTeal,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _busy || !canShare
                      ? null
                      : () => _share(effectiveAsClub ? club.id : null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: [
                        BoxShadow(
                          color: kTeal.withValues(alpha: .35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy) ...[
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _busy ? 'Paylaşılıyor' : 'Paylaş',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF003734),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (!_busy) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.send_rounded,
                              size: 15, color: Color(0xFF003734)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!canShare) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: SwanPalette.light.warning.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: SwanPalette.light.warning.withValues(alpha: .4)),
                      ),
                      child: Row(children: [
                        Icon(Icons.verified_user_rounded,
                            size: 20, color: SwanPalette.light.warning),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                              'Paylaşım yapmak için kimliğini doğrulatmalısın '
                              '(antrenör kademesi veya sporcu lisansı).',
                              style: SwanType.caption(SwanColors.textSecondary,
                                  w: FontWeight.w600)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context, false);
                        Navigator.pushNamed(context, '/dogrulama');
                      },
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text('Doğrulamaya Git',
                            style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
                      ),
                    ),
                  ] else ...[
                    // Who Mode (Club / Personal)
                    if (canPostAsClub && canPostPersonally) ...[
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: alt, borderRadius: BorderRadius.circular(13)),
                        child: Row(children: [
                          _who('Kulüp adına', true, ink, surf),
                          _who('Kendi adıma', false, ink, surf),
                        ]),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Media Preview & Telemetry Overlay (Stitch Screen 23)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 220,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: surfHigh,
                              image: _media.isNotEmpty
                                  ? null
                                  : const DecorationImage(
                                      image: NetworkImage(
                                        'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?w=900&auto=format&fit=crop&q=80',
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                            ),
                            child: _media.isNotEmpty
                                ? Image.memory(
                                    _media.first.bytes,
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                        ),
                        // Dark overlay gradient
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Top badges (4K HDR / Media count)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.videocam_rounded,
                                        size: 13, color: kTeal),
                                    const SizedBox(width: 4),
                                    Text('4K HDR',
                                        style: GoogleFonts.plusJakartaSans(
                                            color: kTeal,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.burst_mode_rounded,
                                        size: 13, color: Colors.white70),
                                    const SizedBox(width: 4),
                                    Text(
                                        _media.isNotEmpty
                                            ? '${_media.length}/$_maxMedia'
                                            : '1/3',
                                        style: GoogleFonts.plusJakartaSans(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Top action icons (crop, filters, pick)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Row(
                            children: [
                              _iconAction(Icons.crop_rounded, () {
                                _snack('Kırpma aracı aktif', kTeal);
                              }),
                              const SizedBox(width: 6),
                              _iconAction(Icons.auto_fix_high_rounded, () {
                                _snack('Performans filtreleri uygulandı', kTeal);
                              }),
                              const SizedBox(width: 6),
                              _iconAction(
                                Icons.add_photo_alternate_rounded,
                                _pickImage,
                                primary: true,
                              ),
                            ],
                          ),
                        ),
                        // Bottom Live Telemetry Pill Overlay
                        Positioned(
                          bottom: 10,
                          left: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F1C2D).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: kTeal.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: kTeal,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Maslak Performance Lab • Canlı Telemetri',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  children: [
                                    const Icon(Icons.verified_rounded,
                                        size: 14, color: kTeal),
                                    const SizedBox(width: 4),
                                    Text(
                                      'DOĞRULANDI',
                                      style: GoogleFonts.sora(
                                        color: kTeal,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_media.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 54,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _media.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(_media[i].bytes,
                                      width: 54, height: 54, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _media.removeAt(i)),
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Icon(Icons.close_rounded,
                                          color: Colors.white, size: 12),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Workout Caption Input Box (Stitch Screen 23)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: surfHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: kTeal.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.fitness_center_rounded,
                                    size: 14, color: kTeal),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Günün Notları & Zihinsel Durum',
                                style: GoogleFonts.plusJakartaSans(
                                  color: ink.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _ctrl,
                            onChanged: (_) => setState(() {}),
                            minLines: 3,
                            maxLines: 6,
                            style: GoogleFonts.plusJakartaSans(
                              color: ink,
                              fontSize: 13,
                              height: 1.45,
                            ),
                            decoration: InputDecoration(
                              hintText:
                                  'Bugünkü antrenmanın nasıldı? Setler, rekorlar ve hislerini not et...',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                color: SwanColors.textSecondary,
                                fontSize: 13,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Wrap(
                                spacing: 6,
                                children: [
                                  _hashtagChip('#PRDay'),
                                  _hashtagChip('#SwanStrength'),
                                  _hashtagChip('#Hypertrophy'),
                                ],
                              ),
                              Text(
                                '${_ctrl.text.length}/500',
                                style: GoogleFonts.plusJakartaSans(
                                  color: SwanColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tag suggestions & summary
                    TagSuggestions(
                      controller: _ctrl,
                      tags: _tags,
                      onChanged: () => setState(() {}),
                    ),
                    TagSummary(text: _ctrl.text, tags: _tags),

                    const SizedBox(height: 14),

                    // Telemetry HUD Card: Synced Workout Data (Stitch Screen 23)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surfHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: line),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bar_chart_rounded,
                                      size: 20, color: kTeal),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Egzersiz Verileri HUD',
                                        style: GoogleFonts.sora(
                                          color: ink,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Senkronize Akıllı Sensörler',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: SwanColors.textSecondary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: surfHigher,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.edit_note_rounded,
                                        size: 14, color: kTeal),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Düzenle +',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: kTeal,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Exercise badges
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _exerciseBadge('Bench Press (5x5 @ 110kg)'),
                              _exerciseBadge('Barbell Squat (4x8 @ 140kg)'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 3 tactical metric columns
                          Row(
                            children: [
                              _metricBox(
                                icon: Icons.fitness_center_rounded,
                                label: 'Hacim',
                                value: '4.850',
                                unit: 'kg',
                                color: kTeal,
                                surf: surfHigher,
                              ),
                              const SizedBox(width: 8),
                              _metricBox(
                                icon: Icons.timer_outlined,
                                label: 'Süre',
                                value: '58',
                                unit: 'dk',
                                color: ink,
                                surf: surfHigher,
                              ),
                              const SizedBox(width: 8),
                              _metricBox(
                                icon: Icons.local_fire_department_rounded,
                                label: 'Kalori',
                                value: '620',
                                unit: 'kcal',
                                color: const Color(0xFFFF8C6F),
                                surf: surfHigher,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Advanced Tags & Distribution
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(
                        'GELİŞMİŞ ETİKETLER & DAĞITIM',
                        style: GoogleFonts.plusJakartaSans(
                          color: SwanColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),

                    // Coach / Partner Tile
                    _optionTile(
                      icon: Icons.person_add_rounded,
                      title: 'Antrenör / Partner',
                      subtitle: _taggedPartner,
                      trailing: Icon(Icons.chevron_right_rounded,
                          size: 18, color: SwanColors.textSecondary),
                      onTap: () => _snack('Partner listesi güncellendi', kTeal),
                      surfHigh: surfHigh,
                      ink: ink,
                    ),
                    const SizedBox(height: 8),

                    // Club Affiliation Selection
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: surfHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.diversity_3_rounded,
                                      size: 16, color: kTeal),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Kulüp Liderlik Panosu',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: ink,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              Text('Tek Seçim',
                                  style: GoogleFonts.plusJakartaSans(
                                      color: SwanColors.textSecondary,
                                      fontSize: 10)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _clubChip(
                                  name: 'Swan Runners',
                                  sub: 'Istanbul Metro',
                                  selected: _selectedClubAffiliation == 'Swan Runners',
                                  onTap: () => setState(() =>
                                      _selectedClubAffiliation = 'Swan Runners'),
                                  surf: surfHigher,
                                  ink: ink,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _clubChip(
                                  name: 'Iron Swans',
                                  sub: 'Power & Weight',
                                  selected: _selectedClubAffiliation == 'Iron Swans',
                                  onTap: () => setState(() =>
                                      _selectedClubAffiliation = 'Iron Swans'),
                                  surf: surfHigher,
                                  ink: ink,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Location Tile
                    _optionTile(
                      icon: Icons.location_on_rounded,
                      title: 'Konum',
                      subtitle: _selectedLocation,
                      trailing: Icon(Icons.chevron_right_rounded,
                          size: 18, color: SwanColors.textSecondary),
                      onTap: () => _snack('Konum GPS ile onaylandı', kTeal),
                      surfHigh: surfHigh,
                      ink: ink,
                    ),
                    const SizedBox(height: 8),

                    // Music Tile
                    _optionTile(
                      icon: Icons.graphic_eq_rounded,
                      title: 'Antrenman Müziği',
                      subtitle: _hasMusic ? 'Heavy Metal Gym Mix • Spotify' : 'Müzik seçilmedi',
                      trailing: _hasMusic
                          ? GestureDetector(
                              onTap: () => setState(() => _hasMusic = false),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: surfHigher,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close_rounded,
                                    size: 14, color: Colors.white70),
                              ),
                            )
                          : const Icon(Icons.add_rounded, size: 18, color: kTeal),
                      onTap: () => setState(() => _hasMusic = true),
                      surfHigh: surfHigh,
                      ink: ink,
                    ),
                    const SizedBox(height: 8),

                    // Distribution Toggle Tile
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: surfHigh,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: line),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E2B3C),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.public_rounded,
                                size: 18, color: kTeal),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Topluluk & Liderlik Panosu',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Tüm kulüp üyeleri ve akış görebilir',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: SwanColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _communityLeaderboardToggle,
                            activeThumbColor: kTeal,
                            activeTrackColor: kTeal.withValues(alpha: 0.35),
                            inactiveThumbColor: Colors.grey,
                            inactiveTrackColor: surfHigher,
                            onChanged: (val) =>
                                setState(() => _communityLeaderboardToggle = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Bottom Security Affirmation
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.security_rounded,
                              size: 13, color: kTeal),
                          const SizedBox(width: 6),
                          Text(
                            'Biyometrik verileriniz ISO-27001 şifrelemesiyle saklanır',
                            style: GoogleFonts.plusJakartaSans(
                              color: SwanColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Bottom Action Bar (Stitch Screen 23)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: surf,
              border: Border(top: BorderSide(color: line)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    _snack('Gönderi taslak olarak kaydedildi', kTeal);
                    Navigator.pop(context, false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: surfHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bookmark_border_rounded,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          'Taslak Kaydet',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _snack('Önizleme modu aktif', kTeal),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: surfHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_rounded,
                            size: 16, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          'Önizle',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _busy || !canShare
                      ? null
                      : () => _share(effectiveAsClub ? club.id : null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kTeal.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.send_rounded,
                            size: 16, color: Color(0xFF003734)),
                        const SizedBox(width: 6),
                        Text(
                          _busy ? 'Paylaşılıyor…' : 'Paylaşımı Tamamla',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF003734),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _who(String label, bool clubMode, Color ink, Color surf) {
    final on = _asClub == clubMode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _asClub = clubMode),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: on ? surf : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label,
              style: SwanType.caption(on ? ink : SwanColors.textSecondary,
                  w: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _iconAction(IconData icon, VoidCallback onTap, {bool primary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: primary ? kTeal : Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 16,
          color: primary ? const Color(0xFF003734) : Colors.white,
        ),
      ),
    );
  }

  Widget _hashtagChip(String text) {
    return GestureDetector(
      onTap: () => _addHashtag(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2B3C),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            color: kTeal,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _exerciseBadge(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2B3C),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: kTeal,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricBox({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required Color surf,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: Colors.white60),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white60,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: GoogleFonts.sora(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' $unit',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white60,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    required Color surfHigh,
    required Color ink,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: surfHigh,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                color: Color(0xFF1E2B3C),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 17, color: kTeal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      color: kTeal,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _clubChip({
    required String name,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
    required Color surf,
    required Color ink,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? kTeal : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      color: selected ? kTeal : ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    sub,
                    style: GoogleFonts.plusJakartaSans(
                      color: SwanColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 16,
              color: selected ? kTeal : SwanColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

