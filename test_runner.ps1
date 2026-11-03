# test_runner.ps1 - run headless Godot tests from tests/<name>.gd (ported from ..\cast, minus its net/voice suites).
#
#   .\test_runner.ps1 -TestName test_glide_trim   # one test (comma-separate several)
#   .\test_runner.ps1 -TestAll                    # every tests\test_*.gd, in parallel
#   .\test_runner.ps1 -TestAll -NoImport          # skip the import check
#   .\test_runner.ps1 -TestAll -Jobs 8            # at most 8 at a time
#
# GPU tests (tests\gpu_test_*.gd: they read back what a shader computed) run windowed, since the headless renderer
# runs no shaders; -TestAll includes them.
#
# Logs: test_logs\<name>.log / .err.log (a sharded test: <name>.<shard>.log). A test passes only with exit code 0,
# the ">>> [TEST PASSED] <name> <<<" marker, AND no "SCRIPT ERROR" or engine ERROR:/WARNING: line in its output.
# Tests run under --fixed-fps 60, so physics is deterministic and runs as fast as the CPU allows.
#
# What keeps the suite quick (the wall clock is the slowest test, or the total over the slots, whichever is more):
#   - the longest tests start first, by the times the last run took (test_logs\durations.csv, or the main
#     checkout's for a fresh worktree), so a long test isn't left to start last and run alone;
#   - a test declaring `const SHARDS := N` runs as N processes, each with `--shard i` (TestCase.shard picks its
#     part): one long test spread over N slots;
#   - the engine itself is launched (not its _console.exe wrapper, one process fewer per test), and its CPU time
#     goes in durations.csv beside the wall time;
#   - the import pass runs only when a script, scene, asset or test changed since the last one.
param(
    [string]$TestName = "",
    [switch]$TestAll,
    [switch]$NoImport,
    [int]$TimeoutSec = 120,
    [int]$Jobs = 0
)
. "$PSScriptRoot\godot_env.ps1"
$godot = Resolve-FlapGodot
# The engine itself: the console wrapper only relays its output, and these pipes take it directly.
$engine = $godot -replace '_console\.exe$', '.exe'
if (-not (Test-Path $engine)) { $engine = $godot }
$logDir = Join-Path $PSScriptRoot "test_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

if (-not $TestAll -and $TestName -eq "") {
    Write-Host "Usage: .\test_runner.ps1 -TestName <name> | -TestAll" -ForegroundColor Yellow
    Get-ChildItem "$PSScriptRoot\tests\test_*.gd" | ForEach-Object { Write-Host "  $($_.BaseName)" }
    exit 1
}
if (-not $NoImport) { Update-FlapImport $godot }

# A run: one process of a test (Shard -1: the test isn't sharded).
function Start-Test($Run) {
    $shardArg = if ($Run.Shard -ge 0) { " --shard $($Run.Shard)" } else { "" }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $engine
    $mode = if ($Run.Name -like "gpu_test_*") { "" } else { "--headless " }
    $psi.Arguments = "--path `"$PSScriptRoot`" $mode--fixed-fps 60 -- --run-test $($Run.Name)$shardArg"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    return [PSCustomObject]@{ Run = $Run; Proc = $p; Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync(); Watch = [Diagnostics.Stopwatch]::StartNew() }
}

$script:times = @{}
function Finish-Test($r) {
    $left = [Math]::Max(0, [int](($TimeoutSec - $r.Watch.Elapsed.TotalSeconds) * 1000))
    if (-not $r.Proc.WaitForExit($left)) { try { $r.Proc.Kill() } catch {}; $r.Proc.WaitForExit() }
    $out = $r.Out.Result; $err = $r.Err.Result
    $label = $r.Run.Label
    Set-Content -Path "$logDir\$($r.Run.Log).log" -Value $out
    Set-Content -Path "$logDir\$($r.Run.Log).err.log" -Value $err
    # A script error inside a coroutine aborts the test silently but can still end in a
    # PASS marker, so any SCRIPT ERROR in the output fails the test too.
    $scriptErr = ($out + "`n" + $err) -match "SCRIPT ERROR"
    # Engine errors and warnings fail the test too (e.g. the camera's physics-interpolation warning, a leaked
    # object at exit): they are bugs that never show up as a failed check.
    $engineMsg = ($out + "`n" + $err) -match "(?m)^(USER )?(ERROR|WARNING):"
    $ok = ($r.Proc.ExitCode -eq 0) -and ($out -match [regex]::Escape(">>> [TEST PASSED] $($r.Run.Name) <<<")) -and (-not $scriptErr) -and (-not $engineMsg)
    $wall = ($r.Proc.ExitTime - $r.Proc.StartTime).TotalSeconds
    $cpu = $r.Proc.TotalProcessorTime.TotalSeconds
    $script:times[$label] = "{0:F1},{1:F1}" -f $wall, $cpu
    $secs = $wall.ToString("F1")
    if ($ok) { Write-Host "  PASS  $label  ($secs s)" -ForegroundColor Green }
    else {
        Write-Host "  FAIL  $label  ($secs s, exit $($r.Proc.ExitCode))" -ForegroundColor Red
        ($out + "`n" + $err) -split "`n" | Where-Object { $_ -match "ASSERT FAILED|SCRIPT ERROR|Parse Error|ERROR:|WARNING:|TEST FAILED" } | Select-Object -First 15 | ForEach-Object { Write-Host "        $_" }
    }
    return $ok
}

