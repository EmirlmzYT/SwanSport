import 'package:swansport_design_system/swansport_design_system.dart';
import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../app/design/swan_palette.dart';
import '../../app/design/swan_shape.dart';
import '../../app/design/swan_type.dart';
import '../../app/widgets/swan_bottom_nav.dart';
import '../../app/widgets/swan_module_app_bar.dart';
import '../../app/widgets/swan_tabs.dart';

enum ClubStaffMode { inventory,health,sporting }
class ClubStaffOperationsScreen extends ConsumerStatefulWidget {
  const ClubStaffOperationsScreen({required this.mode,super.key});
  final ClubStaffMode mode;
  @override ConsumerState<ClubStaffOperationsScreen> createState()=>_ClubStaffOperationsScreenState();
}
class _ClubStaffOperationsScreenState extends ConsumerState<ClubStaffOperationsScreen> {
  int _tab=0;
  @override Widget build(BuildContext context){
    final c=context.swan;
    final access=ref.watch(swanAccessProvider);
    final club=ref.watch(activeClubProvider).valueOrNull;
    final title=switch(widget.mode){ClubStaffMode.inventory=>'Malzeme & Zimmet',ClubStaffMode.health=>'Sağlık & İdari Dinlendirme',ClubStaffMode.sporting=>'Sportif Kadro Planlama'};
    Widget body=Text('Aktif kulüp ve ihtisas yetkisi gerekli.',style:SwanType.body(c.ink));
    final allowed=club!=null&&switch(widget.mode){ClubStaffMode.inventory=>access.canReadClubInventory(club.id),ClubStaffMode.health=>access.canReadClubHealth(club.id),ClubStaffMode.sporting=>access.canReadClubPlanning(club.id)};
    if(allowed&&ref.watch(featureEnabledProvider(FeatureFlags.clubStaffOperations))){
      final activeClub=club;
      final id=activeClub.id;
      final mutation=ref.watch(clubOperationControllerProvider(id));
      body=Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(activeClub.name,style:SwanType.h3(c.ink)),
        if(mutation.error!=null) Card(child:Padding(padding:const EdgeInsets.all(SwanSpace.md),child:Column(children:[
          Text(mutation.error!,style:SwanType.bodySm(c.ink)),
          if(mutation.pending) TextButton(onPressed:mutation.busy?null:()=>ref.read(clubOperationControllerProvider(id).notifier).retry(),child:Text('Aynı işlemi tekrar dene',style:SwanType.bodySm(c.accent))),
        ]))),
        if(mutation.busy) const LinearProgressIndicator(),
        const SizedBox(height:SwanSpace.md),
        Expanded(child:switch(widget.mode){
          ClubStaffMode.inventory=>ref.watch(clubInventoryBoardProvider(id)).when(loading:()=>const Center(child:CircularProgressIndicator()),error:(_,__)=>_retry(()=>ref.invalidate(clubInventoryBoardProvider(id))),data:(board)=>Column(children:[
            SwanSegmentedTabs(labels:const ['Stok','Zimmet','Hasarlı/Eksik'],selected:_tab,onSelect:(i)=>setState(()=>_tab=i)),
            if(access.canManageClubInventory(id)) Wrap(spacing:SwanSpace.md,children:[
              TextButton.icon(onPressed:mutation.busy||mutation.pending?null:()=>_form(id,board,false),icon:const Icon(Icons.add),label:Text('Malzeme Ekle',style:SwanType.bodySm(c.accent))),
              TextButton.icon(onPressed:mutation.busy||mutation.pending||board.items.isEmpty?null:()=>_form(id,board,true),icon:const Icon(Icons.assignment_outlined),label:Text('Zimmet Ver',style:SwanType.bodySm(c.accent))),
            ]),
            Expanded(child:ListView(padding:const EdgeInsets.only(bottom:SwanSpace.xl*5),children:[
              if(_tab==0) ...[for(final i in board.items) _card(Text('${i.name} · ${i.category}\nKullanılabilir ${i.available}/${i.quantity} · Hasarlı ${i.damaged} · Eksik ${i.missing}',style:SwanType.body(c.ink)))],
              if(_tab!=0) ...[for(final a in board.assignments.where((a)=>_tab!=2||a.damagedReturnQuantity>0||a.missingReturnQuantity>0)) _card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('${a.itemName} · ${a.remainingQuantity}/${a.quantity} adet zimmette',style:SwanType.h3(c.ink)),
                Text('${a.targetReference} · ${fmtDate(a.assignedAt.toUtc().add(const Duration(hours:3)))} · ${a.outcome}',style:SwanType.bodySm(c.inkMuted)),
                if(a.resolvedQuantity>0)Text('İşlenen ${a.resolvedQuantity} · Hasarlı ${a.damagedReturnQuantity} · Eksik ${a.missingReturnQuantity}',style:SwanType.caption(c.inkMuted)),
                if(a.notes?.isNotEmpty==true) Text(a.notes!,style:SwanType.bodySm(c.ink)),
                if(a.returnedAt==null&&access.canManageClubInventory(id)) Wrap(spacing:SwanSpace.sm,children:[for(final status in ['returned','damaged','missing']) TextButton(
                  onPressed:mutation.busy||mutation.pending?null:()=>_confirmReturn(id,a,status),child:Text(switch(status){'returned'=>'İade Al','damaged'=>'Hasarlı','missing'=>'Eksik',_=>status},style:SwanType.bodySm(c.accent)))])])),],
              if(board.items.isEmpty) Text('Henüz envanter kaydı yok.',style:SwanType.body(c.inkMuted)),
              Text('Hesapsız sporcular için takım zimmeti kullanılır. Kişi hedefleri özel referans koduyla gösterilir.',style:SwanType.caption(c.inkMuted)),
            ])),
          ])),
          ClubStaffMode.health=>ref.watch(clubHealthOperationsProvider(id)).when(loading:()=>const Center(child:CircularProgressIndicator()),error:(_,__)=>_retry(()=>ref.invalidate(clubHealthOperationsProvider(id))),data:(rows)=>ListView(padding:const EdgeInsets.only(bottom:SwanSpace.xl*5),children:[
            Text('İdari dinlendirmeyi kaldırmak tıbbi kilidi kaldırmaz. Bu ekranda teşhis veya rapor notu tutulmaz.',style:SwanType.bodySm(c.inkMuted)),
            for(final a in rows) _card(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a.reference,style:SwanType.h3(c.ink)),Text(a.reason,style:SwanType.body(c.ink)),
              if(access.canManageAdministrativeStatus(id)) Wrap(children:[
                TextButton(onPressed:mutation.busy||mutation.pending?null:()=>_write(id,'set_club_athlete_rest',{'p_athlete':a.athleteId,'p_status':'rested','p_ends_at':null}),child:Text('İdari Dinlendir',style:SwanType.bodySm(c.accent))),
                if(a.restStatus!=null) TextButton(onPressed:mutation.busy||mutation.pending?null:()=>_write(id,'set_club_athlete_rest',{'p_athlete':a.athleteId,'p_status':'eligible','p_ends_at':null}),child:Text('İdari Dinlenmeyi Kaldır',style:SwanType.bodySm(c.accent))),
              ]),
              if(access.hasMedicalAuthorityForClub(id)) TextButton.icon(onPressed:mutation.busy||mutation.pending?null:()=>_confirmHealth(id,a),icon:const Icon(Icons.health_and_safety_outlined),
                label:Text(a.restrictionId==null?'Tıbbi Kısıt Ekle':'Tıbbi Kısıtı Kaldır',style:SwanType.bodySm(c.accent))),
            ])),
          ])),
          ClubStaffMode.sporting=>ref.watch(clubSportingOverviewProvider(id)).when(loading:()=>const Center(child:CircularProgressIndicator()),error:(_,__)=>_retry(()=>ref.invalidate(clubSportingOverviewProvider(id))),data:(overview)=>ListView(padding:const EdgeInsets.only(bottom:SwanSpace.xl*5),children:[
            _card(Text('${overview.athletes} sporcu · 30 gün içinde ${overview.expiringLicenses} lisans vizesi',style:SwanType.h3(c.ink))),
            for(final t in overview.teams) _card(Text('${t.name} · ${t.athleteCount} sporcu',style:SwanType.body(c.ink))),
            _card(Text('30 gün: ${overview.lockedLineups} kilitli esame · ${overview.completedTransfers} tescilli transfer\nYoklama: ${overview.attendanceRate==null?'Veri yok':'%${overview.attendanceRate!.toStringAsFixed(1)}'} · ${overview.excused} izinli',style:SwanType.body(c.ink))),
            for(final l in overview.licenses)Text('${l.reference} · ${l.sportCode} · ${fmtDate(l.expiresOn)}',style:SwanType.bodySm(c.ink)),
            if(ref.watch(featureEnabledProvider(FeatureFlags.developmentReport))) TextButton(onPressed:()=>Navigator.pushNamed(context,'/gelisim-raporu'),child:Text('Dönem Gelişim Raporu',style:SwanType.body(c.accent))),
            if(access.canUseTransferRequests&&ref.watch(featureEnabledProvider(FeatureFlags.transferRequests)))TextButton.icon(onPressed:()=>Navigator.pushNamed(context,'/transfer-talepleri'),icon:const Icon(Icons.swap_horiz_rounded),label:const Text('Transfer Talepleri')),
          ])),
        }),
      ]);
    }
    return SwanScaffold(backgroundColor:c.bg,appBar:swanModuleAppBar(context,title:title),bottomNavigationBar:const SwanBottomNav(),
      body:SafeArea(child:Padding(padding:const EdgeInsets.all(SwanSpace.lg),child:body)));
  }
  Widget _card(Widget child)=>Container(margin:const EdgeInsets.only(top:SwanSpace.md),padding:const EdgeInsets.all(SwanSpace.lg),
    decoration:BoxDecoration(color:context.swan.surface,borderRadius:BorderRadius.circular(SwanRadius.md)),child:child);
  Widget _retry(VoidCallback onRetry)=>Center(child:TextButton(onPressed:onRetry,child:Text('Veri alınamadı. Tekrar dene',style:SwanType.body(context.swan.ink))));
  Future<void> _write(String id,String rpc,Map<String,dynamic> payload) async {await ref.read(clubOperationControllerProvider(id).notifier).submit(rpc,payload);}
  Future<void> _confirmReturn(String id,ClubInventoryAssignment a,String status) async {
    final actor=ref.read(authSessionProvider).valueOrNull?.user.id;
    final quantity=await showDialog<int>(context:context,builder:(_)=>SwanQuantityDialog(maximum:a.remainingQuantity,title:switch(status){'returned'=>'Sağlam iade','damaged'=>'Hasarlı teslim',_=>'Kayıp / eksik'}));
    if(quantity!=null&&mounted&&ref.read(authSessionProvider).valueOrNull?.user.id==actor&&ref.read(activeClubProvider).valueOrNull?.id==id)await _write(id,'inventory_return_partial',{'p_op':refereeOperationId(),'p_assignment':a.id,'p_quantity':quantity,'p_outcome':status});
  }
  Future<void> _confirmHealth(String id,ClubHealthOperation a) async {
    final actor=ref.read(authSessionProvider).valueOrNull?.user.id;
    final confirmed=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Yetkili Sağlık İşlemi'),content:const Text('Yalnız yetkili sağlık görevlisi klinik durumu doğrulayarak bu işlemi yapabilir.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Doğrula'))]));
    if(confirmed==true&&mounted&&ref.read(authSessionProvider).valueOrNull?.user.id==actor&&ref.read(activeClubProvider).valueOrNull?.id==id)await _write(id,a.restrictionId==null?'open_health_restriction':'clear_health_restriction',a.restrictionId==null?
      {'p_athlete':a.athleteId,'p_status':'restricted','p_reevaluation':null,'p_evidence':null}:{'p_restriction':a.restrictionId,'p_note':'Yetkili sağlık görevlisi doğrulaması'});
  }
  Future<void> _form(String clubId,ClubInventoryBoard board,bool assign)=>showDialog<void>(context:context,builder:(_)=>_InventoryDialog(clubId:clubId,board:board,assign:assign));
}

