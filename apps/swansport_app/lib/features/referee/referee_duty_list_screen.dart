import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../app/design/swan_palette.dart';
import '../../app/design/swan_shape.dart';
import '../../app/design/swan_type.dart';
import '../../app/widgets/swan_tabs.dart';
import 'referee_widgets.dart';

class RefereeDutyListScreen extends ConsumerStatefulWidget {
  const RefereeDutyListScreen({super.key});
  @override ConsumerState<RefereeDutyListScreen> createState()=>_DutyState();
}
class _DutyState extends ConsumerState<RefereeDutyListScreen> {
  int _tab=0;
  final _busy=<String>{};
  String? _error;
  Future<void> _respond(RefereeMatchSummary match,bool accept) async {
    if(_busy.contains(match.officialId)) return;
    final actorId=ref.read(authSessionProvider).valueOrNull?.user.id;
    String? reason;
    if(!accept) {
      final controller=TextEditingController();
      try {
        reason=await showDialog<String>(context:context,builder:(context)=>RefereeActorScope(actorId:actorId,child:AlertDialog(
          title:Text('Mazeret Bildir',style:SwanType.h3(context.swan.ink)),
          content:TextField(controller:controller,maxLength:500,style:SwanType.body(context.swan.ink),
            decoration:const InputDecoration(labelText:'Kısa mazeret açıklaması')),
          actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Vazgeç')),
            TextButton(onPressed:(){if(controller.text.trim().isNotEmpty) Navigator.pop(context,controller.text.trim());},child:const Text('Bildir'))])));
      } finally { controller.dispose(); }
      if(reason == null || !mounted) return;
    }
    setState((){_busy.add(match.officialId);_error=null;});
    try {
      final service=ref.read(sportsRolesServiceProvider);
      if(service == null) throw StateError('Çevrimiçi bağlantı gerekli');
      await service.respondMatchAssignment(match.officialId,accept,reason:reason);
    }catch(e){if(mounted)setState(()=>_error='$e');}
    finally{if(mounted)setState(()=>_busy.remove(match.officialId));}
  }
  @override Widget build(BuildContext context) {
    final gate=refereeGate(context,ref,'Hakem Görevleri');if(gate!=null)return gate;
    final async=ref.watch(refereeDutyMatchesProvider);final c=context.swan;
    return RefereePage(title:'Hakem Görevleri',child:Column(children:[
      SwanSegmentedTabs(labels:const ['Yaklaşan / Bugün','Tamamlananlar'],selected:_tab,onSelect:(i)=>setState(()=>_tab=i)),
      if(_error!=null) RefereeError(error:_error!,onRetry:()=>ref.invalidate(myRefereeMatchesProvider)),
      const SizedBox(height:SwanSpace.md),Expanded(child:async.when(
        loading:()=>const Center(child:CircularProgressIndicator()),
        error:(e,_)=>RefereeError(error:e,onRetry:()=>ref.invalidate(myRefereeMatchesProvider)),
        data:(matches){
          final rows=matches.where((m){final active=m.matchStatus=='scheduled' && (m.status==MatchOfficialStatus.assigned || m.status==MatchOfficialStatus.accepted);return _tab==0 ? active : !active;}).toList();
          if(rows.isEmpty)return Center(child:Text('Bu bölümde maç görevi yok.',style:SwanType.body(c.inkMuted)));
          return RefreshIndicator(onRefresh:()async{ref.invalidate(myRefereeMatchesProvider);await ref.read(myRefereeMatchesProvider(null).future);},
            child:ListView.separated(padding:const EdgeInsets.only(bottom:SwanSpace.xl*5),
              itemCount:rows.length,separatorBuilder:(_,__)=>const SizedBox(height:SwanSpace.md),itemBuilder:(context,i){final m=rows[i];
                return RefereePanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text('${m.homeClubName ?? 'Ev sahibi'} — ${m.awayClubName ?? 'Deplasman'}',style:SwanType.h3(c.ink)),
                  Text(refereeTime(m.startsAt),style:SwanType.bodySm(c.inkMuted)),
                  Text('${m.sportCode} · ${m.location ?? 'Saha belirtilmedi'}${m.cityCode==null ? '' : ' · İl ${m.cityCode}'}',style:SwanType.caption(c.inkMuted)),
                  Text('${refereeDutyLabel(m.duty)} · ${refereeStatusLabel(m.status)} · ${refereeMatchStatusLabel(m.matchStatus)}',style:SwanType.caption(c.ink)),
                  if(m.declineReason!=null)Text(m.declineReason!,style:SwanType.bodySm(c.inkMuted)),
                  const SizedBox(height:SwanSpace.md),
                  if(_busy.contains(m.officialId))const CircularProgressIndicator()
                  else if(m.status==MatchOfficialStatus.assigned && m.matchStatus=='scheduled')Wrap(spacing:SwanSpace.sm,runSpacing:SwanSpace.sm,children:[
                    RefereeButton(label:'Kabul Et',icon:Icons.check_rounded,onPressed:()=>_respond(m,true)),
                    RefereeButton(label:'Mazeret Bildir',icon:Icons.close_rounded,onPressed:()=>_respond(m,false))])
                  else if(m.canControl && refereeSupportsLive(m.sportCode) && m.matchStatus=='scheduled' && refereeSameDay(m.startsAt,DateTime.now()))
                    RefereeButton(label:'Müsabakayı Yönet',onPressed:()=>Navigator.pushNamed(context,'/hakem/esame/${m.matchId}')),
                  if(!refereeSupportsLive(m.sportCode))Text('Bu branşın canlı sonuç protokolü henüz açık değil.',style:SwanType.caption(c.inkMuted)),
                ]));}));}))]));
  }
}
