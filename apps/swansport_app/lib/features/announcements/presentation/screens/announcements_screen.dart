import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/design/swan_type.dart';

/// İletişim & Duyurular — Supabase verisine bağlı, premium tasarım (v3).
class AnnouncementsScreen extends ConsumerStatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  ConsumerState<AnnouncementsScreen> createState() =>
      _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends ConsumerState<AnnouncementsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final club = ref.watch(activeClubProvider).valueOrNull;
    final async = ref.watch(announcementsProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(announcementsProvider);
                await ref.read(announcementsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(club?.name.toUpperCase() ?? 'KULÜP',
                                style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700)),
                            const SizedBox(height: 3),
                            Text('Duyurular',
                                style: SwanType.h2(ink)),
                          ],
                        ),
                      ),
                      if (club != null)
                        GestureDetector(
                          onTap: () => _compose(context, ref, club),
                          child: _newBtn(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('communication-search-field'),
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value.trim()),
                    style: SwanType.bodySm(ink),
                    decoration: InputDecoration(
                      hintText: 'Duyurularda ara…',
                      hintStyle: SwanType.bodySm(SwanColors.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              key: const Key('communication-search-clear'),
                              tooltip: 'Aramayı temizle',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                      filled: true,
                      fillColor: surf,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: line),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  async.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (items) {
                      final needle = _query.toLowerCase();
                      final filtered = needle.isEmpty
                          ? items
                          : items
                              .where((item) =>
                                  item.title.toLowerCase().contains(needle) ||
                                  item.body.toLowerCase().contains(needle))
                              .toList();
                      if (filtered.isEmpty && needle.isNotEmpty) {
                        return premiumEmpty(
                          context,
                          icon: Icons.search_off_rounded,
                          title: 'Duyuru bulunamadı',
                          subtitle: 'Başlık veya içerikte “$_query” geçmiyor.',
                        );
                      }
                      if (items.isEmpty) {
                        return premiumEmpty(
                          context,
                          icon: Icons.campaign_rounded,
                          title: 'Henüz duyuru yok',
                          subtitle: club == null
                              ? 'Önce Kadro’dan bir kulüp oluştur.'
                              : 'İlk duyurunu paylaş.',
                          actionLabel: club == null ? null : 'Duyuru Yaz',
                          onAction: club == null
                              ? null
                              : () => _compose(context, ref, club),
                        );
                      }
                      return Column(
                        children:
                            filtered.map((a) => _card(isDark, a)).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Widget _card(bool isDark, AnnouncementRow a) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: a.pinned ? kTeal.withValues(alpha: 0.4) : line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (a.pinned) ...[
                const Icon(Icons.push_pin_rounded, size: 14, color: kTeal),
                const SizedBox(width: 6),
              ],
              Expanded(
                child:
                    Text(a.title, style: SwanType.bodySm(ink, w: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(a.body,
              style: SwanType.caption(SwanColors.textSecondary)),
          const SizedBox(height: 10),
          Text(_ago(a.createdAt),
              style: SwanType.caption(SwanColors.textSecondary)),
        ],
      ),
    );
  }

  Future<void> _compose(
      BuildContext context, WidgetRef ref, ClubRef club) async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    var pinned = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: surf,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Text('Duyuru Yaz', style: SwanType.h3(ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: SwanType.bodySm(ink, w: FontWeight.w700),
                decoration: const InputDecoration(labelText: 'Başlık'),
              ),
              TextField(
                controller: bodyCtrl,
                maxLines: 3,
                style: SwanType.bodySm(ink),
                decoration: const InputDecoration(labelText: 'İçerik'),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Checkbox(
                    value: pinned,
                    activeColor: kTeal,
                    onChanged: (v) => setLocal(() => pinned = v ?? false),
                  ),
                  Text('Sabitle', style: SwanType.caption(ink, w: FontWeight.w600)),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('İptal',
                  style:
                      SwanType.bodySm(SwanColors.textSecondary, w: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Paylaş', style: SwanType.bodySm(kTeal, w: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
    if (ok != true || titleCtrl.text.trim().isEmpty) return;
    try {
      await ref.read(clubDataServiceProvider).addAnnouncement(
          club.id, titleCtrl.text.trim(), bodyCtrl.text.trim(), pinned);
      ref.invalidate(announcementsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Duyuru paylaşıldı'), backgroundColor: kTeal),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: const Color(0xFFF43F5E)),
        );
      }
    }
  }

  String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
    if (diff.inHours < 24) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';
    return '${d.day}.${d.month}.${d.year}';
  }

  Widget _newBtn() => Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [kTealBright, kTeal]),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 4),
            Text('Yeni', style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
          ],
        ),
      );
}
