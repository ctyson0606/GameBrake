# GameBrake

**English** · [繁體中文](README.zh-TW.md) · [简体中文](README.zh-CN.md)

A Windows tray application that puts a deliberate wait between wanting to play
and playing.

The impulse to play and the act of playing are separated by nothing — a
double-click closes the gap instantly, and by the time you notice the cost the
session is already under way. GameBrake reopens that gap. When you launch an
application you have put on the brake, it is closed immediately and a cooldown
starts. Wait it out, and you get a short window in which the launch is allowed.
Everything not on your list is completely untouched.

It sells friction, not force. It runs as your own user account and can be closed
from Task Manager — that is a deliberate design decision, not an oversight.
Closing it is itself a moment of pause.

---

## How it works

Each protected application moves through four phases:

```
idle      --launch-->        terminate the process; start a cooldown (default 300 s)
cooling   --launch-->        terminate again; the remaining time is NOT extended
cooling   --time passes-->   unlocked, for a grace window (default 300 s)
unlocked  --launch-->        allowed; runs as long as you like
unlocked  --grace expires--> back to idle; the next launch pays in full again
running   --you quit-->      back to idle; the next session pays a fresh cooldown
```

Two properties are worth knowing:

- **A cooldown survives a reboot.** Restarting Windows in the middle of one does
  not clear it. Deadlines are stored as absolute times in a file on disk.
- **The grace window is measured from the cooldown deadline**, not from the
  moment the tool noticed it had passed. Sleeping through a cooldown cannot
  stretch the window into a bypass.

The remaining time is drawn into the tray icon itself: a depleting ring with the
number of minutes left inside it, red while you are waiting and green once the
launch is permitted.

---

## Requirements

