import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_app/app/push/push_io.dart' as io;
import 'package:swansport_app/app/push/push_token_gate.dart';
import 'package:swansport_app/app/push/push.dart';

void main() {
  test('native support admits Android/iOS but not unrelated desktop platforms',
      () {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    for (final platform in TargetPlatform.values) {
      debugDefaultTargetPlatformOverride = platform;
      expect(
          io.pushSupported,
          platform == TargetPlatform.android ||
              (platform == TargetPlatform.iOS &&
                  const bool.fromEnvironment('IOS_FIREBASE_ENABLED',
                      defaultValue: true)));
    }
  });
  test(
      'disabled iOS preview never enters Firebase through any push entry point',
      () async {
    if (const bool.fromEnvironment('IOS_FIREBASE_ENABLED', defaultValue: true))
      return;
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(io.pushSupported, isFalse);
    expect(await io.pushCurrent(), isNull);
    expect(await io.pushUnsubscribe(), isNull);
    expect(await io.pushInitialMessage(), isNull);
    expect(await io.pushTokenChanges().toList(), isEmpty);
    expect(await io.pushForegroundMessages().toList(), isEmpty);
    expect(await io.pushOpenedMessages().toList(), isEmpty);
    await expectLater(io.pushSubscribe(), throwsA(isA<PushException>()));
  });
  test(
      'APNs gate waits until token exists before permitting subsequent FCM work',
      () async {
    var reads = 0;
    final delays = <Duration>[];
    final token = await waitForApnsToken(
        read: () async => ++reads == 3 ? 'fixture-apns' : null,
        delay: (d) async => delays.add(d));
    expect(token, 'fixture-apns');
    expect(reads, 3);
    expect(delays.length, 2);
  });
  test('missing APNs token is bounded and has actionable diagnostic', () async {
    var reads = 0;
    final token = await waitForApnsToken(
        read: () async {
          reads++;
          return null;
        },
        delay: (_) async {},
        attempts: 3);
    expect(token, isNull);
    expect(reads, 3);
    expect(const PushException(PushFailure.apnsUnavailable).toString(),
        contains('İmza'.toLowerCase()));
  });
}
