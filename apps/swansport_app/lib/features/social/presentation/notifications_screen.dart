import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:swansport_app/app/widgets/swan_module_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../app/push/push.dart';
import '../../../app/push/push_service.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import 'widgets/social_widgets.dart';

/// Kişisel bildirim akışı ve telefon bildirim tercihleri.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _selectedFilter = 0;

  final List<String> _filters = const [
    'Tümü',
    'Sosyal',
    'Antrenman',
    'Kulüp',
  ];

  String get _category => switch (_selectedFilter) {
        1 => 'sosyal',
        2 => 'antrenman',
        3 => 'kulup',
        _ => '',
      };

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final async = ref.watch(categorizedNotificationsProvider(_category));
    final unreadCount = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;

    return SwanScaffold(
      appBar: swanModuleAppBar(context, title: 'Bildirimler', actions: [
        if (unreadCount > 0)
          IconButton(
              tooltip: 'Tümünü okundu işaretle',
              icon: Icon(Icons.done_all_rounded, color: c.inkMuted),
              onPressed: _markAllRead),
        IconButton(
            tooltip: 'Bildirim ayarları',
            icon: Icon(Icons.settings_outlined, color: c.inkMuted),
            onPressed: _openPrefs),
      ]),
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                _buildSubheader(c, unreadCount),
                _buildFilterChips(c),
                const SizedBox(height: SwanSpace.sm),
                Expanded(
                  child: RefreshIndicator(
                    color: c.accent,
                    backgroundColor: c.surface,
                    onRefresh: () async {
                      ref.invalidate(
                          categorizedNotificationsProvider(_category));
                      await ref.read(
                          categorizedNotificationsProvider(_category).future);
                    },
                    child: async.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) =>
                          ListView(children: [premiumError(context, '$e')]),
                      data: (list) {
                        if (list.isEmpty) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 48),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: c.surfaceAlt,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                          Icons.notifications_none_rounded,
                                          size: 32,
                                          color: c.inkMuted),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _selectedFilter == 0
                                          ? 'Henüz bildirimin yok'
                                          : 'Bu kategoride bildirim yok',
                                      style: SwanType.h3(c.ink).copyWith(
                                          fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _selectedFilter == 0
                                          ? 'Yeni gelişmeler olduğunda burada göreceksin.'
                                          : 'Diğer bildirimlere Tümü sekmesinden bakabilirsin.',
                                      textAlign: TextAlign.center,
                                      style: SwanType.caption(c.inkMuted),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          );
                        }

                        return ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(SwanSpace.md,
                              SwanSpace.md, SwanSpace.md, SwanSpace.xl * 5),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final n = list[i];
                            final heading = _dateHeading(n.createdAt);
                            final previousHeading = i == 0
                                ? null
                                : _dateHeading(list[i - 1].createdAt);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (heading != previousHeading)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        top: i == 0 ? 0 : SwanSpace.lg,
                                        bottom: SwanSpace.sm),
                                    child: Text(heading,
                                        style: SwanType.bodySm(c.ink,
                                            w: FontWeight.w700)),
                                  ),
                                _tile(c, n),
                                if (i + 1 < list.length &&
                                    _dateHeading(list[i + 1].createdAt) ==
                                        heading)
                                  Divider(height: 1, indent: 62, color: c.line),
                              ],
                            );
                          },
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
      bottomNavigationBar: const SwanBottomNav(),
    );
  }

  Future<void> _markAllRead() async {
    try {
      await ref.read(notificationServiceProvider).markAllRead();
      if (!mounted) return;
      ref.invalidate(unreadNotificationsProvider);
      ref.invalidate(categorizedNotificationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Tüm bildirimler okundu olarak işaretlendi.')));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Bildirimler işaretlenemedi. Tekrar deneyin.')));
    }
  }

  Widget _buildSubheader(SwanPalette c, int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          SwanSpace.md, SwanSpace.md, SwanSpace.md, SwanSpace.xs),
      child: Row(children: [
        Expanded(
            child: Text(
                unreadCount > 0 ? 'Gelişmelerin burada' : 'Tüm bildirimler',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwanType.bodySm(c.inkMuted))),
        if (unreadCount > 0) ...[
          const SizedBox(width: SwanSpace.sm),
          Flexible(
              child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: SwanSpace.sm, vertical: SwanSpace.xs),
            decoration: BoxDecoration(
                color: c.accentSoft,
                borderRadius: BorderRadius.circular(SwanRadius.sm)),
            child: Text('$unreadCount yeni',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SwanType.caption(c.accent, w: FontWeight.w800)),
          )),
        ],
      ]),
    );
  }

  Widget _buildFilterChips(SwanPalette c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding:
          const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 6),
      child: Row(
        children: _filters.asMap().entries.map((entry) {
          final idx = entry.key;
          final label = entry.value;
          final isSelected = _selectedFilter == idx;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => setState(() => _selectedFilter = idx),
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? c.accentFill : c.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: isSelected ? c.accentFill : c.line),
                ),
                child: Text(
                  label,
                  style: SwanType.caption(isSelected ? c.onAccent : c.ink,
                      w: isSelected ? FontWeight.w800 : FontWeight.w500),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _dateHeading(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return 'Bugün';
    if (day == today.subtract(const Duration(days: 1))) return 'Dün';
    return 'Daha önce';
  }

  IconData _iconFor(NotificationRow n) => switch (n.kind) {
        'like' => Icons.favorite_rounded,
        'comment' => Icons.mode_comment_rounded,
        'follow' => Icons.person_add_rounded,
        'message' => Icons.chat_bubble_rounded,
        'match_live' || 'match_result' => Icons.sports_score_rounded,
        'referee_assignment' => Icons.sports_rounded,
        'training' || 'attendance' => Icons.fitness_center_rounded,
        'application' || 'offer' || 'review' => Icons.assignment_rounded,
        _ => Icons.notifications_rounded,
      };

  Widget _tile(SwanPalette c, NotificationRow n) {
    final route = n.resultRoute ?? n.refereeRoute ?? n.liveMatchRoute;
    return InkWell(
        onTap: route == null ? null : () => Navigator.pushNamed(context, route),
        borderRadius: BorderRadius.circular(SwanRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: SwanSpace.sm, vertical: SwanSpace.md),
          decoration: BoxDecoration(
            color: n.isUnread ? c.accentSoft : c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: n.isUnread ? c.surface : c.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(n),
                    size: 19, color: n.isUnread ? c.accent : c.inkMuted),
              ),
              const SizedBox(width: SwanSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            n.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: SwanType.bodySm(c.ink,
                                w: n.isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: SwanSpace.sm),
                        Text(shortAgo(n.createdAt),
                            style: SwanType.caption(c.inkMuted)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if ((n.body ?? '').trim().isNotEmpty)
                      Text(n.body!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.bodySm(c.inkMuted)),
                  ],
                ),
              ),
              if (n.isUnread) ...[
                const SizedBox(width: SwanSpace.sm),
                Padding(
                  padding: const EdgeInsets.only(top: SwanSpace.sm),
                  child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: c.accent, shape: BoxShape.circle)),
                ),
              ],
            ],
          ),
        ));
  }

  Future<void> _openPrefs() async {
    final c = context.swan;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
        ),
        padding: EdgeInsets.fromLTRB(SwanSpace.lg, 18, SwanSpace.lg,
            20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Bildirim Tercihleri', style: SwanType.h3(c.ink)),
            const SizedBox(height: 4),
            Text(
              'Kapattığın kategori telefonuna düşmez; uygulamada yine görünür.',
              textAlign: TextAlign.center,
              style: SwanType.caption(c.inkMuted),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: Consumer(
                builder: (_, r, __) {
                  final prefs = r.watch(notificationPrefsProvider);
                  return prefs.when(
                    loading: premiumLoading,
                    error: (e, _) => premiumError(context, '$e'),
                    data: (list) => ListView(
                      shrinkWrap: true,
                      children: [
                        const _PushBanner(),
                        const _PushDiagnosticsPanel(),
                        for (final p in list)
                          SwitchListTile(
                            value: p.enabled,
                            activeTrackColor: c.accent,
                            title: Text(p.label,
                                style:
                                    SwanType.bodySm(c.ink, w: FontWeight.w700)),
                            subtitle: Text(p.hint,
                                style: SwanType.caption(c.inkMuted)),
                            onChanged: (v) async {
                              await ref
                                  .read(notificationServiceProvider)
                                  .setPref(p.category, v);
                              ref.invalidate(notificationPrefsProvider);
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PushBanner extends ConsumerWidget {
  const _PushBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!pushSupported) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = (isDark ? SwanPalette.dark : SwanPalette.light).ink;
    final surf = (isDark ? SwanPalette.dark : SwanPalette.light).surface;
    final line = (isDark ? SwanPalette.dark : SwanPalette.light).line;
    final on = ref.watch(pushEnabledProvider).valueOrNull ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Icon(
              on
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_rounded,
              size: 19,
              color: on ? context.swan.accentFill : context.swan.inkMuted),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    on
                        ? 'Telefon bildirimleri açık'
                        : 'Telefon bildirimleri kapalı',
                    style: SwanType.caption(ink, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    on
                        ? 'Uygulama kapalıyken de haber verilir.'
                        : 'Aç ki mesaj ve duyurular telefonuna düşsün.',
                    style: SwanType.caption(context.swan.inkMuted)),
              ],
            ),
          ),
          Switch(
            value: on,
            activeThumbColor: context.swan.accent,
            onChanged: (v) => _toggle(context, ref, v),
          ),
        ]),
      ),
    );
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, bool value) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (value) {
        await enablePush(ref);
        messenger.showSnackBar(SnackBar(
            content: Text('Bildirimler açıldı'),
            backgroundColor: context.swan.accent));
      } else {
        await disablePush(ref);
        messenger.showSnackBar(SnackBar(
            content: Text('Bildirimler kapatıldı'),
            backgroundColor: context.swan.inkMuted));
      }
    } on PushException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(switch (e.reason) {
          PushFailure.denied =>
            'Bildirim izni reddedilmiş. Tarayıcı ayarlarından izin verip tekrar dene.',
          PushFailure.unsupported =>
            'Bu tarayıcı bildirim desteklemiyor. iPhone kullanıyorsan uygulamayı ana ekrana ekleyip oradan aç.',
          PushFailure.failed => 'Bildirim açılamadı, tekrar dener misin?',
          PushFailure.apnsUnavailable =>
            'iOS APNs kaydı hazır değil. İmza ve Firebase yapılandırması kontrol edilmeli.',
        }),
        backgroundColor: SwanPalette.light.danger,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Bildirim açılamadı: $e'),
          backgroundColor: SwanPalette.light.danger));
    }
  }
}

