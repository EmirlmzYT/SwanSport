import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../design/swan_palette.dart';
import '../design/swan_shape.dart';
import '../design/swan_type.dart';

RouteFactory guardAccountRoutes(RouteFactory generate) => (settings) {
      final route = generate(settings);
      if (route is MaterialPageRoute<dynamic> &&
          !SwanAccess.isGuestRoute(settings.name)) {
        return MaterialPageRoute<dynamic>(
          settings: settings,
          builder: (_) => AccountRouteGate(builder: route.builder),
        );
      }
      return route;
    };

/// UI for the decision owned by SwanAccess. Never performs a protected write.
Future<bool> requireSwanAction(
  BuildContext context,
  WidgetRef ref,
  SwanAction action,
) async {
  final decision = ref.read(swanAccessProvider).decisionFor(action);
  if (decision == SwanActionDecision.allowed) return true;
  final identity = decision == SwanActionDecision.identityRequired;
  final route = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final c = context.swan;
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SwanSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(identity ? 'Kimlik ve lisans doğrulaması' : 'Hesap gerekli',
                  style: SwanType.h3(c.ink)),
              const SizedBox(height: SwanSpace.md),
              Text(
                identity
                    ? 'Resmi kulüp kadrosuna katılmak için kimlik/lisans doğrulamanız gerekmektedir'
                    : 'Bu özelliği kullanabilmek için hesap açmalısınız',
                style: SwanType.bodySm(c.inkMuted),
              ),
              const SizedBox(height: SwanSpace.xl),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, identity ? '/dogrulama' : '/auth'),
                child: Text(identity
                    ? 'Kimlik ve belge yükle'
                    : 'Giriş Yap / Kayıt Ol'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Gezintiye devam et'),
              ),
            ],
          ),
        ),
      );
    },
  );
  if (route != null && context.mounted) {
    await Navigator.pushNamed(context, route);
  }
  // Returning from authentication never silently repeats the original action.
  return false;
}

/// Protects private deep links before constructing their providers or screen.
class AccountRouteGate extends ConsumerWidget {
  const AccountRouteGate({required this.builder, super.key});
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(swanAccessProvider).hasAccount) return builder(context);
    final c = context.swan;
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap gerekli')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(SwanSpace.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Bu özelliği kullanabilmek için hesap açmalısınız',
                  style: SwanType.bodySm(c.ink)),
              const SizedBox(height: SwanSpace.lg),
              FilledButton(
                onPressed: () =>
                    requireSwanAction(context, ref, SwanAction.publish),
                child: const Text('Giriş Yap / Kayıt Ol'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/kesfet'),
                child: const Text('Misafir olarak keşfet'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
