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
  final route = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        SwanActionGateBottomSheet(decision: decision, action: action),
  );
  if (route != null && context.mounted) {
    await Navigator.pushNamed(context, route);
  }
  // Returning from authentication never silently repeats the original action.
  return false;
}

/// Shared account/identity/phone explanation for a protected action.
class SwanActionGateBottomSheet extends StatelessWidget {
  const SwanActionGateBottomSheet(
      {required this.decision, required this.action, super.key});
  final SwanActionDecision decision;
  final SwanAction action;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    final identity = decision == SwanActionDecision.identityRequired;
    final phone = decision == SwanActionDecision.phoneRequired;
    final venue = action == SwanAction.reservation ||
        action == SwanAction.partner ||
        action == SwanAction.courtCheckIn;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(SwanSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
                identity
                    ? 'Kimlik ve lisans doğrulaması'
                    : phone
                        ? 'Telefon doğrulaması'
                        : 'Hesap gerekli',
                style: SwanType.h3(c.ink)),
            const SizedBox(height: SwanSpace.md),
            Text(
                identity
                    ? 'Resmi kulüp kadrosuna katılmak için kimlik/lisans doğrulamanız gerekmektedir'
                    : phone
                        ? 'Tesis güvenliği ve sahte rezervasyonları önlemek için telefon numarası doğrulaması gerekmektedir.'
                        : venue
                            ? 'Tesis rezervasyonu ve partner iletişimi için SwanSport hesabı gereklidir.'
                            : 'Bu özelliği kullanabilmek için hesap açmalısınız',
                style: SwanType.bodySm(c.inkMuted)),
            const SizedBox(height: SwanSpace.xl),
            FilledButton(
              onPressed: () => Navigator.pop(
                  context, identity || phone ? '/dogrulama' : '/auth'),
              child: Text(identity
                  ? 'Kimlik ve belge yükle'
                  : phone
                      ? 'Telefonumu doğrula'
                      : 'Giriş Yap / Kayıt Ol'),
            ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Gezintiye devam et')),
          ],
        ),
      ),
    );
  }
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

/// Veritabanı ve yetki kuralı istisnalarından gelen teknik metinleri
/// kullanıcıya anlaşılır şekilde temizler.
String cleanPostgresMessage(Object error) {
  final raw = error.toString();
  final match = RegExp(
    r'PostgrestException\(message:\s*(.*?),\s*code:',
    caseSensitive: false,
    dotAll: true,
  ).firstMatch(raw);
  var msg = match?.group(1)?.trim() ?? raw;
  if (msg.startsWith('Exception: ')) {
    msg = msg.substring('Exception: '.length).trim();
  }
  if (msg.contains('PostgrestException(') ||
      RegExp(r'\b(code|details|hint):', caseSensitive: false).hasMatch(msg)) {
    return 'İşlem tamamlanamadı. Lütfen tekrar deneyin.';
  }
  return msg;
}

/// Doğrulanmış hesap veya belge gerektiren kural kısıtlamalarını temsil eder.
class VerificationRequirement {
  const VerificationRequirement({
    required this.title,
    required this.description,
    required this.targetMode, // 0: Antrenör, 1: Sporcu, 2: Kimlik
    required this.actionLabel,
    this.targetRoute = '/dogrulama',
  });

  final String title;
  final String description;
  final int targetMode;
  final String actionLabel;
  final String targetRoute;

