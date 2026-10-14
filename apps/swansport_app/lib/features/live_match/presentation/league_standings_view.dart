import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import 'live_match_widgets.dart';

class LeagueStandingsView extends ConsumerStatefulWidget {
  const LeagueStandingsView({required this.orgId,this.highlightedParticipants=const {},super.key});
  final String orgId;
  final Set<String> highlightedParticipants;
  @override ConsumerState<LeagueStandingsView> createState()=>_LeagueStandingsViewState();
}
class _LeagueStandingsViewState extends ConsumerState<LeagueStandingsView> {
  bool _live=false;
  @override Widget build(BuildContext context){final c=context.swan;
    if(!ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings)))return Text('Puan durumu henüz kullanıma açılmadı.',style:SwanType.body(c.inkMuted));
    final provider=leagueStandingsProvider((orgId:widget.orgId,includeLive:_live));
    return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(_live?'Canlı Puan Durumu':'Resmi Sonuçlar',style:SwanType.h3(c.ink)),
        subtitle:Text(_live?'Devam eden maçlar geçici olarak eklenir.':'Yalnız tescilli güncel sonuçlar.',style:SwanType.caption(c.inkMuted)),
        activeThumbColor:c.accent,value:_live,onChanged:(v)=>setState(()=>_live=v)),
      Text('Puan · averaj · atılan sayı sırası. AV: skor/set farkı. Son 5: eskiden yeniye. Yatay kaydırarak tüm sütunları görün.',style:SwanType.caption(c.inkMuted)),
      ref.watch(provider).when(skipLoadingOnRefresh:false,
        loading:()=>const Padding(padding:EdgeInsets.all(SwanSpace.lg),child:CircularProgressIndicator()),
        error:(_,__)=>TextButton(onPressed:()=>ref.invalidate(provider),child:const Text('Tablo alınamadı. Yeniden dene')),
        data:(rows)=>rows.isEmpty?Padding(padding:const EdgeInsets.all(SwanSpace.lg),child:Text('Bu lig için yayımlanmış tablo yok.',style:SwanType.body(c.inkMuted)))
          :SingleChildScrollView(scrollDirection:Axis.horizontal,child:DataTable(
            headingTextStyle:SwanType.caption(c.inkMuted),dataTextStyle:SwanType.bodySm(c.ink),
            dataRowMinHeight:SwanSpace.xl*2,dataRowMaxHeight:SwanSpace.xl*4,
            horizontalMargin:SwanSpace.sm,columnSpacing:SwanSpace.md,
            columns:[for(final label in ['#','Takım','O','G','B','M','AV','P','Son 5'])DataColumn(label:Text(label))],
            rows:[for(final row in rows)DataRow(
              color:WidgetStatePropertyAll(widget.highlightedParticipants.contains(row.participantId)?c.accentSoft:c.surface),
              cells:[DataCell(Text('${row.rank}')),DataCell(SizedBox(width:SwanSpace.xl*8,child:Row(children:[
                if(row.clubLogo?.isNotEmpty==true) ...[
                  Image.network(row.clubLogo!,width:SwanSpace.xl,height:SwanSpace.xl,fit:BoxFit.contain,
                    errorBuilder:(_,__,___)=>Icon(Icons.shield_outlined,size:SwanSpace.xl,color:c.inkMuted)),
                  const SizedBox(width:SwanSpace.sm)],
                Expanded(child:Text(row.name,maxLines:2,overflow:TextOverflow.ellipsis)),
                if(row.isProvisional)Tooltip(message:'Canlı maç dahil',child:Icon(Icons.circle,size:SwanSpace.sm,color:c.danger)),
              ]))),for(final n in [row.played,row.won,row.drawn,row.lost,row.goalDiff,row.points])DataCell(Text('$n',style:SwanType.bodySm(c.ink,w:FontWeight.w800))),
              DataCell(Row(children:[for(final f in row.form)Padding(padding:const EdgeInsets.only(right:SwanSpace.xs),child:Tooltip(
                message:switch(f){'W'=>'Galibiyet','D'=>'Beraberlik',_=>'Mağlubiyet'},child:Container(
                  padding:const EdgeInsets.all(SwanSpace.xs),decoration:BoxDecoration(color:(f=='W'?c.success:f=='L'?c.danger:c.inkMuted).withValues(alpha:.12),
                    borderRadius:BorderRadius.circular(SwanRadius.sm)),
                  child:Text(f=='W'?'G':f=='D'?'B':'M',style:SwanType.caption(c.ink,w:FontWeight.w800)))))])),
            ])],
          )),
      ),
    ]);
  }
}

