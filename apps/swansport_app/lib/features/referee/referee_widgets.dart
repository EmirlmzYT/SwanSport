import 'package:swansport_app/app/widgets/swan_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';

import '../../app/design/swan_palette.dart';
import '../../app/design/swan_shape.dart';
import '../../app/design/swan_type.dart';
import '../../app/widgets/swan_module_app_bar.dart';
import '../../app/widgets/swan_bottom_nav.dart';

bool refereeAvailable(WidgetRef ref) => ref.watch(swanAccessProvider).isReferee &&
  ref.watch(featureEnabledProvider(FeatureFlags.refereeCockpit));
Widget? refereeGate(BuildContext context,WidgetRef ref,String title) {
  if(refereeAvailable(ref)) return null;
  return RefereePage(title:title,child:Text('Hakem Kokpiti bu hesap için henüz kullanıma açık değil.',style:SwanType.body(context.swan.ink)));
}
class RefereePage extends StatelessWidget {
  const RefereePage({super.key,required this.title,required this.child});
  final String title;
  final Widget child;
  @override Widget build(BuildContext context) => SwanScaffold(
    backgroundColor:context.swan.bg,appBar:swanModuleAppBar(context,title:title),
    bottomNavigationBar:const SwanBottomNav(),
    body:SafeArea(child:Padding(padding:const EdgeInsets.all(SwanSpace.lg),child:child)));
}
/// A private player/reason dialog must not outlive the account that opened it.
class RefereeActorScope extends ConsumerWidget {
  const RefereeActorScope({super.key,required this.actorId,required this.child});
  final String? actorId;
  final Widget child;
  @override Widget build(BuildContext context,WidgetRef ref) {
    if(ref.watch(authSessionProvider).valueOrNull?.user.id==actorId)return child;
    final route=ModalRoute.of(context),navigator=Navigator.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_){
      if(context.mounted && route is PopupRoute<dynamic> && route.isCurrent)navigator.pop();
    });
    return const SizedBox.shrink();
  }
}
class RefereePanel extends StatelessWidget {
  const RefereePanel({super.key,required this.child});
  final Widget child;
  @override Widget build(BuildContext context) => Container(
    padding:const EdgeInsets.all(SwanSpace.lg),
    decoration:BoxDecoration(color:context.swan.surface,borderRadius:BorderRadius.circular(SwanRadius.md)),child:child);
}
class RefereeButton extends StatelessWidget {
  const RefereeButton({super.key,required this.label,this.onPressed,this.icon=Icons.sports_rounded});
  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  @override Widget build(BuildContext context) => FilledButton.icon(
    style:FilledButton.styleFrom(backgroundColor:context.swan.accentFill,foregroundColor:context.swan.onAccent,
      minimumSize:const Size(SwanSpace.xl*2,SwanSpace.xl*2),
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(SwanRadius.md))),
    onPressed:onPressed,icon:Icon(icon),label:Text(label,style:SwanType.body(context.swan.onAccent)));
}
class RefereeError extends StatelessWidget {
  const RefereeError({super.key,required this.error,required this.onRetry,this.retryLabel='Yeniden yükle'});
  final Object error;
  final VoidCallback onRetry;
  final String retryLabel;
  @override Widget build(BuildContext context) => RefereePanel(child:Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(Icons.error_outline_rounded,color:context.swan.danger),
        const SizedBox(width:SwanSpace.sm),Expanded(child:Text('İşlem doğrulanamadı',style:SwanType.h3(context.swan.ink)))]),
      Text('$error',style:SwanType.bodySm(context.swan.inkMuted)),
      const SizedBox(height:SwanSpace.md),RefereeButton(label:retryLabel,onPressed:onRetry,icon:Icons.refresh_rounded)]));
}
String refereeDutyLabel(MatchOfficialDuty duty) => switch(duty) {
  MatchOfficialDuty.headReferee => 'Başhakem',MatchOfficialDuty.assistantReferee1 => '1. Yardımcı Hakem',
  MatchOfficialDuty.assistantReferee2 => '2. Yardımcı Hakem',MatchOfficialDuty.fourthReferee => 'Dördüncü Hakem',
  MatchOfficialDuty.tableOfficial => 'Masa Hakemi',MatchOfficialDuty.observer => 'Gözlemci'};
String refereeStatusLabel(MatchOfficialStatus status) => switch(status) {
  MatchOfficialStatus.assigned => 'Yanıt bekliyor',MatchOfficialStatus.accepted => 'Kabul edildi',
  MatchOfficialStatus.declined => 'Mazeret bildirildi',MatchOfficialStatus.replaced => 'Görev değiştirildi'};
String refereeMatchStatusLabel(String status) => switch(status) {
  'scheduled'=>'Programda','played'=>'Tamamlandı','cancelled'=>'İptal',_=>'Durum doğrulanmalı'};
String refereeEventLabel(RefereeLiveEvent e) => switch(e.kind) {
  'score' => 'Skor +1', 'card' => switch(e.card) {'yellow'=>'Sarı kart','red'=>'Kırmızı kart','two_minutes'=>'2 dk cezası',_=>'Teknik faul'},
  'substitution'=>'Oyuncu değişikliği','period_end'=>'Periyot / set sonu','clock_start'=>'Süre başladı',
  'clock_pause'=>'Süre durdu','undo'=>'Son olay geri alındı',_=>'Olay'};
String refereeTime(DateTime? instant) {
  if(instant == null) return 'Tarih belirtilmedi';
  final d=refereeTurkeyTime(instant);
  return '${d.day}.${d.month}.${d.year} · ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}
class RefereeEntryCard extends ConsumerWidget {
  const RefereeEntryCard({super.key,this.today=false,this.route='/hakem/gorevler'});
  final bool today;
  final String route;
  @override Widget build(BuildContext context,WidgetRef ref) {
    if(!refereeAvailable(ref)) return const SizedBox.shrink();
    final matches=today ? ref.watch(refereeTodayMatchesProvider).asData?.value : null;
    if(today && (matches == null || matches.isEmpty)) return const SizedBox.shrink();
    final first=matches == null || matches.isEmpty ? null : matches.first;
    final quick=first != null && matches!.length==1 && refereeSupportsLive(first.sportCode) ? first : null;
    return Padding(padding:const EdgeInsets.all(SwanSpace.lg),child:RefereePanel(child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(today ? 'Bugün · Müsabaka görevin' : 'Hakem Kokpiti',style:SwanType.h3(context.swan.ink)),
        if(today) Text('${first!.homeClubName ?? 'Ev sahibi'} · ${first.awayClubName ?? 'Deplasman'}',style:SwanType.bodySm(context.swan.inkMuted)),
        RefereeButton(label:quick!=null ? 'Müsabakayı Yönet' : today ? 'Görevleri gör' : 'Müsabaka yönetimi',
          onPressed:()=>Navigator.pushNamed(context,quick!=null ? '/hakem/esame/${quick.matchId}' : route))])));
  }
}
