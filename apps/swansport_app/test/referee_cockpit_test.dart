import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_data/swansport_data.dart';
import 'package:swansport_app/app/router.dart';
import 'package:swansport_app/features/referee/referee_widgets.dart';
import 'package:swansport_app/features/referee/referee_duty_list_screen.dart';
import 'package:swansport_app/features/referee/referee_lineup_approval_screen.dart';
import 'package:swansport_app/features/referee/referee_live_cockpit_screen.dart';
import 'package:swansport_app/features/referee/referee_match_report_screen.dart';

const match='10000000-0000-0000-0000-000000000001';
const access=SwanAccess(isPlatformAdmin:false,clubRole:null,coachLevel:0,athleteKind:null,
  refereeProfile:RefereeProfile(id:'r',profileId:'me',licenseNumber:'R',badgeTier:RefereeBadgeTier.national,sportCode:'tenis',cityCode:'34',isActive:true));
void main(){
  setUpAll(()=>GoogleFonts.config.allowRuntimeFetching=false);
  Widget wrap(Widget child,{bool flag=true,SwanAccess permissions=access,List<Override> extras=const []})=>ProviderScope(overrides:[
    swanAccessProvider.overrideWithValue(permissions),featureEnabledProvider(FeatureFlags.refereeCockpit).overrideWithValue(flag),...extras],child:MaterialApp(home:child));
  test('deep referee routes preserve valid id and reject malformed ids',(){
    for(final route in ['esame','canli','rapor'])expect(refereeRoute(RouteSettings(name:'/hakem/$route/$match')),isNotNull);
    expect(refereeRoute(const RouteSettings(name:'/hakem/canli/not-an-id')),isNull);
    expect(refereeRoute(const RouteSettings(name:'/other/canli/$match')),isNull);
  });
  testWidgets('non-referee/disabled flag cannot build private cockpit', (tester)async{
    await tester.pumpWidget(wrap(const RefereeDutyListScreen(),permissions:SwanAccess.none));
    expect(find.textContaining('henüz kullanıma açık değil'),findsOneWidget);
    await tester.pumpWidget(wrap(const RefereeDutyListScreen(),flag:false));
    expect(find.textContaining('henüz kullanıma açık değil'),findsOneWidget);
  });
  testWidgets('profile cockpit entry follows referee and rollout gates', (tester)async{
    await tester.pumpWidget(wrap(const Scaffold(body:RefereeEntryCard()),flag:false));expect(find.text('Hakem Kokpiti'),findsNothing);
    await tester.pumpWidget(wrap(const Scaffold(body:RefereeEntryCard())));expect(find.text('Hakem Kokpiti'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('private dialog content is hidden when its opening actor no longer matches', (tester)async{
    await tester.pumpWidget(wrap(const Scaffold(body:RefereeActorScope(actorId:'previous-account',child:Text('Private player')))));
    await tester.pump();expect(find.text('Private player'),findsNothing);
    expect(tester.takeException(),isNull);
  });
  testWidgets('real completed match enters completed tab, not merely an accepted assignment', (tester)async{
    await tester.pumpWidget(wrap(const RefereeDutyListScreen(),extras:[myRefereeMatchesProvider(null).overrideWith((ref)async=>[
      RefereeMatchSummary(officialId:'o',matchId:match,duty:MatchOfficialDuty.headReferee,status:MatchOfficialStatus.accepted,
        assignedAt:DateTime.now(),sportCode:'tenis',matchStatus:'played',homeClubName:'Home',awayClubName:'Away')])]));
    await tester.pump();await tester.pump();expect(find.text('Home — Away'),findsNothing);
    await tester.tap(find.text('Tamamlananlar'));await tester.pump();expect(find.text('Home — Away'),findsOneWidget);
    expect(find.text('Müsabakayı Yönet'),findsNothing);
  });
  testWidgets('blocked candidate is visible with privacy mask but cannot be selected', (tester)async{
    await tester.pumpWidget(wrap(const RefereeLineupApprovalScreen(matchId:match),extras:[
      matchLineupApprovalsProvider(match).overrideWith((ref)async=>[]),
      refereeLineupCandidatesProvider(match).overrideWith((ref)async=>[const RefereeLineupCandidate(
        athleteId:match,side:'home',name:null,jerseyNumber:11,licenseNumber:'L',eligibilityStatus:'medical',eligible:false,selection:'unselected')]) ]));
    await tester.pump();await tester.pump();expect(find.text('11 · #100000'),findsOneWidget);
    expect(find.text('Oynayamaz · Tıbbi Engel'),findsOneWidget);
    expect(tester.widget<DropdownButtonFormField<String>>(find.byType(DropdownButtonFormField<String>)).onChanged,isNull);
    expect(tester.takeException(),isNull);
  });
  testWidgets('field action has a minimum 48 dp hit target', (tester)async{
    await tester.pumpWidget(wrap(Scaffold(body:RefereeButton(label:'Skor +1',onPressed:(){}))));
    final size=tester.getSize(find.byType(FilledButton));expect(size.height,greaterThanOrEqualTo(48));expect(size.width,greaterThanOrEqualTo(48));
  });
  testWidgets('live/report direct access fails closed on backend error', (tester)async{
    for(final screen in [const RefereeLiveCockpitScreen(matchId:match),const RefereeMatchReportScreen(matchId:match)]){
      await tester.pumpWidget(wrap(screen,extras:[
        refereeMatchStateProvider(match).overrideWith((ref)async=>throw StateError('No accepted duty')),
        refereeLineupCandidatesProvider(match).overrideWith((ref)async=>[])]));
      await tester.pump();await tester.pump();expect(find.text('İşlem doğrulanamadı'),findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(),isNull);
  });
}
