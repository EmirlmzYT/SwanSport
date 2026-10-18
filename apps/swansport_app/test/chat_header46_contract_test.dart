import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chat refresh keeps approved header46 shell and native navigation', () {
    final screen = File('lib/features/social/presentation/messages_screen.dart').readAsStringSync();
    expect(screen, contains('SwanFloatingHeader('));
    expect(screen, contains('header: _buildHeader(c)'));
    expect(screen, contains('const SwanHeaderSpacer()'));
    expect(screen, contains('scrollUnderHeader: true'));
    expect(screen, contains('const SwanBottomNav()'));
    expect(screen, contains('SwanChatComposer('));
    expect(screen, isNot(contains('_buildActiveAthletesReel')));
    expect(screen, isNot(contains("'Antrenörler'")));
  });
}
