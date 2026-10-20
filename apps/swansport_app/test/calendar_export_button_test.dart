import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/calendar/presentation/widgets/calendar_export_button.dart';
void main(){
  testWidgets('export requires explicit confirmation and explains one-time import',(t)async{
    await t.pumpWidget(ProviderScope(child:MaterialApp(home:Scaffold(body:CalendarExportButton(events:[
      UnifiedCalendarEvent(id:'a',title:'Antrenman',type:CalendarEventType.clubTraining,startsAt:DateTime.utc(2026),status:'scheduled')
    ])))));
    await t.tap(find.byTooltip('Görünen etkinlikleri takvimime aktar'));await t.pumpAndSettle();
    expect(find.textContaining('1 etkinlik .ics'),findsOneWidget);expect(find.textContaining('otomatik eşitlenmez'),findsOneWidget);
    await t.tap(find.text('Vazgeç'));await t.pumpAndSettle();expect(find.text('Dosyayı kaydet'),findsNothing);
  });
}
