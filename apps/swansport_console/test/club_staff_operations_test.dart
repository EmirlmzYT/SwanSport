import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_console/app/modules/module_registry.dart';
import 'package:swansport_console/app/modules/console_module.dart';
import 'package:swansport_console/app/theme/console_theme.dart';
import 'package:swansport_console/app/shell/too_narrow_notice.dart';
import 'package:swansport_console/features/club_staff/club_staff_operations_screen.dart';
import 'package:swansport_data/swansport_data.dart';
const _kit=SwanAccess(isPlatformAdmin:false,clubRole:'parent',coachLevel:0,athleteKind:null,accountantClubIds:{'c'},
  clubOperationsAuthority:[ClubOperationsAuthority(clubId:'c',inventoryRead:true,inventoryWrite:true,healthRead:false,planningRead:false)]);
void main(){
  setUp(()=>GoogleFonts.config.allowRuntimeFetching=false);
  test('kit specialist does not inherit legacy athlete/clinical module access even with accountant role',(){
    expect(moduleForRoute('/malzeme-takibi')!.visibleTo(_kit),isTrue);
    expect(moduleForRoute('/sporcular')!.visibleTo(_kit),isFalse);
    expect(moduleForRoute('/saglik-takibi')!.visibleTo(_kit),isFalse);
    expect(moduleForRoute('/kadro-planlama')!.visibleTo(_kit),isFalse);
    expect(moduleForRoute('/malzeme-takibi')!.visibleTo(const SwanAccess(isPlatformAdmin:false,clubRole:null,coachLevel:0,athleteKind:null,accountantClubIds:{'c'})),isFalse);
  });
  testWidgets('all specialist modules keep the narrow-screen notice',(tester)async{
    tester.view.physicalSize=const Size(800,700);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    for(final mode in ConsoleClubStaffMode.values){await tester.pumpWidget(ProviderScope(child:MaterialApp(theme:ConsoleTheme.dark(),home:Scaffold(body:ConsoleClubStaffOperationsScreen(mode:mode)))));expect(find.byType(TooNarrowNotice),findsOneWidget);}
  });
  testWidgets('inventory shows real zero availability rather than demo stock',(tester)async{
    tester.view.physicalSize=const Size(1200,900);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(overrides:[consoleAccessProvider.overrideWithValue(_kit),
      activeClubProvider.overrideWith((_)async=>const ClubRef(id:'c',name:'Kulüp')),
      featureEnabledProvider(FeatureFlags.clubStaffOperations).overrideWithValue(true),
      clubInventoryBoardProvider('c').overrideWith((_)async=>ClubInventoryBoard(items:const [ClubInventoryItem(id:'i',name:'Top',category:'ball',quantity:5,available:0,damaged:5,missing:0,status:'active')],assignments:[],targets:[])),
      authSessionProvider.overrideWith((_)=>Stream.value(null)),
    ],child:MaterialApp(theme:ConsoleTheme.dark(),home:const Scaffold(body:ConsoleClubStaffOperationsScreen(mode:ConsoleClubStaffMode.inventory)))));
    await tester.pumpAndSettle();expect(find.text('0 kullanılabilir'),findsOneWidget);expect(find.text('Zimmet Ver'),findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
