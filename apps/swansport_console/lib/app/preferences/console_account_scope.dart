import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swansport_data/swansport_data.dart';
import 'console_preferences.dart';

/// The outer scope owns authentication. Each account gets a fresh, unparented
/// container; token refreshes update its auth stream without discarding caches.
class ConsoleAccountScope extends ConsumerWidget {
  const ConsoleAccountScope(
      {required this.child,
      this.overrides = const [],
      this.observers = const [],
      super.key});
  final Widget child;
  final List<Override> overrides;
  final List<ProviderObserver> observers;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authSessionProvider);
    final session = auth.isLoading || auth.hasError ? null : auth.valueOrNull;
    return _IsolatedScope(
      key: ValueKey(session?.user.id),
      session: session,
      observers: observers,
      overrides: [
        supabaseConfigProvider
            .overrideWithValue(ref.watch(supabaseConfigProvider)),
        supabaseClientProvider
            .overrideWithValue(ref.watch(supabaseClientProvider)),
        diagnosticsProvider.overrideWithValue(ref.watch(diagnosticsProvider)),
        consolePreferenceStorageProvider
            .overrideWithValue(ref.watch(consolePreferenceStorageProvider)),
        ...overrides,
      ],
      child: child,
    );
  }
}

class _IsolatedScope extends StatefulWidget {
  const _IsolatedScope(
      {required this.session,
      required this.overrides,
      required this.observers,
      required this.child,
      super.key});
  final Session? session;
  final List<Override> overrides;
  final List<ProviderObserver> observers;
  final Widget child;
  @override
  State<_IsolatedScope> createState() => _IsolatedScopeState();
}

class _IsolatedScopeState extends State<_IsolatedScope> {
  late final ProviderContainer container;
  final _sessions = StreamController<Session?>.broadcast(sync: true);

  @override
  void initState() {
    super.initState();
    container = ProviderContainer(
      overrides: [
        ...widget.overrides,
        // Subscribe to the bridge before publishing its initial snapshot so no
        // update can fall between initial hydration and live subscription.
        authSessionProvider
            .overrideWith((ref) => Stream<Session?>.multi((sink) {
                  final subscription = _sessions.stream.listen(sink.add,
                      onError: sink.addError, onDone: sink.close);
                  sink.onCancel = subscription.cancel;
                  sink.add(widget.session);
                })),
      ],
      observers: widget.observers,
    );
  }

  @override
  void didUpdateWidget(covariant _IsolatedScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.session, widget.session)) {
      _sessions.add(widget.session);
    }
  }

  @override
  void dispose() {
    container.dispose();
    unawaited(_sessions.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      UncontrolledProviderScope(container: container, child: widget.child);
}
