<#
================================================================================
 run_selftest_safe.ps1 - CONTROLLED SELF-TEST RUNNER (ARCANE VOYAGE)
================================================================================
 IMPORTANT: this file is deliberately PURE ASCII.
 Windows PowerShell 5.1 reads .ps1 as ANSI unless the file has a UTF-8 BOM.
 Accented chars / emoji here get mangled and BREAK THE PARSER. Keep it ASCII.

 Why this runner exists:
   On 2026-09-05 `_a44_selftest.gd` was launched 3x directly. All three hung at
   the same logical point; two ended in Kernel-Power 41 (the machine died), one
   needed a manual shutdown. The suite ran its whole battery inside a single
   `process_frame`, so nothing responded and nothing was freed.

   This runner never lets that reach "manual reboot":
     - single-process guard (no Godot alive before starting)
     - low priority (the OS stays responsive)
     - EXTERNAL timeout with kill (never trust the hung test to time itself out)
     - STALL watchdog (log stopped growing => it hung; kill before the timeout)
     - stdout/stderr captured to files
     - no orphan process on exit
     - records: command, timeout, priority, PID, start, end, exit code,
       whether it was killed, and the LAST OBSERVED MARKER

 Usage:
   .\run_selftest_safe.ps1 -Mode import
   .\run_selftest_safe.ps1 -Mode run -Script res://scripts/_a44_selftest.gd -TimeoutSec 600 -StallSec 120

 Exit codes: 0 = ok | 2 = aborted (Godot already running) | 124 = killed by runner
 No commit. No push. No deploy. Self-tests use fixtures, never the live save.
================================================================================
#>
[CmdletBinding()]
param(
    [ValidateSet('import','run')]
    [string]$Mode = 'run',

    [string]$Script = 'res://scripts/_a44_selftest.gd',

    # Absolute ceiling. Past this, it dies.
    [int]$TimeoutSec = 600,

    # Stall watchdog: no new stdout bytes for N seconds => it hung.
    # This is what avoids staring at a frozen log for 20 minutes.
    [int]$StallSec = 120,

    # MEMORY watchdog. Added 2026-09-05 after a real miss: the A44 run climbed to
    # 7.4 GB with free RAM down to 0.8 GB while the STALL watchdog stayed quiet,
    # because the log WAS still growing. A busy process can kill the machine just
    # as dead as a frozen one. Kill on either breach.
    [int]$MaxWorkingSetMB = 4096,
    [int]$MinFreeRamMB    = 1536,

    [ValidateSet('Idle','BelowNormal','Normal')]
    [string]$Priority = 'BelowNormal',

    [string]$GodotExe = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.6.3-stable_win64_console.exe",

    [string]$ProjectDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,

    [string]$OutDir = (Join-Path $env:TEMP 'arcane_selftest_runs')
)

$ErrorActionPreference = 'Stop'

function Say([string]$m, [string]$c = 'Gray') { Write-Host $m -ForegroundColor $c }

# ---- preflight ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $GodotExe)) { throw "Godot not found: $GodotExe" }
if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir 'project.godot'))) { throw "project.godot not found in: $ProjectDir" }
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

# ---- SINGLE PROCESS GUARD ----------------------------------------------------
$alive = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '(?i)godot' })
if ($alive.Count -gt 0) {
    Say "ABORTED: a Godot process is already alive. Kill it before running." 'Red'
    $alive | Select-Object Id, ProcessName, StartTime | Format-Table -AutoSize | Out-String | Write-Host
    exit 2
}

$stamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
if ($Mode -eq 'import') { $tag = 'import' } else { $tag = (($Script -split '/')[-1] -replace '\.gd$','') }
$outLog = Join-Path $OutDir ($stamp + '_' + $tag + '.out.log')
$errLog = Join-Path $OutDir ($stamp + '_' + $tag + '.err.log')
$meta   = Join-Path $OutDir ($stamp + '_' + $tag + '.meta.json')

if ($Mode -eq 'import') {
    # 4.6.3 --help: "Starts the editor, waits for any resources to be imported, and then quits."
    $argv = @('--headless','--path',$ProjectDir,'--import')
} else {
    $argv = @('--headless','--path',$ProjectDir,'--script',$Script)
}

Say ("CMD      : " + '"' + $GodotExe + '" ' + ($argv -join ' ')) 'Cyan'
Say ("LIMITS   : timeout " + $TimeoutSec + "s (absolute) | stall " + $StallSec + "s | priority " + $Priority)
Say ("STDOUT   : " + $outLog)

$startTime = Get-Date
$proc = Start-Process -FilePath $GodotExe -ArgumentList $argv `
        -RedirectStandardOutput $outLog -RedirectStandardError $errLog `
        -WindowStyle Hidden -PassThru

try { $proc.PriorityClass = $Priority } catch { Say ("WARN: could not set priority " + $Priority) 'Yellow' }

# Touching .Handle CACHES the process handle. Without this, ExitCode comes back
# EMPTY after the process dies (Start-Process -PassThru quirk). The exit code is
# required PROOF of the verdict, so it must survive the process exiting.
try { $null = $proc.Handle } catch { Say 'WARN: could not cache process handle (exit code may be unavailable)' 'Yellow' }

Say ("PID      : " + $proc.Id + "  start: " + $startTime.ToString('HH:mm:ss')) 'Cyan'

