import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';
import 'quick_access_preferences.dart';

class HomeTodayTraining extends ConsumerStatefulWidget {
  const HomeTodayTraining({super.key});
  @override
  ConsumerState<HomeTodayTraining> createState() => _HomeTodayTrainingState();
}

class _HomeTodayTrainingState extends ConsumerState<HomeTodayTraining> {
  final _elapsed = Stopwatch();
  TodayTrainingSnapshot? _snapshot;
  Timer? _timer;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _snapshot != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(swanAccessProvider);
    if (!access.hasAccount ||
        !(access.isVerifiedAthlete ||
            access.clubRole == 'athlete' ||
            access.isParent) ||
        !ref.watch(
            featureEnabledProvider(FeatureFlags.sportTrainingSessions))) {
      return const SizedBox.shrink();
    }
    final account = ref.watch(quickAccessAccountProvider);
    if (account == null) return const SizedBox.shrink();
    final result = ref.watch(todayTrainingRsvpsProvider);
    // Errors do not imply there are no sessions, and stale permissions must not persist.
    if (result.hasError && !result.isLoading) {
      return Padding(
          padding: const EdgeInsets.symmetric(horizontal: SwanSpace.lg),
          child: TextButton.icon(
            onPressed: () => ref.invalidate(todayTrainingRsvpsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Bugünkü antrenmanlar yüklenemedi · Yenile'),
          ));
    }
    final data = result.valueOrNull;
    if (data == null || data.accountId != account || data.items.isEmpty)
      return const SizedBox.shrink();
    if (!identical(_snapshot, data)) {
      _snapshot = data;
      _elapsed.reset();
      _elapsed.start();
    }
    final now = data.serverNow.add(_elapsed.elapsed);
    final items = data.items
        .where((item) =>
            (item.isSelf ||
                access.isParent &&
                    ref.watch(
                        featureEnabledProvider(FeatureFlags.parentHub))) &&
            calendarTurkeyTime(item.startsAt).year ==
                calendarTurkeyTime(now).year &&
            calendarTurkeyTime(item.startsAt).month ==
                calendarTurkeyTime(now).month &&
            calendarTurkeyTime(item.startsAt).day ==
                calendarTurkeyTime(now).day &&
            (item.endsAt == null || item.endsAt!.isAfter(now)))
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final c = context.swan;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SwanSpace.lg, SwanSpace.xs, SwanSpace.lg, SwanSpace.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.only(bottom: SwanSpace.sm),
            child:
                Text('Bugünkü antrenman', style: SwanType.caption(c.inkMuted))),
        for (final item in (_expanded ? items : items.take(1)))
          _TrainingReplyCard(
              key: ValueKey('$account:${item.key}'),
              item: item,
              account: account,
              now: now,
              refreshing: result.isLoading),
        if (items.length > 1)
          Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded
                    ? 'Daha az göster'
                    : '${items.length - 1} antrenman daha'),
              )),
      ]),
    );
  }
}

class _TrainingReplyCard extends ConsumerStatefulWidget {
  const _TrainingReplyCard(
      {required this.item,
      required this.account,
      required this.now,
      required this.refreshing,
      super.key});
  final TodayTrainingRsvp item;
  final String account;
  final DateTime now;
  final bool refreshing;
  @override
  ConsumerState<_TrainingReplyCard> createState() => _TrainingReplyCardState();
}

class _TrainingReplyCardState extends ConsumerState<_TrainingReplyCard> {
  bool _saving = false;
  String? _error;

