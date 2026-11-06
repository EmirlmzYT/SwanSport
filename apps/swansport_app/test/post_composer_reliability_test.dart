import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/social/presentation/post_composer_sheet.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets('iki kimlik varsa kişisel başlar ve geçiş taslağı korur',
      (tester) async {
    await _pumpComposer(tester);

    expect(find.text('Deniz Yılmaz'), findsOneWidget);
    expect(find.text('Varsayılan görünürlük'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Taslak metin');
    await tester.tap(find.text('Değiştir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mavişehir Spor Kulübü'));
    await tester.pumpAndSettle();

    expect(find.text('Kulüp gönderisi'), findsOneWidget);
    expect(find.text('Taslak metin'), findsOneWidget);
  });

  testWidgets('sunucu kişisel paylaşımı reddediyorsa yetkili kulübü seçer',
      (tester) async {
    final service = _RecordingSocialService()
      ..allowPersonal = false
      ..allowClub = true;
    await _pumpComposer(tester, social: service);

    expect(find.text('Kulüp gönderisi'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Kulüp duyurusu');
    await tester.pump();
    final shareButton = find.widgetWithText(FilledButton, 'Paylaş');
    expect(tester.widget<FilledButton>(shareButton).onPressed, isNotNull);
    await tester.tap(shareButton);
    await tester.pumpAndSettle();

    expect(service.createCalls, 1);
    expect(service.lastClubId, 'club-1');
  });

  testWidgets('@ ve hashtag geçerli imleç konumuna eklenir', (tester) async {
    await _pumpComposer(tester);
    final field = find.byType(TextField).first;
    await tester.enterText(field, 'Bugün çalıştık');
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.selection = const TextSelection.collapsed(offset: 6);

    await tester.tap(find.byTooltip('Kişi Etiketle'));
    await tester.pump();
    expect(editable.controller.text, 'Bugün @ çalıştık');
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('dolu taslak kapanmadan önce açık onay ister', (tester) async {
    await _pumpComposer(tester);
    await tester.enterText(find.byType(TextField).first, 'Kaybolmasın');
    await tester.tap(find.byTooltip('Gönderi oluşturmayı kapat'));
    await tester.pumpAndSettle();

    expect(find.text('Gönderiden vazgeçilsin mi?'), findsOneWidget);
    await tester.tap(find.text('Düzenlemeye devam et'));
    await tester.pumpAndSettle();
    expect(find.text('Kaybolmasın'), findsOneWidget);
  });

  testWidgets(
      'gönderim kilidi çift gönderimi engeller ve anlık kopyayı kullanır',
      (tester) async {
    final service = _RecordingSocialService()..holdCreate = true;
    await _pumpComposer(tester, social: service);
    await tester.enterText(find.byType(TextField).first, 'İlk metin');

    await tester.tap(find.text('Paylaş'));
    await tester.pump();
    await tester.tap(find.text('Paylaş'));
    expect(service.createCalls, 1);
    expect(service.lastBody, 'İlk metin');
    service.completeCreate();
    await tester.pumpAndSettle();
    expect(service.createCalls, 1);
  });

  testWidgets('etiket kısmi başarısında gönderi çoğaltılamaz ve uyarı kalır',
      (tester) async {
    final social = _RecordingSocialService();
    final shares = _FailingTagService();
    await _pumpComposer(tester, social: social, shares: shares);
    await tester.enterText(find.byType(TextField).first, 'Bugün #kamp');
    await tester.pump();
    await tester.tap(find.text('Paylaş'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(social.createCalls, 1);
    expect(shares.calls, 1);
    expect(find.text('Gönderi paylaşıldı'), findsOneWidget);
    expect(
        find.text('Gönderi paylaşıldı, etiketler eklenemedi.'), findsOneWidget);
    expect(social.createCalls, 1);
  });

  testWidgets('fotoğraflar erişilebilir kontrollerle yeniden sıralanır',
      (tester) async {
    final first = PickedMedia(bytes: Uint8List.fromList([1]), name: 'ilk.jpg');
    final second = PickedMedia(bytes: Uint8List.fromList([2]), name: 'son.jpg');
    await _pumpComposer(tester, initialMedia: [first, second]);

    final before = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as MemoryImage).bytes.first)
        .toList();
    expect(before, [1, 2]);
    await tester.tap(find.byTooltip('Fotoğrafı arkaya taşı').first);
    await tester.pump();
    final after = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => (image.image as MemoryImage).bytes.first)
        .toList();
    expect(after, [2, 1]);
  });

  testWidgets('sekiz fotoğrafta sınır görünür ve seçici kapanır',
      (tester) async {
    final media = List.generate(
      8,
      (index) => PickedMedia(
        bytes: Uint8List.fromList([index + 1]),
        name: '$index.jpg',
      ),
    );
    await _pumpComposer(tester, initialMedia: media);

    expect(find.text('8/8'), findsOneWidget);
    final photoButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Fotoğraf'),
    );
    expect(photoButton.onPressed, isNull);
  });

  testWidgets('gönderim hatasında düzenlenebilir taslak korunur',
      (tester) async {
    final service = _RecordingSocialService()..failCreate = true;
    await _pumpComposer(tester, social: service);
    await tester.enterText(
        find.byType(TextField).first, 'Tekrar denenecek metin');
    await tester.pump();
    await tester.tap(find.text('Paylaş'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tekrar denenecek metin'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('network failure'), findsNothing);
    expect(find.text('Paylaş'), findsOneWidget);
  });
}

Future<void> _pumpComposer(
  WidgetTester tester, {
  _RecordingSocialService? social,
  SocialShareService? shares,
  List<PickedMedia> initialMedia = const [],
}) async {
  final service = social ?? _RecordingSocialService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        socialServiceProvider.overrideWithValue(service),
        socialShareServiceProvider.overrideWithValue(
          shares ?? _RecordingTagService(),
        ),
        currentProfileProvider.overrideWith(
          (_) async =>
              const ProfileInfo(id: 'profile-1', fullName: 'Deniz Yılmaz'),
        ),
        activeClubProvider.overrideWith(
          (_) async => const ClubRef(
            id: 'club-1',
            name: 'Mavişehir Spor Kulübü',
            role: 'coach',
          ),
        ),
        myCredentialsProvider.overrideWith(
          (_) async => const [
            CredentialRow(
              id: 'credential-1',
              kind: 'coach',
              status: 'approved',
            ),
          ],
        ),
        swanAccessProvider.overrideWithValue(
          const SwanAccess(
            isPlatformAdmin: false,
            clubRole: 'coach',
            coachLevel: 1,
            athleteKind: null,
          ),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showModalBottomSheet<bool>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  isDismissible: false,
                  enableDrag: false,
                  builder: (_) => PostComposerSheet(initialMedia: initialMedia),
                ),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Aç'));
  await tester.pumpAndSettle();
}

SupabaseClient _client() => SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

class _RecordingSocialService extends SocialService {
  _RecordingSocialService() : super(_client());

  int createCalls = 0;
  String? lastBody;
  String? lastClubId;
  bool holdCreate = false;
  bool failCreate = false;
  Completer<String>? _pending;
  bool allowPersonal = true;
  bool allowClub = true;

  @override
  Future<bool> canCreatePost({String? clubId}) async =>
      clubId == null ? allowPersonal : allowClub;

  @override
  Future<String> createPost({
    required String body,
    String? clubId,
    Uint8List? imageBytes,
    String? imageName,
    String kind = 'post',
    List<PickedMedia> images = const [],
    String? visibility,
    String? teamId,
  }) {
    createCalls++;
    lastBody = body;
    lastClubId = clubId;
    if (failCreate) return Future.error(StateError('network failure'));
    if (!holdCreate) return Future.value('post-1');
    _pending = Completer<String>();
    return _pending!.future;
  }

  void completeCreate() => _pending?.complete('post-1');
}

class _RecordingTagService extends SocialShareService {
  _RecordingTagService() : super(_client());

  @override
  Future<int> setTags(
    String postId, {
    List<String> mentions = const [],
    List<String> hashtags = const [],
  }) async =>
      mentions.length;
}

class _FailingTagService extends SocialShareService {
  _FailingTagService() : super(_client());

  int calls = 0;

  @override
  Future<int> setTags(
    String postId, {
    List<String> mentions = const [],
    List<String> hashtags = const [],
  }) {
    calls++;
    return Future<int>.error(StateError('tag failure'));
  }
}
