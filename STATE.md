# STATE

> Last updated: 2026-08-23

Current working state. Superseded content is deleted, not archived.
For durable rules see METHOD.md.

## Current Focus

Approved spec for GameBrake v1. The reducer and its tests exist and are green;
nothing that touches Windows exists yet.

v1 runs. GameBrake.Core holds the reducer and the two stores, GameBrake.Windows
the watcher, the enforcer and the engine that wires them, GameBrake.Tray the
icon and the menu. 45 tests pass, 41 of them with no Windows and no real
process. The end-to-end script passes 15 of 15 against the running tray.

Two criteria are not closed, and neither is closable by a script:

- AC7 says rebooting. What is proven is that a deadline survives the tool being
  killed and restarted, which is the same file and the same code path. A real
  Windows restart has not been done, and only the user can do it.
- AC8 says visible without hunting. The tooltip, the menu and the balloon on a
  refused launch all exist and are exercised by tests, but whether the number is
  actually where a person looks is a judgement nobody has made yet.

AC9 is met for the tray, measured at 31 ms over 60 s, 0.05 percent of one core.
The WMI polling that feeds it lives in another process, and attributing that
cost has so far only produced noise. What can be said is that it is small enough
to hide under the run-to-run variation of background WMI activity.

### Problem

The impulse to play and the act of playing are separated by nothing — a
double-click closes the gap instantly, and by the time the cost is noticed the
session is already underway. Whole-machine blockers also take away the machine
for work; willpower is the thing already failing. What is missing is a
deliberate gap between impulse and play, applied only to chosen applications,
charged again on every session.

### Goals

- G1  Every launch of a user-selected Windows executable is interrupted, and
      that executable is kept from running for a cooldown (default 300 s).
- G2  The cooldown is charged per play session — not once ever, not once per day.
- G3  The protected set is editable at any time; any executable, not only games.
- G4  Anything not on the list is completely unaffected.
- G5  Starts with the Windows session; needs no manual arming.
- G6  Waiting out a cooldown grants a time-limited permission to launch;
      letting it expire costs a fresh cooldown.

G6 is a goal rather than an implementation detail: without it the tool can be
defeated by triggering every cooldown in the morning and playing freely after.

### Non-goals (v1)

- N1  URL / website cooling-off. Named as a possible later addition.
- N2  Whole-machine lock, screen lock, or schedule-based blocking.
- N3  Time budgets or quotas. The tool taxes each session start; it does not
      cap total playtime.
- N4  Interrupting a session already under way.
- N5  Any platform other than Windows.
- N6  Multi-user, remote, or accountability-partner features.
- N8  Packaged applications, meaning anything from the Microsoft Store or Game
      Pass. They live under WindowsApps at a path carrying a version number that
      moves on update, and full-path matching does not survive that. Out of
      scope because games here arrive through Steam, Epic and standalone
      installers, which are ordinary executables. Should that change, the
      decided answer is to treat the version segment of the package folder as a
      wildcard; it is not built until something needs it.
- N7  Tamper resistance. The tool runs in user mode and can be closed from Task
      Manager. It sells friction, not force: bypassing it takes a deliberate
      act, and that act is itself a moment of pause. This is chosen, not
      omitted — do not file it as a defect.

### Acceptance criteria

- AC1   With C:\Windows\System32\charmap.exe protected, launching it closes it
        within 2 s of the window appearing. The subject is a plain Win32
        executable on purpose: notepad.exe, which this criterion named until it
        was measured, is an app execution alias on Windows 11 and would let AC1
        pass while the window it was meant to close stayed open. See GOTCHAS.md.
- AC2   A further launch attempt during the cooldown is closed the same way and
        does not extend the remaining time.
- AC3   After the cooldown elapses, a launch inside the grace window succeeds
        and runs indefinitely.
- AC4   Letting the grace window expire without launching returns to the start:
        the next launch is charged a full cooldown.
- AC5   Quitting a permitted session and relaunching charges a fresh cooldown.
- AC6   An unprotected app launches normally at every point above.
- AC7   Rebooting mid-cooldown does not clear it — remaining time survives a
        restart of both the tool and Windows.
- AC8   Remaining time is visible without hunting for it.
- AC9   No measurable CPU when nothing is launching.
- AC10  The reducer is exercised by tests with no Windows API and no real
        process involved.

AC4 and AC7 both assert that something does not happen, which is what makes
them the two most likely to be silently skipped.

### Data contract

config.json — user-owned, hand-editable:

    {
      "cooldownSeconds": 300,
      "graceWindowSeconds": 300,
      "autostart": true,
      "protected": [
        { "id": "uuid",
          "executable": "C:\\Program Files\\Foo\\game.exe",
          "displayName": "Foo",
          "enabled": true }
      ]
    }

