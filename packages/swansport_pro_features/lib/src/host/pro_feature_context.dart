import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
final class ProFeatureContextKey {
  const ProFeatureContextKey({
    required this.userId,
    required this.workspace,
    required this.clubId,
    this.scopeId,
  });

  final String userId;
  final String workspace;
  final String? clubId;
  final String? scopeId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProFeatureContextKey &&
          userId == other.userId &&
          workspace == other.workspace &&
          clubId == other.clubId &&
          scopeId == other.scopeId;

  @override
  int get hashCode => Object.hash(userId, workspace, clubId, scopeId);

  @override
  String toString() =>
      'ProFeatureContextKey(userId: $userId, workspace: $workspace, '
      'clubId: $clubId, scopeId: $scopeId)';
}

final proFeatureContextProvider = StateProvider<ProFeatureContextKey?>(
  (ref) => null,
);

/// Forces mounted feature state to be rebuilt when account or scope changes.
final class ProFeatureContextBoundary extends StatelessWidget {
  const ProFeatureContextBoundary({
    required this.contextKey,
    required this.child,
    super.key,
  });

  final ProFeatureContextKey? contextKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
        key: ValueKey<ProFeatureContextKey?>(contextKey),
        child: child,
      );
}
