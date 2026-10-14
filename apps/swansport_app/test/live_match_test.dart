import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/live_match/presentation/live_match_hub_screen.dart';
import 'package:swansport_app/features/live_match/presentation/live_match_detail_screen.dart';
import 'package:swansport_app/features/live_match/presentation/live_match_widgets.dart';
import 'package:swansport_app/app/router.dart';

const _id='10000000-0000-0000-0000-000000000001';
void main(){
  setUpAll(()=>GoogleFonts.config.allowRuntimeFetching=false);
  testWidgets('direct disabled hub cannot construct the public backend',(tester)async{
    await tester.pumpWidget(ProviderScope(child:MaterialApp(home:const LiveMatchHubScreen())));
    await tester.pumpAndSettle();expect(find.textContaining('henüz kullanıma açılmadı'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('enabled empty hub is honest and preserves branch filters',(tester)async{
    await tester.pumpWidget(ProviderScope(overrides:[featureEnabledProvider(FeatureFlags.liveMatchHub).overrideWithValue(true),
      publicLiveMatchesProvider.overrideWith((_)async=>const []),
    ],child:MaterialApp(home:const LiveMatchHubScreen())));
    await tester.pumpAndSettle();expect(find.text('Bu filtrede maç bulunmuyor.'),findsOneWidget);
    expect(find.text('Tümü'),findsOneWidget);expect(find.text('Tenis'),findsOneWidget);
  });
  testWidgets('withdrawn/unknown detail shows same unavailable result, no old roster',(tester)async{
    await tester.pumpWidget(ProviderScope(overrides:[featureEnabledProvider(FeatureFlags.liveMatchHub).overrideWithValue(true),
      publicMatchLiveStateProvider(_id).overrideWith((_)async=>null),
    ],child:MaterialApp(home:const LiveMatchDetailScreen(matchId:_id))));
    await tester.pumpAndSettle();expect(find.text('Maç bulunamadı veya yayına açık değil.'),findsOneWidget);
    expect(find.text('Kadrolar'),findsNothing);
  });
  testWidgets('feed strip exposes one real live card and opens its public detail',(tester)async{
    final summary=PublicLiveMatchSummary(matchId:_id,sportCode:'futbol',status:'scheduled',isLive:true,
      homeClubName:'Ev Sahibi',awayClubName:'Deplasman',homeScore:2,awayScore:1);
    await tester.pumpWidget(ProviderScope(overrides:[featureEnabledProvider(FeatureFlags.liveMatchHub).overrideWithValue(true),
      publicLiveMatchesProvider.overrideWith((_)async=>[summary]),
    ],child:MaterialApp(routes:{'/canli-mac/$_id':(_)=>const Scaffold(body:Text('Maç Detayı'))},
      home:const Scaffold(body:LiveMatchStrip()))));
    await tester.pumpAndSettle();expect(find.byType(LiveMatchCard),findsOneWidget);
    await tester.tap(find.text('2 : 1'));await tester.pumpAndSettle();expect(find.text('Maç Detayı'),findsOneWidget);
  });
  testWidgets('running scoreboard ticks and disposal cancels ticker on narrow/high-scale layout',(tester)async{
    tester.view.physicalSize=const Size(320,700);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final summary=PublicLiveMatchSummary(matchId:_id,sportCode:'futbol',status:'scheduled',isLive:true,
      homeClubName:'Çok Uzun Ev Sahibi Kulübü',awayClubName:'Çok Uzun Deplasman Kulübü',homeScore:2,awayScore:1,
      elapsedSeconds:60,clockStartedAt:DateTime.utc(2026,10,14,10),serverNow:DateTime.utc(2026,10,14,10));
    var elapsed=Duration.zero;
    await tester.pumpWidget(MaterialApp(home:MediaQuery(data:const MediaQueryData(textScaler:TextScaler.linear(2)),
      child:Scaffold(body:SingleChildScrollView(child:LiveScoreboard(match:summary,elapsedClock:()=>elapsed))))));
    expect(find.text('01:00'),findsOneWidget);elapsed=const Duration(seconds:1);await tester.pump(const Duration(seconds:1));
    expect(find.text('01:01'),findsOneWidget);expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox.shrink());await tester.pump(const Duration(seconds:10));expect(tester.takeException(),isNull);
  });
  test('public router validates UUIDs without changing referee route ownership',(){
    expect(liveMatchRoute(const RouteSettings(name:'/canli-mac/$_id')),isNotNull);
    expect(liveMatchRoute(const RouteSettings(name:'/canli-mac/invalid')),isNull);
    expect(liveMatchRoute(const RouteSettings(name:'/hakem/canli/$_id')),isNull);
  });
}
