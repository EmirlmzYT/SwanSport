import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/swan_tabs.dart';
import 'score_pad.dart';

typedef SubmitDrill =
    Future<void> Function({
      num? total,
      List<num?>? entries,
      DrillMetricPayload? metricPayload,
    });

class BranchDrillPad extends StatelessWidget {
  const BranchDrillPad({
    required this.session,
    required this.config,
    required this.sets,
    required this.onSubmit,
    super.key,
  });
  final TrainingSession session;
  final TrainingProtocolConfig config;
  final List<TrainingSet> sets;
  final SubmitDrill onSubmit;

  @override
  Widget build(BuildContext context) {
    final matches = sets.where((s) => s.setNo == session.currentSet);
    final existing = matches.isEmpty ? null : matches.first;
    return switch (config.archetype) {
      TrainingArchetype.targetScore => TargetScorePad(
        session: session,
        config: config,
        existing: existing,
        onSubmit: onSubmit,
      ),
      TrainingArchetype.attemptDrill => AttemptDrillPad(
        session: session,
        config: config,
        existing: existing,
        onSubmit: onSubmit,
      ),
      TrainingArchetype.lapInterval => LapIntervalPad(
        session: session,
        config: config,
        existing: existing,
        onSubmit: onSubmit,
      ),
      TrainingArchetype.combatRally => CombatRallyPad(
        session: session,
        config: config,
        existing: existing,
        onSubmit: onSubmit,
      ),
    };
  }
}

/// Keep numeric/legacy score entry available, including non-ten-point targets.
class TargetScorePad extends StatefulWidget {
  const TargetScorePad({
    required this.session,
    required this.config,
    required this.existing,
    required this.onSubmit,
    super.key,
  });
  final TrainingSession session;
  final TrainingProtocolConfig config;
  final TrainingSet? existing;
  final SubmitDrill onSubmit;
  @override
  State<TargetScorePad> createState() => _TargetScorePadState();
}

class _TargetScorePadState extends State<TargetScorePad> {
  bool _numeric = false;
  @override
  Widget build(BuildContext context) {
    final legacy =
        widget.existing != null && widget.existing!.metricPayload == null;
    final rings =
        widget.config.maxUnitScore == 10 &&
        widget.config.entryMode.allowsDetailed &&
        !legacy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rings)
          TextButton(
            onPressed: () => setState(() => _numeric = !_numeric),
            child: Text(_numeric ? 'Hedef halkaları' : 'Sayısal giriş'),
          ),
        if (rings && !_numeric)
          _MetricPad(
            session: widget.session,
            config: widget.config,
            existing: widget.existing,
            onSubmit: widget.onSubmit,
          )
        else
          AbsorbPointer(
            absorbing:
                widget.session.paused ||
                !(widget.session.isLive || widget.session.awaitingApproval),
            child: ScorePad(
              key: ValueKey(widget.session.currentSet),
              config: widget.config,
              setNo: widget.session.currentSet,
              branch: branchByCode(widget.session.sportCode),
              existing: widget.existing,
              onSubmit: ({num? total, List<num?>? entries}) =>
                  widget.onSubmit(total: total, entries: entries),
            ),
          ),
      ],
    );
  }
}

class AttemptDrillPad extends _MetricPad {
  const AttemptDrillPad({
    required super.session,
    required super.config,
    required super.existing,
    required super.onSubmit,
    super.key,
  });
}

class LapIntervalPad extends _MetricPad {
  const LapIntervalPad({
    required super.session,
    required super.config,
    required super.existing,
    required super.onSubmit,
    super.key,
  });
}

class CombatRallyPad extends _MetricPad {
  const CombatRallyPad({
    required super.session,
    required super.config,
    required super.existing,
    required super.onSubmit,
    super.key,
  });
}

class _MetricPad extends ConsumerStatefulWidget {
  const _MetricPad({
    required this.session,
    required this.config,
    required this.existing,
    required this.onSubmit,
    super.key,
  });
  final TrainingSession session;
  final TrainingProtocolConfig config;
  final TrainingSet? existing;
  final SubmitDrill onSubmit;
  @override
  ConsumerState<_MetricPad> createState() => _MetricPadState();
}

