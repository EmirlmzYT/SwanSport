import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../app/modules/console_module.dart';
import '../../app/theme/console_theme.dart';
import '../../app/shell/too_narrow_notice.dart';
import '../../app/widgets/status_pill.dart';

enum ConsoleClubStaffMode { inventory,health,sporting }
class ConsoleClubStaffOperationsScreen extends ConsumerWidget {
  const ConsoleClubStaffOperationsScreen({required this.mode,super.key});
  final ConsoleClubStaffMode mode;
  @override Widget build(BuildContext context,WidgetRef ref){
    if(MediaQuery.sizeOf(context).width<ConsoleDensity.minSupportedWidth)return const TooNarrowNotice();
    final access=ref.watch(consoleAccessProvider),club=ref.watch(activeClubProvider).valueOrNull;
    if(club==null)return const Center(child:Text('Aktif kulüp seçin.'));
    final id=club.id;
    final allowed=switch(mode){ConsoleClubStaffMode.inventory=>access.canReadClubInventory(id),ConsoleClubStaffMode.health=>access.canReadClubHealth(id),ConsoleClubStaffMode.sporting=>access.canReadClubPlanning(id)};
    if(!allowed||!ref.watch(featureEnabledProvider(FeatureFlags.clubStaffOperations)))return const Center(child:Text('Bu kulüp/modül için aktif ihtisas ve yayın yetkisi gerekli.'));
    final state=ref.watch(clubOperationControllerProvider(id));
    final title=switch(mode){ConsoleClubStaffMode.inventory=>'Malzeme & Zimmet Takibi',ConsoleClubStaffMode.health=>'Sağlık & İdari Dinlendirme',ConsoleClubStaffMode.sporting=>'Sportif Kadro Planlama'};
    final theme=Theme.of(context);
    return Padding(padding:const EdgeInsets.all(ConsoleDensity.xl),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text('$title · ${club.name}',style:theme.textTheme.headlineSmall)),IconButton(tooltip:'Yenile',onPressed:(){ref.invalidate(clubInventoryBoardProvider(id));ref.invalidate(clubHealthOperationsProvider(id));ref.invalidate(clubSportingOverviewProvider(id));},icon:const Icon(Icons.refresh))]),
      if(state.error!=null) Row(children:[Expanded(child:Text(state.error!)),if(state.pending) TextButton(onPressed:state.busy?null:()=>ref.read(clubOperationControllerProvider(id).notifier).retry(),child:const Text('Aynı işlemi tekrar dene'))]),
      if(state.busy)const LinearProgressIndicator(),
      const SizedBox(height:ConsoleDensity.lg),
      Expanded(child:switch(mode){
        ConsoleClubStaffMode.inventory=>ref.watch(clubInventoryBoardProvider(id)).when(loading:()=>const Center(child:CircularProgressIndicator()),error:(_,__)=>_retry(()=>ref.invalidate(clubInventoryBoardProvider(id))),data:(board)=>ListView(children:[
          if(access.canManageClubInventory(id)) Wrap(spacing:ConsoleDensity.md,children:[
            FilledButton.icon(onPressed:state.busy||state.pending?null:()=>showDialog<void>(context:context,builder:(_)=>_InventoryEditor(clubId:id,board:board,assign:false)),icon:const Icon(Icons.add),label:const Text('Malzeme Ekle')),
            FilledButton.tonalIcon(onPressed:state.busy||state.pending||board.items.isEmpty?null:()=>showDialog<void>(context:context,builder:(_)=>_InventoryEditor(clubId:id,board:board,assign:true)),icon:const Icon(Icons.assignment_outlined),label:const Text('Zimmet Ver'))]),
          const SizedBox(height:ConsoleDensity.lg),
          Text('Stok',style:theme.textTheme.titleLarge),
          if(board.items.isEmpty)const Text('Henüz envanter kaydı yok.'),
          for(final item in board.items) Card(child:ListTile(title:Text(item.name),subtitle:Text('${item.category} · ${item.quantity} toplam · ${item.damaged} hasarlı · ${item.missing} eksik'),
            trailing:StatusPill(label:'${item.available} kullanılabilir',tone:item.available>0?PillTone.good:PillTone.warning))),
          const SizedBox(height:ConsoleDensity.lg),
          Text('Teslim / İade Kayıtları',style:theme.textTheme.titleLarge),
          for(final a in board.assignments) Card(child:Padding(padding:const EdgeInsets.all(ConsoleDensity.lg),child:Row(children:[
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${a.itemName} · ${a.quantity} adet',style:theme.textTheme.titleMedium),
              Text('${a.targetReference} · ${fmtDate(a.assignedAt.toUtc().add(const Duration(hours:3)))}'),if(a.notes!=null)Text(a.notes!)])),
            StatusPill(label:a.outcome,tone:a.outcome=='pending'?PillTone.warning:a.outcome=='returned'?PillTone.good:PillTone.bad),
            if(a.returnedAt==null&&access.canManageClubInventory(id)) PopupMenuButton<String>(enabled:!state.busy&&!state.pending,tooltip:'İade sonucu',
              itemBuilder:(_)=>[for(final kind in ['returned','damaged','missing'])PopupMenuItem(value:kind,child:Text(kind=='returned'?'İade Al':kind=='damaged'?'Hasarlı':'Eksik'))],
              onSelected:(outcome) async {
                final actor=ref.read(authSessionProvider).valueOrNull?.user.id;
                final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Zimmeti Kapat'),content:Text('${a.quantity} adedin tamamı $outcome olarak kapanacak. Geri alınamaz.'),
                  actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Onayla'))]));
                if(ok==true&&context.mounted&&ref.read(authSessionProvider).valueOrNull?.user.id==actor&&ref.read(activeClubProvider).valueOrNull?.id==id)
                  await ref.read(clubOperationControllerProvider(id).notifier).submit('inventory_return',{'p_assignment':a.id,'p_outcome':outcome});
              })
          ]))),
          const Text('Üye kimliği özel referans koduyla gösterilir. Hesapsız sporcular için takım zimmeti kullanılır.'),
        ])),
        ConsoleClubStaffMode.health=>ref.watch(clubHealthOperationsProvider(id)).when(loading:()=>const Center(child:CircularProgressIndicator()),error:(_,__)=>_retry(()=>ref.invalidate(clubHealthOperationsProvider(id))),data:(rows)=>ListView(children:[
          const Text('Teşhis ve rapor metni tutulmaz. İdari dinlendirmeyi kaldırmak tıbbi kilidi kaldırmaz.'),
          for(final a in rows) Card(child:Padding(padding:const EdgeInsets.all(ConsoleDensity.lg),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(a.reference,style:theme.textTheme.titleMedium),Text(a.reason),
            Wrap(spacing:ConsoleDensity.sm,children:[
              if(access.canManageAdministrativeStatus(id)) ...[
                TextButton(onPressed:state.busy||state.pending?null:()=>ref.read(clubOperationControllerProvider(id).notifier).submit('set_club_athlete_rest',{'p_athlete':a.athleteId,'p_status':'rested','p_ends_at':null}),child:const Text('İdari Dinlendir')),
                if(a.restStatus!=null)TextButton(onPressed:state.busy||state.pending?null:()=>ref.read(clubOperationControllerProvider(id).notifier).submit('set_club_athlete_rest',{'p_athlete':a.athleteId,'p_status':'eligible','p_ends_at':null}),child:const Text('İdari Dinlenmeyi Kaldır'))],
              if(access.hasMedicalAuthorityForClub(id))TextButton(onPressed:state.busy||state.pending?null:()=>_medical(context,ref,id,a),child:Text(a.restrictionId==null?'Tıbbi Kısıt Ekle':'Tıbbi Kısıtı Kaldır')),
            ])]))),
        ])),
        ConsoleClubStaffMode.sporting=>ref.watch(clubSportingOverviewProvider(id)).when(loading:()=>const Center(child:CircularProgressIndicator()),error:(_,__)=>_retry(()=>ref.invalidate(clubSportingOverviewProvider(id))),data:(r)=>ListView(children:[
          Card(child:ListTile(title:Text('${r.athletes} sporcu · ${r.expiringLicenses} vize (30 gün)',style:theme.textTheme.titleLarge))),
          for(final t in r.teams)Card(child:ListTile(title:Text(t.name),trailing:Text('${t.athleteCount} sporcu'))),
          Card(child:ListTile(title:Text('30 gün: ${r.lockedLineups} kilitli esame · ${r.completedTransfers} tescilli transfer'),
            subtitle:Text('Yoklama: ${r.attendanceRate==null?'Veri yok':'%${r.attendanceRate!.toStringAsFixed(1)}'} · ${r.excused} izinli'))),
          for(final license in r.licenses)ListTile(title:Text('${license.reference} · ${license.sportCode}'),trailing:Text(fmtDate(license.expiresOn))),
          if(ref.watch(featureEnabledProvider(FeatureFlags.developmentReport))) Align(alignment:Alignment.centerLeft,child:TextButton.icon(
            onPressed:()=>showDialog<void>(context:context,builder:(_)=>_SportingReportDialog(clubId:id)),icon:const Icon(Icons.assessment_outlined),label:const Text('Dönem Gelişim Raporu'))),
          const Text('Transfer talebi iş akışı mevcut şemada bulunmuyor; bekleyen talep sayısı üretilmez.'),
        ])),
      }),
    ]));
  }
  Widget _retry(VoidCallback callback)=>Center(child:TextButton(onPressed:callback,child:const Text('Veri alınamadı. Tekrar dene')));
  Future<void> _medical(BuildContext context,WidgetRef ref,String clubId,ClubHealthOperation a) async {
    final actor=ref.read(authSessionProvider).valueOrNull?.user.id;
    final ok=await showDialog<bool>(context:context,builder:(context)=>AlertDialog(title:const Text('Yetkili Sağlık İşlemi'),content:const Text('Klinik durumu yalnız yetkili sağlık görevlisi doğrulayabilir.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('Doğrula'))]));
    if(ok!=true||!context.mounted||ref.read(authSessionProvider).valueOrNull?.user.id!=actor||ref.read(activeClubProvider).valueOrNull?.id!=clubId)return;
    await ref.read(clubOperationControllerProvider(clubId).notifier).submit(a.restrictionId==null?'open_health_restriction':'clear_health_restriction',a.restrictionId==null?
      {'p_athlete':a.athleteId,'p_status':'restricted','p_reevaluation':null,'p_evidence':null}:{'p_restriction':a.restrictionId,'p_note':'Yetkili sağlık görevlisi doğrulaması'});
  }
}
class _SportingReportDialog extends ConsumerStatefulWidget {
  const _SportingReportDialog({required this.clubId});final String clubId;
  @override ConsumerState<_SportingReportDialog> createState()=>_SportingReportDialogState();
}
class _SportingReportDialogState extends ConsumerState<_SportingReportDialog> {
  String? _athlete,_actor;int _offset=0;
  @override void initState(){super.initState();_actor=ref.read(authSessionProvider).valueOrNull?.user.id;}
  @override Widget build(BuildContext context){
    if(ref.watch(authSessionProvider).valueOrNull?.user.id!=_actor||!ref.watch(consoleAccessProvider).canReadClubPlanning(widget.clubId))return const AlertDialog(content:Text('Oturum/yetki değişti. Pencereyi kapatın.'));
    final athletes=ref.watch(reportAthletesProvider((query:'',offset:_offset)));
    final now=DateTime.now().toUtc().add(const Duration(hours:3));final to=DateTime(now.year,now.month,now.day);
    return AlertDialog(title:const Text('Dönem Gelişim Raporu · Son 30 Gün'),content:SizedBox(width:ConsoleDensity.loginCardWidth,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      athletes.when(loading:()=>const LinearProgressIndicator(),error:(_,__)=>TextButton(onPressed:()=>ref.invalidate(reportAthletesProvider),child:const Text('Sporcular alınamadı. Tekrar dene')),
        data:(page)=>Column(children:[DropdownButtonFormField<String>(value:page.athletes.any((a)=>a.id==_athlete)?_athlete:null,isExpanded:true,decoration:const InputDecoration(labelText:'Yetkili olduğum sporcu'),
          items:[for(final a in page.athletes)DropdownMenuItem(value:a.id,child:Text('${a.name} · ${a.clubName??''}',overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>_athlete=v)),
          Row(mainAxisAlignment:MainAxisAlignment.end,children:[IconButton(tooltip:'Önceki',onPressed:_offset==0?null:()=>setState((){_offset-=40;_athlete=null;}),icon:const Icon(Icons.chevron_left)),
            IconButton(tooltip:'Sonraki',onPressed:!page.hasMore?null:()=>setState((){_offset+=40;_athlete=null;}),icon:const Icon(Icons.chevron_right))])])),
      if(_athlete!=null)ref.watch(developmentReportProvider((athleteId:_athlete!,from:to.subtract(const Duration(days:29)),to:to))).when(
        loading:()=>const LinearProgressIndicator(),error:(_,__)=>const Text('Rapor alınamadı; kapsam ve yayın yetkisini kontrol edin.'),
        data:(r)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${r.attendance.present} katıldı · ${r.attendance.late} geç · ${r.attendance.absent} yok · ${r.attendance.excused} izinli'),
          Text('Devam: ${r.attendance.rate==null?'Veri yok':'%${r.attendance.rate}'}'),
          for(final m in r.metrics)Text('${m.name}: ${m.first} → ${m.last} ${m.unit} (${m.count} ölçüm)'),
          Text('${r.goals.length} güncel hedef · Eski dönem hedef yüzdesi değildir.'),
        ])),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Kapat'))]);
  }
}
class _InventoryEditor extends ConsumerStatefulWidget {
  const _InventoryEditor({required this.clubId,required this.board,required this.assign});
  final String clubId;final ClubInventoryBoard board;final bool assign;
  @override ConsumerState<_InventoryEditor> createState()=>_InventoryEditorState();
}
class _InventoryEditorState extends ConsumerState<_InventoryEditor> {
  final _name=TextEditingController(),_category=TextEditingController(),_quantity=TextEditingController();
  final _form=GlobalKey<FormState>();
  final _operation=refereeOperationId();
  String? _item,_target,_actor;
  @override void initState(){super.initState();_actor=ref.read(authSessionProvider).valueOrNull?.user.id;}
  @override void dispose(){_name.dispose();_category.dispose();_quantity.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    if(ref.watch(authSessionProvider).valueOrNull?.user.id!=_actor||ref.watch(activeClubProvider).valueOrNull?.id!=widget.clubId||!ref.watch(consoleAccessProvider).canManageClubInventory(widget.clubId))return const AlertDialog(content:Text('Oturum/kulüp/yetki değişti. Pencereyi kapatın.'));
    final state=ref.watch(clubOperationControllerProvider(widget.clubId)),locked=state.busy||state.pending;
    return PopScope(canPop:!locked,child:AlertDialog(title:Text(widget.assign?'Zimmet Ver':'Malzeme Ekle'),content:SizedBox(width:ConsoleDensity.loginCardWidth,child:SingleChildScrollView(child:Form(key:_form,child:Column(mainAxisSize:MainAxisSize.min,children:[
      if(!widget.assign)...[TextFormField(controller:_name,enabled:!locked,maxLength:120,decoration:const InputDecoration(labelText:'Malzeme adı'),validator:(v)=>v?.trim().isNotEmpty==true?null:'Ad gerekli'),
        TextFormField(controller:_category,enabled:!locked,maxLength:80,decoration:const InputDecoration(labelText:'Kategori'),validator:(v)=>v?.trim().isNotEmpty==true?null:'Kategori gerekli')],
      if(widget.assign)...[DropdownButtonFormField<String>(value:_item,isExpanded:true,decoration:const InputDecoration(labelText:'Malzeme'),items:[for(final i in widget.board.items.where((i)=>i.available>0&&i.status=='active')) DropdownMenuItem(value:i.id,child:Text('${i.name} · ${i.available}',overflow:TextOverflow.ellipsis))],validator:(v)=>v==null?'Malzeme seçin':null,onChanged:locked?null:(v)=>setState(()=>_item=v)),
        DropdownButtonFormField<String>(value:_target,isExpanded:true,decoration:const InputDecoration(labelText:'Üye / Takım'),items:[for(final t in widget.board.targets)DropdownMenuItem(value:'${t.kind}:${t.id}',child:Text(t.label,overflow:TextOverflow.ellipsis))],validator:(v)=>v==null?'Hedef seçin':null,onChanged:locked?null:(v)=>setState(()=>_target=v))],
      TextFormField(controller:_quantity,enabled:!locked,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Adet'),validator:(v){final n=int.tryParse(v??'');return n==null||n<1||n>1000000?'1–1.000.000 tam sayı girin':null;}),
      if(state.error!=null)Text(state.error!),
    ])))),actions:[TextButton(onPressed:locked?null:()=>Navigator.pop(context),child:const Text('Vazgeç')),FilledButton(onPressed:state.busy?null:()=>_save(state.pending),child:Text(state.pending?'Aynı İşlemi Tekrar Dene':'Kaydet'))]));
  }
  Future<void> _save(bool pending)async{
    if(!pending&&!_form.currentState!.validate())return;
    final ctrl=ref.read(clubOperationControllerProvider(widget.clubId).notifier),t=widget.assign?_target?.split(':'):null;
    final success=pending?await ctrl.retry():await ctrl.submit(widget.assign?'inventory_assign':'inventory_add_item',widget.assign?
      {'p_id':_operation,'p_item':_item,'p_quantity':int.parse(_quantity.text),'p_profile':t![0]=='profile'?t[1]:null,'p_team':t[0]=='team'?t[1]:null,'p_notes':null}:
      {'p_id':_operation,'p_club':widget.clubId,'p_name':_name.text.trim(),'p_category':_category.text.trim(),'p_quantity':int.parse(_quantity.text),'p_sport':null});
    if(success&&mounted&&ref.read(authSessionProvider).valueOrNull?.user.id==_actor)Navigator.pop(context);
  }
}
