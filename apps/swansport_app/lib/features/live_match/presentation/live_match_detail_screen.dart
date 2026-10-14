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
import 'match_follow_button.dart';

class LiveMatchDetailScreen extends ConsumerStatefulWidget {
  const LiveMatchDetailScreen({super.key,required this.matchId});
  final String matchId;
  @override ConsumerState<LiveMatchDetailScreen> createState()=>_LiveMatchDetailScreenState();
}
class _LiveMatchDetailScreenState extends ConsumerState<LiveMatchDetailScreen> {
  int _tab=0;
  @override Widget build(BuildContext context){final c=context.swan;
    final enabled=ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub));
    final standings=ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings));
    final tab=_tab==2&&!standings?0:_tab;
    return Scaffold(backgroundColor:c.bg,appBar:swanModuleAppBar(context,title:'Canlı Müsabaka'),bottomNavigationBar:const SwanBottomNav(),
      body:!enabled?Center(child:Text('Canlı skor merkezi henüz kullanıma açılmadı.',style:SwanType.body(c.inkMuted)))
      :ref.watch(publicMatchLiveStateProvider(widget.matchId)).when(
        loading:()=>const Center(child:CircularProgressIndicator()),
        error:(_,__)=>Center(child:TextButton(onPressed:()=>ref.invalidate(publicMatchLiveStateProvider(widget.matchId)),child:const Text('Maç alınamadı. Yeniden dene'))),
        data:(detail)=>detail==null?Center(child:Text('Maç bulunamadı veya yayına açık değil.',style:SwanType.body(c.inkMuted)))
        :RefreshIndicator(onRefresh:()async{
          ref.invalidate(publicMatchLiveStateProvider(widget.matchId));ref.invalidate(publicMatchRosterProvider(widget.matchId));
          ref.invalidate(matchStandingsContextProvider(widget.matchId));ref.invalidate(leagueStandingsProvider);
          await ref.read(publicMatchLiveStateProvider(widget.matchId).future);
        },child:ListView(physics:const AlwaysScrollableScrollPhysics(),
          padding:const EdgeInsets.fromLTRB(SwanSpace.lg,SwanSpace.lg,SwanSpace.lg,SwanSpace.xl*5),children:[
            Container(padding:const EdgeInsets.all(SwanSpace.lg),decoration:BoxDecoration(color:c.surface,borderRadius:BorderRadius.circular(SwanRadius.md)),
              child:LiveScoreboard(match:detail.summary)),
            MatchFollowButton(key:ValueKey(widget.matchId),matchId:widget.matchId),
            const SizedBox(height:SwanSpace.lg),
            Text(detail.summary.programName??'Resmi müsabaka',style:SwanType.h3(c.ink)),
            if(detail.summary.location!=null)Text(detail.summary.location!,style:SwanType.bodySm(c.inkMuted)),
            if(detail.summary.cityCode!=null)Text('İl kodu: ${detail.summary.cityCode}',style:SwanType.caption(c.inkMuted)),
            for(final official in detail.officials)Text('${liveDutyName(official.duty)} · ${official.name}',style:SwanType.bodySm(c.inkMuted)),
            const SizedBox(height:SwanSpace.lg),
            SwanPillTabs(labels:['Olay Akışı','Kadrolar',if(standings)'Puan Durumu'],selected:tab,onSelect:(i)=>setState(()=>_tab=i)),
            const SizedBox(height:SwanSpace.lg),
            if(tab==0) ...[
              if(detail.events.isEmpty)Text('Henüz yayımlanmış maç olayı yok.',style:SwanType.bodySm(c.inkMuted)),
              for(final event in detail.events) _event(context,event),
            ] else if(tab==2) MatchLeagueStandingsView(matchId:widget.matchId)
            else ref.watch(publicMatchRosterProvider(widget.matchId)).when(
              loading:()=>const Center(child:CircularProgressIndicator()),
              error:(_,__)=>TextButton(onPressed:()=>ref.invalidate(publicMatchRosterProvider(widget.matchId)),child:const Text('Kadro alınamadı. Yeniden dene')),
              data:(roster)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                if(roster==null||roster.players.isEmpty)Text('Kilitlenmiş esame henüz yayımlanmadı.',style:SwanType.bodySm(c.inkMuted)),
                if(roster!=null)for(final side in ['home','away'])for(final selection in ['starter','substitute']) ...[
                  Text('${side=='home'?'Ev Sahibi':'Deplasman'} · ${selection=='starter'?'İlk Kadro':'Yedekler'}',style:SwanType.h3(c.ink)),
                  for(final player in roster.players.where((p)=>p.side==side&&p.selection==selection))
                    Padding(padding:const EdgeInsets.symmetric(vertical:SwanSpace.sm),child:Text(
                      '${player.jerseyNumber??'–'} · ${player.name}${player.position==null?'':' · ${player.position}'}',style:SwanType.body(c.ink))),
                  const SizedBox(height:SwanSpace.lg),
                ],
              ]),
            ),
          ])),
      ));
  }
  Widget _event(BuildContext context,PublicLiveMatchEvent e){final c=context.swan;
    final label=switch(e.kind){'score'=>'Sayı / Gol','card'=>e.card=='red'?'Kırmızı kart':e.card=='yellow'?'Sarı kart':'Kart / Faul',
      'substitution'=>'Oyuncu değişikliği','period_end'=>'Periyot / Set sonu',_=>'Maç olayı'};
    final color=e.kind=='card'?(e.card=='red'?c.danger:c.warning):c.ink;
    return Padding(padding:const EdgeInsets.only(bottom:SwanSpace.md),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('${e.minute}′',style:SwanType.caption(c.inkMuted)),const SizedBox(width:SwanSpace.md),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(label,style:SwanType.body(color)),
        Text('${e.side=='home'?'Ev Sahibi':e.side=='away'?'Deplasman':'Müsabaka'} · ${e.period}. periyot',style:SwanType.caption(c.inkMuted)),
        if(e.athleteName!=null)Text('${e.athleteName}${e.replacementName==null?'':' → ${e.replacementName}'}',style:SwanType.bodySm(c.ink)),
      ])),
    ]));
  }
}
