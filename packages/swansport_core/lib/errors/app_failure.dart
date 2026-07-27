class AppFailure {
  const AppFailure({
    required this.message,
    this.code,
  });

  final String message;
  final String? code;
}
