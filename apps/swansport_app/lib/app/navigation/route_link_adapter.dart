import 'app_routes.dart';

/// Converts external URLs, custom-scheme links and legacy paths into one
/// canonical in-app location. It does not perform navigation.
abstract final class RouteLinkAdapter {
  static const _webHosts = <String>{
    'swansport.pages.dev',
    'swansport.com.tr',
    'www.swansport.com.tr',
  };

  static final _swanToken = RegExp(r'^[0-9a-fA-F]{48}$');

  static String? fromExternalUri(Uri uri) {
    final Uri target;
    if (uri.scheme == 'swansport') {
      target = _customSchemeTarget(uri);
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        _webHosts.contains(uri.host)) {
      target = _webTarget(uri);
    } else {
      return null;
    }
    return normalizeLocation(target);
  }

  static Uri _customSchemeTarget(Uri uri) => Uri(
        path: '/${[uri.host, ...uri.pathSegments].join('/')}',
        queryParameters:
            uri.queryParameters.isEmpty ? null : uri.queryParameters,
      );

  static Uri _webTarget(Uri uri) {
    if (uri.fragment.isNotEmpty) {
      return Uri.parse(
        uri.fragment.startsWith('/') ? uri.fragment : '/${uri.fragment}',
      );
    }
    return Uri(path: uri.path, queryParameters: uri.queryParameters);
  }

  static String? normalizeLocation(Uri target) {
    final segments = target.pathSegments;
    if (segments.length == 3 &&
        segments[0] == 'swan-id' &&
        segments[1] == 'dogrula' &&
        _swanToken.hasMatch(segments[2])) {
      return AppRoutes.swanIdVerification(segments[2]);
    }

    if (segments.isNotEmpty &&
        (segments.first == 'profil' || segments.first == 'kulup-profil')) {
      if (segments.length > 2) return null;
      final id =
          segments.length == 2 ? segments[1] : target.queryParameters['id'];
      if (id == null || id.isEmpty) return null;
      return Uri(
        path: '/${segments.first}',
        queryParameters: {'id': id},
      ).toString();
    }

    return null;
  }
}
