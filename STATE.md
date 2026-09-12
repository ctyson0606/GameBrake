# STATE

> Last updated: 2026-09-12

Current working state. Superseded content is deleted, not archived.
For durable rules see METHOD.md.

## Current Focus

v1 is done and in daily use. GameBrake.Core holds the reducer and the two
stores, GameBrake.Windows the watcher, the enforcer and the engine that wires
them, GameBrake.Tray the icon and the menu. 50 tests pass, 29 of them with no
Windows and no real process. The end-to-end script passes 15 of 15.

All ten acceptance criteria are closed. The two that needed a person rather than
a script:

- AC7, measured across a real Windows restart. A cooldown was charged at
  17:36:48 with a deadline of 17:41:48, the machine rebooted at 17:37:28 forty
  seconds into it, the tray came back on its own 81 seconds after boot, and at
  17:41:05 it still read cooling with 43 seconds left. state.json had not been
  rewritten since 17:36:48, so the file written before the restart is the one
  that stayed in force.
- AC8, judged by the user after the countdown moved into the icon. The tooltip
  alone was not enough: it freezes while on screen, which is shell behaviour and
  not a defect here, so no amount of updating the text would have served.

It brakes the game it was built for, with one binary protected rather than two.
VALORANT-Win64-Shipping.exe is the entry that works, and config.json holds it
alone. The first run had VALORANT.exe protected as well, which charged the two
sixteen milliseconds apart on coinciding deadlines and was written down here as
one wait rather than two. Using it again showed that was a description of one
launch and not of the arrangement: with both protected the user was blocked a
second time, after the first cooldown had already been waited out. With only
VALORANT.exe protected the game is not stopped at all. Neither of those needs
explaining away: two entries are two ids and therefore two independent cooldowns,
which look like one wait only while both processes happen to sit in the same
phase, and Terminate ends one process and never its tree, so ending the first
link of a chain leaves the game running. One entry per game, and it is the binary
that owns the session.

Installed at %LOCALAPPDATA%\Programs\GameBrake and started from the Run key, so
it is independent of the build output. What sits there is now the single file
dist/ holds, replacing the eleven files of bin/Release/net10.0-windows that were
copied whole until 2026-09-12. The Run key needed no edit across that change and
was not touched: it already held the absolute path the new file took over. A
change reaches daily use only when that one file is copied again.

A security review on 2026-08-23 read every source file and turned up one thing
worth fixing: the single-instance mutex could be taken by anything in the
session, after which the tray exited without a word at every start. It now
checks whether a second GameBrake process actually exists before standing down.
Built, tested, installed, and confirmed against the installed executable rather
than the build output.

The review found nothing else to act on. There is no network code and no
third-party dependency beyond System.Management; the manifest is asInvoker; the
only registry key touched is HKCU Run, whose value is correctly quoted;
deserialisation is System.Text.Json onto records with no polymorphism; and the
single Process.Start call takes a fixed path. What the tool can see is wide and
what it retains is nothing — see METHOD.md, which now holds that as a rule.

The repository now explains itself to somebody who has not read the source.
README.md, README.zh-TW.md and README.zh-CN.md cover what the tool is, the four
phases and the two properties worth knowing about them, building it, packing it
into one self-contained file and copying that somewhere of its own, the
SmartScreen warning an unsigned file gets on first launch, every key in
config.json, and why the game binary is the thing to protect rather than the
launcher. Everything in them was read out of the source rather than out of
this file. Licensed MIT.

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
- N8  Packaged applications, meaning anything from the Microsoft Store or Game
      Pass. They live under WindowsApps at a path carrying a version number that
      moves on update, and full-path matching does not survive that. Out of
      scope because games here arrive through Steam, Epic and standalone
      installers, which are ordinary executables. Should that change, the
      decided answer is to treat the version segment as a wildcard; it is not
      built until something needs it.

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

### Recorded assumptions

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

## Next Steps

Nothing is outstanding in the code. The Environment facts in AGENTS.md are
complete: install, dev, test, build, e2e and pack have each been run, and
typecheck and lint are none for the reasons under Known Annoyances. pack is not
one of the keys the framework names; it was added because a build command nobody
lists is a build command the next session does not know exists.

