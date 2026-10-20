import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_design_system/swansport_design_system.dart';
void main(){
  testWidgets('partial amount is returned and excessive/fractional quantities are rejected',(t)async{
    int? result;
    await t.pumpWidget(MaterialApp(home:Builder(builder:(context)=>Scaffold(body:TextButton(onPressed:()async{
      result=await showDialog<int>(context:context,builder:(_)=>const SwanQuantityDialog(maximum:8,title:'Sağlam iade'));
    },child:const Text('Aç'))))));
    await t.tap(find.text('Aç'));await t.pumpAndSettle();
    await t.enterText(find.byType(TextFormField),'9');await t.tap(find.text('Kaydet'));await t.pumpAndSettle();expect(find.textContaining('tam sayı gir.'),findsOneWidget);expect(result,isNull);
    await t.enterText(find.byType(TextFormField),'1.5');await t.tap(find.text('Kaydet'));await t.pumpAndSettle();expect(result,isNull);
    await t.enterText(find.byType(TextFormField),'3');await t.tap(find.text('Kaydet'));await t.pumpAndSettle();expect(result,3);
  });
}
