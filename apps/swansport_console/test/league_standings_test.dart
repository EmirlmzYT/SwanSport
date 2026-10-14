import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/app/shell/too_narrow_notice.dart';
import 'package:swansport_console/app/theme/console_theme.dart';
import 'package:swansport_console/app/widgets/console_table.dart';
import 'package:swansport_console/features/federation/league_standings_panel.dart';
import 'package:swansport_console/features/federation/provincial_leagues_screen.dart';

const _id='10000000-0000-0000-0000-000000000001';
const _foreign='10000000-0000-0000-0000-000000000002';
SwanAccess _access()=>SwanAccess(isPlatformAdmin:false,clubRole:null,coachLevel:0,athleteKind:null,
  federationRoles:[FederationRole(id:'role',federationId:'f',profileId:'p',role:FederationRoleKind.provincialRep,
    cityCode:'34',startsOn:DateTime(2020),endsOn:DateTime(2090))]);
LeagueStandingsRow _row(int i)=>LeagueStandingsRow(rank:i,participantId:'participant-$i',name:'Kulüp $i',
  played:2,won:1,drawn:1,lost:0,goalsFor:3,goalsAgainst:1,goalDiff:2,points:4,form:['W','D']);
void main(){
  setUp(()=>GoogleFonts.config.allowRuntimeFetching=false);
  testWidgets('standings preserves direct desktop and role guards',(tester)async{
    tester.view.physicalSize=const Size(800,700);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(child:MaterialApp(home:const Scaffold(body:ConsoleLeagueStandingsPanel()))));
    expect(find.byType(TooNarrowNotice),findsOneWidget);
    tester.view.physicalSize=const Size(1200,800);
    await tester.pumpWidget(ProviderScope(child:MaterialApp(home:const Scaffold(body:ConsoleLeagueStandingsPanel()))));
    expect(find.text('Aktif federasyon görevi gerekli.'),findsOneWidget);expect(find.byType(ConsoleTable<LeagueStandingsRow>),findsNothing);
  });
  testWidgets('province selects only server-scoped federation/city and toggles live query',(tester)async{
    tester.view.physicalSize=const Size(1000,800);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final queries=<LeagueStandingsQuery>[];
    await tester.pumpWidget(ProviderScope(overrides:[consoleAccessProvider.overrideWithValue(_access()),
      featureEnabledProvider(FeatureFlags.leagueStandings).overrideWithValue(true),
      federationConsoleScopesProvider.overrideWith((_)async=>[const FederationConsoleScope(federationId:'f',name:'Federasyon',sportCode:'tenis',cityCode:'34',role:'provincial_rep')]),
      standingsLeaguesProvider.overrideWith((_)async=>[
        const StandingsLeague(id:_id,name:'İstanbul Ligi',sportCode:'tenis',cityCode:'34',federationId:'f'),
        const StandingsLeague(id:_foreign,name:'Gizli Olmayan Ankara',sportCode:'tenis',cityCode:'06',federationId:'f'),
        const StandingsLeague(id:'other',name:'Başka Federasyon',sportCode:'tenis',cityCode:'34',federationId:'other'),
      ]),
      leagueStandingsProvider.overrideWith((ref,q)async{queries.add(q);return [_row(1)];}),
    ],child:MaterialApp(theme:ConsoleTheme.dark(),home:const Scaffold(body:ConsoleLeagueStandingsPanel()))));
    await tester.pumpAndSettle();expect(queries.last.orgId,_id);expect(queries.last.includeLive,isFalse);
    final dropdowns=tester.widgetList<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>)).toList();
    expect(dropdowns.first.onChanged,isNull);expect(find.text('İstanbul Ligi'),findsOneWidget);
    expect(find.text('Gizli Olmayan Ankara'),findsNothing);expect(find.text('Başka Federasyon'),findsNothing);
    await tester.tap(find.byType(Switch));await tester.pumpAndSettle();expect(queries.last.includeLive,isTrue);
    expect(tester.takeException(),isNull);
  });
  testWidgets('provincial module keeps fixture tab and adds gated standings tab',(tester)async{
    tester.view.physicalSize=const Size(1200,900);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides:[consoleAccessProvider.overrideWithValue(_access()),
      featureEnabledProvider(FeatureFlags.leagueStandings).overrideWithValue(true),
      federationConsoleScopesProvider.overrideWith((_)async=>[const FederationConsoleScope(federationId:'f',name:'Federasyon',sportCode:'tenis',cityCode:'34',role:'provincial_rep')]),
      citiesProvider.overrideWith((_)async=>[]),
      federationConsoleMatchesProvider.overrideWith((_,q)async=>FederationConsolePage<FederationConsoleMatch>(total:0,rows:[])),
      standingsLeaguesProvider.overrideWith((_)async=>[]),
    ],child:MaterialApp(theme:ConsoleTheme.dark(),home:const Scaffold(body:ProvincialLeaguesScreen()))));
    await tester.pumpAndSettle();expect(find.text('Fikstür & Maçlar'),findsOneWidget);
    await tester.tap(find.text('Puan Durumu'));await tester.pumpAndSettle();
    expect(find.textContaining('Yetki kapsamınızda yayımlanmış lig yok'),findsOneWidget);expect(tester.takeException(),isNull);
  });
}
