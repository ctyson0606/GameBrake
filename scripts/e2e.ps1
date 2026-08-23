# End-to-end run of AC1 to AC7 and AC9 against the real tray host.
# Cooldown is shortened to 40 s and grace to 20 s so the whole cycle fits in a
# run; the criteria are about behaviour, not about the number 300. The first
# version used 15 s, which the AC7 block alone outlasted, so the tool moved on
# legitimately and the check read that as a loss. Every wait below is now derived
# from the deadline in the file rather than from a guess.

$ErrorActionPreference = 'Stop'
# Derived from where this script sits, not written down. A path typed in here
# is one machine's path, and it is also that machine's directory layout
# published to anyone who reads the repository.
$repository = Split-Path -Parent $PSScriptRoot
$tray = Join-Path $repository 'src/GameBrake.Tray/bin/Debug/net10.0-windows/GameBrake.Tray.exe'
if (-not (Test-Path $tray)) {
    throw "Build it first with: dotnet build. Expected $tray"
}
$dir = Join-Path $env:APPDATA 'GameBrake'
$configPath = Join-Path $dir 'config.json'
$statePath = Join-Path $dir 'state.json'
$subject = Join-Path $env:SystemRoot 'System32\charmap.exe'
$unprotected = Join-Path $env:SystemRoot 'System32\msinfo32.exe'

$results = [System.Collections.Generic.List[string]]::new()
function Check($name, $condition, $detail) {
    $mark = if ($condition) { 'PASS' } else { 'FAIL' }
    $line = "{0}  {1}  {2}" -f $mark, $name, $detail
    $results.Add($line)
    Write-Host $line
}

function Alive($exe) {
    $n = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    return (@(Get-Process -Name $n -ErrorAction SilentlyContinue)).Count -gt 0
}

function KillAll($exe) {
    $n = [System.IO.Path]::GetFileNameWithoutExtension($exe)
    Get-Process -Name $n -ErrorAction SilentlyContinue | ForEach-Object {
        try { $_.Kill(); $_.WaitForExit(3000) } catch {}
    }
}

function Phase() {
    if (-not (Test-Path $statePath)) { return $null }
    $obj = (Get-Content $statePath -Raw) | ConvertFrom-Json
    foreach ($p in $obj.PSObject.Properties) { return $p.Value.phase }
    return $null
}

function Deadline() {
    if (-not (Test-Path $statePath)) { return $null }
    $raw = Get-Content $statePath -Raw
    $obj = $raw | ConvertFrom-Json
    foreach ($p in $obj.PSObject.Properties) { return $p.Value.cooldownEndsAt }
    return $null
}

# --- arrange -----------------------------------------------------------------
Get-Process -Name 'GameBrake.Tray' -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
KillAll $subject
KillAll $unprotected
New-Item -ItemType Directory -Force $dir | Out-Null
if (Test-Path $statePath) { Remove-Item $statePath }

$config = @{
    cooldownSeconds    = 40
    graceWindowSeconds = 20
    autostart          = $false
    protected          = @(
        @{ id = '11111111-2222-3333-4444-555555555555'
           executable = $subject
           displayName = 'Charmap'
           enabled = $true }
    )
} | ConvertTo-Json -Depth 5
Set-Content -Path $configPath -Value $config -Encoding utf8

Write-Host "config: $configPath"
Write-Host "subject: $subject"
Write-Host ''

Start-Process -FilePath $tray | Out-Null
Start-Sleep -Seconds 5
Check 'tray is running' (@(Get-Process -Name 'GameBrake.Tray' -ErrorAction SilentlyContinue).Count -eq 1) ''

# --- AC1 ---------------------------------------------------------------------
Start-Process -FilePath $subject | Out-Null
Start-Sleep -Milliseconds 2500
Check 'AC1 protected launch is closed' (-not (Alive $subject)) 'checked 2.5 s after launch'
$firstDeadline = Deadline
Check 'AC1 a cooldown was recorded' ($null -ne $firstDeadline) "cooldownEndsAt=$firstDeadline"

# --- AC2 ---------------------------------------------------------------------
Start-Sleep -Seconds 3
Start-Process -FilePath $subject | Out-Null
Start-Sleep -Milliseconds 2500
$secondDeadline = Deadline
Check 'AC2 retry is closed too' (-not (Alive $subject)) ''
Check 'AC2 the deadline did not move' ($firstDeadline -eq $secondDeadline) "still $secondDeadline"

