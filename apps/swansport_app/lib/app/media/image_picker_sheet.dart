import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';
import 'image_pick.dart';

typedef ImageSelectionLoader = Future<List<PickedImage>> Function({
  required ImagePickSource source,
  required int limit,
});

bool _pickerOpen = false;

/// Kamera/galeri, doğrulama ve onay tek akıştır; onaylanmadan yükleme yapmaz.
Future<List<PickedImage>> showImagePickerSheet(
  BuildContext context, {
  String title = 'Fotoğraf ekle',
  int limit = 1,
  ImageSelectionLoader picker = pickImages,
}) async {
  if (_pickerOpen) return [];
  if (limit < 1 || limit > 8) throw ArgumentError.value(limit, 'limit');
  _pickerOpen = true;
  FocusManager.instance.primaryFocus?.unfocus();
  try {
    final images = await _chooseSource(
      context,
      title: title,
      limit: limit,
      picker: picker,
    );
    if (!context.mounted || images.isEmpty) return [];
    return await Navigator.of(context).push<List<PickedImage>>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _ImageReview(
                images: images, title: title, limit: limit, picker: picker,),
          ),
        ) ??
        [];
  } finally {
    _pickerOpen = false;
  }
}

Future<PickedImage?> showSingleImagePicker(
  BuildContext context, {
  String title = 'Fotoğraf ekle',
}) async {
  final images = await showImagePickerSheet(context, title: title);
  return images.isEmpty ? null : images.first;
}

Future<List<PickedImage>> _chooseSource(
  BuildContext context, {
  required String title,
  required int limit,
  required ImageSelectionLoader picker,
}) async =>
    await showModalBottomSheet<List<PickedImage>>(
      context: context,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: context.swan.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
      ),
      builder: (_) =>
          _ImageSourceSheet(title: title, limit: limit, picker: picker),
    ) ??
    [];

class _ImageSourceSheet extends StatefulWidget {
  const _ImageSourceSheet({
    required this.title,
    required this.limit,
    required this.picker,
  });
  final ImageSelectionLoader picker;
  final String title;
  final int limit;

  @override
  State<_ImageSourceSheet> createState() => _ImageSourceSheetState();
}

class _ImageSourceSheetState extends State<_ImageSourceSheet> {
  bool _busy = false;
  String? _error;
  bool _permissionError = false;

