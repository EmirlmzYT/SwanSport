import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

class LiveAttendanceScreen extends ConsumerStatefulWidget {
  const LiveAttendanceScreen({super.key});
  @override
  ConsumerState<LiveAttendanceScreen> createState() => _AttendanceState();
}

class _AttendanceState extends ConsumerState<LiveAttendanceScreen> {
  String? _event, _message, _onlineOp;
  final _marks = <String, Map<String, dynamic>>{};
  List<AttendanceConflict> _conflicts = [];
  bool _busy = false, _uncertain = false;
  static const labels = {
    'present': 'Var',
    'absent': 'Yok',
    'excused': 'İzinli',
    'late': 'Geç',
  };
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
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'İşlem tamamlanamadı. Cihaz kaydını veya sunucu sonucunu kontrol edip tekrar dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveOnline() async {
    _onlineOp ??= diagnosticId();
    await _action(() async {
      try {
        final result =
            await ref.read(clubLifecycleServiceProvider).saveAttendance(
                  eventId: _event!,
                  opId: _onlineOp!,
                  marks: _marks.values.toList(),
                );
        _conflicts = result.conflicts;
        final ids = result.conflicts.map((c) => c.athleteId).toSet();
        _marks.removeWhere((id, _) => !ids.contains(id));
        _uncertain = false;
        _onlineOp = null;
        ref.invalidate(versionedRosterProvider(_event!));
        if (mounted) {
          setState(
            () => _message = result.hasConflicts
                ? 'Bazı işaretler çakıştı; kararını bekliyor.'
                : 'Yoklama sunucuda doğrulandı.',
          );
        }
      } on PostgrestException catch (e) {
        _uncertain = _uncertain ||
            !(e.code == 'P0001' ||
                e.code == '42501' ||
                (e.code?.startsWith('22') ?? false));
        if (!_uncertain) _onlineOp = null;
        rethrow;
      } catch (_) {
        _uncertain = true;
        rethrow;
      }
    });
  }

  Future<bool> _confirm(String title, String explanation) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(explanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Onayla'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _checkQueue(AttendanceQueue queue) async {
    await queue.sync();
    if (queue.lastStorageError != null) {
      throw StateError(queue.lastStorageError!);
    }
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

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final queue = ref.watch(attendanceQueueProvider).valueOrNull;
    final localAsync = ref.watch(attendanceLocalDataProvider);
    final local = localAsync.valueOrNull ??
        {
          'cache': <Map<String, dynamic>>[],
          'drafts': <Map<String, dynamic>>[],
          'ops': <Map<String, dynamic>>[],
        };
    final club = ref.watch(activeClubProvider).valueOrNull;
    final live = ref.watch(eventsProvider).valueOrNull ?? <EventRow>[];
    final cache = local['cache']!;
    final events = <String, (String, String)>{
      for (final e in live.where((e) => ['training', 'match'].contains(e.kind)))
        e.id: (e.title, SeasonSetupDraft.dateText(e.startsAt)),
      for (final s
          in cache.where((s) => club == null || s['club_id'] == club.id))
        s['event_id'] as String: (
          s['title'] as String,
          SeasonSetupDraft.dateText(DateTime.parse(s['starts_at'] as String))
        ),
    };
    final requested = ModalRoute.of(context)?.settings.arguments;
    if (_event == null &&
        requested is String &&
        events.containsKey(requested)) {
      _event = requested;
    }
    _event ??= events.keys.firstOrNull;
    final snapshot = cache.where((s) => s['event_id'] == _event).firstOrNull;
    final usable = snapshot != null &&
        DateTime.parse(snapshot['expires_at'] as String)
            .isAfter(DateTime.now().toUtc());
    final offline = snapshot != null && queue != null;
    final eventVisible = events.containsKey(_event);
    final roster = _event == null
        ? const AsyncValue<List<RosterEntry>>.data([])
        : ref.watch(versionedRosterProvider(_event!));
    final denied = roster.error is PostgrestException &&
        ['P0001', '42501'].contains((roster.error as PostgrestException).code);
    final rows = offline && !denied && eventVisible
        ? (snapshot['rows'] as List)
            .map(
              (r) => RosterEntry.fromVersionedMap(
                Map<String, dynamic>.from(r as Map),
              ),
            )
            .toList()
        : eventVisible
            ? roster.valueOrNull ?? <RosterEntry>[]
            : <RosterEntry>[];
    final drafts =
        local['drafts']!.where((r) => r['event_id'] == _event).toList();
    final pending = local['ops']!.where((r) => r['state'] != 'done').toList();
    final frozen = pending.any((r) => r['event_id'] == _event) ||
        _uncertain ||
        _conflicts.isNotEmpty;
    final confirmed = local['ops']!
        .where((r) => r['state'] == 'done' && r['resolution'] == null)
        .toList();
    return PopScope(
      canPop: !_busy && (_marks.isEmpty || offline),
      child: Scaffold(
        appBar: AppBar(title: const Text('Yoklama')),
        body: ListView(
          padding: const EdgeInsets.all(SwanSpace.lg),
          children: [
            if (_event != null && !eventVisible)
              const Text(
                'Etkinlik mevcut kulüp listesinde yok. İşaretleri kontrol et veya bırakıp yeni etkinliği seç.',
              ),
            if (localAsync.hasError)
              const Text(
                'Cihaz deposu açılamadı. Çevrimdışı kayıt kullanılamıyor.',
              ),
            if (events.isEmpty) ...[
              const Text(
                'Etkinlik yüklenemedi veya hazırlanmış kadro yok. İnternet varken etkinliği seçip kadroyu hazırla.',
              ),
              TextButton(
                onPressed: () => ref.invalidate(eventsProvider),
                child: const Text('Etkinlikleri yeniden yükle'),
              ),
            ] else
              DropdownButtonFormField<String>(
                initialValue: events.containsKey(_event) ? _event : null,
                key: ValueKey(_event),
                decoration: const InputDecoration(labelText: 'Etkinlik'),
                isExpanded: true,
                items: [
                  for (final e in events.entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Text(
                        '${e.value.$2} · ${e.value.$1}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: _busy
                    ? null
                    : (id) {
                        if (id == null) return;
                        if (_marks.isNotEmpty || _uncertain) {
                          setState(
                            () => _message =
                                'Önce bu etkinliğin işaretlerini kaydet.',
                          );
                          return;
                        }
                        setState(() {
                          _event = id;
                          _conflicts = [];
                          _onlineOp = null;
                          _message = null;
                        });
                      },
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
                'Hazırlanmış kadro · ${SeasonSetupDraft.dateText(DateTime.parse(snapshot['prepared_at'] as String))}\nYalnız dokunduğun satırlar cihazda saklanır.',
                style: SwanType.caption(c.inkMuted),
              ),
            if (snapshot != null && queue != null)
              TextButton(
                onPressed: _busy
                    ? null
                    : () => _action(
                          () => queue.store.forget(queue.actor, _event!),
                        ),
                child: const Text('Cihazdan hazırlanmış kadroyu kaldır'),
              ),
            if (snapshot != null && !usable)
              const Text(
                'Kadronun yedi günlük süresi doldu. Yeniden hazırla; bekleyen kayıtlar silinmedi.',
              ),
            if (denied)
              const Text(
                'Sunucu bu kadroya erişimi reddetti. Yetkini kontrol et.',
              ),
            if (!offline && roster.isLoading) const LinearProgressIndicator(),
            if (!offline && roster.hasError && !denied)
              const Text('Kadro yüklenemedi. Bağlantını kontrol et.'),
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
                child: Text(_message!, style: SwanType.body(c.inkMuted)),
              ),
            for (final row in rows) ...[
              const SizedBox(height: SwanSpace.lg),
              Text(row.fullName, style: SwanType.h3(c.ink)),
              if (row.rsvp != null)
                Text(
                  'Katılım yanıtı: ${row.rsvp == "attending" ? "Katılacak" : row.rsvp == "unavailable" ? "Katılamayacak" : "Belirsiz"} · yoklama değildir',
                  style: SwanType.caption(c.inkMuted),
                ),
              if (row.isBlocked)
                Text('Uygunluk kısıtı var', style: SwanType.body(c.danger)),
              Wrap(
                spacing: SwanSpace.sm,
                children: [
                  for (final choice in labels.entries)
                    ChoiceChip(
                      label: Text(choice.value),
                      selected: _status(row, drafts, offline) == choice.key,
                      onSelected: _busy ||
                              frozen ||
                              denied ||
                              (offline && !usable) ||
                              row.isBlocked &&
                                  ['present', 'late'].contains(choice.key)
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
                                setState(
                                  () => _marks[row.athleteId] = {
                                    'athlete_id': row.athleteId,
                                    'status': choice.key,
                                    'version': _marks[row.athleteId]
                                            ?['version'] ??
                                        row.version,
                                    'marked_at': DateTime.now()
                                        .toUtc()
                                        .toIso8601String(),
                                  },
                                );
                              }
                            },
                    ),
                ],
              ),
            ],
            if (_conflicts.isNotEmpty) ...[
              const Text(
                'Sunucudaki yoklama değişmiş. Değeri kabul et veya güncel kadroda yeniden işaretle.',
              ),
              for (final conflict in _conflicts)
                Text(
                  '${conflict.athleteId}: sen ${labels[conflict.sentStatus]}, sunucuda ${labels[conflict.currentStatus] ?? "kayıt yok"}',
                ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _conflicts = [];
                          _marks.clear();
                          ref.invalidate(versionedRosterProvider(_event!));
                        }),
                child: const Text('Sunucudakini kullan / yeniden işaretle'),
              ),
            ],
            if (_event != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SwanSpace.xl),
                child: FilledButton(
                  onPressed: _busy ||
                          frozen ||
                          denied ||
                          !eventVisible ||
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
                onPressed: _busy ? null : _saveOnline,
                child: const Text('Aynı işlemi tekrar dene'),
              ),
            if (_marks.isNotEmpty)
              TextButton(
                onPressed: _busy
                    ? null
                    : () async {
                        final accepted = await _confirm(
                          'Yerel işaretleri bırak?',
                          _uncertain
                              ? 'Sunucu işlemi almış olabilir. Yerel işaretleri bıraktıktan sonra kayıtları yeniden kontrol et; bu işlem sunucudaki yoklamayı silmez.'
                              : 'Henüz gönderilmemiş işaretler bırakılır. Sunucudaki yoklama değişmez.',
                        );
                        if (!accepted || !mounted) return;
                        setState(() {
                          _marks.clear();
                          _conflicts = [];
                          _uncertain = false;
                          _onlineOp = null;
                        });
                        if (_event != null) {
                          ref.invalidate(versionedRosterProvider(_event!));
                        }
                      },
                child: const Text('İşaretleri bırak ve kayıtları kontrol et'),
              ),
            if (confirmed.isNotEmpty)
              Text(
                '${confirmed.fold<int>(0, (sum, op) => sum + (op['applied'] as int? ?? 0))} işaret sunucuda doğrulandı (cihaz geçmişi).',
              ),
            Text(
              'Bekleyen Yoklamalar (${pending.length})',
              style: SwanType.h3(c.ink),
            ),
            if (queue != null)
              TextButton(
                onPressed:
                    _busy ? null : () => _action(() => _checkQueue(queue)),
                child: const Text('Gönderimi kontrol et'),
              ),
            for (final op in pending)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SwanSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cache
                              .where(
                                (s) => s['event_id'] == op['event_id'],
                              )
                              .firstOrNull?['title'] as String? ??
                          'Etkinlik ${op['event_id']}',
                      style: SwanType.body(c.ink),
                    ),
                    Text(
                      switch (op['state']) {
                        'conflict' => 'Çakışma: kararın gerekli',
                        'rejected' => 'Sunucu reddetti; cihaz kaydı korunuyor',
                        'paused' => 'Gönderim duraklatıldı',
                        'sending' => 'Sunucu yanıtı bekleniyor',
                        _ => 'Sunucuda henüz doğrulanmadı'
                      },
                    ),
                    if (op['error'] != null) Text(op['error'] as String),
                    if (op['state'] == 'rejected' && queue != null)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                final accepted = await _confirm(
                                  'Reddedilen işlemi bırak?',
                                  'Bu işaretler sunucuya uygulanmadı. İşlem cihaz geçmişinde tutulur; güncel kadroyu hazırlayıp yeniden işaretleyebilirsin.',
                                );
                                if (!accepted || !mounted) return;
                                await _action(
                                  () => queue.store.abandonRejected(
                                    queue.actor,
                                    op['op_id'] as String,
                                  ),
                                );
                              },
                        child: const Text('Reddedilen işlemi bırak'),
                      ),
                    if (op['state'] == 'conflict') ...[
                      for (final conflict in (op['conflicts'] as List)
                          .cast<Map<String, dynamic>>())
                        Text(
                          '${conflict['athlete_id']}: sen ${labels[conflict['sent_status']]}, sunucuda ${labels[conflict['current_status']] ?? 'kayıt yok'}',
                        ),
                      Wrap(
                        children: [
                          TextButton(
                            onPressed: _busy || queue == null
                                ? null
                                : () => _action(
                                      () => queue.store.resolve(
                                        queue.actor,
                                        op['op_id'] as String,
                                      ),
                                    ),
                            child: const Text('Sunucudakini kabul et'),
                          ),
                          TextButton(
                            onPressed: _busy || queue == null
                                ? null
                                : () => _action(() => queue.keepMine(op)),
                            child: const Text(
                              'Güncel sürüme kendi işaretimi uygula',
                            ),
                          ),
                        ],
                      ),
                    ] else if (['pending', 'paused', 'rejected']
                        .contains(op['state']))
                      TextButton(
                        onPressed: _busy || queue == null
                            ? null
                            : () => _action(() async {
                                  await queue.store.retry(
                                    queue.actor,
                                    op['op_id'] as String,
                                  );
                                  await _checkQueue(queue);
                                }),
                        child: const Text('Kontrol ettim, tekrar dene'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
