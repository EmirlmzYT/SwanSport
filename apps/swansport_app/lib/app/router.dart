import 'package:flutter/material.dart';
import 'package:swansport_data/swansport_data.dart';
import '../features/live_match/presentation/live_match_detail_screen.dart';
import '../features/referee/referee_lineup_approval_screen.dart';
import '../features/referee/referee_live_cockpit_screen.dart';
import '../features/referee/referee_match_report_screen.dart';

/// Only the referee subroutes; the existing MaterialApp/AccountRouteGate remains
/// the navigation authority. IDs are parsed, never inferred from UI state.
Route<void>? refereeRoute(RouteSettings settings) {
  final target=Uri.tryParse(settings.name ?? '');
  if(target==null || target.pathSegments.length!=3 || target.pathSegments.first!='hakem')return null;
  final matchId=target.pathSegments.last;
  if(!RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$',caseSensitive:false).hasMatch(matchId))return null;
  final prefix='/${target.pathSegments.take(2).join('/')}';
  final Widget screen;
  switch(prefix) {
    case '/hakem/esame':screen=RefereeLineupApprovalScreen(matchId:matchId);
    case '/hakem/canli':screen=RefereeLiveCockpitScreen(matchId:matchId);
    case '/hakem/rapor':screen=RefereeMatchReportScreen(matchId:matchId);
    default:return null;
  }
  return MaterialPageRoute<void>(settings:settings,builder:(_)=>screen);
}

Route<void>? liveMatchRoute(RouteSettings settings) {
  final target=Uri.tryParse(settings.name??'');
  if(target==null||target.hasScheme||target.hasAuthority||target.pathSegments.length!=2
    ||target.pathSegments.first!='canli-mac'||!isPublicMatchId(target.pathSegments.last))return null;
  return MaterialPageRoute<void>(settings:settings,builder:(_)=>LiveMatchDetailScreen(matchId:target.pathSegments.last));
}
