import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/push/push.dart';
import '../../../app/push/push_service.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import 'widgets/social_widgets.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Bildirimler — beğeni, yorum, takip, başvuru ve onay hareketleri.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// Boş = hepsi. Kategoriler veritabanındaki eşlemeden gelir.
  String _category = '';

  static const _categories = [
    ('', 'Tümü'),
    ('kritik', 'Kritik'),
    ('aidat', 'Aidat'),
    ('antrenman', 'Antrenman'),
    ('kulup', 'Kulüp'),
    ('federasyon', 'Federasyon'),
    ('sosyal', 'Sosyal'),
  ];

  @override
  void initState() {
    super.initState();
    // Ekran açılınca okundu say.
    Future.microtask(() async {
      await ref.read(notificationServiceProvider).markAllRead();
      if (mounted) ref.invalidate(unreadNotificationsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final async = ref.watch(categorizedNotificationsProvider(_category));

    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
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
                    const SizedBox(width: 14),
                    Text('Bildirimler', style: SwanType.h2(ink)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/mesajlar'),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: surf,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: line)),
                        child: Icon(Icons.chat_bubble_outline_rounded,
                            size: 18, color: ink),
                      ),
                    ),
                  ]),
                ),
                const _PushBanner(),
                _categoryBar(isDark, ink),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(
                          categorizedNotificationsProvider(_category));
                      await ref.read(
                          categorizedNotificationsProvider(_category).future);
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
                                icon: Icons.notifications_none_rounded,
                                title: 'Bildirim yok',
                                subtitle:
                                    'Beğeni, yorum ve başvurular burada görünür.',
                              ),
                            ],
                          );
                        }
                        return _groupedList(isDark, list);
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


  /// Kategori şeridi — bildirim yığını büyüdükçe filtrelemeden okunmaz oluyor.
  Widget _categoryBar(bool isDark, Color ink) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        children: [
          for (final c in _categories)
            GestureDetector(
              onTap: () => setState(() => _category = c.$1),
              child: Container(
                margin: const EdgeInsets.only(right: 7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: _category == c.$1
                      ? kTeal
                      : (isDark ? const Color(0xFF1A2537) : Colors.white),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _category == c.$1
                          ? kTeal
                          : (isDark
                              ? const Color(0xFF233149)
                              : const Color(0xFFEAEEF3))),
                ),
                child: Text(c.$2,
                    style: SwanType.caption(_category == c.$1 ? Colors.white : ink, w: FontWeight.w700)),
              ),
            ),
          GestureDetector(
            onTap: _openPrefs,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF233149)
                        : const Color(0xFFEAEEF3)),
              ),
              child: Icon(Icons.tune_rounded,
                  size: 15, color: SwanColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  /// Bildirim tercihleri.
  ///
  /// "Kapat" demek "sil" demek değil: kapatılan kategori uygulama içinde yine
  /// listelenir, yalnızca telefon titremez.
  Future<void> _openPrefs() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            20, 18, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Bildirim tercihleri', style: SwanType.h3(ink)),
          const SizedBox(height: 4),
          Text('Kapattığın kategori telefonuna düşmez; uygulamada yine görünür.',
              textAlign: TextAlign.center,
              style: SwanType.caption(SwanColors.textSecondary)),
          const SizedBox(height: 14),
          Flexible(
            child: Consumer(builder: (_, r, __) {
              final prefs = r.watch(notificationPrefsProvider);
              return prefs.when(
                loading: premiumLoading,
                error: (e, _) => premiumError(context, '$e'),
                data: (list) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in list)
                      SwitchListTile(
                        value: p.enabled,
                        activeTrackColor: kTeal,
                        title: Text(p.label,
                            style: SwanType.bodySm(ink, w: FontWeight.w700)),
                        subtitle: Text(p.hint,
                            style: SwanType.caption(SwanColors.textSecondary)),
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
            }),
          ),
        ]),
      ),
    );
  }

  Widget _tile(bool isDark, NotificationRow n) {

    final (icon, color) = switch (n.kind) {
      'like' => (Icons.favorite_rounded, const Color(0xFFF43F5E)),
      'comment' => (Icons.mode_comment_rounded, const Color(0xFF2563EB)),
      'follow' => (Icons.person_add_rounded, const Color(0xFF7C5CE6)),
      'application' => (Icons.group_add_rounded, const Color(0xFF10B981)),
      'offer' => (Icons.mail_rounded, const Color(0xFFD9860B)),
      'announcement' => (Icons.campaign_rounded, kTeal),
      'fee_reminder' => (Icons.account_balance_wallet_rounded,
          Color(0xFFD9860B)),
      'attendance_reminder' => (Icons.checklist_rounded, Color(0xFF2563EB)),
      'payment' => (Icons.payments_rounded, Color(0xFF10B981)),
      'donation' => (Icons.volunteer_activism_rounded, Color(0xFFFF7A59)),
      _ => (Icons.verified_rounded, kTeal),
    };

    final c = context.swan;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(n),
      child: Container(
        // Okunmamışı kutuyla değil sol kenardaki ince şeritle işaretliyoruz —
        // brief §9: "Bildirimleri devasa kartlara koyma."
        padding: const EdgeInsets.fromLTRB(
            SwanSpace.md, SwanSpace.md, 0, SwanSpace.md),
        decoration: n.isUnread
            ? BoxDecoration(
                border: Border(
                    left: BorderSide(color: c.accent, width: 3)))
            : null,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: SwanSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title,
                    style: SwanType.bodySm(c.ink,
                        w: n.isUnread ? FontWeight.w800 : FontWeight.w700)),
                if (n.body != null && n.body!.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(n.body!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.caption(c.inkMuted)),
                ],
                const SizedBox(height: 3),
                Text(shortAgo(n.createdAt),
                    style: SwanType.caption(c.inkMuted)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  /// Zamana göre gruplu liste — brief §9: "Bugün / Bu hafta".
  ///
  /// Gruplama sunucuda değil burada: `createdAt` zaten geliyor, ekstra sorgu
  /// gerekmiyor.
  Widget _groupedList(bool isDark, List<NotificationRow> list) {
    final c = context.swan;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 7));

    final buckets = <String, List<NotificationRow>>{
      'Bugün': [],
      'Bu hafta': [],
      'Daha önce': [],
    };
    for (final n in list) {
      final at = n.createdAt;
      if (!at.isBefore(today)) {
        buckets['Bugün']!.add(n);
      } else if (at.isAfter(weekStart)) {
        buckets['Bu hafta']!.add(n);
      } else {
        buckets['Daha önce']!.add(n);
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          SwanSpace.lg, 0, SwanSpace.lg, 132),
      children: [
        for (final e in buckets.entries)
          if (e.value.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                  top: SwanSpace.lg, bottom: SwanSpace.xs),
              child: Text(e.key, style: SwanType.h3(c.ink)),
            ),
            for (final n in e.value) _tile(isDark, n),
          ],
      ],
    );
  }

  void _open(NotificationRow n) {
    switch (n.entityType) {
      case 'profile':
        Navigator.pushNamed(context, '/profil', arguments: n.entityId);
      case 'application':
        Navigator.pushNamed(context, '/basvurular');
      case 'credential':
        Navigator.pushNamed(context, '/dogrulama');
      case 'post':
        if (n.actorId != null) {
          Navigator.pushNamed(context, '/akis');
        }
      default:
        break;
    }
  }
}


