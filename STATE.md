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

AC8 is met, judged by the user on 2026-08-23 after the countdown moved into the
icon. The tooltip alone was not enough: it froze while on screen, which is a
shell behaviour and not a defect in the tool, and no amount of updating the text
could have fixed it.

AC7 is met, measured on 2026-08-23 across a real Windows restart. A cooldown was
charged at 17:36:48 with a deadline of 17:41:48, the machine rebooted at 17:37:28
forty seconds into it, the tray came back on its own 81 seconds after boot, and
at 17:41:05 it still read cooling with 43 seconds left. state.json had not been
rewritten since 17:36:48, so the file written before the restart is the one that
stayed in force: the deadline was honoured, not reset, and the remaining time
counted down through the reboot.

All ten acceptance criteria are now closed.

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

1. Live with it against real games. Whether 300 seconds is the right number, and
   whether user-mode friction is enough (N7), are questions about the user rather
   than about the code, and only use answers them.
2. Decide what to do about the git author address and the Co-Authored-By trailer
   before the first push. Nothing has been pushed since the initial commit.

Published to the per-user programs folder rather than run from the build output,
because autostart records an absolute path and dotnet clean would otherwise
break it silently. That is a copied folder, not an installer, and an installer
is still deliberately not started.

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

## Recent Decisions from use

First real session on 2026-08-23 found two things a passing suite had not.

- Configuration.Cooldown, a getter with no setter, was being serialised into
  config.json. It could not be read back, so the file carried a second thing
  that looked like the cooldown setting, next to the real one, doing nothing.
  Edited by hand instead of cooldownSeconds, it changed nothing and said nothing.
  Now [JsonIgnore]. The test that should have caught it used Assert.Contains,
  which can only notice a key that went missing, never one that turned up
  uninvited; it now asserts the exact key set.
- The tray tooltip does not update while it is on screen. The shell reads a
  notify icon tooltip once, when it appears, and never again, so a countdown
  there stands still until the pointer leaves and comes back. Reported from use.
  Rather than replace it with a custom window that chases the pointer, the
  countdown is drawn into the icon, which redraws in place and needs no pointer
  at all. That is closer to what AC8 asks for than the tooltip ever was.
- The icon shows one digit and never two. Sixteen pixels is what the shell asks
  for, and two digits rendered into that are a smudge: 59 and 28 were drawn and
  looked at, and both were unreadable while 5 and 9 were clear. So it counts
  minutes, 5 4 3 2 1, then turns green. Showing nothing at all under a minute
  was tried first and left a blank disc that read as a broken icon.
- The ring sweeps the seconds within the current minute, not the whole cooldown.
  Against five minutes it moves a third of a percent per second and stands
  visibly still, which was the original complaint restated in another form.
- The integration tests fought a running copy of the product for the subject
  process. A process that starts and dies inside the one-second WMI polling
  window raises no creation event at all, so the failure read as the watcher
  never seeing the launch. The fixture now refuses to run while GameBrake.Tray
  is up, and says why.

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
- Nothing enforces anything for the first minute or so after a reboot. The tray
  autostarted 81 seconds after boot in the run that closed AC7, and until it is
  up a protected application launches untouched. A cooldown already owed still
  survives, so this is not a way out of one, but it is a way to start a fresh
  session free by rebooting first. Closing it means running before the user
  session, which is the service this project decided against (N7). Recorded
  rather than fixed.
- Nothing tests TrayIconArt. It was verified by rendering every state to a file
  and looking at it, which is how the two digit problem was found, but there is
  no test holding the one-digit rule in place. A change that reintroduces two
  characters would go unnoticed until someone looked at the tray.
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
