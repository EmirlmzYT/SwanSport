import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_page_header.dart';

/// Sporcunun ekipman, kalibrasyon (tuning) ve malzeme bakım takip ekranı.
///
/// Veriler doğrudan Supabase `athlete_equipment` tablosuna yazılır ve okunur.
class EquipmentTuningScreen extends ConsumerStatefulWidget {
  const EquipmentTuningScreen({super.key});

  @override
  ConsumerState<EquipmentTuningScreen> createState() =>
      _EquipmentTuningScreenState();
}

class _EquipmentTuningScreenState extends ConsumerState<EquipmentTuningScreen> {
  static IconData _categoryIcon(String category) {
    switch (category) {
      case 'bow':
        return Icons.sports_score_rounded;
      case 'racket':
        return Icons.sports_tennis_rounded;
      case 'footwear':
        return Icons.roller_skating_rounded;
      case 'apparel':
        return Icons.checkroom_rounded;
      case 'ball':
        return Icons.sports_soccer_rounded;
      default:
        return Icons.build_circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final equipmentAsync = ref.watch(myEquipmentProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myEquipmentProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SwanSpace.lg,
                  SwanSpace.md,
                  SwanSpace.lg,
                  120,
                ),
                children: [
                  SwanPageHeader(
                    title: 'Ekipman ve Kalibrasyon',
                    subtitle: 'Malzeme ayarları ve bakım takibi',
                    onBack: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(height: SwanSpace.md),
                  equipmentAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Container(
                      padding: const EdgeInsets.all(SwanSpace.md),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                        border: Border.all(color: c.line),
                      ),
                      child: Text(
                        'Ekipman kayıtları yüklenemedi: $err',
                        style: SwanType.caption(c.danger),
                      ),
                    ),
                    data: (items) {
                      final activeCount =
                          items.where((i) => i.status == 'active').length;
                      final maintenanceCount =
                          items.where((i) => i.status == 'maintenance').length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryCard(
                            c: c,
                            total: items.length,
                            active: activeCount,
                            maintenance: maintenanceCount,
                          ),
                          const SizedBox(height: SwanSpace.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Kayıtlı Malzemeler', style: SwanType.h3(c.ink)),
                              FilledButton.icon(
                                onPressed: () => _openAddEquipmentModal(
                                  context: context,
                                  c: c,
                                  profileId: profile?.id,
                                ),
                                icon: const Icon(Icons.add_rounded, size: 16),
                                label: const Text('Ekipman Ekle'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: c.accent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: SwanSpace.sm),
                          if (items.isEmpty)
                            _buildEmptyCard(c)
                          else
                            ...items.map(
                              (eq) => _buildEquipmentTile(
                                context: context,
                                c: c,
                                eq: eq,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildSummaryCard({
    required SwanPalette c,
    required int total,
    required int active,
    required int maintenance,
  }) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCol(
            c: c,
            label: 'Toplam Ekipman',
            value: '$total',
            color: c.ink,
          ),
          Container(width: 1, height: 36, color: c.line),
          _buildStatCol(
            c: c,
            label: 'Kullanımda',
            value: '$active',
            color: const Color(0xFF10B981),
          ),
          Container(width: 1, height: 36, color: c.line),
          _buildStatCol(
            c: c,
            label: 'Bakım Gerekli',
            value: '$maintenance',
            color: maintenance > 0 ? const Color(0xFFF59E0B) : c.inkMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCol({
    required SwanPalette c,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: SwanType.h2(color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: SwanType.caption(c.inkMuted),
        ),
      ],
    );
  }

  Widget _buildEmptyCard(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.xl),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Icon(Icons.sports_rounded, size: 36, color: c.inkMuted),
          const SizedBox(height: SwanSpace.sm),
          Text(
            'Henüz kayıtlı ekipman yok',
            style: SwanType.bodySm(c.ink, w: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Antrenman malzemelerini, yay/raket ayarlarını ve bakım tarihlerini kaydetmek için ekipman ekle.',
            textAlign: TextAlign.center,
            style: SwanType.caption(c.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentTile({
    required BuildContext context,
    required SwanPalette c,
    required AthleteEquipment eq,
  }) {
    final statusColor = eq.status == 'active'
        ? const Color(0xFF10B981)
        : eq.status == 'maintenance'
            ? const Color(0xFFF59E0B)
            : c.inkMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.sm),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Icon(
                  _categoryIcon(eq.category),
                  color: c.accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eq.name,
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        eq.categoryLabel,
                        if ((eq.brandModel ?? '').isNotEmpty) eq.brandModel!,
                        if ((eq.serialNo ?? '').isNotEmpty) 'S/N: ${eq.serialNo}',
                      ].join(' · '),
                      style: SwanType.caption(c.inkMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  eq.statusLabel,
                  style: SwanType.caption(statusColor, w: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (eq.tuningParams.isNotEmpty) ...[
            const SizedBox(height: SwanSpace.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: eq.tuningParams.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceAlt,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${e.key}: ${e.value}',
                    style: SwanType.caption(c.inkMuted, w: FontWeight.w600)
                        .copyWith(fontSize: 11),
                  ),
                );
              }).toList(),
            ),
          ],
          if ((eq.notes ?? '').isNotEmpty) ...[
            const SizedBox(height: SwanSpace.xs),
            Text(
              eq.notes!,
              style: SwanType.caption(c.inkMuted),
            ),
          ],
          const SizedBox(height: SwanSpace.sm),
          Divider(color: c.line, height: 1),
          const SizedBox(height: SwanSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                eq.lastServicedAt != null
                    ? 'Son Bakım: ${eq.lastServicedAt!.day}.${eq.lastServicedAt!.month}.${eq.lastServicedAt!.year}'
                    : 'Henüz bakım kaydı yok',
                style: SwanType.caption(c.inkMuted).copyWith(fontSize: 11),
              ),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _openTuningModal(
                      context: context,
                      c: c,
                      eq: eq,
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Kalibre Et'),
                    style: TextButton.styleFrom(
                      foregroundColor: c.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    tooltip: 'Sil',
                    color: c.inkMuted,
                    onPressed: () async {
                      await ref
                          .read(equipmentServiceProvider)
                          .deleteEquipment(eq.id);
                      ref.invalidate(myEquipmentProvider);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openAddEquipmentModal({
    required BuildContext context,
    required SwanPalette c,
    required String? profileId,
  }) async {
    if (profileId == null) return;
    final athlete =
        await ref.read(athleteByProfileProvider(profileId).future);
    if (athlete == null) return;

    final nameController = TextEditingController();
    final brandController = TextEditingController();
    final serialController = TextEditingController();
    final tuneKeyController = TextEditingController(text: 'Ayar / Sertlik');
    final tuneValController = TextEditingController();
    final notesController = TextEditingController();
    String selectedCategory = 'bow';
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                SwanSpace.lg,
                SwanSpace.lg,
                SwanSpace.lg,
                MediaQuery.of(ctx).viewInsets.bottom + SwanSpace.xl,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: SwanSpace.md),
                    Text('Yeni Ekipman Kaydet', style: SwanType.h2(c.ink)),
                    const SizedBox(height: SwanSpace.sm),
                    DropdownButtonFormField<String>(
                      initialValue: selectedCategory,
                      decoration: InputDecoration(
                        labelText: 'Ekipman Türü',
                        filled: true,
                        fillColor: c.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                      ),
                      dropdownColor: c.surface,
                      items: const [
                        DropdownMenuItem(
                          value: 'bow',
                          child: Text('Okçuluk & Yay'),
                        ),
                        DropdownMenuItem(
                          value: 'racket',
                          child: Text('Raket'),
                        ),
                        DropdownMenuItem(
                          value: 'footwear',
                          child: Text('Ayakkabı'),
                        ),
                        DropdownMenuItem(
                          value: 'apparel',
                          child: Text('Kıyafet & Koruma'),
                        ),
                        DropdownMenuItem(
                          value: 'ball',
                          child: Text('Top & Ekipman'),
                        ),
                        DropdownMenuItem(
                          value: 'other',
                          child: Text('Genel Malzeme'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedCategory = val);
                        }
                      },
                    ),
                    const SizedBox(height: SwanSpace.sm),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Ekipman Adı',
                        hintText: 'örn. Win&Win Inno AL1 Gövde',
                        filled: true,
                        fillColor: c.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                      ),
                      style: SwanType.bodySm(c.ink),
                    ),
                    const SizedBox(height: SwanSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: brandController,
                            decoration: InputDecoration(
                              labelText: 'Marka / Model',
                              filled: true,
                              fillColor: c.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                            ),
                            style: SwanType.bodySm(c.ink),
                          ),
                        ),
                        const SizedBox(width: SwanSpace.xs),
                        Expanded(
                          child: TextField(
                            controller: serialController,
                            decoration: InputDecoration(
                              labelText: 'Seri No (Opsiyonel)',
                              filled: true,
                              fillColor: c.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                            ),
                            style: SwanType.bodySm(c.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SwanSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: tuneKeyController,
                            decoration: InputDecoration(
                              labelText: 'Ayar Parametresi',
                              filled: true,
                              fillColor: c.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                            ),
                            style: SwanType.bodySm(c.ink),
                          ),
                        ),
                        const SizedBox(width: SwanSpace.xs),
                        Expanded(
                          child: TextField(
                            controller: tuneValController,
                            decoration: InputDecoration(
                              labelText: 'Değer (örn. 38 lbs)',
                              filled: true,
                              fillColor: c.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.md),
                                borderSide: BorderSide(color: c.line),
                              ),
                            ),
                            style: SwanType.bodySm(c.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SwanSpace.sm),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Ek Notlar',
                        filled: true,
                        fillColor: c.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                      ),
                      style: SwanType.bodySm(c.ink),
                    ),
                    const SizedBox(height: SwanSpace.lg),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final name = nameController.text.trim();
                                if (name.isEmpty) return;

                                setModalState(() => isSaving = true);
                                try {
                                  final tuning = <String, dynamic>{};
                                  if (tuneKeyController.text.trim().isNotEmpty &&
                                      tuneValController.text.trim().isNotEmpty) {
                                    tuning[tuneKeyController.text.trim()] =
                                        tuneValController.text.trim();
                                  }

                                  await ref
                                      .read(equipmentServiceProvider)
                                      .saveEquipment(
                                        athleteId: athlete.id,
                                        name: name,
                                        category: selectedCategory,
                                        brandModel: brandController.text,
                                        serialNo: serialController.text,
                                        tuningParams: tuning,
                                        notes: notesController.text,
                                      );

                                  ref.invalidate(myEquipmentProvider);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Ekipman kaydedildi.'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Kayıt başarısız: $e'),
                                        backgroundColor: c.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Kaydet',
                                style: SwanType.bodySm(
                                  Colors.white,
                                  w: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openTuningModal({
    required BuildContext context,
    required SwanPalette c,
    required AthleteEquipment eq,
  }) async {
    final Map<String, TextEditingController> controllers = {};
    for (final entry in eq.tuningParams.entries) {
      controllers[entry.key] =
          TextEditingController(text: entry.value.toString());
    }

    final newKeyController = TextEditingController();
    final newValController = TextEditingController();
    final notesController = TextEditingController(text: eq.notes ?? '');
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                SwanSpace.lg,
                SwanSpace.lg,
                SwanSpace.lg,
                MediaQuery.of(ctx).viewInsets.bottom + SwanSpace.xl,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: c.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: SwanSpace.md),
                    Text(
                      'Kalibrasyon & Bakım Kaydı',
                      style: SwanType.h2(c.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(eq.name, style: SwanType.caption(c.inkMuted)),
                    const SizedBox(height: SwanSpace.md),
                    Text(
                      'Mevcut Parametreler:',
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700),
                    ),
                    const SizedBox(height: SwanSpace.xs),
                    ...controllers.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                entry.key,
                                style: SwanType.bodySm(
                                  c.ink,
                                  w: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: entry.value,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: c.surfaceAlt,
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(SwanRadius.sm),
                                    borderSide: BorderSide(color: c.line),
                                  ),
                                ),
                                style: SwanType.bodySm(c.ink),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: SwanSpace.sm),
                    Text(
                      'Yeni Parametre Ekle:',
                      style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newKeyController,
                            decoration: InputDecoration(
                              hintText: 'Parametre adı',
                              hintStyle: SwanType.caption(c.inkMuted),
                              filled: true,
                              fillColor: c.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.sm),
                                borderSide: BorderSide(color: c.line),
                              ),
                            ),
                            style: SwanType.bodySm(c.ink),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            controller: newValController,
                            decoration: InputDecoration(
                              hintText: 'Değer',
                              hintStyle: SwanType.caption(c.inkMuted),
                              filled: true,
                              fillColor: c.surfaceAlt,
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(SwanRadius.sm),
                                borderSide: BorderSide(color: c.line),
                              ),
                            ),
                            style: SwanType.bodySm(c.ink),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline_rounded),
                          color: c.accent,
                          onPressed: () {
                            final k = newKeyController.text.trim();
                            final v = newValController.text.trim();
                            if (k.isNotEmpty && v.isNotEmpty) {
                              setModalState(() {
                                controllers[k] = TextEditingController(text: v);
                                newKeyController.clear();
                                newValController.clear();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: SwanSpace.md),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Bakım Notları & Değişen Parçalar',
                        filled: true,
                        fillColor: c.surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(SwanRadius.md),
                          borderSide: BorderSide(color: c.line),
                        ),
                      ),
                      style: SwanType.bodySm(c.ink),
                    ),
                    const SizedBox(height: SwanSpace.lg),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setModalState(() => isSaving = true);
                                try {
                                  final newParams = <String, dynamic>{};
                                  for (final e in controllers.entries) {
                                    if (e.value.text.trim().isNotEmpty) {
                                      newParams[e.key] = e.value.text.trim();
                                    }
                                  }

                                  await ref
                                      .read(equipmentServiceProvider)
                                      .updateTuning(
                                        equipmentId: eq.id,
                                        tuningParams: newParams,
                                        notes: notesController.text,
                                      );

                                  ref.invalidate(myEquipmentProvider);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('Kalibrasyon ve bakım güncellendi.'),
                                        backgroundColor: Color(0xFF10B981),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Güncelleme başarısız: $e'),
                                        backgroundColor: c.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(SwanRadius.md),
                          ),
                        ),
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Bakımı Kaydet',
                                style: SwanType.bodySm(
                                  Colors.white,
                                  w: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

