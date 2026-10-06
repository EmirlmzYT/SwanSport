import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_page_header.dart';

/// Kulüp tesisleri ve sahalar için rezervasyon & takvim tahsisi ekranı.
///
/// Veriler doğrudan Supabase `facilities`, `events` ve `facility_conflicts` RPC'si
/// üzerinden çalışır.
class FacilityReservationScreen extends ConsumerStatefulWidget {
  const FacilityReservationScreen({super.key});

  @override
  ConsumerState<FacilityReservationScreen> createState() =>
      _FacilityReservationScreenState();
}

class _FacilityReservationScreenState
    extends ConsumerState<FacilityReservationScreen> {
  String? _selectedFacilityId;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 14, minute: 0);
  int _durationMinutes = 90;
  final TextEditingController _titleController =
      TextEditingController(text: 'Antrenman Seansı & Saha Kullanımı');
  List<FacilitySlot> _conflicts = [];
  bool _checkedConflicts = false;
  bool _isChecking = false;
  bool _isSubmitting = false;

  static const List<int> _durations = [60, 90, 120];

  DateTime get _startDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  DateTime get _endDateTime =>
      _startDateTime.add(Duration(minutes: _durationMinutes));

  Future<void> _checkConflicts(String facilityId) async {
    setState(() {
      _isChecking = true;
      _checkedConflicts = false;
    });

    try {
      final res = await ref.read(clubOpsServiceProvider).conflicts(
            facilityId: facilityId,
            start: _startDateTime,
            end: _endDateTime,
          );
      if (mounted) {
        setState(() {
          _conflicts = res;
          _checkedConflicts = true;
          _isChecking = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  Future<void> _submitBooking(
    BuildContext context,
    String clubId,
    String facilityId,
    String facilityName,
  ) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await ref.read(clubOpsServiceProvider).createEvent(
            clubId: clubId,
            title: title,
            kind: 'training',
            startsAt: _startDateTime,
            endsAt: _endDateTime,
            facilityId: facilityId,
            place: facilityName,
          );

      ref.invalidate(facilityLoadProvider);
      ref.invalidate(facilityScheduleProvider(facilityId));

      if (context.mounted) {
        setState(() {
          _isSubmitting = false;
          _checkedConflicts = false;
          _conflicts = [];
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$facilityName için rezervasyon oluşturuldu.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rezervasyon oluşturulamadı: $e'),
            backgroundColor: context.swan.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final clubAsync = ref.watch(activeClubProvider);
    final facilitiesAsync = ref.watch(facilityLoadProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(facilityLoadProvider);
                if (_selectedFacilityId != null) {
                  ref.invalidate(
                    facilityScheduleProvider(_selectedFacilityId!),
                  );
                }
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  SwanSpace.lg,
                  SwanSpace.md,
                  SwanSpace.lg,
                  120,
                ),
                children: [
                  SwanPageHeader(
                    title: 'Tesis Rezervasyonu',
                    subtitle: 'Saha, kort ve antrenman alanı tahsisi',
                    onBack: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(height: SwanSpace.md),
                  clubAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (err, _) => Container(
                      padding: const EdgeInsets.all(SwanSpace.md),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(SwanRadius.md),
                        border: Border.all(color: c.line),
                      ),
                      child: Text(
                        'Kulüp bilgisi yüklenemedi: $err',
                        style: SwanType.caption(c.danger),
                      ),
                    ),
                    data: (club) {
                      if (club == null) {
                        return Container(
                          padding: const EdgeInsets.all(SwanSpace.lg),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius:
                                BorderRadius.circular(SwanRadius.md),
                            border: Border.all(color: c.line),
                          ),
                          child: Text(
                            'Rezervasyon yapmak için aktif bir kulüp üyeliği gereklidir.',
                            style: SwanType.bodySm(c.ink),
                          ),
                        );
                      }

                      return facilitiesAsync.when(
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        error: (err, _) => Container(
                          padding: const EdgeInsets.all(SwanSpace.md),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius:
                                BorderRadius.circular(SwanRadius.md),
                            border: Border.all(color: c.line),
                          ),
                          child: Text(
                            'Tesisler yüklenemedi: $err',
                            style: SwanType.caption(c.danger),
                          ),
                        ),
                        data: (facilities) {
                          if (facilities.isEmpty) {
                            return _buildNoFacilitiesCard(c);
                          }

                          final facility = facilities.firstWhere(
                            (f) => f.facilityId == _selectedFacilityId,
                            orElse: () => facilities.first,
                          );

                          _selectedFacilityId = facility.facilityId;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFacilitySelector(c, facilities, facility),
                              const SizedBox(height: SwanSpace.lg),
                              _buildBookingForm(
                                context: context,
                                c: c,
                                clubId: club.id,
                                facility: facility,
                              ),
                              const SizedBox(height: SwanSpace.xl),
                              _buildScheduleSection(
                                c: c,
                                facilityId: facility.facilityId,
                                facilityName: facility.name,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildNoFacilitiesCard(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.xl),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        children: [
          Icon(Icons.stadium_outlined, size: 40, color: c.inkMuted),
          const SizedBox(height: SwanSpace.sm),
          Text(
            'Kayıtlı tesis bulunamadı',
            style: SwanType.bodySm(c.ink, w: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Kulübünüze ait henüz bir saha veya salon tanımlanmamış. Tesis yöneticisiyle iletişime geçebilirsiniz.',
            textAlign: TextAlign.center,
            style: SwanType.caption(c.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilitySelector(
    SwanPalette c,
    List<FacilityLoad> facilities,
    FacilityLoad selected,
  ) {
    return Container(
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.md),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tesis / Saha Seçin',
            style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: selected.facilityId,
            decoration: InputDecoration(
              filled: true,
              fillColor: c.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SwanRadius.md),
                borderSide: BorderSide(color: c.line),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SwanRadius.md),
                borderSide: BorderSide(color: c.line),
              ),
            ),
            dropdownColor: c.surface,
            items: facilities.map((f) {
              final kindInfo = f.kind != null ? '${f.kind} • ' : '';
              return DropdownMenuItem(
                value: f.facilityId,
                child: Text(
                  '${f.name} ($kindInfo%${f.loadPercent} Doluluk)',
                  style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedFacilityId = val;
                  _checkedConflicts = false;
                  _conflicts = [];
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBookingForm({
    required BuildContext context,
    required SwanPalette c,
    required String clubId,
    required FacilityLoad facility,
  }) {
    final startStr =
        '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}';
    final endStr =
        '${_endDateTime.hour.toString().padLeft(2, '0')}:${_endDateTime.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rezervasyon Detayları', style: SwanType.h3(c.ink)),
          const SizedBox(height: SwanSpace.md),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Rezervasyon / Faaliyet Başlığı',
              filled: true,
              fillColor: c.surfaceAlt,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(SwanRadius.md),
                borderSide: BorderSide(color: c.line),
              ),
            ),
            style: SwanType.bodySm(c.ink),
          ),
          const SizedBox(height: SwanSpace.md),
          // Tarih ve Başlangıç Saati
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedDate = picked;
                        _checkedConflicts = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(
                    '${_selectedDate.day}.${_selectedDate.month}.${_selectedDate.year}',
                    style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: c.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.sm),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _selectedTime,
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedTime = picked;
                        _checkedConflicts = false;
                      });
                    }
                  },
                  icon: const Icon(Icons.access_time_rounded, size: 16),
                  label: Text(
                    '$startStr - $endStr',
                    style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: c.line),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.md),
          Text(
            'Kullanım Süresi:',
            style: SwanType.caption(c.inkMuted, w: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: _durations.map((d) {
              final isSel = _durationMinutes == d;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('$d dk'),
                  selected: isSel,
                  selectedColor: c.accent.withValues(alpha: 0.15),
                  labelStyle: SwanType.caption(
                    isSel ? c.accent : c.ink,
                    w: isSel ? FontWeight.w700 : FontWeight.w500,
                  ),
                  backgroundColor: c.surfaceAlt,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: isSel ? c.accent : c.line),
                  ),
                  onSelected: (val) {
                    if (val) {
                      setState(() {
                        _durationMinutes = d;
                        _checkedConflicts = false;
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: SwanSpace.md),
          // Çakışma Kontrol Butonu & Durumu
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isChecking
                    ? null
                    : () => _checkConflicts(facility.facilityId),
                icon: _isChecking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Çakışma Kontrolü Yap'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.accent,
                  side: BorderSide(color: c.accent),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(width: SwanSpace.sm),
              if (_checkedConflicts)
                Expanded(
                  child: Text(
                    _conflicts.isEmpty
                        ? 'Saha müsait'
                        : '${_conflicts.length} çakışma var!',
                    style: SwanType.caption(
                      _conflicts.isEmpty
                          ? const Color(0xFF10B981)
                          : c.danger,
                      w: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (_checkedConflicts && _conflicts.isNotEmpty) ...[
            const SizedBox(height: SwanSpace.sm),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _conflicts.map((conf) {
                  return Text(
                    '• ${conf.title} (${conf.startsAt.hour}:${conf.startsAt.minute.toString().padLeft(2, '0')})',
                    style: SwanType.caption(c.danger, w: FontWeight.w600),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: SwanSpace.lg),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting
                  ? null
                  : () => _submitBooking(
                        context,
                        clubId,
                        facility.facilityId,
                        facility.name,
                      ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.done_rounded, size: 20),
              label: Text(
                _isSubmitting
                    ? 'Kaydediliyor...'
                    : 'Rezervasyonu Onayla ve Ayırt',
                style: SwanType.bodySm(Colors.white, w: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection({
    required SwanPalette c,
    required String facilityId,
    required String facilityName,
  }) {
    final scheduleAsync = ref.watch(facilityScheduleProvider(facilityId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('7 Günlük Tesis Programı', style: SwanType.h3(c.ink)),
            Text(facilityName, style: SwanType.caption(c.accent, w: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: SwanSpace.sm),
        scheduleAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (err, _) => Text(
            'Program alınamadı: $err',
            style: SwanType.caption(c.danger),
          ),
          data: (slots) {
            if (slots.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(SwanSpace.md),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(SwanRadius.md),
                  border: Border.all(color: c.line),
                ),
                child: Text(
                  'Önümüzdeki 7 günde planlanmış antrenman bulunmuyor.',
                  style: SwanType.caption(c.inkMuted),
                ),
              );
            }

            return Column(
              children: slots.map((s) {
                final start = s.startsAt;
                final dateStr =
                    '${start.day}.${start.month} · ${start.hour}:${start.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(SwanSpace.sm),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(SwanRadius.sm),
                    border: Border.all(color: c.line),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.title,
                          style: SwanType.bodySm(c.ink, w: FontWeight.w600),
                        ),
                      ),
                      Text(
                        dateStr,
                        style: SwanType.caption(c.inkMuted),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

