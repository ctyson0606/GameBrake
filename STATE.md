# STATE

> Last updated: 2026-08-23

Current working state. Superseded content is deleted, not archived.
For durable rules see METHOD.md.

## Current Focus

Approved spec for GameBrake v1. The reducer and its tests exist and are green;
nothing that touches Windows exists yet.

Built so far: GameBrake.Core (the reducer, pure) and GameBrake.Core.Tests
(13 tests, all passing). Every acceptance criterion below that is about policy
rather than about Windows is already covered there.

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
- N7  Tamper resistance. The tool runs in user mode and can be closed from Task
      Manager. It sells friction, not force: bypassing it takes a deliberate
      act, and that act is itself a moment of pause. This is chosen, not
      omitted — do not file it as a defect.

### Acceptance criteria

- AC1   With notepad.exe protected, launching it closes it within 2 s of the
        window appearing.
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

Done: the solution scaffold, the reducer, and its tests. AGENTS.md Environment
facts are filled in for install, test and build, each having actually been run.

1. Store: load and save config.json and state.json. This completes AC7 — the
   reducer half is covered, what is missing is that absolute deadlines survive a
   real round trip through disk.
2. Watcher: emit LaunchAttempt on every process start, and ProcessExited.
   Windows-facing, so a separate net10.0-windows project.
3. Enforcer: carry out Terminate.
4. Tray host: wire the four together, show remaining time (AC8), start with the
   session (G5).
5. Then AC1 to AC9 against real processes, and fill in the dev and e2e
   Environment facts, which are blank today because there is nothing to run.

## Open Questions

None blocking. Two deliberately deferred:

- URL / website cooling-off (N1). Deferred, not rejected. Whether it can reuse
  the same reducer is unexamined.
- Hardening to a SYSTEM service (N7). Revisit only if user-mode friction turns
  out to be insufficient in practice — a question about the user, not the code.

## Known Annoyances

- No linter or analyzer is configured, so lint is "none" in AGENTS.md. Any
  verification that reports lint as passing would be reporting a command that
  never ran. Whether to add one has not been decided.
- typecheck is also "none", but for a different and harmless reason: C# has no
  type-check step separate from build. Reading it as a gap would be a mistake.

## Recent Decisions

- Grace window over open-ended permission (G6, AC4). An unexpiring permission
  would let every cooldown be pre-paid in the morning, leaving the rest of the
  day unguarded. Cost: one extra config value and one extra state transition.
- User-mode tray app over a SYSTEM service (N7). The smaller version is
  sufficient because what the tool sells is a pause, not a wall, and a
  user-mode app already delivers a pause. A service brings service/UI
  separation, IPC, an installer, and an unlock back door — none of which the
  problem statement asks for yet.
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