executable is matched on the full path, case-insensitively.

state.json — written by the tool, survives restart (AC7):

    {
      "<appId>": {
        "phase": "idle" | "cooling" | "unlocked" | "running",
        "cooldownEndsAt": "2026-08-23T10:05:00Z",
        "graceEndsAt": null
      }
    }

### API contract

    reduce(state, event, config) -> (state', action)   pure, no I/O, no clock
        event  : Tick(now) | LaunchAttempt(now, exePath, pid)
                 | ProcessExited(now, exePath)
        action : None | Terminate(pid) | Allow

    idle      --LaunchAttempt-->  Terminate; cooling,
                                  cooldownEndsAt = now + cooldownSeconds
    cooling   --LaunchAttempt-->  Terminate; state unchanged            (AC2)
    cooling   --Tick >= cooldownEndsAt-->  unlocked,
                                  graceEndsAt = cooldownEndsAt + graceWindowSeconds
    unlocked  --LaunchAttempt-->  Allow; running
    unlocked  --Tick >= graceEndsAt-->  idle                            (AC4)
    running   --ProcessExited-->  idle                                  (AC5)

    Watcher  : emits LaunchAttempt on every process start (WMI / ETW)
    Enforcer : carries out Terminate
    Store    : load() / save(state)                                     (AC7)

Two constraints hold this together:

- graceEndsAt is derived from cooldownEndsAt, never from the moment the tool
  noticed the expiry. Deriving it from observation time would let sleep or
  shutdown stretch the grace window into a bypass.
- reduce holds no clock of its own; now is always passed in. This is why AC10
  is reachable, and why time-dependent correctness can be tested without
  waiting five minutes for anything.

### Recorded assumptions

- A1  Terminate rather than suspend — nothing is lost at launch time.
- A2  After a cooldown the user relaunches manually; the tool does not do it.
      Auto-launch would hand back the friction the tool exists to add.
- A3  Retrying during a cooldown neither resets nor extends the timer.
      Resetting is punitive and could make an app permanently unreachable.
- A4  Matching is on the full executable path. A game launcher and the game
      binary are different executables; the user picks which one to protect.
- A5  A process already running when the tool starts is left alone.
- A6  Cooldown length is a single global value, not per-app.

## Next Steps

The Environment facts in AGENTS.md are complete: install, dev, test, build and
e2e have each been run, and typecheck and lint are none for the reasons under
Known Annoyances.

1. Reboot the machine mid-cooldown and confirm the remaining time is still owed.
   This closes AC7 as written and needs a person, not a script.
2. Look at the tray while a cooldown runs and decide whether AC8 is actually met.
   The number exists in three places; whether that is the right three is a
   judgement.
3. Live with it for a while against real games. Whether 300 seconds is the right
   number, and whether user-mode friction is enough (N7), are questions about the
   user rather than about the code, and only use answers them.

Not started, and deliberately: packaging or an installer. Running it from the
build output plus the autostart toggle is enough to find out whether the thing
works before deciding it deserves an installer.

## Open Questions

None blocking. The two the watcher probe raised are answered: AC1 now names a
plain executable, and packaged applications are N8.

Two remain deliberately deferred:

- URL / website cooling-off (N1). Deferred, not rejected. Whether it can reuse
  the same reducer is unexamined.
- Hardening to a SYSTEM service (N7). Revisit only if user-mode friction turns
  out to be insufficient in practice — a question about the user, not the code.

## Recent Findings

Measured 2026-08-23 by a throwaway probe, unelevated, on this machine only.
Six launches per configuration on an idle machine; nothing here says anything
about a loaded one.

- Win32_ProcessStartTrace raises "Access denied" unelevated. The unelevated
  route is __InstanceCreationEvent WITHIN 1, which works and does carry
  ExecutablePath. The user-mode decision settles the mechanism, it does not
  block it.
- Detection latency for a plain executable: median 347 ms, max 920 ms, against
  the 2 s AC1 allows.
- WITHIN 0.5 measured slower than WITHIN 1, not faster. Leave it at 1.
- The 1270 to 1521 ms first seen for notepad was the packaged-app launch chain,
  not WMI. It is not evidence about the watcher.
- Idle cost is NOT established. Attributing CPU to the subscription produced a
  negative delta, which means the cost sits under the run-to-run noise of
  background WMI activity in the host processes. That is not the same as zero.
  AC9 must not be recorded as met on the strength of it.

## Known Annoyances

- scripts/e2e.ps1 writes to the real %APPDATA%\GameBrake, because that is where
  the tool it is testing looks. Running it replaces config.json and state.json.
  Anything real in there should be copied aside first.
- AGENTS.md now names scripts/e2e.ps1, but the path-reference check in
  scripts/check.sh only looks at .md, .sh, .json, .yaml and .txt. Renaming the
  e2e script would not be caught. Worth sending upstream rather than fixing here.

- No linter or analyzer is configured, so lint is "none" in AGENTS.md. Any
  verification that reports lint as passing would be reporting a command that
  never ran. Whether to add one has not been decided.
- typecheck is also "none", but for a different and harmless reason: C# has no
  type-check step separate from build. Reading it as a gap would be a mistake.
- dotnet test now launches and closes real charmap.exe windows, and takes about
  8 seconds longer for it. That is the price of AC1 being tested rather than
  assumed, but it does mean the suite is no longer silent or instant.
- One assertion in GameBrake.Windows.Tests is a wall-clock deadline: a launch
  must be seen inside 2 s, which is AC1 itself. It held on four consecutive runs
  on an idle machine, against a measured median of 347 ms. A heavily loaded
  machine is untested and could make it fail. If it ever does, the finding is
  about AC1, not about the test.

## Recent Decisions

- Grace window over open-ended permission (G6, AC4). An unexpiring permission
  would let every cooldown be pre-paid in the morning, leaving the rest of the
  day unguarded. Cost: one extra config value and one extra state transition.
- User-mode tray app over a SYSTEM service (N7). The smaller version is
  sufficient because what the tool sells is a pause, not a wall, and a
  user-mode app already delivers a pause. A service brings service/UI
  separation, IPC, an installer, and an unlock back door — none of which the
  problem statement asks for yet.
- AC1 changed subject from notepad.exe to charmap.exe after measurement, and
  packaged applications became N8. Both came from the same finding, and the
  first is the more uncomfortable one: an acceptance criterion written to catch
  a tool that reports success while doing nothing could itself have been passed
  by a tool doing nothing. It was approved, reviewed, and wrong, and only
  running it revealed that.
- C# / .NET for the stack. Process watching, autostart, and tray UI are all
  first-class on Windows, and it is the same toolchain if N7 is ever revisited.
  Local SDK confirmed at 10.0.400.
- GameBrake.Core targets net10.0, not net10.0-windows. AC10 asks for a reducer
  that can be tested with no Windows API involved; targeting the neutral
  framework makes reaching for one a compile error rather than a thing to
  remember. The Windows-facing projects will target net10.0-windows on their own.
- Expiries are applied inside reduce, before the event is examined, rather than
  only on Tick. A decision must never depend on a Tick having arrived on time: a
  launch landing between two ticks, or a machine asleep across an entire
  cooldown, would otherwise be judged against a deadline that had already passed.
- The stores live in GameBrake.Core under Storage/ rather than in a project of
  their own. What the contract asks for is that reduce be pure, which its
  signature already guarantees; a second assembly would buy nothing a folder
  does not. Revisit if anything outside the host ever needs one without the other.
- A damaged config.json or state.json raises rather than falling back to empty.
  Reading a damaged state file as "nothing owed" would make corrupting it the
  cheapest way out of every cooldown at once, and reading a damaged config as
  "nothing protected" would silently disarm the tool. How the host should
  present that failure is not decided, because there is no host yet.
- Process exits are noticed by holding the permitted process and taking its
  Exited event, not by a second WMI subscription. A deletion subscription would
  double the polling that AC9 is about, to answer a question that is already
  exactly answerable: the only exit that matters is that of a process this tool
  permitted, and its identity is known at the moment it is permitted.
- The tray keeps no policy of its own. Everything it shows comes from
  BrakeEngine.Status, and every decision comes back from Reducer.Reduce. The
  engine sits behind IProcessWatcher and IProcessTerminator so the wiring can be
  tested with a fake watcher and a clock under the test, which is where
  forgetting to save state or forgetting to follow a permitted process would
  otherwise hide until a real game found it.
- State is written to disk before the terminate is carried out, not after. If
  the process dies between the two, the cooldown is still owed. The other order
  loses it, and losing it is the failure that matters.
- Quitting from the tray asks once when a cooldown is running. Closing the tool
  stays possible by decision (N7), but the usual reason for being in that menu
  is irritation at a countdown, and one question is the cheapest possible pause.
- Terminate ends one process, never its tree. A game started from a launcher is
  a child of that launcher, and taking the tree would close the launcher with it.
- state.json is written to a temporary file and then moved over the target.
  It is rewritten on every transition, and a torn write would leave a file that
  does not parse, which by the decision above stops the tool rather than
  clearing the cooldown, but either way losing power should not enter into it.
