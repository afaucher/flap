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
# test_logs\passed.txt records the tree tested and the tests that passed on it, so mutation_check.ps1 needn't run
# them again as its baseline. Process handling and the pass rule are in test_lib.ps1 (shared with mutation_check).
param(
    [string]$TestName = "",
    [switch]$TestAll,
    [switch]$NoImport,
    [int]$TimeoutSec = 120,
    [int]$Jobs = 0
)
. "$PSScriptRoot\godot_env.ps1"
. "$PSScriptRoot\test_lib.ps1"
$godot = Resolve-FlapGodot
$engine = Get-FlapEngine $godot
$logDir = Join-Path $PSScriptRoot "test_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

if (-not $TestAll -and $TestName -eq "") {
    Write-Host "Usage: .\test_runner.ps1 -TestName <name> | -TestAll" -ForegroundColor Yellow
    Get-ChildItem "$PSScriptRoot\tests\test_*.gd" | ForEach-Object { Write-Host "  $($_.BaseName)" }
    exit 1
}
if (-not $NoImport) { Update-FlapImport $godot }
$tree = Get-WorkingTree $PSScriptRoot   # (what these runs test: test_logs\passed.txt records it)

# A run: one process of a test (Shard -1: the test isn't sharded).
function Start-Test($Run) {
    return [PSCustomObject]@{ Run = $Run; Proc = (Start-TestRun $engine $PSScriptRoot $Run) }
}

$script:times = Read-TestDurations $PSScriptRoot
function Finish-Test($r) {
    if (-not $r.Proc.HasExited) { $r.Proc.Kill() }   # (timed out)
    $r.Proc.Wait()
    $out = $r.Proc.Out; $err = $r.Proc.Err
    $label = $r.Run.Label
    Set-Content -Path "$logDir\$($r.Run.Log).log" -Value $out
    Set-Content -Path "$logDir\$($r.Run.Log).err.log" -Value $err
    $ok = Test-RunPassed $r.Run.Name $r.Proc.Proc.ExitCode $out $err
    $wall = $r.Proc.WallSec
    $script:times[$label] = "{0:F1},{1:F1}" -f $wall, $r.Proc.CpuSec
    $secs = $wall.ToString("F1")
    if ($ok) { Write-Host "  PASS  $label  ($secs s)" -ForegroundColor Green }
    else {
        Write-Host "  FAIL  $label  ($secs s, exit $($r.Proc.Proc.ExitCode))" -ForegroundColor Red
        ($out + "`n" + $err) -split "`n" | Where-Object { $_ -match "ASSERT FAILED|SCRIPT ERROR|Parse Error|ERROR:|WARNING:|TEST FAILED" } | Select-Object -First 15 | ForEach-Object { Write-Host "        $_" }
    }
    return $ok
}

# The last run's times (label -> wall seconds): this checkout's, else the main checkout's (a fresh worktree has none).
$durFile = Join-Path $logDir "durations.csv"
$last = @{}
foreach ($k in @($script:times.Keys)) { $last[$k] = [double](($script:times[$k] -split ",")[0]) }

$names = if ($TestAll) { Get-ChildItem "$PSScriptRoot\tests\test_*.gd", "$PSScriptRoot\tests\gpu_test_*.gd" | ForEach-Object { $_.BaseName } } else { @($TestName -split '[\s,]+' | Where-Object { $_ -ne "" }) }
$runs = @(Get-TestRuns $PSScriptRoot $names)
# Longest first; a test with no time yet goes first too (it may be long).
$runs = @($runs | Sort-Object -Property @{ Expression = { if ($last.ContainsKey($_.Label)) { $last[$_.Label] } else { 1e9 } }; Descending = $true }, Label)

# 16 at a time: past it (on 32 threads) the suite got no quicker, the slowest test sets the pace.
$max = if ($Jobs -gt 0) { $Jobs } else { [Math]::Max(2, [Math]::Min(16, [Environment]::ProcessorCount - 4)) }
$running = @(); $failed = @(); $total = 0
$suite = [Diagnostics.Stopwatch]::StartNew()
foreach ($run in $runs) {
    while ($true) {
        $done = @($running | Where-Object { $_.Proc.HasExited -or $_.Proc.Watch.Elapsed.TotalSeconds -gt $TimeoutSec })
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
    $done = @($running | Where-Object { $_.Proc.HasExited -or $_.Proc.Watch.Elapsed.TotalSeconds -gt $TimeoutSec })
    if ($done.Count -eq 0) { Start-Sleep -Milliseconds 50; continue }
    foreach ($r in $done) {
        $total += 1
        if (-not (Finish-Test $r)) { $failed += $r.Run.Label }
        $running = @($running | Where-Object { $_ -ne $r })
    }
}
$script:times.Keys | Sort-Object | ForEach-Object { "$_,$($script:times[$_])" } | Set-Content -Path $durFile
# The tests that passed, every shard, on this tree (if nothing changed while they ran): mutation_check.ps1's baseline.
$passed = @($names | Where-Object { $n = $_; -not ($failed | Where-Object { ($_ -split "#")[0] -eq $n }) })
if ($passed.Count -and (Get-WorkingTree $PSScriptRoot) -eq $tree) { Write-PassedTests $PSScriptRoot $tree $passed }

$wall = $suite.Elapsed.TotalSeconds.ToString("F0")
if ($failed.Count -gt 0) { Write-Host "$($failed.Count) of $total test(s) FAILED in $wall s: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host "All $total test(s) passed in $wall s ($max at a time)." -ForegroundColor Green
exit 0