  bool get _mobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<void> _pick(ImagePickSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _permissionError = false;
    });
    try {
      final images = await widget.picker(source: source, limit: widget.limit);
      for (final image in images) {
        if (image.bytes.isEmpty || image.bytes.length > 10 * 1024 * 1024) {
          throw const FormatException('Fotoğraf en fazla 10 MB olabilir.');
        }
        // Bozuk/çözülemeyen dosyayı önizlemeye ve yüklemeye taşıma.
        final codec =
            await ui.instantiateImageCodec(image.bytes, targetWidth: 64);
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
      }
      if (!mounted) return;
      if (images.isNotEmpty) Navigator.pop(context, images);
    } on PlatformException catch (e) {
      if (!mounted) return;
      final denied = e.code.toLowerCase().contains('denied') ||
          e.code.toLowerCase().contains('restricted');
      setState(() {
        _permissionError = denied;
        _error = denied
            ? source == ImagePickSource.camera
                ? 'Kamerayı kullanmak için cihaz ayarlarından kamera iznini açabilirsin.'
                : 'Fotoğraf erişimi kapalı. Cihaz ayarlarından izin verebilirsin.'
            : 'Fotoğraf seçici açılamadı. Tekrar deneyebilir veya galeriden seçebilirsin.';
      });
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Bu fotoğraf okunamadı. Başka bir fotoğraf seçmeyi dene.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SwanSpace.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(widget.title, style: SwanType.h3(c.ink)),),
                  IconButton(
                    tooltip: 'Vazgeç',
                    onPressed: _busy ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              if (_busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: SwanSpace.md),
                Text(
                  'Fotoğraflar hazırlanıyor…',
                  style: SwanType.bodySm(c.inkMuted),
                ),
              ],
              if (_mobile || kIsWeb)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Fotoğraf çek'),
                  subtitle: const Text('Kamerayla yeni bir fotoğraf çek'),
                  enabled: !_busy,
                  onTap: () => _pick(ImagePickSource.camera),
                ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeriden seç'),
                subtitle: Text(
                  widget.limit > 1
                      ? 'Tek seferde en fazla ${widget.limit} fotoğraf'
                      : 'Eklemek istediğin fotoğrafı seç',
                ),
                enabled: !_busy,
                onTap: () => _pick(ImagePickSource.gallery),
              ),
              if (_error != null) ...[
                Text(_error!, style: SwanType.bodySm(c.danger)),
                if (_permissionError && _mobile)
                  TextButton.icon(
                    onPressed: () async {
                      final opened = await openAppSettings();
                      if (!opened && mounted) {
                        setState(
                          () => _error =
                              'Cihazında Ayarlar > SwanSport bölümünü açıp izinleri değiştirebilirsin.',
                        );
                      }
                    },
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Cihaz ayarlarını aç'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageReview extends StatefulWidget {
  const _ImageReview({
    required this.images,
    required this.title,
    required this.limit,
    required this.picker,
  });
  final ImageSelectionLoader picker;
  final List<PickedImage> images;
  final String title;
  final int limit;

  @override
  State<_ImageReview> createState() => _ImageReviewState();
}

class _ImageReviewState extends State<_ImageReview> {
  late final List<PickedImage> _images = List.of(widget.images);
  final _pages = PageController();
  int _index = 0;
  bool _adding = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _move(int offset) {
    final next = _index + offset;
    if (next < 0 || next >= _images.length) return;
    setState(() {
      final image = _images.removeAt(_index);
      _images.insert(next, image);
      _index = next;
    });
    _pages.jumpToPage(next);
  }

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      final images = await _chooseSource(
        context,
        title: widget.title,
        limit: widget.limit - _images.length,
        picker: widget.picker,
      );
      if (mounted) setState(() => _images.addAll(images));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        title: Text(widget.title, style: SwanType.h3(c.ink)),
        actions: [
          TextButton(
            onPressed: _adding ? null : () => Navigator.pop(context, _images),
            child: Text(
              _images.length == 1
                  ? 'Fotoğrafı kullan'
                  : '${_images.length} fotoğrafı kullan',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(SwanSpace.md),
              child: Text(
                '${_index + 1} / ${_images.length} · Yakınlaştırarak kontrol edebilirsin',
                style: SwanType.caption(c.inkMuted),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _images.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (_, index) => InteractiveViewer(
                  key: ObjectKey(_images[index]),
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.memory(
                      _images[index].bytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(SwanSpace.md),
              child: Row(
                children: [
                  for (var i = 0; i < _images.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: SwanSpace.sm),
                      child: Semantics(
                        label: '${i + 1}. fotoğraf',
                        selected: i == _index,
                        button: true,
                        child: InkWell(
                          onTap: () => _pages.jumpToPage(i),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(SwanRadius.sm),
                              border: Border.all(
                                color: i == _index ? c.accent : c.line,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(SwanRadius.sm),
                              child: Image.memory(
                                _images[i].bytes,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                if (_images.length > 1) ...[
                  IconButton(
                    tooltip: 'Öne taşı',
                    onPressed: _index > 0 ? () => _move(-1) : null,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  IconButton(
                    tooltip: 'Arkaya taşı',
                    onPressed:
                        _index < _images.length - 1 ? () => _move(1) : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Kaldır'),
                  onPressed: () {
                    if (_images.length == 1) {
                      Navigator.pop(context, <PickedImage>[]);
                      return;
                    }
                    setState(() {
                      _images.removeAt(_index);
                      if (_index >= _images.length) _index = _images.length - 1;
                    });
                    _pages.jumpToPage(_index);
                  },
                ),
                if (_images.length < widget.limit)
                  TextButton.icon(
                    onPressed: _adding ? null : _add,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Fotoğraf ekle'),
                  ),
              ],
            ),
            const SizedBox(height: SwanSpace.md),
          ],
        ),
      ),
    );
  }
}
