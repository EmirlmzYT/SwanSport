import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/network/presentation/guest_explore_screen.dart';
import 'package:swansport_app/features/social/presentation/feed_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('authenticated feed never becomes guest while access is pending',
      (tester) async {
    final sessions = StreamController<Session?>();
    addTearDown(sessions.close);
    await tester.pumpWidget(ProviderScope(overrides: [
      isSupabaseEnabledProvider.overrideWithValue(true),
      authSessionProvider.overrideWith((_) => sessions.stream),
      swanAccessProvider.overrideWithValue(SwanAccess.none),
      platformConfigProvider.overrideWith((_) async => PlatformConfig.fromMap({})),
      discoverProvider.overrideWith((_) async => []),
      announcementsProvider.overrideWith((_) async => []),
      newsProvider.overrideWith((_) async => []),
      currentProfileProvider.overrideWith((_) async => null),
    ], child: const MaterialApp(home: FeedScreen())));
    expect(find.byType(GuestExploreScreen), findsNothing);
    sessions.add(Session(
      accessToken: 'test-token', tokenType: 'bearer',
      user: User(id: 'startup-user', appMetadata: {}, userMetadata: {},
          aud: 'authenticated', createdAt: '2026-10-17T00:00:00Z'),
    ));
    await tester.pump();
    await tester.pump();
    expect(find.byType(GuestExploreScreen), findsNothing);
    expect(find.byKey(const Key('feed-floating-header')), findsOneWidget);
    // The visual shell does not grant any account/club permissions.
    expect(ProviderScope.containerOf(tester.element(find.byType(FeedScreen)))
        .read(swanAccessProvider).hasAccount, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
