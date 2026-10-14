import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../app/modules/console_module.dart';
import '../../app/shell/too_narrow_notice.dart';
import '../../app/theme/console_theme.dart';
import '../../app/widgets/console_table.dart';
import '../../app/widgets/status_pill.dart';

class ConsoleLeagueStandingsPanel extends ConsumerStatefulWidget {
  const ConsoleLeagueStandingsPanel({super.key});
  @override ConsumerState<ConsoleLeagueStandingsPanel> createState()=>_ConsoleLeagueStandingsPanelState();
}
class _ConsoleLeagueStandingsPanelState extends ConsumerState<ConsoleLeagueStandingsPanel> {
  String? _org,_city;
  bool _live=false;
  ConsoleTableQuery _query=const ConsoleTableQuery();
  @override Widget build(BuildContext context){
    if(MediaQuery.sizeOf(context).width<ConsoleDensity.minSupportedWidth)return const TooNarrowNotice();
    final access=ref.watch(consoleAccessProvider);
    if(!access.canViewProvincialLeagues)return const Center(child:Text('Aktif federasyon görevi gerekli.'));
    if(!ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings)))return const Center(child:Text('Puan durumu henüz kullanıma açılmadı.'));
    final scopes=ref.watch(federationConsoleScopesProvider);
    if(scopes.asData==null)return Center(child:scopes.hasError?TextButton(onPressed:()=>ref.invalidate(federationConsoleScopesProvider),child:const Text('Yetki kapsamı alınamadı. Tekrar dene')):const CircularProgressIndicator());
    final s=scopes.asData!.value;
    return ref.watch(standingsLeaguesProvider).when(
      loading:()=>const Center(child:CircularProgressIndicator()),
      error:(_,__)=>Center(child:TextButton(onPressed:()=>ref.invalidate(standingsLeaguesProvider),child:const Text('Ligler alınamadı. Tekrar dene'))),
      data:(all){
        // Central access admits the module; authoritative server scopes constrain
        // its provincial view. The rows themselves are already public, not private.
        final permitted=all.where((l)=>s.any((e)=>e.federationId==l.federationId&&e.sportCode==l.sportCode&&
          (e.role=='president'||(e.role=='provincial_rep'&&e.cityCode==l.cityCode)))).toList();
        final cities=permitted.map((l)=>l.cityCode).toSet();
        final city=cities.contains(_city)?_city:(!access.isFederationPresident&&cities.length==1?cities.single:null);
        final leagues=permitted.where((l)=>city==null||l.cityCode==city).toList();
        if(leagues.isEmpty)return const Center(child:Text('Yetki kapsamınızda yayımlanmış lig yok. Gizli ligler bu genel tabloda gösterilmez.'));
        final league=leagues.firstWhere((l)=>l.id==_org,orElse:()=>leagues.first);
        final provider=leagueStandingsProvider((orgId:league.id,includeLive:_live));
        final state=ref.watch(provider);final rows=state.asData?.value??const <LeagueStandingsRow>[];
        final pages=(rows.length/_query.pageSize).ceil();
        final query=_query.page>=pages?_query.copyWith(page:pages==0?0:pages-1):_query;
        final page=rows.skip(query.offset).take(query.pageSize).toList();
        return Padding(padding:const EdgeInsets.all(ConsoleDensity.xl),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Lig Puan Durumu',style:Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height:ConsoleDensity.md),
          Row(children:[SizedBox(width:ConsoleDensity.sidebarWidth,child:DropdownButtonFormField<String>(value:city,
            decoration:const InputDecoration(labelText:'İl kapsamı'),items:[
              if(access.isFederationPresident||cities.length>1||cities.contains(null))const DropdownMenuItem<String>(value:null,child:Text('Yetkili olduğum tüm iller / Ulusal')),
              for(final c in cities.whereType<String>())DropdownMenuItem(value:c,child:Text('İl $c'))],
            onChanged:!access.isFederationPresident&&cities.length==1?null:(v)=>setState((){_city=v;_org=null;_query=const ConsoleTableQuery();}))),
            const SizedBox(width:ConsoleDensity.md),Expanded(child:DropdownButtonFormField<String>(key:ValueKey(league.id),value:league.id,isExpanded:true,
              decoration:const InputDecoration(labelText:'Yayımlanmış lig'),items:[for(final l in leagues)DropdownMenuItem(value:l.id,child:Text(l.name,overflow:TextOverflow.ellipsis))],
              onChanged:(v)=>setState((){_org=v;_query=const ConsoleTableQuery();}))),
            IconButton(tooltip:'Yenile',onPressed:(){ref.invalidate(provider);ref.invalidate(standingsLeaguesProvider);},icon:const Icon(Icons.refresh)),
          ]),
          Row(children:[Switch(value:_live,onChanged:(v)=>setState((){_live=v;_query=const ConsoleTableQuery();})),
            Text(_live?'Canlı puan durumu · geçici':'Yalnız resmi sonuçlar'),const SizedBox(width:ConsoleDensity.lg),
            Text('G/B/M puanı: ${league.winPoints}/${league.drawPoints}/${league.lossPoints}')]),
          const Text('Sıra: puan, averaj, atılan sayı, takım adı. Son 5: eskiden yeniye. Grup/eleme ve özel bonus kuralları yoktur.'),
          if(state.hasError)TextButton(onPressed:()=>ref.invalidate(provider),child:const Text('Tablo alınamadı. Tekrar dene')),
          Expanded(child:ConsoleTable<LeagueStandingsRow>(query:query,onQueryChanged:(v)=>setState(()=>_query=v),
            totalCount:rows.length,rows:page,rowId:(r)=>r.participantId,loading:state.isLoading,error:state.error,
            emptyMessage:'Yayımlanmış tablo bulunmuyor.',columns:[
              ConsoleColumn(label:'#',width:ConsoleDensity.xxl,cell:(r)=>Text('${r.rank}')),
              ConsoleColumn(label:'Takım',flex:3,cell:(r)=>Row(children:[
                if(r.clubLogo?.isNotEmpty==true)...[Image.network(r.clubLogo!,width:ConsoleDensity.brandMarkSize,height:ConsoleDensity.brandMarkSize,fit:BoxFit.contain,
                  errorBuilder:(_,__,___)=>const Icon(Icons.shield_outlined)),const SizedBox(width:ConsoleDensity.sm)],
                Expanded(child:Text(r.name,overflow:TextOverflow.ellipsis)),
                if(r.isProvisional)const Tooltip(message:'Canlı maç dahil',child:Icon(Icons.bolt)),
              ])),
              ConsoleColumn(label:'O',width:ConsoleDensity.xxl,numeric:true,cell:(r)=>Text('${r.played}')),
              ConsoleColumn(label:'G',width:ConsoleDensity.xxl,numeric:true,cell:(r)=>Text('${r.won}')),
              ConsoleColumn(label:'B',width:ConsoleDensity.xxl,numeric:true,cell:(r)=>Text('${r.drawn}')),
              ConsoleColumn(label:'M',width:ConsoleDensity.xxl,numeric:true,cell:(r)=>Text('${r.lost}')),
              ConsoleColumn(label:'AV',width:ConsoleDensity.xxl,numeric:true,cell:(r)=>Text('${r.goalDiff}')),
              ConsoleColumn(label:'P',width:ConsoleDensity.xxl,numeric:true,cell:(r)=>Text('${r.points}',style:Theme.of(context).textTheme.titleSmall)),
              ConsoleColumn(label:'Son 5',width:ConsoleDensity.logoPreviewSize*2,cell:(r)=>Tooltip(message:'Eskiden yeniye',child:Row(children:[
                for(final f in r.form)StatusPill(label:f=='W'?'G':f=='D'?'B':'M',tone:f=='W'?PillTone.good:f=='D'?PillTone.muted:PillTone.bad)]))),
            ])),
        ]));
      });
  }
}
