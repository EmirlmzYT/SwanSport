import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';
import '../widgets/swan_module_app_bar.dart';
import '../widgets/swan_scaffold.dart';
import '../widgets/swan_surface.dart';
import 'quick_access_catalog.dart';
import 'quick_access_preferences.dart';

class QuickAccessScreen extends ConsumerWidget {
  const QuickAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(quickAccessAccountProvider);
    final prefs = account == null
        ? null
        : ref.watch(quickAccessPreferencesProvider(account));
    return SwanScaffold(
      backgroundColor: context.swan.bg,
      appBar: swanModuleAppBar(context, title: 'Hızlı erişim'),
      body: account == null
          ? const Center(child: Text('Hesap bilgilerin bekleniyor.'))
          : prefs!.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: TextButton(
                  onPressed: () =>
                      ref.invalidate(quickAccessPreferencesProvider(account)),
                  child: const Text('Tercihleri yeniden yükle'),
                ),
              ),
              data: (value) => _QuickAccessEditor(
                key: ValueKey(account),
                account: account,
                initial: value,
              ),
            ),
    );
  }
}

class _QuickAccessEditor extends ConsumerStatefulWidget {
  const _QuickAccessEditor({
    required this.account,
    required this.initial,
    super.key,
  });
  final String account;
  final QuickAccessPreferences initial;

  @override
  ConsumerState<_QuickAccessEditor> createState() => _QuickAccessEditorState();
}

class _QuickAccessEditorState extends ConsumerState<_QuickAccessEditor> {
  late bool _hidden = widget.initial.hidden;
  List<String>? _ids;
  bool _initialized = false;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(quickAccessPreferencesProvider(widget.account).notifier)
          .save(QuickAccessPreferences(hidden: _hidden, ids: _ids));
      if (mounted && ref.read(quickAccessAccountProvider) == widget.account) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error =
              'Kaydedilemedi. Tercihlerin korunuyor, yeniden deneyebilirsin.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final access = ref.watch(swanAccessProvider);
    final available = ref.watch(availableHomeShortcutsProvider);
    if (!_initialized) {
      _ids = widget.initial.ids == null ? null : List.of(widget.initial.ids!);
      _initialized = true;
    }
    final selected = selectedHomeShortcuts(
      QuickAccessPreferences(ids: _ids),
      access,
      available,
    );
    final selectedIds = selected.map((s) => s.id).toSet();
    final remaining =
        available.where((s) => !selectedIds.contains(s.id)).toList();
    void setSelection(List<String> ids) => setState(() => _ids = ids);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(SwanSpace.lg),
                  children: [
                    Text('Ana sayfan, senin düzenin.',
                        style: SwanType.h2(c.ink)),
                    const SizedBox(height: SwanSpace.sm),
                    Text(
                      'Sık kullandığın en fazla 4 kısayolu seç. Sıralamayı sürükleyerek veya oklarla değiştirebilirsin.',
                      style: SwanType.body(c.inkMuted),
                    ),
                    const SizedBox(height: SwanSpace.xl),
                    SwanSurface(
                      child: SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Ana sayfada göster'),
                        subtitle:
                            const Text('Kapattığında kısayolların saklanır.'),
                        value: !_hidden,
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _hidden = !value),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Seçtiklerin · ${selected.length}/4',
                            style: SwanType.h3(c.ink),
                          ),
                        ),
                        TextButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() {
                                    _ids = null;
                                    _hidden = false;
                                  }),
                          child: const Text('Varsayılana dön'),
                        ),
                      ],
                    ),
                    if (selected.isEmpty)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: SwanSpace.lg),
                        child: Text(
                          'Aşağıdan kısayol ekleyebilirsin.',
                          style: SwanType.body(c.inkMuted),
                        ),
                      ),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      itemCount: selected.length,
                      onReorderItem: (oldIndex, newIndex) {
                        if (_saving) return;
                        final ids = selected.map((s) => s.id).toList();
                        ids.insert(newIndex, ids.removeAt(oldIndex));
                        setSelection(ids);
                      },
                      itemBuilder: (context, index) {
                        final item = selected[index];
                        return Material(
                          key: ValueKey(item.id),
                          color: c.surface,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: SwanSpace.sm),
                            leading: ReorderableDragStartListener(
                              index: index,
                              enabled: !_saving,
                              child: Tooltip(
                                message: 'Sürükleyerek sırala',
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: SwanSpace.md,
                                  ),
                                  child: Icon(
                                    Icons.drag_indicator_rounded,
                                    color: c.inkMuted,
                                  ),
                                ),
                              ),
                            ),
                            title:
                                Text(item.label, style: SwanType.body(c.ink)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: '${item.label} yukarı taşı',
                                  icon: const Icon(Icons.arrow_upward_rounded),
                                  onPressed: index == 0 || _saving
                                      ? null
                                      : () {
                                          final ids = selected
                                              .map((s) => s.id)
                                              .toList();
                                          ids.insert(
                                              index - 1, ids.removeAt(index));
                                          setSelection(ids);
                                        },
                                ),
                                IconButton(
                                  tooltip: '${item.label} kaldır',
                                  icon: const Icon(
                                      Icons.remove_circle_outline_rounded),
                                  onPressed: _saving
                                      ? null
                                      : () => setSelection(
                                            selected
                                                .where((s) => s.id != item.id)
                                                .map((s) => s.id)
                                                .toList(),
                                          ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: SwanSpace.xl),
                    Text('Ekleyebileceklerin', style: SwanType.h3(c.ink)),
                    const SizedBox(height: SwanSpace.sm),
                    Text(
                      'Yalnızca hesabına açık alanlar burada görünür.',
                      style: SwanType.caption(c.inkMuted),
                    ),
                    for (final item in remaining)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(item.icon, color: c.inkMuted),
                        title: Text(item.label, style: SwanType.body(c.ink)),
                        trailing: const Icon(Icons.add_rounded),
                        enabled: selected.length < 4 && !_saving,
                        onTap: () => setSelection(
                            [...selected.map((s) => s.id), item.id]),
                      ),
                    const SizedBox(height: SwanSpace.xl),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(
                        'Hızlı erişim nasıl çalışır?',
                        style: SwanType.body(c.ink),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: SwanSpace.lg),
                          child: Text(
                            'İlk düzen görevlerine göre hazırlanır. Seçimlerin bu cihazda, hesabına özel saklanır. Yetkin veya bir özelliğin kullanılabilirliği değişirse ilgili kısayol gizlenir. Gizlediğin alanı Ayarlar → Ana sayfa → Hızlı erişim üzerinden yeniden açabilirsin. Varsayılana dön, görevlerine uygun düzeni yeniden seçer.',
                            style: SwanType.body(c.inkMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(SwanSpace.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Text(_error!, style: SwanType.caption(c.danger)),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Kaydediliyor…' : 'Kaydet'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
