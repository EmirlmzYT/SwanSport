import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/facility_controller.dart';
import '../domain/facility_management.dart';
import 'facility_route_args.dart';

class FacilityManagementScreen extends ConsumerWidget {
  const FacilityManagementScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(facilityControllerProvider),
        c = ref.read(facilityControllerProvider.notifier);
    if (!state.permissions.canView) {
      return const Scaffold(
        body: Center(child: Text('Tesis merkezini görüntüleme yetkiniz yok.')),
      );
    }
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final zones = state.facilities.expand((f) => f.zones).length,
        occupied = state.facilities
            .expand((f) => f.zones)
            .where((z) => z.status == ZoneStatus.occupied)
            .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Tesis Yönetim Merkezi')),
      body: LayoutBuilder(
        builder: (context, box) {
          final overview = Column(
            children: [
              Container(
                key: const Key('facility-command-center'),
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
                      'FACILITY COMMAND CENTER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${state.facilities.length} Tesis • $zones Alan',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${state.facilities.where((f) => f.status == FacilityStatus.active).length} aktif • $occupied dolu • ${state.facilities.expand((f) => f.reservations).length} rezervasyon',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    Text(
                      'Operasyon Sağlığı: %${state.facilities.map((f) => f.health).reduce((a, b) => a + b) ~/ state.facilities.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              Card(
                child: ExpansionTile(
                  title: const Text('Acil Uyarılar & Öncelikli İşlemler'),
                  children: [
                    for (final f in state.facilities) ...[
                      for (final w in f.workOrders
                          .where((w) => w.status == WorkOrderStatus.overdue))
                        ListTile(
                          leading: const Icon(Icons.error_outline),
                          title: Text(w.title),
                          subtitle: Text('${f.name} • Gecikmiş bakım'),
                        ),
                      for (final d in f.documents.where(
                        (d) => d.status != FacilityDocumentStatus.valid,
                      ))
                        ListTile(
                          leading: const Icon(Icons.warning_amber),
                          title: Text(d.title),
                          subtitle: Text('${f.name} • ${d.status.name}'),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          );
          final directory = Column(
            children: [
              TextField(
                key: const Key('facility-search'),
                onChanged: c.search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Tesis, alan, tür, şube, kampüs veya yönetici ara',
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Tümü'),
                      selected: state.filter.status == null,
                      onSelected: (_) => c.filterStatus(null),
                    ),
                    ...FacilityStatus.values.map(
                      (s) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: ChoiceChip(
                          label: Text(s.name),
                          selected: state.filter.status == s,
                          onSelected: (_) => c.filterStatus(s),
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
                    'Eşleşen tesis bulunamadı.',
                    key: Key('facility-empty'),
                  ),
                ),
              ...state.filtered.map(
                (f) => Card(
                  child: ListTile(
                    key: Key('facility-${f.id.value}'),
                    leading: const Icon(Icons.stadium),
                    title: Text(f.name),
                    subtitle: Text(
                      '${f.type} • ${f.campus}\n${f.status.name} • Kapasite ${f.capacity} • Sağlık %${f.health}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                      context,
                      '/facility-detail',
                      arguments: FacilityDetailArgs(f.id),
                    ),
                  ),
                ),
              ),
            ],
          );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'TESİS OPERASYONLARI',
                style:
                    TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.3),
              ),
              const Text(
                'Tesis Yönetim Merkezi',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              if (box.maxWidth >= 840)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: overview),
                    const SizedBox(width: 24),
                    Expanded(flex: 7, child: directory),
                  ],
                )
              else ...[overview, const SizedBox(height: 16), directory],
            ],
          );
        },
      ),
    );
  }
}

class FacilityDetailScreen extends ConsumerWidget {
  const FacilityDetailScreen({required this.args, super.key});
  final FacilityDetailArgs? args;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(facilityControllerProvider),
        c = ref.read(facilityControllerProvider.notifier);
    if (args == null) {
      return const Scaffold(
        body: Center(child: Text('Geçersiz tesis bağlantısı.')),
      );
    }
    final found =
        state.facilities.where((f) => f.id.value == args!.facilityId.value);
    if (state.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (found.isEmpty) {
      return const Scaffold(body: Center(child: Text('Tesis bulunamadı.')));
    }
    final f = found.single;
    return Scaffold(
      appBar: AppBar(title: Text(f.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            f.name,
            key: const Key('facility-detail-name'),
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
          Text('${f.type} • ${f.status.name} • Sağlık %${f.health}'),
          Text(
            '${f.address}\nYönetici: ${f.manager} • ${f.contact}\nKapasite: ${f.capacity}',
          ),
          if (state.permissions.canEdit)
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => c.lifecycle(f, FacilityStatus.active),
                  child: const Text('Etkinleştir'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      c.lifecycle(f, FacilityStatus.temporarilyClosed),
                  child: const Text('Geçici Kapat'),
                ),
                if (state.permissions.canArchive)
                  OutlinedButton(
                    onPressed: () => c.lifecycle(f, FacilityStatus.archived),
                    child: const Text('Arşivle'),
                  ),
              ],
            ),
          _section(
            'Alanlar',
            f.zones.map(
              (z) => ListTile(
                title: Text(z.name),
                subtitle: Text(
                  '${z.type} • ${z.status.name} • Kapasite ${z.capacity} • ${z.openHour}:00-${z.closeHour}:00',
                ),
              ),
            ),
          ),
          _section(
            'Rezervasyonlar',
            f.reservations.map(
              (r) => ListTile(
                title: Text(r.title),
                subtitle: Text('${r.start} → ${r.end} • ${r.status.name}'),
              ),
            ),
          ),
          if (state.conflict case final conflict?)
            Card(
              color: Colors.orange.withValues(alpha: .15),
              child: ListTile(
                key: const Key('reservation-conflict'),
                leading: const Icon(Icons.block),
                title: const Text('Rezervasyon engellendi'),
                subtitle: Text(conflict.message),
              ),
            ),
          _section(
            'Bakım Merkezi',
            f.workOrders.map(
              (w) => ListTile(
                title: Text(w.title),
                subtitle: Text(
                  '${w.priority} • ${w.status.name} • ${w.assignee}',
                ),
              ),
            ),
          ),
          _section(
            'Ekipman Sağlığı',
            f.equipment.map(
              (e) => ListTile(
                title: Text(e.name),
                subtitle: Text(
                  '${e.category} • ${e.condition.name} • Sağlık %${e.health}',
                ),
              ),
            ),
          ),
          _section(
            'Belgeler & Uyumluluk',
            f.documents.map(
              (d) => ListTile(
                title: Text(d.title),
                subtitle: Text('${d.type} • ${d.status.name} • ${d.owner}'),
              ),
            ),
          ),
          const Text(
            'Sağlık Skoru Açıklaması',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const Text(
            'Skor; kullanılabilirlik, gecikmiş bakım, ekipman durumu, belge uyumu ve güvenli alan durumundan hesaplanır.',
          ),
        ],
      ),
    );
  }

  Widget _section(String title, Iterable<Widget> children) => Card(
        child: ExpansionTile(
          title: Text(title),
          children: children.isEmpty
              ? const [ListTile(title: Text('Kayıt bulunmuyor.'))]
              : children.toList(),
        ),
      );
}
