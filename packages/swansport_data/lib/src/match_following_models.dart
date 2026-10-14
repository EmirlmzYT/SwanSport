class MatchFollowState {
  const MatchFollowState({required this.matchId,required this.isFollowed,
    this.notifyKickoff=false,this.notifyScore=false,this.notifyFinal=false,
    this.muted=false,this.source='none'});
  final String matchId,source;
  final bool isFollowed,notifyKickoff,notifyScore,notifyFinal,muted;
  factory MatchFollowState.fromMap(Map<String,dynamic> m)=>MatchFollowState(
    matchId:m['match_id'] as String,isFollowed:m['is_followed']==true,
    notifyKickoff:m['notify_kickoff']==true,notifyScore:m['notify_score']==true,
    notifyFinal:m['notify_final']==true,muted:m['muted']==true,source:m['source'] as String? ?? 'none');
}
