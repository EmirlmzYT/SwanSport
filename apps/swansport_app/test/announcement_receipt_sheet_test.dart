import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/announcements/presentation/widgets/announcement_receipt_sheet.dart';

class FakeReceipts extends AnnouncementReceiptService {
  FakeReceipts() : super(Supabase.instance.client);
  final calls = <bool>[];
  bool fail = false;
  @override
  Future<AnnouncementDetail> load(String id) async => const AnnouncementDetail(
      id: 'a', title: 'Duyuru', body: 'Gerçek içerik', version: 'v');
  @override
  Future<AnnouncementDetail> record(AnnouncementDetail d,
      {required bool acknowledge}) async {
    calls.add(acknowledge);
    if (fail) throw Exception('offline');
    return AnnouncementDetail(
        id: d.id,
        title: d.title,
        body: d.body,
        version: d.version,
        readAt: DateTime.utc(2026),
        acknowledgedAt: acknowledge ? DateTime.utc(2026) : null,
        readCount: 1,
        acknowledgedCount: acknowledge ? 1 : 0);
  }
}

void main() {
  Future<void> show(WidgetTester t, FakeReceipts service) async {
    await t.pumpWidget(ProviderScope(
        overrides: [
          announcementReceiptServiceProvider.overrideWithValue(service)
        ],
        child: const MaterialApp(
            home: Scaffold(body: AnnouncementReceiptSheet(id: 'a')))));
    await t.pumpAndSettle();
  }

  testWidgets('open records read; acknowledgement requires explicit tap',
      (t) async {
    final s = FakeReceipts();
    await show(t, s);
    expect(s.calls, [false]);
    expect(find.text('1 okundu · 0 onaylandı'), findsOneWidget);
    await t.tap(find.text('Okudum, onaylıyorum'));
    await t.pumpAndSettle();
    expect(s.calls, [false, true]);
    expect(find.text('Onayın kaydedildi'), findsOneWidget);
  });
  testWidgets('failed write never presents success and offers refresh',
      (t) async {
    final s = FakeReceipts();
    await show(t, s);
    s.fail = true;
    await t.tap(find.text('Okudum, onaylıyorum'));
    await t.pumpAndSettle();
    expect(find.text('Onayın kaydedildi'), findsNothing);
    expect(find.text('Yenile'), findsOneWidget);
    s.fail = false;
    await t.tap(find.text('Yenile'));
    await t.pumpAndSettle();
    expect(s.calls.last, false);
  });
}
