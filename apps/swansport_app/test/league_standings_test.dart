import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/features/live_match/presentation/league_standings_view.dart';
import 'package:swansport_app/features/live_match/presentation/live_match_hub_screen.dart';
import 'package:swansport_app/features/live_match/presentation/live_match_detail_screen.dart';

const _id='10000000-0000-0000-0000-000000000001';
LeagueStandingsRow _row()=>LeagueStandingsRow(rank:1,participantId:_id,name:'Uzun İsimli Spor Kulübü',
  played:3,won:1,drawn:1,lost:1,goalsFor:3,goalsAgainst:4,goalDiff:-1,points:4,form:['W','D','L']);
void main(){
  setUp(()=>GoogleFonts.config.allowRuntimeFetching=false);
  testWidgets('disabled standings has no backend or table',(tester)async{
    await tester.pumpWidget(ProviderScope(child:MaterialApp(home:Scaffold(body:LeagueStandingsView(orgId:_id)))));
    expect(find.textContaining('henüz kullanıma açılmadı'),findsOneWidget);expect(find.byType(DataTable),findsNothing);
  });
  testWidgets('narrow high-scale table scrolls, highlights match club and toggles live provider',(tester)async{
    tester.view.physicalSize=const Size(320,800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final queries=<LeagueStandingsQuery>[];
    await tester.pumpWidget(ProviderScope(overrides:[featureEnabledProvider(FeatureFlags.leagueStandings).overrideWithValue(true),
      leagueStandingsProvider.overrideWith((ref,q)async{queries.add(q);return [_row()];}),
    ],child:MaterialApp(home:MediaQuery(data:const MediaQueryData(textScaler:TextScaler.linear(2)),child:Scaffold(
      body:SingleChildScrollView(child:LeagueStandingsView(orgId:_id,highlightedParticipants:const {_id})))))));
    await tester.pumpAndSettle();expect(find.byType(DataTable),findsOneWidget);
    expect(queries.last.includeLive,isFalse);final data=tester.widget<DataTable>(find.byType(DataTable));
    expect(data.rows.single.color,isNotNull);expect(data.rows.single.cells.length,9);
    await tester.tap(find.byType(Switch));await tester.pumpAndSettle();expect(queries.last.includeLive,isTrue);
    expect(find.text('Canlı Puan Durumu'),findsOneWidget);expect(tester.takeException(),isNull);
  });
  testWidgets('hub exposes standings selector only with its own flag',(tester)async{
    await tester.pumpWidget(ProviderScope(overrides:[featureEnabledProvider(FeatureFlags.liveMatchHub).overrideWithValue(true),
      featureEnabledProvider(FeatureFlags.leagueStandings).overrideWithValue(true),
      publicLiveMatchesProvider.overrideWith((_)async=>[]),standingsLeaguesProvider.overrideWith((_)async=>[]),
    ],child:MaterialApp(home:const LiveMatchHubScreen())));
    await tester.pumpAndSettle();await tester.ensureVisible(find.text('Puan Durumu'));
    await tester.tap(find.text('Puan Durumu'));await tester.pumpAndSettle();expect(find.text('Yayımlanmış lig bulunmuyor.'),findsOneWidget);
  });
  testWidgets('match context is explicit UUID and unknown/publication-withdrawn does not show table',(tester)async{
    await tester.pumpWidget(ProviderScope(overrides:[featureEnabledProvider(FeatureFlags.leagueStandings).overrideWithValue(true),
      matchStandingsContextProvider(_id).overrideWith((_)async=>null),
    ],child:MaterialApp(home:const Scaffold(body:MatchLeagueStandingsView(matchId:_id)))));
    await tester.pumpAndSettle();expect(find.textContaining('yayımlanmış lig tablosu yok'),findsOneWidget);
    expect(find.byType(DataTable),findsNothing);
  });
  testWidgets('league refresh preserves live switch; withdrawn league removes stale table',(tester)async{
    const league=StandingsLeague(id:_id,name:'Lig',sportCode:'futbol');
    var pending=Completer<List<StandingsLeague>>()..complete([league]);
    final c=ProviderContainer(overrides:[featureEnabledProvider(FeatureFlags.leagueStandings).overrideWithValue(true),
      standingsLeaguesProvider.overrideWith((_)=>pending.future),
      leagueStandingsProvider.overrideWith((_,q)async=>[_row()]),
    ]);addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container:c,child:MaterialApp(home:const Scaffold(
      body:SingleChildScrollView(child:LeagueStandingsSelector())))));
    await tester.pumpAndSettle();await tester.tap(find.byType(Switch));await tester.pumpAndSettle();
    pending=Completer<List<StandingsLeague>>();c.invalidate(standingsLeaguesProvider);await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value,isTrue);
    pending.complete([league]);await tester.pumpAndSettle();expect(tester.widget<Switch>(find.byType(Switch)).value,isTrue);
    pending=Completer<List<StandingsLeague>>()..complete([]);c.invalidate(standingsLeaguesProvider);await tester.pumpAndSettle();
    expect(find.byType(DataTable),findsNothing);expect(find.text('Yayımlanmış lig bulunmuyor.'),findsOneWidget);
  });
  testWidgets('detail third tab uses public league context without private roster reads',(tester)async{
    await tester.pumpWidget(ProviderScope(overrides:[featureEnabledProvider(FeatureFlags.liveMatchHub).overrideWithValue(true),
      featureEnabledProvider(FeatureFlags.leagueStandings).overrideWithValue(true),
      publicMatchLiveStateProvider(_id).overrideWith((_)async=>PublicLiveMatchDetail(summary:PublicLiveMatchSummary(matchId:_id,sportCode:'futbol',status:'scheduled'))),
      matchStandingsContextProvider(_id).overrideWith((_)async=>null),
    ],child:MaterialApp(home:const LiveMatchDetailScreen(matchId:_id))));
    await tester.pumpAndSettle();await tester.ensureVisible(find.text('Puan Durumu'));await tester.tap(find.text('Puan Durumu'));
    await tester.pumpAndSettle();expect(find.byType(MatchLeagueStandingsView),findsOneWidget);expect(tester.takeException(),isNull);
  });
}
