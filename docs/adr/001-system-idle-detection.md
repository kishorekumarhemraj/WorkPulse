# ADR 001 — System Idle Detection

- **Status**: Accepted
- **Date**: 2026-08-24
- **Supersedes**: the in-process activity timestamp in `DesktopIdleDetectorService`

## Context

`WORKPULSE_SPEC.md` §31 defines idle as *"no detectable keyboard/mouse
interaction occurred for the configured period"*, and §54 rules out keystroke
logging, application-usage monitoring, and anything of that kind. Those two
constraints together are the whole design problem: WorkPulse must know that the
machine has been untouched, without watching what the user does on it.

The implementation being replaced did not satisfy either half.

`DesktopIdleDetectorService` kept a `_lastActivityTime` field and exposed
`recordUserActivity()` to move it forward. **Nothing in the codebase ever called
`recordUserActivity()`.** The field only advanced when monitoring started or
when an idle event had just fired, so the detector was, in effect, a repeating
timer rather than an idle detector.

That defect was masked by a second one. `MainShellView` reacted to the timer
provider with an unfiltered `ref.listen`, and the timer republishes its state
once a second so the on-screen clock ticks. Each of those emissions called
`startMonitoring(isTracking: true)`, which cancelled the 10-second polling
timer and recreated it. The poll therefore never survived long enough to run.
The net effect: **live idle detection never fired at all**, on any platform, in
any released version. Only startup gap recovery (from the persisted heartbeat)
worked, and it is a different mechanism answering a different question.

Fixing only the restart loop would have been worse than leaving it alone: the
detector would have started firing on a fixed schedule regardless of activity,
prompting a user who had been typing continuously to account for time they had
plainly worked.

## Decision

Read idle time from the operating system rather than tracking activity in
process, behind a `SystemIdleSource` interface in `lib/core/platform/`.

| Platform | API | Access |
| :--- | :--- | :--- |
| macOS | `CGEventSourceSecondsSinceLastEventType(kCGEventSourceStateHIDSystemState, kCGAnyInputEventType)` | `dart:ffi` into `ApplicationServices.framework` |
| Windows | `GetLastInputInfo` + `GetTickCount` | `dart:ffi` into `user32.dll` / `kernel32.dll` |
| Everything else | — | `UnavailableIdleSource` |

Three properties made this the right shape:

- **It is a query, not an observation.** Both APIs return a single aggregate
  the OS already maintains. Neither reports *which* keys were pressed or which
  application had focus, so the privacy boundary in §54 holds by construction.
- **It needs no permission.** `CGEventSourceSecondsSinceLastEventType` is
  readable from inside the macOS App Sandbox and does not require Accessibility
  access, unlike an event tap. `GetLastInputInfo` is an ordinary user32 call.
- **It answers the right question.** WorkPulse exists to keep running while the
  user works in *other* applications. Activity observed inside WorkPulse's own
  window would have been the wrong signal.

`dart:ffi` was chosen over a platform channel or a plugin because both calls are
small, synchronous, stable C entry points. A method channel would have meant
Swift and C++ runner code on both platforms for two function calls, and would
have put a message hop on a path that runs every ten seconds.

Two supporting changes make the detector behave:

- `startMonitoring` is idempotent. Calling it with the state it is already in
  is a no-op, so a caller that fires repeatedly cannot restart the poll.
- The shell listens to `timerProvider.select((s) => s.value?.isRunning)`, so
  `_syncActivityMonitors` runs on transitions rather than on every tick.

## Consequences

**Idle detection works**, for the first time, on macOS and Windows.

**An unavailable source never prompts.** `idleTime()` returns `null` for "cannot
tell", which the detector treats as "no answer" rather than "no idle time". A
failed `DynamicLibrary.open`, an unexpected return value, and Linux all land in
the same safe state: the behaviour the app had before, minus the false prompts.
`isSupported` is logged once at start so the degradation is visible rather than
silent.

**Startup gap recovery is unaffected.** It reads the persisted heartbeat, not
the OS counter, and continues to cover time the process was not running — which
no live source can see.

**The default threshold moved from 5 to 10 minutes**, matching the spec. Since
the live detector never fired, this changes only the threshold used by startup
gap recovery. It is now user-configurable, as §31 requires.

**Linux has no live idle detection.** The Linux desktop has no single portable
equivalent; `org.freedesktop.ScreenSaver`'s `GetSessionIdleTime` is the closest,
but it is inconsistently implemented across desktop environments. Linux is not a
shipping target, so this is recorded as known debt rather than worked around.

**Two native calls are untestable in CI.** The FFI lookups only run on their own
platform. The pure logic each wraps — the seconds-to-`Duration` conversion, the
32-bit `GetTickCount` wraparound — is unit-tested, and the detector itself is
tested end to end against an injected `FakeIdleSource`. The FFI signatures
themselves are only verified by actually running on macOS and Windows.

## Alternatives considered

- **Feed in-app input events to `recordUserActivity()`.** Roughly ten lines and
  no native code, but it answers the wrong question: a user writing a document
  in another application for six hours would be prompted every ten minutes.
- **Shell out to `ioreg -c IOHIDSystem` (macOS) and PowerShell (Windows).** No
  FFI, but it spawns a process every ten seconds for the life of every session,
  and parses human-readable output. PowerShell start-up alone costs hundreds of
  milliseconds.
- **A platform channel or a published plugin.** More runner code and a message
  hop for two synchronous C calls, or a new third-party dependency on the path
  that decides whether the user's tracked time is real.
