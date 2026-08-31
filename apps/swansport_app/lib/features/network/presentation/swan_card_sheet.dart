import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../app/widgets/premium.dart';
import '../../social/presentation/widgets/social_widgets.dart';
import '../../../app/design/swan_type.dart';

/// SwanSport Kartı — paylaşılabilir QR kimlik.
///
/// QR yalnızca **herkese açık profil bağlantısını** taşır. Kulüp içi veriler
/// (aidat, sağlık, yoklama) QR üzerinden erişilemez; bağlantıyı açan kişi
/// zaten profil sayfasında ne görebiliyorsa onu görür.
Future<void> showSwanCard(
  BuildContext context, {
  required String id,
  required String name,
  required bool isClub,
  String? subtitle,
  String? avatarUrl,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _SwanCard(
      id: id,
      name: name,
      isClub: isClub,
      subtitle: subtitle,
      avatarUrl: avatarUrl,
    ),
  );
}

class _SwanCard extends ConsumerWidget {
  const _SwanCard({
    required this.id,
    required this.name,
    required this.isClub,
    this.subtitle,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final bool isClub;
  final String? subtitle;
  final String? avatarUrl;

  /// Kart, uygulamanın herkese açık adresine götürür.
  String get _link =>
      'https://swansport.pages.dev/#/${isClub ? "kulup-profil" : "profil"}/$id';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surf = isDark ? const Color(0xFF131D2E) : Colors.white;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: surf,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
          22, 20, 22, 24 + MediaQuery.of(context).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('SwanSport Kartı', style: SwanType.h3(ink)),
        const SizedBox(height: 16),

        // Kartın kendisi — koyu zemin, teal çerçeve; okutulduğunda tanınsın.
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kTealDeep, Color(0xFF0A111E)],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(children: [
            Row(children: [
              SocialAvatar(
                initials: name.isEmpty ? '?' : name[0].toUpperCase(),
                imageUrl: avatarUrl,
                size: 44,
                radius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: SwanType.h3(Colors.white)),
                    if ((subtitle ?? '').isNotEmpty)
                      Text(subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SwanType.caption(Colors.white.withValues(alpha: .75), w: FontWeight.w600)),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: _link,
                size: 168,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF04464B),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF0A111E),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text('SwanSport',
                style: SwanType.caption(
                    Colors.white.withValues(alpha: .6),
                    w: FontWeight.w800)),
          ]),
        ),

        const SizedBox(height: 14),
        Text('Okutan kişi yalnızca herkese açık profilini görür.',
            textAlign: TextAlign.center,
            style: SwanType.caption(SwanColors.textSecondary)),
        const SizedBox(height: 16),

        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _link));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Bağlantı kopyalandı'), backgroundColor: kTeal));
          },
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kTealBright, kTeal]),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text('Bağlantıyı kopyala',
                style: SwanType.bodySm(Colors.white, w: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }
}
