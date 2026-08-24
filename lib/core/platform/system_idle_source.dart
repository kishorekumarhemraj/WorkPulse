import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

/// How long the operating system reports since the last keyboard or mouse
/// input *anywhere on the machine* — not just inside WorkPulse.
///
/// This is the signal idle detection is defined against
/// (`docs/WORKPULSE_SPEC.md` §31: "no detectable keyboard/mouse interaction
/// occurred for the configured period"). It is deliberately a *query* of an
/// aggregate the OS already maintains, never a keystroke or event tap, so it
/// stays inside the privacy boundary the spec draws (§54) and needs no
/// accessibility permission on macOS.
///
/// Implementations must never throw: an unavailable source reports `null`,
/// which the detector reads as "cannot tell" and therefore never prompts.
/// Guessing would be worse than staying quiet — a false idle prompt asks the
/// user to account for time they actually worked.
abstract class SystemIdleSource {
  /// Time since the last system-wide input event, or `null` when this platform
  /// cannot report it.
  Duration? idleTime();

  /// Whether this source can report anything at all. Checked once so callers
  /// can degrade loudly (a log line) rather than silently.
  bool get isAvailable;

  /// Releases any native handle held by the source.
  void dispose() {}

  /// The right source for the host platform, or [UnavailableIdleSource] when
  /// there is none.
  factory SystemIdleSource.forPlatform() {
    if (kIsWeb) return const UnavailableIdleSource();
    try {
      if (Platform.isMacOS) return MacOsIdleSource();
      if (Platform.isWindows) return WindowsIdleSource();
    } catch (error) {
      debugPrint('[WorkPulse] System idle source unavailable: $error');
    }
    return const UnavailableIdleSource();
  }
}

/// The fallback for platforms with no supported query — Linux, tests, and any
/// host where opening the native library failed.
class UnavailableIdleSource implements SystemIdleSource {
  const UnavailableIdleSource();

  @override
  bool get isAvailable => false;

  @override
  Duration? idleTime() => null;

  @override
  void dispose() {}
}

// --- macOS ---------------------------------------------------------------

typedef _CGEventSourceSecondsSinceLastEventTypeNative = Double Function(
  Uint32 stateID,
  Uint32 eventType,
);
typedef _CGEventSourceSecondsSinceLastEventTypeDart = double Function(
  int stateID,
  int eventType,
);

/// Reads system idle time from Core Graphics.
///
/// `CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateHIDSystemState,
/// kCGAnyInputEventType)` returns seconds since the HID system last saw any
/// input. It is readable from inside the App Sandbox and requires no
/// entitlement, unlike an event tap.
class MacOsIdleSource implements SystemIdleSource {
  /// `kCGEventSourceStateHIDSystemState` — the hardware event stream, which is
  /// what "the user touched the machine" means.
  static const int _hidSystemState = 1;

  /// `kCGAnyInputEventType` — any input event, defined as `UINT32_MAX`.
  static const int _anyInputEventType = 0xFFFFFFFF;

  static const String _frameworkPath =
      '/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices';

  _CGEventSourceSecondsSinceLastEventTypeDart? _secondsSinceLastEvent;

  MacOsIdleSource() {
    try {
      final library = DynamicLibrary.open(_frameworkPath);
      _secondsSinceLastEvent = library.lookupFunction<
          _CGEventSourceSecondsSinceLastEventTypeNative,
          _CGEventSourceSecondsSinceLastEventTypeDart>(
        'CGEventSourceSecondsSinceLastEventType',
      );
    } catch (error) {
      debugPrint('[WorkPulse] CoreGraphics idle source unavailable: $error');
      _secondsSinceLastEvent = null;
    }
  }

  @override
  bool get isAvailable => _secondsSinceLastEvent != null;

  @override
  Duration? idleTime() {
    final seconds = _secondsSinceLastEvent;
    if (seconds == null) return null;
    try {
      return secondsToDuration(seconds(_hidSystemState, _anyInputEventType));
    } catch (error) {
      debugPrint('[WorkPulse] CoreGraphics idle query failed: $error');
      return null;
    }
  }

