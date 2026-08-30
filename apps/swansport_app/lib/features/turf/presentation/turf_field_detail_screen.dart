import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';

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

  TurfField get _field => widget.field;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final async = ref.watch(turfOccupancyGridProvider(_field.id));
    final isManager =
        ref.watch(swanAccessProvider).isTurfManagerOf(_field.id);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_field.name, style: sora(16, FontWeight.w800, ink)),
            Text('${_field.venueName} · ${_field.opensAt}–${_field.closesAt}',
                style:
                    jakarta(11, FontWeight.w600, SwanColors.textSecondary)),
          ],
        ),
      ),
      body: async.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (slots) {
          if (slots.isEmpty) {
            return premiumEmpty(
              context,
              icon: Icons.grass_rounded,
              title: 'Bu saha kapalı görünüyor',
              subtitle: 'Saatler henüz tanımlanmamış olabilir.',
            );
          }

          final byDay = <String, List<TurfSlot>>{};
          for (final s in slots) {
            final key = '${s.startsAt.year}-${s.startsAt.month}-${s.startsAt.day}';
            byDay.putIfAbsent(key, () => []).add(s);
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(turfOccupancyGridProvider(_field.id)),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                if (isManager) _managerBanner(isDark, ink),
                for (final day in byDay.entries) ...[
                  _dayHeader(ink, day.value.first.startsAt),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in day.value) _cell(isDark, ink, s, isManager),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
                if (_field.phone != null && _field.phone!.isNotEmpty)
                  Text('Rezervasyon için ara: ${_field.phone}',
                      style: jakarta(
                          11.5, FontWeight.w600, SwanColors.textSecondary)),
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
          border: Border.all(color: const Color(0xFF3FB950).withValues(alpha: .25)),
        ),
        child: Row(children: [
          const Icon(Icons.edit_calendar_rounded,
              color: Color(0xFF3FB950), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'Bu sahayı sen yönetiyorsun — bir saate dokunarak dolu/boş '
                'işaretleyebilirsin.',
                style: jakarta(11.5, FontWeight.w700, ink)),
          ),
        ]),
      );

  Widget _dayHeader(Color ink, DateTime day) {
    const gunler = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
    ];
    final label = '${gunler[day.weekday - 1]} · ${day.day.toString().padLeft(2, '0')}.'
        '${day.month.toString().padLeft(2, '0')}';
    return Text(label, style: jakarta(13, FontWeight.w800, ink));
  }

  Widget _cell(bool isDark, Color ink, TurfSlot s, bool isManager) {
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final freeColor = const Color(0xFF3FB950);
    final busyColor = const Color(0xFFD64545);
    final requestedColor = const Color(0xFFD9860B);

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

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 68,
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fg.withValues(alpha: s.occupied || s.requestedByMe ? .12 : .10),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: (s.occupied || s.requestedByMe)
                  ? fg.withValues(alpha: .3)
                  : line),
        ),
        child: Column(children: [
          Text(s.hourLabel,
              style: jakarta(12.5, FontWeight.w800,
                  (s.occupied || s.requestedByMe) ? fg : ink)),
          Text(label, style: jakarta(9.5, FontWeight.w700, fg)),
        ]),
      ),
    );
  }

  /// Bağlayıcı bir rezervasyon değil: saha yöneticisine oyuncunun ağzından
  /// gerçek bir mesaj gider, iki taraf sohbetten anlaşır. Son söz hâlâ
  /// yönetici — kesinleşince hücreyi o işaretler.
  Future<void> _request(TurfSlot s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${s.hourLabel} için sor'),
        content: const Text(
            'Saha yöneticisine bu saati sorduğunu bildiren bir mesaj '
            'gönderilecek ve sohbet açılacak. Rezervasyon, yönetici onaylayana '
            'kadar kesinleşmiş sayılmaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mesaj gönder'),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Mesajın gönderildi.'),
        action: SnackBarAction(
          label: 'Sohbete git',
          onPressed: () => Navigator.pushNamed(context, '/mesajlar'),
        ),
      ));
    } catch (e) {
      _say(_readable(e));
    } finally {
      if (mounted) setState(() => _busy = false);
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
    if (s.occupied) {
      setState(() => _busy = true);
      try {
        await ref
            .read(turfServiceProvider)
            .markFree(fieldId: _field.id, startsAt: s.startsAt);
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
    if (note == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(turfServiceProvider).markOccupied(
            fieldId: _field.id,
            startsAt: s.startsAt,
            note: note.trim().isEmpty ? null : note.trim(),
          );
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
