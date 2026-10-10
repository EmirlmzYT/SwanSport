import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

/// Official history has no edit/delete callbacks, even for club managers.
class OfficialAthleteCv extends ConsumerWidget {
  const OfficialAthleteCv(
      {super.key, required this.athleteId, this.includeClub = false});
  final String athleteId;
  final bool includeClub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? SwanPalette.dark
        : SwanPalette.light;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Resmi Federasyon Dereceleri', style: SwanType.h3(c.ink)),
      const SizedBox(height: SwanSpace.sm),
      ref.watch(officialAchievementsProvider(athleteId)).when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => error is OfficialCvAccessDenied
                ? Text(
                    'Resmi sicil sporcu, bağlı veli ve yetkili kulüp personeline açıktır.',
                    style: SwanType.bodySm(c.inkMuted))
                : TextButton.icon(
                    onPressed: () =>
                        ref.invalidate(officialAchievementsProvider(athleteId)),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Resmi sicil yüklenemedi. Yeniden dene'),
                  ),
            data: (rows) => rows.isEmpty
                ? Text('Yayımlanmış resmi derece yok.',
                    style: SwanType.bodySm(c.inkMuted))
                : Column(children: [
                    for (final row in rows.where((a) => a.isOfficial))
                      OfficialAchievementTile(achievement: row)
                  ]),
          ),
      if (includeClub) ...[
        const SizedBox(height: SwanSpace.xl),
        Text('Kulüp Başarıları', style: SwanType.h3(c.ink)),
        ref.watch(achievementsProvider(athleteId)).when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => Text('Kulüp başarıları yüklenemedi.',
                  style: SwanType.bodySm(c.inkMuted)),
              data: (rows) => Column(children: [
                for (final a in rows.where((a) => !a.isOfficial))
                  ListTile(
                      title: Text(a.title, style: SwanType.body(c.ink)),
                      subtitle: Text(a.sourceLabel,
                          style: SwanType.caption(c.inkMuted)))
              ]),
            ),
      ],
    ]);
  }
}

class OfficialAchievementTile extends StatelessWidget {
  const OfficialAchievementTile({super.key, required this.achievement});
  final Achievement achievement;
  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final c = Theme.of(context).brightness == Brightness.dark
        ? SwanPalette.dark
        : SwanPalette.light;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: SwanSpace.sm),
      leading: Icon(Icons.verified_user_rounded,
          color: c.success, semanticLabel: 'Onaylı resmi federasyon kaydı'),
      title: Text(a.title, style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
      subtitle: Text(
          [
            'Resmi Federasyon Derecesi',
            if (a.sportCode != null) _sport(a.sportCode!),
            if (a.eventDate != null) _date(a.eventDate!),
            if (a.placement != null) '${a.placement}. (seri)',
            if (a.note != null) a.note!,
          ].join(' · '),
          style: SwanType.caption(c.inkMuted)),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => _OfficialSourceSheet(achievementId: a.id)),
    );
  }
}

class _OfficialSourceSheet extends ConsumerWidget {
  const _OfficialSourceSheet({required this.achievementId});
  final String achievementId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).brightness == Brightness.dark
        ? SwanPalette.dark
        : SwanPalette.light;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(SwanSpace.xl),
        child: ref.watch(officialAchievementSourceProvider(achievementId)).when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) =>
                  Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Resmi müsabaka yüklenemedi.',
                    style: SwanType.body(c.ink)),
                TextButton(
                    onPressed: () => ref.invalidate(
                        officialAchievementSourceProvider(achievementId)),
                    child: const Text('Yeniden dene')),
              ]),
              data: (source) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Icon(Icons.verified_user_rounded, color: c.success),
                      const SizedBox(width: SwanSpace.sm),
                      Expanded(
                          child: Text('Kaynak Resmi Müsabaka',
                              style: SwanType.h3(c.ink)))
                    ]),
                    const SizedBox(height: SwanSpace.lg),
                    Text(source.name, style: SwanType.h2(c.ink)),
                    Text(_sport(source.sportCode),
                        style: SwanType.body(c.inkMuted)),
                    if (source.startsAt != null)
                      Text(_date(calendarTurkeyTime(source.startsAt!)),
                          style: SwanType.bodySm(c.ink)),
                    if (source.location != null)
                      Text(source.location!, style: SwanType.bodySm(c.ink)),
                    for (final score in source.scores)
                      Text('${score.label}: ${score.home}–${score.away}',
                          style: SwanType.bodySm(c.ink)),
                    if (source.result != null)
                      Text(source.result!, style: SwanType.body(c.ink)),
                    const SizedBox(height: SwanSpace.lg),
                    Text(
                        'Resmi sonuç revizyonu ${source.version}. Bu kayıt değiştirilemez.',
                        style: SwanType.caption(c.inkMuted)),
                    if (source.version != source.currentVersion)
                      Text('Daha yeni bir resmi sonuç revizyonu bulunuyor.',
                          style: SwanType.bodySm(c.inkMuted)),
                    Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Kapat'))),
                  ]),
            ));
  }
}

String _date(DateTime d) => '${d.day}.${d.month}.${d.year}';
String _sport(String code) =>
    const {
      'basketbol': 'Basketbol',
      'futbol': 'Futbol',
      'tenis': 'Tenis',
      'okculuk': 'Okçuluk',
      'yuzme': 'Yüzme',
      'atletizm': 'Atletizm'
    }[code] ??
    code;
