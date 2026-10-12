import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Shared raster/vector loading and error handling; appearance belongs to
/// each consuming app's tokens. Fixed bounds prevent brand layout jumps.
class SwanNetworkLogo extends StatelessWidget {
  const SwanNetworkLogo({super.key, required this.url, required this.size,
    required this.fallback, this.semanticLabel});
  final String? url;
  final double size;
  final Widget fallback;
  final String? semanticLabel;
  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    final uri = Uri.tryParse(value);
    final local = Image.asset('packages/swansport_design_system/assets/images/swan_logo.png',
      fit: BoxFit.contain, semanticLabel: semanticLabel,
      errorBuilder: (_, __, ___) => fallback);
    return SizedBox(width: size, height: size, child:
      uri == null || uri.scheme != 'https' || !uri.hasAuthority ? local :
      uri.path.toLowerCase().endsWith('.svg')
        ? SvgPicture.network(value, fit: BoxFit.contain, semanticsLabel: semanticLabel,
            placeholderBuilder: (_) => local, errorBuilder: (_, __, ___) => local)
        : Image.network(value, fit: BoxFit.contain, semanticLabel: semanticLabel,
            errorBuilder: (_, __, ___) => local));
  }
}
