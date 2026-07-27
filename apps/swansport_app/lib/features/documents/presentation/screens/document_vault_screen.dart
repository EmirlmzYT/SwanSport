import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../application/document_vault_controller.dart';
import '../../domain/models/document_vault.dart';
import '../routing/document_detail_route_args.dart';

class DocumentVaultScreen extends ConsumerStatefulWidget {
  const DocumentVaultScreen({super.key});
  @override
  ConsumerState<DocumentVaultScreen> createState() =>
      _DocumentVaultScreenState();
}

class _DocumentVaultScreenState extends ConsumerState<DocumentVaultScreen> {
  final _search = TextEditingController();
  int _navIndex = 2;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(documentVaultControllerProvider);
    final controller = ref.read(documentVaultControllerProvider.notifier);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? SwanColors.darkBackground : SwanColors.background,
      appBar: SwanAppBar(
        clubName: 'Kadıköy SK',
        roleName: 'Antrenör',
        actions: [
          if (state.permissions.canManageRequests)
            IconButton(
              key: const Key('document-create-request'),
              tooltip: 'Evrak talebi oluştur',
              onPressed: () => _showRequestDialog(controller),
              icon: const Icon(Icons.note_add_rounded),
            ),
        ],
      ),
      body: _body(state, controller),
      bottomNavigationBar: SwanFloatingNavigationBar(
        selectedIndex: _navIndex,
        destinations: const [
          SwanNavigationDestination(
            icon: Icons.grid_view_rounded,
            label: 'Ana Sayfa',
          ),
          SwanNavigationDestination(
            icon: Icons.calendar_month_rounded,
            label: 'Takvim',
          ),
          SwanNavigationDestination(
            icon: Icons.folder_rounded,
            label: 'Belgeler',
          ),
          SwanNavigationDestination(
            icon: Icons.campaign_rounded,
            label: 'Duyurular',
          ),
        ],
        onDestinationSelected: (index) {
          setState(() => _navIndex = index);
          if (index == 0) Navigator.pushNamed(context, '/dashboard');
          if (index == 1) Navigator.pushNamed(context, '/calendar');
          if (index == 3) Navigator.pushNamed(context, '/announcements');
        },
      ),
    );
  }

  Widget _body(DocumentVaultState state, DocumentVaultController controller) {
    if (state.status == DocumentVaultStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == DocumentVaultStatus.permissionDenied) {
      return const Center(
        child: Text('Belge kasasını görüntüleme yetkiniz yok.'),
      );
    }
    if (state.status == DocumentVaultStatus.failure) {
      return Center(child: Text(state.error ?? 'Belgeler yüklenemedi.'));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final overview = _overview(state);
        final content = _documents(state, controller);
        return ListView(
          key: const Key('document-vault-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
          children: [
            const Text(
              'DİJİTAL EVRAK KASASI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            const Text(
              'Belgeler & Dosya Merkezi',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            if (state.status == DocumentVaultStatus.offline)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Çevrimdışı önbellek gösteriliyor.'),
                ),
              ),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: overview),
                  const SizedBox(width: 24),
                  Expanded(flex: 7, child: content),
                ],
              )
            else ...[
              overview,
              const SizedBox(height: 20),
              content,
            ],
          ],
        );
      },
    );
  }

  Widget _overview(DocumentVaultState state) {
    final overview = state.overview!;
    final storage = state.storage!;
    return Column(
      children: [
        Container(
          key: const Key('document-overview'),
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
                'VAULT OVERVIEW',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${overview.total} Toplam Belge',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _metric('${overview.active}', 'Aktif'),
                  _metric('${overview.expiringSoon}', 'Süresi Doluyor'),
                  _metric('${overview.pendingApproval}', 'Onay Bekliyor'),
                  _metric('${overview.archived}', 'Arşiv'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          key: const Key('document-storage-overview'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Depolama',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  '${storage.usedGb} GB / ${storage.totalGb.toStringAsFixed(0)} GB • %${storage.usagePercentage}',
                ),
                LinearProgressIndicator(
                  value: storage.usedGb / storage.totalGb,
                ),
                Text('Durum: ${storage.health}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ExpansionTile(
            key: const Key('document-requests'),
            title: Text('Evrak Talepleri (${state.requests.length})'),
            children: state.requests
                .map(
                  (request) => ListTile(
                    title: Text(request.title),
                    subtitle:
                        Text('${request.athlete} • ${request.status.name}'),
                    trailing: state.permissions.canManageRequests
                        ? PopupMenuButton<DocumentRequestStatus>(
                            onSelected: (status) => ref
                                .read(
                                  documentVaultControllerProvider.notifier,
                                )
                                .setRequestStatus(request, status),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: DocumentRequestStatus.approved,
                                child: Text('Onayla'),
                              ),
                              PopupMenuItem(
                                value: DocumentRequestStatus.rejected,
                                child: Text('Reddet'),
                              ),
                              PopupMenuItem(
                                value: DocumentRequestStatus.pending,
                                child: Text('Hatırlat'),
                              ),
                              PopupMenuItem(
                                value: DocumentRequestStatus.cancelled,
                                child: Text('İptal Et'),
                              ),
                            ],
                          )
                        : null,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _documents(
    DocumentVaultState state,
    DocumentVaultController controller,
  ) {
    final documents = state.filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          key: const Key('document-search-field'),
          controller: _search,
          onChanged: controller.search,
          decoration: InputDecoration(
            hintText: 'Dosya, sporcu, takım, sezon, yükleyen veya etiket ara',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: state.filter.query.isEmpty
                ? null
                : IconButton(
                    key: const Key('document-search-reset'),
                    onPressed: () {
                      _search.clear();
                      controller.resetSearch();
                    },
                    icon: const Icon(Icons.close),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Tümü'),
                selected: state.filter.category == null,
                onSelected: (_) => controller.selectCategory(null),
              ),
              ...DocumentCategory.values.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(category.name),
                    selected: state.filter.category == category,
                    onSelected: (_) => controller.selectCategory(category),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Favoriler'),
                selected: state.filter.favoritesOnly,
                onSelected: (_) => controller.toggleFavorites(),
              ),
              const SizedBox(width: 6),
              FilterChip(
                label: const Text('Sabitlenenler'),
                selected: state.filter.pinnedOnly,
                onSelected: (_) => controller.togglePinned(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (state.status == DocumentVaultStatus.empty)
          const Center(
            child: Text('Belge kasası boş.', key: Key('document-empty')),
          )
        else if (documents.isEmpty)
          const Center(
            child: Text(
              'Aramanızla eşleşen belge bulunamadı.',
              key: Key('document-no-results'),
            ),
          )
        else
          ...documents.map(
            (document) => Card(
              key: Key('document-card-${document.id.value}'),
              child: ListTile(
                leading: Icon(
                  document.isPinned ? Icons.push_pin : Icons.description,
                ),
                title: Text(document.filename),
                subtitle: Text(
                  '${document.athlete.isEmpty ? document.team : document.athlete} • ${document.uploader}\n${document.tags.map((tag) => "#$tag").join(" ")}',
                ),
                isThreeLine: true,
                trailing: Chip(label: Text(document.status.name)),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/document-detail',
                  arguments: DocumentDetailRouteArgs(documentId: document.id),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _metric(String value, String label) => SizedBox(
        width: 90,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: .75),
                fontSize: 11,
              ),
            ),
          ],
        ),
      );

  Future<void> _showRequestDialog(DocumentVaultController controller) async {
    final title = TextEditingController();
    final athlete = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Evrak Talebi Oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('request-title'),
              controller: title,
              decoration: const InputDecoration(labelText: 'Belge'),
            ),
            TextField(
              key: const Key('request-athlete'),
              controller: athlete,
              decoration: const InputDecoration(labelText: 'Sporcu'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    if (accepted == true &&
        title.text.trim().isNotEmpty &&
        athlete.text.trim().isNotEmpty) {
      await controller.createRequest(
        title.text.trim(),
        athlete.text.trim(),
        DateTime(2026, 8, 1),
      );
    }
    title.dispose();
    athlete.dispose();
  }
}