1. Live with it. Whether 300 seconds is the right number, and whether user-mode
   friction is enough (N7), are questions about the user and only use answers
   them.
2. If the answer to either turns out to be no, the decided next moves are
   already written down: a longer cooldown is one config value, and hardening is
   the SYSTEM service under N7.

Packaging goes as far as one file and no further. scripts/pack.ps1 publishes
self-contained and single-file into dist/, giving a 49.4 MB GameBrake.Tray.exe
that needs no .NET on the machine it runs on, and the READMEs give that as the
install procedure: run the script, copy one file, tick Start with Windows. The
script fails if dist/ ends up holding anything besides that executable, which is
the only claim it makes.

Nothing beyond that is built: no installer, no Start Menu entry, no entry in
Add or Remove Programs, and no signature, so every first launch shows SmartScreen.
An installer was the alternative on the table and was not taken, on the grounds
that copying one file is already the whole procedure.

## Open Questions

None blocking.

The two Valorant behaviours were briefly written here as open questions and are
not. Charging twice for two entries, and failing to stop a game whose first link
was the protected one, are both what the data contract and the Terminate decision
say will happen. Recording a documented consequence as a mystery invites someone
to go and measure what is already written down two sections away.

Two remain deliberately deferred:

- URL / website cooling-off (N1). Deferred, not rejected. Whether it can reuse
  the same reducer is unexamined.
- Hardening to a SYSTEM service (N7). Revisit only if user-mode friction turns
  out to be insufficient in practice — a question about the user, not the code.

## Measurements

All on this machine, unelevated, 2026-08-23. Idle machine throughout; nothing
here says anything about a loaded one.

- Detection latency for a plain executable, WMI __InstanceCreationEvent WITHIN 1,
  six launches: median 347 ms, max 920 ms, against the 2 s AC1 allows.
- WITHIN 0.5 measured slower than WITHIN 1, not faster: median 537 ms, max
  705 ms. There is no margin to buy by shortening it.
- Win32_ProcessStartTrace raises "Access denied" unelevated, which settles the
  mechanism rather than blocking it.
- The 1270 to 1521 ms first seen for notepad was the packaged-app launch chain,
  not WMI, and is not evidence about the watcher.
- Tray idle cost: 31 ms over 60 s, 0.05 percent of one core. This is what AC9 is
  recorded as met on. A separate attempt to attribute the WMI subscription's own
  cost, which lives in other processes, produced a negative delta and settled
  nothing; that cost is under the noise floor of background WMI activity, which
  is not the same as zero.

Packaging, same machine, 2026-09-12.

- Single-file self-contained: 111 MB uncompressed, 49.4 MB with
  EnableCompressionInSingleFile. The folder it replaced was eleven files and
  0.6 MB, which is what borrowing the machine's installed .NET costs instead.
- Compression does not slow the start. Time from Start-Process to the
  single-instance mutex existing, five launches each: compressed single file 164,
  92, 89, 90, 92 ms; the framework-dependent folder it replaced 102, 45, 45, 137,
  107 ms. Medians 92 and 102 ms, and the two ranges overlap.
  What this measures is managed Main being entered, since the mutex is taken on
  its first line. It says nothing about when the watcher is live, which is the
  number that would matter for how long after login the tool is blind.
- The installed single file intercepts charmap: terminated after 358 ms and, on a
  second attempt during the cooldown, 799 ms, both inside the 2 s AC1 allows.
  cooldownEndsAt read 2026-09-12T09:51:33.6549772Z after both, unchanged, which
  is AC2 observed rather than inferred from the reducer tests.

## Decisions

Design-time, in the order they still matter.

- Grace window over open-ended permission (G6, AC4). An unexpiring permission
  would let every cooldown be pre-paid in the morning, leaving the rest of the
  day unguarded. Cost: one extra config value and one extra state transition.
- User-mode tray app over a SYSTEM service (N7). What the tool sells is a pause,
  not a wall, and a user-mode app already delivers a pause. A service brings
  service/UI separation, IPC, an installer, and an unlock back door — none of
  which the problem statement asks for.
