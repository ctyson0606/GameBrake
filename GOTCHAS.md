# GOTCHAS

Version-bound traps. Every entry carries a date. Entries here may be deleted
without justification once the dependency they describe is gone.

Format:  ### <one-line trap>  `[YYYY-MM-DD]`

### `dotnet new sln` on SDK 10 produces GameBrake.slnx, not a .sln  `[2026-08-23]`

The XML solution format is the default from .NET 10. Tooling older than
VS 2022 17.13 or SDK 9.0.200 cannot open it. Nothing here is affected, since
the build runs through `dotnet` on SDK 10.0.400, but a search for
"GameBrake.sln" finds nothing and the absence looks like a missing file.

### notepad.exe on Windows 11 is an alias, not the program  `[2026-08-23]`

C:\Windows\System32\notepad.exe is an app execution alias. Launching it starts a
stub with that path, whose WMI ExecutablePath reads null and which exits on its
own, and separately the real packaged binary at
C:\Program Files\WindowsApps\Microsoft.WindowsNotepad_11.2606.15.0_x64__8wekyb3d8bbwe\Notepad\Notepad.exe
which owns the window. Measured over 5 launches: the stub matched the launcher
pid once, the packaged process the other four times. Protecting the System32
path matches only the stub, so the tool would report a clean interception while
the window stayed open. Note the version number in the real path; it moves on
update.

### Win32_ProcessStartTrace needs administrator, __InstanceCreationEvent does not  `[2026-08-23]`

Subscribing to Win32_ProcessStartTrace unelevated raises ManagementException
"Access denied" at Start(). The unelevated route is
SELECT * FROM __InstanceCreationEvent WITHIN 1 WHERE TargetInstance ISA
'Win32_Process', which works and carries ExecutablePath for ordinary processes.

### WITHIN 0.5 is slower than WITHIN 1, not faster  `[2026-08-23]`

Measured on charmap.exe, 6 launches each: WITHIN 1 gave median 347 ms and max
920 ms, WITHIN 0.5 gave median 537 ms and max 705 ms. Shortening the interval
buys no margin and costs more polling, so there is no reason to reach for it.

### A Windows path through an inline python heredoc loses one level of escaping  `[2026-08-23]`

Writing \\bin into a file this way produced a backspace character, and
\\net10.0 produced a real newline: one level of \ is stripped before python
sees it, so what survives is a valid python escape. Earlier edits looked fine
only because \G and \s are invalid escapes, which python leaves alone. The
SyntaxWarning about an invalid escape sequence is the signal that this is
happening, and it appears even when the output happens to come out right.
It corrupted scripts/e2e.ps1 after a scan had already called the file clean.

### Riot Vanguard hides ExecutablePath from WMI, but not from Windows  `[2026-08-23]`

Win32_Process reports ExecutablePath as NULL for VALORANT.exe,
VALORANT-Win64-Shipping.exe and vgc.exe while Vanguard is running, and
Process.MainModule throws access denied for them, because reading modules wants
PROCESS_VM_READ. QueryFullProcessImageName wants only
PROCESS_QUERY_LIMITED_INFORMATION, which is granted, and it returns the real
full path for both game processes. PROCESS_TERMINATE is granted for them too,
so they can be ended once they can be seen. Vanguard's own service vgc.exe
refuses every access, and nothing here needs it.

### Riot Client puts itself in the Run key in background mode  `[2026-08-23]`

HKCU Run carries RiotClientServices.exe --launch-background-mode, so the
launcher is resident from login. Measured once: it started 48 s after boot and
GameBrake 81 s after, so by A5 the launcher was left alone permanently. Even
without that race, pressing Play wakes the resident client rather than starting
a new process, so there is no launch to intercept. Protect the game binaries,
not the launcher.