# --- AC6 ---------------------------------------------------------------------
Start-Process -FilePath $unprotected | Out-Null
Start-Sleep -Seconds 3
Check 'AC6 an unprotected app is untouched' (Alive $unprotected) 'msinfo32 still running'
KillAll $unprotected

# --- AC7, across a restart of the tool ---------------------------------------
$beforeRestart = Deadline
Get-Process -Name 'GameBrake.Tray' -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill(); $_.WaitForExit(3000) }
Start-Sleep -Seconds 1
Start-Process -FilePath $tray | Out-Null
Start-Sleep -Seconds 4
Check 'AC7 the deadline survived the restart' ((Deadline) -eq $beforeRestart) "phase=$(Phase) still $beforeRestart"
Start-Process -FilePath $subject | Out-Null
Start-Sleep -Milliseconds 2500
Check 'AC7 the restarted tool still refuses' (-not (Alive $subject)) ''
Check 'AC7 and still did not extend it' ((Deadline) -eq $beforeRestart) ''

# --- AC3 ---------------------------------------------------------------------
Write-Host '  ... waiting out the cooldown'
$until = [datetime]::Parse($firstDeadline).ToUniversalTime()
while ([datetime]::UtcNow -lt $until.AddSeconds(1)) { Start-Sleep -Milliseconds 500 }
Start-Process -FilePath $subject | Out-Null
Start-Sleep -Seconds 3
Check 'AC3 a launch inside the grace window survives' (Alive $subject) 'still running 3 s later'

# --- AC5 ---------------------------------------------------------------------
KillAll $subject
Start-Sleep -Seconds 2
Start-Process -FilePath $subject | Out-Null
Start-Sleep -Milliseconds 2500
Check 'AC5 relaunching after quitting is charged again' (-not (Alive $subject)) ''

# --- AC4 ---------------------------------------------------------------------
Write-Host '  ... waiting out the cooldown, then letting the grace window lapse'
$lapse = Deadline
$untilLapse = [datetime]::Parse($lapse).ToUniversalTime().AddSeconds(20 + 3)
while ([datetime]::UtcNow -lt $untilLapse) { Start-Sleep -Milliseconds 500 }
$phaseBefore = Phase
Check 'AC4 an unused grace window returns to idle' ($phaseBefore -eq 'idle') "phase=$phaseBefore"
Start-Process -FilePath $subject | Out-Null
Start-Sleep -Milliseconds 2500
$afterAc4 = Deadline
Check 'AC4 and the next launch is charged a full cooldown' (-not (Alive $subject)) ''
Check 'AC4 with a fresh deadline' (($null -ne $afterAc4) -and ($afterAc4 -ne $lapse)) "was $lapse, now $afterAc4"

# --- AC9 ---------------------------------------------------------------------
Write-Host '  ... measuring idle cost over 60 s'
function TrayCpu() {
    $p = Get-Process -Name 'GameBrake.Tray' -ErrorAction SilentlyContinue
    if ($null -eq $p) { return $null }
    return $p.TotalProcessorTime
}
KillAll $subject
Start-Sleep -Seconds 3
$cpuBefore = TrayCpu
Start-Sleep -Seconds 60
$cpuAfter = TrayCpu
$ms = ($cpuAfter - $cpuBefore).TotalMilliseconds
$pct = $ms / 600.0
Check 'AC9 tray idle CPU below 1 percent of one core' ($pct -lt 1.0) ("{0:N0} ms over 60 s = {1:N2}% of one core" -f $ms, $pct)

# --- teardown ----------------------------------------------------------------
Get-Process -Name 'GameBrake.Tray' -ErrorAction SilentlyContinue | ForEach-Object { $_.Kill() }
KillAll $subject
KillAll $unprotected

Write-Host ''
Write-Host '================ SUMMARY ================'
$results | ForEach-Object { Write-Host $_ }
$failed = @($results | Where-Object { $_.StartsWith('FAIL') }).Count
Write-Host ''
Write-Host ("{0} checks, {1} failed" -f $results.Count, $failed)
