import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_data/swansport_data.dart';

/// Fallback route when a notification cannot be routed to a specific operational screen.
const String proFallbackRoute = '/gelen-kutusu';

const _staticProRoutes = <String>{
  '/panel',
  '/gorevler',
  '/takvim',
  '/gelen-kutusu',
  '/hesap',
  '/operasyon/yoklama',
  '/operasyon/antrenmanlar',
  '/operasyon/federasyon-maclar',
  '/operasyon/hakem-gorevleri',
  '/operasyon/muhasebe',
  '/operasyon/tesis-gorevleri',
  '/operasyon/platform',
};

/// Accepts only known in-app paths from a native push payload.
String resolveProPushUrl(String? rawUrl) {
  if (rawUrl == null) return proFallbackRoute;
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment) {
    return proFallbackRoute;
  }
  final path = uri.path;
  if (_staticProRoutes.contains(path)) return path;
  final segments = uri.pathSegments;
  if (segments.length == 3 &&
      segments[0] == 'operasyon' &&
      const {'hakem-canli', 'hakem-esame', 'hakem-rapor'}
          .contains(segments[1]) &&
      isPublicMatchId(segments[2])) {
    return '/operasyon/${segments[1]}/${segments[2]}';
  }
  return proFallbackRoute;
}

/// Resolves a notification kind and payload into a validated typed Pro route.
///
/// Guaranteed to never throw; returns [proFallbackRoute] for any unmapped,
/// invalid, or unsupported payload.
String resolveProNotificationRoute({
  required String kind,
  String? entityType,
  String? entityId,
}) {
  final cleanKind = kind.trim().toLowerCase();

  switch (cleanKind) {
    case 'referee_assignment':
      return '/operasyon/hakem-gorevleri';

    case 'attendance':
    case 'attendance_reminder':
      return '/operasyon/yoklama';

    case 'training_session':
    case 'training_result':
      return '/operasyon/antrenmanlar';

    case 'expense_approval':
    case 'expense_rejected':
    case 'commitment_due':
    case 'account_negative':
    case 'bank_unmatched':
    case 'period_closed':
    case 'period_blocked':
    case 'fee':
    case 'fee_reminder':
    case 'payment':
    case 'donation':
      return '/operasyon/muhasebe';

    case 'turf_slot_request':
    case 'turf_field':
    case 'turf_manager':
    case 'court_waitlist':
    case 'turf_delegation':
      return '/operasyon/tesis-gorevleri';

    case 'match_live':
      if (entityType == 'match' &&
          entityId != null &&
          isPublicMatchId(entityId)) {
        return '/operasyon/hakem-canli/$entityId';
      }
      return '/operasyon/federasyon-maclar';

    case 'match_result':
      return '/operasyon/federasyon-maclar';

    case 'store_decision':
    case 'moderation':
      return '/operasyon/platform';

    default:
      return proFallbackRoute;
  }
}

/// Helper to handle navigating to a notification's target in Pro.
void handleProNotificationTap(BuildContext context, NotificationRow item) {
  final route = resolveProNotificationRoute(
    kind: item.kind,
    entityType: item.entityType,
    entityId: item.entityId,
  );
  try {
    context.push(route);
  } catch (e) {
    // If navigation fails, fallback to inbox safely
    try {
      context.go(proFallbackRoute);
    } catch (_) {}
  }
}
