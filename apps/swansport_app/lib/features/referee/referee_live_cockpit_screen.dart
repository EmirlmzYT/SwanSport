import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../app/design/swan_palette.dart';
import '../../app/design/swan_shape.dart';
import '../../app/design/swan_type.dart';
import 'referee_widgets.dart';

class RefereeLiveCockpitScreen extends ConsumerStatefulWidget {
  const RefereeLiveCockpitScreen({super.key,required this.matchId});
  final String matchId;
  @override ConsumerState<RefereeLiveCockpitScreen> createState()=>_LiveState();
}
class _LiveState extends ConsumerState<RefereeLiveCockpitScreen> {
  Timer? _ticker;
  @override void initState(){super.initState();_ticker=Timer.periodic(const Duration(seconds:1),(_){if(mounted && TickerMode.of(context))setState((){});});}
  @override void dispose(){_ticker?.cancel();super.dispose();}
  Future<void> _send(RefereeLiveState s,String kind,{String? side,String? athlete,String? replacement,String? card}) async {
    final mutation=ref.read(refereeMutationProvider(widget.matchId));
    if(mutation.busy || mutation.pending)return;
    await HapticFeedback.selectionClick();if(!mounted)return;
    await ref.read(refereeMutationProvider(widget.matchId).notifier).submit('referee_append_match_event',{
      'p_match_id':widget.matchId,'p_operation_id':refereeOperationId(),'p_expected_version':s.version,
      'p_kind':kind,'p_side':side,'p_athlete_id':athlete,'p_replacement_id':replacement,'p_card':card});
  }
  Future<void> _playerAction(RefereeLiveState s,List<RefereeLineupCandidate> candidates,bool substitution) async {
    final actorId=ref.read(authSessionProvider).valueOrNull?.user.id;
    var side='home';String? out;String? into;var card='yellow';
    String label(String id){final found=candidates.where((r)=>r.athleteId==id);return found.isEmpty ? '#${id.substring(0,6)}' : '${found.first.jerseyNumber ?? '—'} · ${found.first.name ?? found.first.maskedRef}';}
    final result=await showDialog<bool>(context:context,builder:(context)=>StatefulBuilder(builder:(context,setLocal){
      final active=s.squads['active_$side'] ?? const <String>[],bench=s.squads['bench_$side'] ?? const <String>[];
      return RefereeActorScope(actorId:actorId,child:AlertDialog(title:Text(substitution?'Oyuncu Değişikliği':'Kart / Faul',style:SwanType.h3(context.swan.ink)),
        content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
          DropdownButtonFormField<String>(value:side,decoration:const InputDecoration(labelText:'Takım'),
            items:const [DropdownMenuItem(value:'home',child:Text('Ev Sahibi')),DropdownMenuItem(value:'away',child:Text('Deplasman'))],
            onChanged:(v)=>setLocal((){side=v!;out=null;into=null;})),
          DropdownButtonFormField<String>(value:out,style:SwanType.body(context.swan.ink),decoration:InputDecoration(labelText:substitution?'Çıkan sporcu':'Sporcu'),
            items:[for(final id in active)DropdownMenuItem(value:id,child:Text(label(id),overflow:TextOverflow.ellipsis))],onChanged:(v)=>setLocal(()=>out=v)),
          if(substitution)DropdownButtonFormField<String>(value:into,style:SwanType.body(context.swan.ink),decoration:const InputDecoration(labelText:'Giren sporcu'),
            items:[for(final id in bench)DropdownMenuItem(value:id,child:Text(label(id),overflow:TextOverflow.ellipsis))],onChanged:(v)=>setLocal(()=>into=v))
          else DropdownButtonFormField<String>(value:card,decoration:const InputDecoration(labelText:'Olay'),
            items:const [DropdownMenuItem(value:'yellow',child:Text('Sarı Kart')),DropdownMenuItem(value:'red',child:Text('Kırmızı Kart')),
              DropdownMenuItem(value:'two_minutes',child:Text('2 dk Cezası')),DropdownMenuItem(value:'technical',child:Text('Teknik Faul'))],onChanged:(v)=>setLocal(()=>card=v!)),
        ])),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Vazgeç')),
          RefereeButton(label:'Kaydet',onPressed:out==null || (substitution && into==null) ? null : ()=>Navigator.pop(context,true))]));}));
    if(result==true && mounted)await _send(s,substitution?'substitution':'card',side:side,athlete:out,replacement:substitution?into:null,card:substitution?null:card);
  }
  @override Widget build(BuildContext context) {
    final gate=refereeGate(context,ref,'Canlı Hakem Kokpiti');if(gate!=null)return gate;
    final async=ref.watch(refereeMatchStateProvider(widget.matchId));
    final mutation=ref.watch(refereeMutationProvider(widget.matchId));
    final candidates=ref.watch(refereeLineupCandidatesProvider(widget.matchId)).asData?.value ?? const <RefereeLineupCandidate>[];
    final c=context.swan;
    return PopScope(canPop:!mutation.busy && !mutation.pending,child:RefereePage(title:'Canlı Hakem Kokpiti',child:async.when(
      loading:()=>const Center(child:CircularProgressIndicator()),
      error:(e,_)=>RefereeError(error:e,onRetry:()=>ref.invalidate(refereeMatchStateProvider(widget.matchId))),
      data:(s){if(s==null)return Text('Çevrimiçi maç kaydı gerekli.',style:SwanType.body(c.inkMuted));
        final seconds=s.secondsAt(DateTime.now());final blocked=mutation.busy || mutation.pending || s.isClosed || async.isLoading || !refereeSupportsLive(s.sportCode);
        return ListView(padding:const EdgeInsets.only(bottom:SwanSpace.xl*5),children:[
          RefereePanel(child:Column(children:[
            Text(s.sportCode=='tenis'?'Set ${s.period} · Oyun':'Periyot / Devre ${s.period}',style:SwanType.h3(c.ink)),
            Text('${s.sportCode=='tenis'?s.periodHome:s.homeScore} — ${s.sportCode=='tenis'?s.periodAway:s.awayScore}',style:SwanType.display(c.ink)),
            if(s.sets.isNotEmpty)Text('Tamamlananlar: ${s.sets.map((p)=>'${p.home}–${p.away}').join(' · ')}',style:SwanType.bodySm(c.inkMuted)),
            Text('${(seconds~/60).toString().padLeft(2,'0')}:${(seconds%60).toString().padLeft(2,'0')}',style:SwanType.stopwatch(c.ink)),
            Text(s.isClosed?'Resmi rapor tescilli':'Sunucu kaydı · sürüm ${s.version}',style:SwanType.caption(c.inkMuted)),
          ])),const SizedBox(height:SwanSpace.lg),
          if(mutation.busy)const Center(child:CircularProgressIndicator()),
          if(mutation.error!=null)RefereeError(error:mutation.error!,retryLabel:mutation.pending?'Aynı işlemi tekrar dene':'Güncel kaydı yükle',onRetry:(){
            if(mutation.pending)ref.read(refereeMutationProvider(widget.matchId).notifier).retry();else ref.invalidate(refereeMatchStateProvider(widget.matchId));}),
          Wrap(spacing:SwanSpace.sm,runSpacing:SwanSpace.sm,children:[
            RefereeButton(label:s.sportCode=='tenis'?'Ev · Oyun +1':'Ev · Skor +1',onPressed:blocked?null:()=>_send(s,'score',side:'home')),
            RefereeButton(label:s.sportCode=='tenis'?'Dep · Oyun +1':'Dep · Skor +1',onPressed:blocked?null:()=>_send(s,'score',side:'away')),
            RefereeButton(label:s.clockStartedAt==null?'Süreyi Başlat':'Süreyi Durdur',icon:Icons.timer_rounded,onPressed:blocked?null:()=>_send(s,s.clockStartedAt==null?'clock_start':'clock_pause')),
            RefereeButton(label:'Kart / Faul',icon:Icons.flag_rounded,onPressed:blocked || candidates.isEmpty?null:()=>_playerAction(s,candidates,false)),
            RefereeButton(label:'Oyuncu Değişikliği',icon:Icons.swap_horiz_rounded,onPressed:blocked || candidates.isEmpty?null:()=>_playerAction(s,candidates,true)),
            RefereeButton(label:s.sportCode=='tenis'?'Seti Bitir':'Periyot / Devre Bitir',onPressed:blocked?null:()=>_send(s,'period_end')),
            RefereeButton(label:'Son Olayı Geri Al',icon:Icons.undo_rounded,onPressed:blocked || !s.events.any((e)=>e.kind!='undo' && !e.undone)?null:()=>_send(s,'undo')),
            RefereeButton(label:s.isClosed?'Tescilli Rapor':'Müsabakayı Bitir ve Raporla',icon:Icons.fact_check_rounded,
              onPressed:mutation.busy || mutation.pending || s.clockStartedAt!=null ? null : ()=>Navigator.pushNamed(context,'/hakem/rapor/${widget.matchId}')),
          ]),
          Text('Raporlamadan önce süreyi durdur. Bağlantı belirsizse yeni olay eklemeden aynı işlemi tekrar dene.',style:SwanType.caption(c.inkMuted)),
          if(!refereeSupportsLive(s.sportCode))Text('Bu branşın canlı sonuç protokolü henüz desteklenmiyor.',style:SwanType.bodySm(c.inkMuted)),
          const SizedBox(height:SwanSpace.lg),Text('Olay Akışı',style:SwanType.h3(c.ink)),
          for(final e in s.events.reversed)Padding(padding:const EdgeInsets.only(top:SwanSpace.sm),child:RefereePanel(child:Text(
            '${e.elapsedSeconds~/60}′ · ${refereeEventLabel(e)}${e.side==null?'':' · ${e.side=='home'?'Ev Sahibi':'Deplasman'}'}${e.undone?' · Geri alındı':''}',
            style:SwanType.bodySm(e.undone?c.inkMuted:c.ink)))),
        ]);} )));
  }
}
