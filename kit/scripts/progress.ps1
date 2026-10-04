# Windows launcher for progress.sh. It finds Git Bash's own bash.exe, has it
# write the page, and opens the page. The generator is progress.sh; this file
# holds only what Windows needs.
#
# Plain "bash" is never used: in PowerShell it resolves to WSL's launcher in
# System32, which fails with a message that points nowhere near the cause.
#
# Run it as:  powershell -ExecutionPolicy Bypass -File scripts/progress.ps1
# Extra arguments go to progress.sh (--out, --no-mark, --untranslated).
# This file is ASCII on purpose: Windows PowerShell 5.1 reads a BOM-less file
# as ANSI.

$ErrorActionPreference = 'Stop'

function Find-GitBash {
    $starts = @()
    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        $starts += (Split-Path -Parent $git.Source)
        $exec = & git --exec-path
        if ($exec) { $starts += $exec }
    }
    $starts += (Join-Path $env:ProgramFiles 'Git')
    foreach ($s in $starts) {
        $d = $s
        for ($i = 0; $i -lt 6 -and $d; $i++) {
            foreach ($rel in @('bin\bash.exe', 'usr\bin\bash.exe')) {
                $c = Join-Path $d $rel
                if (Test-Path -LiteralPath $c) { return $c }
            }
            $d = Split-Path -Parent $d
        }
    }
    return $null
}

$bash = Find-GitBash
if (-not $bash) {
    Write-Error 'Git Bash was not found. Install Git for Windows, or run scripts/progress.sh from Git Bash.'
    exit 1
}

$script = (Join-Path $PSScriptRoot 'progress.sh').Replace([string][char]92, '/')
$noOpen = $false
foreach ($a in $args) {
    if ($a -eq '--no-open' -or $a -eq '--untranslated') { $noOpen = $true }
}

$lines = @(& $bash $script '--no-open' @args)
$code = $LASTEXITCODE
if ($code -ne 0) { exit $code }

if ($noOpen) {
    $lines
    exit 0
}

$page = $lines | Where-Object { $_ -and $_.Trim() } | Select-Object -Last 1
if (-not $page -or -not (Test-Path -LiteralPath $page)) {
    Write-Error "progress.sh did not report a page that exists: $page"
    exit 1
}
Write-Output $page
Start-Process -FilePath $page
