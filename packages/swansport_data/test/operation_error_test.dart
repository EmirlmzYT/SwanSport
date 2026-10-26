import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;
import 'package:swansport_data/swansport_data.dart';

void main() {
  test('network errors receive a safe retry message', () {
    for (final error in <Object>[
      TimeoutException('private timeout detail'),
      ClientException('private host detail'),
      const PostgrestException(
        message: 'private gateway detail',
        code: 'PGRST000',
      ),
    ]) {
      final safe = classifyOperationError(error);
      expect(safe.kind, OperationErrorKind.network);
      expect(safe.userMessage, contains('Bağlantı'));
      expect(safe.userMessage, isNot(contains('private')));
      expect(safe.cause, same(error));
    }
  });

  test('authorization errors never expose backend detail', () {
    for (final error in <Object>[
      const AuthException('private auth detail'),
      const PostgrestException(message: 'private policy detail', code: '42501'),
    ]) {
      final safe = classifyOperationError(error);
      expect(safe.kind, OperationErrorKind.unauthorized);
      expect(safe.userMessage, contains('yetkin'));
      expect(safe.userMessage, isNot(contains('private')));
    }
  });

  test('conflict, validation, and unknown errors have stable categories', () {
    expect(
      classifyOperationError(
        const PostgrestException(message: 'version', code: '40001'),
      ).kind,
      OperationErrorKind.conflict,
    );
    expect(
      classifyOperationError(const FormatException('private value')).kind,
      OperationErrorKind.validation,
    );
    final unknown = classifyOperationError(Exception('private unknown'));
    expect(unknown.kind, OperationErrorKind.unknown);
    expect(unknown.userMessage, isNot(contains('private')));
  });
}
