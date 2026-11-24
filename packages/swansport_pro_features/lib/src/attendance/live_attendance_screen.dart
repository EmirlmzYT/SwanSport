import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_dirty_state.dart';
import '../host/pro_feature_host.dart';
import '../host/pro_feature_theme.dart';

final attendanceOperationIdProvider = Provider<String Function()>(
  (ref) => diagnosticId,
);

class SharedLiveAttendanceScreen extends ConsumerStatefulWidget {
  const SharedLiveAttendanceScreen({this.initialEventId, super.key});

  final String? initialEventId;

  @override
  ConsumerState<SharedLiveAttendanceScreen> createState() =>
      _SharedLiveAttendanceScreenState();
}

class _SharedLiveAttendanceScreenState
    extends ConsumerState<SharedLiveAttendanceScreen> {
  static const _labels = {
    'present': 'Var',
    'absent': 'Yok',
    'excused': 'İzinli',
    'late': 'Geç',
  };

  String? _event;
  String? _message;
  String? _onlineOperationId;
  final _marks = <String, Map<String, dynamic>>{};
  List<AttendanceConflict> _conflicts = const [];
  bool _busy = false;
  bool _uncertain = false;
  bool _leaving = false;
  late final ProDirtyStateRegistration _dirtyRegistration;

  @override
  void initState() {
    super.initState();
    _event = widget.initialEventId;
    _dirtyRegistration =
        ref.read(proDirtyStateCoordinatorProvider).register('attendance');
  }

  @override
  void dispose() {
    _dirtyRegistration.dispose();
    super.dispose();
  }

  void _syncDirty() {
    if (_marks.isNotEmpty || _uncertain || _conflicts.isNotEmpty) {
      _dirtyRegistration.markDirty();
    } else {
      _dirtyRegistration.markClean();
    }
  }

  Future<void> _action(
    Future<void> Function() action, {
    String? success,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted && success != null) setState(() => _message = success);
    } catch (error) {
      if (mounted) {
        setState(() => _message = classifyOperationError(error).userMessage);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveOnline() async {
    _onlineOperationId ??= ref.read(attendanceOperationIdProvider)();
    await _action(() async {
      try {
        final result = await ref.read(attendanceSaveCommandProvider)(
          eventId: _event!,
          opId: _onlineOperationId!,
          marks: _marks.values.toList(),
        );
        _conflicts = result.conflicts;
        final conflictIds = result.conflicts.map((c) => c.athleteId).toSet();
        _marks.removeWhere((id, _) => !conflictIds.contains(id));
        _uncertain = false;
        _onlineOperationId = null;
        ref.invalidate(versionedRosterProvider(_event!));
        _syncDirty();
        if (mounted) {
          setState(() {
            _message = result.hasConflicts
                ? 'Bazı işaretler çakıştı; kararını bekliyor.'
                : 'Yoklama sunucuda doğrulandı.';
          });
        }
      } catch (error) {
        final safe = classifyOperationError(error);
        _uncertain = safe.kind == OperationErrorKind.network ||
            safe.kind == OperationErrorKind.unknown;
        if (!_uncertain) _onlineOperationId = null;
        _syncDirty();
        if (_uncertain && mounted) {
          ProFeatureHostScope.of(context).chrome.showMessage(
                context,
                safe.userMessage,
                tone: ProFeatureMessageTone.warning,
              );
        }
        rethrow;
      }
    });
  }

  Future<void> _checkQueue(AttendanceQueue queue) async {
    await queue.sync();
    if (queue.lastStorageError != null) throw StateError('queue storage');
  }

  String? _status(
    RosterEntry row,
    List<Map<String, dynamic>> drafts,
    bool offline,
  ) {
    final touched = offline
        ? drafts.where((m) => m['athlete_id'] == row.athleteId).firstOrNull
        : _marks[row.athleteId];
    return (touched?['status'] as String?) ?? row.attendance;
  }

  Future<void> _requestBack() async {
    if (_leaving || _busy) return;
    final host = ProFeatureHostScope.of(context);
    final allowed =
        await ref.read(proDirtyStateCoordinatorProvider).runGuardedTransition(
              confirmDiscard: () => host.chrome.confirm(
                context,
                title: 'Kaydedilmemiş işaretler var',
                message:
                    'Bu sayfadan ayrılırsan kaydedilmemiş yoklama işaretleri bırakılır.',
                confirmLabel: 'İşaretleri bırak',
              ),
              invalidate: () {},
              transition: () async {
                _leaving = true;
                if (mounted) Navigator.of(context).pop();
              },
            );
    if (!allowed) _leaving = false;
  }

  @override
  Widget build(BuildContext context) {
    final host = ProFeatureHostScope.of(context);
    final colors = host.theme;
    final onlineEnabled = ref.watch(
      featureEnabledProvider(FeatureFlags.attendanceOperations),
    );
    if (!onlineEnabled) {
      return host.chrome.buildPage(
        context,
        title: 'Yoklama',
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Yoklama operasyonları şu anda kullanıma kapalı.'),
          ),
        ),
        allowBack: true,
      );
    }

    final queue = ref.watch(attendanceQueueProvider).valueOrNull;
    final localAsync = ref.watch(attendanceLocalDataProvider);
    final local = localAsync.valueOrNull ??
        const {
          'cache': <Map<String, dynamic>>[],
          'drafts': <Map<String, dynamic>>[],
          'ops': <Map<String, dynamic>>[],
        };
    final club = ref.watch(activeClubProvider).valueOrNull;
    final live = ref.watch(eventsProvider).valueOrNull ?? const <EventRow>[];
    final cache = local['cache']!;
    final events = <String, (String, String)>{
      for (final event
          in live.where((event) => {'training', 'match'}.contains(event.kind)))
        event.id: (
          event.title,
          SeasonSetupDraft.dateText(event.startsAt),
        ),
      for (final snapshot
          in cache.where((row) => club == null || row['club_id'] == club.id))
        snapshot['event_id'] as String: (
          snapshot['title'] as String,
          SeasonSetupDraft.dateText(
            DateTime.parse(snapshot['starts_at'] as String),
          ),
        ),
    };
    if (_event != null && !events.containsKey(_event) && events.isNotEmpty) {
      _event = null;
    }
    _event ??= events.keys.firstOrNull;
    final snapshot =
        cache.where((row) => row['event_id'] == _event).firstOrNull;
    final usable = snapshot != null &&
        DateTime.parse(snapshot['expires_at'] as String)
            .isAfter(DateTime.now().toUtc());
    final offline = snapshot != null && queue != null;
    final roster = _event == null
        ? const AsyncValue<List<RosterEntry>>.data([])
        : ref.watch(versionedRosterProvider(_event!));
    final rosterError = roster.error == null
        ? null
        : classifyOperationError(roster.error as Object);
    final denied = rosterError?.kind == OperationErrorKind.unauthorized;
    final rows = offline && !denied
        ? (snapshot['rows'] as List)
            .map(
              (row) => RosterEntry.fromVersionedMap(
                (row as Map).cast<String, dynamic>(),
              ),
            )
            .toList()
        : roster.valueOrNull ?? const <RosterEntry>[];
    final drafts =
        local['drafts']!.where((row) => row['event_id'] == _event).toList();
    final pending =
        local['ops']!.where((row) => row['state'] != 'done').toList();
    final frozen = pending.any((row) => row['event_id'] == _event) ||
        _uncertain ||
        _conflicts.isNotEmpty;
    final media = MediaQuery.of(context);
    final compactLayout =
        media.size.width < 360 || media.textScaler.scale(1) > 1.5;
    Widget buildSaveAction() => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: FilledButton.icon(
            key: const Key('attendance-save'),
            onPressed: _busy ||
                    frozen ||
                    denied ||
                    (offline ? drafts.isEmpty : _marks.isEmpty)
                ? null
                : () async {
                    if (offline) {
                      await _action(
                        () async {
                          await queue.store.enqueue(queue.actor, _event!);
                          await _checkQueue(queue);
                        },
                        success:
                            'İşaretler cihazda korundu. Gönderim durumunu kontrol et.',
                      );
                    } else {
                      await _saveOnline();
                    }
                  },
            icon: Icon(
              offline ? Icons.cloud_upload_outlined : Icons.verified_outlined,
            ),
            label: Text(
              _busy
                  ? 'İşlem sürüyor…'
                  : offline
                      ? 'İşaretleri kuyruğa al (${drafts.length})'
                      : 'Sunucuya kaydet (${_marks.length})',
            ),
          ),
        );
    final body = SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          _AttendanceOverview(
            athleteCount: rows.length,
            markedCount: offline ? drafts.length : _marks.length,
            pendingCount: pending.length,
            offline: offline,
            colors: colors,
          ),
          const SizedBox(height: 16),
          if (localAsync.hasError)
            _AttendanceNotice(
              icon: Icons.phone_android_outlined,
              message:
                  'Cihaz deposu açılamadı. Çevrimdışı kayıt kullanılamıyor.',
              color: colors.warning,
              colors: colors,
            ),
          if (events.isEmpty) ...[
            _AttendancePanel(
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Etkinlik yüklenemedi veya hazırlanmış kadro yok.',
                    style: TextStyle(color: colors.inkMuted),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(eventsProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Etkinlikleri yeniden yükle'),
                  ),
                ],
              ),
            ),
          ] else
            _AttendancePanel(
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AttendanceSectionLabel(
                    icon: Icons.event_available_outlined,
                    label: 'ETKİNLİK VE KADRO',
                    colors: colors,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    key: const Key('attendance-event-select'),
                    initialValue: events.containsKey(_event) ? _event : null,
                    decoration: const InputDecoration(
                      labelText: 'Etkinlik',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    isExpanded: true,
                    items: [
                      for (final event in events.entries)
                        DropdownMenuItem(
                          value: event.key,
                          child: Text(
                            '${event.value.$2} · ${event.value.$1}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: _busy || frozen
                        ? null
                        : (id) => setState(() {
                              _event = id;
                              _message = null;
                            }),
                  ),
                ],
              ),
            ),
          if (_event != null &&
              queue != null &&
              ref.watch(
                featureEnabledProvider(FeatureFlags.offlineAttendance),
              ))
            TextButton.icon(
              onPressed: _busy || _marks.isNotEmpty
                  ? null
                  : () => _action(
                        () => queue.prepare(_event!),
                        success: 'Kadro cihazda hazırlandı.',
                      ),
              icon: const Icon(Icons.download_for_offline_outlined),
              label: const Text('Çevrimdışına hazırla / güncelle'),
            ),
          if (offline)
            Text(
              'Hazırlanmış kadro · yalnız dokunduğun satırlar cihazda saklanır.',
              style: TextStyle(color: colors.inkMuted),
            ),
          if (snapshot != null && !usable)
            Text(
              'Kadronun yedi günlük süresi doldu. Yeniden hazırla.',
              style: TextStyle(color: colors.inkMuted),
            ),
          if (denied)
            Text(
              'Sunucu bu kadroya erişimi reddetti. Yetkini kontrol et.',
              style: TextStyle(color: colors.danger),
            ),
          if (!offline && roster.isLoading) const LinearProgressIndicator(),
          if (!offline && roster.hasError && !denied)
            Text(
              rosterError!.userMessage,
              style: TextStyle(color: colors.inkMuted),
            ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _AttendanceNotice(
                icon: Icons.info_outline_rounded,
                message: _message!,
                color: colors.accent,
                colors: colors,
              ),
            ),
          if (_event != null && !compactLayout) buildSaveAction(),
          if (_uncertain) ...[
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              key: const Key('attendance-retry'),
              onPressed: _busy ? null : _saveOnline,
              icon: const Icon(Icons.sync_rounded),
              label: const Text('Aynı işlemi tekrar dene'),
            ),
          ],
          if (_conflicts.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AttendanceNotice(
              icon: Icons.compare_arrows_rounded,
              message:
                  'Sunucudaki yoklama değişmiş. Güncel kaydı kabul et veya yeniden işaretle.',
              color: colors.warning,
              colors: colors,
            ),
            const SizedBox(height: 8),
            for (final conflict in _conflicts)
              Text(
                '${conflict.athleteId}: sen ${_labels[conflict.sentStatus]}, sunucuda ${_labels[conflict.currentStatus] ?? "kayıt yok"}',
              ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _conflicts = [];
                        _marks.clear();
                        _syncDirty();
                        ref.invalidate(versionedRosterProvider(_event!));
                      }),
              child: const Text('Sunucudakini kullan / yeniden işaretle'),
            ),
          ],
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Sporcu Yoklaması',
              style: TextStyle(
                color: colors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${rows.length} sporcu · ${offline ? drafts.length : _marks.length} işaret değiştirildi',
              style: TextStyle(color: colors.inkMuted),
            ),
          ],
          for (final row in rows) ...[
            const SizedBox(height: 12),
            _AttendancePanel(
              colors: colors,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AthleteAvatar(name: row.fullName, colors: colors),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.fullName,
                              style: TextStyle(
                                color: colors.ink,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (row.rsvp != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                'Katılım yanıtı: ${row.rsvp == "attending" ? "Katılacak" : row.rsvp == "unavailable" ? "Katılamayacak" : "Belirsiz"} · yoklama değildir',
                                style: TextStyle(
                                  color: colors.inkMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (row.isBlocked)
                        Tooltip(
                          message: 'Uygunluk kısıtı var',
                          child: Icon(
                            Icons.health_and_safety_outlined,
                            color: colors.danger,
                          ),
                        ),
                    ],
                  ),
                  if (row.isBlocked) ...[
                    const SizedBox(height: 10),
                    _AttendanceNotice(
                      icon: Icons.block_rounded,
                      message:
                          'Uygunluk kısıtı var. Var ve Geç seçenekleri kullanılamaz.',
                      color: colors.danger,
                      colors: colors,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final choice in _labels.entries)
                        ChoiceChip(
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                          key: Key(
                            'attendance-choice-${row.athleteId}-${choice.key}',
                          ),
                          avatar: Icon(
                            _attendanceChoiceIcon(choice.key),
                            size: 17,
                          ),
                          label: Text(choice.value),
                          selected: _status(row, drafts, offline) == choice.key,
                          onSelected: _busy ||
                                  frozen ||
                                  denied ||
                                  (offline && !usable) ||
                                  (row.isBlocked &&
                                      {'present', 'late'}.contains(choice.key))
                              ? null
                              : (_) async {
                                  if (offline) {
                                    await _action(
                                      () => queue.store.mark(
                                        queue.actor,
                                        _event!,
                                        row.athleteId,
                                        choice.key,
                                      ),
                                    );
                                  } else {
                                    setState(() {
                                      _marks[row.athleteId] = {
                                        'athlete_id': row.athleteId,
                                        'status': choice.key,
                                        'version': _marks[row.athleteId]
                                                ?['version'] ??
                                            row.version,
                                        'marked_at': DateTime.now()
                                            .toUtc()
                                            .toIso8601String(),
                                      };
                                      _syncDirty();
                                    });
                                  }
                                },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (_event != null && compactLayout) buildSaveAction(),
          if (_marks.isNotEmpty)
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final accepted = await host.chrome.confirm(
                        context,
                        title: 'Yerel işaretleri bırak?',
                        message: _uncertain
                            ? 'Sunucu işlemi almış olabilir. Bıraktıktan sonra kayıtları yeniden kontrol et.'
                            : 'Henüz gönderilmemiş işaretler bırakılır.',
                        confirmLabel: 'Onayla',
                      );
                      if (!accepted || !mounted) return;
                      setState(() {
                        _marks.clear();
                        _conflicts = [];
                        _uncertain = false;
                        _onlineOperationId = null;
                        _syncDirty();
                      });
                    },
              child: const Text('İşaretleri bırak ve kayıtları kontrol et'),
            ),
          Text(
            'Bekleyen Yoklamalar (${pending.length})',
            style: TextStyle(
              color: colors.ink,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          if (queue != null)
            TextButton(
              onPressed: _busy ? null : () => _action(() => _checkQueue(queue)),
              child: const Text('Gönderimi kontrol et'),
            ),
          for (final operation in pending)
            _PendingOperation(
              operation: operation,
              queue: queue,
              busy: _busy,
              onAction: _action,
              confirm: (title, message) => host.chrome.confirm(
                context,
                title: title,
                message: message,
                confirmLabel: 'Onayla',
              ),
            ),
        ],
      ),
    );
    return PopScope(
      canPop: _leaving || (!_busy && !_marks.isNotEmpty && !_uncertain),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestBack();
      },
      child: host.chrome.buildPage(
        context,
        title: 'Yoklama',
        body: body,
        allowBack: true,
      ),
    );
  }
}

