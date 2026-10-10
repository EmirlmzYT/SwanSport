import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/features/training/presentation/widgets/score_pad.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  for (final branch in kBranchDefinitions) {
    testWidgets('score pad safely displays ${branch.code}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScorePad(
                config: TrainingProtocolConfig.fromMap(const {
                  'set_count': 1,
                  'units_per_set': 3,
                  'max_unit_score': 10,
                  'entry_mode': 'detailed',
                }),
                setNo: 1,
                branch: branch,
                onSubmit: ({num? total, List<num?>? entries}) async {},
              ),
            ),
          ),
        ),
      );
      expect(find.byType(ScorePad), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
