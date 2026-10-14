import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../app/modules/console_module.dart';
import '../../app/shell/too_narrow_notice.dart';
import '../../app/theme/console_theme.dart';
import 'league_standings_panel.dart';
import 'referee_assignments_screen.dart';

class ProvincialLeaguesScreen extends ConsumerStatefulWidget {
  const ProvincialLeaguesScreen({super.key});
  @override ConsumerState<ProvincialLeaguesScreen> createState()=>_ProvincialLeaguesScreenState();
}
class _ProvincialLeaguesScreenState extends ConsumerState<ProvincialLeaguesScreen> {
  bool _standings=false;
  @override Widget build(BuildContext context){
    if(MediaQuery.sizeOf(context).width<ConsoleDensity.minSupportedWidth)return const TooNarrowNotice();
    if(!ref.watch(consoleAccessProvider).canViewProvincialLeagues)return const Center(child:Text('Bu modül için aktif federasyon görevi gerekli.'));
    final enabled=ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings));
    return Column(children:[
      if(enabled)Padding(padding:const EdgeInsets.all(ConsoleDensity.lg),child:Wrap(spacing:ConsoleDensity.sm,children:[
        ChoiceChip(label:const Text('Fikstür & Maçlar'),selected:!_standings,onSelected:(_)=>setState(()=>_standings=false)),
        ChoiceChip(label:const Text('Puan Durumu'),selected:_standings,onSelected:(_)=>setState(()=>_standings=true)),
      ])),
      Expanded(child:_standings&&enabled?const ConsoleLeagueStandingsPanel():const FederationFixtureBoard(assignments:false)),
    ]);
  }
}
