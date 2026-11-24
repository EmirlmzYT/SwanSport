import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

/// App'e ait hafif yoklama kuyruğu özeti.
///
/// Kuyruk ve özellik bayrağı iki ürünün ortak veri katmanından gelir; görünüm
/// ve rota ise sosyal mobil App'e aittir. Ayrıntılı operasyon ekranları Pro'da
/// kalırken App çevrimdışı taslakların kaybolmadığını kullanıcıya bildirir.
class AttendanceQueueBanner extends ConsumerWidget {
  const AttendanceQueueBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      featureEnabledProvider(FeatureFlags.attendanceOperations),
    );
    if (!enabled) return const SizedBox.shrink();

    final data = ref.watch(attendanceLocalDataProvider).valueOrNull;
    final pending =
        data?['ops']?.where((row) => row['state'] != 'done').length ?? 0;
    final drafts =
        data?['drafts']?.map((row) => row['event_id']).toSet().length ?? 0;
    if (pending + drafts == 0) return const SizedBox.shrink();

    final palette = context.swan;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
      child: Material(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(SwanRadius.md),
          onTap: () => Navigator.pushNamed(context, '/attendance'),
          child: Padding(
            padding: const EdgeInsets.all(SwanSpace.md),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(SwanSpace.sm),
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                  ),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(width: SwanSpace.md),
                Expanded(
                  child: Text(
                    '$pending yoklama gönderimi, '
                    '$drafts cihaz taslağı bekliyor',
                    style: SwanType.bodySm(palette.ink),
                  ),
                ),
                Icon(Icons.chevron_right, color: palette.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
