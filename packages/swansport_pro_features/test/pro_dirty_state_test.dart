import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:swansport_pro_features/swansport_pro_features.dart';

void main() {
  test('registration disposal cannot leave the coordinator dirty', () {
    final coordinator = ProDirtyStateCoordinator();
    final registration = coordinator.register('attendance');

    expect(coordinator.isDirty, isFalse);
    registration.markDirty();
    expect(coordinator.isDirty, isTrue);
    registration.dispose();
    expect(coordinator.isDirty, isFalse);
  });

  test('clean transition skips confirmation and invalidates before switching',
      () async {
    final coordinator = ProDirtyStateCoordinator();
    final order = <String>[];
    var confirmationCalls = 0;

    final moved = await coordinator.runGuardedTransition(
      confirmDiscard: () async {
        confirmationCalls++;
        return true;
      },
      invalidate: () => order.add('invalidate'),
      transition: () => order.add('switch'),
    );

    expect(moved, isTrue);
    expect(confirmationCalls, 0);
    expect(order, ['invalidate', 'switch']);
  });

  test('cancel preserves dirty state and does not invalidate or switch',
      () async {
    final coordinator = ProDirtyStateCoordinator();
    final registration = coordinator.register('attendance')..markDirty();
    addTearDown(registration.dispose);
    var confirmationCalls = 0;
    var invalidations = 0;
    var transitions = 0;

    final moved = await coordinator.runGuardedTransition(
      confirmDiscard: () async {
        confirmationCalls++;
        return false;
      },
      invalidate: () => invalidations++,
      transition: () => transitions++,
    );

    expect(moved, isFalse);
    expect(confirmationCalls, 1);
    expect(invalidations, 0);
    expect(transitions, 0);
    expect(coordinator.isDirty, isTrue);
  });

  test('confirmation clears dirty state then invalidates then switches',
      () async {
    final coordinator = ProDirtyStateCoordinator();
    final registration = coordinator.register('attendance')..markDirty();
    addTearDown(registration.dispose);
    final order = <String>[];

    final moved = await coordinator.runGuardedTransition(
      confirmDiscard: () async => true,
      invalidate: () {
        expect(coordinator.isDirty, isFalse);
        order.add('invalidate');
      },
      transition: () => order.add('switch'),
    );

    expect(moved, isTrue);
    expect(order, ['invalidate', 'switch']);
    expect(coordinator.isDirty, isFalse);
  });

  test('concurrent transition attempts share one confirmation and switch',
      () async {
    final coordinator = ProDirtyStateCoordinator();
    final registration = coordinator.register('attendance')..markDirty();
    addTearDown(registration.dispose);
    final answer = Completer<bool>();
    var confirmationCalls = 0;
    var transitions = 0;

    Future<bool> move() => coordinator.runGuardedTransition(
          confirmDiscard: () {
            confirmationCalls++;
            return answer.future;
          },
          invalidate: () {},
          transition: () => transitions++,
        );

    final first = move();
    final second = move();
    expect(confirmationCalls, 1);
    answer.complete(true);

    expect(await first, isTrue);
    expect(await second, isTrue);
    expect(transitions, 1);
  });
}
