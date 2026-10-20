import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
void main(){
  final now=DateTime.utc(2026,10,20);
  UnifiedCalendarEvent event({String title='Antrenman',String? place,DateTime? end,String status='scheduled'})=>UnifiedCalendarEvent(
    id:'club:1:event:2',title:title,type:CalendarEventType.clubTraining,startsAt:DateTime.parse('2026-10-20T18:00:00+03:00'),endsAt:end,status:status,place:place);
  test('UTC timestamps, stable UID and duplicate elimination',(){
    final first=exportCalendar([event(),event()],generatedAt:now);
    expect(first,contains('DTSTART:20261020T150000Z\r\n'));expect('BEGIN:VEVENT'.allMatches(first).length,1);
    final uid=first.split('\r\n').firstWhere((s)=>s.startsWith('UID:'));
    expect(exportCalendar([event(title:'Yeni')],generatedAt:now.add(const Duration(days:1))),contains(uid));
    expect(first.endsWith('END:VCALENDAR\r\n'),true);
  });
  test('escaping prevents property injection; UTF-8 folding respects 75 octets',(){
    final title=List.filled(40,'Şğü🏊').join()+',;\\\r\nATTENDEE:fake';
    final file=exportCalendar([event(title:title,place:'Salon, A;B')],generatedAt:now);
    for(final line in file.split('\r\n'))expect(utf8.encode(line).length,lessThanOrEqualTo(75));
    final unfolded=file.replaceAll('\r\n ','');
    expect(unfolded,contains(r'\,\;\\\nATTENDEE:fake'));expect(unfolded,contains(r'LOCATION:Salon\, A\;B'));
    expect(file.split('\r\n').where((l)=>l.startsWith('ATTENDEE:')),isEmpty);
  });
  test('cancelled status and invalid end',(){
    expect(exportCalendar([event(status:'cancelled')],generatedAt:now),contains('STATUS:CANCELLED'));
    expect(()=>exportCalendar([event(end:now)],generatedAt:now),throwsArgumentError);
  });
  test('all-day end is exclusive in Turkey dates',(){
    final a=FederationActivity.fromMap({'id':'1','program_id':'2','title':'Kamp','sport_code':'football','season_id':'3','season_label':'2026','federation_name':'Federasyon','office_name':'Ofis','kind':'camp','status':'open','starts_at':'2026-10-19T21:00:00Z','ends_at':'2026-10-22T21:00:00Z','all_day':true});
    final file=exportCalendar([UnifiedCalendarEvent.official(a)],generatedAt:now);
    expect(file,contains('DTSTART;VALUE=DATE:20261020'));expect(file,contains('DTEND;VALUE=DATE:20261023'));
  });
}