  @override
  void dispose() {}

  /// Converts the API's floating-point seconds to a [Duration], rejecting the
  /// values that mean "no answer" rather than "no idle time".
  @visibleForTesting
  static Duration? secondsToDuration(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds < 0) return null;
    return Duration(microseconds: (seconds * 1000000).round());
  }
}

// --- Windows -------------------------------------------------------------

/// `LASTINPUTINFO { UINT cbSize; DWORD dwTime; }` — 8 bytes, both fields
/// 32-bit unsigned.
final class _LastInputInfo extends Struct {
  @Uint32()
  external int cbSize;

  @Uint32()
  external int dwTime;
}

typedef _GetLastInputInfoNative = Int32 Function(Pointer<_LastInputInfo>);
typedef _GetLastInputInfoDart = int Function(Pointer<_LastInputInfo>);

typedef _GetTickCountNative = Uint32 Function();
typedef _GetTickCountDart = int Function();

/// Reads system idle time from Win32.
///
/// `GetLastInputInfo` reports the tick count of the last input event; the
/// difference from `GetTickCount` is the idle time. Both are ordinary
/// user32/kernel32 calls with no special privileges.
class WindowsIdleSource implements SystemIdleSource {
  /// `GetTickCount` is a 32-bit millisecond counter, so it wraps roughly every
  /// 49.7 days. Subtracting in unsigned 32-bit space handles the wrap.
  static const int _tickCountModulus = 0x100000000;

  _GetLastInputInfoDart? _getLastInputInfo;
  _GetTickCountDart? _getTickCount;
  Pointer<_LastInputInfo>? _buffer;

  WindowsIdleSource() {
    try {
      final user32 = DynamicLibrary.open('user32.dll');
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      _getLastInputInfo =
          user32.lookupFunction<_GetLastInputInfoNative, _GetLastInputInfoDart>(
        'GetLastInputInfo',
      );
      _getTickCount =
          kernel32.lookupFunction<_GetTickCountNative, _GetTickCountDart>(
        'GetTickCount',
      );
      // Allocated once and reused: this is polled on a timer for as long as a
      // session runs, and a per-call malloc/free would be pure churn.
      _buffer = calloc<_LastInputInfo>();
    } catch (error) {
      debugPrint('[WorkPulse] Win32 idle source unavailable: $error');
      _getLastInputInfo = null;
      _getTickCount = null;
    }
  }

  @override
  bool get isAvailable => _getLastInputInfo != null && _getTickCount != null;

  @override
  Duration? idleTime() {
    final getLastInputInfo = _getLastInputInfo;
    final getTickCount = _getTickCount;
    final buffer = _buffer;
    if (getLastInputInfo == null || getTickCount == null || buffer == null) {
      return null;
    }

    try {
      buffer.ref.cbSize = sizeOf<_LastInputInfo>();
      if (getLastInputInfo(buffer) == 0) return null;
      return ticksToDuration(
        lastInputTick: buffer.ref.dwTime,
        currentTick: getTickCount(),
      );
    } catch (error) {
      debugPrint('[WorkPulse] Win32 idle query failed: $error');
      return null;
    }
  }

  @override
  void dispose() {
    final buffer = _buffer;
    _buffer = null;
    if (buffer != null) calloc.free(buffer);
  }

  /// Idle time between two `GetTickCount` values, wrapping correctly at the
  /// 32-bit boundary.
  @visibleForTesting
  static Duration ticksToDuration({
    required int lastInputTick,
    required int currentTick,
  }) {
    final elapsed = (currentTick - lastInputTick) % _tickCountModulus;
    return Duration(milliseconds: elapsed);
  }
}

/// A source under test control, used by widget and unit tests to drive the
/// detector without touching the host machine's real input state.
@visibleForTesting
class FakeIdleSource implements SystemIdleSource {
  Duration? current;

  @override
  bool isAvailable;

  FakeIdleSource({this.current, this.isAvailable = true});

  @override
  Duration? idleTime() => current;

  @override
  void dispose() {}
}
