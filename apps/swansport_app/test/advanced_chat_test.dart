import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/social/presentation/messages_screen.dart';
import 'package:swansport_app/features/social/presentation/widgets/chat_presentation.dart';
import 'package:swansport_app/features/social/presentation/widgets/chat_message_bubble.dart';
import 'package:swansport_app/features/social/presentation/widgets/chat_timeline.dart';
import 'package:swansport_app/app/design/swan_palette.dart';

ChatItem item(String id,
        {String? body,
        DateTime? at,
        bool mine = false,
        String? sender,
        MessageStatus status = MessageStatus.sent,
        bool share = false}) =>
    ChatItem(
        message: MessageRow(
            id: id,
            body: body ?? 'Mesaj $id',
            createdAt: at ?? DateTime(2026, 10, 18, 12),
            isMine: mine,
            status: status,
            contentType: share ? 'content_share' : 'text',
            sharedKind: share ? 'post' : null,
            sharedId: share ? 'private-reference' : null),
        senderId: sender ?? (mine ? 'self' : 'peer'));

class _Service extends NotificationService {
  _Service() : super(Supabase.instance.client);
  final marks = <String>{};
  int wholeMarks = 0;
  int sends = 0;
  Completer<void>? delivery;
  bool fail = false;
  @override
  Future<int> markMessagesRead(List<String> ids) async {
    marks.addAll(ids);
    return ids.length;
  }

  @override
  Future<void> markConversationRead(String id) async {
    wholeMarks++;
  }

