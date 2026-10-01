# SPEC

The contract this project is built against: what the spec gate produced and a
person approved. It stays true for as long as the code does, so it is kept
apart from STATE.md, which is replaced as the work moves.

Change it only through the spec gate, never as you go. What no longer holds is
rewritten in place, not appended to; git holds the history.

## Problem

The impulse to play and the act of playing are separated by nothing — a
double-click closes the gap instantly, and by the time the cost is noticed the
session is already underway. Whole-machine blockers also take away the machine
for work; willpower is the thing already failing. What is missing is a
deliberate gap between impulse and play, applied only to chosen applications,
charged again on every session.

## Goals

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

## Non-goals (v1)

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
- N8  Packaged applications, meaning anything from the Microsoft Store or Game
      Pass. They live under WindowsApps at a path carrying a version number that
      moves on update, and full-path matching does not survive that. Out of
      scope because games here arrive through Steam, Epic and standalone
      installers, which are ordinary executables. Should that change, the
      decided answer is to treat the version segment as a wildcard; it is not
      built until something needs it.

## Acceptance criteria

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

## Data and API contract

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

Those four keys and no others: anything the tool writes it must also be able to
read back. executable is matched on the full path, case-insensitively.

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

    Watcher  : emits LaunchAttempt on every process start (WMI)
    Enforcer : carries out Terminate
    Store    : load() / save(state)                                     (AC7)

Two constraints hold this together:

- graceEndsAt is derived from cooldownEndsAt, never from the moment the tool
  noticed the expiry. Deriving it from observation time would let sleep or
  shutdown stretch the grace window into a bypass.
- reduce holds no clock of its own; now is always passed in. This is why AC10
  is reachable, and why time-dependent correctness can be tested without
  waiting five minutes for anything.

## Assumptions

- A1  Terminate rather than suspend — nothing is lost at launch time.
- A2  After a cooldown the user relaunches manually; the tool does not do it.
      Auto-launch would hand back the friction the tool exists to add.
- A3  Retrying during a cooldown neither resets nor extends the timer.
      Resetting is punitive and could make an app permanently unreachable.
- A4  Matching is on the full executable path. A game launcher and the game
      binary are different executables; the user picks which one to protect.
      This survived the Valorant fix intact and is worth keeping that way.
      One entry per game, and it is the binary that owns the session: two links
      of one chain are two ids, two states and two cooldowns, and will charge
      twice as soon as their processes stop moving together.
- A5  A process already running when the tool starts is left alone. This is
      cheap to say and expensive in practice; see Known Annoyances.
- A6  Cooldown length is a single global value, not per-app.
