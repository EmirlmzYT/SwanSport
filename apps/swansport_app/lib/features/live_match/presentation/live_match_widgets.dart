import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import 'match_follow_button.dart';

String liveSportName(String code)=>switch(code){'futbol'=>'Futbol','basketbol'=>'Basketbol','voleybol'=>'Voleybol','tenis'=>'Tenis',_=>code};
String liveClock(int seconds)=>'${(seconds~/60).toString().padLeft(2,'0')}:${(seconds%60).toString().padLeft(2,'0')}';
String liveStartTime(DateTime instant){final t=calendarTurkeyTime(instant);
  return '${t.day.toString().padLeft(2,'0')}.${t.month.toString().padLeft(2,'0')} · ${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}';}
String liveDutyName(String duty)=>switch(duty){'head_referee'=>'Başhakem','assistant_referee_1'=>'Yardımcı hakem',
  'assistant_referee_2'=>'Yardımcı hakem','fourth_referee'=>'Dördüncü hakem','table_official'=>'Masa hakemi','observer'=>'Gözlemci',_=>duty};

class LiveMatchCard extends StatelessWidget {
  const LiveMatchCard({super.key,required this.match});
  final PublicLiveMatchSummary match;
  @override
  Widget build(BuildContext context) {
    final c=context.swan;
    return Padding(padding:const EdgeInsets.only(bottom:SwanSpace.md),child:Material(
      color:c.surface,borderRadius:BorderRadius.circular(SwanRadius.md),clipBehavior:Clip.antiAlias,
      child:InkWell(onTap:()=>Navigator.pushNamed(context,'/canli-mac/${match.matchId}'),
        child:Padding(padding:const EdgeInsets.all(SwanSpace.lg),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Wrap(spacing:SwanSpace.sm,runSpacing:SwanSpace.xs,crossAxisAlignment:WrapCrossAlignment.center,children:[
            if(match.isLive)
              Container(padding:const EdgeInsets.symmetric(horizontal:SwanSpace.sm,vertical:SwanSpace.xs),
                decoration:BoxDecoration(color:c.danger.withValues(alpha:0.15),borderRadius:BorderRadius.circular(SwanRadius.sm)),
                child:Text('● CANLI · ${match.secondsAt(Duration.zero)~/60}′',style:SwanType.caption(c.danger,w:FontWeight.w700)))
            else if(match.isOfficialResult)
              Container(padding:const EdgeInsets.symmetric(horizontal:SwanSpace.sm,vertical:SwanSpace.xs),
                decoration:BoxDecoration(
                  color:(match.isRevisedResult?c.warning:c.accent).withValues(alpha:0.15),
                  borderRadius:BorderRadius.circular(SwanRadius.sm)),
                child:Text(match.isRevisedResult?'● REVİZE SONUÇ (V${match.resultVersion})':'✓ TESCİLLİ SONUÇ',
                  style:SwanType.caption(match.isRevisedResult?c.warning:c.accent,w:FontWeight.w700)))
            else
              Text('PLANLANDI',style:SwanType.caption(c.inkMuted)),
            Text(liveSportName(match.sportCode),style:SwanType.caption(c.inkMuted)),
            MatchFollowIndicator(matchId:match.matchId),
          ]),
          const SizedBox(height:SwanSpace.sm),
          LiveScoreboard(match:match,compact:true),
          if(match.isOfficialResult && match.revisionReason!=null && match.revisionReason!.isNotEmpty)
            Padding(padding:const EdgeInsets.only(top:SwanSpace.xs),
              child:Row(children:[
                Icon(Icons.history_edu_rounded,size:14,color:c.inkMuted),
                const SizedBox(width:SwanSpace.xs),
                Expanded(child:Text(match.revisionReason!,maxLines:1,overflow:TextOverflow.ellipsis,style:SwanType.caption(c.inkMuted))),
              ])),
          if(match.programName!=null) Padding(padding:const EdgeInsets.only(top:SwanSpace.sm),
            child:Text(match.programName!,maxLines:2,overflow:TextOverflow.ellipsis,style:SwanType.caption(c.inkMuted))),
          if(match.location?.isNotEmpty==true) Text(match.location!,maxLines:2,overflow:TextOverflow.ellipsis,style:SwanType.caption(c.inkMuted)),
          if(match.startsAt!=null)Text(liveStartTime(match.startsAt!),style:SwanType.caption(c.inkMuted)),
        ])),
      )));
  }
}

