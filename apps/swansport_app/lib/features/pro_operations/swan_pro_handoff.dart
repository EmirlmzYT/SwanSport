import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/design/swan_palette.dart';
import '../../app/design/swan_shape.dart';
import '../../app/design/swan_type.dart';

const swanSportProScheme = 'swansportpro';
const swanSportProHost = 'app';

typedef SwanSportProLauncher = Future<bool> Function(Uri uri);

Uri swanSportProUri(String route) {
  final normalized = route.startsWith('/') ? route : '/$route';
  final routeUri = Uri.parse(normalized);
  return Uri(
    scheme: swanSportProScheme,
    host: swanSportProHost,
    path: routeUri.path,
    queryParameters:
        routeUri.queryParameters.isEmpty ? null : routeUri.queryParameters,
  );
}

Future<bool> launchSwanSportPro(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Keeps the social app focused on lightweight context while handing detailed
/// professional work to the independently installed SwanSport Pro client.
class SwanProHandoffCard extends StatelessWidget {
  const SwanProHandoffCard({
    required this.route,
    required this.title,
    required this.subtitle,
    this.launcher = launchSwanSportPro,
    super.key,
  });

  final String route;
  final String title;
  final String subtitle;
  final SwanSportProLauncher launcher;

  Future<void> _open(BuildContext context) async {
    final opened = await launcher(swanSportProUri(route));
    if (!context.mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'SwanSport Pro açılamadı. Uygulamanın bu cihazda yüklü olduğundan emin ol.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;

    return Semantics(
      button: true,
      label: '$title. $subtitle. SwanSport Pro’da aç',
      child: Material(
        color: palette.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(SwanRadius.lg),
          onTap: () => _open(context),
          child: Container(
            padding: const EdgeInsets.all(SwanSpace.lg),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SwanRadius.lg),
              border: Border.all(color: palette.line),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: palette.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(SwanRadius.md),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_outlined,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(width: SwanSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title, style: SwanType.body(palette.ink)),
                        const SizedBox(height: SwanSpace.xs),
                        Text(
                          subtitle,
                          style: SwanType.bodySm(palette.inkMuted),
                        ),
                        const SizedBox(height: SwanSpace.sm),
                        Text(
                          'SwanSport Pro’da aç',
                          style: SwanType.bodySm(
                            palette.accent,
                            w: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SwanSpace.sm),
                  Icon(
                    Icons.open_in_new_rounded,
                    color: palette.inkMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compatibility destination for legacy social-app routes. The route remains
/// valid, but detailed professional data is rendered only by SwanSport Pro.
class SwanProHandoffPage extends StatelessWidget {
  const SwanProHandoffPage({
    required this.appBarTitle,
    required this.route,
    required this.title,
    required this.subtitle,
    this.launcher = launchSwanSportPro,
    super.key,
  });

  final String appBarTitle;
  final String route;
  final String title;
  final String subtitle;
  final SwanSportProLauncher launcher;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = isDark ? SwanPalette.dark : SwanPalette.light;

    return Scaffold(
      backgroundColor: palette.bg,
      appBar: AppBar(
        backgroundColor: palette.bg,
        foregroundColor: palette.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(appBarTitle, style: SwanType.h3(palette.ink)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SwanSpace.lg),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwanProHandoffCard(
                  route: route,
                  title: title,
                  subtitle: subtitle,
                  launcher: launcher,
                ),
                const SizedBox(height: SwanSpace.md),
                Text(
                  'Aynı SwanSport hesabın ve mevcut yetkilerin kullanılır.',
                  style: SwanType.bodySm(palette.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