  /// Hata metninden veya istisnadan doğrulanmış hesap kısıtını tespit eder.
  static VerificationRequirement? detect(Object error) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('veli için doğrulanmış kimlik') ||
        raw.contains('veli için') ||
        raw.contains('davet bağı')) {
      return const VerificationRequirement(
        title: 'Veli Doğrulaması Gerekli',
        description:
            'Sporcu adına işlem yapabilmek için doğrulanmış veli hesabınız ve geçerli sporcu bağlantınızın bulunması gerekir.',
        targetMode: 2,
        actionLabel: 'Veli Bağlantısını Tamamla',
        targetRoute: '/veli-bagla',
      );
    }
    if (raw.contains('en az 2. kademe') ||
        raw.contains('en az ikinci kademe') ||
        raw.contains('ikinci kademe belge') ||
        raw.contains('antrenör belgesi') ||
        raw.contains('antrenör kademesi')) {
      return const VerificationRequirement(
        title: 'Antrenör Belgesi Gerekli',
        description:
            'Kulüp kurabilmek ve kadro yönetebilmek için federasyon onaylı en az 2. kademe antrenör belgenizin doğrulanmış olması gerekir.',
        targetMode: 0,
        actionLabel: 'Antrenör Belgesi Yükle',
      );
    }
    if (raw.contains('doğrulanmış kimlik') ||
        raw.contains('dogrulanmis kimlik') ||
        raw.contains('bekleme odasında') ||
        raw.contains('bekleme odasinda') ||
        raw.contains('kimlik gerekli') ||
        raw.contains('hesap bekleme')) {
      return const VerificationRequirement(
        title: 'Doğrulanmış Hesap Gerekli',
        description:
            'Bu işlemi gerçekleştirebilmek için T.C. Kimlik doğrulaması yapmanız ve hesabınızın onaylanmış olması gerekmektedir.',
        targetMode: 2,
        actionLabel: 'Kimlik Doğrulamaya Git',
      );
    }
    if (raw.contains('hesapsız sporcu için branş lisans')) {
      return const VerificationRequirement(
        title: 'Lisans Kaydı Gerekli',
        description:
            'Sporcunun kulüp kadrosuna dahil edilebilmesi için geçerli branş lisans kaydı gerekmektedir.',
        targetMode: 1,
        actionLabel: 'Lisans Bilgilerini Gör',
      );
    }
    return null;
  }
}

/// Yönlendirmeli doğrulanmış hesap uyarı modalını açar.
Future<void> showVerificationRequiredSheet(
  BuildContext context, {
  VerificationRequirement? requirement,
  String? title,
  String? description,
  int targetMode = 2,
  String? actionLabel,
}) {
  final req = requirement ??
      VerificationRequirement(
        title: title ?? 'Doğrulanmış Hesap Gerekli',
        description: description ??
            'Bu işlemi gerçekleştirebilmek için doğrulanmış kimlik veya lisans belgesi gerekmektedir.',
        targetMode: targetMode,
        actionLabel: actionLabel ?? 'Doğrulamaya Git',
      );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => VerificationRequiredBottomSheet(requirement: req),
  );
}

/// Yönlendirmeli şık doğrulanmış hesap bottom sheet'i.
class VerificationRequiredBottomSheet extends StatelessWidget {
  const VerificationRequiredBottomSheet({
    required this.requirement,
    super.key,
  });

  final VerificationRequirement requirement;

  @override
  Widget build(BuildContext context) {
    final c = context.swan;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SwanRadius.lg),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        SwanSpace.lg,
        SwanSpace.md,
        SwanSpace.lg,
        SwanSpace.xl,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: c.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: SwanSpace.lg),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.verified_user_rounded,
                  color: c.warning,
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: SwanSpace.md),
            Text(
              requirement.title,
              textAlign: TextAlign.center,
              style: SwanType.h2(c.ink),
            ),
            const SizedBox(height: SwanSpace.sm),
            Text(
              requirement.description,
              textAlign: TextAlign.center,
              style: SwanType.bodySm(c.inkMuted),
            ),
            const SizedBox(height: SwanSpace.xl),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    requirement.targetRoute,
                    arguments: requirement.targetMode,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.accentFill,
                  foregroundColor: c.onAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SwanRadius.md),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(
                  requirement.actionLabel,
                  style: SwanType.bodySm(c.onAccent, w: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: SwanSpace.xs),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Daha Sonra',
                style: SwanType.caption(c.inkMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
