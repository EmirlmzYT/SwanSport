import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

/// Bugün yapılması gerekenler — **bütün rollerden birleşik**.
///
/// **Neden rol seçici yok:** aynı kişi aynı anda hem antrenör hem veli
/// olabiliyor. "Aktif rol" kavramı kullanıcıyı, çocuğunun aidatını görmek
/// için rol değiştirmeye zorlardı; oysa ikisi de aynı sabahın işi.
///
/// Kartlar rol **etiketi** taşıyor: iş hangi şapkadan geliyor belli oluyor
/// ama hiçbiri gizlenmiyor. Etiket yalnızca bilgi — yetkiyi, gezinmeyi ya da
/// erişimi değiştirmiyor. O `SwanAccess` ve RLS'in işi.
///
/// **En fazla üç kart.** Ana Sayfa'nın işi "bugün ne yapmalıyım" sorusuna
/// cevap vermek; on kart o soruyu cevaplamıyor, erteliyor. Fazlası ilgili
/// bölüme yönlendiriliyor.
class TodayTasks extends ConsumerWidget {
  const TodayTasks({this.maxItems = 3, super.key});

  final int maxItems;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.swan;
    final tasks = _collect(ref, c);
    if (tasks.isEmpty) return const SizedBox.shrink();

    final shown = tasks.take(maxItems).toList();
    final more = tasks.length - shown.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: SwanSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Bugün', style: SwanType.h3(c.ink))),
            if (more > 0)
              Text('+$more', style: SwanType.caption(c.inkMuted)),
          ]),
          const SizedBox(height: SwanSpace.sm),
          for (final t in shown) ...[
            _card(context, c, t),
            const SizedBox(height: SwanSpace.sm),
          ],
        ],
      ),
    );
  }

  /// İşleri topla ve **önceliğe göre sırala**.
  ///
  /// Sıra planın koyduğu gibi: önce şimdi aksiyon bekleyen, sonra bugünkü
  /// program, sonra bekleyen yanıt. Aynı öncelikte olanlar eklendiği sırada
  /// kalıyor.
  List<_Task> _collect(WidgetRef ref, SwanPalette c) {
    final access = ref.watch(swanAccessProvider);
    final out = <_Task>[];

    // ---- Sporcu / veli: ödenmemiş aidat -----------------------------------
    final fees = ref.watch(myFeesProvider).valueOrNull ?? const [];
    final overdue = fees.where((f) => f.overdue).toList();
    if (overdue.isNotEmpty) {
      out.add(_Task(
        priority: 0,
        role: access.isParent ? 'Veli olarak' : 'Sporcu olarak',
        icon: Icons.receipt_long_rounded,
        title: overdue.length == 1
            ? 'Gecikmiş aidat var'
            : '${overdue.length} gecikmiş aidat var',
        subtitle: money(overdue.fold<num>(0, (a, f) => a + f.amount)),
        route: '/aidatlarim',
        tone: c.danger,
      ));
    }

    // ---- Bugünün etkinlikleri ---------------------------------------------
    final events = ref.watch(eventsProvider).valueOrNull ?? const [];
    final now = DateTime.now();
    final today = events
        .where((e) =>
            e.startsAt.year == now.year &&
            e.startsAt.month == now.month &&
            e.startsAt.day == now.day &&
            e.startsAt.isAfter(now.subtract(const Duration(hours: 2))))
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    if (today.isNotEmpty) {
      final e = today.first;
      final hh = e.startsAt.hour.toString().padLeft(2, '0');
      final mm = e.startsAt.minute.toString().padLeft(2, '0');

      // Antrenör için aynı etkinlik "yoklama al" işi; sporcu için "bugün
      // antrenman var" bilgisi. Aynı veri, farklı iş.
      if (access.isClubStaff) {
        out.add(_Task(
          priority: 0,
          role: 'Antrenör olarak',
          icon: Icons.checklist_rounded,
          title: 'Yoklama: ${e.title}',
          subtitle: '$hh:$mm${e.place == null ? '' : ' · ${e.place}'}',
          route: '/attendance',
          tone: c.accent,
        ));
      } else {
        out.add(_Task(
          priority: 1,
          role: 'Sporcu olarak',
          icon: Icons.event_available_rounded,
          title: e.title,
          subtitle: '$hh:$mm${e.place == null ? '' : ' · ${e.place}'}',
          route: '/calendar',
          tone: c.accent,
        ));
      }
    }

    // ---- Kulüp yöneticisi: bekleyen onaylar --------------------------------
    if (access.isClubStaff) {
      final apps =
          ref.watch(clubPendingApplicationsProvider).valueOrNull ?? const [];
      if (apps.isNotEmpty) {
        out.add(_Task(
          priority: 0,
          role: 'Yönetici olarak',
          icon: Icons.person_add_alt_1_rounded,
          title: apps.length == 1
              ? '1 başvuru onay bekliyor'
              : '${apps.length} başvuru onay bekliyor',
          route: '/onay-paneli',
          tone: c.warning,
        ));
      }
    }

    // ---- Mağaza yöneticisi: başvuru sonucu ---------------------------------
    // Pazaryeri bayrağı kapalıyken bu iş hiç görünmüyor: kullanıcıya
    // erişemediği bir şeyin işini vermek kafa karıştırır.
    if (ref.watch(featureEnabledProvider(FeatureFlags.marketplace))) {
      final stores = ref.watch(myStoresProvider).valueOrNull ?? const [];
      final pending = stores.where((s) => s.status == 'pending').length;
      if (pending > 0) {
        out.add(_Task(
          priority: 2,
          role: 'Mağaza olarak',
          icon: Icons.storefront_rounded,
          title: 'Mağaza başvurun inceleniyor',
          route: '/magaza-basvuru',
          tone: c.inkMuted,
        ));
      }
    }

    out.sort((a, b) => a.priority.compareTo(b.priority));
    return out;
  }

  Widget _card(BuildContext context, SwanPalette c, _Task t) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pushNamed(context, t.route),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: SwanSpace.lg, vertical: SwanSpace.md),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SwanRadius.md),
            border: Border(left: BorderSide(color: t.tone, width: 3)),
          ),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.tone.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(SwanRadius.sm),
              ),
              child: Icon(t.icon, size: 17, color: t.tone),
            ),
            const SizedBox(width: SwanSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Rol etiketi başlığın ÜSTÜNDE ve küçük: işin kendisi
                  // önce okunmalı, hangi şapkadan geldiği sonra.
                  Text(t.role,
                      style: SwanType.caption(c.faintOr(t.tone),
                          w: FontWeight.w700)),
                  Text(t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: SwanType.bodySm(c.ink, w: FontWeight.w700)),
                  if (t.subtitle != null)
                    Text(t.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.caption(c.inkMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.inkMuted),
          ]),
        ),
      );
}

class _Task {
  const _Task({
    required this.priority,
    required this.role,
    required this.icon,
    required this.title,
    required this.route,
    required this.tone,
    this.subtitle,
  });

  /// 0 = şimdi aksiyon bekliyor, 1 = bugünkü program, 2 = bilgilendirme.
  final int priority;
  final String role;
  final IconData icon;
  final String title;
  final String? subtitle;
  final String route;
  final Color tone;
}

extension on SwanPalette {
  /// Rol etiketi için soluk ton. Kartın kendi rengini kullanıyor ama
  /// başlıkla yarışmasın diye söndürülmüş.
  Color faintOr(Color tone) => tone == accent ? accent : inkMuted;
}
