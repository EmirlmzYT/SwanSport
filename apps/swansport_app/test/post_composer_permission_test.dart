import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_app/app/theme/app_theme.dart';
import 'package:swansport_app/features/social/presentation/post_composer_sheet.dart';
import 'package:swansport_data/swansport_data.dart';

void main() {
  testWidgets('sunucu reddederse yerel belge paylaşımı açmaz', (tester) async {
    final service = _DeniedSocialService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          socialServiceProvider.overrideWithValue(service),
          currentProfileProvider.overrideWith(
            (_) async =>
                const ProfileInfo(id: 'profile-1', fullName: 'Deniz Yılmaz'),
          ),
          activeClubProvider.overrideWith((_) async => null),
          myCredentialsProvider.overrideWith(
            (_) async => const [
              CredentialRow(
                id: 'credential-1',
                kind: 'athlete_licensed',
                status: 'approved',
              ),
            ],
          ),
          swanAccessProvider.overrideWithValue(SwanAccess.none),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () => showPostComposer(context),
                child: const Text('Aç'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Aç'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Paylaşım metni');
    await tester.pump();
    await tester.tap(find.text('Paylaş'));
    await tester.pump();

    expect(service.permissionChecks, 1);
    expect(service.createCalls, 0);
    expect(find.textContaining('onaylı sporcu/antrenör belgesi'), findsOneWidget);
  });
}

SupabaseClient _client() => SupabaseClient(
      'https://example.supabase.co',
      'anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );

class _DeniedSocialService extends SocialService {
  _DeniedSocialService() : super(_client());

  int permissionChecks = 0;
  int createCalls = 0;

  @override
  Future<bool> canCreatePost({String? clubId}) async {
    permissionChecks++;
    return false;
  }

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
  }) async {
    createCalls++;
    return 'post-1';
  }
}
