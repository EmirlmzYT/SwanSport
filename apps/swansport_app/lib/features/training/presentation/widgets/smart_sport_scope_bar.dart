import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/swan_tabs.dart';

class SmartSportScopeBar extends ConsumerWidget {
  const SmartSportScopeBar({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final selected = ref.watch(effectiveSportContextProvider);
    void choose(String? code) => ref.read(selectedSportContextProvider.notifier).state = code ?? '*';
    return ref.watch(sportContextOptionsProvider).when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Column(children: [
        Text('Branş bağlamı yüklenemedi.', style: SwanType.bodySm(c.danger)),
        TextButton(onPressed: () { ref.invalidate(activeClubSportsProvider); ref.invalidate(myActiveSportsProvider); },
          child: const Text('Yeniden dene')),
      ]),
      data: (sports) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (sports.length == 1 && (selected == null || selected == sports.single.code))
          Chip(label: Text(sports.single.name, style: SwanType.bodySm(c.ink)))
        else if (sports.isNotEmpty)
          SwanPillTabs(labels: ['Tümü', ...sports.map((s) => s.name)],
            selected: selected == null ? 0 : sports.any((s) => s.code == selected)
              ? sports.indexWhere((s) => s.code == selected) + 1 : -1,
            onSelect: (index) => choose(index == 0 ? null : sports[index - 1].code)),
        const SizedBox(height: SwanSpace.xs),
        if (sports.isEmpty || sports.length >= 5) TextButton.icon(icon: const Icon(Icons.search_rounded),
          label: Text(SportsCatalog.findByCode(selected)?.name ?? 'Tüm Branşlar (60)'),
          onPressed: () async {
            final sport = await showSearch<SportItem?>(context: context, delegate: _SportSearch());
            if (sport != null && context.mounted) choose(sport.code);
          }),
      ]),
    );
  }
}

class _SportSearch extends SearchDelegate<SportItem?> {
  _SportSearch() : super(searchFieldLabel: '60 branş içinde ara');
  @override
  List<Widget> buildActions(BuildContext context) => [IconButton(
    tooltip: 'Aramayı temizle', onPressed: () => query = '', icon: const Icon(Icons.clear_rounded))];
  @override
  Widget buildLeading(BuildContext context) => IconButton(tooltip: 'Geri dön',
    onPressed: () => close(context, null), icon: const Icon(Icons.arrow_back_rounded));
  @override
  Widget buildResults(BuildContext context) => _list(context);
  @override
  Widget buildSuggestions(BuildContext context) => _list(context);
  Widget _list(BuildContext context) => ListView(children: [
    for (final sport in SportsCatalog.search(query)) ListTile(
      title: Text(sport.name, style: SwanType.body(context.swan.ink)),
      subtitle: Text(sport.federationName, style: SwanType.caption(context.swan.inkMuted)),
      onTap: () => close(context, sport)),
  ]);
}
