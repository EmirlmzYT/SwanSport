import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_console/app/widgets/console_table.dart';
import 'package:swansport_console/app/widgets/csv_export.dart';

/// CSV üretimi.
///
/// Bozuk kaçışlama sessiz bir hatadır: dosya indirilir, açılır, sütunlar
/// kaymıştır ve kimse fark etmez. O yüzden ayraç/tırnak/satır sonu
/// durumlarının hepsi sınanıyor.
void main() {
  group('escapeCsvField', () {
    test('düz metne dokunmaz', () {
      expect(escapeCsvField('Ali Veli'), 'Ali Veli');
    });

    test('ayraç içeren alanı tırnaklar', () {
      // Ayraç noktalı virgül; tırnaklanmazsa tek alan iki sütuna bölünürdü.
      expect(escapeCsvField('Kaleci;Defans'), '"Kaleci;Defans"');
    });

    test('tırnağı ikiye katlar', () {
      expect(escapeCsvField('12" boy'), '"12"" boy"');
    });

    test('satır sonu içeren alanı tırnaklar', () {
      expect(escapeCsvField('bir\niki'), '"bir\niki"');
      expect(escapeCsvField('bir\riki'), '"bir\riki"');
    });

    test('boş alan boş kalır', () {
      expect(escapeCsvField(''), '');
    });
  });

  group('buildCsv', () {
    final columns = [
      ConsoleColumn<_Row>(
        label: 'Ad',
        csv: (r) => r.name,
        cell: (r) => Text(r.name),
      ),
      ConsoleColumn<_Row>(
        label: 'Mevki',
        csv: (r) => r.position,
        cell: (r) => Text(r.position),
      ),
      // csv verilmemiş sütun dışa aktarmaya girmemeli (ör. ok ikonu sütunu).
      ConsoleColumn<_Row>(
        label: '',
        cell: (r) => const Icon(Icons.chevron_right),
      ),
    ];

    test('başlık satırı ve satırlar yazılır', () {
      final out = buildCsv(
        columns: columns,
        rows: const [_Row('Ali', 'Kaleci'), _Row('Veli', 'Forvet')],
      );

      final lines = out!.trim().split('\n');
      // İlk karakter BOM — Excel Türkçe karakterleri doğru açsın diye.
      expect(out.codeUnitAt(0), 0xFEFF);
      expect(lines[0], contains('Ad;Mevki'));
      expect(lines[1].trim(), 'Ali;Kaleci');
      expect(lines[2].trim(), 'Veli;Forvet');
    });

    test('csv tanımsız sütun dışa aktarılmaz', () {
      final out = buildCsv(columns: columns, rows: const [_Row('Ali', 'X')]);
      // Üç sütun var ama ikisi dışa aktarılabilir → tek ayraç.
      expect(out!.trim().split('\n')[1].split(';').length, 2);
    });

    test('satır yoksa yalnızca başlık kalır', () {
      final out = buildCsv(columns: columns, rows: const <_Row>[]);
      expect(out!.trim().split('\n').length, 1);
    });

    test('dışa aktarılabilir sütun yoksa null döner', () {
      final out = buildCsv(
        columns: [
          ConsoleColumn<_Row>(label: 'X', cell: (r) => const SizedBox()),
        ],
        rows: const [_Row('Ali', 'Kaleci')],
      );
      expect(out, isNull);
    });

    test('içinde ayraç olan veri sütunları kaydırmaz', () {
      final out = buildCsv(
        columns: columns,
        rows: const [_Row('Ali;Sahte', 'Kaleci')],
      );
      final dataLine = out!.trim().split('\n')[1].trim();
      expect(dataLine, '"Ali;Sahte";Kaleci');
    });
  });

  group('csvFileName', () {
    test('tarihli ve .csv uzantılı', () {
      final name = csvFileName('sporcular');
      expect(name, startsWith('sporcular-'));
      expect(name, endsWith('.csv'));
      expect(RegExp(r'^sporcular-\d{4}-\d{2}-\d{2}\.csv$').hasMatch(name),
          isTrue);
    });
  });
}

class _Row {
  const _Row(this.name, this.position);
  final String name;
  final String position;
}
