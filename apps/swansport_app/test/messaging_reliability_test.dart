import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/features/communities/presentation/community_chat_screen.dart';
import 'package:swansport_app/features/social/presentation/messages_screen.dart';
import 'package:swansport_data/swansport_data.dart';

const _access = SwanAccess(
  isPlatformAdmin: false,
  clubRole: null,
  coachLevel: 0,
  athleteKind: null,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'iyimser mesaj realtime kopyasıyla çift görünmez ve taslak korunur',
      (tester) async {
    final stream = StreamController<List<MessageRow>>();
    final service = _DelayedMessageService();
    await _pumpDirect(tester, service, stream.stream, otherId: 'first');
    stream.add(const []);
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Gönderilen mesaj');
    await tester.pump();
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pump();
    expect(service.calls, hasLength(1));
    expect(find.text('Gönderilen mesaj'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Yeni taslak korunmalı');
    final sent = MessageRow(
      id: service.calls.single.id,
      body: service.calls.single.body,
      createdAt: DateTime(2026, 11, 5, 12),
      isMine: true,
    );
    service.completer.complete(sent);
    await tester.pump();
    stream.add([sent]);
    await tester.pump();

    expect(find.text('Gönderilen mesaj'), findsOneWidget);
    expect(find.text('Yeni taslak korunmalı'), findsOneWidget);
    await stream.close();
  });

  testWidgets('sohbet hedefi değişince önceki bekleyen mesaj görünmez',
      (tester) async {
    final service = _DelayedMessageService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(service),
          chatProvider('first').overrideWith((_) => Stream.value(const [])),
          chatProvider('second').overrideWith((_) => Stream.value(const [])),
          swanAccessProvider.overrideWithValue(_access),
        ],
        child: const MaterialApp(
          home: ChatScreen(otherId: 'first', otherName: 'Birinci Kişi'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Birinci sohbette kaldı');
    await tester.pump();
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pump();
    expect(find.text('Birinci sohbette kaldı'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(service),
          chatProvider('first').overrideWith((_) => Stream.value(const [])),
          chatProvider('second').overrideWith((_) => Stream.value(const [])),
          swanAccessProvider.overrideWithValue(_access),
        ],
        child: const MaterialApp(
          home: ChatScreen(otherId: 'second', otherName: 'İkinci Kişi'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Birinci sohbette kaldı'), findsNothing);
    expect(find.text('İkinci Kişi'), findsOneWidget);
  });

  testWidgets('grup gönderimi çiftlenmez ve hata taslağı korur',
      (tester) async {
    final service = _DelayedCommunityService();
    await _pumpGroup(tester, service, Stream.value(const []));
    await tester.enterText(find.byType(TextField), 'Kaybolmayan grup taslağı');
    await tester.pump();
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pump();
    expect(find.byTooltip('Gönderiliyor'), findsOneWidget);
    await tester.tap(find.byTooltip('Gönderiliyor'));
    await tester.pump();
    expect(service.calls, ['Kaybolmayan grup taslağı']);

    service.completer.completeError(StateError('network'));
    await tester.pumpAndSettle();
    expect(find.text('Kaybolmayan grup taslağı'), findsOneWidget);
    expect(find.text('Mesaj gönderilemedi. Metnin korunuyor.'), findsOneWidget);
  });

  testWidgets('eski grup mesajları okunurken yeni mesaj zorla alta kaydırmaz',
      (tester) async {
    tester.view.physicalSize = const Size(390, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = StreamController<List<CommunityMessageRow>>();
    await _pumpGroup(tester, _DelayedCommunityService(), controller.stream);
    controller.add(_manyGroupMessages(35));
    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    await tester.drag(scrollable, const Offset(0, 500));
    await tester.pump();
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(
        before,
        lessThan(
          tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        ));

    controller.add(_manyGroupMessages(36));
    await tester.pump();
    final after = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(after, closeTo(before, 1));
    await controller.close();
  });
}

Future<void> _pumpDirect(
  WidgetTester tester,
  NotificationService service,
  Stream<List<MessageRow>> stream, {
  required String otherId,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        notificationServiceProvider.overrideWithValue(service),
        chatProvider(otherId).overrideWith((_) => stream),
        swanAccessProvider.overrideWithValue(_access),
      ],
      child: MaterialApp(
        home: ChatScreen(otherId: otherId, otherName: 'Deniz Yılmaz'),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpGroup(
  WidgetTester tester,
  CommunityService service,
  Stream<List<CommunityMessageRow>> stream,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        communityServiceProvider.overrideWithValue(service),
        communityMessagesProvider('group').overrideWith((_) => stream),
        communityMembersProvider('group').overrideWith((_) async => const {}),
        communityListProvider.overrideWith((_) async => const [
              CommunityRow(
                id: 'group',
                name: 'Takım',
                cityName: 'İzmir',
                memberCount: 2,
                unread: 0,
                joined: true,
                canWrite: true,
                kind: 'city_coach',
              ),
            ]),
        swanAccessProvider.overrideWithValue(_access),
      ],
      child: const MaterialApp(
        home: CommunityChatScreen(communityId: 'group', title: 'Takım'),
      ),
    ),
  );
  await tester.pump();
}

List<CommunityMessageRow> _manyGroupMessages(int count) => List.generate(
      count,
      (index) => CommunityMessageRow(
        id: 'message-$index',
        senderId: index.isEven ? 'other' : 'me',
        body: 'Mesaj $index uzun konuşma içeriği',
        createdAt: DateTime(2026, 11, 5, 10, index),
        isMine: index.isOdd,
      ),
    );

class _DelayedMessageService extends NotificationService {
  _DelayedMessageService()
      : super(SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  final completer = Completer<MessageRow>();
  final calls = <({String id, String body, String otherId})>[];

  @override
  Future<void> markConversationRead(String otherId) async {}

  @override
  Future<int> markMessagesRead(List<String> ids) async => ids.length;

  @override
  Future<MessageRow> send(String otherId, String body, {String? messageId}) {
    calls.add((id: messageId!, body: body, otherId: otherId));
    return completer.future;
  }
}

class _DelayedCommunityService extends CommunityService {
  _DelayedCommunityService()
      : super(SupabaseClient(
          'https://example.supabase.co',
          'test-anon-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ));

  final completer = Completer<void>();
  final calls = <String>[];

  @override
  Future<void> markRead(String communityId) async {}

  @override
  Future<void> send(String communityId, String body) {
    calls.add(body);
    return completer.future;
  }
}
