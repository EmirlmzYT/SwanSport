import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/features/social/presentation/messages_screen.dart';
import 'package:swansport_data/swansport_data.dart';

class _MessagesService extends NotificationService {
  _MessagesService(this.client) : super(client);
  final SupabaseClient client;
  final calls = <String>[];
  final completions = <Completer<MessageRow>>[];
  @override
  Future<void> markConversationRead(String otherId) async {}
  @override
  Future<MessageRow> send(String otherId, String body, {String? messageId}) {
    calls.add(body);
    final completion = Completer<MessageRow>();
    completions.add(completion);
    return completion.future;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('Hızlı mesajlar sırayla gönderilir ve alt alta gösterilir',
      (tester) async {
    final service =
        _MessagesService(SupabaseClient('https://example.supabase.co', 'test'));

    await tester.pumpWidget(ProviderScope(
        overrides: [
          notificationServiceProvider.overrideWithValue(service),
          swanAccessProvider.overrideWithValue(const SwanAccess(
              isPlatformAdmin: false,
              clubRole: null,
              coachLevel: 0,
              athleteKind: null)),
          chatProvider('other')
              .overrideWith((_) => Stream.value(const <MessageRow>[])),
        ],
        child: const MaterialApp(
            home: ChatScreen(otherId: 'other', otherName: 'Deniz'))));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Birinci');
    await tester.pump();
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'İkinci');
    await tester.pump();
    await tester.tap(find.byTooltip('Gönder'));
    await tester.pump();
    expect(service.calls, ['Birinci']);
    expect(tester.getTopLeft(find.text('Birinci')).dy,
        lessThan(tester.getTopLeft(find.text('İkinci')).dy));
    service.completions.first.complete(MessageRow(
        id: '1', body: 'Birinci', createdAt: DateTime.now(), isMine: true));
    await tester.pump();
    expect(service.calls, ['Birinci', 'İkinci']);
    service.completions.last.complete(MessageRow(
        id: '2', body: 'İkinci', createdAt: DateTime.now(), isMine: true));
    await tester.pump();
    expect(find.text('Birinci'), findsOneWidget);
    expect(find.text('İkinci'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    service.client.auth.stopAutoRefresh();
  });
}
