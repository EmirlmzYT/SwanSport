import 'package:flutter/material.dart';

import '../design/swan_brand.dart';
import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';
import '../../features/social/presentation/widgets/social_widgets.dart';

/// Kapak + marka bandı + avatar.
///
/// **Kişi ve kulüp aynı bileşeni kullanıyor.** İki kopya yazmak, birinde
/// kontrastı düzeltip diğerini unutmak demekti — bu depoda sekme çubuğu tam
/// olarak böyle dört kez kopyalandı.
///
/// Marka rengi burada yalnızca **kimlik** taşıyor: bandın zemini ve ince
/// şerit. Düğmeler, aktif sekmeler ve bağlantılar teal kalıyor (`accent`),
/// çünkü teal bu uygulamada "birincil aksiyon" anlamına geliyor.
class IdentityHeader extends StatelessWidget {
  const IdentityHeader({
    super.key,
    required this.name,
    required this.initials,
    this.coverUrl,
    this.avatarUrl,
    this.brandColor,
    this.avatarTint = 0,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  final String name;
  final String initials;
  final String? coverUrl;
  final String? avatarUrl;

  /// `#RRGGBB` ya da null. Null ise temanın accent'ine düşülüyor.
  final String? brandColor;

  /// Avatar arka plan gradyanı. Çağıran `avatarTint ?? name.length % 4`
  /// hesabını yapıp buraya geçiyor — eski davranış korunuyor.
  final int avatarTint;

  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  static const double _coverHeight = 132;
  static const double _avatarSize = 82;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final tone = BrandTone.from(brandColor, c);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          // Avatar bandın alt kenarından taşıyor; yığının yüksekliği
          // kapak + taşan yarım avatar.
          height: _coverHeight + _avatarSize / 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _cover(context, tone),
              Positioned(
                left: SwanSpace.lg,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    // Avatarın etrafındaki halka sayfa zemininde: kapak
                    // görseli koyu da olsa açık da olsa avatar ayrışıyor.
                    color: c.bg,
                    borderRadius: BorderRadius.circular(SwanRadius.md + 3),
                  ),
                  child: SocialAvatar(
                    initials: initials,
                    imageUrl: avatarUrl,
                    size: _avatarSize,
                    radius: SwanRadius.md,
                    gradientIndex: avatarTint,
                  ),
                ),
              ),
              if (onBack != null)
                Positioned(
                  left: SwanSpace.lg,
                  top: SwanSpace.md,
                  child: _circleButton(
                      context, Icons.arrow_back_ios_new_rounded, onBack!),
                ),
              if (trailing != null)
                Positioned(
                  right: SwanSpace.lg,
                  top: SwanSpace.md,
                  child: trailing!,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cover(BuildContext context, BrandTone tone) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: _coverHeight,
      // Profil listesi 20px iç boşluklu; kapak kenardan kenara gitmiyor.
      // Köşeleri yuvarlatmak bunu kasıtlı bir kart yapıyor — düz bırakmak
      // kırık bir tam genişlik denemesi gibi görünüyordu.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(SwanRadius.md),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl != null)
              Image.network(
                coverUrl!,
                fit: BoxFit.cover,
                // Görsel yüklenemezse marka bandına düşüyor — kırık ikon
                // göstermek profil sayfasını bozuk gösterirdi.
                errorBuilder: (_, __, ___) => ColoredBox(color: tone.base),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : ColoredBox(color: tone.soft),
              )
            else
              // Kapak yoksa marka rengi tek başına band oluyor. Rengi de yoksa
              // accent'e düşüyor ve uygulamanın kendi kimliğiyle görünüyor.
              ColoredBox(color: tone.base),

            // Kapak görseli üstündeyken alt kenarda okunabilirlik için koyu
            // geçiş: avatarın halkası ve ad her zeminde ayrışsın.
            if (coverUrl != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.35),
                    ],
                  ),
                ),
              ),

            // Kimlik şeridi — kapak varken markanın tek görünür izi.
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(height: 3, color: tone.stripe),
            ),

            // Kapak yokken adı bandın üstüne yazıyoruz; yazı rengi ölçülerek
            // seçiliyor, tahmin edilmiyor.
            if (coverUrl == null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    SwanSpace.lg, 0, SwanSpace.lg, SwanSpace.lg + 24),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: SwanType.h3(tone.ink),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(
      BuildContext context, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          // Kapak görseli her renk olabilir; yarı saydam koyu zemin ikonu
          // her durumda okunur tutuyor.
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(SwanRadius.sm),
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 15, color: Colors.white),
      ),
    );
  }
}

/// Marka renginde küçük rozet — kulüp/kişi etiketleri için.
class BrandChip extends StatelessWidget {
  const BrandChip({
    super.key,
    required this.label,
    this.brandColor,
    this.icon,
  });

  final String label;
  final String? brandColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = BrandTone.from(brandColor, context.swan);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        // Yumuşak dolgu sayfa zemininin üstünde; yazı marka renginin kendisi.
        // Dolu marka rengi kullansaydık akışta beş kulübün rengi yan yana
        // gelince gürültü olurdu.
        color: tone.soft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: tone.base),
          const SizedBox(width: 4),
        ],
        Text(label, style: SwanType.caption(tone.base, w: FontWeight.w700)),
      ]),
    );
  }
}
