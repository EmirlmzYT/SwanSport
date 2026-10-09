import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

/// A single, retryable transaction. A lost response freezes the original draft.
class SeasonSetupScreen extends ConsumerStatefulWidget {
  const SeasonSetupScreen({super.key});
  @override
  ConsumerState<SeasonSetupScreen> createState() => _SeasonSetupScreenState();
}

class _SeasonSetupScreenState extends ConsumerState<SeasonSetupScreen> {
  final _label = TextEditingController();
  final _team = TextEditingController();
  final _fee = TextEditingController();
  final _amount = TextEditingController();
  final _selected = <String>{};
  final _days = <int>{1, 3, 5};
  DateTime _start = SeasonSetupDraft.dateOnly(DateTime.now());
  late DateTime _end = _start.add(const Duration(days: 364));
  late DateTime _until = _start.add(const Duration(days: 27));
  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  int _step = 0, _duration = 90, _due = 10;
  bool _activate = false, _program = false, _fees = false, _busy = false;
  String? _clubId, _operation, _error;
  SeasonSetupDraft? _pending;
  SeasonSetupResult? _result;
  static const _steps = [
    'Sezon',
    'Takım ve kadro',
    'Program',
    'Aidat planı',
    'Son kontrol',
  ];

  @override
  void dispose() {
    for (final c in [_label, _team, _fee, _amount]) {
      c.dispose();
    }
    super.dispose();
  }

  SeasonSetupDraft _draft() => SeasonSetupDraft(
        clubId: _clubId!,
        label: _label.text,
        startsOn: _start,
        endsOn: _end,
        teamName: _team.text,
        athleteIds: List.unmodifiable(_selected),
        activate: _activate,
        scheduleUntil: _program ? _until : null,
        weekdays: List.unmodifiable(_days.toList()..sort()),
        hour: _time.hour,
        minute: _time.minute,
        duration: _duration,
        feeName: _fees ? _fee.text : null,
        feeAmount: _fees
            ? num.tryParse(_amount.text.trim().replaceAll(',', '.'))
            : null,
        dueDay: _due,
      );

