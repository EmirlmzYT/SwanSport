import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

class ReportProblemSheet extends ConsumerStatefulWidget {
  const ReportProblemSheet({super.key});
  @override
  ConsumerState<ReportProblemSheet> createState() => _ReportProblemSheetState();
}

class _ReportProblemSheetState extends ConsumerState<ReportProblemSheet> {
  final _subject = TextEditingController(), _body = TextEditingController();
  bool _includeTechnical = false, _sending = false, _picking = false;
  Uint8List? _image;
  String? _ticket, _attachment, _message;
  late final Map<String, dynamic> _snapshot =
      ref.read(diagnosticsProvider).supportSnapshot();
  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return PopScope(
      canPop: !_sending,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            SwanSpace.lg,
            SwanSpace.lg,
            SwanSpace.lg,
            MediaQuery.viewInsetsOf(context).bottom + SwanSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Sorun bildir',
                      style: SwanType.h3(c.ink),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kapat',
                    onPressed: _sending ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              TextField(
                controller: _subject,
                enabled: !_sending && _ticket == null,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Konu',
                  hintText: 'Ne çalışmadı?',
                ),
              ),
              TextField(
                controller: _body,
                enabled: !_sending && _ticket == null,
                minLines: 3,
                maxLines: 7,
                maxLength: 2000,
                decoration: const InputDecoration(
                  labelText: 'Ne oldu?',
                  hintText: 'Ne yaptın, ne bekliyordun ve ne oldu?',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Teknik bilgileri bu talebe ekle'),
                subtitle: const Text(
                  'Sürüm, platform, ekran ve varsa son teknik işlemler. Otomatik kayıt tercihini değiştirmez.',
                ),
                value: _includeTechnical,
                onChanged: _sending
                    ? null
                    : (v) => setState(
                          () => _includeTechnical = v ?? false,
                        ),
              ),
              if (_includeTechnical)
                ExpansionTile(
                  title: const Text('Gönderilecek teknik bilgiler'),
                  children: [
                    SelectableText(
                      'Sürüm: ${_snapshot['release']}\nPlatform: ${_snapshot['platform']}\nEkran: ${_snapshot['screen']}\nTeknik işlem sayısı: ${(_snapshot['events'] as List).length}',
                    ),
                  ],
                ),
              OutlinedButton.icon(
                onPressed: _sending || _picking ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                  _picking ? 'Görsel hazırlanıyor…' : 'Ekran görüntüsü seç',
                ),
              ),
              Text(
                'İsteğe bağlı. Özel bilgileri gizleyerek ekle. Görsel yalnızca sen ve yetkili SwanSport ekibi tarafından görülebilir.',
                style: SwanType.caption(c.inkMuted),
              ),
              if (_image != null) ...[
                const SizedBox(height: SwanSpace.sm),
                Image.memory(_image!, height: 180, fit: BoxFit.contain),
                TextButton(
                  onPressed: _sending
                      ? null
                      : () => setState(() {
                            _image = null;
                            _attachment = null;
                          }),
                  child: const Text('Görseli kaldır'),
                ),
              ],
              const SizedBox(height: SwanSpace.md),
              Text(
                'Şifre, belge, sağlık bilgisi, kart numarası veya IBAN yazma.',
                style: SwanType.caption(c.inkMuted),
              ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: SwanSpace.sm,
                  ),
                  child: Text(
                    _message!,
                    style: SwanType.bodySm(c.danger),
                  ),
                ),
              FilledButton(
                onPressed: _sending || _picking ? null : _send,
                child: Text(
                  _sending
                      ? 'Gönderiliyor…'
                      : _ticket == null
                          ? 'Gönder'
                          : 'Teknik ekleri tekrar gönder',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    setState(() => _picking = true);
    ui.Codec? codec;
    ui.Image? decoded;
    try {
      final selected = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
      );
      final bytes = await selected?.readAsBytes();
      if (bytes == null) return;
      if (bytes.length > 5242880) throw const FormatException('size');
      // Re-encode to PNG: remove EXIF/location metadata and constrain dimensions.
      codec = await ui.instantiateImageCodecWithSize(
        await ui.ImmutableBuffer.fromUint8List(bytes),
        getTargetSize: (width, height) {
          final longest = width > height ? width : height;
          if (longest <= 1600) {
            return ui.TargetImageSize(width: width, height: height);
          }
          return ui.TargetImageSize(
            width: (width * 1600 / longest).round().clamp(1, 1600),
            height: (height * 1600 / longest).round().clamp(1, 1600),
          );
        },
      );
      final frame = await codec.getNextFrame();
      decoded = frame.image;
      final data = await decoded.toByteData(format: ui.ImageByteFormat.png);
      if (data == null || data.lengthInBytes > 5242880) {
        throw const FormatException('size');
      }
      if (mounted) {
        setState(() {
          _image = data.buffer.asUint8List();
          _attachment = null;
          _message = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Görsel açılamadı. En fazla 5 MB PNG veya JPEG seç.',
        );
      }
    } finally {
      decoded?.dispose();
      codec?.dispose();
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _send() async {
    if (_subject.text.trim().isEmpty || _body.text.trim().isEmpty) {
      setState(() => _message = 'Konu ve açıklama gerekli.');
      return;
    }
    setState(() {
      _sending = true;
      _message = null;
    });
    final subject = _subject.text.trim(), body = _body.text.trim();
    final lifecycle = ref.read(clubLifecycleServiceProvider);
    final diagnostics = ref.read(diagnosticsServiceProvider);
    final recorder = ref.read(diagnosticsProvider);
    try {
      if (_ticket == null) {
        final club = await ref.read(activeClubProvider.future);
        _ticket = await recorder.trace(
          'action:support_ticket',
          () => lifecycle.openTicket(
            subject: subject,
            body: body,
            clubId: club?.id,
            context: {'screen': '/destek'},
          ),
        );
      }
      if (_image != null && _attachment == null) {
        _attachment = await diagnostics.uploadScreenshot(_ticket!, _image!);
      }
      if (_includeTechnical || _attachment != null) {
        final snapshot = _includeTechnical
            ? _snapshot
            : {
                'session_id': _snapshot['session_id'],
                'screen': '/unknown',
                'release': 'unknown',
                'platform': 'unknown',
                'events': <Map<String, dynamic>>[],
              };
        await diagnostics.linkTicket(
          _ticket!,
          snapshot,
          attachment: _attachment,
        );
      }
      if (mounted) {
        ref.invalidate(myTicketsProvider);
        setState(() => _sending = false);
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = _ticket == null
              ? 'Talep gönderilemedi. Bağlantını kontrol edip tekrar dene.'
              : 'Talebin alındı ancak teknik ekler gönderilemedi. Tekrar göndermek yeni talep oluşturmaz.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
