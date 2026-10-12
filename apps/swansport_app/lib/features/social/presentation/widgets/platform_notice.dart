import 'package:flutter/material.dart';
import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';

class PlatformBroadcastBanner extends StatefulWidget {
  const PlatformBroadcastBanner({super.key, required this.alert});
  final Map<String, dynamic> alert;
  @override
  State<PlatformBroadcastBanner> createState() => _PlatformBroadcastBannerState();
}
class _PlatformBroadcastBannerState extends State<PlatformBroadcastBanner> {
  bool _dismissed = false;
  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final c = context.swan;
    final tone = switch(widget.alert['severity']) {
      'danger' => c.danger, 'warning' => c.warning, _ => c.accent,
    };
    return Semantics(liveRegion: true, child: Container(
      margin: const EdgeInsets.all(SwanSpace.md),
      padding: const EdgeInsets.all(SwanSpace.md),
      decoration: BoxDecoration(color: tone.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(SwanRadius.md)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline_rounded, color: tone),
        const SizedBox(width: SwanSpace.sm),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${widget.alert['title'] ?? 'Platform duyurusu'}', style: SwanType.bodySm(c.ink, w: FontWeight.w800)),
          if ('${widget.alert['message'] ?? ''}'.isNotEmpty)
            Text('${widget.alert['message']}', style: SwanType.bodySm(c.ink)),
        ])),
        IconButton(tooltip: 'Duyuruyu kapat', onPressed: () => setState(() => _dismissed = true),
          icon: Icon(Icons.close_rounded, color: c.inkMuted)),
      ])));
  }
}

class PlatformMaintenanceNotice extends StatelessWidget {
  const PlatformMaintenanceNotice({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Scaffold(backgroundColor: c.bg, body: SafeArea(child: Center(
      child: Padding(padding: const EdgeInsets.all(SwanSpace.xl),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.build_circle_outlined, color: c.accent, size: SwanSpace.xl * 2),
          const SizedBox(height: SwanSpace.lg),
          Text('SwanSport Bakımda', style: SwanType.h2(c.ink), textAlign: TextAlign.center),
          const SizedBox(height: SwanSpace.md),
          Text(message, style: SwanType.body(c.inkMuted), textAlign: TextAlign.center),
          const SizedBox(height: SwanSpace.xl),
          TextButton(onPressed: onRetry, child: Text('Durumu yeniden kontrol et', style: SwanType.bodySm(c.accent))),
        ])))));
  }
}
