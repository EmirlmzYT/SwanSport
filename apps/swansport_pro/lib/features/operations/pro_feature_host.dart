import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

class ProOperationsFeatureHost extends StatelessWidget {
  const ProOperationsFeatureHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => ProFeatureHostScope(
        navigator: _ProNavigator(context),
        chrome: const _ProChrome(),
        theme: const ProFeatureThemeData(
          background: Color(0xFF0B132B),
          surface: Color(0xFF1C2541),
          line: Color(0xFF3A4B75),
          ink: Colors.white,
          inkMuted: Color(0xFF94A3B8),
          accent: Color(0xFF38BDF8),
          danger: Color(0xFFEF4444),
          warning: Color(0xFFF59E0B),
          success: Color(0xFF10B981),
        ),
        child: child,
      );
}

final class _ProNavigator extends ProFeatureNavigatorBase {
  _ProNavigator(this.context);
  final BuildContext context;

  @override
  void openTeams() => context.push('/operasyon/takimlar');
  @override
  void openRoster(TeamRouteTarget target) => context.push(
        '/operasyon/takim/${target.teamId}',
        extra: target,
      );
  @override
  void openAttendance() => context.push('/operasyon/yoklama');
  @override
  void openAttendanceHistory() => context.push('/operasyon/devam');
  @override
  void openTrainingList() => context.push('/operasyon/antrenmanlar');
  @override
  void openTrainingProtocols() =>
      context.push('/operasyon/antrenman-sablonlari');
  @override
  void openTrainingBuilder() => context.push('/operasyon/antrenman-olustur');
  @override
  void openTrainingSession({String? sessionId}) =>
      context.push('/operasyon/antrenman-oturumu', extra: sessionId);
  @override
  void openTrainingResult({String? sessionId}) =>
      context.push('/operasyon/antrenman-sonuc', extra: sessionId);
}

final class _ProChrome implements ProFeatureChrome {
  const _ProChrome();

  @override
  Widget buildPage(
    BuildContext context, {
    required String title,
    required Widget body,
    List<Widget> actions = const [],
    Widget? bottomBar,
    bool allowBack = true,
  }) =>
      Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: allowBack,
          title: Text(title),
          actions: actions,
        ),
        body: body,
        bottomNavigationBar: bottomBar,
      );

  @override
  Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Vazgeç',
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(cancelLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;

  @override
  void showMessage(
    BuildContext context,
    String message, {
    ProFeatureMessageTone tone = ProFeatureMessageTone.info,
  }) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
