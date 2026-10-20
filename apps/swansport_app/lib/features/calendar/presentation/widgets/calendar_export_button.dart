import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

class CalendarExportButton extends ConsumerStatefulWidget {
  const CalendarExportButton({required this.events, super.key});
  final List<UnifiedCalendarEvent> events;
  @override
  ConsumerState<CalendarExportButton> createState() =>
      _CalendarExportButtonState();
}

class _CalendarExportButtonState extends ConsumerState<CalendarExportButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => IconButton(
      tooltip: 'Görünen etkinlikleri takvimime aktar',
      onPressed: _busy || widget.events.isEmpty ? null : _save,
      icon: const Icon(Icons.event_available_outlined));
  Future<void> _save() async {
    final account = ref.read(authSessionProvider).valueOrNull?.user.id;
    final events = List<UnifiedCalendarEvent>.of(
        widget.events.where((e) => e.guardianResult == null));
    if (events.isEmpty) return;
    final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Takvimime aktar'),
                content: Text(
                    '${events.length} etkinlik .ics dosyası olarak kaydedilecek. Dosyayı telefonunun takvim uygulamasında açabilirsin. Sonraki değişiklik ve iptaller otomatik eşitlenmez.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Vazgeç')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Dosyayı kaydet'))
                ]));
    if (approved != true ||
        !mounted ||
        account != ref.read(authSessionProvider).valueOrNull?.user.id) return;
    setState(() => _busy = true);
    try {
      await FilePicker.saveFile(
          fileName: 'swansport-takvim.ics',
          mimeType: 'text/calendar',
          bytes: Uint8List.fromList(utf8
              .encode(exportCalendar(events, generatedAt: DateTime.now()))));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Takvim dosyası kaydedilemedi. Yeniden dene.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
