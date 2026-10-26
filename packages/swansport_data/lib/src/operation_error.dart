import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, PostgrestException;

enum OperationErrorKind {
  network,
  unauthorized,
  conflict,
  validation,
  unknown,
}

final class SafeOperationError {
  const SafeOperationError({
    required this.kind,
    required this.userMessage,
    required this.cause,
  });

  final OperationErrorKind kind;
  final String userMessage;

  /// Retained for diagnostics only. Presentation code must use [userMessage].
  final Object cause;
}

SafeOperationError classifyOperationError(Object error) {
  if (error is TimeoutException || error is ClientException) {
    return SafeOperationError(
      kind: OperationErrorKind.network,
      userMessage: 'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.',
      cause: error,
    );
  }

  if (error is AuthException) {
    return SafeOperationError(
      kind: OperationErrorKind.unauthorized,
      userMessage: 'Bu işlem için aktif yetkin bulunmuyor.',
      cause: error,
    );
  }

  if (error is PostgrestException) {
    final code = error.code?.toUpperCase();
    if (const {'PGRST000', 'PGRST001', 'PGRST002', 'PGRST003'}.contains(code)) {
      return SafeOperationError(
        kind: OperationErrorKind.network,
        userMessage:
            'Bağlantı kurulamadı. İnternetini kontrol edip tekrar dene.',
        cause: error,
      );
    }
    if (const {'42501', 'PGRST301', 'PGRST302', '401', '403'}.contains(code)) {
      return SafeOperationError(
        kind: OperationErrorKind.unauthorized,
        userMessage: 'Bu işlem için aktif yetkin bulunmuyor.',
        cause: error,
      );
    }
    if (const {'40001', '40P01', '23505', '409'}.contains(code)) {
      return SafeOperationError(
        kind: OperationErrorKind.conflict,
        userMessage: 'Kayıt başka bir işlemle değişti. Yenileyip tekrar dene.',
        cause: error,
      );
    }
    if (const {'22023', '23502', '23503', '23514', 'P0001'}.contains(code)) {
      return SafeOperationError(
        kind: OperationErrorKind.validation,
        userMessage: 'Gönderilen bilgiler doğrulanamadı. Alanları kontrol et.',
        cause: error,
      );
    }
  }

  if (error is FormatException ||
      error is ArgumentError ||
      error is StateError) {
    return SafeOperationError(
      kind: OperationErrorKind.validation,
      userMessage: 'Gönderilen bilgiler doğrulanamadı. Alanları kontrol et.',
      cause: error,
    );
  }

  return SafeOperationError(
    kind: OperationErrorKind.unknown,
    userMessage: 'İşlem tamamlanamadı. Lütfen tekrar dene.',
    cause: error,
  );
}
