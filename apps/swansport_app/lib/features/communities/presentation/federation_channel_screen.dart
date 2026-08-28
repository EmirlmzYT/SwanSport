import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../social/presentation/widgets/social_widgets.dart';

/// Federasyon duyuru kanalı.
///
/// Şehir gruplarından bilerek farklı görünüyor: burası sohbet değil, duyuru
/// panosu. Baloncuk yerine kart, karışık sıra yerine yeniden eskiye. Antrenör
/// ana akışa yazamaz; her duyurunun altındaki dizide soru sorar.
class FederationChannelScreen extends ConsumerStatefulWidget {
  const FederationChannelScreen({
    super.key,
    required this.communityId,
    required this.title,
  });

  final String communityId;
  final String title;

  @override
  ConsumerState<FederationChannelScreen> createState() =>
      _FederationChannelScreenState();
}

class _FederationChannelScreenState
    extends ConsumerState<FederationChannelScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(communityServiceProvider).markRead(widget.communityId);
      if (mounted) ref.invalidate(communityListProvider);
    });
  }

  /// Bu kanalda duyuru yazma yetkim var mı?
  bool get _canPublish {
    final list = ref.watch(communityListProvider).valueOrNull ?? const [];
    for (final c in list) {
      if (c.id == widget.communityId) return c.canWrite;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final async = ref.watch(federationAnnouncementsProvider(widget.communityId));

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: line)),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: sora(18, FontWeight.w800, ink)),
                          Text('Resmî duyuru kanalı',
                              style: jakarta(10.5, FontWeight.w600,
                                  SwanColors.textSecondary)),
                        ],
                      ),
                    ),
                  ]),
                ),
                Divider(color: line, height: 1),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(federationAnnouncementsProvider(widget.communityId));
                      await ref.read(
                          federationAnnouncementsProvider(widget.communityId).future);
                    },
                    child: async.when(
                      loading: () => ListView(children: [premiumLoading()]),
                      error: (e, _) =>
                          ListView(children: [premiumError(context, '$e')]),
                      data: (list) {
                        if (list.isEmpty) {
                          return ListView(
                            padding: const EdgeInsets.only(top: 40),
                            children: [
                              premiumEmpty(
                                context,
                                icon: Icons.campaign_outlined,
                                title: 'Henüz duyuru yok',
                                subtitle: _canPublish
                                    ? 'İlk duyuruyu sen yayımla.'
                                    : 'Federasyon duyuru yayımladığında '
                                        'burada ve bildirimlerinde görürsün.',
                              ),
                            ],
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                          itemCount: list.length,
                          itemBuilder: (_, i) => _card(isDark, list[i]),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _canPublish
          ? FloatingActionButton.extended(
              onPressed: _publish,
              backgroundColor: kTeal,
              icon: const Icon(Icons.campaign_rounded, color: Colors.white),
              label: Text('Duyuru',
                  style: jakarta(13, FontWeight.w800, Colors.white)),
            )
          : null,
    );
  }

  Widget _card(bool isDark, FederationAnnouncement a) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SocialAvatar(
              initials: a.senderName.isEmpty ? 'F' : a.senderName[0],
              imageUrl: a.senderAvatarUrl,
              size: 34,
              radius: 11,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: jakarta(12.5, FontWeight.w800, ink)),
                  Text(shortAgo(a.createdAt),
                      style: jakarta(
                          10.5, FontWeight.w600, SwanColors.textSecondary)),
                ],
              ),
            ),
            // Hedef rozeti: duyurunun kime gittiği bir bakışta belli olsun.
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: kTeal.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(
                    a.cityName == null
                        ? Icons.public_rounded
                        : Icons.location_on_rounded,
                    size: 11,
                    color: kTeal),
                const SizedBox(width: 4),
                Text(a.cityName ?? 'Tüm Türkiye',
                    style: jakarta(10, FontWeight.w800, kTeal)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          Text(a.body,
              style: jakarta(13.5, FontWeight.w500, ink).copyWith(height: 1.45)),
          const SizedBox(height: 12),
          Divider(color: line, height: 1),
          const SizedBox(height: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openThread(a),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Icon(Icons.mode_comment_outlined,
                    size: 15, color: SwanColors.textSecondary),
                const SizedBox(width: 7),
                Text(
                    a.replyCount == 0
                        ? 'Soru sor'
                        : '${a.replyCount} yanıt',
                    style: jakarta(12, FontWeight.w700,
                        a.replyCount == 0 ? SwanColors.textSecondary : kTeal)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    size: 17, color: SwanColors.textSecondary),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------- duyuru yaz -------------------------------
  Future<void> _publish() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final ctrl = TextEditingController();
    final cities = ref.read(citiesProvider).valueOrNull ?? const <CityRow>[];
    String? cityCode; // boş = tüm Türkiye

    final sent = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
          decoration: BoxDecoration(
            color: surf,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Duyuru yayımla', style: sora(19, FontWeight.w800, ink)),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              minLines: 4,
              maxLines: 10,
              autofocus: true,
              style: jakarta(13.5, FontWeight.w500, ink),
              decoration: InputDecoration(
                hintText: 'Duyuru metni…',
                hintStyle:
                    jakarta(13, FontWeight.w500, SwanColors.textSecondary),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15)),
              ),
            ),
            const SizedBox(height: 14),
            // Hedef seçimi: tüm ülke ya da tek il.
            Row(children: [
              Icon(Icons.send_rounded, size: 16, color: SwanColors.textSecondary),
              const SizedBox(width: 8),
              Text('Kime:',
                  style: jakarta(12, FontWeight.w700, SwanColors.textSecondary)),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () async {
                    final picked = await _pickCity(cities, cityCode);
                    setSheet(() => cityCode = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: kTeal.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Text(
                            cityCode == null
                                ? 'Tüm Türkiye'
                                : cities
                                    .firstWhere((c) => c.code == cityCode)
                                    .name,
                            style: jakarta(12.5, FontWeight.w800, kTeal)),
                      ),
                      const Icon(Icons.expand_more_rounded,
                          size: 18, color: kTeal),
                    ]),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text('Yayımla',
                    style: jakarta(14, FontWeight.w800, Colors.white)),
              ),
            ),
          ]),
        );
      }),
    );

    if (sent != true || ctrl.text.trim().isEmpty) return;

    try {
      await ref.read(communityServiceProvider).publish(
            widget.communityId,
            ctrl.text,
            cityCode: cityCode,
          );
      ref.invalidate(federationAnnouncementsProvider(widget.communityId));
      ref.invalidate(communityListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Duyuru yayımlandı'), backgroundColor: kTeal));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Yayımlanamadı: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    }
  }

  Future<String?> _pickCity(List<CityRow> cities, String? current) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.7,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(children: [
          Text('Kime gitsin?', style: sora(18, FontWeight.w800, ink)),
          const SizedBox(height: 10),
          Expanded(
            child: ListView(children: [
              ListTile(
                leading: const Icon(Icons.public_rounded, color: kTeal),
                title: Text('Tüm Türkiye',
                    style: jakarta(13.5, FontWeight.w700, ink)),
                trailing: current == null
                    ? const Icon(Icons.check_rounded, color: kTeal, size: 19)
                    : null,
                onTap: () => Navigator.pop(ctx, null),
              ),
              for (final c in cities)
                ListTile(
                  title:
                      Text(c.name, style: jakarta(13.5, FontWeight.w600, ink)),
                  trailing: c.code == current
                      ? const Icon(Icons.check_rounded, color: kTeal, size: 19)
                      : null,
                  onTap: () => Navigator.pop(ctx, c.code),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  // -------------------------------- yanıtlar --------------------------------
  Future<void> _openThread(FederationAnnouncement a) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ThreadSheet(
        communityId: widget.communityId,
        announcement: a,
      ),
    );
    ref.invalidate(federationAnnouncementsProvider(widget.communityId));
  }
}

/// Duyurunun altındaki soru/yanıt dizisi.
class _ThreadSheet extends ConsumerStatefulWidget {
  const _ThreadSheet({required this.communityId, required this.announcement});

  final String communityId;
  final FederationAnnouncement announcement;

  @override
  ConsumerState<_ThreadSheet> createState() => _ThreadSheetState();
}

class _ThreadSheetState extends ConsumerState<_ThreadSheet> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(communityServiceProvider)
          .reply(widget.communityId, widget.announcement.id, text);
      _ctrl.clear();
      ref.invalidate(repliesProvider(widget.announcement.id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Gönderilemedi: $e'),
            backgroundColor: const Color(0xFFF43F5E)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final alt = isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8);

    final async = ref.watch(repliesProvider(widget.announcement.id));

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, 14 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(children: [
        Text('Duyuru yanıtları', style: sora(17, FontWeight.w800, ink)),
        const SizedBox(height: 12),
        // Duyurunun kendisi bağlam olarak üstte kalsın.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: alt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(widget.announcement.body,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: jakarta(12.5, FontWeight.w500, ink).copyWith(height: 1.4)),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: async.when(
            loading: () => premiumLoading(),
            error: (e, _) => premiumError(context, '$e'),
            data: (list) {
              if (list.isEmpty) {
                return Center(
                  child: Text('İlk soruyu sen sor',
                      style: jakarta(
                          12.5, FontWeight.w600, SwanColors.textSecondary)),
                );
              }
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final r = list[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SocialAvatar(
                          initials:
                              r.senderName.isEmpty ? '?' : r.senderName[0],
                          imageUrl: r.senderAvatarUrl,
                          size: 30,
                          radius: 10,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(r.senderName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: jakarta(
                                          12, FontWeight.w800, ink)),
                                ),
                                Text(shortAgo(r.createdAt),
                                    style: jakarta(10, FontWeight.w600,
                                        SwanColors.textSecondary)),
                              ]),
                              const SizedBox(height: 2),
                              Text(r.body,
                                  style: jakarta(12.5, FontWeight.w500, ink)
                                      .copyWith(height: 1.35)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Divider(color: line, height: 20),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              minLines: 1,
              maxLines: 4,
              style: jakarta(13, FontWeight.w500, ink),
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Sorunu yaz…',
                hintStyle:
                    jakarta(12.5, FontWeight.w500, SwanColors.textSecondary),
                filled: true,
                fillColor: alt,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: line)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: kTeal, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 9),
          GestureDetector(
            onTap: _sending ? null : _send,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kTealBright, kTeal]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: _sending
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 18),
            ),
          ),
        ]),
      ]),
    );
  }
}
