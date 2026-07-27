import '../errors/app_failure.dart';

sealed class AppResult<T> {
  const AppResult();
}

class AppSuccess<T> extends AppResult<T> {
  const AppSuccess(this.value);

  final T value;
}

class AppError<T> extends AppResult<T> {
  const AppError(this.failure);

  final AppFailure failure;
}
