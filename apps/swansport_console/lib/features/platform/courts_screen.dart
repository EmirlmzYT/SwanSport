import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

/// Halka açık kort yönetimi — yalnızca platform yöneticisi.
///
/// Kortlar sisteme elle giriliyor: iki korttan başlanacak, oyuncuların kort
/// ekleyebilmesi bilerek kapsam dışı (doğrulama derdi ayrı bir iş).
class ConsoleCourtsScreen extends ConsumerWidget {
  const ConsoleCourtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(courtsProvider(null));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kortlar'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: () => _edit(context, ref, null),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Kort ekle'),
            ),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (courts) {
          if (courts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                    'Henüz kort yok. Konumuyla birlikte ilk kortu ekleyin — '
                    'koordinat olmadan oyuncular kortta olduklarını '
                    'doğrulayamaz.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: courts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final c = courts[i];
              return ListTile(
                leading: const Icon(Icons.sports_tennis_rounded),
                title: Text(c.name),
                subtitle: Text([
                  if ((c.venue ?? '').isNotEmpty) c.venue!,
                  if (c.where.isNotEmpty) c.where,
                  '${c.opensAt}–${c.closesAt}',
                  '${c.capacity} kişilik',
                  '${c.lat.toStringAsFixed(5)}, ${c.lng.toStringAsFixed(5)}',
                ].join(' · ')),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => _edit(context, ref, c),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Court? court) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CourtDialog(court: court),
    );
    if (saved == true) ref.invalidate(courtsProvider(null));
  }
}

class _CourtDialog extends ConsumerStatefulWidget {
  const _CourtDialog({this.court});
  final Court? court;

  @override
  ConsumerState<_CourtDialog> createState() => _CourtDialogState();
}

class _CourtDialogState extends ConsumerState<_CourtDialog> {
  late final _name = TextEditingController(text: widget.court?.name ?? '');
  late final _venue = TextEditingController(text: widget.court?.venue ?? '');
  late final _district =
      TextEditingController(text: widget.court?.district ?? '');
  late final _lat =
      TextEditingController(text: widget.court?.lat.toString() ?? '');
  late final _lng =
      TextEditingController(text: widget.court?.lng.toString() ?? '');
  late final _opens =
      TextEditingController(text: widget.court?.opensAt ?? '08:00');
  late final _closes =
      TextEditingController(text: widget.court?.closesAt ?? '23:00');
  late final _capacity =
      TextEditingController(text: '${widget.court?.capacity ?? 4}');

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name, _venue, _district, _lat, _lng, _opens, _closes, _capacity
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final lat = double.tryParse(_lat.text.trim().replaceAll(',', '.'));
    final lng = double.tryParse(_lng.text.trim().replaceAll(',', '.'));

    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Kort adı gerekiyor');
      return;
    }
    // Koordinat yanlışsa kimse kortta olduğunu doğrulayamaz ve kort sessizce
    // kullanılamaz hale gelir — burada durdurmak, sahada anlaşılmasından iyi.
    if (lat == null || lng == null) {
      setState(() => _error = 'Enlem ve boylam sayı olmalı');
      return;
    }
    if (lat < 35 || lat > 43 || lng < 25 || lng > 45) {
      setState(() => _error =
          'Koordinat Türkiye sınırları dışında görünüyor — enlem/boylam '
          'yer değiştirmiş olabilir');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      final row = {
        'name': _name.text.trim(),
        'venue': _venue.text.trim().isEmpty ? null : _venue.text.trim(),
        'district':
            _district.text.trim().isEmpty ? null : _district.text.trim(),
        'lat': lat,
        'lng': lng,
        'opens_at': _opens.text.trim(),
        'closes_at': _closes.text.trim(),
        'capacity': int.tryParse(_capacity.text.trim()) ?? 4,
      };
      if (widget.court == null) {
        await client.from('courts').insert(row);
      } else {
        await client.from('courts').update(row).eq('id', widget.court!.id);
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
      title: Text(widget.court == null ? 'Kort ekle' : 'Kortu düzenle'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            field('Kort adı', _name, hint: 'Millet Bahçesi Kort 1'),
            field('Tesis', _venue, hint: 'Millet Bahçesi'),
            field('İlçe', _district, hint: 'Selçuklu'),
            Row(children: [
              Expanded(child: field('Enlem', _lat, hint: '37.874641')),
              const SizedBox(width: 12),
              Expanded(child: field('Boylam', _lng, hint: '32.492500')),
            ]),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                  'Koordinatı haritadan al: Google Maps\'te korta sağ tıkla, '
                  'çıkan sayıya tıklayınca kopyalanır. Oyuncular bu noktanın '
                  '150 metre yakınında sayılır.',
                  style: TextStyle(fontSize: 12)),
            ),
            Row(children: [
              Expanded(child: field('Açılış', _opens, hint: '08:00')),
              const SizedBox(width: 12),
              Expanded(child: field('Kapanış', _closes, hint: '23:00')),
            ]),
            field('Kapasite', _capacity, hint: '4'),
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
