import 'console_table.dart';
import 'csv_download_stub.dart'
    if (dart.library.js_interop) 'csv_download_web.dart' as impl;

/// Tabloyu CSV olarak indirir.
///
/// **Görünen sayfa değil, süzgecin tamamı** dışa aktarılır: kullanıcı 200
/// sporcuyu süzüp 50'sini görüyorsa, indirdiği dosyada 200'ü de olmalı.
/// Bu yüzden çağıran taraf sayfalamasız ikinci bir sorgu geçer.
Future<void> downloadCsv<T>({
  required String fileName,
  required List<ConsoleColumn<T>> columns,
  required List<T> rows,
}) async {
  final text = buildCsv(columns: columns, rows: rows);
  if (text == null) return;
  impl.saveTextFile(fileName: fileName, text: text, mimeType: 'text/csv');
}

/// CSV metnini üretir; dışa aktarılabilir sütun yoksa null döner.
///
/// İndirmeden ayrı durması bilinçli: dosya kaydetmek platforma bağlı, metni
/// biçimlendirmek değil. Böylece kaçışlama kuralları testle sınanabiliyor.
///
/// Excel'in Türkçe karakterleri doğru açması için başa BOM konur; ayraç
/// olarak noktalı virgül kullanılır — Türkçe Windows yerelinde Excel virgülü
/// ondalık ayracı sayıp her şeyi tek sütuna basıyor.
String? buildCsv<T>({
  required List<ConsoleColumn<T>> columns,
  required List<T> rows,
}) {
  final exportable = columns.where((c) => c.csv != null).toList();
  if (exportable.isEmpty) return null;

  final buffer = StringBuffer()
    ..write('﻿')
    ..writeln(exportable.map((c) => escapeCsvField(c.label)).join(';'));

  for (final row in rows) {
    buffer.writeln(
        exportable.map((c) => escapeCsvField(c.csv!(row))).join(';'));
  }
  return buffer.toString();
}

/// CSV alanı kaçışlama: ayraç, tırnak veya satır sonu varsa tırnak içine al.
String escapeCsvField(String value) {
  final needsQuotes = value.contains(';') ||
      value.contains('"') ||
      value.contains('\n') ||
      value.contains('\r');
  final escaped = value.replaceAll('"', '""');
  return needsQuotes ? '"$escaped"' : escaped;
}

/// Dosya adına tarih ekler: `sporcular-2026-08-28.csv`.
String csvFileName(String base) {
  final now = DateTime.now();
  final d = now.toIso8601String().substring(0, 10);
  return '$base-$d.csv';
}
