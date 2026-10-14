import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/features/verification/presentation/mernis_verification_section.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _PendingService extends VerificationService {
  _PendingService(SupabaseClient client) : super(client);
  final pending = Completer<({bool success, String? error})>();
  @override
  Future<({bool success, String? error})> verifyWithMernis({required String nationalId,
    required String firstName, required String lastName, required int birthYear}) => pending.future;
}

void main() {
  setUpAll(()=>GoogleFonts.config.allowRuntimeFetching=false);
  Widget form({bool available=false,bool verified=false})=>ProviderScope(overrides:[
    authSessionProvider.overrideWith((_)=>Stream.value(null)),
    mernisAvailabilityProvider.overrideWith((_)async=>available),
    myIdentityGateProvider.overrideWith((_)async=>IdentityGateState(verified:verified)),
  ],child:MaterialApp(home:Scaffold(body:SingleChildScrollView(child:const MernisVerificationSection()))));

  testWidgets('unconfigured service explains manual fallback without collecting TCKN',(tester)async{
    await tester.pumpWidget(form());await tester.pumpAndSettle();
    expect(find.textContaining('Otomatik doğrulama şu anda kapalı'),findsOneWidget);
    expect(find.byType(TextFormField),findsNothing);expect(find.text('Doğrula ve Onayla'),findsNothing);
    expect(tester.takeException(),isNull);
  });
  testWidgets('checksum prevents submitting malformed identity',(tester)async{
    await tester.pumpWidget(form(available:true));await tester.pumpAndSettle();
    final fields=find.byType(TextFormField);
    await tester.enterText(fields.at(0),'10000000147');await tester.enterText(fields.at(1),'İlker');
    await tester.enterText(fields.at(2),'Işık');await tester.enterText(fields.at(3),'1995');
    await tester.ensureVisible(find.text('Doğrula ve Onayla'));await tester.tap(find.text('Doğrula ve Onayla'));await tester.pumpAndSettle();
    expect(find.text('Geçerli 11 haneli numara yazın.'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('authoritative verified gate removes identity inputs without claiming sports approval',(tester)async{
    await tester.pumpWidget(form(available:true,verified:true));await tester.pumpAndSettle();
    expect(find.textContaining('Kimliğiniz doğrulanmış.'),findsOneWidget);
    expect(find.byType(TextFormField),findsNothing);
    expect(find.textContaining('spor lisansı veya yaş doğrulaması yerine geçmez'),findsOneWidget);
  });
  testWidgets('account switch clears sensitive draft and ignores late completion',(tester)async{
    final client=SupabaseClient('https://example.supabase.co','test');addTearDown(client.dispose);
    final service=_PendingService(client);
    final sessions=StreamController<Session?>();addTearDown(sessions.close);
    Session? session(String uid)=>Session.fromJson({'access_token':'test-$uid','refresh_token':'refresh',
      'expires_in':3600,'token_type':'bearer','user':{'id':uid,'aud':'authenticated',
        'created_at':'2026-10-14T00:00:00Z','app_metadata':<String,dynamic>{},'user_metadata':<String,dynamic>{}}});
    await tester.pumpWidget(ProviderScope(overrides:[
      authSessionProvider.overrideWith((_)=>sessions.stream),
      mernisAvailabilityProvider.overrideWith((_)async=>true),
      myIdentityGateProvider.overrideWith((_)async=>const IdentityGateState()),
      verificationServiceProvider.overrideWithValue(service),
    ],child:MaterialApp(home:Scaffold(body:SingleChildScrollView(child:const MernisVerificationSection())))));
    sessions.add(session('old'));await tester.pumpAndSettle();
    final fields=find.byType(TextFormField);
    await tester.enterText(fields.at(0),'10000000146');await tester.enterText(fields.at(1),'İlker');
    await tester.enterText(fields.at(2),'Işık');await tester.enterText(fields.at(3),'1995');
    await tester.ensureVisible(find.text('Doğrula ve Onayla'));await tester.tap(find.text('Doğrula ve Onayla'));await tester.pump();
    sessions.add(session('new'));await tester.pump();await tester.pump();
    service.pending.complete((success:true,error:null));await tester.pumpAndSettle();
    for(final field in tester.widgetList<TextFormField>(find.byType(TextFormField))) {
      expect(field.controller!.text,isEmpty);
    }
    expect(find.textContaining('Kimliğiniz doğrulanmış.'),findsNothing);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
