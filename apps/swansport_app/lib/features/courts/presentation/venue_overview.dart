import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';

/// Public facility facts; neither account nor device location is required.
class VenueOverview extends StatelessWidget {
  const VenueOverview(
      {required this.where,
      this.surfaceType,
      this.photoUrls = const [],
      this.lat,
      this.lng,
      super.key});
  final String where;
  final String? surfaceType;
  final List<String> photoUrls;
  final double? lat, lng;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (where.isNotEmpty) Text(where, style: SwanType.bodySm(c.inkMuted)),
      if (surfaceType != null && surfaceType!.trim().isNotEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: SwanSpace.sm),
            child: Text('Zemin: $surfaceType', style: SwanType.bodySm(c.ink))),
      if (photoUrls.isNotEmpty) ...[
        AspectRatio(
          aspectRatio: 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SwanRadius.md),
            child: PageView(children: [
              for (final url in photoUrls)
                Image.network(url,
                    fit: BoxFit.cover,
                    semanticLabel: 'Tesis fotoğrafı',
                    errorBuilder: (_, __, ___) => Center(
                        child: Text('Fotoğraf yüklenemedi',
                            style: SwanType.caption(c.inkMuted)))),
            ]),
          ),
        ),
        const SizedBox(height: SwanSpace.sm),
        Text('${photoUrls.length} tesis fotoğrafı · kaydırarak incele',
            style: SwanType.caption(c.inkMuted)),
      ],
      if (lat != null && lng != null && lat!.isFinite && lng!.isFinite)
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: const Text('Haritada göster'),
              onPressed: () async {
                final url = Uri.https('www.google.com', '/maps/search/',
                    {'api': '1', 'query': '$lat,$lng'});
                try {
                  if (!await launchUrl(url,
                      mode: LaunchMode.externalApplication))
                    throw StateError('Harita açılamadı');
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Harita açılamadı. Yeniden dene.')));
                }
              },
            )),
      const SizedBox(height: SwanSpace.md),
    ]);
  }
}
