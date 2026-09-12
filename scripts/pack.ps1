# Produces one self-contained GameBrake.Tray.exe in dist/.
#
# Self-contained because the point is a file that runs on a machine with no
# .NET installed: asking someone to install a runtime before they can install
# the thing is the friction this removes.
#
# The name is not shortened to GameBrake.exe on purpose. The single-instance
# check in Program.cs compares process names, so two copies under two names
# cannot see each other, and an old installed copy would go on running beside
# the new one, both watching and both writing state.json.

$ErrorActionPreference = 'Stop'

$repository = Split-Path -Parent $PSScriptRoot
$project = Join-Path $repository 'src/GameBrake.Tray'
$dist = Join-Path $repository 'dist'

if (Test-Path $dist) {
    Remove-Item $dist -Recurse -Force
}

# EnableCompressionInSingleFile takes it from 111 MB to 49 MB. It costs
# decompression at every start, which is paid once per Windows session.
# DebugType none keeps the .pdb files out: they are 48 KB of no use to anyone
# who did not build this, and their absence is what makes dist/ one file.
dotnet publish $project `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -p:DebugType=none `
    -o $dist

if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish failed with exit code $LASTEXITCODE"
}

$exe = Join-Path $dist 'GameBrake.Tray.exe'
if (-not (Test-Path $exe)) {
    throw "publish reported success but $exe is not there"
}

# Anything besides the executable means the single-file build stopped being
# single, which is the whole claim this script makes.
$extra = Get-ChildItem $dist | Where-Object { $_.Name -ne 'GameBrake.Tray.exe' }
if ($extra) {
    throw "dist/ holds more than the executable: $($extra.Name -join ', ')"
}

$megabytes = [math]::Round((Get-Item $exe).Length / 1MB, 1)
Write-Host ""
Write-Host "dist/GameBrake.Tray.exe  ($megabytes MB)"
Write-Host "Copy it anywhere and run it. Nothing else is needed."