class MatchLeagueStandingsView extends ConsumerWidget {
  const MatchLeagueStandingsView({required this.matchId,super.key});
  final String matchId;
  @override Widget build(BuildContext context,WidgetRef ref){final c=context.swan;
    if(!ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings)))return const SizedBox.shrink();
    return ref.watch(matchStandingsContextProvider(matchId)).when(
      loading:()=>const Center(child:CircularProgressIndicator()),
      error:(_,__)=>TextButton(onPressed:()=>ref.invalidate(matchStandingsContextProvider(matchId)),child:const Text('Lig alınamadı. Yeniden dene')),
      data:(league)=>league==null?Text('Bu maç için yayımlanmış lig tablosu yok.',style:SwanType.body(c.inkMuted))
        :Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(league.name,style:SwanType.h3(c.ink)),
          LeagueStandingsView(key:ValueKey(league.orgId),orgId:league.orgId,highlightedParticipants:{
            if(league.homeParticipantId!=null)league.homeParticipantId!,if(league.awayParticipantId!=null)league.awayParticipantId!})]));
  }
}

class LeagueStandingsSelector extends ConsumerStatefulWidget {
  const LeagueStandingsSelector({this.sport,super.key});
  final String? sport;
  @override ConsumerState<LeagueStandingsSelector> createState()=>_LeagueStandingsSelectorState();
}
class _LeagueStandingsSelectorState extends ConsumerState<LeagueStandingsSelector> {
  String? _org;
  @override Widget build(BuildContext context){final c=context.swan;
    if(!ref.watch(featureEnabledProvider(FeatureFlags.leagueStandings)))return Text('Puan durumu henüz kullanıma açılmadı.',style:SwanType.body(c.inkMuted));
    return ref.watch(standingsLeaguesProvider).when(
      loading:()=>const Center(child:CircularProgressIndicator()),
      error:(_,__)=>TextButton(onPressed:()=>ref.invalidate(standingsLeaguesProvider),child:const Text('Ligler alınamadı. Yeniden dene')),
      data:(all){final leagues=all.where((l)=>widget.sport==null||l.sportCode==widget.sport).toList();
        if(leagues.isEmpty)return Text('Yayımlanmış lig bulunmuyor.',style:SwanType.body(c.inkMuted));
        final selected=leagues.firstWhere((l)=>l.id==_org,orElse:()=>leagues.first);
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          DropdownButtonFormField<String>(key:ValueKey(selected.id),value:selected.id,isExpanded:true,decoration:const InputDecoration(labelText:'Lig seç'),
            items:[for(final l in leagues)DropdownMenuItem(value:l.id,child:Text('${l.name} · ${liveSportName(l.sportCode)}${l.cityCode==null?'':' · İl ${l.cityCode}'}',maxLines:1,overflow:TextOverflow.ellipsis,style:SwanType.bodySm(c.ink)))],
            onChanged:(v)=>setState(()=>_org=v)),
          const SizedBox(height:SwanSpace.md),
          Text('Puan kuralı: ${selected.winPoints}/${selected.drawPoints}/${selected.lossPoints}',style:SwanType.caption(c.inkMuted)),
          LeagueStandingsView(key:ValueKey(selected.id),orgId:selected.id),
        ]);
      });
  }
}
