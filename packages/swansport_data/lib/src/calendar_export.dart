import 'dart:convert';
import 'unified_calendar.dart';

/// RFC 5545 file; deliberately omits attendees, private results and reports.
String exportCalendar(List<UnifiedCalendarEvent> events,
    {required DateTime generatedAt}) {
  String stamp(DateTime d) =>
      d
          .toUtc()
          .toIso8601String()
          .split('.')
          .first
          .replaceAll(RegExp('[-:]'), '') +
      'Z';
  String date(DateTime d) {
    final t = calendarTurkeyTime(d);
    return '${t.year.toString().padLeft(4, '0')}${t.month.toString().padLeft(2, '0')}${t.day.toString().padLeft(2, '0')}';
  }

  String escape(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .replaceAll('\n', r'\n')
      .replaceAll(';', r'\;')
      .replaceAll(',', r'\,');
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//SwanSport//Calendar//TR',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH'
  ];
  final unique = {
    for (final e in events)
      if (e.guardianResult == null) e.id: e
  };
  for (final e in unique.values) {
    final end = e.endsAt;
    if (end != null && !end.isAfter(e.startsAt))
      throw ArgumentError('Etkinlik bitişi başlangıçtan sonra olmalı.');
    final allDay = e.activity?.allDay == true;
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:${base64Url.encode(utf8.encode(e.id)).replaceAll('=', '')}@swansport',
      'DTSTAMP:${stamp(generatedAt)}',
      allDay
          ? 'DTSTART;VALUE=DATE:${date(e.startsAt)}'
          : 'DTSTART:${stamp(e.startsAt)}',
      if (end != null)
        allDay ? 'DTEND;VALUE=DATE:${date(end)}' : 'DTEND:${stamp(end)}',
      'SUMMARY:${escape(e.title)}',
      if (e.place?.isNotEmpty == true) 'LOCATION:${escape(e.place!)}',
      'STATUS:${e.status == 'cancelled' ? 'CANCELLED' : 'CONFIRMED'}',
      'DESCRIPTION:Tek seferlik aktarım. Değişiklikleri SwanSport üzerinden kontrol edin.',
      'END:VEVENT'
    ]);
  }
  lines.add('END:VCALENDAR');
  // Fold by UTF-8 octets, never splitting a Unicode scalar (75 incl. prefix).
  String fold(String s) {
    final parts = <String>[];
    var part = '';
    var count = 0;
    for (final rune in s.runes) {
      final char = String.fromCharCode(rune);
      final n = utf8.encode(char).length;
      if (count + n > 75) {
        parts.add(part);
        part = ' ';
        count = 1;
      }
      part += char;
      count += n;
    }
    parts.add(part);
    return parts.join('\r\n');
  }

  return lines.map(fold).join('\r\n') + '\r\n';
}
