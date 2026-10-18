import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/swan_module_app_bar.dart';
import '../../../app/widgets/swan_bottom_nav.dart';
import '../../../app/widgets/swan_tabs.dart';
import 'live_match_widgets.dart';
import 'league_standings_view.dart';

class LiveMatchHubScreen extends ConsumerStatefulWidget {
  const LiveMatchHubScreen({super.key});
  @override ConsumerState<LiveMatchHubScreen> createState()=>_LiveMatchHubScreenState();
}
class _LiveMatchHubScreenState extends ConsumerState<LiveMatchHubScreen> {
  int _tab=0;String? _sport;
  @override Widget build(BuildContext context){final c=context.swan;
    final enabled=ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub));
    final standings=ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings));
    final tab=_tab==3&&!standings?0:_tab;
    final AutoDisposeFutureProvider<List<PublicLiveMatchSummary>> matchesProvider=_sport==null?publicLiveMatchesProvider:publicLiveMatchesForSportProvider(_sport);
    return SwanScaffold(backgroundColor:c.bg,appBar:swanModuleAppBar(context,title:'Canlı Skor Merkezi'),
      bottomNavigationBar:const SwanBottomNav(),
      body:!enabled?Center(child:Text('Canlı skor merkezi henüz kullanıma açılmadı.',style:SwanType.body(c.inkMuted)))
      :Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(SwanSpace.lg,SwanSpace.xs,SwanSpace.lg,SwanSpace.md),
          child:SwanPillTabs(labels:['Canlı','Günün Maçları','Bitenler',if(standings)'Puan Durumu'],selected:tab,onSelect:(i)=>setState(()=>_tab=i))),
        Padding(padding:const EdgeInsets.symmetric(horizontal:SwanSpace.lg),child:SingleChildScrollView(scrollDirection:Axis.horizontal,
          child:Row(children:[for(final s in <String?>[null,'futbol','basketbol','voleybol','tenis'])
            Padding(padding:const EdgeInsets.only(right:SwanSpace.sm),child:ChoiceChip(label:Text(s==null?'Tümü':liveSportName(s),style:SwanType.caption(c.ink)),
              selectedColor:c.accentSoft,backgroundColor:c.surface,side:BorderSide.none,
              selected:_sport==s,onSelected:(_)=>setState(()=>_sport=s))),]))),
        const SizedBox(height:SwanSpace.md),
        if(tab!=3)Text('En fazla 200 maç gösterilir.',style:SwanType.caption(c.inkMuted)),
        Expanded(child:tab==3?ListView(padding:const EdgeInsets.fromLTRB(SwanSpace.lg,SwanSpace.sm,SwanSpace.lg,SwanSpace.xl*5),
          children:[LeagueStandingsSelector(sport:_sport)]):ref.watch(matchesProvider).when(
          loading:()=>const Center(child:CircularProgressIndicator()),
          error:(_,__)=>Center(child:TextButton(onPressed:()=>ref.invalidate(matchesProvider),child:const Text('Skorlar alınamadı. Yeniden dene'))),
          data:(items){final matches=items.where((m)=>(_sport==null||m.sportCode==_sport)&&
            (tab==0?m.isLive:tab==1?m.isToday:m.status=='played')).toList();
            return RefreshIndicator(onRefresh:()async{ref.invalidate(matchesProvider);await ref.read(matchesProvider.future);},
              child:ListView(padding:const EdgeInsets.fromLTRB(SwanSpace.lg,SwanSpace.sm,SwanSpace.lg,SwanSpace.xl*5),
                physics:const AlwaysScrollableScrollPhysics(),children:matches.isEmpty
                  ?[Text('Bu filtrede maç bulunmuyor.',style:SwanType.body(c.inkMuted))]
                  :[for(final m in matches)LiveMatchCard(match:m)]));
          },
        )),
      ]));
  }
}
