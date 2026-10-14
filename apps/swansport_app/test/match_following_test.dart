import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/live_match/presentation/match_follow_button.dart';
const _id='10000000-0000-0000-0000-000000000001';
const _access=SwanAccess(isPlatformAdmin:false,clubRole:null,coachLevel:0,athleteKind:null);
Session _session()=>Session(accessToken:'fixture',tokenType:'bearer',user:User(
  id:'actor',appMetadata:{},userMetadata:{},aud:'authenticated',createdAt:'2020-01-01T00:00:00Z'));
class _Service extends MatchFollowingService {
  _Service(super.client);
  bool followed=false,fail=false;
  Completer<bool>? pending;
  final List<bool> desired=[];
  @override Future<bool> setFollow(String id,{required bool follow}) async {
    desired.add(follow);followed=follow;
    if(fail)throw StateError('uncertain response');if(pending!=null)return await pending!.future;
    return follow;
  }
}
Widget _app(_Service service,{bool guest=false})=>ProviderScope(overrides:[
  featureEnabledProvider(FeatureFlags.liveMatchNotifications).overrideWithValue(true),
  swanAccessProvider.overrideWithValue(guest?SwanAccess.none:_access),
  authSessionProvider.overrideWith((_)=>Stream.value(guest?null:_session())),
  matchFollowingServiceProvider.overrideWithValue(service),
  matchFollowStateProvider(_id).overrideWith((_)async=>MatchFollowState(matchId:_id,isFollowed:service.followed)),
],child:MaterialApp(home:const Scaffold(body:SingleChildScrollView(child:MatchFollowButton(matchId:_id)))));
void main(){
  setUp(()=>GoogleFonts.config.allowRuntimeFetching=false);
  testWidgets('disabled flag hides follow action and indicator',(tester)async{
    await tester.pumpWidget(ProviderScope(child:MaterialApp(home:const Scaffold(body:Column(children:[
      MatchFollowButton(matchId:_id),MatchFollowIndicator(matchId:_id)])))));
    expect(find.byType(FilledButton),findsNothing);expect(find.byIcon(Icons.notifications_active_rounded),findsNothing);
  });
  testWidgets('guest sees account gate and never writes after opening it',(tester)async{
    final client=SupabaseClient('https://example.supabase.co','test');addTearDown(client.dispose);final service=_Service(client);
    await tester.pumpWidget(_app(service,guest:true));await tester.pumpAndSettle();await tester.tap(find.text('Bildirimleri Aç'));await tester.pumpAndSettle();
    expect(find.text('Giriş Yap / Kayıt Ol'),findsOneWidget);expect(service.desired,isEmpty);
  });
  testWidgets('follow changes only match preference and exposes separate device permission control',(tester)async{
    final client=SupabaseClient('https://example.supabase.co','test');addTearDown(client.dispose);final service=_Service(client);
    await tester.pumpWidget(_app(service));await tester.pumpAndSettle();await tester.tap(find.text('Bildirimleri Aç'));await tester.pumpAndSettle();
    expect(service.desired,[true]);expect(find.text('Bildirimleri Kapat'),findsOneWidget);
    expect(find.text('Cihaz Bildirim Ayarları'),findsOneWidget);expect(find.textContaining('tercihi kaydedildi'),findsOneWidget);
    await tester.tap(find.text('Bildirimleri Kapat'));await tester.pumpAndSettle();expect(service.desired,[true,false]);
  });
  testWidgets('lost reply retries same desired state, not an inverted toggle',(tester)async{
    final client=SupabaseClient('https://example.supabase.co','test');addTearDown(client.dispose);final service=_Service(client)..fail=true;
    await tester.pumpWidget(_app(service));await tester.pumpAndSettle();await tester.tap(find.text('Bildirimleri Aç'));await tester.pumpAndSettle();
    expect(find.text('Tercihi Yeniden Dene'),findsOneWidget);service.fail=false;
    await tester.tap(find.text('Tercihi Yeniden Dene'));await tester.pumpAndSettle();expect(service.desired,[true,true]);expect(service.followed,isTrue);
  });
  testWidgets('busy action cannot double-submit and dispose safely ignores completion',(tester)async{
    final client=SupabaseClient('https://example.supabase.co','test');addTearDown(client.dispose);
    final service=_Service(client)..pending=Completer<bool>();await tester.pumpWidget(_app(service));await tester.pumpAndSettle();
    await tester.tap(find.text('Bildirimleri Aç'));await tester.pump();
    final button=tester.widget<FilledButton>(find.byType(FilledButton));expect(button.onPressed,isNull);expect(service.desired,[true]);
    await tester.pumpWidget(const SizedBox.shrink());service.pending!.complete(true);await tester.pump();expect(tester.takeException(),isNull);
  });
}
