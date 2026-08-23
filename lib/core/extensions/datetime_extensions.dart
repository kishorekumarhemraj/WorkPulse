/// Extensions on [DateTime] for consistent storage serialization.
extension DateTimeStorage on DateTime {
  /// Converts to UTC ISO-8601 string for SQLite storage.
  ///
  /// Always appends the 'Z' suffix regardless of whether the
  /// original DateTime was local or already UTC.
  String toStorageString() => toUtc().toIso8601String();
}
