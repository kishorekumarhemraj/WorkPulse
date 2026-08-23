/// Base exception for WorkPulse domain and data layer errors
abstract class AppException implements Exception {
  final String message;
  final dynamic details;

  const AppException(this.message, [this.details]);

  @override
  String toString() =>
      '$runtimeType: $message${details != null ? ' ($details)' : ''}';
}

class AppDatabaseException extends AppException {
  const AppDatabaseException(super.message, [super.details]);
}

class ValidationException extends AppException {
  const ValidationException(super.message, [super.details]);
}

class NotFoundException extends AppException {
  const NotFoundException(super.message, [super.details]);
}

class SessionConflictException extends AppException {
  const SessionConflictException(super.message, [super.details]);
}
