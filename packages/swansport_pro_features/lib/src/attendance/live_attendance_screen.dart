import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../host/pro_dirty_state.dart';
import '../host/pro_feature_host.dart';

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
                Map<String, dynamic>.from(row as Map),
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
    final body = SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (localAsync.hasError)
            Text(
              'Cihaz deposu açılamadı. Çevrimdışı kayıt kullanılamıyor.',
              style: TextStyle(color: colors.inkMuted),
            ),
          if (events.isEmpty) ...[
            Text(
              'Etkinlik yüklenemedi veya hazırlanmış kadro yok.',
              style: TextStyle(color: colors.inkMuted),
            ),
            TextButton(
              onPressed: () => ref.invalidate(eventsProvider),
              child: const Text('Etkinlikleri yeniden yükle'),
            ),
          ] else
            DropdownButtonFormField<String>(
              key: const Key('attendance-event-select'),
              initialValue: events.containsKey(_event) ? _event : null,
              decoration: const InputDecoration(labelText: 'Etkinlik'),
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
              child: Text(_message!, style: TextStyle(color: colors.inkMuted)),
            ),
          for (final row in rows) ...[
            const SizedBox(height: 16),
            Text(
              row.fullName,
              style: TextStyle(
                color: colors.ink,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (row.rsvp != null)
              Text(
                'Katılım yanıtı: ${row.rsvp == "attending" ? "Katılacak" : row.rsvp == "unavailable" ? "Katılamayacak" : "Belirsiz"} · yoklama değildir',
                style: TextStyle(color: colors.inkMuted, fontSize: 12),
              ),
            if (row.isBlocked)
              Text(
                'Uygunluk kısıtı var',
                style: TextStyle(color: colors.danger),
              ),
            Wrap(
              spacing: 8,
              children: [
                for (final choice in _labels.entries)
                  ChoiceChip(
                    key: Key(
                      'attendance-choice-${row.athleteId}-${choice.key}',
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
                                  'marked_at':
                                      DateTime.now().toUtc().toIso8601String(),
                                };
                                _syncDirty();
                              });
                            }
                          },
                  ),
              ],
            ),
          ],
          if (_conflicts.isNotEmpty) ...[
            const Text(
              'Sunucudaki yoklama değişmiş. Güncel kaydı kabul et veya yeniden işaretle.',
            ),
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
          if (_event != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: FilledButton(
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
                child: Text(
                  _busy
                      ? 'İşlem sürüyor…'
                      : offline
                          ? 'İşaretleri kuyruğa al (${drafts.length})'
                          : 'Sunucuya kaydet (${_marks.length})',
                ),
              ),
            ),
          if (_uncertain)
            FilledButton(
              key: const Key('attendance-retry'),
              onPressed: _busy ? null : _saveOnline,
              child: const Text('Aynı işlemi tekrar dene'),
            ),
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
              fontSize: 17,
              fontWeight: FontWeight.w700,
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
