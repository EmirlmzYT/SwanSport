import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

class ClubTrainingSportsSheet extends ConsumerStatefulWidget {
  const ClubTrainingSportsSheet({required this.clubId, super.key});
  final String clubId;
  @override
  ConsumerState<ClubTrainingSportsSheet> createState() => _ClubTrainingSportsSheetState();
}

class _ClubTrainingSportsSheetState extends ConsumerState<ClubTrainingSportsSheet> {
  final _search = TextEditingController();
  final _selected = <String>{};
  bool _initialized = false, _busy = false;
  String? _error;
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_busy || !_initialized) return;
    if (ref.read(activeClubProvider).valueOrNull?.id != widget.clubId) {
      setState(() => _error = 'Aktif kulüp değişti. Seçiciyi yeniden aç.'); return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await ref.read(clubTrainingSportsServiceProvider).setClubTrainingSports(
        clubId: widget.clubId, sportCodes: _selected.toList()..sort());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kulüp antrenman branşları kaydedildi.')));
      setState(() => _busy = false);
      // PopScope must rebuild before the successful programmatic pop.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Kaydedilemedi: $e');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final sports = ref.watch(activeClubSportsProvider);
    final activeClub = ref.watch(activeClubProvider);
    return PopScope(canPop: !_busy, child: SafeArea(child: Padding(
      padding: EdgeInsets.fromLTRB(SwanSpace.lg, SwanSpace.lg, SwanSpace.lg,
        MediaQuery.viewInsetsOf(context).bottom + SwanSpace.lg),
      child: Column(children: [
        Text('Kulüp branşlarını yönet', style: SwanType.h3(c.ink)),
        Text('Bu seçim resmi federasyon tescili değildir. Ana branş, tescil ve takım branşları filtrelerde ayrıca görünür.',
          style: SwanType.caption(c.inkMuted)),
        TextField(controller: _search, enabled: !_busy,
          decoration: const InputDecoration(labelText: '60 branş içinde ara', prefixIcon: Icon(Icons.search_rounded)),
          onChanged: (_) => setState(() {})),
        Expanded(child: sports.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => Center(child: TextButton(onPressed: () => ref.invalidate(activeClubSportsProvider),
            child: const Text('Branşlar yüklenemedi. Yeniden dene'))),
          data: (items) {
            if (!_initialized) { _selected.addAll(items.map((s) => s.code)); _initialized = true; }
            return ListView(children: [for (final sport in SportsCatalog.all.where((s) =>
              trContains(s.name, _search.text) || trContains(s.federationName, _search.text)))
              CheckboxListTile(value: _selected.contains(sport.code),
                title: Text(sport.name, style: SwanType.body(c.ink)),
                onChanged: _busy ? null : (checked) => setState(() {
                  if (checked == true) { _selected.add(sport.code); } else { _selected.remove(sport.code); }
                }))]);
          },
        )),
        if (_error != null) Text(_error!, style: SwanType.bodySm(c.danger)),
        FilledButton(onPressed: !_busy && _initialized && activeClub.valueOrNull?.id == widget.clubId && sports.hasValue && !sports.isLoading && !sports.hasError ? _save : null,
          child: Text(_busy ? 'Kaydediliyor…' : 'Kaydet')),
      ]),
    )));
  }
}
