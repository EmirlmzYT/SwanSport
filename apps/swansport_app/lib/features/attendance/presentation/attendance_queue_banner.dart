import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

/// A pending-work status row, not an extra home task card.
class AttendanceQueueBanner extends ConsumerWidget {
  const AttendanceQueueBanner({super.key});
  @override Widget build(BuildContext context,WidgetRef ref) {
    final data=ref.watch(attendanceLocalDataProvider).valueOrNull;
    final pending=data?['ops']?.where((r)=>r['state']!='done').length ?? 0;
    final drafts=data?['drafts']?.map((r)=>r['event_id']).toSet().length ?? 0;
    if(pending+drafts==0) return const SizedBox.shrink();
    return ListTile(leading:const Icon(Icons.cloud_upload_outlined),
      title:Text('$pending yoklama gönderimi, $drafts cihaz taslağı bekliyor'),
      trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.pushNamed(context,'/attendance'),);
  }
}
