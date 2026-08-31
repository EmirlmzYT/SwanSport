import 'package:flutter/material.dart';
import 'package:swansport_design_system/swansport_design_system.dart';

import '../../../../app/widgets/premium.dart';
import '../../../../app/design/swan_type.dart';

/// Ağdan yüklenen avatar; görsel yoksa baş harflerle degrade avatara düşer.
class SocialAvatar extends StatelessWidget {
  const SocialAvatar({
    super.key,
    required this.initials,
    this.imageUrl,
    this.size = 42,
    this.radius,
    this.gradientIndex = 0,
  });

  final String initials;
  final String? imageUrl;
  final double size;
  final double? radius;
  final int gradientIndex;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? size * 0.32;
    if (imageUrl == null || imageUrl!.isEmpty) {
      return GradientAvatar(
        initials: initials,
        size: size,
        radius: r,
        gradientIndex: gradientIndex,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(r),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => GradientAvatar(
          initials: initials,
          size: size,
          radius: r,
          gradientIndex: gradientIndex,
        ),
      ),
    );
  }
}

/// Akıştaki görsellerin oran sınırları.
///
/// Fotoğraf kendi oranını korur ama bu aralığa sıkıştırılır: çok uzun dikey
/// görseller akışı ele geçirmez, çok geniş panoramalar da şerit gibi kalmaz.
/// (Instagram'ın yaklaşımı: 4:5 dikey ↔ 1.91:1 yatay.)
const double kMinPostAspect = 0.8; // 4:5
const double kMaxPostAspect = 1.91; // 1.91:1

/// Görseli kendi en-boy oranıyla, sınırlar içinde gösterir.
///
/// Oran öğrenilene kadar kare bir yer tutucu gösterir; böylece akış yüklenirken
/// zıplamaz.
class RatioImage extends StatefulWidget {
  const RatioImage({
    super.key,
    required this.image,
    this.borderRadius = 14,
    this.background,
  });

  final ImageProvider image;
  final double borderRadius;
  final Color? background;

  @override
  State<RatioImage> createState() => _RatioImageState();
}

class _RatioImageState extends State<RatioImage> {
  double? _ratio;
  bool _failed = false;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant RatioImage old) {
    super.didUpdateWidget(old);
    if (old.image != widget.image) {
      _ratio = null;
      _failed = false;
      _resolve();
    }
  }

  void _resolve() {
    _detach();
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (h <= 0) return;
        setState(() => _ratio = w / h);
      },
      // Çözülemeyen biçimler (ör. HEIC) sonsuz dönen bir gösterge bırakmasın.
      onError: (_, __) {
        if (!mounted) return;
        setState(() => _failed = true);
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  void _detach() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholder = widget.background ??
        (isDark ? const Color(0xFF1A2537) : const Color(0xFFF1F5F8));
    final ratio = (_ratio ?? 1).clamp(kMinPostAspect, kMaxPostAspect);

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: AspectRatio(
        aspectRatio: ratio,
        child: Container(
          color: placeholder,
          child: _failed
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported_rounded,
                          color: SwanColors.textSecondary, size: 26),
                      const SizedBox(height: 6),
                      Text('Görsel gösterilemiyor',
                          style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
                    ],
                  ),
                )
              : _ratio == null
              ? const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kTeal),
                  ),
                )
              : Image(
                  image: widget.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Icon(Icons.broken_image_rounded,
                        color: SwanColors.textSecondary, size: 26),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Doğrulanmış hesap rozeti.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 14});
  final double size;

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.verified_rounded, size: size, color: kTeal);
}

/// "2 dk", "3 sa", "5 g" gibi kısa göreli zaman.
String shortAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'şimdi';
  if (d.inMinutes < 60) return '${d.inMinutes} dk';
  if (d.inHours < 24) return '${d.inHours} sa';
  if (d.inDays < 7) return '${d.inDays} g';
  if (d.inDays < 30) return '${(d.inDays / 7).floor()} hf';
  if (d.inDays < 365) return '${(d.inDays / 30).floor()} ay';
  return '${(d.inDays / 365).floor()} y';
}

/// Sayıyı kısalt: 1200 → 1,2B
String compactCount(int n) {
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final v = n / 1000;
    return '${v.toStringAsFixed(v < 10 ? 1 : 0).replaceAll('.', ',')}B';
  }
  final v = n / 1000000;
  return '${v.toStringAsFixed(v < 10 ? 1 : 0).replaceAll('.', ',')}M';
}

/// Profil/akış üstünde kullanılan sayaç bloğu.
class SocialStat extends StatelessWidget {
  const SocialStat({super.key, required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? Colors.white : SwanColors.textPrimary;
    return Column(
      children: [
        Text(compactCount(value), style: SwanType.h3(ink)),
        const SizedBox(height: 2),
        Text(label,
            style: SwanType.caption(SwanColors.textSecondary, w: FontWeight.w600)),
      ],
    );
  }
}
