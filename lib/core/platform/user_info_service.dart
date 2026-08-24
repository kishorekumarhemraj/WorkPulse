import 'dart:io';

/// Platform utility service to detect the current logged-in user's full name
/// across macOS, Windows, and Linux.
class UserInfoService {
  static String? _cachedFullName;

  /// Retrieves the human-readable full name of the currently logged-in user on macOS or Windows.
  /// Falls back to the environment username if full name lookup fails.
  static Future<String> getCurrentUserFullName() async {
    if (_cachedFullName != null && _cachedFullName!.trim().isNotEmpty) {
      return _cachedFullName!;
    }

    try {
      if (Platform.isMacOS) {
        // macOS: 'id -F' returns the user's full display name (e.g. 'Kishore Kumar Hemraj')
        final result = await Process.run('id', ['-F']);
        if (result.exitCode == 0) {
          final name = (result.stdout as String).trim();
          if (name.isNotEmpty) {
            _cachedFullName = name;
            return name;
          }
        }
      } else if (Platform.isWindows) {
        // Windows: query full name via PowerShell or identity
        try {
          final result = await Process.run('powershell', [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            r"""[System.Security.Principal.WindowsIdentity]::GetCurrent().Name""",
          ]);
          if (result.exitCode == 0) {
            final name = (result.stdout as String).trim();
            if (name.isNotEmpty) {
              _cachedFullName = name;
              return name;
            }
          }
        } catch (_) {}
      } else if (Platform.isLinux) {
        try {
          final user = Platform.environment['USER'];
          if (user != null && user.isNotEmpty) {
            final result = await Process.run('getent', ['passwd', user]);
            if (result.exitCode == 0) {
              final parts = (result.stdout as String).split(':');
              if (parts.length >= 5 && parts[4].trim().isNotEmpty) {
                final gecos = parts[4].split(',').first.trim();
                if (gecos.isNotEmpty) {
                  _cachedFullName = gecos;
                  return gecos;
                }
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    final fallback = Platform.environment['USER'] ??
        Platform.environment['USERNAME'] ??
        Platform.environment['LOGNAME'] ??
        'User';

    _cachedFullName = fallback.trim();
    return _cachedFullName!;
  }

  /// For unit testing: sets the cached user name.
  static void setMockUserName(String? name) {
    _cachedFullName = name;
  }
}