/// Telefona düşen bildirimleri açma/kapama şeridi.
///
/// Bildirimler ekranının tepesinde duruyor çünkü kullanıcı tam da bildirimlere
/// baktığı anda "bunlar telefonuma da gelsin" diyecek durumda oluyor.
class _PushBanner extends ConsumerWidget {
  const _PushBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!pushSupported) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
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
          Icon(on ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
              size: 19, color: on ? kTeal : SwanColors.textSecondary),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(on ? 'Telefon bildirimleri açık' : 'Telefon bildirimleri kapalı',
                    style: SwanType.caption(ink, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    on
                        ? 'Uygulama kapalıyken de haber verilir.'
                        : 'Aç ki mesaj ve duyurular telefonuna düşsün.',
                    style: SwanType.caption(SwanColors.textSecondary)),
              ],
            ),
          ),
          Switch(
            value: on,
            activeThumbColor: kTeal,
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
        messenger.showSnackBar(const SnackBar(
            content: Text('Bildirimler açıldı'), backgroundColor: kTeal));
      } else {
        await disablePush(ref);
        messenger.showSnackBar(const SnackBar(
            content: Text('Bildirimler kapatıldı'),
            backgroundColor: SwanColors.textSecondary));
      }
    } on PushException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(switch (e.reason) {
          PushFailure.denied =>
            'Bildirim izni reddedilmiş. Tarayıcı ayarlarından izin verip tekrar dene.',
          PushFailure.unsupported =>
            'Bu tarayıcı bildirim desteklemiyor. iPhone kullanıyorsan uygulamayı ana ekrana ekleyip oradan aç.',
          PushFailure.failed => 'Bildirim açılamadı, tekrar dener misin?',
        }),
        backgroundColor: const Color(0xFFF43F5E),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Bildirim açılamadı: $e'),
          backgroundColor: const Color(0xFFF43F5E)));
    }
  }
}
