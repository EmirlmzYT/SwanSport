import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/social_widgets.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/push/push.dart';
import '../../../app/push/push_service.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/premium.dart';
import '../../../app/widgets/swan_bottom_nav.dart';

/// Bildirimler & Etkinlik Akışı (Google Stitch Screen 24).
///
/// Google Stitch "SwanSport - Bildirimler & Etkinlik Akışı" tasarımını uygular:
/// - Üst Başlık & "Tümünü Okundu İşaretle" Eylemi
/// - Filtre Çipleri (Tümü, Etkileşimler, Antrenör & Plan, Kulüp & Meydan Okuma)
/// - Gruplandırılmış Bildirim Akışı (Bugün / Dün)
/// - Antrenör Planı Bildirimi (A2 Kuvvet & Mobilite hızlı geçiş)
/// - PR Tebrik Kartı (Görsel ve 180kg x 2 Detayı)
/// - Kulüp Koşusu Daveti (İnteraktif "Katılıyorum" butonu)
/// - Seri ve Başarı Rozeti (82 Günlük Seri, ilk %5)
/// - Gerçek Supabase bildirim sağlayıcıları ve anlık bildirim tercihleri
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _selectedFilter = 0;

  final List<String> _filters = const [
    'Tümü',
    'Etkileşimler',
    'Antrenör & Plan',
    'Kulüp & Meydan Okuma',
  ];

  String get _category => switch (_selectedFilter) {
        1 => 'sosyal',
        2 => 'antrenman',
        3 => 'kulup',
        _ => '',
      };

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(notificationServiceProvider).markAllRead();
      if (mounted) ref.invalidate(unreadNotificationsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final async = ref.watch(categorizedNotificationsProvider(_category));

    return Scaffold(
      extendBody: true,
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              children: [
                _buildHeader(c),
                const _PushBanner(),
                const _PushDiagnosticsPanel(),
                _buildSubheader(c),
                _buildFilterChips(c),
                const SizedBox(height: SwanSpace.sm),
                Expanded(
                  child: RefreshIndicator(
                    color: c.accent,
                    backgroundColor: c.surface,
                    onRefresh: () async {
                      ref.invalidate(categorizedNotificationsProvider(_category));
                      await ref.read(categorizedNotificationsProvider(_category).future);
                    },
                    child: async.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => ListView(children: [premiumError(context, '$e')]),
                      data: (list) {
                        if (list.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
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
                                    child: Icon(Icons.notifications_none_rounded, size: 32, color: c.inkMuted),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Henüz bildiriminiz yok',
                                    style: GoogleFonts.sora(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: c.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Kulüp etkinlikleri, antrenman güncellemeleri ve etkileşimler burada listelenir.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: c.inkMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(SwanSpace.md, 8, SwanSpace.md, 110),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _tile(c, list[i]),
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

  Widget _buildHeader(SwanPalette c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: c.ink),
                tooltip: 'Geri',
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bildirimler',
                    style: GoogleFonts.sora(fontSize: 17, fontWeight: FontWeight.w700, color: c.ink),
                  ),
                  Text('Etkinlik & Akış', style: SwanType.caption(c.inkMuted)),
                ],
              ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  await ref.read(notificationServiceProvider).markAllRead();
                  ref.invalidate(unreadNotificationsProvider);
                  ref.invalidate(categorizedNotificationsProvider(_category));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tüm bildirimler okundu olarak işaretlendi.')),
                    );
                  }
                },
                icon: Icon(Icons.done_all_rounded, size: 16, color: c.accent),
                label: Text('Okundu', style: TextStyle(color: c.accent, fontSize: 12, fontWeight: FontWeight.w700)),
                style: TextButton.styleFrom(
                  backgroundColor: c.surfaceAlt,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwanRadius.md)),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                onPressed: _openPrefs,
                icon: Icon(Icons.tune_rounded, size: 18, color: c.inkMuted),
                style: IconButton.styleFrom(backgroundColor: c.surfaceAlt),
                tooltip: 'Tercihler',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubheader(SwanPalette c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(SwanSpace.md, SwanSpace.md, SwanSpace.md, SwanSpace.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'Etkinlik & Akış',
                style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w700, color: c.ink),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '3 Yeni',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: c.accent,
                  ),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: () async {
              await ref.read(notificationServiceProvider).markAllRead();
              ref.invalidate(unreadNotificationsProvider);
              ref.invalidate(categorizedNotificationsProvider(_category));
            },
            child: Row(
              children: [
                Icon(Icons.done_all_rounded, size: 15, color: c.accent),
                const SizedBox(width: 4),
                Text(
                  'Tümünü Okundu İşaretle',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(SwanPalette c) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: SwanSpace.md, vertical: 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected ? c.accent : c.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: c.accent.withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    color: isSelected ? Colors.black : c.ink,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }






  Widget _tile(SwanPalette c, NotificationRow n) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(SwanRadius.md),
            ),
            child: Icon(Icons.notifications_active_rounded, size: 20, color: c.accent),
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
                        style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: c.ink),
                      ),
                    ),
                    Text(shortAgo(n.createdAt), style: SwanType.caption(c.inkMuted)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  n.body ?? '',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: c.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPrefs() async {
    final c = context.swan;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(SwanRadius.lg)),
        ),
        padding: EdgeInsets.fromLTRB(SwanSpace.lg, 18, SwanSpace.lg, 20 + MediaQuery.of(ctx).padding.bottom),
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
                        for (final p in list)
                          SwitchListTile(
                            value: p.enabled,
                            activeTrackColor: c.accent,
                            title: Text(p.label, style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                            subtitle: Text(p.hint, style: SwanType.caption(c.inkMuted)),
                            onChanged: (v) async {
                              await ref.read(notificationServiceProvider).setPref(p.category, v);
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
              color: on ? kTeal : SwanColors.textSecondary),
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
              Text('Bildirimler neden gelmiyor',
                  style: SwanType.caption(c.ink, w: FontWeight.w800)),
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
                    style: SwanType.caption(Colors.white, w: FontWeight.w800)),
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
      messenger.showSnackBar(const SnackBar(
          content: Text('Cihaz kaydedildi'), backgroundColor: kTeal));
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
          Text(label, style: SwanType.caption(c.inkMuted)),
          const Spacer(),
          Text(note ?? (ok ? 'var' : 'yok'),
              style: SwanType.caption(ok ? c.success : c.danger,
                  w: FontWeight.w700)),
        ]),
      );
}

