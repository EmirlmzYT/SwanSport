import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../../../app/design/swan_palette.dart';
import '../../../../app/design/swan_shape.dart';
import '../../../../app/design/swan_type.dart';
import '../../../../app/widgets/quick_actions.dart';

/// Yeni sporcunun ilk ekranı.
///
/// **Neden var:** hiç verisi olmayan bir sporcu ana ekranında yedi bölümün
/// altısında olumsuz cümle görüyor — "Takım yok", "Sağlık kaydı yok",
/// "Belge yüklenmemiş", "Duyuru yok", "Henüz kayıt yok", "Başka etkinlik
/// yok". Bölümlerin her biri kendi başına doğru davranıyor; toplamı yanlış.
/// İlk oturum geri dönülüp dönülmeyeceğini belirliyor ve orada yapılabilecek
/// tek bir şey yazmıyor.
///
/// Bu blok o boşluğu **doldurmuyor**, adlandırıyor: ekranın neyle dolacağını
/// bir cümlede söylüyor ve o an gerçekten yapılabilecek işleri veriyor.
/// Sahte veri ya da "hoş geldin" kutlaması yok — sporcunun antrenmana
/// gitmesi gerekiyor, uygulama bunu taklit edemez.
///
/// Veri geldiği anda kendiliğinden kayboluyor: kapatma düğmesi yok, çünkü
/// kapatılacak bir şey de yok — bir antrenmana katılınca zaten gidiyor.
class GettingStartedCard extends ConsumerWidget {
  const GettingStartedCard({super.key, required this.card});

  /// Sporcunun kartı. `hasData` yanlışsa bu blok çiziliyor — aynı sinyal
  /// "Gelişim" bölümünün de kullandığı sinyal, ikinci bir tanım yazılmadı.
  final AthleteCard? card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Veri varsa hiç çizilmiyor.
    if (card == null || card!.hasData) return const SizedBox.shrink();

    final c = context.swan;
    final training = ref.watch(
        featureEnabledProvider(FeatureFlags.sportTrainingSessions));

    return Container(
      margin: const EdgeInsets.only(bottom: SwanSpace.lg),
      padding: const EdgeInsets.all(SwanSpace.lg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SwanRadius.lg),
        border: Border.all(color: c.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Başlarken', style: SwanType.h3(c.ink)),
        const SizedBox(height: SwanSpace.xs),
        Text(
          card!.clubName == null
              ? 'Bir kulübe katıldığında antrenmanların, katılımın ve '
                  'gelişimin burada birikmeye başlayacak.'
              : 'İlk antrenmanından sonra katılımın, hedeflerin ve '
                  'gelişimin bu ekranda birikmeye başlayacak.',
          style: SwanType.bodySm(c.inkMuted),
        ),
        const SizedBox(height: SwanSpace.lg),
        QuickActions(actions: [
          // Kulübün istediği belgeler; sporcunun hemen yapabileceği tek
          // somut iş genelde bu.
          const QuickAction(
              icon: Icons.folder_rounded,
              label: 'Belgelerim',
              route: '/documents'),
          if (training)
            const QuickAction(
                icon: Icons.sports_rounded,
                label: 'Antrenmanlarım',
                route: '/antrenmanlarim'),
          const QuickAction(
              icon: Icons.verified_user_rounded,
              label: 'Doğrulama',
              route: '/dogrulama'),
        ]),
      ]),
    );
  }
}
