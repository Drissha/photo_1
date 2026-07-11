class AppError {
  const AppError({
    required this.code,
    required this.cause,
    required this.solution,
    required this.autoFix,
    required this.retryable,
  });

  final String code;
  final String cause;
  final String solution;
  final String autoFix;
  final bool retryable;

  @override
  String toString() => '$code: $cause';
}
