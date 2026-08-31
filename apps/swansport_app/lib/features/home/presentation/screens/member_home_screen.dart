import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/inbox_actions.dart';
import '../../../../app/widgets/premium.dart';
import '../../../../app/widgets/swan_bottom_nav.dart';
import '../../../../app/design/swan_type.dart';

/// Üye Ana Ekranı — en düşük yetkili rol (premium v3).
///
/// Üyenin asıl yolu rolünü doğrulatmak: belge yükleyip antrenör/sporcu
/// kimliği kazanınca yetkileri açılır. Ekran bu adımı merkeze alır; ayrıca
/// kulüp duyurularını gösterir.
class MemberHomeScreen extends ConsumerWidget {
  const MemberHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0A111E) : const Color(0xFFF4F7FA);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);

    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final club = ref.watch(activeClubProvider).valueOrNull;
    final anns = ref.watch(announcementsProvider);
    final creds = ref.watch(myCredentialsProvider);

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
                ref.invalidate(myCredentialsProvider);
                ref.invalidate(announcementsProvider);
                await ref.read(announcementsProvider.future);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 132),
                children: [
                  Row(children: [
                    GradientAvatar(
                        initials: profile?.initials ?? 'Ü',
                        size: 46,
                        gradientIndex: 3),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile?.fullName ?? 'Üye',
                              style: SwanType.bodySm(ink, w: FontWeight.w800)),
                          Text(
                              club?.name != null ? 'Üye · ${club!.name}' : 'Üye',
                              style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                        ],
                      ),
                    ),
                    const InboxActions(),
                  ]),
                  const SizedBox(height: 18),
                  Text('Üyelik', style: SwanType.h3(ink)),
                  const SizedBox(height: 4),
                  Text('Merhaba, ${profile?.firstName ?? 'Üye'}',
                      style: SwanType.h2(ink)),
                  const SizedBox(height: 16),

                  // Doğrulama durumu / CTA
                  creds.when(
                    loading: () => _skeleton(surf, line),
                    error: (_, __) => _verifyCta(context),
                    data: (list) {
                      if (list.isEmpty) return _verifyCta(context);
                      final c = list.first;
                      return _statusCard(context, isDark, c);
                    },
                  ),
                  const SizedBox(height: 20),

                  // Ne yapabilirim
                  Text('Ne Yapabilirsin', style: SwanType.h3(ink)),
                  const SizedBox(height: 10),
                  _infoRow(isDark, Icons.verified_user_rounded,
                      'Antrenör ya da sporcu isen', 'Belgeni yükle, onaylanınca yetkilerin açılır'),
                  _infoRow(isDark, Icons.family_restroom_rounded,
                      'Veli isen', 'Kulüpten davet kodu iste, çocuğuna bağlan'),
                  _infoRow(isDark, Icons.campaign_rounded, 'Şimdilik',
                      'Kulüp duyurularını takip edebilirsin'),

                  const SizedBox(height: 20),
                  Row(children: [
                    _quick(context, isDark, Icons.verified_user_rounded,
                        'Doğrulama', '/dogrulama'),
                    const SizedBox(width: 10),
                    _quick(context, isDark, Icons.campaign_rounded, 'Duyurular',
                        '/announcements'),
                  ]),
                  // Onaylı sporcu ve kulübü yoksa ferdi sporcu kaydı
                  if (_isApprovedAthlete(creds.valueOrNull) && club == null) ...[
                    const SizedBox(height: 10),
                    _individualCta(context, ref, isDark),
                  ],

                  // Onaylı 2.+ kademe antrenörse kulüp kurabilir.
                  if (_canFoundClub(creds.valueOrNull) && club == null) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      _quick(context, isDark, Icons.add_business_rounded,
                          'Kulüp Oluştur', '/athletes'),
                      const SizedBox(width: 10),
                      const Expanded(child: SizedBox()),
                    ]),
                  ],

                  // Duyurular
                  _label('KULÜP DUYURULARI'),
                  anns.when(
                    loading: () => _mini('Yükleniyor…'),
                    error: (_, __) => _mini('Yüklenemedi'),
                    data: (list) {
                      if (list.isEmpty) return _mini('Duyuru yok');
                      return Column(
                          children: list
                              .take(4)
                              .map((a) =>
                                  _annCard(isDark, a.title, a.body, a.pinned))
                              .toList());
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


  /// Onaylı sporcu kimliği var mı?
  bool _isApprovedAthlete(List<CredentialRow>? creds) {
    if (creds == null) return false;
    return creds.any((c) => !c.isCoach && c.status == 'approved');
  }

  /// Kulüpsüz sporcu için ferdi kayıt oluşturma kartı.
  Widget _individualCta(BuildContext context, WidgetRef ref, bool isDark) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return GestureDetector(
      onTap: () async {
        try {
          await ref
              .read(clubApplicationServiceProvider)
              .createIndividualAthlete();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Ferdi sporcu kaydın oluşturuldu'),
                backgroundColor: kTeal));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Oluşturulamadı: $e'),
                backgroundColor: const Color(0xFFF43F5E)));
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: kTeal.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.directions_run_rounded,
                color: kTeal, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ferdi sporcu kaydını oluştur',
                    style: SwanType.bodySm(ink, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Kulübe bağlı olmadan kendi sporcu profilini aç.',
                    style: SwanType.caption(SwanColors.textSecondary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 20, color: SwanColors.textSecondary),
        ]),
      ),
    );
  }

  /// Kulüp kurma şartı: onaylı, en az 2. kademe antrenör kimliği.
  bool _canFoundClub(List<CredentialRow>? creds) {
    if (creds == null) return false;
    return creds.any((c) =>
        c.isCoach && c.status == 'approved' && (c.coachLevel ?? 0) >= 2);
  }

  Widget _verifyCta(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/dogrulama'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kTealBright, kTeal, kTealDeep],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: kTeal.withValues(alpha: .3),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.verified_user_rounded,
                    color: Colors.white, size: 23),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text('Rolünü doğrula',
                    style: SwanType.h3(Colors.white)),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.white, size: 22),
            ]),
            const SizedBox(height: 12),
            Text(
                'Kademe belgeni veya sporcu lisansını yükle. Platform '
                'yöneticisi onayladığında ilgili tüm modüller açılır.',
                style: SwanType.caption(Colors.white70, w: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(BuildContext context, bool isDark, CredentialRow c) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    final (color, icon) = switch (c.status) {
      'approved' => (const Color(0xFF10B981), Icons.check_circle_rounded),
      'rejected' => (const Color(0xFFF43F5E), Icons.cancel_rounded),
      _ => (const Color(0xFFD9860B), Icons.schedule_rounded),
    };
    final sub = switch (c.status) {
      'approved' =>
        'Onaylandı — kulübe başvurabilir ya da teklif alabilirsin.',
      'rejected' => c.note ?? 'Reddedildi. Belgeni kontrol edip tekrar yükle.',
      _ => 'Platform yöneticisi belgeni inceliyor.',
    };
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/dogrulama'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: .45), width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(c.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.bodySm(ink, w: FontWeight.w800)),
                  ),
                  const SizedBox(width: 8),
                  PremiumStatusChip(
                      label: c.statusLabel, color: color, icon: icon),
                ]),
                const SizedBox(height: 4),
                Text(sub,
                    style: SwanType.caption(SwanColors.textSecondary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoRow(bool isDark, IconData icon, String title, String sub) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line)),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: kTeal.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: kTeal, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: SwanType.bodySm(ink, w: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(sub,
                  style:
                      SwanType.caption(SwanColors.textSecondary)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _quick(BuildContext context, bool isDark, IconData icon, String label,
      String route) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Expanded(
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
          decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: line)),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: kTeal.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(icon, color: kTeal, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.caption(ink, w: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _skeleton(Color surf, Color line) => Container(
        height: 110,
        decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: line),
        ),
        child: const Center(
            child: CircularProgressIndicator(color: kTeal, strokeWidth: 2)),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Text(t,
            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w700)),
      );

  Widget _mini(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(text,
            style: SwanType.caption(SwanColors.textSecondary)),
      );

  Widget _annCard(bool isDark, String title, String body, bool pinned) {
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final line = isDark ? const Color(0xFF233149) : const Color(0xFFEAEEF3);
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: surf,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (pinned) ...[
              const Icon(Icons.push_pin_rounded, size: 14, color: kCoral),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SwanType.bodySm(ink, w: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: SwanType.caption(SwanColors.textSecondary)),
        ],
      ),
    );
  }

}
