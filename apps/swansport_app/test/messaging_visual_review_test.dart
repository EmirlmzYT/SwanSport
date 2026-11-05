import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/communities/presentation/community_chat_screen.dart';
import 'package:swansport_app/features/social/presentation/messages_screen.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });

  testWidgets('sohbet listesi görsel inceleme fixture', (tester) async {
    final boundary = GlobalKey();
    await _pump(
      tester,
      boundary: boundary,
      child: const MessagesScreen(),
      overrides: [
        isSupabaseEnabledProvider.overrideWithValue(false),
        currentProfileProvider.overrideWith((_) async => null),
        conversationsProvider.overrideWith((_) async => _conversations),
        communityListProvider.overrideWith((_) async => _communities),
      ],
    );
    expect(find.textContaining('Başantrenör Selin'), findsOneWidget);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/messages-list-current.png'),
    );
  });

  testWidgets('birebir sohbet uzun ve paylaşılan içerik görünümü',
      (tester) async {
    final boundary = GlobalKey();
    await _pump(
      tester,
      boundary: boundary,
      child: const ChatScreen(
        otherId: 'coach-1',
        otherName: 'Başantrenör Selin Kaya Çok Uzun Kulüp Görevi',
      ),
      overrides: [
        notificationServiceProvider.overrideWithValue(_MessageService()),
        chatProvider('coach-1').overrideWith(
          (_) => Stream.value(_directMessages),
        ),
        swanAccessProvider.overrideWithValue(SwanAccess.none),
      ],
    );
    expect(find.textContaining('toparlanma programını'), findsOneWidget);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/direct-chat-current.png'),
    );
  });

  testWidgets('grup sohbeti gönderen ve uzun mesaj görünümü', (tester) async {
    final boundary = GlobalKey();
    await _pump(
      tester,
      boundary: boundary,
      child: const CommunityChatScreen(
        communityId: 'team-1',
        title: 'Mavişehir Yüzme Takımı Büyükler A Grubu',
      ),
      overrides: [
        communityServiceProvider.overrideWithValue(_CommunityService()),
        communityMessagesProvider('team-1').overrideWith(
          (_) => Stream.value(_groupMessages),
        ),
        communityMembersProvider('team-1').overrideWith((_) async => _members),
        communityListProvider.overrideWith((_) async => _communities),
        swanAccessProvider.overrideWithValue(SwanAccess.none),
      ],
    );
    expect(find.text('Deniz Yılmaz'), findsOneWidget);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/group-chat-current.png'),
    );
  });

  testWidgets('klavye açık dar ekranda yazma alanı görünür kalır',
      (tester) async {
    final boundary = GlobalKey();
    await _pump(
      tester,
      size: const Size(320, 700),
      textScale: 1.3,
      keyboard: 260,
      boundary: boundary,
      child: const ChatScreen(otherId: 'coach-1', otherName: 'Selin Kaya'),
      overrides: [
        notificationServiceProvider.overrideWithValue(_MessageService()),
        chatProvider('coach-1').overrideWith(
          (_) => Stream.value(_directMessages),
        ),
        swanAccessProvider.overrideWithValue(SwanAccess.none),
      ],
    );
    await tester.tap(find.byType(TextField));
    await tester.enterText(
      find.byType(TextField),
      'Yarınki program için bir sorum var.\nİkinci satır.',
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Gönder'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(
      () => _capture(boundary, 'build/design-review/chat-keyboard-current.png'),
    );
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  required List<Override> overrides,
  required GlobalKey boundary,
  Size size = const Size(390, 844),
  double textScale = 1,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: RepaintBoundary(
        key: boundary,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          builder: (context, appChild) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              viewInsets: EdgeInsets.only(bottom: keyboard),
            ),
            child: appChild!,
          ),
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _capture(GlobalKey key, String path) async {
  final render =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(bytes!.buffer.asUint8List());
  image.dispose();
}

final _conversations = [
  ConversationRow(
    otherId: 'coach-1',
    otherName: 'Başantrenör Selin Kaya Çok Uzun Kulüp Görevi',
    lastBody: 'Yarınki antrenman programında küçük bir değişiklik yaptık.',
    lastAt: DateTime(2026, 11, 5, 14, 32),
    unread: 12,
  ),
  ConversationRow(
    otherId: 'athlete-1',
    otherName: 'Deniz Yılmaz',
    lastBody: 'Teşekkürler hocam, görüşürüz.',
    lastAt: DateTime(2026, 11, 5, 12, 10),
    unread: 0,
  ),
];

final _communities = [
  CommunityRow(
    id: 'team-1',
    name: 'Mavişehir Yüzme Takımı Büyükler A Grubu',
    cityName: 'İzmir',
    memberCount: 28,
    unread: 4,
    joined: true,
    canWrite: true,
    lastBody: 'Hafta sonu buluşma saati güncellendi.',
    lastAt: DateTime(2026, 11, 4, 19, 45),
    kind: 'city_coach',
  ),
];

final _directMessages = [
  MessageRow(
    id: 'dm-1',
    body:
        'Merhaba Deniz, yarınki antrenmandan sonra toparlanma programını birlikte gözden geçirelim.',
    createdAt: DateTime(2026, 11, 5, 13, 20),
    isMine: false,
  ),
  MessageRow(
    id: 'dm-2',
    body: 'Tamam hocam. Notlarımı ve sorularımı hazırlayıp geleceğim 👍',
    createdAt: DateTime(2026, 11, 5, 13, 24),
    isMine: true,
    readAt: DateTime(2026, 11, 5, 13, 25),
  ),
  MessageRow(
    id: 'dm-3',
    body: 'Takım etkinliği',
    createdAt: DateTime(2026, 11, 5, 13, 28),
    isMine: false,
    contentType: 'event_share',
    sharedKind: 'event',
    sharedId: 'event-1',
  ),
];

final _groupMessages = [
  CommunityMessageRow(
    id: 'group-1',
    senderId: 'athlete-1',
    body:
        'Hafta sonu yarışına gelecek olanlar için servis kulübün önünden saat 07.15’te hareket edecek.',
    createdAt: DateTime(2026, 11, 5, 9, 12),
    isMine: false,
  ),
  CommunityMessageRow(
    id: 'group-2',
    senderId: 'me',
    body: 'Bilgi için teşekkürler, ben de geleceğim.',
    createdAt: DateTime(2026, 11, 5, 9, 18),
    isMine: true,
  ),
];

const _members = {
  'athlete-1': CommunityMember(id: 'athlete-1', name: 'Deniz Yılmaz'),
};

class _MessageService extends NotificationService {
  _MessageService()
      : super(SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  @override
  Future<void> markConversationRead(String otherId) async {}

  @override
  Future<int> markMessagesRead(List<String> ids) async => ids.length;
}

class _CommunityService extends CommunityService {
  _CommunityService()
      : super(SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  @override
  Future<void> markRead(String communityId) async {}
}
