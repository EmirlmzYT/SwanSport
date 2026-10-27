import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final proDirtyStateCoordinatorProvider = Provider<ProDirtyStateCoordinator>(
  (ref) {
    final coordinator = ProDirtyStateCoordinator();
    ref.onDispose(coordinator.dispose);
    return coordinator;
  },
);

final class ProDirtyStateCoordinator {
  final Map<Object, _DirtyEntry> _entries = {};
  Future<bool>? _pendingTransition;
  bool _disposed = false;

  bool get isDirty => _entries.values
      .any((entry) => entry.isDirty || entry.hasPendingOperation);

  bool get hasPendingOperation =>
      _entries.values.any((entry) => entry.hasPendingOperation);

  ProDirtyStateRegistration register(String owner) {
    _ensureActive();
    final token = Object();
    _entries[token] = _DirtyEntry(owner);
    return ProDirtyStateRegistration._(
      markDirty: () => _setDirty(token, true),
      markClean: () => _setDirty(token, false),
      markPendingOperation: () => _setPendingOperation(token, true),
      clearPendingOperation: () => _setPendingOperation(token, false),
      unregister: () => _entries.remove(token),
    );
  }

  Future<bool> runGuardedTransition({
    required Future<bool> Function() confirmDiscard,
    required FutureOr<void> Function() invalidate,
    required FutureOr<void> Function() transition,
  }) {
    _ensureActive();
    final pending = _pendingTransition;
    if (pending != null) return pending;

    final operation = _performTransition(
      confirmDiscard: confirmDiscard,
      invalidate: invalidate,
      transition: transition,
    );
    _pendingTransition = operation;
    operation.whenComplete(() {
      if (identical(_pendingTransition, operation)) {
        _pendingTransition = null;
      }
    });
    return operation;
  }

  Future<bool> _performTransition({
    required Future<bool> Function() confirmDiscard,
    required FutureOr<void> Function() invalidate,
    required FutureOr<void> Function() transition,
  }) async {
    if (isDirty && !await confirmDiscard()) return false;
    _clearDirtyState();
    await invalidate();
    await transition();
    return true;
  }

  void _setDirty(Object token, bool value) {
    if (_disposed) return;
    final entry = _entries[token];
    if (entry != null) entry.isDirty = value;
  }

  void _setPendingOperation(Object token, bool value) {
    if (_disposed) return;
    final entry = _entries[token];
    if (entry != null) entry.hasPendingOperation = value;
  }

  void _clearDirtyState() {
    for (final entry in _entries.values) {
      entry.isDirty = false;
      entry.hasPendingOperation = false;
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('ProDirtyStateCoordinator has been disposed');
    }
  }

  void dispose() {
    _disposed = true;
    _entries.clear();
  }
}

final class ProDirtyStateRegistration {
  ProDirtyStateRegistration._({
    required void Function() markDirty,
    required void Function() markClean,
    required void Function() markPendingOperation,
    required void Function() clearPendingOperation,
    required void Function() unregister,
  })  : _markDirty = markDirty,
        _markClean = markClean,
        _markPendingOperation = markPendingOperation,
        _clearPendingOperation = clearPendingOperation,
        _unregister = unregister;

  final void Function() _markDirty;
  final void Function() _markClean;
  final void Function() _markPendingOperation;
  final void Function() _clearPendingOperation;
  final void Function() _unregister;
  bool _disposed = false;

  void markDirty() {
    if (!_disposed) _markDirty();
  }

  void markClean() {
    if (!_disposed) _markClean();
  }

  void markPendingOperation() {
    if (!_disposed) _markPendingOperation();
  }

  void clearPendingOperation() {
    if (!_disposed) _clearPendingOperation();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _unregister();
  }
}

final class _DirtyEntry {
  _DirtyEntry(this.owner);

  final String owner;
  bool isDirty = false;
  bool hasPendingOperation = false;
}
