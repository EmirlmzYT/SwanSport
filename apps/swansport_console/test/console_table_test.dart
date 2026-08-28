import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_console/app/widgets/console_table.dart';

/// Tablo sorgusu ve çizimi.
///
/// `ConsoleTableQuery` sayfalama/sıralama niyetini taşıyor; yanlış hesaplanan
/// bir `offset` kullanıcıya sessizce yanlış sayfayı gösterir — hata vermeden.
void main() {
  group('ConsoleTableQuery', () {
    test('offset sayfa ve sayfa boyutundan hesaplanır', () {
      expect(const ConsoleTableQuery().offset, 0);
      expect(const ConsoleTableQuery(page: 1, pageSize: 50).offset, 50);
      expect(const ConsoleTableQuery(page: 3, pageSize: 20).offset, 60);
    });

    test('copyWith yalnızca verileni değiştirir', () {
      const q = ConsoleTableQuery(
        page: 2,
        pageSize: 25,
        sortKey: 'first_name',
        ascending: false,
        search: 'ali',
      );
      final next = q.copyWith(page: 0);

      expect(next.page, 0);
      expect(next.pageSize, 25);
      expect(next.sortKey, 'first_name');
      expect(next.ascending, isFalse);
      expect(next.search, 'ali');
    });

    test('değer eşitliği var — gereksiz yeniden sorgu olmasın', () {
      const a = ConsoleTableQuery(page: 1, search: 'x');
      const b = ConsoleTableQuery(page: 1, search: 'x');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  group('ConsoleTable çizimi', () {
    final columns = [
      ConsoleColumn<_Row>(
        label: 'Ad',
        sortKey: 'name',
        csv: (r) => r.name,
        cell: (r) => Text(r.name),
      ),
      ConsoleColumn<_Row>(
        label: 'Puan',
        width: 80,
        numeric: true,
        csv: (r) => '${r.score}',
        cell: (r) => Text('${r.score}'),
      ),
    ];

    Widget wrap(Widget child) =>
        MaterialApp(home: Scaffold(body: SizedBox(height: 600, child: child)));

    testWidgets('satırları ve kayıt sayısını gösterir', (tester) async {
      await tester.pumpWidget(wrap(ConsoleTable<_Row>(
        columns: columns,
        rows: const [_Row('Ali', 10), _Row('Veli', 20)],
        query: const ConsoleTableQuery(),
        totalCount: 2,
        rowId: (r) => r.name,
        onQueryChanged: (_) {},
      )));

      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Veli'), findsOneWidget);
      expect(find.text('1–2 / 2 kayıt'), findsOneWidget);
    });

    testWidgets('boş listede mesaj gösterir', (tester) async {
      await tester.pumpWidget(wrap(ConsoleTable<_Row>(
        columns: columns,
        rows: const [],
        query: const ConsoleTableQuery(),
        totalCount: 0,
        rowId: (r) => r.name,
        emptyMessage: 'Kayıt bulunamadı.',
        onQueryChanged: (_) {},
      )));

      expect(find.text('Kayıt bulunamadı.'), findsOneWidget);
    });

    testWidgets('başlığa basınca sıralama sunucuya bildirilir',
        (tester) async {
      ConsoleTableQuery? sent;
      await tester.pumpWidget(wrap(ConsoleTable<_Row>(
        columns: columns,
        rows: const [_Row('Ali', 10)],
        query: const ConsoleTableQuery(),
        totalCount: 1,
        rowId: (r) => r.name,
        onQueryChanged: (q) => sent = q,
      )));

      await tester.tap(find.text('AD'));
      await tester.pump();

      expect(sent, isNotNull);
      expect(sent!.sortKey, 'name');
      expect(sent!.ascending, isTrue);
      // Sıralama değişince ilk sayfaya dönülmeli; yoksa kullanıcı yeni
      // sıralamanın 3. sayfasında, sebepsiz bir yerde kalır.
      expect(sent!.page, 0);
    });

    testWidgets('aynı başlığa tekrar basmak yönü çevirir', (tester) async {
      ConsoleTableQuery? sent;
      await tester.pumpWidget(wrap(ConsoleTable<_Row>(
        columns: columns,
        rows: const [_Row('Ali', 10)],
        query: const ConsoleTableQuery(sortKey: 'name'),
        totalCount: 1,
        rowId: (r) => r.name,
        onQueryChanged: (q) => sent = q,
      )));

      await tester.tap(find.text('AD'));
      await tester.pump();

      expect(sent!.ascending, isFalse);
    });

    testWidgets('seçim yapılınca toplu işlem çubuğu belirir', (tester) async {
      await tester.pumpWidget(wrap(ConsoleTable<_Row>(
        columns: columns,
        rows: const [_Row('Ali', 10), _Row('Veli', 20)],
        query: const ConsoleTableQuery(),
        totalCount: 2,
        rowId: (r) => r.name,
        selected: const {'Ali'},
        onSelectionChanged: (_) {},
        bulkActions: [
          ConsoleBulkAction(
            label: 'Pasife al',
            icon: Icons.pause_rounded,
            onRun: () async {},
          ),
        ],
        onQueryChanged: (_) {},
      )));

      expect(find.text('1 seçili'), findsOneWidget);
      expect(find.text('Pasife al'), findsOneWidget);
    });

    testWidgets('ilk sayfada geri düğmesi kapalı', (tester) async {
      await tester.pumpWidget(wrap(ConsoleTable<_Row>(
        columns: columns,
        rows: const [_Row('Ali', 10)],
        query: const ConsoleTableQuery(),
        totalCount: 100,
        rowId: (r) => r.name,
        onQueryChanged: (_) {},
      )));

      final back = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
      );
      expect(back.onPressed, isNull);

      final forward = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );
      expect(forward.onPressed, isNotNull);
    });

    testWidgets('hata varsa satır yerine hata gösterir', (tester) async {
      await tester.pumpWidget(wrap(ConsoleTable<_Row>(
        columns: columns,
        rows: const [],
        query: const ConsoleTableQuery(),
        totalCount: 0,
        rowId: (r) => r.name,
        error: 'RLS reddetti',
        onQueryChanged: (_) {},
      )));

      expect(find.text('Veri alınamadı'), findsOneWidget);
      expect(find.textContaining('RLS reddetti'), findsOneWidget);
    });
  });
}

class _Row {
  const _Row(this.name, this.score);
  final String name;
  final int score;
}
