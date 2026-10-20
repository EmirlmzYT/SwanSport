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
  bool _details = false;
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
    String time(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    final when =
        '${time(calendarTurkeyTime(item.startsAt))}${item.endsAt == null ? '' : '–${time(calendarTurkeyTime(item.endsAt!))}'}';
    final started = !item.startsAt.isAfter(widget.now);
    final disabled = _saving || widget.refreshing || started;
    final timing = _saving
        ? 'Kaydediliyor…'
        : started
            ? 'Başladı'
            : when;
    final subtitle =
        item.isSelf ? timing : '${item.childName ?? 'Çocuğun'} · $timing';
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final shortTitle = item.title
        .replaceFirst(
          RegExp(r'\s+antrenman[ıi]?$', caseSensitive: false),
          '',
        )
        .trim();

    Widget choice(
        String status, String label, String fullLabel, IconData icon) {
      final selected = item.response == status;
      return Semantics(
        selected: selected,
        button: true,
        label: fullLabel,
        child: Tooltip(
            message: fullLabel,
            child: TextButton.icon(
              onPressed: disabled ? null : () => _respond(status),
              style: TextButton.styleFrom(
                foregroundColor: selected ? c.accent : c.inkMuted,
                backgroundColor: selected ? c.accentSoft : Colors.transparent,
                minimumSize: const Size(0, SwanSpace.xl * 2),
                padding: const EdgeInsets.symmetric(horizontal: SwanSpace.sm),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.sm)),
              ),
              icon:
                  Icon(selected ? Icons.check_circle_rounded : icon, size: 16),
              label: Text(label,
                  style: SwanType.caption(selected ? c.accent : c.inkMuted)),
            )),
      );
    }

    final responses = Row(mainAxisSize: MainAxisSize.min, children: [
      choice('attending', 'Varım', 'Katılacağım', Icons.check_rounded),
      const SizedBox(width: SwanSpace.xs),
      choice('unavailable', 'Yokum', 'Katılamayacağım', Icons.close_rounded),
    ]);
    final heading = Tooltip(
        message: 'Antrenman ayrıntıları',
        child: InkWell(
          borderRadius: BorderRadius.circular(SwanRadius.sm),
          onTap: () => setState(() => _details = !_details),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: SwanSpace.xl * 2),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_details || shortTitle.isEmpty ? item.title : shortTitle,
                      maxLines: _details
                          ? null
                          : largeText
                              ? 2
                              : 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.body(c.ink, w: FontWeight.w600)),
                  const SizedBox(height: SwanSpace.xs),
                  Row(children: [
                    Flexible(
                        child: Text(subtitle,
                            style: SwanType.caption(c.inkMuted))),
                    const SizedBox(width: SwanSpace.xs),
                    Icon(
                        _details
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: c.inkMuted),
                  ]),
                ]),
          ),
        ));
    return Padding(
      padding: const EdgeInsets.only(bottom: SwanSpace.sm),
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: SwanSpace.md, vertical: SwanSpace.sm),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (largeText) ...[
              heading,
              if (!started)
                Align(alignment: Alignment.centerRight, child: responses),
            ] else
              Row(children: [
                Expanded(child: heading),
                if (!started) ...[
                  const SizedBox(width: SwanSpace.sm),
                  responses
                ],
              ]),
            if (_details) ...[
              const SizedBox(height: SwanSpace.sm),
              Text(item.clubName, style: SwanType.caption(c.inkMuted)),
              if (item.place?.trim().isNotEmpty == true) ...[
                const SizedBox(height: SwanSpace.xs),
                Text(item.place!, style: SwanType.caption(c.inkMuted)),
              ],
              const SizedBox(height: SwanSpace.sm),
              Text('Bu seçim katılım niyetindir; yoklamayı antrenörün alır.',
                  style: SwanType.caption(c.inkMuted)),
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: SwanSpace.sm),
                  child: Semantics(
                      liveRegion: true,
                      child: Text(_error!, style: SwanType.caption(c.danger)))),
          ]),
        ),
      ),
    );
  }
}
