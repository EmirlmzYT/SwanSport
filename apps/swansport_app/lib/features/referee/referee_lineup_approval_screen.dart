import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../app/design/swan_palette.dart';
import '../../app/design/swan_shape.dart';
import '../../app/design/swan_type.dart';
import '../../app/widgets/swan_tabs.dart';
import 'referee_widgets.dart';

class RefereeLineupApprovalScreen extends ConsumerStatefulWidget {
  const RefereeLineupApprovalScreen({super.key,required this.matchId});
  final String matchId;
  @override ConsumerState<RefereeLineupApprovalScreen> createState()=>_LineupState();
}
class _LineupState extends ConsumerState<RefereeLineupApprovalScreen> {
  int _tab=0;bool _busy=false;String? _error;
  final _selections=<String,String>{};
  Future<void> _lock(List<RefereeLineupCandidate> rows) async {
    if(_busy)return;
    final selected=_selections.entries.where((e)=>e.value!='unselected').map((e)=>e.key).toSet();
    if(selected.any((id)=>!rows.any((r)=>r.athleteId==id && r.eligible))){
      setState(()=>_error='Seçtiğin kadro veya uygunluk değişti. Taslağı sıfırla ve güncel adayları yeniden seç.');return;
    }
    List<String> ids(String side,String role)=>[for(final r in rows)if(r.side==side && _selections[r.athleteId]==role && r.eligible)r.athleteId];
    if(ids('home','starter').isEmpty || ids('away','starter').isEmpty){setState(()=>_error='İki takım için sahaya çıkanları seç.');return;}
    setState((){_busy=true;_error=null;});
    try {
      final service=ref.read(sportsRolesServiceProvider);if(service==null)throw StateError('Çevrimiçi bağlantı gerekli');
      await service.verifyMatchLineup(widget.matchId,ids('home','starter'),ids('away','starter'),
        homeSubs:ids('home','substitute'),awaySubs:ids('away','substitute'));
      ref.invalidate(matchLineupApprovalsProvider(widget.matchId));
      ref.invalidate(refereeLineupCandidatesProvider(widget.matchId));
      if(mounted)Navigator.pushReplacementNamed(context,'/hakem/canli/${widget.matchId}');
    }catch(e){if(mounted)setState(()=>_error='$e');ref.invalidate(matchLineupApprovalsProvider(widget.matchId));}
    finally{if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context) {
    final gate=refereeGate(context,ref,'Dijital Esame');if(gate!=null)return gate;
    final c=context.swan;final approvals=ref.watch(matchLineupApprovalsProvider(widget.matchId));
    final locked=approvals.asData?.value.isNotEmpty ?? false;
    final async=ref.watch(refereeLineupCandidatesProvider(widget.matchId));
    return PopScope(canPop:!_busy,child:RefereePage(title:'Dijital Esame',child:Column(children:[
      SwanSegmentedTabs(labels:const ['Ev Sahibi','Deplasman'],selected:_tab,onSelect:(i)=>setState(()=>_tab=i)),
      if(_selections.isNotEmpty && !locked && !_busy)TextButton.icon(
        onPressed:()=>setState((){_selections.clear();_error=null;}),icon:Icon(Icons.restart_alt_rounded,color:c.inkMuted),
        label:Text('Taslağı Sıfırla',style:SwanType.bodySm(c.inkMuted))),
      if(_error!=null)RefereeError(error:_error!,onRetry:(){ref.invalidate(refereeLineupCandidatesProvider(widget.matchId));ref.invalidate(matchLineupApprovalsProvider(widget.matchId));}),
      if(approvals.hasError)RefereeError(error:approvals.error!,onRetry:()=>ref.invalidate(matchLineupApprovalsProvider(widget.matchId))),
      const SizedBox(height:SwanSpace.md),Expanded(child:async.when(
        loading:()=>const Center(child:CircularProgressIndicator()),
        error:(e,_)=>RefereeError(error:e,onRetry:()=>ref.invalidate(refereeLineupCandidatesProvider(widget.matchId))),
        data:(rows){final visible=rows.where((r)=>r.side==(_tab==0 ? 'home' : 'away')).toList();
          return Column(children:[Expanded(child:ListView.separated(itemCount:visible.length,
            separatorBuilder:(_,__)=>const SizedBox(height:SwanSpace.sm),itemBuilder:(context,i){final r=visible[i];
              final label=switch(r.eligibilityStatus){'medical'=>'Oynayamaz · Tıbbi Engel','suspended'=>'Cezalı','rested'=>'Dinlendiriliyor','license'=>'Vize / lisans engeli',_=>'Uygun'};
              final tone=r.eligibilityStatus=='rested' ? c.warning : r.eligible ? c.success : c.danger;
              return RefereePanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${r.jerseyNumber ?? '—'} · ${r.name ?? r.maskedRef}',style:SwanType.h3(c.ink)),
                Text('Lisans: ${r.licenseNumber ?? 'Yok'} · Vize: ${r.licenseExpiresOn==null ? 'Yok' : '${r.licenseExpiresOn!.day}.${r.licenseExpiresOn!.month}.${r.licenseExpiresOn!.year}'}',style:SwanType.caption(c.inkMuted)),
                Container(padding:const EdgeInsets.all(SwanSpace.sm),
                  decoration:BoxDecoration(color:c.surfaceAlt,borderRadius:BorderRadius.circular(SwanRadius.sm)),
                  child:Row(children:[Icon(r.eligible?Icons.check_circle_outline_rounded:Icons.block_rounded,color:tone),
                    const SizedBox(width:SwanSpace.sm),Expanded(child:Text(label,style:SwanType.caption(c.ink)))])),
                DropdownButtonFormField<String>(value:locked ? r.selection : _selections[r.athleteId] ?? 'unselected',
                  style:SwanType.body(c.ink),decoration:const InputDecoration(labelText:'Esame seçimi'),
                  items:const [DropdownMenuItem(value:'unselected',child:Text('Dışarıda')),
                    DropdownMenuItem(value:'starter',child:Text('Sahaya çıkan')),
                    DropdownMenuItem(value:'substitute',child:Text('Yedek'))],
                  onChanged:locked || _busy || !r.eligible ? null : (v)=>setState(()=>_selections[r.athleteId]=v!)),
              ]));})),const SizedBox(height:SwanSpace.md),
            if(_busy)const CircularProgressIndicator()
            else if(locked)RefereeButton(label:'Esame Kilitli · Canlı Kokpite Geç',icon:Icons.lock_rounded,onPressed:()=>Navigator.pushReplacementNamed(context,'/hakem/canli/${widget.matchId}'))
            else RefereeButton(label:'Esameyi Onayla ve Kilitle',icon:Icons.lock_rounded,
              onPressed:approvals.isLoading || approvals.hasError || rows.isEmpty ? null : ()=>_lock(rows)),
            Text('Kilit geri alınamaz. Sağlık ve kimlik koşulları sunucuda tekrar denetlenir.',style:SwanType.caption(c.inkMuted)),
          ]);} ))])));
  }
}