class LiveScoreboard extends StatefulWidget {
  const LiveScoreboard({super.key,required this.match,this.compact=false,this.elapsedClock});
  final PublicLiveMatchSummary match;
  final bool compact;
  /// Optional monotonic source for deterministic tests; production owns a Stopwatch.
  final Duration Function()? elapsedClock;
  @override
  State<LiveScoreboard> createState()=>_LiveScoreboardState();
}
class _LiveScoreboardState extends State<LiveScoreboard> with WidgetsBindingObserver {
  final _elapsed=Stopwatch();Timer? _timer;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_reset();}
  @override void didUpdateWidget(covariant LiveScoreboard old){super.didUpdateWidget(old);
    if(!identical(old.match,widget.match)||old.compact!=widget.compact)_reset();}
  void _reset(){_timer?.cancel();_elapsed.reset();_elapsed.start();_tick();}
  void _tick(){_timer?.cancel();if(!widget.compact&&widget.match.clockRunning
    && (WidgetsBinding.instance.lifecycleState==null||WidgetsBinding.instance.lifecycleState==AppLifecycleState.resumed))
      _timer=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState((){});});}
  @override void didChangeAppLifecycleState(AppLifecycleState state){_tick();}
  @override void dispose(){_timer?.cancel();_elapsed.stop();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override
  Widget build(BuildContext context){final c=context.swan;final m=widget.match;
    Widget team(String? name,String? logo)=>Column(children:[
        SizedBox(width:widget.compact?SwanSpace.xl:SwanSpace.xl*2,height:widget.compact?SwanSpace.xl:SwanSpace.xl*2,child:logo==null
          ? Icon(Icons.shield_outlined,color:c.inkMuted,size:SwanSpace.xl)
          : Image.network(logo,fit:BoxFit.contain,errorBuilder:(_,__,___)=>Icon(Icons.shield_outlined,color:c.inkMuted))),
        const SizedBox(height:SwanSpace.sm),
      Text(name??'Takım henüz belli değil',textAlign:TextAlign.center,maxLines:3,
        overflow:TextOverflow.ellipsis,style:SwanType.body(c.ink)),
    ]);
    return Column(children:[Row(children:[
      Expanded(child:team(m.homeClubName,m.homeClubLogo)),
      const SizedBox(width:SwanSpace.md),
      Expanded(child:team(m.awayClubName,m.awayClubLogo)),
    ]),const SizedBox(height:SwanSpace.sm),
      Center(child:FittedBox(fit:BoxFit.scaleDown,child:Text('${m.homeScore??'–'} : ${m.awayScore??'–'}',
        style:widget.compact?SwanType.h3(c.ink):SwanType.h2(c.ink)))),
    if(!widget.compact) ...[
      const SizedBox(height:SwanSpace.lg),
      Text(m.isLive?liveClock(m.secondsAt(widget.elapsedClock?.call()??_elapsed.elapsed)):m.status=='played'
        ?(m.homeScore==null||m.awayScore==null?'Sonuç tescilli; sayısal skor mevcut değil.':'Kesinleşmiş sonuç'):'Maç başlamadı',
        style:SwanType.h2(c.ink)),
      if(m.isLive) Text('${m.period??1}. ${m.sportCode=='tenis'?'Set':'Periyot'} · ${m.clockRunning?'Süre akıyor':'Süre durdu'}',style:SwanType.caption(c.inkMuted)),
      if(m.sportCode=='tenis'&&(m.sets.isNotEmpty||m.isLive)) ...[
        const SizedBox(height:SwanSpace.sm),
        Wrap(spacing:SwanSpace.sm,runSpacing:SwanSpace.xs,children:[
          for(var i=0;i<m.sets.length;i++)Text('${i+1}. Set ${m.sets[i].home}–${m.sets[i].away}',style:SwanType.bodySm(c.ink)),
          if(m.isLive)Text('Güncel set: ${m.periodHome??0}–${m.periodAway??0}',style:SwanType.bodySm(c.ink)),
        ]),
      ],
    ]]);
  }
}

class LiveMatchStrip extends ConsumerWidget {
  const LiveMatchStrip({super.key});
  @override Widget build(BuildContext context,WidgetRef ref){
    if(!ref.watch(featureEnabledProvider(FeatureFlags.liveMatchHub)))return const SizedBox.shrink();
    final async=ref.watch(publicLiveMatchesProvider);
    if(async.hasError)return const SizedBox.shrink();
    final live=(async.valueOrNull??const <PublicLiveMatchSummary>[]).where((m)=>m.isLive).take(1).toList();
    if(live.isEmpty)return const SizedBox.shrink();
    return Padding(padding:const EdgeInsets.all(SwanSpace.lg),child:Column(children:[
      for(final m in live)LiveMatchCard(match:m),
      TextButton(onPressed:()=>Navigator.pushNamed(context,'/canli-skor'),child:const Text('Tüm Canlı Skorlar')),
    ]));
  }
}
