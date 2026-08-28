import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/theme/console_theme.dart';
import 'attendance_providers.dart';

/// Tekrarlayan antrenman serisi kurma penceresi.
///
/// Mevcut `create_event_series` RPC'sini çağırır — tekrar mantığı sunucuda,
/// `Europe/Istanbul` saatiyle. Aynı işi istemcide tarih üreterek yapmak, yaz
/// saati geçişlerinde antrenmanları bir saat kaydırırdı.
Future<void> showSeriesDialog(BuildContext context, WidgetRef ref) async {
  await showDialog<void>(
    context: context,
    builder: (_) => const _SeriesDialog(),
  );
}

class _SeriesDialog extends ConsumerStatefulWidget {
  const _SeriesDialog();

  @override
  ConsumerState<_SeriesDialog> createState() => _SeriesDialogState();
}

class _SeriesDialogState extends ConsumerState<_SeriesDialog> {
  final _title = TextEditingController(text: 'Antrenman');
  final _place = TextEditingController();

  /// ISO gün numaraları: 1 = Pazartesi.
  final Set<int> _weekdays = {1, 3, 5};

  TimeOfDay _time = const TimeOfDay(hour: 18, minute: 0);
  int _minutes = 90;
  DateTime _from = DateTime.now();
  DateTime _until = DateTime.now().add(const Duration(days: 84));

  String? _facilityId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final facilities = ref.watch(facilitiesProvider);

    return AlertDialog(
      title: const Text('Tekrarlayan antrenman'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Başlık'),
              ),
              const SizedBox(height: ConsoleDensity.md),
              Text('GÜNLER', style: t.textTheme.labelSmall),
              const SizedBox(height: ConsoleDensity.sm),
              Wrap(
                spacing: ConsoleDensity.sm,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      label: Text(_dayShort(d)),
                      selected: _weekdays.contains(d),
                      onSelected: (v) => setState(() {
                        if (v) {
                          _weekdays.add(d);
                        } else {
                          _weekdays.remove(d);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: ConsoleDensity.lg),
              Row(
                children: [
                  Expanded(
                    child: _Picker(
                      label: 'SAAT',
                      value:
                          '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: _time);
                        if (picked != null) setState(() => _time = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: ConsoleDensity.md),
                  Expanded(
                    child: TextFormField(
                      initialValue: '$_minutes',
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Süre (dk)'),
                      onChanged: (v) =>
                          _minutes = int.tryParse(v) ?? _minutes,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ConsoleDensity.md),
              Row(
                children: [
                  Expanded(
                    child: _Picker(
                      label: 'BAŞLANGIÇ',
                      value: _fmt(_from),
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  const SizedBox(width: ConsoleDensity.md),
                  Expanded(
                    child: _Picker(
                      label: 'BİTİŞ',
                      value: _fmt(_until),
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ConsoleDensity.md),
              facilities.when(
                loading: () => const SizedBox(
                    height: 48,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2))),
                error: (_, __) => TextField(
                  controller: _place,
                  decoration: const InputDecoration(
                      labelText: 'Yer (tesis listesi alınamadı)'),
                ),
                data: (list) => list.isEmpty
                    ? TextField(
                        controller: _place,
                        decoration: const InputDecoration(labelText: 'Yer'),
                      )
                    : DropdownButtonFormField<String?>(
                        initialValue: _facilityId,
                        decoration: const InputDecoration(labelText: 'Tesis'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('Tesis seçme')),
                          for (final f in list)
                            DropdownMenuItem(
                                value: f.id, child: Text(f.name)),
                        ],
                        onChanged: (v) => setState(() => _facilityId = v),
                      ),
              ),
              if (_error != null) ...[
                const SizedBox(height: ConsoleDensity.md),
                Text(_error!,
                    style: t.textTheme.bodySmall
                        ?.copyWith(color: t.colorScheme.error)),
              ],
              const SizedBox(height: ConsoleDensity.md),
              Text(
                'Seçilen günlerde, iki tarih arasındaki her hafta için bir '
                'antrenman oluşturulur. Tesis seçersen çakışma sunucuda '
                'kontrol edilir.',
                style: t.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _busy || _weekdays.isEmpty ? null : _create,
          child: Text(_busy ? 'Oluşturuluyor…' : 'Oluştur'),
        ),
      ],
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _until,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _until = picked;
      }
    });
  }

  Future<void> _create() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final club = await ref.read(activeClubProvider.future);
      if (club == null) throw StateError('Aktif kulüp yok');

      final count = await ref.read(clubOpsServiceProvider).createEventSeries(
            clubId: club.id,
            title: _title.text.trim().isEmpty
                ? 'Antrenman'
                : _title.text.trim(),
            kind: 'training',
            from: _from,
            until: _until,
            hour: _time.hour,
            minute: _time.minute,
            weekdays: _weekdays.toList()..sort(),
            minutes: _minutes,
            facilityId: _facilityId,
            place: _facilityId == null && _place.text.trim().isNotEmpty
                ? _place.text.trim()
                : null,
          );

      ref
        ..invalidate(attendanceEventsProvider)
        ..invalidate(eventsProvider);

      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('$count antrenman oluşturuldu.')),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _busy = false;
        });
      }
    }
  }

  static String _dayShort(int iso) =>
      const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'][iso - 1];

  static String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _Picker extends StatelessWidget {
  const _Picker({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ConsoleDensity.radius),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value),
      ),
    );
  }
}