  Future<void> _date(int field) async {
    final initial = field == 0
        ? _start
        : field == 1
            ? _end
            : _until;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (field == 0) {
        _start = SeasonSetupDraft.dateOnly(picked);
      } else if (field == 1) {
        _end = SeasonSetupDraft.dateOnly(picked);
      } else {
        _until = SeasonSetupDraft.dateOnly(picked);
      }
    });
  }

  void _next() {
    String? error;
    if (_step == 0) {
      final span = _end.difference(_start).inDays;
      if (_label.text.trim().isEmpty || _label.text.trim().length > 80) {
        error = 'Sezon adı 1–80 karakter olmalı.';
      } else if (span < 0 || span > 365) {
        error = 'Sezon tarihleri sıralı ve en fazla 366 gün olmalı.';
      }
    } else if (_step == 1 &&
        (_team.text.trim().isEmpty || _team.text.trim().length > 80)) {
      error = 'Yeni takım adı 1–80 karakter olmalı.';
    } else if (_step >= 2) {
      error = _draft().validate();
    }
    setState(() {
      _error = error;
      if (error == null) _step++;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final club = ref.read(activeClubProvider).valueOrNull;
    if (club == null || club.id != _clubId) return;
    final draft = _pending ?? _draft();
    final validation = draft.validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _pending = draft;
      _operation ??= diagnosticId();
    });
    try {
      final result = await ref
          .read(clubConfigServiceProvider)
          .openSeason(draft, operationId: _operation!);
      for (final provider in [
        clubSeasonsProvider,
        teamsProvider,
        clubAthletesProvider,
        eventsProvider,
        feePlansProvider,
      ]) {
        ref.invalidate(provider);
      }
      if (mounted) {
        setState(() {
          _result = result;
          _pending = null;
        });
      }
    } on PostgrestException catch (e) {
      if (!mounted) return;
      final rejected = e.code == 'P0001' ||
          (e.code?.startsWith('22') ?? false) ||
          e.code == '42501' ||
          e.code == 'PGRST202' ||
          e.code == 'PGRST203';
      setState(() {
        _error = rejected
            ? 'Hazırlık kabul edilmedi. Tarihleri, adları, kadroyu ve yetkini kontrol et.'
            : 'İşlemin sonucu doğrulanamadı. Aynı hazırlığı tekrar dene; ikinci sezon oluşturulmaz.';
        if (rejected) {
          _pending = null;
          _operation = null;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'İşlemin sonucu doğrulanamadı. Aynı hazırlığı tekrar dene; ikinci sezon oluşturulmaz.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkRecords() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Önce kayıtları kontrol et'),
        content: const Text(
          'İşlem kaydedilmiş olabilir. Bu hazırlığın tekrar deneme ekranından çıkacaksın. Yeni bir hazırlık yapmadan önce Takımlar ve Takvim kayıtlarını kontrol et.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Burada kal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Takımları kontrol et'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      await Navigator.pushReplacementNamed<void, void>(context, '/teams');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final permitted = ref.watch(swanAccessProvider).isClubAdmin;
    final enabled = ref.watch(featureEnabledProvider(FeatureFlags.seasonSetup));
    final backend = ref.watch(isSupabaseEnabledProvider);
    if (!permitted || !enabled || !backend) {
      return Scaffold(
        appBar: AppBar(title: const Text('Sezon Açılışı')),
        body: const Center(
          child: Text('Sezon açılışı şu anda hesabına açık değil.'),
        ),
      );
    }
    final club = ref.watch(activeClubProvider);
    final athletes = ref.watch(clubAthletesProvider);
    return PopScope(
      canPop: !_busy && _pending == null,
      child: Scaffold(
        appBar: AppBar(title: const Text('Sezon Açılışı')),
        body: club.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
            child: Text('Kulüp yüklenemedi. Sayfayı yeniden aç.'),
          ),
          data: (value) {
            if (value == null || !value.isActive) {
              return const Center(
                child: Text('Aktif bir kulüp seçmelisin.'),
              );
            }
            _clubId ??= value.id;
            if (value.id != _clubId) {
              return const Center(
                child: Text(
                  'Aktif kulüp değişti. Hazırlık için sayfayı yeniden aç.',
                ),
              );
            }
            if (_result != null) return _success();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(SwanSpace.lg),
                  child: Column(
                    children: [
                      Text(value.name, style: SwanType.body(c.inkMuted)),
                      Text(
                        '${_step + 1}/5 · ${_steps[_step]}',
                        style: SwanType.h3(c.ink),
                      ),
                      const SizedBox(height: SwanSpace.sm),
                      LinearProgressIndicator(value: (_step + 1) / 5),
                    ],
                  ),
                ),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: _busy || _pending != null,
                    child: ListView(
                      padding: const EdgeInsets.all(SwanSpace.lg),
                      children: _body(athletes),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(SwanSpace.lg),
                    child: Text(
                      _error!,
                      style: SwanType.body(c.danger),
                      key: const Key('season-error'),
                    ),
                  ),
                if (_pending != null && !_busy)
                  TextButton(
                    onPressed: _checkRecords,
                    child: const Text('Kayıtları kontrol ederek çık'),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(SwanSpace.lg),
                    child: Row(
                      children: [
                        if (_step > 0)
                          TextButton(
                            onPressed: _busy || _pending != null
                                ? null
                                : () => setState(() {
                                      _step--;
                                      _error = null;
                                    }),
                            child: const Text('Geri'),
                          ),
                        const SizedBox(width: SwanSpace.md),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy
                                ? null
                                : _step == 4
                                    ? _save
                                    : _next,
                            child: Text(
                              _busy
                                  ? 'Hazırlanıyor…'
                                  : _step < 4
                                      ? 'Devam'
                                      : _pending != null
                                          ? 'Aynı işlemi tekrar dene'
                                          : 'Sezonu hazırla',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool money = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: SwanSpace.lg),
        child: TextField(
          controller: controller,
          maxLength: money ? 12 : 80,
          keyboardType: money
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
        ),
      );

  List<Widget> _body(AsyncValue<List<AthleteRow>> athletes) => switch (_step) {
        0 => [
            _field(_label, 'Sezon adı'),
            ListTile(
              title: const Text('Başlangıç'),
              subtitle: Text(SeasonSetupDraft.dateText(_start)),
              onTap: () => _date(0),
            ),
            ListTile(
              title: const Text('Bitiş'),
              subtitle: Text(SeasonSetupDraft.dateText(_end)),
              onTap: () => _date(1),
            ),
            SwitchListTile(
              title: const Text('Yeni sezonu aktif yap'),
              subtitle: const Text('Mevcut aktif sezonun yerini alır.'),
              value: _activate,
              onChanged: (v) => setState(() => _activate = v),
            ),
          ],
        1 => [
            _field(_team, 'Yeni takım adı'),
            const Text(
              'Mevcut takım adından farklı bir ad kullan. Kadroyu şimdi seçebilir veya sonra ekleyebilirsin.',
            ),
            Text('${_selected.length}/200 sporcu seçildi'),
            ...athletes.when(
              loading: () => [const LinearProgressIndicator()],
              error: (_, __) => [
                const Text('Sporcular yüklenemedi.'),
                TextButton(
                  onPressed: () => ref.invalidate(clubAthletesProvider),
                  child: const Text('Yeniden yükle'),
                ),
              ],
              data: (rows) => [
                for (final a in rows.where((a) => a.isActive))
                  CheckboxListTile(
                    title: Text(a.fullName),
                    value: _selected.contains(a.id),
                    onChanged:
                        !_selected.contains(a.id) && _selected.length >= 200
                            ? null
                            : (v) => setState(() {
                                  if (v == true) {
                                    _selected.add(a.id);
                                  } else {
                                    _selected.remove(a.id);
                                  }
                                }),
                  ),
              ],
            ),
          ],
        2 => [
            SwitchListTile(
              title: const Text('İlk haftaların programını ekle'),
              value: _program,
              onChanged: (v) => setState(() => _program = v),
            ),
            if (_program) ...[
              const Text(
                'Sezon başlangıcından itibaren en fazla 91 gün. Saatler Türkiye saatidir.',
              ),
              ListTile(
                title: const Text('Programın son günü'),
                subtitle: Text(SeasonSetupDraft.dateText(_until)),
                onTap: () => _date(2),
              ),
              Wrap(
                spacing: SwanSpace.sm,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(
                        const [
                          'Pzt',
                          'Sal',
                          'Çar',
                          'Per',
                          'Cum',
                          'Cmt',
                          'Paz',
                        ][d - 1],
                      ),
                      selected: _days.contains(d),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _days.add(d);
                        } else {
                          _days.remove(d);
                        }
                      }),
                    ),
                ],
              ),
              ListTile(
                title: const Text('Başlangıç saati'),
                subtitle: Text(_time.format(context)),
                onTap: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (mounted && t != null) setState(() => _time = t);
                },
              ),
              DropdownButtonFormField<int>(
                initialValue: _duration,
                decoration: const InputDecoration(labelText: 'Süre (dakika)'),
                items: [
                  for (final n in [15, 30, 45, 60, 90, 120, 180, 240])
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (v) => setState(() => _duration = v!),
              ),
            ],
          ],
        3 => [
            SwitchListTile(
              title: const Text('Taslak aidat planı hazırla'),
              value: _fees,
              onChanged: (v) => setState(() => _fees = v),
            ),
            const Text(
              'Plan pasif kaydedilir. Sporcuya aidat atanmaz ve borç oluşmaz. Aidat Yönetimi > Planlar üzerinden ayrıca etkinleştir.',
            ),
            if (_fees) ...[
              _field(_fee, 'Aidat planı adı'),
              _field(_amount, 'Aylık tutar (TL)', money: true),
              DropdownButtonFormField<int>(
                initialValue: _due,
                decoration: const InputDecoration(labelText: 'Son ödeme günü'),
                items: [
                  for (var n = 1; n <= 28; n++)
                    DropdownMenuItem(value: n, child: Text('$n')),
                ],
                onChanged: (v) => setState(() => _due = v!),
              ),
            ],
          ],
        _ => [
            Text(_label.text.trim(), style: SwanType.h3(context.swan.ink)),
            Text(
              '${SeasonSetupDraft.dateText(_start)} → ${SeasonSetupDraft.dateText(_end)}',
            ),
            Text(
              _activate
                  ? 'Aktif sezon değiştirilecek.'
                  : 'Sezon pasif hazırlanacak.',
            ),
            ListTile(
              title: Text(_team.text.trim()),
              subtitle: Text('${_selected.length} sporcu · yeni takım'),
            ),
            ListTile(
              title: Text(
                _program
                    ? '${_draft().eventCount} antrenman'
                    : 'Program eklenmeyecek',
              ),
              subtitle: _program
                  ? const Text(
                      'Takım üyelerine yeni antrenman bildirimi gider.',
                    )
                  : null,
            ),
            ListTile(
              title: Text(
                _fees
                    ? '${_fee.text.trim()} · ${_amount.text.trim()} TL'
                    : 'Aidat planı eklenmeyecek',
              ),
              subtitle: _fees
                  ? const Text(
                      'Pasif taslak · aidat ataması ve borç oluşturulmaz.',
                    )
                  : null,
            ),
            const Text(
              'Kaydetme bir bütündür. Herhangi bir adım başarısız olursa tüm hazırlık geri alınır.',
            ),
          ],
      };

  Widget _success() => ListView(
        padding: const EdgeInsets.all(SwanSpace.lg),
        children: [
          Text('Sezon hazırlandı', style: SwanType.h2(context.swan.ink)),
          Text(
            '${_result!.rosterCount} sporcu kadroya eklendi. ${_result!.eventCount} antrenman oluşturuldu.',
          ),
          if (_result!.feePlanId != null)
            const Text('Aidat planı pasif taslak olarak kaydedildi.'),
          for (final target in [
            ('Takımları aç', '/teams'),
            ('Takvimi aç', '/calendar'),
            ('Aidat Yönetimi', '/finans'),
          ])
            TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, target.$2),
              child: Text(target.$1),
            ),
        ],
      );
}
