import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import '../../../app/widgets/swan_module_app_bar.dart';
import '../../../app/design/swan_shape.dart';
import '../../courts/presentation/venue_overview.dart';
import '../../../app/widgets/action_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../saha_operations/presentation/turf_duty_invite_dialog.dart';

/// Sahanın haftalık doluluk şeridi.
///
/// Tek ekran, iki rol: herkes görür, yönetici olan kişi hücreye dokununca
/// dolu/boş işaretler. Ayrı bir "Saha Yönetimi" ekranı yok — düzenleme
/// kontrolü aynı ekranda, `SwanAccess.isTurfManagerOf` şartına bağlı.
class TurfFieldDetailScreen extends ConsumerStatefulWidget {
  const TurfFieldDetailScreen({required this.field, super.key});
  final TurfField field;

  @override
  ConsumerState<TurfFieldDetailScreen> createState() =>
      _TurfFieldDetailScreenState();
}

class _TurfFieldDetailScreenState extends ConsumerState<TurfFieldDetailScreen> {
  bool _busy = false;
  String? _selectedDayKey;

  TurfField get _field => widget.field;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark ? SwanPalette.dark : SwanPalette.light).bg;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;

    final async = ref.watch(turfOccupancyGridProvider(_field.id));
    final isManager =
        ref.watch(swanAccessProvider).canEditTurfOccupancy(_field.id);

    return SwanScaffold(
      backgroundColor: bg,
      appBar: swanModuleAppBar(context,
          title: _field.name,
          subtitle:
              '${_field.venueName} · ${_field.opensAt}–${_field.closesAt}'),
      body: async.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(
          context,
          'Müsaitlik bilgisi yüklenemedi.',
          onRetry: () => ref.invalidate(turfOccupancyGridProvider(_field.id)),
        ),
        data: (slots) {
          final byDay = <String, List<TurfSlot>>{};
          for (final s in slots) {
            final key =
                '${s.startsAt.year}-${s.startsAt.month}-${s.startsAt.day}';
            byDay.putIfAbsent(key, () => []).add(s);
          }
          final selectedKey = byDay.containsKey(_selectedDayKey)
              ? _selectedDayKey
              : (byDay.isEmpty ? null : byDay.keys.first);
          final selectedSlots = selectedKey == null
              ? const <TurfSlot>[]
              : byDay[selectedKey] ?? const <TurfSlot>[];

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(turfOccupancyGridProvider(_field.id)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                VenueOverview(
                    where: _field.where,
                    surfaceType: _field.surfaceType,
                    photoUrls: _field.photoUrls,
                    lat: _field.lat,
                    lng: _field.lng),
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                if (isManager) _managerBanner(isDark, ink),
                Wrap(
                    spacing: SwanSpace.sm,
                    runSpacing: SwanSpace.sm,
                    children: [
                      if (ref.watch(
                          featureEnabledProvider(FeatureFlags.turfDelegation)))
                        ActionChip(
                          backgroundColor: context.swan.surface,
                          avatar: Icon(Icons.schedule_rounded,
                              color: context.swan.inkMuted),
                          onPressed: () =>
                              Navigator.pushNamed(context, '/saha-islemlerim'),
                          label: const Text('Saha görevlerim'),
                        ),
                      if (ref.watch(
                            featureEnabledProvider(FeatureFlags.turfDelegation),
                          ) &&
                          ref
                              .watch(swanAccessProvider)
                              .isTurfManagerOf(_field.id))
                        ActionChip(
                          backgroundColor: context.swan.surface,
                          avatar: Icon(Icons.person_add_outlined,
                              color: context.swan.inkMuted),
                          onPressed: _busy
                              ? null
                              : () => showDialog<void>(
                                    context: context,
                                    builder: (_) => TurfDutyInviteDialog(
                                        fieldId: _field.id),
                                  ),
                          label: const Text('Görev devret'),
                        ),
                    ]),
                const SizedBox(height: SwanSpace.md),
                Text('Gün ve saat seç', style: SwanType.h3(ink)),
                const SizedBox(height: SwanSpace.xs),
                Text(
                  isManager
                      ? 'Bir saate dokunarak doluluk durumunu yönetebilirsin.'
                      : 'Müsait bir saat seçerek saha yöneticisine istek gönder.',
                  style: SwanType.caption(context.swan.inkMuted),
                ),
                const SizedBox(height: SwanSpace.md),
                if (byDay.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      for (final day in byDay.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: SwanSpace.sm),
                          child: ChoiceChip(
                            label: Text(_shortDay(day.value.first.startsAt)),
                            selected: selectedKey == day.key,
                            onSelected: (_) =>
                                setState(() => _selectedDayKey = day.key),
                          ),
                        ),
                    ]),
                  ),
                const SizedBox(height: SwanSpace.md),
                _legend(ink),
                const SizedBox(height: SwanSpace.md),
                if (selectedSlots.isEmpty)
                  _emptyAvailability(ink)
                else ...[
                  _dayHeader(ink, selectedSlots.first.startsAt),
                  const SizedBox(height: SwanSpace.sm),
                  Wrap(
                    spacing: SwanSpace.sm,
                    runSpacing: SwanSpace.sm,
                    children: [
                      for (final s in selectedSlots)
                        _cell(isDark, ink, s, isManager),
                    ],
                  ),
                  const SizedBox(height: SwanSpace.lg),
                ],
                if (_field.phone != null && _field.phone!.isNotEmpty)
                  Text(
                    'Rezervasyon için ara: ${_field.phone}',
                    style: SwanType.caption(
                      context.swan.inkMuted,
                      w: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _managerBanner(bool isDark, Color ink) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF3FB950).withValues(alpha: .09),
          borderRadius: BorderRadius.circular(15),
          border:
              Border.all(color: const Color(0xFF3FB950).withValues(alpha: .25)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.edit_calendar_rounded,
              color: Color(0xFF3FB950),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ref.watch(swanAccessProvider).isTurfManagerOf(_field.id)
                    ? 'Bu sahayı sen yönetiyorsun; bir saate dokunarak dolu/boş işaretleyebilirsin.'
                    : 'Geçici saha görevin var; doluluk işaretleyebilirsin. Süre bitince erişimin kapanır.',
                style: SwanType.caption(ink, w: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  Widget _dayHeader(Color ink, DateTime day) {
    const gunler = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar',
    ];
    final label =
        '${gunler[day.weekday - 1]} · ${day.day.toString().padLeft(2, '0')}.'
        '${day.month.toString().padLeft(2, '0')}';
    return Text(label, style: SwanType.bodySm(ink, w: FontWeight.w800));
  }

  String _shortDay(DateTime day) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return '${days[day.weekday - 1]} ${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}';
  }

  Widget _legend(Color ink) => Wrap(
        spacing: SwanSpace.md,
        runSpacing: SwanSpace.xs,
        children: [
          _legendItem(const Color(0xFF3FB950), 'Müsait', ink),
          _legendItem(const Color(0xFFD64545), 'Dolu', ink),
          _legendItem(SwanPalette.light.warning, 'İstek gönderildi', ink),
        ],
      );

  Widget _legendItem(Color color, String label, Color ink) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: SwanSpace.xs),
          Text(label, style: SwanType.caption(ink, w: FontWeight.w700)),
        ],
      );

  Widget _emptyAvailability(Color ink) => Container(
        padding: const EdgeInsets.all(SwanSpace.lg),
        decoration: BoxDecoration(
          color: context.swan.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.swan.line),
        ),
        child: Column(children: [
          Icon(Icons.event_busy_outlined, color: context.swan.inkMuted),
          const SizedBox(height: SwanSpace.sm),
          Text('Bu gün için saat bulunmuyor',
              style: SwanType.bodySm(ink, w: FontWeight.w800)),
          const SizedBox(height: SwanSpace.xs),
          Text('Başka bir gün seçebilir veya müsaitliği yenileyebilirsin.',
              textAlign: TextAlign.center,
              style: SwanType.caption(context.swan.inkMuted)),
          TextButton.icon(
            onPressed: () =>
                ref.invalidate(turfOccupancyGridProvider(_field.id)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Müsaitliği yenile'),
          ),
        ]),
      );

  Widget _cell(bool isDark, Color ink, TurfSlot s, bool isManager) {
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    const freeColor = Color(0xFF3FB950);
    const busyColor = Color(0xFFD64545);
    final requestedColor = SwanPalette.light.warning;

    final VoidCallback? onTap;
    if (isManager) {
      onTap = _busy ? null : () => _toggle(s);
    } else if (!s.occupied && !s.requestedByMe) {
      onTap = _busy ? null : () => _request(s);
    } else {
      onTap = null;
    }

    final Color fg;
    final String label;
    if (s.occupied) {
      fg = busyColor;
      label = 'Dolu';
    } else if (s.requestedByMe) {
      fg = requestedColor;
      label = 'İstendi';
    } else {
      fg = freeColor;
      label = 'Boş';
    }

    return Semantics(
      button: onTap != null,
      label: '${s.hourLabel}, $label',
      child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fg.withValues(
                  alpha: s.occupied || s.requestedByMe ? .12 : .10),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: (s.occupied || s.requestedByMe)
                    ? fg.withValues(alpha: .3)
                    : line,
              ),
            ),
            child: Column(
              children: [
                Text(
                  s.hourLabel,
                  style: SwanType.caption(
                    (s.occupied || s.requestedByMe) ? fg : ink,
                    w: FontWeight.w800,
                  ),
                ),
                Text(label, style: SwanType.caption(fg, w: FontWeight.w700)),
              ],
            ),
          )),
    );
  }

  /// Bağlayıcı bir rezervasyon değil: saha yöneticisine oyuncunun ağzından
  /// gerçek bir mesaj gider, iki taraf sohbetten anlaşır. Son söz hâlâ
  /// yönetici — kesinleşince hücreyi o işaretler.
  Future<void> _request(TurfSlot s) async {
    if (!await requireSwanAction(context, ref, SwanAction.reservation) ||
        !mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('İstek özeti'),
        content: Text(
            '${_field.name}\n${_field.venueName}\n${_shortDay(s.startsAt)} · ${s.hourLabel}\n\n'
            'Saha yöneticisine mesaj gönderilir. Yönetici onaylayana kadar rezervasyon kesinleşmez.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Rezervasyon isteği gönder'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(turfServiceProvider)
          .requestSlot(fieldId: _field.id, startsAt: s.startsAt);
      ref.invalidate(turfOccupancyGridProvider(_field.id));
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(Icons.schedule_send_rounded, color: context.swan.accent),
          title: const Text('İstek gönderildi'),
          content: Text(
            '${_field.name} · ${_shortDay(s.startsAt)} ${s.hourLabel}\n\n'
            'Durum: Onay bekliyor. Yöneticiyle mevcut sohbet akışından görüşebilirsin.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.pushNamed(context, '/mesajlar');
              },
              child: const Text('Sohbete git'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tamam'),
            ),
          ],
        ),
      );
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted && _busy) setState(() => _busy = false);
    }
  }

  /// Postgres istisnaları `PostgrestException(message: …)` diye geliyor;
  /// kullanıcıya ham hata gösterilmez.
  String _readable(Object e) {
    final text = '$e';
    final match = RegExp(r'message: ([^,]+)').firstMatch(text);
    return match?.group(1)?.trim() ?? 'Bir şeyler ters gitti.';
  }

  Future<void> _toggle(TurfSlot s) async {
    if (_busy) return;
    if (s.occupied) {
      setState(() => _busy = true);
      try {
        await ref
            .read(turfServiceProvider)
            .markFree(fieldId: _field.id, startsAt: s.startsAt);
        if (!mounted) return;
        ref.invalidate(turfOccupancyGridProvider(_field.id));
      } catch (e) {
        _say(_readable(e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    final note = await showDialog<String>(
      context: context,
      builder: (_) => _NoteDialog(hour: s.hourLabel),
    );
    if (note == null || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(turfServiceProvider).markOccupied(
            fieldId: _field.id,
            startsAt: s.startsAt,
            note: note.trim().isEmpty ? null : note.trim(),
          );
      if (!mounted) return;
      ref.invalidate(turfOccupancyGridProvider(_field.id));
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.hour});
  final String hour;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.hour} dolu işaretle'),
      content: TextField(
        controller: _ctrl,
        decoration: const InputDecoration(
          labelText: 'Not (isteğe bağlı)',
          hintText: 'Ahmet - haftalık',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          child: const Text('İşaretle'),
        ),
      ],
    );
  }
}