# The last run's times (label -> wall seconds): this checkout's, else the main checkout's (a fresh worktree has none).
$durFile = Join-Path $logDir "durations.csv"
$durSrc = $durFile
if (-not (Test-Path $durSrc)) {
    $common = git -C $PSScriptRoot rev-parse --git-common-dir 2>$null
    if ($common) {
        if (-not [IO.Path]::IsPathRooted($common)) { $common = Join-Path $PSScriptRoot $common }
        $durSrc = Join-Path (Split-Path ([IO.Path]::GetFullPath($common)) -Parent) "test_logs\durations.csv"
    }
}
$last = @{}
if (Test-Path $durSrc) {
    foreach ($line in Get-Content $durSrc) {
        $f = $line -split ","
        if ($f.Count -ge 2) { $last[$f[0]] = [double]$f[1]; $script:times[$f[0]] = ($f[1..($f.Count - 1)] -join ",") }
    }
}

$names = if ($TestAll) { Get-ChildItem "$PSScriptRoot\tests\test_*.gd", "$PSScriptRoot\tests\gpu_test_*.gd" | ForEach-Object { $_.BaseName } } else { @($TestName -split '[\s,]+' | Where-Object { $_ -ne "" }) }
$runs = @()
foreach ($n in $names) {
    $shards = 0
    $src = "$PSScriptRoot\tests\$n.gd"
    if (Test-Path $src) {
        $m = [regex]::Match((Get-Content -Raw $src), '(?m)^const SHARDS\s*:=\s*(\d+)')
        if ($m.Success) { $shards = [int]$m.Groups[1].Value }
    }
    if ($shards -gt 1) {
        for ($i = 0; $i -lt $shards; $i++) { $runs += [PSCustomObject]@{ Name = $n; Shard = $i; Label = "$n#$i"; Log = "$n.$i" } }
    } else {
        $runs += [PSCustomObject]@{ Name = $n; Shard = -1; Label = $n; Log = $n }
    }
}
# Longest first; a test with no time yet goes first too (it may be long).
$runs = @($runs | Sort-Object -Property @{ Expression = { if ($last.ContainsKey($_.Label)) { $last[$_.Label] } else { 1e9 } }; Descending = $true }, Label)

# 16 at a time: past it (on 32 threads) the suite got no quicker, the slowest test sets the pace.
$max = if ($Jobs -gt 0) { $Jobs } else { [Math]::Max(2, [Math]::Min(16, [Environment]::ProcessorCount - 4)) }
$running = @(); $failed = @(); $total = 0
$suite = [Diagnostics.Stopwatch]::StartNew()
foreach ($run in $runs) {
    while ($true) {
        $done = @($running | Where-Object { $_.Proc.HasExited -or $_.Watch.Elapsed.TotalSeconds -gt $TimeoutSec })
        foreach ($r in $done) {
            $total += 1
            if (-not (Finish-Test $r)) { $failed += $r.Run.Label }
            $running = @($running | Where-Object { $_ -ne $r })
        }
        if ($running.Count -lt $max) { break }
        Start-Sleep -Milliseconds 50
    }
    $running += Start-Test $run
}
while ($running.Count -gt 0) {
    $done = @($running | Where-Object { $_.Proc.HasExited -or $_.Watch.Elapsed.TotalSeconds -gt $TimeoutSec })
    if ($done.Count -eq 0) { Start-Sleep -Milliseconds 50; continue }
    foreach ($r in $done) {
        $total += 1
        if (-not (Finish-Test $r)) { $failed += $r.Run.Label }
        $running = @($running | Where-Object { $_ -ne $r })
    }
}
$script:times.Keys | Sort-Object | ForEach-Object { "$_,$($script:times[$_])" } | Set-Content -Path $durFile

$wall = $suite.Elapsed.TotalSeconds.ToString("F0")
if ($failed.Count -gt 0) { Write-Host "$($failed.Count) of $total test(s) FAILED in $wall s: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host "All $total test(s) passed in $wall s ($max at a time)." -ForegroundColor Green
exit 0