- C# / .NET for the stack. Process watching, autostart, and tray UI are all
  first-class on Windows, and it is the same toolchain if N7 is ever revisited.
- GameBrake.Core targets net10.0, not net10.0-windows. AC10 asks for a reducer
  testable with no Windows API involved; the neutral framework makes reaching
  for one a compile error rather than a thing to remember.
- Expiries are applied inside reduce, before the event is examined, rather than
  only on Tick. A decision must never depend on a Tick having arrived on time: a
  launch landing between two ticks, or a machine asleep across an entire
  cooldown, would otherwise be judged against a deadline already passed.
- The stores live in GameBrake.Core under Storage/ rather than in a project of
  their own. What the contract asks is that reduce be pure, which its signature
  guarantees; a second assembly buys nothing a folder does not.
- A damaged config.json or state.json raises rather than falling back to empty.
  Reading damaged state as "nothing owed" would make corrupting it the cheapest
  way out of every cooldown at once, and reading a damaged config as "nothing
  protected" would silently disarm the tool. The tray says so in a dialog and
  carries on with nothing protected until the file is valid again.
- Process exits are noticed by holding the permitted process and taking its
  Exited event, not by a second WMI subscription. A deletion subscription would
  double the polling AC9 is about, to answer a question already exactly
  answerable: the only exit that matters is that of a process this tool
  permitted, and its identity is known the moment it is permitted.
- The tray keeps no policy of its own. Everything it shows comes from
  BrakeEngine.Status and every decision from Reducer.Reduce. The engine sits
  behind IProcessWatcher and IProcessTerminator so the wiring can be tested with
  a fake watcher and a clock under the test, which is where forgetting to save
  state or forgetting to follow a permitted process would otherwise hide until a
  real game found it.
- State is written to disk before the terminate is carried out, not after. If
  the process dies between the two, the cooldown is still owed. The other order
  loses it, and losing it is the failure that matters.
- state.json is written to a temporary file and then moved over the target, so a
  torn write cannot leave a file that does not parse.
- Terminate ends one process, never its tree. A game started from a launcher is
  a child of that launcher, and taking the tree would close the launcher too.
- Quitting from the tray asks once when a cooldown is running. Closing the tool
  stays possible by decision (N7), but the usual reason for being in that menu
  is irritation at a countdown, and one question is the cheapest possible pause.
- The single-instance check verifies rather than infers. A taken mutex name is
  evidence that somebody holds the name, not that another copy is running, and
  the two part company the moment anything else takes it first. So the tray asks
  the question the name was standing in for: is there a second GameBrake process?
  If not, there is nothing to collide over, and whoever holds the name may keep
  it. The process name is read from the running process rather than written down,
  so renaming the executable cannot quietly turn the check into one that never
  matches.
- MIT rather than no licence at all. Nothing here was being withheld, and a
  repository with no licence is one nobody may legally reuse — which is a
  stricter position than was ever intended, arrived at by omission.
- Three READMEs rather than one English file with a note. The tool is used in
  Chinese and read in English, and a translation that exists is read while a
  translation that is promised is not. The cost is that the three have to be
  edited together, which check.sh enforces.
- One self-contained file rather than a folder of eleven, and rather than an
  installer. The folder was the thing being complained about: eleven files of
  which any one going missing is a failure with no symptom until a launch is not
  intercepted. An installer would add a Start Menu entry and an Add or Remove
  Programs row, and would cost a build-time dependency on Inno Setup and a second
  place that writes the Run key — and the Run key is already written by the tray,
  which means two writers for one value and a question about who clears it. What
  it would not shorten is the install: copying one file is already the procedure.
- Compression on, though it is paid at every start rather than once. 111 MB is a
  file that is awkward to move anywhere; 49 MB is not. It was turned on before
  being measured and would have been kept either way, which is the wrong order —
  the measurement showing no cost is luck, not vindication.
- DebugType none, so no .pdb ships. The 48 KB is not the reason; a single file
  being single is. The consequence is under Known Annoyances and is real.
