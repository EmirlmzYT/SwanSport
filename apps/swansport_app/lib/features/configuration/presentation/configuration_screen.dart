import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/configuration_controller.dart';
import '../domain/club_configuration.dart';
import 'configuration_module_args.dart';

class ConfigurationScreen extends ConsumerWidget {
  const ConfigurationScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(configurationControllerProvider);
    final c = ref.read(configurationControllerProvider.notifier);
    if (!state.permissions.canView) {
      return const Scaffold(
        body: Center(child: Text('Yapılandırmayı görüntüleme yetkiniz yok.')),
      );
    }
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Kulüp Yapılandırması')),
      body: LayoutBuilder(
        builder: (context, box) {
          final left = _Overview(state: state, controller: c);
          final right = _Modules(state: state, controller: c);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'SİSTEM AYARLARI',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const Text(
                'Kulüp Yapılandırma Merkezi',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              if (box.maxWidth >= 900)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: left),
                    const SizedBox(width: 24),
                    Expanded(flex: 7, child: right),
                  ],
                )
              else ...[left, const SizedBox(height: 16), right],
            ],
          );
        },
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.state, required this.controller});
  final ConfigurationState state;
  final ConfigurationController controller;
  @override
  Widget build(BuildContext context) {
    final h = controller.repository.health;
    return Column(
      children: [
        Container(
          key: const Key('configuration-health'),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF063337), Color(0xFF008C95)],
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'EXECUTIVE CONFIGURATION HEALTH',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '%${h.score} Sağlık Skoru',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${h.activeSeason} • ${h.branches} Branş • ${h.teams} Takım',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'Marka: ${h.brandingReady ? "Hazır" : "Eksik"} • Bildirim: ${h.notificationsHealthy ? "Sağlıklı" : "Sorunlu"} • Yasal: ${h.legalCompliant ? "Uyumlu" : "Eksik"}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        Card(
          child: ExpansionTile(
            key: const Key('configuration-profiles'),
            title: Text('Yapılandırma Profilleri (${state.profiles.length})'),
            trailing: state.permissions.canEdit
                ? IconButton(
                    onPressed: () => controller.createProfile('Yeni Profil'),
                    icon: const Icon(Icons.add),
                  )
                : null,
            children: state.profiles
                .map(
                  (p) => ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.archived ? 'Arşivlendi' : 'Etkin'),
                    onTap: () => controller.preview(p),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'duplicate') controller.duplicate(p);
                        if (v == 'archive') controller.archive(p);
                        if (v == 'apply') controller.apply(p);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'duplicate',
                          child: Text('Çoğalt'),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text('Arşivle'),
                        ),
                        PopupMenuItem(
                          value: 'apply',
                          child: Text('Uygula (Onay)'),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        if (state.previewProfile case final p?)
          Card(
            child: ListTile(
              title: Text('${p.name} Fark Önizlemesi'),
              subtitle: Text(
                '${p.values.length} ayar geçerli yapılandırmanın üzerine yazılacak.',
              ),
            ),
          ),
        Card(
          child: ExpansionTile(
            key: const Key('configuration-validation'),
            title: Text('Doğrulama Merkezi • ${h.score}'),
            children: state.validations
                .map(
                  (v) => ListTile(
                    leading: Icon(
                      v.severity == ValidationSeverity.warning
                          ? Icons.warning_amber
                          : Icons.info_outline,
                    ),
                    title: Text(v.message),
                    subtitle: Text(v.severity.name),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/configuration-module',
                      arguments: ConfigurationModuleArgs(v.settingId),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Card(
          child: ExpansionTile(
            key: const Key('configuration-history'),
            title: Text('Yapılandırma Geçmişi (${state.history.length})'),
            children: state.history.isEmpty
                ? const [ListTile(title: Text('Henüz değişiklik yok.'))]
                : state.history
                    .map(
                      (e) => ListTile(
                        title: Text(e.settingId),
                        subtitle: Text(
                          '${e.previousValue} → ${e.newValue}\n${e.changedBy} • ${e.reason ?? ""}',
                        ),
                      ),
                    )
                    .toList(),
          ),
        ),
      ],
    );
  }
}

class _Modules extends StatelessWidget {
  const _Modules({required this.state, required this.controller});
  final ConfigurationState state;
  final ConfigurationController controller;
  @override
  Widget build(BuildContext context) => Column(
        children: [
          TextField(
            key: const Key('configuration-search'),
            onChanged: controller.search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Ayar, modül veya kategori ara',
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Tümü'),
                  selected: state.category == null,
                  onSelected: (_) => controller.filter(null),
                ),
                ...ConfigurationCategory.values.map(
                  (v) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(v.name),
                      selected: state.category == v,
                      onSelected: (_) => controller.filter(v),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Eşleşen ayar bulunamadı.',
                key: Key('configuration-no-results'),
              ),
            ),
          ...state.filtered.map(
            (s) => Card(
              child: Semantics(
                button: true,
                label: '${s.module}: ${s.label}',
                child: ListTile(
                  key: Key('configuration-setting-${s.id}'),
                  title: Text(s.module),
                  subtitle: Text('${s.label}\n${s.value}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pushNamed(
                    context,
                    '/configuration-module',
                    arguments: ConfigurationModuleArgs(s.id),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

class ConfigurationModuleScreen extends ConsumerWidget {
  const ConfigurationModuleScreen({required this.args, super.key});
  final ConfigurationModuleArgs? args;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(configurationControllerProvider);
    if (args == null) {
      return const Scaffold(
        body: Center(child: Text('Geçersiz yapılandırma bağlantısı.')),
      );
    }
    final matches = state.settings.where((s) => s.id == args!.settingId);
    if (matches.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Yapılandırma bulunamadı.')),
      );
    }
    final setting = matches.single;
    final input = TextEditingController(text: setting.value);
    return Scaffold(
      appBar: AppBar(title: Text(setting.module)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            setting.label,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          TextField(
            key: const Key('configuration-value'),
            controller: input,
            readOnly: !state.permissions.canEdit,
          ),
          const SizedBox(height: 12),
          if (state.permissions.canEdit)
            FilledButton(
              onPressed: () {
                ref
                    .read(configurationControllerProvider.notifier)
                    .update(setting.id, input.text);
                Navigator.pop(context);
              },
              child: const Text('Kaydet'),
            ),
        ],
      ),
    );
  }
}
