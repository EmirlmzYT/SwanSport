import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:swansport_data/swansport_data.dart';
import '../../../app/design/swan_palette.dart';
import '../../../app/design/swan_shape.dart';
import '../../../app/design/swan_type.dart';
import '../../../app/widgets/action_gate.dart';

class MatchFollowButton extends ConsumerStatefulWidget {
  const MatchFollowButton({required this.matchId,super.key});
  final String matchId;
  @override ConsumerState<MatchFollowButton> createState()=>_MatchFollowButtonState();
}
class _MatchFollowButtonState extends ConsumerState<MatchFollowButton> {
  bool _busy=false;
  bool _saving=false;
  bool? _uncertainDesired;
  String? _uncertainActor;
  @override Widget build(BuildContext context){final c=context.swan;
    if(!ref.watch(featureEnabledProvider(FeatureFlags.liveMatchNotifications)))return const SizedBox.shrink();
    final actor=ref.watch(authSessionProvider).valueOrNull?.user.id;
    final state=ref.watch(matchFollowStateProvider(widget.matchId));
    final followed=state.valueOrNull?.isFollowed??false;
    final uncertain=_uncertainDesired!=null&&_uncertainActor==actor;
    return Padding(padding:const EdgeInsets.only(top:SwanSpace.md),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      FilledButton.tonalIcon(onPressed:_busy||state.isLoading?null:()=>_set(uncertain?_uncertainDesired!:!followed),
        icon:_saving?SizedBox(width:SwanSpace.lg,height:SwanSpace.lg,child:const CircularProgressIndicator())
          :Icon(followed?Icons.notifications_active_rounded:Icons.notifications_none_rounded,color:followed?c.accent:c.inkMuted),
        label:Text(uncertain?'Tercihi Yeniden Dene':followed?'Bildirimleri Kapat':'Bildirimleri Aç',style:SwanType.bodySm(c.ink))),
      if(state.hasError)TextButton(onPressed:()=>ref.invalidate(matchFollowStateProvider(widget.matchId)),child:const Text('Takip durumu alınamadı. Yenile')),
      if(state.valueOrNull?.source=='club')Text('Kulüp takibinden açık. Kapatmak bu maçı sessize alır.',style:SwanType.caption(c.inkMuted)),
      Text('Maç tercihi cihaz izni değildir. Telefon bildirimleri için Bildirimler ekranındaki cihaz anahtarını açın.',style:SwanType.caption(c.inkMuted)),
      TextButton(onPressed:()=>Navigator.pushNamed(context,'/bildirimler'),child:const Text('Cihaz Bildirim Ayarları')),
    ]));
  }
  Future<void> _set(bool desired) async {
    if(_busy)return;
    setState(()=>_busy=true);
    final actor=ref.read(authSessionProvider).valueOrNull?.user.id;
    try{
      if(!await requireSwanAction(context,ref,SwanAction.matchFollow))return;
      if(!mounted||actor!=ref.read(authSessionProvider).valueOrNull?.user.id)return;
      setState(() => _saving = true);
      final value=await ref.read(matchFollowingServiceProvider).setFollow(widget.matchId,follow:desired);
      if(!mounted||actor!=ref.read(authSessionProvider).valueOrNull?.user.id)return;
      _uncertainDesired=null;_uncertainActor=null;
      ref.invalidate(matchFollowStateProvider(widget.matchId));ref.invalidate(isMatchFollowedProvider(widget.matchId));
      // Optional device feedback must never hold a successful server write busy.
      unawaited(HapticFeedback.selectionClick().catchError((Object _) {}));
      if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(value
        ?'Maç bildirim tercihi kaydedildi. Cihaz izni ve bağlantı varsa uyarılar iletilir.'
        :'Bu maçın bildirimleri sessize alındı.')));
    }catch(_){if(mounted&&actor==ref.read(authSessionProvider).valueOrNull?.user.id){
      _uncertainDesired=desired;_uncertainActor=actor;
      ref.invalidate(matchFollowStateProvider(widget.matchId));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Tercih doğrulanamadı. Aynı tercihi yeniden deneyebilir veya durumu yenileyebilirsiniz.')));
    }}finally{if(mounted)setState((){_busy=false;_saving=false;});}
  }
}

class MatchFollowIndicator extends ConsumerWidget {
  const MatchFollowIndicator({required this.matchId,super.key});
  final String matchId;
  @override Widget build(BuildContext context,WidgetRef ref){final c=context.swan;
    if(!ref.watch(featureEnabledProvider(FeatureFlags.liveMatchNotifications)))return const SizedBox.shrink();
    return ref.watch(isMatchFollowedProvider(matchId)).valueOrNull==true
      ?Tooltip(message:'Maç bildirimleri açık',child:Icon(Icons.notifications_active_rounded,size:SwanSpace.lg,color:c.accent))
      :const SizedBox.shrink();
  }
}