  Future<void> _respond(String status) async {
    if (_saving ||
        widget.refreshing ||
        !widget.item.startsAt.isAfter(widget.now)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(respondTodayTrainingProvider)(widget.item, status);
      // Render the authoritative refreshed response, never an optimistic attendance mark.
    } catch (_) {
      if (mounted && ref.read(quickAccessAccountProvider) == widget.account) {
        setState(() => _error =
            'Yanıt kaydedilemedi. Güncel yanıtı kontrol edip tekrar dene.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final item = widget.item;
    final starts = calendarTurkeyTime(item.startsAt);
    String time(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    final when =
        '${time(starts)}${item.endsAt == null ? '' : '–${time(calendarTurkeyTime(item.endsAt!))}'}';
    final started = !item.startsAt.isAfter(widget.now);
    final disabled = _saving || widget.refreshing || started;
    final identity = item.isSelf
        ? item.clubName
        : '${item.childName ?? 'Çocuğun'} · ${item.clubName}';
    Widget button(String status, String text, IconData icon) {
      final selected = item.response == status;
      return Semantics(
          selected: selected,
          child: OutlinedButton.icon(
            onPressed: disabled ? null : () => _respond(status),
            style: OutlinedButton.styleFrom(
              backgroundColor: selected ? c.accentSoft : Colors.transparent,
              foregroundColor: selected ? c.accent : c.inkMuted,
              side: BorderSide(color: selected ? c.accent : c.line),
              minimumSize: const Size(0, SwanSpace.xl * 2),
              padding: const EdgeInsets.symmetric(
                  horizontal: SwanSpace.sm, vertical: SwanSpace.sm),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SwanRadius.sm)),
            ),
            icon: Icon(selected ? Icons.check_circle_rounded : icon, size: 16),
            label: Text(text,
                style: SwanType.caption(selected ? c.accent : c.inkMuted)),
          ));
    }

    final buttons = [
      button('attending', 'Katılacağım', Icons.check_rounded),
      button('unavailable', 'Katılamayacağım', Icons.close_rounded)
    ];
    return Padding(
        padding: const EdgeInsets.only(bottom: SwanSpace.sm),
        child: Material(
          color: c.surface,
          borderRadius: BorderRadius.circular(SwanRadius.md),
          child: Padding(
              padding: const EdgeInsets.all(SwanSpace.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(item.title,
                              style: SwanType.body(c.ink, w: FontWeight.w700)),
                          const SizedBox(height: SwanSpace.xs),
                          Text(identity, style: SwanType.caption(c.inkMuted)),
                        ])),
                    const SizedBox(width: SwanSpace.sm),
                    Text(when,
                        style: SwanType.caption(c.ink, w: FontWeight.w700)),
                  ]),
                  if (item.place?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: SwanSpace.sm),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 16, color: c.inkMuted),
                      const SizedBox(width: SwanSpace.xs),
                      Expanded(
                          child: Text(item.place!,
                              style: SwanType.caption(c.inkMuted))),
                    ]),
                  ],
                  const SizedBox(height: SwanSpace.md),
                  if (started)
                    Text('Antrenman başladı · Yanıt süresi doldu',
                        style: SwanType.caption(c.inkMuted))
                  else if (MediaQuery.textScalerOf(context).scale(1) > 1.3)
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          buttons[0],
                          const SizedBox(height: SwanSpace.sm),
                          buttons[1]
                        ])
                  else
                    Row(children: [
                      Expanded(child: buttons[0]),
                      const SizedBox(width: SwanSpace.sm),
                      Expanded(child: buttons[1])
                    ]),
                  const SizedBox(height: SwanSpace.sm),
                  Semantics(
                      liveRegion: true,
                      child: Text(
                          _error ??
                              (_saving
                                  ? 'Yanıtın kaydediliyor…'
                                  : item.response == 'attending'
                                      ? 'Katılacağım dedin · Bu yanıt yoklama değildir.'
                                      : item.response == 'unavailable'
                                          ? 'Katılamayacağım dedin · Bu yanıt yoklama değildir.'
                                          : 'Katılımını bildir · Yoklamayı antrenörün alır.'),
                          style: SwanType.caption(
                              _error == null ? c.inkMuted : c.danger))),
                ],
              )),
        ));
  }
}