  @override
  Future<void> send(String otherId, String text) async {
    sends++;
    if (delivery != null) await delivery!.future;
    if (fail) throw StateError('fixture offline');
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  test(
      'ordering, dedup and grouping are deterministic across date, sender and share boundaries',
      () {
    final base = DateTime(2026, 10, 18, 12);
    final a = item('a', at: base);
    final b = item('b', at: base.add(const Duration(minutes: 5)));
    expect(groupsWith(a, b), isTrue);
    expect(
        groupsWith(
            a, item('c', at: base.add(const Duration(minutes: 5, seconds: 1)))),
        isFalse);
    expect(groupsWith(a, item('c', at: base, sender: 'another')), isFalse);
    expect(groupsWith(a, item('c', at: base, share: true)), isFalse);
    expect(
        groupsWith(item('x', at: DateTime(2026, 10, 17, 23, 59)),
            item('y', at: DateTime(2026, 10, 18))),
        isFalse);
    expect(orderedChatItems([b, a, a]).map((e) => e.message.id), ['a', 'b']);
  });
  test('Turkish dates, clock, highlights and truthful statuses', () {
    final now = DateTime(2026, 10, 18, 12);
    expect(chatDayLabel(now, now: now), 'Bugün');
    expect(chatDayLabel(DateTime(2026, 10, 17), now: now), 'Dün');
    expect(chatDayLabel(DateTime(2026, 9, 3), now: now), '3 Eylül 2026');
    expect(chatTime(DateTime(2026, 10, 18, 9, 5)), '09:05');
    expect(
        chatMatchRanges('🏃 Işık Şampiyon IŞIK', 'isik'), [(3, 7), (17, 21)]);
    expect(chatMatchRanges('metin', ''), isEmpty);
    expect(chatStatus(item('a', mine: true).message), 'Gönderildi');
    expect(chatStatus(item('b', status: MessageStatus.failed).message),
        'Gönderilemedi');
    expect(chatStatus(item('c', status: MessageStatus.sending).message),
        'Gönderiliyor');
  });

  Future<void> render(WidgetTester tester, Widget child,
      {Brightness mode = Brightness.dark, double width = 393}) async {
    tester.view.physicalSize = Size(width, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: mode), home: Scaffold(body: child)));
    await tester.pump();
  }

  testWidgets('long press copies only original text; retry action is explicit',
      (tester) async {
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData')
        copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    var retries = 0;
    await render(
        tester,
        ChatMessageBubble(
            item: item('failed',
                body: 'Özel gerçek metin',
                mine: true,
                status: MessageStatus.failed),
            onRetry: () => retries++));
    await tester.longPress(find.text('Özel gerçek metin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Metni kopyala'));
    await tester.pumpAndSettle();
    expect(copied, 'Özel gerçek metin');
    expect(find.text('Mesaj kopyalandı'), findsOneWidget);
    await tester.tap(find.text('Tekrar gönder'));
    expect(retries, 1);
  });

  testWidgets(
      'only visible rows are reported; incoming messages preserve old reading position',
      (tester) async {
    var rows = List.generate(
        55,
        (i) => item('$i',
            body: 'Uzun mesaj $i\nİkinci satır\nÜçüncü satır',
            at: DateTime(2026, 10, 18, 12, i)));
    final visible = <String>{};
    late StateSetter change;
    await render(tester, StatefulBuilder(builder: (_, state) {
      change = state;
      return ChatTimeline(
          items: rows,
          empty: const Text('Boş'),
          onVisible: (items) => visible.addAll(items.map((e) => e.message.id)));
    }));
    await tester.pumpAndSettle();
    expect(visible, contains('54'));
    expect(visible, isNot(contains('0')));
    await tester.drag(find.byType(ListView), const Offset(0, 550));
    await tester.pumpAndSettle();
    final mounted = find
        .byType(ChatMessageBubble)
        .evaluate()
        .map((e) => (e.widget as ChatMessageBubble).item.message.id)
        .toList();
    final anchor = mounted.firstWhere((id) {
      final p = tester.getTopLeft(find.byKey(ValueKey(id)));
      return p.dy > 50 && p.dy < 500;
    });
    final before = tester.getTopLeft(find.byKey(ValueKey(anchor))).dy;
    change(() => rows = [
          ...rows,
          item('new', body: 'Yeni gelen mesaj', at: DateTime(2026, 10, 18, 13))
        ]);
    await tester.pumpAndSettle();
    expect(find.text('Yeni mesajlar'), findsOneWidget);
    expect(
        tester.getTopLeft(find.byKey(ValueKey(anchor))).dy, closeTo(before, 2));
    await tester.tap(find.text('Yeni mesajlar'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni gelen mesaj'), findsOneWidget);
    expect(find.text('Yeni mesajlar'), findsNothing);
  });

  testWidgets(
      'search navigates to lazy variable-height rows and keeps selection on refresh',
      (tester) async {
    var query = '';
    var rows = List.generate(
        45,
        (i) => item('$i',
            body: i == 2 || i == 40 ? 'Işık sporcu $i' : 'Mesaj $i',
            at: DateTime(2026, 10, 18, 12, i)));
    late StateSetter change;
    await render(tester, StatefulBuilder(builder: (_, state) {
      change = state;
      return ChatTimeline(
          items: rows, query: query, searching: true, empty: const Text('Boş'));
    }));
    change(() => query = 'isik');
    await tester.pumpAndSettle();
    expect(find.text('1/2 sonuç'), findsOneWidget);
    expect(find.byKey(const ValueKey('2')), findsOneWidget);
    await tester.tap(find.byTooltip('Sonraki sonuç'));
    await tester.pumpAndSettle();
    expect(find.text('2/2 sonuç'), findsOneWidget);
    change(() => rows = [...rows]);
    await tester.pumpAndSettle();
    expect(find.text('2/2 sonuç'), findsOneWidget);
    change(() => query = 'yok');
    await tester.pumpAndSettle();
    expect(find.text('Sonuç bulunamadı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> dm(
      WidgetTester tester, _Service service, List<MessageRow> messages) async {
    await tester.pumpWidget(ProviderScope(
        overrides: [
          isSupabaseEnabledProvider.overrideWithValue(false),
          swanAccessProvider.overrideWithValue(const SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null)),
          notificationServiceProvider.overrideWithValue(service),
          conversationsProvider.overrideWith((_) async => []),
          chatProvider('peer').overrideWith((_) => Stream.value(messages)),
        ],
        child: MaterialApp(
            routes: {
              '/profil': (context) => Scaffold(
                  body: Text(
                      'Profil: ${ModalRoute.of(context)!.settings.arguments}')),
            },
            home:
                const ChatScreen(otherId: 'peer', otherName: 'Deniz Sporcu'))));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'DM never marks whole chat, retry and in-flight draft survive and dispose is safe',
      (tester) async {
    final service = _Service()..fail = true;
    await dm(
        tester,
        service,
        List.generate(
            30, (i) => item('$i', at: DateTime(2020, 10, 18, 12, i)).message));
    expect(service.wholeMarks, 0);
    expect(service.marks, isNot(contains('0')));
    await tester.enterText(find.byType(TextField), 'Gönderilecek');
    await tester.pump();
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pumpAndSettle();
    expect(service.sends, 1,
        reason: 'authorized DM must reach the existing service');
    expect(find.byType(ChatTimeline), findsOneWidget);
    expect(find.text('Gönderilemedi'), findsOneWidget);
    service.fail = false;
    service.delivery = Completer<void>();
    await tester.tap(find.text('Tekrar gönder'));
    await tester.pump();
    expect(service.sends, 2);
    await tester.enterText(find.byType(TextField), 'Yeni taslak');
    service.delivery!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Yeni taslak');
    service.delivery = Completer<void>();
    await tester.pump();
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
    service.delivery!.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'empty DM identity, search close and profile navigation are real actions',
      (tester) async {
    final service = _Service();
    await dm(tester, service, []);
    expect(find.text('İlk mesajı gönder'), findsOneWidget);
    expect(find.text('Profili görüntüle'), findsOneWidget);
    expect(service.wholeMarks, 0);
    expect(service.marks, isEmpty);
    await tester.tap(find.byTooltip('Sohbette ara'));
    await tester.pumpAndSettle();
    expect(find.text('Yüklenen mesajlarda ara'), findsWidgets);
    await tester.tap(find.byTooltip('Aramayı kapat'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.tap(find.text('Profili görüntüle'));
    await tester.pumpAndSettle();
    expect(find.text('Profil: peer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('background and covered route do not report messages as visible',
      (tester) async {
    final visible = <String>{};
    final nav = GlobalKey<NavigatorState>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(MaterialApp(
        navigatorKey: nav,
        home: Scaffold(
            body: ChatTimeline(
                items: [item('a')],
                onVisible: (rows) =>
                    visible.addAll(rows.map((e) => e.message.id)),
                empty: const Text('Boş')))));
    await tester.pumpAndSettle();
    expect(visible, {'a'});
    visible.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(visible, isEmpty);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(visible, {'a'});
    visible.clear();
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Profil'))));
    await tester.pumpAndSettle();
    expect(visible, isEmpty);
    Supabase.instance.client.auth.stopAutoRefresh();
  });

  testWidgets(
      'shared card refresh removes private source title without fetching it for actions',
      (tester) async {
    var available = true;
    var reads = 0;
    final cardProvider = sharedCardProvider('post|private-reference');
    final container = ProviderContainer(overrides: [
      cardProvider.overrideWith((_) async {
        reads++;
        return available
            ? const SharedCard(available: true, title: 'Özel kaynak başlığı')
            : const SharedCard.unavailable();
      })
    ]);
    addTearDown(container.dispose);
    await render(
        tester,
        UncontrolledProviderScope(
            container: container,
            child: ChatMessageBubble(
                item: item('shared', body: '', share: true))));
    await tester.pumpAndSettle();
    expect(find.text('Özel kaynak başlığı'), findsOneWidget);
    await tester.longPress(find.text('Özel kaynak başlığı'));
    await tester.pumpAndSettle();
    expect(find.text('Metni kopyala'), findsNothing);
    expect(reads, 1);
    available = false;
    container.invalidate(cardProvider);
    await tester.pumpAndSettle();
    expect(find.text('Özel kaynak başlığı'), findsNothing);
    expect(find.text('Bu içerik artık kullanılamıyor'), findsOneWidget);
  });

  testWidgets('keyboard resize does not reset an older reading position',
      (tester) async {
    await render(
        tester,
        ChatTimeline(
            items: List.generate(
                40,
                (i) => item('$i',
                    body: 'Uzun mesaj $i\nİkinci satır\nÜçüncü satır',
                    at: DateTime(2026, 10, 18, 12, i))),
            empty: const Text('Boş')));
    await tester.drag(find.byType(ListView), const Offset(0, 650));
    await tester.pumpAndSettle();
    final controller =
        tester.widget<ListView>(find.byType(ListView)).controller!;
    final before = controller.offset;
    expect(before, greaterThan(100));
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(before, 2));
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(controller.offset, closeTo(before, 2));
    expect(tester.takeException(), isNull);
  });

  for (final mode in Brightness.values) {
    testWidgets('full DM visual with identity, search and composer $mode',
        (tester) async {
      final boundary = GlobalKey();
      final service = _Service();
      final messages = [
        item('a',
                body: 'Yarın antrenman sahasında buluşuyor muyuz?',
                at: DateTime(2026, 10, 17, 18, 30))
            .message,
        item('b',
                body: 'Evet, 18:30 gibi oradayım.',
                mine: true,
                at: DateTime(2026, 10, 17, 18, 32))
            .message,
        item('c', body: 'Harika, görüşürüz!', at: DateTime(2026, 10, 18, 9, 15))
            .message,
      ];
      await render(
          tester,
          RepaintBoundary(
              key: boundary,
              child: ProviderScope(
                  overrides: [
                    isSupabaseEnabledProvider.overrideWithValue(false),
                    swanAccessProvider.overrideWithValue(const SwanAccess(
                        isPlatformAdmin: false,
                        clubRole: null,
                        coachLevel: 0,
                        athleteKind: null)),
                    notificationServiceProvider.overrideWithValue(service),
                    conversationsProvider.overrideWith((_) async => [
                          ConversationRow(
                              otherId: 'peer',
                              otherName: 'Deniz Sporcu',
                              lastBody: 'Harika, görüşürüz!',
                              lastAt: DateTime(2026, 10, 18),
                              unread: 0)
                        ]),
                    chatProvider('peer')
                        .overrideWith((_) => Stream.value(messages)),
                  ],
                  child: const ChatScreen(
                      otherId: 'peer', otherName: 'Deniz Sporcu'))),
          mode: mode);
      await tester.pumpAndSettle();
      expect(find.text('Birebir sohbet'), findsOneWidget);
      expect(find.text('Deniz Sporcu'), findsOneWidget);
      await tester.tap(find.byTooltip('Sohbette ara'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.widgetWithText(TextField, 'Yüklenen mesajlarda ara'),
          'sahasında');
      await tester.pumpAndSettle();
      expect(find.text('1/1 sonuç'), findsOneWidget);
      await tester.tap(find.byTooltip('Aramayı kapat'));
      await tester.pumpAndSettle();
      expect(find.text('1/1 sonuç'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final image = await (boundary.currentContext!.findRenderObject()!
                as RenderRepaintBoundary)
            .toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final file = File('../../build/advanced-chat/full-dm-${mode.name}.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
      });
    });
    for (final width in [320.0, 393.0]) {
      testWidgets('synthetic conversation visual $mode/$width', (tester) async {
        final boundary = GlobalKey();
        await render(
            tester,
            Builder(
                builder: (context) => RepaintBoundary(
                    key: boundary,
                    child: ColoredBox(
                        color: context.swan.bg,
                        child: MediaQuery(
                            data: MediaQuery.of(context).copyWith(
                                textScaler: const TextScaler.linear(1.3)),
                            child: ChatTimeline(items: [
                              item('a',
                                  body: 'Antrenman yarın kaçta başlıyor?',
                                  at: DateTime(2026, 10, 17, 18, 30)),
                              item('b',
                                  body:
                                      'Sahada 18:30 gibi buluşalım. Isınmayla başlarız.',
                                  mine: true,
                                  at: DateTime(2026, 10, 17, 18, 32)),
                              item('c',
                                  body: 'Harika, görüşürüz! 🏃',
                                  at: DateTime(2026, 10, 18, 9, 15)),
                            ], empty: const Text('Boş')))))),
            mode: mode,
            width: width);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final image = await (boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          final file = File(
              '../../build/advanced-chat/${mode.name}-${width.toInt()}.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
      });
    }
  }
}
