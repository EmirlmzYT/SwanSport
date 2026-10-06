import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_core/swansport_core.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/widgets/swan_page_header.dart';

class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});
  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _pinnedOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final canCompose =
        club != null && ref.watch(swanAccessProvider).isClubStaff;
    final announcements = ref.watch(announcementsProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(announcementsProvider);
            await ref.read(announcementsProvider.future);
          },
          child: ListView(
              padding: const EdgeInsets.fromLTRB(
                  SwanSpace.lg, SwanSpace.md, SwanSpace.lg, 120),
              children: [
                SwanPageHeader(
                    title: 'Duyurular',
                    subtitle: club?.name ?? 'Kulüp duyuruları'),
                const SizedBox(height: SwanSpace.md),
                TextField(
                    key: const Key('communication-search-field'),
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v.trim()),
                    decoration: InputDecoration(
                        hintText: 'Duyuru ara…',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                key: const Key('communication-search-clear'),
                                tooltip: 'Aramayı temizle',
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() {
                                      _search.clear();
                                      _query = '';
                                    })))),
                const SizedBox(height: SwanSpace.md),
                Wrap(spacing: SwanSpace.sm, children: [
                  ChoiceChip(
                      label: const Text('Tümü'),
                      selected: !_pinnedOnly,
                      onSelected: (_) => setState(() => _pinnedOnly = false)),
                  ChoiceChip(
                      label: const Text('Sabitlenenler'),
                      selected: _pinnedOnly,
                      onSelected: (_) => setState(() => _pinnedOnly = true)),
                ]),
                if (canCompose)
                  TextButton.icon(
                      onPressed: () => _compose(context, club),
                      icon: const Icon(Icons.add),
                      label: const Text('Yeni duyuru')),
                const SizedBox(height: SwanSpace.md),
                announcements.when(
                  loading: premiumLoading,
                  error: (e, _) => premiumError(context, '$e'),
                  data: (items) {
                    final filtered = items
                        .where((a) =>
                            (!_pinnedOnly || a.pinned) &&
                            (trContains(a.title, _query) ||
                                trContains(a.body, _query)))
                        .toList();
                    if (filtered.isEmpty)
                      return Text(
                          _query.isEmpty
                              ? 'Henüz duyuru yok.'
                              : 'Aramaya uygun duyuru bulunamadı.',
                          style: SwanType.bodySm(c.inkMuted));
                    return Column(children: [
                      for (final item in filtered)
                        _buildAnnouncementCard(c, item)
                    ]);
                  },
                ),
              ]),
        ),
      ))),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _buildAnnouncementCard(SwanPalette c, AnnouncementRow a) {
    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.sm),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign_outlined, size: 16, color: c.accent),
                  const SizedBox(width: 4),
                  Text('Kulüp Duyurusu',
                      style: SwanType.caption(c.accent, w: FontWeight.w700)),
                ],
              ),
              Text(
                '${a.createdAt.day}.${a.createdAt.month}.${a.createdAt.year}',
                style: SwanType.caption(c.inkMuted),
              ),
            ],
          ),
          const SizedBox(height: SwanSpace.xs),
          Text(a.title, style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(a.body, style: SwanType.caption(c.inkMuted)),
        ],
      ),
    );
  }

  Future<void> _compose(BuildContext context, ClubRef club) async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = ctx.swan;
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(SwanSpace.lg),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(SwanRadius.lg)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yeni Duyuru Yaz', style: SwanType.h3(c.ink)),
                const SizedBox(height: SwanSpace.md),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Duyuru Başlığı',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: SwanSpace.sm),
                TextField(
                  controller: bodyCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Duyuru Metni',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: SwanSpace.md),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      try {
                        await ref.read(clubDataServiceProvider).addAnnouncement(
                              club.id,
                              titleCtrl.text.trim(),
                              bodyCtrl.text.trim(),
                              false,
                            );
                        ref.invalidate(announcementsProvider);
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Hata: $e')),
                          );
                        }
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: c.accent),
                    child: const Text('Duyuruyu Yayınla'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
