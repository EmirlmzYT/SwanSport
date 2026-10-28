import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'pro_notification_route_handler.dart';
import 'pro_push_client.dart';

/// Connects native FCM delivery to visible UI and safe Pro navigation.
class ProPushCoordinator extends ConsumerStatefulWidget {
  const ProPushCoordinator({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<ProPushCoordinator> createState() => _ProPushCoordinatorState();
}

class _ProPushCoordinatorState extends ConsumerState<ProPushCoordinator> {
  StreamSubscription<ProPushMessage>? _foregroundSubscription;
  StreamSubscription<ProPushMessage>? _openedSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bind());
  }

  Future<void> _bind() async {
    if (!mounted) return;
    final client = ref.read(proPushClientProvider);
    _foregroundSubscription = client.foregroundMessages().listen(
          _showForegroundMessage,
          onError: (Object error) =>
              debugPrint('Pro foreground push stream failed: $error'),
        );
    _openedSubscription = client.openedMessages().listen(
          _openMessage,
          onError: (Object error) =>
              debugPrint('Pro opened push stream failed: $error'),
        );
    final initial = await client.initialMessage();
    if (initial != null && mounted) _openMessage(initial);
  }

  void _openMessage(ProPushMessage message) {
    if (!mounted) return;
    widget.router.go(resolveProPushUrl(message.route));
  }

  void _showForegroundMessage(ProPushMessage message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message.body.isEmpty
                ? message.title
                : '${message.title}\n${message.body}',
          ),
          action: SnackBarAction(
            label: 'Aç',
            onPressed: () => _openMessage(message),
          ),
        ),
      );
  }

  @override
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
