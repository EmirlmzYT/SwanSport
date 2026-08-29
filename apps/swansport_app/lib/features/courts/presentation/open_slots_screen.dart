import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';

/// Oyuncu aranan oyunlar.
///
/// Tek başına gelen biri için sistemin en değerli tarafı bu: kort bulmak
/// kadar oynayacak birini bulmak da dert.
class OpenSlotsScreen extends ConsumerWidget {
  const OpenSlotsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final async = ref.watch(openSlotsProvider(null));
    final verified =
        ref.watch(swanAccessProvider).hasVerificationTier('location');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text('Oyuncu aranıyor', style: sora(19, FontWeight.w800, ink)),
      ),
      body: async.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (slots) {
          if (slots.isEmpty) {
            return premiumEmpty(
              context,
              icon: Icons.group_add_rounded,
              title: 'Şu an oyuncu arayan yok',
              subtitle:
                  'Sen saat alırken "oyuncu arıyorum" dersen burada görünürsün.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(openSlotsProvider(null)),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: slots.length,
              itemBuilder: (_, i) =>
                  _card(context, ref, isDark, ink, slots[i], verified),
            ),
          );
        },
      ),
    );
  }

  Widget _card(BuildContext context, WidgetRef ref, bool isDark, Color ink,
      OpenSlot s, bool verified) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final hour = '${s.startsAt.hour.toString().padLeft(2, '0')}:'
        '${s.startsAt.minute.toString().padLeft(2, '0')}';
    final where = [
      if ((s.venue ?? '').isNotEmpty) s.venue!,
      if ((s.cityName ?? '').isNotEmpty) s.cityName!,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$hour · ${s.courtName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(14, FontWeight.w800, ink)),
                const SizedBox(height: 3),
                Text([s.ownerName, if (where.isNotEmpty) where].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: jakarta(
                        11.5, FontWeight.w600, SwanColors.textSecondary)),
              ],
            ),
          ),
          PremiumStatusChip(
              label: '${s.remaining} kişi',
              color: const Color(0xFFD9860B),
              icon: Icons.group_add_rounded),
        ]),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: (s.requested || !verified)
              ? null
              : () async {
                  try {
                    await ref.read(courtServiceProvider).requestJoin(s.slotId);
                    ref.invalidate(openSlotsProvider(null));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'İsteğin gönderildi. Sahibi onaylayınca haber vereceğiz.')));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
          child: Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: (s.requested || !verified)
                  ? null
                  : const LinearGradient(colors: [kTealBright, kTeal]),
              borderRadius: BorderRadius.circular(12),
              border: (s.requested || !verified)
                  ? Border.all(color: line)
                  : null,
            ),
            child: Text(
                s.requested
                    ? 'İstek gönderildi'
                    : (verified
                        ? 'Katılmak istiyorum'
                        : 'Önce kortta doğrulanmalısın'),
                style: jakarta(
                    12.5,
                    FontWeight.w800,
                    (s.requested || !verified)
                        ? SwanColors.textSecondary
                        : Colors.white)),
          ),
        ),
      ]),
    );
  }
}