class _MetricPadState extends ConsumerState<_MetricPad> {
  final _distance = TextEditingController();
  Timer? _tick;
  bool _busy = false;
  String? _error;
  DrillDraftKey get _key =>
      (sessionId: widget.session.id, setNo: widget.session.currentSet);
  DrillDraftController get _controller =>
      ref.read(drillDraftProvider(_key).notifier);
  bool get _enabled =>
      !_busy &&
      !widget.session.paused &&
      widget.existing?.locked != true &&
      (widget.session.isLive || widget.session.awaitingApproval);

  @override
  void initState() {
    super.initState();
    if (widget.config.archetype == TrainingArchetype.lapInterval) {
      final metric = widget.existing?.metricPayload;
      if (metric is LapIntervalMetric) {
        _distance.text = '${metric.distanceMeters}';
      }
      _tick = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant _MetricPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.session.paused && widget.session.paused) {
      final controller = _controller;
      final now = widget.session.pausedAt ?? DateTime.now();
      scheduleMicrotask(() {
        if (mounted) controller.pauseLap(now);
      });
    }
    if (oldWidget.session.phase == SessionPhase.lapActive &&
        widget.session.phase != SessionPhase.lapActive) {
      final controller = _controller;
      final now = DateTime.now();
      scheduleMicrotask(() {
        if (mounted) controller.pauseLap(now);
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _distance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_enabled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.config.archetype == TrainingArchetype.lapInterval) {
        _controller.pauseLap(DateTime.now());
      }
      final d = ref.read(drillDraftProvider(_key));
      final payload = switch (widget.config.archetype) {
        TrainingArchetype.targetScore => TargetScoreMetric(d.marks),
        TrainingArchetype.attemptDrill => AttemptDrillMetric(
          drillName: d.drillName.isEmpty ? _drills.first : d.drillName,
          successful: d.successful,
          faults: d.faults,
          totalAttempts: d.successful + d.faults,
        ),
        TrainingArchetype.lapInterval => LapIntervalMetric(
          lapNumber: widget.session.currentSet,
          splitMillis: d.elapsedMillis,
          distanceMeters: int.tryParse(_distance.text.trim()) ?? 0,
        ),
        TrainingArchetype.combatRally => CombatRallyMetric(
          rallies: d.rallies,
          winners: d.winners,
          unforcedErrors: d.errors,
        ),
      };
      await widget.onSubmit(metricPayload: payload);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Set kaydedildi.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String> get _drills => switch (widget.session.sportCode) {
    'volleyball' => ['Servis', 'Smaç', 'Manşet'],
    'basketball' => ['Şut', 'Serbest atış', 'Pas'],
    'football' => ['Şut', 'Pas', 'Top kontrolü'],
    _ => ['Deneme', 'Teknik', 'İstasyon'],
  };

  Widget _action(String label, VoidCallback action, {bool error = false}) =>
      FilledButton(
        onPressed: _enabled ? action : null,
        style: FilledButton.styleFrom(
          backgroundColor: error
              ? context.swan.surfaceAlt
              : context.swan.successFill,
          foregroundColor: error
              ? context.swan.ink
              : Theme.of(context).colorScheme.onPrimary,
          side: error ? BorderSide(color: context.swan.danger) : null,
          padding: const EdgeInsets.all(SwanSpace.xl),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SwanRadius.md),
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      );

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final d = ref.watch(drillDraftProvider(_key));
    final lapSaved = widget.existing?.metricPayload is LapIntervalMetric;
    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${widget.session.currentSet}. set', style: SwanType.h3(c.ink)),
          if (widget.existing?.locked == true)
            Text('Sonuç kilitli', style: SwanType.caption(c.inkMuted)),
          const SizedBox(height: SwanSpace.md),
          ...switch (widget.config.archetype) {
            TrainingArchetype.targetScore => [
              Text(
                d.marks.isEmpty ? 'Hedef halkasını seç' : d.marks.join(' · '),
                style: SwanType.h2(c.ink),
              ),
              Wrap(
                spacing: SwanSpace.sm,
                runSpacing: SwanSpace.sm,
                children: [
                  for (final mark in [
                    'X',
                    '10',
                    '9',
                    '8',
                    '7',
                    '6',
                    '5',
                    '4',
                    '3',
                    '2',
                    '1',
                    'M',
                  ])
                    OutlinedButton(
                      onPressed:
                          _enabled && d.marks.length < widget.config.unitsPerSet
                          ? () => _controller.mark(
                              mark,
                              widget.config.unitsPerSet,
                            )
                          : null,
                      child: Text(mark),
                    ),
                  TextButton(
                    onPressed: _enabled && d.marks.isNotEmpty
                        ? _controller.undoMark
                        : null,
                    child: const Text('Son oku geri al'),
                  ),
                ],
              ),
              Text(
                '${d.marks.length}/${widget.config.unitsPerSet} ok',
                style: SwanType.caption(c.inkMuted),
              ),
            ],
            TrainingArchetype.attemptDrill => [
              AbsorbPointer(
                absorbing: !_enabled || d.successful + d.faults > 0,
                child: SwanSegmentedTabs(
                  labels: _drills,
                  selected: _drills
                      .indexOf(d.drillName)
                      .clamp(0, _drills.length - 1),
                  onSelect: (i) => _controller.selectDrill(_drills[i]),
                ),
              ),
              const SizedBox(height: SwanSpace.lg),
              Text(
                '${d.successful} / ${d.successful + d.faults}',
                textAlign: TextAlign.center,
                style: SwanType.h2(c.ink),
              ),
              Text(
                d.successful + d.faults == 0
                    ? 'Henüz deneme yok'
                    : '%${(100 * d.successful / (d.successful + d.faults)).round()} İsabet',
                textAlign: TextAlign.center,
                style: SwanType.display(c.ink),
              ),
              const SizedBox(height: SwanSpace.lg),
              _action('+ BAŞARILI', () => _controller.attempt(true)),
              const SizedBox(height: SwanSpace.sm),
              _action(
                '− HATA/AUT',
                () => _controller.attempt(false),
                error: true,
              ),
              Text(
                'Her set tek drill içerir. Yeni drill için sonraki sete geç.',
                style: SwanType.caption(c.inkMuted),
              ),
            ],
            TrainingArchetype.lapInterval => [
              Text(
                formatLapTime(d.elapsedAt(DateTime.now())),
                textAlign: TextAlign.center,
                style: SwanType.display(c.ink),
              ),
              TextField(
                controller: _distance,
                enabled: _enabled && !lapSaved,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tur mesafesi (metre)',
                ),
              ),
              const SizedBox(height: SwanSpace.md),
              OutlinedButton(
                onPressed:
                    _enabled &&
                        !lapSaved &&
                        widget.session.isLive &&
                        widget.session.phase == SessionPhase.lapActive
                    ? () {
                        if (d.startedAt == null) {
                          _controller.startLap(DateTime.now());
                        } else {
                          _controller.pauseLap(DateTime.now());
                        }
                      }
                    : null,
                child: Text(
                  d.startedAt == null
                      ? 'Kronometreyi başlat / sürdür'
                      : 'Kronometreyi duraklat',
                ),
              ),
              Text(
                lapSaved
                    ? 'Tur kaydedildi. Sonraki tur aşamasını bekle.'
                    : 'Her tur bir set olarak kaydedilir.',
                style: SwanType.caption(c.inkMuted),
              ),
            ],
            TrainingArchetype.combatRally => [
              Text(
                '${d.rallies} ralli · ${d.winners} winner · ${d.errors} basit hata',
                style: SwanType.h3(c.ink),
              ),
              const SizedBox(height: SwanSpace.lg),
              _action('Winner (+)', () => _controller.rally(winner: true)),
              const SizedBox(height: SwanSpace.sm),
              _action(
                'Basit Hata (−)',
                () => _controller.rally(winner: false),
                error: true,
              ),
              const SizedBox(height: SwanSpace.sm),
              _action('Ace', () => _controller.rally(winner: true)),
              Text(
                'Ace, winner toplamına dahildir.',
                style: SwanType.caption(c.inkMuted),
              ),
            ],
          },
          if (_error != null) Text(_error!, style: SwanType.bodySm(c.danger)),
          const SizedBox(height: SwanSpace.lg),
          FilledButton(
            onPressed: _enabled && !lapSaved ? _save : null,
            child: Text(
              _busy
                  ? 'Kaydediliyor…'
                  : widget.config.archetype == TrainingArchetype.lapInterval
                  ? 'TUR AL (SPLIT)'
                  : 'Seti kaydet',
            ),
          ),
        ],
      ),
    );
  }
}

String formatLapTime(num millis) {
  final value = millis.round().clamp(0, 86400000);
  final minutes = value ~/ 60000;
  final seconds = (value ~/ 1000) % 60;
  final centis = (value ~/ 10) % 100;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.${centis.toString().padLeft(2, '0')}';
}
