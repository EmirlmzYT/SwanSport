import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import 'branch_drill_pad.dart' show SubmitDrill;

class StrengthSetPad extends StructuredMetricPad {
  const StrengthSetPad({required super.session, required super.config,
    required super.existing, required super.onSubmit, super.key});
}
class RoutineJudgePad extends StructuredMetricPad {
  const RoutineJudgePad({required super.session, required super.config,
    required super.existing, required super.onSubmit, super.key});
}
class MindTacticalPad extends StructuredMetricPad {
  const MindTacticalPad({required super.session, required super.config,
    required super.existing, required super.onSubmit, super.key});
}

/// One structured result per set; server refreshes never replace an input draft.
class StructuredMetricPad extends ConsumerStatefulWidget {
  const StructuredMetricPad({required this.session, required this.config,
    required this.existing, required this.onSubmit, super.key});
  final TrainingSession session;
  final TrainingProtocolConfig config;
  final TrainingSet? existing;
  final SubmitDrill onSubmit;
  @override
  ConsumerState<StructuredMetricPad> createState() => _StructuredMetricPadState();
}

class _StructuredMetricPadState extends ConsumerState<StructuredMetricPad> {
  final _controllers = <String, TextEditingController>{};
  bool _busy = false;
  String? _error;
  DrillDraftKey get _key => (sessionId: widget.session.id, setNo: widget.session.currentSet);
  Map<String, String> get _fields => switch (widget.config.archetype) {
    TrainingArchetype.strengthSet => {'exercise_name': 'Hareket', 'weight_kg': 'Ağırlık (kg · 0,5 adım)', 'reps': 'Tekrar', 'rpe': 'RPE (isteğe bağlı · 1–10)'},
    TrainingArchetype.routineJudge => {'routine_name': 'Seri adı', 'difficulty_score': 'Zorluk (D)', 'execution_score': 'Uygulama (E)', 'deductions': 'Kesintiler'},
    TrainingArchetype.mindTactical => {'task_name': 'Görev / bulmaca', 'solved_count': 'Çözülen', 'failed_count': 'Başarısız', 'duration_seconds': 'Süre (saniye)'},
    _ => throw StateError('Yapılandırılmış arketip gerekli'),
  };
  bool get _enabled => !_busy && !widget.session.paused &&
      widget.existing?.locked != true &&
      (widget.session.isLive || widget.session.awaitingApproval);

  @override
  void initState() {
    super.initState();
    final draft = ref.read(structuredDrillDraftProvider(_key));
    final saved = widget.existing?.metricPayload?.toMap() ?? const <String, Object?>{};
    for (final field in [..._fields.keys, if (widget.config.archetype == TrainingArchetype.strengthSet) 'good_lift']) {
      _controllers[field] = TextEditingController(text: draft[field] ?? saved[field]?.toString() ??
        (field == 'good_lift' ? 'true' : ''));
    }
  }
  @override
  void dispose() {
    for (final controller in _controllers.values) { controller.dispose(); }
    super.dispose();
  }
  void _remember() {
    ref.read(structuredDrillDraftProvider(_key).notifier).state = {
      for (final entry in _controllers.entries) entry.key: entry.value.text,
    };
    setState(() {});
  }
  num _number(String key) => num.parse(_controllers[key]!.text.trim().replaceAll(',', '.'));
  int _integer(String key) => int.parse(_controllers[key]!.text.trim());
  DrillMetricPayload _payload() => switch (widget.config.archetype) {
    TrainingArchetype.strengthSet => StrengthSetMetric(
      exerciseName: _controllers['exercise_name']!.text.trim(), weightKg: _number('weight_kg'),
      reps: _integer('reps'), rpe: _controllers['rpe']!.text.trim().isEmpty ? null : _integer('rpe'),
      goodLift: _controllers['good_lift']!.text == 'true'),
    TrainingArchetype.routineJudge => RoutineJudgeMetric(
      routineName: _controllers['routine_name']!.text.trim(), difficultyScore: _number('difficulty_score'),
      executionScore: _number('execution_score'), deductions: _number('deductions')),
    TrainingArchetype.mindTactical => MindTacticalMetric(
      taskName: _controllers['task_name']!.text.trim(), solvedCount: _integer('solved_count'),
      failedCount: _integer('failed_count'), durationSeconds: _integer('duration_seconds')),
    _ => throw StateError('Yapılandırılmış arketip gerekli'),
  };
  Future<void> _save() async {
    if (!_enabled) return;
    setState(() { _busy = true; _error = null; });
    try {
      await widget.onSubmit(metricPayload: _payload());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Set kaydedildi.')));
    } catch (error) {
      if (mounted) setState(() => _error = 'Kaydedilemedi: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final profile = branchTrainingProfileFor(widget.session.sportCode);
    String? preview;
    try {
      preview = switch (_payload()) {
        final RoutineJudgeMetric m => 'Net: ${m.netScore}',
        final MindTacticalMetric m => 'Doğruluk: %${(100 * m.accuracyRate).round()}',
        _ => null,
      };
    } on FormatException { /* An incomplete draft is not a submitted result. */ }
    return Padding(padding: const EdgeInsets.all(SwanSpace.lg), child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${widget.session.currentSet}. ${profile.setLabel}', style: SwanType.h3(c.ink)),
        Wrap(spacing: SwanSpace.sm, children: [for (final drill in profile.presetDrills)
          ActionChip(label: Text(drill), onPressed: _enabled ? () {
            _controllers[_fields.keys.first]!.text = drill; _remember();
          } : null)]),
        if (preview != null) Text(preview, style: SwanType.h3(c.ink)),
        for (final field in _fields.entries) ...[
          TextField(controller: _controllers[field.key], enabled: _enabled,
            keyboardType: field.key.endsWith('_name') ? TextInputType.text : const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: field.value), onChanged: (_) => _remember()),
          const SizedBox(height: SwanSpace.md),
        ],
        if (widget.config.archetype == TrainingArchetype.strengthSet)
          SwitchListTile(title: const Text('Geçerli kaldırış'), value: _controllers['good_lift']!.text == 'true',
            onChanged: _enabled ? (value) { _controllers['good_lift']!.text = '$value'; _remember(); } : null),
        if (_error != null) Text(_error!, style: SwanType.bodySm(c.danger)),
        FilledButton(onPressed: _enabled ? _save : null, child: Text(_busy ? 'Kaydediliyor…' : 'Seti kaydet')),
      ],
    ));
  }
}