class _InventoryDialog extends ConsumerStatefulWidget {
  const _InventoryDialog({required this.clubId,required this.board,required this.assign});
  final String clubId;final ClubInventoryBoard board;final bool assign;
  @override ConsumerState<_InventoryDialog> createState()=>_InventoryDialogState();
}
class _InventoryDialogState extends ConsumerState<_InventoryDialog> {
  final _name=TextEditingController(),_category=TextEditingController(),_quantity=TextEditingController();
  final _form=GlobalKey<FormState>();
  String? _item,_target,_actor;
  final _operation=refereeOperationId();
  @override void initState(){super.initState();_actor=ref.read(authSessionProvider).valueOrNull?.user.id;}
  @override void dispose(){_name.dispose();_category.dispose();_quantity.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    if(ref.watch(authSessionProvider).valueOrNull?.user.id!=_actor||ref.watch(activeClubProvider).valueOrNull?.id!=widget.clubId||!ref.watch(swanAccessProvider).canManageClubInventory(widget.clubId))return const AlertDialog(content:Text('Oturum/kulüp/yetki değişti. Pencereyi kapatın.'));
    final state=ref.watch(clubOperationControllerProvider(widget.clubId));final locked=state.busy||state.pending;
    final c=context.swan;
    return PopScope(canPop:!locked,child:AlertDialog(title:Text(widget.assign?'Zimmet Ver':'Malzeme Ekle',style:SwanType.h3(c.ink)),content:SingleChildScrollView(child:Form(key:_form,child:Column(mainAxisSize:MainAxisSize.min,children:[
      if(!widget.assign) ...[TextFormField(controller:_name,enabled:!locked,maxLength:120,decoration:const InputDecoration(labelText:'Malzeme adı'),validator:(v)=>v?.trim().isNotEmpty==true?null:'Ad gerekli'),
        TextFormField(controller:_category,enabled:!locked,maxLength:80,decoration:const InputDecoration(labelText:'Kategori'),validator:(v)=>v?.trim().isNotEmpty==true?null:'Kategori gerekli')],
      if(widget.assign) ...[DropdownButtonFormField<String>(value:_item,isExpanded:true,decoration:const InputDecoration(labelText:'Malzeme'),
        items:[for(final i in widget.board.items.where((i)=>i.available>0&&i.status=='active')) DropdownMenuItem(value:i.id,child:Text('${i.name} · ${i.available}',overflow:TextOverflow.ellipsis))],
        validator:(v)=>v==null?'Malzeme seçin':null,onChanged:locked?null:(v)=>setState(()=>_item=v)),
        DropdownButtonFormField<String>(value:_target,isExpanded:true,decoration:const InputDecoration(labelText:'Üye / Takım'),items:[for(final t in widget.board.targets) DropdownMenuItem(value:'${t.kind}:${t.id}',child:Text(t.label,overflow:TextOverflow.ellipsis))],
          validator:(v)=>v==null?'Hedef seçin':null,onChanged:locked?null:(v)=>setState(()=>_target=v))],
      TextFormField(controller:_quantity,enabled:!locked,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Adet'),validator:(v){final n=int.tryParse(v??'');return n==null||n<1||n>1000000?'1–1.000.000 tam sayı girin':null;}),
      if(state.error!=null)Text(state.error!,style:SwanType.bodySm(c.ink)),
    ]))),actions:[TextButton(onPressed:locked?null:()=>Navigator.pop(context),child:const Text('Vazgeç')),FilledButton(onPressed:state.busy?null:()=>_save(state.pending),child:Text(state.pending?'Aynı İşlemi Tekrar Dene':'Kaydet'))]));
  }
  Future<void> _save(bool pending) async {
    final controller=ref.read(clubOperationControllerProvider(widget.clubId).notifier);
    if(!pending&&!_form.currentState!.validate())return;
    final t=widget.assign?_target?.split(':'):null;
    final success=pending?await controller.retry():await controller.submit(widget.assign?'inventory_assign':'inventory_add_item',widget.assign?
      {'p_id':_operation,'p_item':_item,'p_quantity':int.parse(_quantity.text),'p_profile':t![0]=='profile'?t[1]:null,'p_team':t[0]=='team'?t[1]:null,'p_notes':null}:
      {'p_id':_operation,'p_club':widget.clubId,'p_name':_name.text.trim(),'p_category':_category.text.trim(),'p_quantity':int.parse(_quantity.text),'p_sport':null});
    if(success&&mounted&&ref.read(authSessionProvider).valueOrNull?.user.id==_actor)Navigator.pop(context);
  }
}
