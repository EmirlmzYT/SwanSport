import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import 'social_widgets.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/design/swan_palette.dart';

/// Antrenör künyesi — kademe, kulüpler ve deneyim.
///
/// Sporcuda "künye + başarılar" varken antrenörde karşılığı buydu; boş kalmasın.
class CoachProfileSection extends ConsumerWidget {
  const CoachProfileSection({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubs = ref.watch(coachClubsProvider(profileId)).valueOrNull;
    if (clubs == null || clubs.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    // En yüksek kademe ve en eski katılım tarihi künyeyi belirler.
    final topLevel = clubs
        .map((c) => c.level ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    final since = clubs
        .map((c) => c.since)
        .whereType<DateTime>()
        .fold<DateTime?>(null, (a, b) => a == null || b.isBefore(a) ? b : a);
    final years =
        since == null ? null : DateTime.now().difference(since).inDays ~/ 365;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Text('Antrenörlük', style: SwanType.h3(ink)),
        const SizedBox(height: 10),
        Container(
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
                    gradient: const LinearGradient(
                        colors: [Color(0xFF9E7BFF), Color(0xFF6D45C4)]),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(Icons.sports_rounded,
                      size: 21, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          topLevel > 0
                              ? '$topLevel. Kademe Antrenör'
                              : 'Antrenör',
                          style: SwanType.bodySm(ink, w: FontWeight.w800)),
                      Text(
                          clubs.length == 1
                              ? clubs.first.clubName
                              : '${clubs.length} kulüpte görevli',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.caption(SwanColors.textSecondary)),
                    ],
                  ),
                ),
                if (years != null && years > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('$years yıl',
                        style: SwanType.caption(kTeal, w: FontWeight.w800)),
                  ),
              ]),
              const SizedBox(height: 14),
              ...clubs.map((c) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () => Navigator.pushNamed(
                          context, '/kulup-profil',
                          arguments: c.clubId),
                      child: Row(children: [
                        const Icon(Icons.account_balance_rounded,
                            size: 16, color: kTeal),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(c.clubName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: SwanType.caption(ink, w: FontWeight.w700)),
                        ),
                        if (c.level != null)
                          Text('${c.level}. kademe',
                              style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700)),
                      ]),
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kulüp profilindeki kadro listesi.
class ClubMembersSection extends ConsumerWidget {
  const ClubMembersSection({super.key, required this.clubId});

  final String clubId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(clubMembersProvider(clubId)).valueOrNull;
    if (members == null || members.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: Text('Kadro', style: SwanType.h3(ink)),
          ),
          Text('${members.length} kişi',
              style:
                  SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        ...members.take(12).map((m) => GestureDetector(
              onTap: () =>
                  Navigator.pushNamed(context, '/profil', arguments: m.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: line),
                ),
                child: Row(children: [
                  SocialAvatar(
                      initials: m.name.isNotEmpty
                          ? m.name[0].toUpperCase()
                          : '?',
                      imageUrl: m.avatarUrl,
                      size: 38,
                      gradientIndex: m.name.length % 4),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(ink, w: FontWeight.w700)),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(m.role,
                        style: SwanType.caption(kTeal, w: FontWeight.w800)),
                  ),
                ]),
              ),
            )),
        if (members.length > 12)
          Text('ve ${members.length - 12} kişi daha',
              style:
                  SwanType.caption(SwanColors.textSecondary)),
      ],
    );
  }
}
