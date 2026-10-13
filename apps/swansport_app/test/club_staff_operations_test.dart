import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:swansport_app/features/club_staff/club_staff_operations_screen.dart';
import 'package:swansport_data/swansport_data.dart';
void main(){
  setUp(()=>GoogleFonts.config.allowRuntimeFetching=false);
  testWidgets('direct inventory route is closed without club permission',(tester)async{
    await tester.pumpWidget(ProviderScope(overrides:[swanAccessProvider.overrideWithValue(SwanAccess.none),activeClubProvider.overrideWith((_)async=>const ClubRef(id:'c',name:'Kulüp'))],
      child:MaterialApp(theme:ThemeData.dark(),home:const ClubStaffOperationsScreen(mode:ClubStaffMode.inventory))));
    await tester.pumpAndSettle();expect(find.text('Malzeme Ekle'),findsNothing);expect(find.text('Zimmet Ver'),findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('physician label without server authority does not open clinical controls',(tester)async{
    const a=SwanAccess(isPlatformAdmin:false,clubRole:'parent',coachLevel:0,athleteKind:null,
      clubOperationsAuthority:[ClubOperationsAuthority(clubId:'c',inventoryRead:false,inventoryWrite:false,healthRead:true,planningRead:false)]);
    await tester.pumpWidget(ProviderScope(overrides:[swanAccessProvider.overrideWithValue(a),activeClubProvider.overrideWith((_)async=>const ClubRef(id:'c',name:'Kulüp')),
      featureEnabledProvider(FeatureFlags.clubStaffOperations).overrideWithValue(true),authSessionProvider.overrideWith((_)=>Stream.value(null)),
      clubHealthOperationsProvider('c').overrideWith((_)async=>const [ClubHealthOperation(athleteId:'a',reference:'#A3F91C',status:'restricted',reason:'Aktif sağlık kısıtı',blocked:true)]),
    ],child:MaterialApp(theme:ThemeData.dark(),home:const ClubStaffOperationsScreen(mode:ClubStaffMode.health))));
    await tester.pumpAndSettle();expect(find.text('#A3F91C'),findsOneWidget);expect(find.text('Tıbbi Kısıtı Kaldır'),findsNothing);expect(find.text('Tıbbi Kısıt Ekle'),findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
