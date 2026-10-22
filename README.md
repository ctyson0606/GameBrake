<!-- Hero -->
<div align="center">
  <h1>GameBrake</h1>
  <p><b>A Windows tray app that brakes the games you choose</b>: launching one closes it at once and starts a cooldown, and only once you have waited it out can it run.</p>
  <p>
    <img alt="platform: Windows 10 | 11" src="https://img.shields.io/badge/platform-Windows%2010%20%7C%2011-4d6bfe">
    <img alt=".NET 10" src="https://img.shields.io/badge/.NET-10-4d6bfe">
    <img alt="admin rights: none" src="https://img.shields.io/badge/admin%20rights-none-brightgreen">
    <img alt="license: MIT" src="https://img.shields.io/badge/license-MIT-blue">
  </p>
  <p>🌏 <a href="./README.zh-CN.md">简体中文</a> · <a href="./README.zh-TW.md">繁體中文</a> · English</p>
</div>

<!-- Screenshot placeholder: commit the image at docs/screenshot.png, then remove this comment pair.
<p align="center"><img src="docs/screenshot.png" alt="The GameBrake tray icon counting down" width="480"></p>
-->

The impulse to play and the act of playing are separated by nothing: a double-click closes the gap, and by the time you notice the cost the session is under way. GameBrake reopens that gap. It sells friction, not force — it runs as your own account and Task Manager can close it, and closing it is itself a moment of pause.

## ✨ Features

- **Brakes what you choose**: any executable you put on the list, games or not; everything else is completely untouched.
- **A cooldown per session**: every session start pays one, not once ever and not once a day.
- **A grace window**: once the cooldown ends, a launch is allowed for a while; let it lapse and the next launch pays again.
- **Survives a reboot**: deadlines are absolute times on disk, so restarting Windows mid-cooldown does not clear it.
- **The countdown in the icon**: a depleting ring with the minutes left, red while you wait and green once the launch is allowed.
- **Edit it any time**: from the tray menu, or in `config.json`, which is reloaded the moment you save.
- **No administrator rights**: it asks for none, at build time or at run time.

## 🚀 Installation