IconData _attendanceChoiceIcon(String value) => switch (value) {
      'present' => Icons.check_circle_outline_rounded,
      'absent' => Icons.cancel_outlined,
      'excused' => Icons.event_busy_outlined,
      'late' => Icons.schedule_rounded,
      _ => Icons.radio_button_unchecked_rounded,
    };

class _AttendanceOverview extends StatelessWidget {
  const _AttendanceOverview({
    required this.athleteCount,
    required this.markedCount,
    required this.pendingCount,
    required this.offline,
    required this.colors,
  });

  final int athleteCount;
  final int markedCount;
  final int pendingCount;
  final bool offline;
  final ProFeatureThemeData colors;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width < 360 || media.textScaler.scale(1) > 1.5) {
      return const SizedBox.shrink();
    }
    return _AttendancePanel(
      colors: colors,
      emphasized: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AttendanceSectionLabel(
            icon: Icons.fact_check_outlined,
            label: 'CANLI OPERASYON',
            colors: colors,
          ),
          const SizedBox(height: 10),
          Text(
            'Günün yoklamasını tamamla',
            style: TextStyle(
              color: colors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            offline
                ? 'Hazırlanmış kadro üzerinden çevrimdışı çalışıyorsun.'
                : 'İşaretler sürüm kontrolüyle doğrudan sunucuya kaydedilir.',
            style: TextStyle(color: colors.inkMuted, height: 1.35),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AttendanceMetric(
                icon: Icons.groups_2_outlined,
                value: '$athleteCount',
                label: 'sporcu',
                colors: colors,
              ),
              _AttendanceMetric(
                icon: Icons.edit_note_rounded,
                value: '$markedCount',
                label: 'değişiklik',
                colors: colors,
              ),
              _AttendanceMetric(
                icon: Icons.cloud_upload_outlined,
                value: '$pendingCount',
                label: 'bekleyen',
                colors: colors,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttendanceMetric extends StatelessWidget {
  const _AttendanceMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String value;
  final String label;
  final ProFeatureThemeData colors;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.line),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(icon, size: 17, color: colors.accent),
            const SizedBox(width: 7),
            Text(
              '$value $label',
              style: TextStyle(
                color: colors.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
}

class _AttendancePanel extends StatelessWidget {
  const _AttendancePanel({
    required this.child,
    required this.colors,
    this.emphasized = false,
  });

  final Widget child;
  final ProFeatureThemeData colors;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                emphasized ? colors.accent.withValues(alpha: .3) : colors.line,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.ink.withValues(alpha: .04),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
}

class _AttendanceSectionLabel extends StatelessWidget {
  const _AttendanceSectionLabel({
    required this.icon,
    required this.label,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final ProFeatureThemeData colors;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: colors.accent),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: colors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
          ),
        ],
      );
}

class _AttendanceNotice extends StatelessWidget {
  const _AttendanceNotice({
    required this.icon,
    required this.message,
    required this.color,
    required this.colors,
  });

  final IconData icon;
  final String message;
  final Color color;
  final ProFeatureThemeData colors;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: .22)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: colors.ink,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _AthleteAvatar extends StatelessWidget {
  const _AthleteAvatar({required this.name, required this.colors});

  final String name;
  final ProFeatureThemeData colors;

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.isEmpty || parts.first.isEmpty
        ? '?'
        : '${parts.first[0]}${parts.length > 1 ? parts.last[0] : ''}'
            .toUpperCase();
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: colors.accent,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PendingOperation extends StatelessWidget {
  const _PendingOperation({
    required this.operation,
    required this.queue,
    required this.busy,
    required this.onAction,
    required this.confirm,
  });

  final Map<String, dynamic> operation;
  final AttendanceQueue? queue;
  final bool busy;
  final Future<void> Function(Future<void> Function(), {String? success})
      onAction;
  final Future<bool> Function(String, String) confirm;

  @override
  Widget build(BuildContext context) {
    final state = operation['state'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            switch (state) {
              'conflict' => 'Çakışma: kararın gerekli',
              'rejected' => 'Sunucu reddetti; cihaz kaydı korunuyor',
              'paused' => 'Gönderim duraklatıldı',
              'sending' => 'Sunucu yanıtı bekleniyor',
              _ => 'Sunucuda henüz doğrulanmadı',
            },
          ),
          if (state == 'rejected' && queue != null)
            TextButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!await confirm(
                        'Reddedilen işlemi bırak?',
                        'İşaretler sunucuya uygulanmadı; cihaz geçmişinde korunur.',
                      )) {
                        return;
                      }
                      await onAction(
                        () => queue!.store.abandonRejected(
                          queue!.actor,
                          operation['op_id'] as String,
                        ),
                      );
                    },
              child: const Text('Reddedilen işlemi bırak'),
            ),
          if ({'pending', 'paused', 'rejected'}.contains(state) &&
              queue != null)
            TextButton(
              onPressed: busy
                  ? null
                  : () => onAction(() async {
                        await queue!.store.retry(
                          queue!.actor,
                          operation['op_id'] as String,
                        );
                        await queue!.sync();
                      }),
              child: const Text('Kontrol ettim, tekrar dene'),
            ),
        ],
      ),
    );
  }
}
