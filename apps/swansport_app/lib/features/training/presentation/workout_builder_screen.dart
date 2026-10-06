import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';

/// Creates a versioned protocol through the existing authorized RPC.
class WorkoutProtocolBuilderScreen extends ConsumerStatefulWidget {
  const WorkoutProtocolBuilderScreen({super.key, this.initialTitle = ''});
  final String initialTitle;

  @override
  ConsumerState<WorkoutProtocolBuilderScreen> createState() => _BuilderState();
}

class _BuilderState extends ConsumerState<WorkoutProtocolBuilderScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _description = TextEditingController();
  final _numbers = <String, TextEditingController>{
    'set_count': TextEditingController(text: '6'),
    'units_per_set': TextEditingController(text: '6'),
    'prep_seconds': TextEditingController(text: '10'),
    'shoot_seconds': TextEditingController(text: '120'),
    'collect_seconds': TextEditingController(text: '60'),
    'rest_seconds': TextEditingController(text: '0'),
    'max_unit_score': TextEditingController(text: '10'),
  };
  String? _sport;
  TrainingMode _mode = TrainingMode.technique;
  ScoreEntryMode _entry = ScoreEntryMode.flexible;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    for (final c in _numbers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final club = ref.watch(activeClubProvider);
    final access = ref.watch(swanAccessProvider);
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(title: const Text('Antrenman şablonu oluştur')),
      body: club.when(
        loading: premiumLoading,
        error: (e, _) => premiumError(context, '$e'),
        data: (club) {
          if (club == null || !access.isClubStaff) {
            return premiumEmpty(context,
                icon: Icons.lock_outline,
                title: 'Kulüp personeli erişimi gerekli',
                subtitle:
                    'Şablon oluşturmak için bir kulüpte yetkili olmalısın.');
          }
          return Center(
              child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.all(SwanSpace.lg),
                  children: [
                    Text(club.name, style: SwanType.h3(c.ink)),
                    const SizedBox(height: SwanSpace.md),
                    TextFormField(
                        controller: _name,
                        enabled: !_saving,
                        decoration:
                            const InputDecoration(labelText: 'Şablon adı'),
                        validator: (v) => v == null || v.trim().length < 3
                            ? 'En az 3 karakter yaz.'
                            : null),
                    const SizedBox(height: SwanSpace.md),
                    TextFormField(
                        controller: _description,
                        enabled: !_saving,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Açıklama (isteğe bağlı)')),
                    const SizedBox(height: SwanSpace.md),
                    ref.watch(sportsProvider).when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, _) => Text('Branşlar yüklenemedi: $e',
                              style: SwanType.bodySm(c.danger)),
                          data: (sports) => DropdownButtonFormField<String>(
                            initialValue: _sport,
                            isExpanded: true,
                            decoration:
                                const InputDecoration(labelText: 'Branş'),
                            items: [
                              for (final sport in sports)
                                DropdownMenuItem(
                                    value: sport.code, child: Text(sport.name))
                            ],
                            onChanged: _saving
                                ? null
                                : (v) => setState(() => _sport = v),
                            validator: (v) =>
                                v == null ? 'Bir branş seç.' : null,
                          ),
                        ),
                    const SizedBox(height: SwanSpace.md),
                    DropdownButtonFormField<TrainingMode>(
                        initialValue: _mode,
                        decoration:
                            const InputDecoration(labelText: 'Antrenman türü'),
                        items: [
                          for (final mode in TrainingMode.values)
                            DropdownMenuItem(
                                value: mode, child: Text(mode.label))
                        ],
                        onChanged:
                            _saving ? null : (v) => setState(() => _mode = v!)),
                    const SizedBox(height: SwanSpace.md),
                    DropdownButtonFormField<ScoreEntryMode>(
                        initialValue: _entry,
                        decoration:
                            const InputDecoration(labelText: 'Skor girişi'),
                        items: const [
                          DropdownMenuItem(
                              value: ScoreEntryMode.simple,
                              child: Text('Set toplamı')),
                          DropdownMenuItem(
                              value: ScoreEntryMode.detailed,
                              child: Text('Her tekrar ayrı')),
                          DropdownMenuItem(
                              value: ScoreEntryMode.flexible,
                              child: Text('Sporcu seçer')),
                        ],
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _entry = v!)),
                    for (final field in const [
                      ('set_count', 'Set sayısı', 1, 50),
                      ('units_per_set', 'Set başına tekrar', 1, 100),
                      ('prep_seconds', 'Hazırlık (saniye)', 0, 3600),
                      ('shoot_seconds', 'Çalışma (saniye)', 5, 3600),
                      ('collect_seconds', 'Toplama (saniye)', 0, 3600),
                      ('rest_seconds', 'Dinlenme (saniye)', 0, 3600),
                      (
                        'max_unit_score',
                        'Tekrar başına en yüksek puan',
                        1,
                        1000
                      ),
                    ]) ...[
                      const SizedBox(height: SwanSpace.md),
                      TextFormField(
                          controller: _numbers[field.$1],
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(labelText: field.$2),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            return n == null || n < field.$3 || n > field.$4
                                ? '${field.$3}–${field.$4} arasında tam sayı yaz.'
                                : null;
                          }),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: SwanSpace.md),
                      Text(_error!, style: SwanType.bodySm(c.danger)),
                    ],
                    const SizedBox(height: SwanSpace.lg),
                    FilledButton(
                        onPressed: _saving ? null : _save,
                        child:
                            Text(_saving ? 'Kaydediliyor…' : 'Şablonu kaydet')),
                  ],
                )),
          ));
        },
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate() || _sport == null) return;
    final club = ref.read(activeClubProvider).valueOrNull;
    if (club == null || !ref.read(swanAccessProvider).isClubStaff) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      int n(String key) => int.parse(_numbers[key]!.text.trim());
      await ref.read(trainingSessionServiceProvider).createProtocol(
            clubId: club.id,
            sportCode: _sport!,
            name: _name.text.trim(),
            description: _description.text.trim(),
            config: TrainingProtocolConfig(
              setCount: n('set_count'),
              unitsPerSet: n('units_per_set'),
              prepSeconds: n('prep_seconds'),
              shootSeconds: n('shoot_seconds'),
              collectSeconds: n('collect_seconds'),
              restSeconds: n('rest_seconds'),
              maxUnitScore: n('max_unit_score'),
              entryMode: _entry,
              mode: _mode,
            ),
          );
      ref.invalidate(trainingProtocolsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Şablon kaydedildi.')));
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _error = 'Şablon kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
