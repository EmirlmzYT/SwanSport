import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/quick_form.dart';

/// Profil sayfasındaki "Sporcu" bölümü — künye + başarılar.
///
/// Sportif bilgileri kulüp (ferdi sporcuda kişinin kendisi) düzenler;
/// düzenleme düğmeleri yalnızca yetkiliye görünür.
class AthleteProfileSection extends ConsumerWidget {
  const AthleteProfileSection({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final athlete = ref.watch(athleteByProfileProvider(profileId)).valueOrNull;
    if (athlete == null) return const SizedBox.shrink();

    final canManage =
        ref.watch(canManageAthleteProvider(athlete.id)).valueOrNull ?? false;
    final achievements =
        ref.watch(achievementsProvider(athlete.id)).valueOrNull ?? const [];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: Text('SPORCU KÜNYESİ',
                style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                    ls: 1.2)),
          ),
          if (canManage)
            GestureDetector(
              onTap: () => _editInfo(context, ref, athlete),
              child: Row(children: [
                const Icon(Icons.edit_rounded, size: 15, color: kTeal),
                const SizedBox(width: 5),
                Text('Düzenle', style: jakarta(12, FontWeight.w800, kTeal)),
              ]),
            ),
        ]),
        const SizedBox(height: 10),
        _card(context, isDark, athlete),

        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: Text('BAŞARILAR',
                style: jakarta(11, FontWeight.w700, SwanColors.textSecondary,
                    ls: 1.2)),
          ),
          if (canManage)
            GestureDetector(
              onTap: () => _addAchievement(context, ref, athlete.id),
              child: Row(children: [
                const Icon(Icons.add_rounded, size: 16, color: kTeal),
                const SizedBox(width: 4),
                Text('Ekle', style: jakarta(12, FontWeight.w800, kTeal)),
              ]),
            ),
        ]),
        const SizedBox(height: 10),
        if (achievements.isEmpty)
          _emptyAchievements(isDark, canManage)
        else
          ...achievements.map(
              (a) => _achievement(context, ref, isDark, a, canManage)),

        if (!canManage && athlete.clubName != null) ...[
          const SizedBox(height: 6),
          Text('Sportif bilgileri kulüp yönetir.',
              style:
                  jakarta(10.5, FontWeight.w500, SwanColors.textSecondary)),
        ],
        const SizedBox(height: 4),
        Text('', style: jakarta(1, FontWeight.w400, ink)),
      ],
    );
  }

  // ------------------------------------------------------------- künye
  Widget _card(BuildContext context, bool isDark, AthleteSportInfo a) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final chips = <(String, String)>[
      if (a.branch != null) ('Branş', a.branch!),
      if (a.position != null) ('Mevki', a.position!),
      if (a.jerseyNumber != null) ('Forma', '#${a.jerseyNumber}'),
      if (a.heightCm != null) ('Boy', '${a.heightCm} cm'),
      if (a.weightKg != null) ('Kilo', '${a.weightKg} kg'),
      if (a.dominantSide != null) ('Kullandığı taraf', a.dominantSide!),
      if (a.yearsActive != null) ('Tecrübe', '${a.yearsActive} yıl'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kTealBright, kTealDeep]),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                  a.isIndividual
                      ? Icons.directions_run_rounded
                      : Icons.sports_rounded,
                  size: 21,
                  color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.isIndividual ? 'Ferdi Sporcu' : 'Lisanslı Sporcu',
                      style: jakarta(13.5, FontWeight.w800, ink)),
                  Text(a.clubName ?? 'Kulübe bağlı değil',
                      style: jakarta(
                          11.5, FontWeight.w500, SwanColors.textSecondary)),
                ],
              ),
            ),
            if (a.status == 'active')
              const PremiumStatusChip(
                  label: 'Aktif',
                  color: Color(0xFF10B981),
                  icon: Icons.check_circle_rounded),
          ]),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.map((c) => _chip(isDark, c.$1, c.$2)).toList(),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Text('Henüz künye bilgisi girilmemiş.',
                style: jakarta(
                    12, FontWeight.w500, SwanColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  Widget _chip(bool isDark, String label, String value) {
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: alt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: jakarta(9, FontWeight.w800, SwanColors.textSecondary,
                  ls: .8)),
          const SizedBox(height: 2),
          Text(value, style: jakarta(13, FontWeight.w800, ink)),
        ],
      ),
    );
  }

  // --------------------------------------------------------- başarılar
  Widget _emptyAchievements(bool isDark, bool canManage) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(children: [
        Icon(Icons.emoji_events_outlined,
            size: 30, color: SwanColors.textSecondary),
        const SizedBox(height: 8),
        Text(
            canManage
                ? 'Henüz başarı eklenmemiş. Yukarıdaki “Ekle” ile başla.'
                : 'Henüz başarı eklenmemiş.',
            textAlign: TextAlign.center,
            style: jakarta(12, FontWeight.w500, SwanColors.textSecondary)),
      ]),
    );
  }

  Widget _achievement(BuildContext context, WidgetRef ref, bool isDark,
      Achievement a, bool canManage) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final medal = switch (a.placement) {
      1 => const Color(0xFFE9B949),
      2 => const Color(0xFFB6C2CF),
      3 => const Color(0xFFCD7F32),
      _ => kTeal,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: a.isPodium ? medal.withValues(alpha: .45) : line),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: medal.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
              a.isPodium
                  ? Icons.emoji_events_rounded
                  : Icons.workspace_premium_rounded,
              size: 20,
              color: medal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(13.5, FontWeight.w800, ink)),
              const SizedBox(height: 2),
              Text(
                  [
                    if (a.placement != null) a.placementLabel else a.categoryLabel,
                    if (a.eventDate != null) _date(a.eventDate!),
                    if (a.location != null) a.location!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: jakarta(
                      11.5, FontWeight.w500, SwanColors.textSecondary)),
              if (a.note != null && a.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(a.note!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(
                        11.5, FontWeight.w500, SwanColors.textSecondary)),
              ],
            ],
          ),
        ),
        if (canManage)
          GestureDetector(
            onTap: () async {
              await ref
                  .read(athleteProfileServiceProvider)
                  .removeAchievement(a.id);
              ref.invalidate(achievementsProvider(a.athleteId));
            },
            child: Icon(Icons.delete_outline_rounded,
                size: 18, color: SwanColors.textSecondary),
          ),
      ]),
    );
  }

  String _date(DateTime d) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  // ----------------------------------------------------------- formlar
  Future<void> _editInfo(
      BuildContext context, WidgetRef ref, AthleteSportInfo a) async {
    final branch = FormField_('Branş',
        hint: 'Futbol / Voleybol / Atletizm', required: false)
      ..controller.text = a.branch ?? '';
    final position = FormField_('Mevki', hint: 'Forvet', required: false)
      ..controller.text = a.position ?? '';
    final jersey = FormField_('Forma numarası',
        hint: '10', required: false, keyboard: TextInputType.number)
      ..controller.text = a.jerseyNumber?.toString() ?? '';
    final height = FormField_('Boy (cm)',
        hint: '178', required: false, keyboard: TextInputType.number)
      ..controller.text = a.heightCm?.toString() ?? '';
    final weight = FormField_('Kilo (kg)',
        hint: '72',
        required: false,
        keyboard: const TextInputType.numberWithOptions(decimal: true))
      ..controller.text = a.weightKg?.toString() ?? '';
    final side = FormField_('Kullandığı taraf',
        hint: 'Sağ / Sol / Çift', required: false)
      ..controller.text = a.dominantSide ?? '';

    final ok = await showQuickForm(
      context,
      title: 'Sporcu Künyesi',
      note: 'Bu bilgileri kulüp yönetir. Boş bıraktığın alanlar değişmez.',
      fields: [branch, position, jersey, height, weight, side],
      onSubmit: () => ref.read(athleteProfileServiceProvider).updateSportInfo(
            a.id,
            branch: branch.value.isEmpty ? null : branch.value,
            position: position.value.isEmpty ? null : position.value,
            jersey: int.tryParse(jersey.value),
            height: int.tryParse(height.value),
            weight: num.tryParse(weight.value.replaceAll(',', '.')),
            dominantSide: side.value.isEmpty ? null : side.value,
          ),
    );
    if (ok == true) ref.invalidate(athleteByProfileProvider(profileId));
  }

  Future<void> _addAchievement(
      BuildContext context, WidgetRef ref, String athleteId) async {
    final title = FormField_('Başlık', hint: 'Türkiye Şampiyonası');
    final placement = FormField_('Derece',
        hint: '1', required: false, keyboard: TextInputType.number);
    final date = FormField_('Tarih', hint: '2026-05-14', required: false);
    final location = FormField_('Yer', hint: 'Ankara', required: false);
    final note = FormField_('Not', hint: 'Kısa açıklama', required: false);

    final ok = await showQuickForm(
      context,
      title: 'Başarı Ekle',
      note: 'Derece alanı boş bırakılabilir (ödül, rekor, seçilme için).',
      fields: [title, placement, date, location, note],
      onSubmit: () => ref.read(athleteProfileServiceProvider).addAchievement(
            athleteId: athleteId,
            title: title.value,
            placement: int.tryParse(placement.value),
            eventDate: DateTime.tryParse(date.value),
            location: location.value.isEmpty ? null : location.value,
            note: note.value.isEmpty ? null : note.value,
          ),
    );
    if (ok == true) ref.invalidate(achievementsProvider(athleteId));
  }
}
