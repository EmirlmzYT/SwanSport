import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';

/// Stitch Screen 7: SwanSport - Antrenman Planlayıcı & Özel Seans Oluşturucu.
/// Canlı set matrisi, RPE/hacim metrikleri, hedef kas grubu yönetimi ve SwanAI koç analizi.
class WorkoutProtocolBuilderScreen extends ConsumerStatefulWidget {
  const WorkoutProtocolBuilderScreen({
    super.key,
    this.initialTitle = 'Kuvvet & Hipertrofi B Günü',
  });

  final String initialTitle;

  @override
  ConsumerState<WorkoutProtocolBuilderScreen> createState() =>
      _WorkoutProtocolBuilderScreenState();
}

class _WorkoutProtocolBuilderScreenState
    extends ConsumerState<WorkoutProtocolBuilderScreen> {
  late final TextEditingController _titleController;
  final List<String> _muscleGroups = ['Göğüs', 'Ön/Yan Omuz', 'Triceps'];
  final String _category = 'Ağırlık';
  final String _difficulty = 'RPE 8.5';
  final String _duration = '60-75 dk';

  // Exercises with tactile set matrix
  late List<_ExerciseItem> _exercises;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _exercises = [
      _ExerciseItem(
        id: '1',
        title: 'Barbell Incline Bench Press',
        restSeconds: 90,
        targetRpe: 'RPE 8.0',
        sets: [
          _SetItem(setNum: 1, loadKg: 85, reps: '10', isCompleted: true),
          _SetItem(setNum: 2, loadKg: 85, reps: '10', isCompleted: true),
          _SetItem(setNum: 3, loadKg: 85, reps: '8', isCompleted: true),
          _SetItem(
            setNum: 4,
            loadKg: 60,
            reps: 'Maks (Drop)',
            isDropSet: true,
            isCompleted: false,
          ),
        ],
      ),
      _ExerciseItem(
        id: '2',
        title: 'Dumbbell Lateral Raise',
        restSeconds: 60,
        targetRpe: 'RPE 8.5',
        supersetName: 'Face Pull (Kablo)',
        sets: [
          _SetItem(setNum: 1, loadKg: 14, reps: '15', isCompleted: true),
          _SetItem(setNum: 2, loadKg: 14, reps: '15', isCompleted: true),
          _SetItem(setNum: 3, loadKg: 14, reps: '15', isCompleted: true),
        ],
      ),
      _ExerciseItem(
        id: '3',
        title: 'Kablo Triceps Pushdown',
        restSeconds: 60,
        targetRpe: 'RPE 8.0',
        sets: [
          _SetItem(setNum: 1, loadKg: 35, reps: '12', isCompleted: true),
          _SetItem(setNum: 2, loadKg: 35, reps: '12', isCompleted: true),
          _SetItem(setNum: 3, loadKg: 35, reps: '12', isCompleted: true),
          _SetItem(setNum: 4, loadKg: 35, reps: '10', isCompleted: false),
        ],
      ),
    ];
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: palette.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Antrenman Planlayıcı',
          style: SwanType.h3(palette.ink),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, size: 20, color: palette.ink),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Antrenman bağlantısı kopyalandı.')),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.more_vert_rounded, size: 20, color: palette.ink),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                // Top Modal Context Strip
                _buildContextStrip(palette),
                const SizedBox(height: 16),

                // 1. Program Basic Info Card
                _buildBasicInfoCard(palette),
                const SizedBox(height: 16),

                // 2. Target Muscle Groups & Tags
                _buildMuscleGroupsSection(palette),
                const SizedBox(height: 20),

                // 3. Exercise Header & Reorder
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: palette.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Egzersiz Blokları (${_exercises.length})',
                          style: SwanType.h3(palette.ink),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 16, color: palette.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Sırala',
                          style:
                              SwanType.caption(palette.accent, w: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Exercise Cards
                for (int i = 0; i < _exercises.length; i++) ...[
                  _buildExerciseCard(palette, _exercises[i], i + 1),
                  const SizedBox(height: 14),
                ],

                // 4. Add New Exercise Button
                _buildAddExerciseButton(palette),
                const SizedBox(height: 18),

                // 5. SwanAI Coach Analysis Card
                _buildAiCoachCard(palette),
                const SizedBox(height: 20),
              ],
            ),

            // 6. Fixed Bottom Floating HUD
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildBottomHud(palette),
            ),
          ],
        ),
      ),
    );
  }

  // --- Context Nav Strip ---
  Widget _buildContextStrip(SwanPalette palette) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.line),
              ),
              child: Icon(Icons.edit_note_rounded, size: 20, color: palette.accent),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ANTRENMAN TASARIMI',
                  style: SwanType.caption(palette.accent, w: FontWeight.w800),
                ),
                Text(
                  'Özel Seans Oluşturucu',
                  style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Antrenman şablonu başarıyla kaydedildi!')),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kTealBright, kTeal]),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: kTeal.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_done_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  'Kaydet',
                  style: SwanType.caption(Colors.white, w: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // --- Basic Info Card ---
  Widget _buildBasicInfoCard(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PROGRAM ADI',
                style: SwanType.caption(palette.inkMuted, w: FontWeight.w700),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: palette.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Taslak Modu',
                      style: SwanType.caption(palette.accent, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Live Title Input Field
          Container(
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.line),
            ),
            child: TextField(
              controller: _titleController,
              style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: InputBorder.none,
                suffixIcon: Icon(Icons.edit_rounded,
                    size: 18, color: palette.inkMuted),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Quick Metrics Strip
          Row(
            children: [
              Expanded(
                child: _metricTile(
                  palette,
                  icon: Icons.fitness_center_rounded,
                  iconColor: palette.accent,
                  label: 'Kategori',
                  value: _category,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  palette,
                  icon: Icons.speed_rounded,
                  iconColor: const Color(0xFFFF7A59),
                  label: 'Zorluk',
                  value: _difficulty,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _metricTile(
                  palette,
                  icon: Icons.schedule_rounded,
                  iconColor: palette.accent,
                  label: 'Süre',
                  value: _duration,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricTile(
    SwanPalette palette, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: SwanType.caption(palette.inkMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: SwanType.bodySm(palette.ink, w: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- Muscle Groups Section ---
  Widget _buildMuscleGroupsSection(SwanPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'HEDEF KAS GRUPLARI',
              style: SwanType.caption(palette.inkMuted, w: FontWeight.w700),
            ),
            Text(
              '${_muscleGroups.length} Odak Seçili',
              style: SwanType.caption(palette.accent, w: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final mg in _muscleGroups)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mg,
                      style: SwanType.caption(palette.accent, w: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _muscleGroups.remove(mg);
                        });
                      },
                      child: Icon(Icons.close_rounded,
                          size: 14, color: palette.inkMuted),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: palette.line),
              ),
              child: Text(
                '#PushDay',
                style: SwanType.caption(palette.inkMuted, w: FontWeight.w600),
              ),
            ),
            GestureDetector(
              onTap: () {
                _showAddTagDialog(context, palette);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: palette.accent.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: palette.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Etiket Ekle',
                      style:
                          SwanType.caption(palette.accent, w: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddTagDialog(BuildContext context, SwanPalette palette) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.surface,
        title: Text('Yeni Hedef Bölge Ekle', style: SwanType.h3(palette.ink)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Örn: Biceps, Sırt, Core'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _muscleGroups.add(controller.text.trim());
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  // --- Exercise Card with Set Matrix ---
  Widget _buildExerciseCard(
      SwanPalette palette, _ExerciseItem exercise, int index) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Icon(
                  Icons.fitness_center_rounded,
                  size: 20,
                  color: palette.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '#$index',
                          style: SwanType.caption(palette.inkMuted,
                              w: FontWeight.w800),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            exercise.title,
                            style:
                                SwanType.bodySm(palette.ink, w: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'Dinlenme: ${exercise.restSeconds} sn',
                          style: SwanType.caption(palette.inkMuted),
                        ),
                        const SizedBox(width: 6),
                        Text('•', style: SwanType.caption(palette.inkMuted)),
                        const SizedBox(width: 6),
                        Text(
                          'Hedef: ${exercise.targetRpe}',
                          style: SwanType.caption(const Color(0xFFFF7A59),
                              w: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert_rounded,
                    size: 18, color: palette.inkMuted),
                onPressed: () {},
              ),
            ],
          ),
          if (exercise.supersetName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SÜPER SET',
                          style: SwanType.caption(Colors.white,
                              w: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        exercise.supersetName!,
                        style: SwanType.caption(palette.ink,
                            w: FontWeight.w700),
                      ),
                    ],
                  ),
                  Text(
                    'Dinlenmesiz Geçiş',
                    style: SwanType.caption(palette.inkMuted),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Tactile Set Matrix Table
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.line),
            ),
            child: Column(
              children: [
                // Table Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(
                          'SET',
                          style: SwanType.caption(palette.inkMuted,
                              w: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'YÜK',
                          style: SwanType.caption(palette.inkMuted,
                              w: FontWeight.w700),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'TEKRAR',
                          style: SwanType.caption(palette.inkMuted,
                              w: FontWeight.w700),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          'DURUM',
                          textAlign: TextAlign.end,
                          style: SwanType.caption(palette.inkMuted,
                              w: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // Set Rows
                for (final s in exercise.sets)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      color: s.isDropSet
                          ? const Color(0xFFFF7A59).withValues(alpha: 0.12)
                          : palette.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: s.isDropSet
                          ? Border.all(
                              color: const Color(0xFFFF7A59)
                                  .withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${s.setNum}',
                            style: SwanType.caption(
                              s.isDropSet
                                  ? const Color(0xFFFF7A59)
                                  : palette.accent,
                              w: FontWeight.w800,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${s.loadKg} kg',
                            style: SwanType.caption(
                              s.isDropSet
                                  ? const Color(0xFFFF7A59)
                                  : palette.ink,
                              w: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            s.reps,
                            style: SwanType.caption(
                              s.isDropSet
                                  ? const Color(0xFFFF7A59)
                                  : palette.ink,
                              w: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: s.isDropSet
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF7A59),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'DROP',
                                      style: SwanType.caption(Colors.white,
                                          w: FontWeight.w800),
                                    ),
                                  )
                                : Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: s.isCompleted
                                          ? palette.accent
                                              .withValues(alpha: 0.2)
                                          : palette.surfaceAlt,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: s.isCompleted
                                          ? palette.accent
                                          : palette.inkMuted,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    final nextSetNum = exercise.sets.length + 1;
                    exercise.sets.add(
                      _SetItem(
                        setNum: nextSetNum,
                        loadKg: exercise.sets.last.loadKg,
                        reps: '10',
                        isCompleted: false,
                      ),
                    );
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: palette.line),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: palette.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Set Ekle',
                        style: SwanType.caption(palette.accent,
                            w: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.timelapse_rounded,
                      size: 14, color: palette.inkMuted),
                  const SizedBox(width: 4),
                  Text(
                    '${exercise.sets.length} Set Toplam',
                    style: SwanType.caption(palette.inkMuted),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Add Exercise Wide Button ---
  Widget _buildAddExerciseButton(SwanPalette palette) {
    return GestureDetector(
      onTap: () {
        setState(() {
          final nextId = '${_exercises.length + 1}';
          _exercises.add(
            _ExerciseItem(
              id: nextId,
              title: 'Yeni Egzersiz',
              restSeconds: 60,
              targetRpe: 'RPE 8.0',
              sets: [
                _SetItem(setNum: 1, loadKg: 50, reps: '10', isCompleted: false),
                _SetItem(setNum: 2, loadKg: 50, reps: '10', isCompleted: false),
                _SetItem(setNum: 3, loadKg: 50, reps: '10', isCompleted: false),
              ],
            ),
          );
        });
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.line),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, size: 16, color: palette.accent),
            ),
            const SizedBox(width: 8),
            Text(
              'Yeni Egzersiz Ekle',
              style: SwanType.bodySm(palette.accent, w: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  // --- SwanAI Coach Analysis Card ---
  Widget _buildAiCoachCard(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
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
                  color: palette.accent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy_rounded,
                    size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                'SWANAI ANTRENÖR ANALİZİ',
                style: SwanType.caption(palette.accent, w: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: SwanType.caption(palette.ink).copyWith(height: 1.5),
              children: [
                const TextSpan(
                  text:
                      'Bu antrenman dünkü sırt hacminizle mükemmel bir ',
                ),
                TextSpan(
                  text: 'push/pull dengesi',
                  style: TextStyle(
                      color: palette.accent, fontWeight: FontWeight.bold),
                ),
                const TextSpan(
                  text:
                      ' sağlıyor. Göğüs lifleri için beklenen toparlanma süresi 48 saat.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded,
                      size: 16, color: Color(0xFFFF7A59)),
                  const SizedBox(width: 4),
                  Text(
                    'Tahmini Yakım: ',
                    style: SwanType.caption(palette.inkMuted),
                  ),
                  Text(
                    '580 kcal',
                    style: SwanType.caption(palette.ink, w: FontWeight.w800),
                  ),
                ],
              ),
              Row(
                children: [
                  Icon(Icons.analytics_rounded, size: 16, color: palette.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Yoğunluk: ',
                    style: SwanType.caption(palette.inkMuted),
                  ),
                  Text(
                    'Yüksek',
                    style: SwanType.caption(palette.ink, w: FontWeight.w800),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Bottom Floating HUD ---
  Widget _buildBottomHud(SwanPalette palette) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).pushNamed('/antrenman-oturumu');
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kTeal.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow_rounded,
                        size: 22, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Şimdi Başlat',
                      style: SwanType.bodySm(Colors.white, w: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seans takvime eklendi.')),
              );
            },
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: palette.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.line),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 18, color: palette.ink),
                  const SizedBox(width: 6),
                  Text(
                    'Takvime Ekle',
                    style: SwanType.caption(palette.ink, w: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseItem {
  _ExerciseItem({
    required this.id,
    required this.title,
    required this.restSeconds,
    required this.targetRpe,
    required this.sets,
    this.supersetName,
  });

  final String id;
  final String title;
  final int restSeconds;
  final String targetRpe;
  final String? supersetName;
  final List<_SetItem> sets;
}

class _SetItem {
  _SetItem({
    required this.setNum,
    required this.loadKg,
    required this.reps,
    this.isDropSet = false,
    this.isCompleted = false,
  });

  final int setNum;
  final int loadKg;
  final String reps;
  final bool isDropSet;
  final bool isCompleted;
}