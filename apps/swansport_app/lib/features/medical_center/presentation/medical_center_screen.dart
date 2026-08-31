import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../../app/widgets/quick_form.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Sağlık Merkezi — sporcuların sakatlık/uygunluk kayıtları.
///
/// Eskiden sabit örnek verilerle doluydu; artık `injuries` tablosundan okuyor
/// ve kayıt eklenip güncellenebiliyor.
class MedicalCenterScreen extends ConsumerStatefulWidget {
  const MedicalCenterScreen({super.key});

  @override
  ConsumerState<MedicalCenterScreen> createState() =>
      _MedicalCenterScreenState();
}

class _MedicalCenterScreenState extends ConsumerState<MedicalCenterScreen> {
  /// Durum → (etiket, renk, ikon). Renk tek başına anlam taşımasın diye her
  /// durum ikon ve yazıyla birlikte gösteriliyor.
  static const _states = {
    'injured': ('Sakat', Color(0xFFF43F5E), Icons.personal_injury_rounded),
    'pending': ('Takipte', Color(0xFFD9860B), Icons.help_rounded),
    'fit': ('Sağlam', Color(0xFF10B981), Icons.check_circle_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final async = ref.watch(injuriesProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(injuriesProvider);
                await ref.read(injuriesProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                children: [
                  Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('KULÜP',
                              style: jakarta(
                                  11, FontWeight.w700, SwanColors.textSecondary,
                                  ls: 1.4)),
                          const SizedBox(height: 3),
                          Text('Sağlık Merkezi',
                              style: sora(25, FontWeight.w800, ink)),
                        ],
                      ),
                    ),
                    AddButton(onTap: _addRecord, tooltip: 'Kayıt ekle'),
                  ]),
                  const SizedBox(height: 18),
                  async.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) {
                      if (list.isEmpty) {
                        return premiumEmpty(
                          context,
                          icon: Icons.medical_services_rounded,
                          title: 'Sağlık kaydı yok',
                          subtitle:
                              'Sakatlanan ya da durumu izlenen sporcular için '
                              'kayıt ekle.',
                          actionLabel: 'Kayıt ekle',
                          onAction: _addRecord,
                        );
                      }
                      return Column(children: [
                        _summary(isDark, ink, list),
                        const SizedBox(height: 18),
                        for (final r in list) _row(isDark, ink, r),
                      ]);
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

  Widget _summary(bool isDark, Color ink, List<InjuryRow> list) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    int count(String s) => list.where((r) => r.status == s).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Row(children: [
        for (final e in _states.entries)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(e.value.$3, size: 14, color: e.value.$2),
                  const SizedBox(width: 5),
                  Text('${count(e.key)}',
                      style: sora(20, FontWeight.w800, ink)),
                ]),
                const SizedBox(height: 2),
                Text(e.value.$1,
                    style: jakarta(
                        10.5, FontWeight.w600, SwanColors.textSecondary)),
              ],
            ),
          ),
      ]),
    );
  }

  Widget _row(bool isDark, Color ink, InjuryRow r) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final st = _states[r.status] ?? _states['fit']!;

    return GestureDetector(
      onTap: () => _actions(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: st.$2.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(st.$3, size: 19, color: st.$2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(r.athleteName,
                    style: jakarta(13.5, FontWeight.w800, ink)),
                const SizedBox(height: 2),
                Text(
                    r.note?.trim().isNotEmpty == true
                        ? r.note!
                        : '${r.createdAt.day}.${r.createdAt.month}.${r.createdAt.year}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(
                        11, FontWeight.w500, SwanColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PremiumStatusChip(label: st.$1, color: st.$2, icon: st.$3),
        ]),
      ),
    );
  }

  Future<void> _addRecord() async {
    final athletes = ref.read(clubAthletesProvider).valueOrNull ?? const [];
    if (athletes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kadroda sporcu yok'),
          backgroundColor: Color(0xFFF43F5E)));
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final athleteId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(children: [
          Text('Hangi sporcu?', style: sora(17, FontWeight.w800, ink)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: athletes.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(athletes[i].fullName,
                    style: jakarta(13, FontWeight.w600, ink)),
                onTap: () => Navigator.pop(ctx, athletes[i].id),
              ),
            ),
          ),
        ]),
      ),
    );
    if (athleteId == null) return;

    final status = await _pickStatus();
    if (status == null) return;

    final note = FormField_('Not', hint: 'Ayak bileği burkulması',
        required: false);
    await showQuickForm(
      context,
      title: 'Sağlık kaydı',
      fields: [note],
      onSubmit: () => _guard(() async {
        final club = ref.read(activeClubProvider).valueOrNull;
        if (club == null) return;
        await ref
            .read(clubOpsServiceProvider)
            .addInjury(club.id, athleteId, status, note: note.value);
        ref.invalidate(injuriesProvider);
      }, 'Kayıt eklendi'),
    );
  }

  Future<String?> _pickStatus() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return showModalBottomSheet<String>(
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
          Text('Durum', style: sora(17, FontWeight.w800, ink)),
          const SizedBox(height: 8),
          for (final e in _states.entries)
            ListTile(
              leading: Icon(e.value.$3, color: e.value.$2),
              title: Text(e.value.$1,
                  style: jakarta(13.5, FontWeight.w600, ink)),
              onTap: () => Navigator.pop(ctx, e.key),
            ),
        ]),
      ),
    );
  }

  Future<void> _actions(InjuryRow r) async {
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
          Text(r.athleteName, style: sora(17, FontWeight.w800, ink)),
          const SizedBox(height: 12),
          for (final e in _states.entries)
            if (e.key != r.status)
              ListTile(
                dense: true,
                leading: Icon(e.value.$3, color: e.value.$2, size: 20),
                title: Text('${e.value.$1} olarak işaretle',
                    style: jakarta(13, FontWeight.w600, ink)),
                onTap: () {
                  Navigator.pop(ctx);
                  _guard(() async {
                    await ref
                        .read(clubOpsServiceProvider)
                        .updateInjury(r.id, status: e.key);
                    ref.invalidate(injuriesProvider);
                  }, 'Durum güncellendi');
                },
              ),
          const Divider(height: 18),
          ListTile(
            dense: true,
            leading: const Icon(Icons.delete_outline_rounded,
                size: 20, color: Color(0xFFF43F5E)),
            title: Text('Kaydı sil',
                style: jakarta(13, FontWeight.w700, const Color(0xFFF43F5E))),
            onTap: () {
              Navigator.pop(ctx);
              _guard(() async {
                await ref.read(clubOpsServiceProvider).removeInjury(r.id);
                ref.invalidate(injuriesProvider);
              }, 'Kayıt silindi');
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
