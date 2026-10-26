import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_feature_host.dart';

class SharedAttendanceQueueBanner extends ConsumerWidget {
  const SharedAttendanceQueueBanner({super.key});

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
    return ListTile(
      leading: const Icon(Icons.cloud_upload_outlined),
      title: Text(
        '$pending yoklama gönderimi, $drafts cihaz taslağı bekliyor',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: ProFeatureHostScope.of(context).navigator.openAttendance,
    );
  }
}