- Windows 10 or 11 (x64). Windows only — there is no other platform.
- [.NET SDK 10.0](https://dotnet.microsoft.com/download) or newer, to build it.
  Verified on SDK 10.0.400.
- No administrator rights. The application asks for none, at build time or run
  time.

---

## Get it and build it

```bash
git clone https://github.com/ctyson0606/GameBrake.git
cd GameBrake

dotnet restore
dotnet build -c Release
```

That produces the tray executable at:

```
src/GameBrake.Tray/bin/Release/net10.0-windows/GameBrake.Tray.exe
```

To try it straight away without installing anything:

```bash
dotnet run --project src/GameBrake.Tray
```

An icon appears in the notification area. Right-click it for the menu.

---

## Install your own copy

The build output lives inside your clone, so anything that rebuilds or cleans the
repository disturbs the copy you use every day. Copy it somewhere of its own
instead:

```powershell
$source = "src/GameBrake.Tray/bin/Release/net10.0-windows"
$target = "$env:LOCALAPPDATA/Programs/GameBrake"

New-Item -ItemType Directory -Force $target
Copy-Item "$source/*" $target -Recurse -Force

Start-Process "$target/GameBrake.Tray.exe"
```

Then right-click the tray icon and tick **Start with Windows**. That writes an
absolute path into `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` under the
value name `GameBrake`, so the installed copy — not the build output — is what
starts with your session.

> **Updating.** A change you build reaches daily use only when you repeat the
> copy above. Exit the tray first, or the files will be in use.

To uninstall: exit from the tray menu, untick **Start with Windows** (or delete
that `Run` value), then delete `%LOCALAPPDATA%\Programs\GameBrake` and
`%APPDATA%\GameBrake`.

---

## Choose what to brake

The easy way is the tray menu: **Protect an application…**, then pick an `.exe`.

The file behind it is `%APPDATA%\GameBrake\config.json`, which is yours to edit by
hand. The tool reloads it the moment you save.

```json
{
  "cooldownSeconds": 300,
  "graceWindowSeconds": 300,
  "autostart": true,
  "protected": [
    {
      "id": "3f2a6c18-9d41-4f0e-9b8a-1c5d7e2b4a90",
      "executable": "C:\\Program Files\\Foo\\game.exe",
      "displayName": "Foo",
      "enabled": true
    }
  ]
}
```

| Key | Meaning |
| --- | --- |
| `cooldownSeconds` | How long you wait after a blocked launch. One global value, not per-app. |
| `graceWindowSeconds` | How long the permission lasts once the cooldown ends. |
| `autostart` | Mirrors the **Start with Windows** tick. |
| `protected[].id` | Any UUID. State is keyed by this, so a moved executable can be repointed without discharging its cooldown. |
| `protected[].executable` | **Full path**, matched case-insensitively. Backslashes must be escaped as `\\` in JSON. |
| `protected[].displayName` | What the menu and the notifications call it. |
| `protected[].enabled` | `false` is treated exactly as though the entry were absent. |

Those four top-level keys and no others. If the file is malformed, GameBrake says
so in a dialog and protects **nothing** until you fix it — it will not quietly
fall back to defaults, and it will not quietly read damage as "nothing owed".

The tool also writes `%APPDATA%\GameBrake\state.json`. That one belongs to the
tool; it holds the deadlines that survive a reboot.

### Protect game binaries, not launchers

A launcher and the game are different executables, and you choose which one goes
on the brake. Choose the game.

Many launchers (Riot Client, for one) put themselves in the `Run` key and are
already resident from login, so there is no launch to intercept — pressing *Play*
wakes the existing process rather than starting one. Protecting the launcher only
kills its helper processes while the game itself goes on.

Some games run a chain of binaries, and only one link in the chain is the right
one to hold. Valorant runs `VALORANT.exe` into `VALORANT-Win64-Shipping.exe`:
protect `VALORANT-Win64-Shipping.exe`, and only that. Both together was tried and
charges a second cooldown after the first has already been waited out.
`VALORANT.exe` on its own does not stop the game from running at all. Neither
behaviour is understood yet.

So if a protected game starts anyway, or makes you wait twice, try a different
binary in its chain before concluding the tool is broken. The tray menu shows
each protected entry and its phase, which is the quickest way to see which one
is actually being charged.

---

## Developing

```bash
# build
dotnet build
# 50 tests
dotnet test
# 15 end-to-end checks
powershell -ExecutionPolicy Bypass -File scripts/e2e.ps1
```

Three things to know before running those:

1. **Exit the tray before `dotnet test`.** A running copy kills the test subject
   faster than the watcher can see it, and the failure then reads as though the
   watcher never worked.
2. **`dotnet test` opens and closes real `charmap.exe` windows** and takes about
   eight seconds longer for it. That is the price of the interception being
   tested rather than assumed.
3. **`scripts/e2e.ps1` overwrites the real `%APPDATA%\GameBrake`**, because that
   is where the tool it tests looks. Copy anything real aside first.

There is no separate typecheck step — C# type-checks during the build — and no
linter is configured.

### Layout

| Project | What lives there |
| --- | --- |
| `src/GameBrake.Core` | The reducer — the whole cooldown policy as a pure function — and the two file stores. Targets plain `net10.0`, so reaching for a Windows API is a compile error rather than something to remember. |
| `src/GameBrake.Windows` | The WMI process watcher, the terminator, and the engine wiring them to the reducer. |
| `src/GameBrake.Tray` | The tray icon, the menu, the drawn countdown, and autostart. Holds no policy of its own. |
| `tests/` | 50 tests, 29 of which touch neither Windows nor a real process. |

---

## Known limits

- **Anything already running when GameBrake starts is left alone** for the rest of
  that session. Applications that start themselves at login win the race against
  the tray and stay exempt until you reboot. A cooldown already owed still
  survives a restart, so this is no way out of one — but it is a way to begin a
  session free.
- **Microsoft Store and Game Pass applications are out of scope.** They live under
  a path carrying a version number that moves on every update, and full-path
  matching does not survive that.
- **It does not interrupt a session already under way**, and it does not cap total
  playtime. It taxes each session *start*.
- **It is not tamper-resistant.** `config.json` and the executable are writable by
  anything running as you, and the tool can be closed from Task Manager. That is
  the bargain rather than a separate hole: the same access already permits closing
  it.
- **No websites or URLs.** Executables only.

---

## Design notes

`METHOD.md`, `STATE.md` and `GOTCHAS.md` in this repository carry the reasoning
behind the decisions above — including the ones that were measured and turned out
differently from what was expected. Worth reading before changing anything.

---

## License

MIT. See [LICENSE](LICENSE).
