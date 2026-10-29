import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/features/communities/presentation/community_chat_screen.dart';
import 'package:swansport_data/swansport_data.dart';

class _CommunityService extends CommunityService {
  _CommunityService(this.client) : super(client);
  final SupabaseClient client;

  @override
  Future<void> markRead(String communityId) async {}
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('grup mesajları eskiden yeniye alt alta gösterilir',
      (tester) async {
    final client = SupabaseClient('https://example.supabase.co', 'test');
    final service = _CommunityService(client);
    final newer = DateTime(2026, 10, 24, 12);
    final older = DateTime(2026, 10, 23, 12);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        communityServiceProvider.overrideWithValue(service),
        communityMessagesProvider('group').overrideWith(
          (_) => Stream.value([
            CommunityMessageRow(
              id: 'new',
              senderId: 'a',
              body: 'Yeni mesaj',
              createdAt: newer,
              isMine: true,
            ),
            CommunityMessageRow(
              id: 'old',
              senderId: 'b',
              body: 'Eski mesaj',
              createdAt: older,
              isMine: false,
            ),
          ]),
        ),
        communityMembersProvider('group').overrideWith((_) async => const {}),
      ],
      child: const MaterialApp(
        home: CommunityChatScreen(
          communityId: 'group',
          title: 'Takım',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Eski mesaj')).dy,
      lessThan(tester.getTopLeft(find.text('Yeni mesaj')).dy),
    );

    await tester.pumpWidget(const SizedBox());
    client.auth.stopAutoRefresh();
  });
}
