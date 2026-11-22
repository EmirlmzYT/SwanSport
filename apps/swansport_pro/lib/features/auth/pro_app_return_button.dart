import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

final proAppReturnUriProvider = Provider<Uri>((ref) => Uri.parse(
      kDebugMode ? 'http://127.0.0.1:55430/' : 'https://swansport.pages.dev/',
    ));

final proAppReturnLauncherProvider =
    Provider<Future<bool> Function(Uri)>((ref) => (uri) => launchUrl(
          uri,
          mode: kIsWeb
              ? LaunchMode.platformDefault
              : LaunchMode.externalApplication,
        ));

final class ProAppReturnButton extends ConsumerWidget {
  const ProAppReturnButton({super.key});

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final appUri = ref.read(proAppReturnUriProvider);
    var opened = false;
    try {
      opened = await ref.read(proAppReturnLauncherProvider)(appUri);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'SwanSport App bağlantısı açılamadı. Tarayıcıdan '
            '${appUri.host}${appUri.hasPort ? ':${appUri.port}' : ''} '
            'adresini açabilirsiniz.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => OutlinedButton.icon(
        onPressed: () => _open(context, ref),
        icon: const Icon(Icons.arrow_back_rounded),
        label: const Text('SwanSport App’e dön'),
      );
}
