import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_navigator.dart';
import 'app_routes.dart';
import 'swan_navigation.dart';

/// A route-aware back policy shared by headers and system-back handling.
///
/// Nested legacy navigators are checked before the outer GoRouter. When no
/// stack can pop (deep link, browser refresh or push entry), a safe parent is
/// selected without inventing history.
abstract final class SwanBackNavigation {
  static const _noFallback = <String>{
    AppRoutes.root,
    AppRoutes.feed,
    AppRoutes.explore,
    AppRoutes.messages,
    AppRoutes.profile,
    AppRoutes.auth,
    AppRoutes.guide,
    '/landing',
    '/demo-rol',
  };

  static const _messagesRoutes = <String>{
    AppRoutes.directMessage,
    AppRoutes.community,
    AppRoutes.communities,
    AppRoutes.assistant,
  };

  static const _exploreRoutes = <String>{
    AppRoutes.search,
    AppRoutes.notifications,
    AppRoutes.clubs,
    AppRoutes.clubProfile,
    AppRoutes.clubDetail,
    AppRoutes.venues,
    AppRoutes.turfVenues,
    AppRoutes.partnerSearch,
    AppRoutes.playerWanted,
    AppRoutes.marketplace,
    AppRoutes.listings,
    AppRoutes.createListing,
    AppRoutes.storeApplication,
    AppRoutes.coachDiscovery,
    AppRoutes.organizations,
    AppRoutes.liveScore,
    AppRoutes.federation,
    AppRoutes.federationCenter,
    AppRoutes.federationCalendar,
  };

  static const _profileRoutes = <String>{
    AppRoutes.account,
    AppRoutes.clubSettings,
    AppRoutes.clubCockpit,
    AppRoutes.finance,
    AppRoutes.quickExpense,
    AppRoutes.financeTasks,
    AppRoutes.accountantLedger,
    AppRoutes.periodReversal,
    AppRoutes.athletes,
    AppRoutes.teams,
    AppRoutes.calendar,
    AppRoutes.attendance,
    AppRoutes.attendanceHistory,
    AppRoutes.seasonSetup,
    AppRoutes.facilities,
    AppRoutes.facilityReservation,
    AppRoutes.medicalCenter,
    AppRoutes.clubInventory,
    AppRoutes.clubHealth,
    AppRoutes.clubSquadPlanning,
    AppRoutes.homeCommand,
    AppRoutes.performanceAnalytics,
    AppRoutes.myTraining,
    AppRoutes.trainingSession,
    AppRoutes.trainingProtocols,
    AppRoutes.createWorkout,
    AppRoutes.trainingResult,
    AppRoutes.myFees,
    AppRoutes.documents,
    AppRoutes.credentials,
    AppRoutes.refereeDuties,
    AppRoutes.parentConsent,
    AppRoutes.guardianLink,
    AppRoutes.developmentReport,
    AppRoutes.courtOperations,
    AppRoutes.savedPosts,
    AppRoutes.campaigns,
    AppRoutes.applications,
    AppRoutes.help,
    AppRoutes.support,
  };

  static String? routeOf(BuildContext context) {
    final modalName = ModalRoute.settingsOf(context)?.name;
    if (modalName != null && modalName.isNotEmpty && modalName != '/') {
      return Uri.tryParse(modalName)?.path ?? modalName;
    }
    final router = swanGoRouter ?? GoRouter.maybeOf(context);
    return router?.routeInformationProvider.value.uri.path ?? modalName;
  }

  static String? fallbackFor(String? route) {
    if (route == null || _noFallback.contains(route)) return null;
    if (_messagesRoutes.contains(route) || route.startsWith('/sohbet')) {
      return AppRoutes.messages;
    }
    if (_exploreRoutes.contains(route) ||
        route.startsWith('/canli-mac') ||
        route.startsWith('/kulup-') ||
        route.startsWith('/swan-id/dogrula')) {
      return AppRoutes.explore;
    }
    if (_profileRoutes.contains(route) ||
        route.startsWith('/hakem/') ||
        route.startsWith('/performance-') ||
        route.startsWith('/document-') ||
        route.startsWith('/report-')) {
      return AppRoutes.profile;
    }
    // Registered operational/detail routes that predate AppRoutes remain
    // recoverable on history-less entry. Feed is the least privileged parent.
    return AppRoutes.feed;
  }

  static bool canPop(BuildContext context) {
    final local = Navigator.maybeOf(context);
    final modal = ModalRoute.of(context);
    final goRouter = swanGoRouter ?? GoRouter.maybeOf(context);
    final routerAtDirectEntry = goRouter != null &&
        !goRouter.canPop() &&
        goRouter.routeInformationProvider.value.uri.path == routeOf(context);
    if (!routerAtDirectEntry &&
        modal?.isFirst == false &&
        (local?.canPop() ?? false)) {
      return true;
    }
    if (goRouter != null) return goRouter.canPop();
    final root = Navigator.maybeOf(context, rootNavigator: true);
    return root != local && (root?.canPop() ?? false);
  }

  static bool shouldShow(
    BuildContext context, {
    String? fallbackRoute,
  }) =>
      canPop(context) ||
      (fallbackRoute ?? fallbackFor(routeOf(context))) != null;

  static void back<T extends Object?>(
    BuildContext context, {
    T? result,
    String? fallbackRoute,
  }) {
    final local = Navigator.maybeOf(context);
    final modal = ModalRoute.of(context);
    final goRouter = swanGoRouter ?? GoRouter.maybeOf(context);
    final routerAtDirectEntry = goRouter != null &&
        !goRouter.canPop() &&
        goRouter.routeInformationProvider.value.uri.path == routeOf(context);
    if (!routerAtDirectEntry &&
        modal?.isFirst == false &&
        (local?.canPop() ?? false)) {
      local!.pop(result);
      return;
    }
    if (goRouter != null) {
      if (goRouter.canPop()) {
        goRouter.pop(result);
        return;
      }
    } else {
      final root = Navigator.maybeOf(context, rootNavigator: true);
      if (root != local && (root?.canPop() ?? false)) {
        root!.pop(result);
        return;
      }
    }
    final fallback = fallbackRoute ?? fallbackFor(routeOf(context));
    if (fallback == null) return;
    if (swanGoRouter != null) {
      swanGoRouter!.go(fallback);
    } else if (GoRouter.maybeOf(context) != null) {
      SwanNavigation.go(context, fallback);
    } else {
      local?.pushReplacementNamed(fallback);
    }
  }
}

class SwanBackButton extends StatelessWidget {
  const SwanBackButton({super.key, this.fallbackRoute});

  final String? fallbackRoute;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Geri dön',
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: () => SwanBackNavigation.back(
          context,
          fallbackRoute: fallbackRoute,
        ),
      );
}
