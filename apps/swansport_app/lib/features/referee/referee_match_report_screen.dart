import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../app/design/swan_palette.dart';
import '../../app/design/swan_shape.dart';
import '../../app/design/swan_type.dart';
import 'referee_widgets.dart';

class RefereeMatchReportScreen extends ConsumerStatefulWidget {
  const RefereeMatchReportScreen({super.key,required this.matchId});
  final String matchId;
  @override ConsumerState<RefereeMatchReportScreen> createState()=>_ReportState();
}
class _ReportState extends ConsumerState<RefereeMatchReportScreen> {
  final _notes=TextEditingController();
  @override void dispose(){_notes.dispose();super.dispose();}
  Future<void> _sign(RefereeLiveState s) async {
    if(_notes.text.trim().isEmpty)return;
    final ok=await ref.read(refereeMutationProvider(widget.matchId).notifier).submit('referee_submit_match_report',{
      'p_match_id':widget.matchId,'p_operation_id':refereeOperationId(),'p_expected_version':s.version,'p_notes':_notes.text.trim()});
    if(ok && mounted)_done();
  }
  void _done(){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Resmi maç raporu sunucuda tescil edildi.')));
    Navigator.pushNamedAndRemoveUntil(context,'/hakem/gorevler',(r)=>r.isFirst);}
  @override Widget build(BuildContext context) {
    final gate=refereeGate(context,ref,'Resmi Maç Raporu');if(gate!=null)return gate;
    final c=context.swan;final mutation=ref.watch(refereeMutationProvider(widget.matchId));
    final async=ref.watch(refereeMatchStateProvider(widget.matchId));
    return PopScope(canPop:!mutation.busy && !mutation.pending,child:RefereePage(title:'Resmi Maç Raporu',child:async.when(
      loading:()=>const Center(child:CircularProgressIndicator()),
      error:(e,_)=>RefereeError(error:e,onRetry:()=>ref.invalidate(refereeMatchStateProvider(widget.matchId))),
      data:(s){if(s==null)return Text('Çevrimiçi maç kaydı gerekli.',style:SwanType.body(c.inkMuted));
        return ListView(padding:const EdgeInsets.only(bottom:SwanSpace.xl*5),children:[
          RefereePanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(s.sportCode=='tenis'?'Setler: ${s.sets.map((p)=>'${p.home}–${p.away}').join(' · ')}':'Sonuç: ${s.homeScore} — ${s.awayScore}',style:SwanType.h2(c.ink)),
            Text('Olay sürümü ${s.version} · ${s.events.where((e)=>e.kind!='undo' && !e.undone).length} geçerli olay',style:SwanType.caption(c.inkMuted)),
            if(s.reportRevisionId!=null)Text('Tescil: ${s.reportRevisionId}',style:SwanType.bodySm(c.success)),
            if(s.reportNotes!=null)Text(s.reportNotes!,style:SwanType.body(c.ink)),
          ])),const SizedBox(height:SwanSpace.lg),
          for(final e in s.events.where((e)=>e.kind!='undo' && !e.undone))Text('${e.elapsedSeconds~/60}′ · ${refereeEventLabel(e)} · ${e.side ?? 'Maç'}',style:SwanType.bodySm(c.ink)),
          const SizedBox(height:SwanSpace.lg),
          if(!s.isClosed)TextField(controller:_notes,maxLines:5,maxLength:500,enabled:!mutation.busy && !mutation.pending,
            style:SwanType.body(c.ink),decoration:const InputDecoration(labelText:'Hakem gözlem / saha olayları / disiplin sevki',helperText:'TC, telefon veya tıbbi teşhis yazma.'),onChanged:(_)=>setState((){})),
          if(mutation.busy)const Center(child:CircularProgressIndicator()),
          if(mutation.error!=null)RefereeError(error:mutation.error!,retryLabel:mutation.pending?'Aynı raporu tekrar dene':'Güncel kaydı yükle',onRetry:()async{
            if(mutation.pending){final ok=await ref.read(refereeMutationProvider(widget.matchId).notifier).retry();if(ok && mounted)_done();}
            else ref.invalidate(refereeMatchStateProvider(widget.matchId));}),
          const SizedBox(height:SwanSpace.lg),
          if(s.isClosed)RefereeButton(label:'Görevlere Dön',onPressed:()=>Navigator.pushNamedAndRemoveUntil(context,'/hakem/gorevler',(r)=>r.isFirst))
          else RefereeButton(label:'Resmi Maç Raporunu İmzala ve Tescil Et',icon:Icons.verified_rounded,
            onPressed:mutation.busy || mutation.pending || async.isLoading || _notes.text.trim().isEmpty || s.clockStartedAt!=null ? null : ()=>_sign(s)),
          Text('Bu işlem oturumunla sunucuya kaydolur; nitelikli elektronik imza değildir. Tescil sonrası hakem raporu değiştirilemez; düzeltme yetkili federasyon revizyonuyla yapılır.',style:SwanType.caption(c.inkMuted)),
        ]);} )));
  }
}
