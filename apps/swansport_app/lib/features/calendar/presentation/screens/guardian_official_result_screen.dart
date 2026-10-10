import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../athlete_workspace/presentation/widgets/official_athlete_cv.dart';

class GuardianResultBadge extends StatelessWidget {
  const GuardianResultBadge({super.key, required this.result});
  final GuardianOfficialResult result;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final color = switch (result.outcome) {
      GuardianResultOutcome.won || GuardianResultOutcome.recorded => c.success,
      GuardianResultOutcome.lost || GuardianResultOutcome.dq => c.danger,
      _ => c.inkMuted,
    };
    return Text(result.outcomeLabel,
        style: SwanType.caption(color, w: FontWeight.w700));
  }
}

class GuardianOfficialResultScreen extends ConsumerWidget {
  const GuardianOfficialResultScreen(
      {super.key, this.notificationId = '', this.matchId, this.childId});
  final String notificationId;
  final String? matchId, childId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Resmi Müsabaka Karnesi')),
      body: (matchId != null && childId != null
              ? ref.watch(guardianMatchResultProvider(
                  (matchId: matchId!, childId: childId!)))
              : ref.watch(guardianNotificationResultProvider(notificationId)))
          .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Bu resmi sonuç görüntülenemiyor.', style: SwanType.body(c.ink)),
          TextButton(
              onPressed: () {
                if (matchId != null && childId != null) {
                  ref.invalidate(guardianMatchResultProvider(
                      (matchId: matchId!, childId: childId!)));
                } else {
                  ref.invalidate(
                      guardianNotificationResultProvider(notificationId));
                }
              },
              child: const Text('Yeniden dene')),
        ])),
        data: (result) => SingleChildScrollView(
          padding: const EdgeInsets.all(SwanSpace.xl),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(result.childName, style: SwanType.h2(c.ink)),
            GuardianResultBadge(result: result),
            const SizedBox(height: SwanSpace.lg),
            OfficialResultSourceContent(source: result.source),
          ]),
        ),
      ),
    );
  }
}

class GuardianCalendarResultCard extends StatelessWidget {
  const GuardianCalendarResultCard({super.key, required this.entry});
  final GuardianCalendarResult entry;
  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(Icons.verified_user_rounded, color: context.swan.success),
        title: Text('${entry.result.childName} · ${entry.result.source.name}',
            style: SwanType.bodySm(context.swan.ink)),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              'Resmi Federasyon Müsabakası · ${entry.result.source.result ?? ''}',
              style: SwanType.caption(context.swan.inkMuted)),
          GuardianResultBadge(result: entry.result),
        ]),
        onTap: () => Navigator.pushNamed(
            context,
            entry.childId != null
                ? '/resmi-sonuc?match=${Uri.encodeQueryComponent(entry.result.source.matchId)}&child=${Uri.encodeQueryComponent(entry.childId!)}'
                : '/resmi-sonuc?notification=${Uri.encodeQueryComponent(entry.notificationId ?? '')}'),
      );
}