class _PushDiagnosticsPanel extends ConsumerWidget {
  const _PushDiagnosticsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!pushSupported) return const SizedBox.shrink();

    final diag = ref.watch(pushDiagnosticsProvider).valueOrNull;
    if (diag == null || diag.healthy) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? SwanPalette.dark : SwanPalette.light;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.warning.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.warning.withValues(alpha: .30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.info_outline_rounded, size: 17, color: c.warning),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Bildirimler neden gelmiyor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(c.ink, w: FontWeight.w800))),
            ]),
            const SizedBox(height: 8),
            Text(diag.summary, style: SwanType.caption(c.inkMuted)),
            const SizedBox(height: 10),
            _row(c, 'İzin', diag.permission),
            _row(c, 'Cihaz adresi', diag.token != null),
            _row(c, 'Sunucuya kayıt', diag.registered,
                note: diag.state == PushSubState.otherAccount
                    ? 'başka hesapta'
                    : null),
            if (diag.error != null) ...[
              const SizedBox(height: 6),
              SelectableText(diag.error!, style: SwanType.caption(c.danger)),
            ],
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _retry(context, ref),
              child: Container(
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accentFill,
                  borderRadius: BorderRadius.circular(SwanRadius.sm),
                ),
                child: Text('Kaydı tekrar dene',
                    style: SwanType.caption(context.swan.onAccent,
                        w: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await enablePush(ref);
      ref.invalidate(pushDiagnosticsProvider);
      messenger.showSnackBar(SnackBar(
          content: Text('Cihaz kaydedildi'),
          backgroundColor: context.swan.accent));
    } catch (e) {
      ref.invalidate(pushDiagnosticsProvider);
      messenger.showSnackBar(SnackBar(
        content: Text('Kayıt başarısız: $e'),
        backgroundColor: SwanPalette.light.danger,
        duration: const Duration(seconds: 10),
      ));
    }
  }

  Widget _row(SwanPalette c, String label, bool ok, {String? note}) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(children: [
          Icon(ok ? Icons.check_rounded : Icons.close_rounded,
              size: 13, color: ok ? c.success : c.danger),
          const SizedBox(width: 6),
          Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(c.inkMuted))),
          const SizedBox(width: SwanSpace.sm),
          Flexible(
              child: Text(note ?? (ok ? 'var' : 'yok'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(ok ? c.success : c.danger,
                      w: FontWeight.w700))),
        ]),
      );
}
