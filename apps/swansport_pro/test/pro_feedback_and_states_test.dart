import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_pro/app/pro_theme.dart';
import 'package:swansport_pro/features/operations/pro_feature_host.dart';
import 'package:swansport_pro/features/operations/pro_operations_gate.dart';
import 'package:swansport_pro/widgets/pro_ui_components.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  group('Pro Durum Ekranları ve Geri Bildirim Sözleşmeleri', () {
    testWidgets('ProLoadingState ProTheme renkleriyle iskelet ve spinner sunar',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.dark(),
          home: const Scaffold(
            body: ProLoadingState(message: 'Veriler hazırlanıyor…'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Veriler hazırlanıyor…'), findsOneWidget);
    });

    testWidgets('ProEmptyState operasyonel ikon ve yetkiye bağlı aksiyon sunar',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.dark(),
          home: Scaffold(
            body: Column(
              children: [
                const ProEmptyState(
                  icon: Icons.sports_soccer_rounded,
                  title: 'Atanmış maç yok',
                  subtitle: 'Bu hafta için hakem atamanız bulunmuyor.',
                ),
                ProEmptyState(
                  icon: Icons.fitness_center_rounded,
                  title: 'Antrenman şablonu yok',
                  subtitle: 'Yeni bir şablon oluşturarak başlayabilirsin.',
                  action: FilledButton(
                    onPressed: () {},
                    child: const Text('Şablon Oluştur'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atanmış maç yok'), findsOneWidget);
      expect(find.text('Bu hafta için hakem atamanız bulunmuyor.'),
          findsOneWidget);
      expect(find.text('Antrenman şablonu yok'), findsOneWidget);
      expect(find.text('Şablon Oluştur'), findsOneWidget);
    });

    testWidgets(
        'ProErrorState asla ham exception veya PostgREST hatası sızdırmaz',
        (tester) async {
      final safeMessage = classifyOperationError(
        PostgrestException(
          message: 'permission denied for table match_reports',
          code: '42501',
        ),
      ).userMessage;

      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.dark(),
          home: Scaffold(
            body: ProErrorState(
              message: safeMessage,
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kullanıcı dostu mesaj görüntülenir
      expect(find.text(safeMessage), findsOneWidget);
      // Ham PostgREST veya SQL sızmaz
      expect(find.textContaining('permission denied for table'), findsNothing);
      expect(find.textContaining('42501'), findsNothing);
      expect(find.textContaining('PostgrestException'), findsNothing);

      // Tekrar dene butonu min 48 dokunma alanını korur
      final retryBtn = find.text('Tekrar Dene');
      expect(retryBtn, findsOneWidget);
      final size = tester.getSize(find.ancestor(
        of: retryBtn,
        matching: find.byType(OutlinedButton),
      ));
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('ProUnauthorizedState kilit ikonu ve gerekli rolü gösterir',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.dark(),
          home: Scaffold(
            body: ProUnauthorizedState(
              roleName: 'Kulüp Muhasebecisi',
              onBack: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock_person_outlined), findsOneWidget);
      expect(find.text('Yetkisiz Erişim'), findsOneWidget);
      expect(find.textContaining('Kulüp Muhasebecisi'), findsOneWidget);
      expect(find.text('Geri Dön'), findsOneWidget);
    });

    testWidgets(
        'ProUncertainStateBanner mükerrer tıklamayı önleyen uyarı sunar',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.dark(),
          home: Scaffold(
            body: ProUncertainStateBanner(
              onRetry: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sync_problem_rounded), findsOneWidget);
      expect(find.textContaining('İşlem sonucu doğrulanıyor'), findsOneWidget);
      expect(find.text('Durumu Kontrol Et'), findsOneWidget);
    });

    testWidgets('ProSuccessBanner yeşil onay tonu ile sunulur', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ProTheme.dark(),
          home: const Scaffold(
            body: ProSuccessBanner(message: 'Yoklama başarıyla kaydedildi.'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
      expect(find.text('Yoklama başarıyla kaydedildi.'), findsOneWidget);
    });

    testWidgets(
        'gerçek Pro host başarı ve belirsiz sonuç bileşenlerini kullanır',
        (tester) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            scaffoldMessengerKey: messengerKey,
            theme: ProTheme.dark(),
            home: ProOperationsFeatureHost(
              child: Scaffold(
                body: Builder(
                  builder: (context) => Column(
                    children: [
                      FilledButton(
                        onPressed: () =>
                            ProFeatureHostScope.of(context).chrome.showMessage(
                                  context,
                                  'İşlem tamamlandı.',
                                  tone: ProFeatureMessageTone.success,
                                ),
                        child: const Text('Başarı'),
                      ),
                      FilledButton(
                        onPressed: () =>
                            ProFeatureHostScope.of(context).chrome.showMessage(
                                  context,
                                  'Aynı işlem kimliği korunuyor.',
                                  tone: ProFeatureMessageTone.warning,
                                ),
                        child: const Text('Belirsiz'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Başarı'));
      await tester.pump();
      expect(find.byType(ProSuccessBanner), findsOneWidget);
      messengerKey.currentState!.hideCurrentSnackBar();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Belirsiz'));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(ProUncertainStateBanner), findsOneWidget);
    });

    testWidgets(
        'gerçek Pro host kritik onayda standart tehlike diyaloğunu kullanır',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ProTheme.dark(),
            home: ProOperationsFeatureHost(
              child: Builder(
                builder: (context) => FilledButton(
                  onPressed: () =>
                      ProFeatureHostScope.of(context).chrome.confirm(
                            context,
                            title: 'Kritik işlem',
                            message: 'Bu işlem geri alınamaz.',
                            confirmLabel: 'Onayla',
                          ),
                  child: const Text('Aç'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Aç'));
      await tester.pumpAndSettle();
      expect(find.text('Kritik işlem'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('gerçek operasyon kapısı yetkisiz durumda standart ekranı açar',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            swanAccessProvider.overrideWithValue(SwanAccess.none),
          ],
          child: MaterialApp(
            theme: ProTheme.dark(),
            home: const ProRefereeOperationsGate(child: SizedBox()),
          ),
        ),
      );

      expect(find.byType(ProUnauthorizedState), findsOneWidget);
      expect(find.textContaining('aktif hakem operasyonu'), findsOneWidget);
    });
  });
}