- The published file keeps the name GameBrake.Tray.exe. Shortening it to
  GameBrake.exe reads better and breaks the single-instance check, which compares
  process names: the renamed copy and an older installed one cannot see each
  other, so both run, both watch, and both write state.json. Making the name safe
  to change means changing that check, which is worth doing only if the name ever
  needs to change for a reason better than how it looks.

## What using it changed

Everything here was found by running the thing, and none of it by a passing
suite.

- AC1 changed subject from notepad.exe to charmap.exe after measurement, and
  packaged applications became N8. The uncomfortable part: an acceptance
  criterion written to catch a tool that reports success while doing nothing
  could itself have been passed by a tool doing nothing. It was approved,
  reviewed, and wrong, and only running it revealed that.
- Configuration.Cooldown, a getter with no setter, was being serialised into
  config.json and dropped on the way back in. The file carried a second thing
  that looked like the cooldown setting, next to the real one, doing nothing.
  Edited by hand instead of cooldownSeconds it changed nothing and said nothing.
  Now [JsonIgnore], with a test asserting the exact key set and another that
  round-trips a saved configuration.
- The tray tooltip does not update while it is on screen; the shell reads it
  once, when it appears. The countdown moved into the icon, which redraws in
  place and needs no pointer at all — closer to what AC8 asks for than the
  tooltip ever was.
- The icon shows one digit and never two. Sixteen pixels is what the shell asks
  for, and two digits rendered into that are a smudge: 59 and 28 were drawn and
  looked at, both unreadable, while 5 and 9 were clear. So it counts minutes,
  5 4 3 2 1, then turns green. Showing nothing under a minute was tried first
  and left a blank disc that read as a broken icon.
- The ring sweeps the seconds within the current minute, not the whole cooldown.
  Against five minutes it moves a third of a percent per second and stands
  visibly still, which was the original complaint restated in another form.
- Win32_Process reports no ExecutablePath for a process Vanguard protects, and
  the watcher discarded every start it could not name, so Valorant was invisible
  and state.json never held an entry for it. The watcher now falls back to
  QueryFullProcessImageName, which needs only PROCESS_QUERY_LIMITED_INFORMATION
  and returns the real path. Termination was checked first and was never the
  obstacle: PROCESS_TERMINATE is granted for both game binaries. Checking that
  first is what kept A4 intact, since the alternative on the table was to loosen
  matching to a file name.
- Protecting both binaries of the Valorant chain is wrong, and it looked right
  for exactly one launch. Charged sixteen milliseconds apart with coinciding
  deadlines, it was recorded as a single wait; used again, with both still
  protected, it blocked the user a second time after the first cooldown had been
  waited out. That is the contract working rather than failing: two entries are
  two independent cooldowns, and they look like one wait only while the two
  processes sit in the same phase, which stops being true as soon as their
  lifetimes differ. Protecting VALORANT.exe alone does not stop the game either,
  for the equally undramatic reason that Terminate never takes the tree. Only
  VALORANT-Win64-Shipping.exe is protected now. What is worth keeping is not the
  wrong entry but how it was arrived at: one cycle was watched, and what it
  implied was written down as though it had been seen.
- The Riot launcher cannot usefully be protected. It puts itself in the Run key
  in background mode, so it is resident from login and exempt under A5, and
  pressing Play wakes it rather than starting it. Protecting it only killed
  helper instances and charged cooldowns for them while the game went on.
  Protect game binaries, not launchers.

## Known Annoyances

- A5 is a bigger hole than it sounds. Anything that starts itself at login wins
  the race against the tray, which came up 81 seconds after boot in the run that
  closed AC7, and is then exempt for the whole session. For a resident launcher
  that is permanent, not a one-minute window. A cooldown already owed still
  survives a reboot, so this is no way out of one, but it is a way to start a
  fresh session free. Closing it means running before the user session, which is
  the service this project decided against (N7). Recorded rather than fixed.
