import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

/// Halı saha yönetimi — yalnızca platform yöneticisi.
///
/// courts_screen.dart'ın deseni: sahalar elle ekleniyor. Farkı: burada
/// ayrıca "yönetici davet kodu" üretiliyor — sahayı gerçekten işleten kişiye
/// elden (WhatsApp vb.) iletilip `/veli-bagla` ekranından girilir, tıpkı
/// kulüp muhasebecisi davetiyle aynı model.
class ConsoleTurfFieldsScreen extends ConsumerWidget {
  const ConsoleTurfFieldsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(turfFieldsProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Halı Sahalar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Saha ekle'),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (fields) {
          if (fields.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                    'Henüz halı saha yok. Ekledikten sonra "Davet kodu" ile '
                    'sahayı işleten kişiye yönetici erişimi verebilirsin.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: fields.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final f = fields[i];
              return ListTile(
                leading: const Icon(Icons.grass_rounded),
                title: Text('${f.venueName} · ${f.name}'),
                subtitle: Text([
                  if (f.where.isNotEmpty) f.where,
                  '${f.opensAt}–${f.closesAt}',
                  if ((f.phone ?? '').isNotEmpty) f.phone!,
                ].join(' · ')),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    tooltip: 'Yönetici davet kodu',
                    icon: const Icon(Icons.key_rounded),
                    onPressed: () => _invite(context, ref, f),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: () => _edit(context, ref, f),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(
      BuildContext context, WidgetRef ref, TurfField? field) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TurfFieldDialog(field: field),
    );
    if (saved == true) ref.invalidate(turfFieldsProvider(null));
  }

  Future<void> _invite(
      BuildContext context, WidgetRef ref, TurfField field) async {
    try {
      final code =
          await ref.read(turfServiceProvider).createManagerInvite(field.id);
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Yönetici davet kodu'),
          content: SelectableText(
              '$code\n\nBu kodu sahayı işleten kişiye ilet. Kişi uygulamada '
              '"Kod Gir" ekranından girip yönetici olur. 48 saat geçerli.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }
}

class _TurfFieldDialog extends ConsumerStatefulWidget {
  const _TurfFieldDialog({this.field});
  final TurfField? field;

  @override
  ConsumerState<_TurfFieldDialog> createState() => _TurfFieldDialogState();
}

class _TurfFieldDialogState extends ConsumerState<_TurfFieldDialog> {
  late final _name = TextEditingController(text: widget.field?.name ?? '');
  late final _venueName =
      TextEditingController(text: widget.field?.venueName ?? '');
  late final _phone = TextEditingController(text: widget.field?.phone ?? '');
  late final _district =
      TextEditingController(text: widget.field?.district ?? '');
  late final _lat =
      TextEditingController(text: widget.field?.lat?.toString() ?? '');
  late final _lng =
      TextEditingController(text: widget.field?.lng?.toString() ?? '');
  late final _opens =
      TextEditingController(text: widget.field?.opensAt ?? '08:00');
  late final _closes =
      TextEditingController(text: widget.field?.closesAt ?? '24:00');

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name, _venueName, _phone, _district, _lat, _lng, _opens, _closes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _venueName.text.trim().isEmpty) {
      setState(() => _error = 'Saha adı ve işletme adı gerekiyor');
      return;
    }

    double? lat, lng;
    if (_lat.text.trim().isNotEmpty || _lng.text.trim().isNotEmpty) {
      lat = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
      lng = double.tryParse(_lng.text.trim().replaceAll(',', '.'));
      if (lat == null || lng == null) {
        setState(() => _error = 'Enlem/boylam sayı olmalı — boş da bırakabilirsin');
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      final row = {
        'name': _name.text.trim(),
        'venue_name': _venueName.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'district':
            _district.text.trim().isEmpty ? null : _district.text.trim(),
        'lat': lat,
        'lng': lng,
        'opens_at': _opens.text.trim(),
        'closes_at': _closes.text.trim(),
      };
      if (widget.field == null) {
        await client.from('turf_fields').insert(row);
      } else {
        await client
            .from('turf_fields')
            .update(row)
            .eq('id', widget.field!.id);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget field(String label, TextEditingController c, {String? hint}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        );

    return AlertDialog(
      title: Text(widget.field == null ? 'Saha ekle' : 'Sahayı düzenle'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field('İşletme adı', _venueName, hint: 'Yıldız Halı Saha'),
            field('Saha adı', _name, hint: 'Saha 1'),
            field('Telefon', _phone, hint: '0532 000 00 00'),
            field('İlçe', _district, hint: 'Selçuklu'),
            Row(children: [
              Expanded(
                  child: field('Enlem (isteğe bağlı)', _lat,
                      hint: '37.874641')),
              const SizedBox(width: 12),
              Expanded(
                  child: field('Boylam (isteğe bağlı)', _lng,
                      hint: '32.492500')),
            ]),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'Koordinat yalnızca "yakınımdaki sahalar" sıralaması için — '
                  'boş bırakılırsa saha listede sırasız görünür.',
                  style: TextStyle(fontSize: 12)),
            ),
            Row(children: [
              Expanded(child: field('Açılış', _opens, hint: '08:00')),
              const SizedBox(width: 12),
              Expanded(child: field('Kapanış', _closes, hint: '24:00')),
            ]),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFD64545))),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Kaydediliyor…' : 'Kaydet'),
        ),
      ],
    );
  }
}