# ---- watch loop --------------------------------------------------------------
$killed     = $false
$killReason = ''
$lastSize   = -1
$lastGrowth = Get-Date
$lastMarker = '(none)'
$peakWsMB   = 0
# TestHarness prints failures with U+2717. Built via [char] so this file stays PURE ASCII
# (PowerShell 5.1 reads .ps1 as ANSI without a BOM and would mangle a literal glyph).
$failGlyph  = [char]0x2717
$markerRx   = '^\[A44\]|^\s+OK\s|^>>>|^\s*GROUP|Godot Engine v|^\s+' + $failGlyph

while ($true) {
    if ($proc.HasExited) { break }
    Start-Sleep -Milliseconds 1000

    $size = 0
    if (Test-Path -LiteralPath $outLog) { $size = (Get-Item -LiteralPath $outLog).Length }

    if ($size -ne $lastSize) {
        $lastSize = $size
        $lastGrowth = Get-Date
        try {
            $tail = Get-Content -LiteralPath $outLog -Tail 40 -ErrorAction SilentlyContinue
            $m = $tail | Where-Object { $_ -match $markerRx } | Select-Object -Last 1
            if ($m) { $lastMarker = $m.Trim() }
        } catch { }
    }

    $elapsed = ((Get-Date) - $startTime).TotalSeconds
    $stalled = ((Get-Date) - $lastGrowth).TotalSeconds

    # MEMORY watchdog. The console exe SPAWNS the real engine as a separate PID, so
    # measure every godot-ish process, not just $proc (which is only the wrapper).
    $godots = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '(?i)godot' })
    $wsMB = 0
    foreach ($gp in $godots) { $w = [math]::Round($gp.WorkingSet64/1MB); if ($w -gt $wsMB) { $wsMB = $w } }
    if ($wsMB -gt $peakWsMB) { $peakWsMB = $wsMB }
    $freeMB = 0
    try { $freeMB = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1KB) } catch { $freeMB = 999999 }

    if ($elapsed -ge $TimeoutSec)     { $killed = $true; $killReason = ('ABSOLUTE_TIMEOUT ' + $TimeoutSec + 's'); break }
    if ($stalled -ge $StallSec)       { $killed = $true; $killReason = ('STALLED ' + $StallSec + 's with no new output'); break }
    if ($wsMB -ge $MaxWorkingSetMB)   { $killed = $true; $killReason = ('MEMORY_CEILING working set ' + $wsMB + 'MB >= ' + $MaxWorkingSetMB + 'MB'); break }
    if ($freeMB -le $MinFreeRamMB)    { $killed = $true; $killReason = ('LOW_SYSTEM_RAM free ' + $freeMB + 'MB <= ' + $MinFreeRamMB + 'MB'); break }
}

if ($killed) {
    Say ("KILLING: " + $killReason) 'Red'
    Say ("  last marker: " + $lastMarker) 'Yellow'
    try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop } catch { }
    Start-Sleep -Milliseconds 800
}

# ---- NO ORPHANS --------------------------------------------------------------
$leftovers = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match '(?i)godot' })
foreach ($lp in $leftovers) {
    Say ("CLEANUP: killing leftover Godot PID " + $lp.Id) 'Yellow'
    try { Stop-Process -Id $lp.Id -Force -ErrorAction Stop } catch { }
}

$endTime  = Get-Date
$exitCode = $null
if (-not $killed) {
    # WaitForExit()+Refresh() are required or ExitCode comes back empty on a
    # Start-Process -PassThru object. The exit code is PROOF, so capture it properly.
    try { $proc.WaitForExit() } catch { }
    try { $proc.Refresh() }    catch { }
    try { $exitCode = $proc.ExitCode } catch { $exitCode = $null }
}

try {
    $tail = Get-Content -LiteralPath $outLog -Tail 80 -ErrorAction SilentlyContinue
    $m = $tail | Where-Object { $_ -match $markerRx } | Select-Object -Last 1
    if ($m) { $lastMarker = $m.Trim() }
} catch { }

$outBytes = 0
if (Test-Path -LiteralPath $outLog) { $outBytes = (Get-Item -LiteralPath $outLog).Length }
$errBytes = 0
if (Test-Path -LiteralPath $errLog) { $errBytes = (Get-Item -LiteralPath $errLog).Length }

$scriptField = $null
if ($Mode -eq 'run') { $scriptField = $Script }

$record = [ordered]@{
    mode             = $Mode
    command          = ('"' + $GodotExe + '" ' + ($argv -join ' '))
    project_dir      = $ProjectDir
    script           = $scriptField
    timeout_sec      = $TimeoutSec
    stall_sec        = $StallSec
    max_ws_mb        = $MaxWorkingSetMB
    min_free_ram_mb  = $MinFreeRamMB
    peak_ws_mb       = $peakWsMB
    priority         = $Priority
    pid              = $proc.Id
    start_time       = $startTime.ToString('o')
    end_time         = $endTime.ToString('o')
    elapsed_sec      = [math]::Round(($endTime - $startTime).TotalSeconds, 1)
    exit_code        = $exitCode
    killed_by_runner = $killed
    kill_reason      = $killReason
    last_marker      = $lastMarker
    stdout_log       = $outLog
    stderr_log       = $errLog
    stdout_bytes     = $outBytes
    stderr_bytes     = $errBytes
    orphans_killed   = $leftovers.Count
}
$record | ConvertTo-Json -Depth 4 | Out-File -LiteralPath $meta -Encoding utf8

Say ''
Say '---------------- RESULT ----------------' 'Cyan'
$record.GetEnumerator() | ForEach-Object { '{0,-18} {1}' -f $_.Key, $_.Value } | Write-Host
Say ''
Say ("meta: " + $meta)

if ($killed) { exit 124 }
if ($null -ne $exitCode) { exit $exitCode }
exit 0