- dotnet test cannot be green while GameBrake.Tray is running. The four
  integration tests refuse to start and say why, because a running copy kills
  the subject process faster than WMI polls and the failure otherwise reads as
  the watcher never seeing the launch. Exit the tray before running the suite.
- dotnet test launches and closes real charmap.exe windows and takes about
  8 seconds longer for it. That is the price of AC1 being tested rather than
  assumed.
- One assertion in GameBrake.Windows.Tests is a wall-clock deadline: a launch
  must be seen inside 2 s, which is AC1 itself. It has held on every run on an
  idle machine, against a measured median of 347 ms. A heavily loaded machine is
  untested. If it ever fails, the finding is about AC1, not about the test.
- Nothing tests TrayIconArt. It was verified by rendering every state to a file
  and looking at it, which is how the two-digit problem was found, but no test
  holds the one-digit rule in place. A change that reintroduces two characters
  would go unnoticed until someone looked at the tray.
- state.json keeps an entry for an application after it is removed from
  config.json. Nothing reads it, since Status walks the configuration, but the
  file grows and reading it by hand is confusing. Four orphans are in there now,
  against one live entry, and the count only goes up as protected applications
  are tried and dropped.
- scripts/e2e.ps1 writes to the real %APPDATA%\GameBrake, because that is where
  the tool it tests looks. Running it replaces config.json and state.json.
  Anything real in there should be copied aside first.
- AGENTS.md names scripts/e2e.ps1, but the path-reference check in
  scripts/check.sh only looks at .md, .sh, .json, .yaml and .txt. Renaming the
  e2e script would not be caught. Worth sending upstream rather than fixing here.
- No linter or analyzer is configured, so lint is "none" in AGENTS.md. Any
  verification reporting lint as passing would be reporting a command that never
  ran. Whether to add one has not been decided.
- typecheck is also "none", but for a different and harmless reason: C# has no
  type-check step separate from build. Reading it as a gap would be a mistake.
- Nothing tests the single-instance check. It was verified by a throwaway script
  that took the name, launched the tray and watched it survive, with a control
  run first showing the name free so the probe was known to be able to report
  both answers. The script was not kept. Same gap as TrayIconArt.
- Terminate can in principle hit the wrong process. Between the WMI event and the
  kill — median 347 ms — the observed process could exit and Windows could
  reissue its pid. Never seen, and the window is small, but it is the only path
  by which this tool could end something nobody asked it to. Recorded, not fixed.
- The READMEs quote four numbers that nothing keeps in sync: 50 tests, 29 of
  them free of Windows, 15 end-to-end checks, and the 49 MB of dist/. The first
  three were counted rather than copied when written — 50 [Fact] with no theories
  and no inline data, 29 of them in GameBrake.Core.Tests, 15 Check calls in
  scripts/e2e.ps1 — and the fourth was measured. But adding a single test makes
  three files wrong, a .NET update moves the fourth, and check.sh compares the
  translations against each other, never against the suite or the build. Same
  class of gap as TrayIconArt.
- config.json and the installed executable are both writable by anything running
  as this user, which can therefore add entries, empty the protected set, or
  replace the tray outright. That is the N7 bargain rather than a separate hole:
  the same access already permits closing the tool. Worth knowing when reading
  the file; not worth defending against.
- No automated test ever sees a published file. dotnet test builds Debug and
  scripts/e2e.ps1 runs the Debug executable, so the whole single-file path — the
  runtime pack, the self-extraction of native libraries, compression — is covered
  only by someone running dist/GameBrake.Tray.exe by hand and watching. It was
  run by hand on 2026-09-12 and it worked. That is one cycle, and the file is
  rebuilt every time anything changes.
- No .pdb ships with the installed executable, so a crash there yields a stack
  trace with no file or line numbers. Nothing has ever crashed, which is why this
  is an annoyance and not a decision to revisit; the day it does crash is the day
  it will be missed, and the answer then is to reproduce against a Debug build.
- The eleven-file folder that was installed until 2026-09-12 was moved to a
  session-scoped temporary directory rather than deleted, so treat it as gone.
  If the single file turns out to be wrong, the way back is scripts/pack.ps1 or
  a plain dotnet build, not that folder.