Prerequisite: Windows 10 or 11 (x64), and the [.NET SDK 10.0](https://dotnet.microsoft.com/download) on the machine that builds it. What it builds carries its own .NET and runs where none is installed.

**Option 1 · one self-contained file**

```powershell
git clone https://github.com/ctyson0606/GameBrake.git
cd GameBrake
powershell -ExecutionPolicy Bypass -File scripts/pack.ps1

$target = "$env:LOCALAPPDATA/Programs/GameBrake"
New-Item -ItemType Directory -Force $target
Copy-Item "dist/GameBrake.Tray.exe" $target -Force
Start-Process "$target/GameBrake.Tray.exe"
```

Then right-click the tray icon and tick **Start with Windows**, so the installed copy, not the build output, starts with your session.

**Option 2 · run it from the source**

<details>
<summary>Use this to try it without installing anything</summary>

```powershell
dotnet run --project src/GameBrake.Tray
```

</details>

**Verify**

```powershell
Get-Process GameBrake.Tray
```

One process is listed, and its icon is in the notification area. The first start of an unsigned file shows **Windows protected your PC**: choose **More info** → **Run anyway**.

## 🕹️ Usage

### Choosing what to brake

Right-click the tray icon, choose **Protect an application...** and pick an `.exe`. The menu lists each protected entry and its phase.

### What happens on a launch

```text
idle      --launch-->        terminate the process; start a cooldown
cooling   --launch-->        terminate again; the remaining time is NOT extended
cooling   --time passes-->   unlocked, for a grace window
unlocked  --launch-->        allowed; runs as long as you like
unlocked  --grace expires--> back to idle; the next launch pays in full again
running   --you quit-->      back to idle; the next session pays a fresh cooldown
```

The grace window is measured from the cooldown's deadline, not from when the tool noticed it passed, so sleeping through a cooldown cannot stretch it.

### Updating your copy

A change reaches daily use only when the file is packed and copied again: exit from the tray menu, run Option 1's last five lines again, and start it.

### Uninstalling

Exit from the tray menu, untick **Start with Windows**, then delete `%LOCALAPPDATA%\Programs\GameBrake` and `%APPDATA%\GameBrake`.

## 🎮 Protect game binaries, not launchers

A launcher and the game are different executables; put the game on the brake. Many launchers are already resident from login, so there is no launch to intercept.

Some games run a chain of binaries, and only one link is the right one. Valorant runs `VALORANT.exe` into `VALORANT-Win64-Shipping.exe`: protect `VALORANT-Win64-Shipping.exe`, and only that.

- **Both protected**: two entries are two independent cooldowns, so you wait a second time after the first.
- **Only the launcher protected**: a termination ends one process, never its children, so the game runs anyway.

**One entry per game, and it is the binary that owns the session.**

## 💾 Settings

`%APPDATA%\GameBrake\config.json` is yours to edit; GameBrake reloads it when you save.

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

| Item | Value |
| --- | --- |
| `cooldownSeconds` | How long you wait after a blocked launch; one value for every entry |
| `graceWindowSeconds` | How long the permission lasts once the cooldown ends |
| `autostart` | Mirrors **Start with Windows** |
| `protected[].id` | Any UUID; state is keyed by it, so a moved executable can be repointed without discharging its cooldown |
| `protected[].executable` | The full path, matched case-insensitively; escape backslashes as `\\` |
| `protected[].displayName` | What the menu and the notifications call it |
| `protected[].enabled` | `false` is the same as the entry being absent |
| A malformed file | A dialog says so, and nothing is protected until it is fixed |
| `%APPDATA%\GameBrake\state.json` | The tool's own file: the deadlines that survive a reboot |

## 🛠️ Development and testing

Restore, build and run:

```powershell
dotnet restore
dotnet build
dotnet run --project src/GameBrake.Tray
```

The tests, then the end-to-end checks:

```powershell
dotnet test
powershell -ExecutionPolicy Bypass -File scripts/e2e.ps1
```

The single file the installation uses:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/pack.ps1
```

- **Exit the tray before `dotnet test`**: a running copy kills the test subject before the watcher sees it, and the failure reads as a broken watcher.
- **`dotnet test` opens and closes real `charmap.exe` windows**, which is what makes the interception tested rather than assumed.
- **`scripts/e2e.ps1` overwrites the real `%APPDATA%\GameBrake`**, because that is where the tool looks; copy anything real aside first.

C# type-checks during the build, and no linter is configured.

## 📦 Project layout

```text
src/GameBrake.Core/
src/GameBrake.Windows/
src/GameBrake.Tray/
tests/
scripts/pack.ps1
scripts/e2e.ps1
GameBrake.slnx
```

- `src/GameBrake.Core/`: the reducer — the whole cooldown policy as a pure function — and the two file stores; it targets plain `net10.0`, so reaching for a Windows API is a compile error;
- `src/GameBrake.Windows/`: the WMI process watcher, the terminator, and the engine wiring them to the reducer;
- `src/GameBrake.Tray/`: the tray icon, the menu, the drawn countdown and autostart, with no policy of its own;
- `tests/`: the tests, most of them touching neither Windows nor a real process;
- `scripts/pack.ps1`: the single self-contained file in `dist/`;
- `scripts/e2e.ps1`: the end-to-end checks against the real tray;
- `GameBrake.slnx`: the solution.

`METHOD.md`, `STATE.md` and `GOTCHAS.md` carry the reasoning behind these decisions, including the ones measured and found different from what was expected.

## ⚠️ Compatibility and limits

- **Anything already running when GameBrake starts is left alone** for that session; an app that starts itself at login wins the race until you reboot. A cooldown already owed still survives the restart.
- **Microsoft Store and Game Pass apps are out of scope**: their path carries a version number that moves on every update.
- **It does not interrupt a session already under way** and does not cap playtime; it taxes each session start.
- **It is not tamper-resistant**: `config.json` and the executable are writable by anything running as you. The same access already lets you close it.
- **Executables only**: no websites or URLs.

## ❓ FAQ

| Symptom | What to do |
| --- | --- |
| A protected game starts anyway | Protect another binary in its chain: the one that owns the session |
| It makes me wait twice | Two entries for one game are two cooldowns; keep one |
| **Windows protected your PC** on first start | The file is unsigned; **More info** → **Run anyway** |
| A dialog says `config.json` is malformed | Fix the JSON; nothing is protected until then |
| `dotnet test` fails in the watcher tests | Exit the tray first |
| My settings changed after `scripts/e2e.ps1` | It overwrites `%APPDATA%\GameBrake`; restore the copy you set aside |

## 📄 License

MIT, see [LICENSE](LICENSE).
