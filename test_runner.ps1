# test_runner.ps1 - run headless Godot tests from tests/<name>.gd (ported from ..\cast, minus its net/voice suites).
#
#   .\test_runner.ps1 -TestName test_glide_trim   # one test (comma-separate several)
#   .\test_runner.ps1 -TestAll                    # every tests\test_*.gd, in parallel
#   .\test_runner.ps1 -TestAll -NoImport          # skip the import pass
#
# Logs: test_logs\<name>.log / .err.log. A test passes only with exit code 0,
# the ">>> [TEST PASSED] <name> <<<" marker, AND no "SCRIPT ERROR" or engine ERROR:/WARNING: line in its output.
# Tests run under --fixed-fps 60, so physics is deterministic and runs as fast as the CPU allows.
param(
    [string]$TestName = "",
    [switch]$TestAll,
    [switch]$NoImport,
    [int]$TimeoutSec = 120
)
. "$PSScriptRoot\godot_env.ps1"
$godot = Resolve-FlapGodot
$logDir = Join-Path $PSScriptRoot "test_logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

if (-not $TestAll -and $TestName -eq "") {
    Write-Host "Usage: .\test_runner.ps1 -TestName <name> | -TestAll" -ForegroundColor Yellow
    Get-ChildItem "$PSScriptRoot\tests\test_*.gd" | ForEach-Object { Write-Host "  $($_.BaseName)" }
    exit 1
}
if (-not $NoImport) { Invoke-FlapImport $godot }

function Start-Test([string]$Name) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $godot
    $psi.Arguments = "--path `"$PSScriptRoot`" --headless --fixed-fps 60 -- --run-test $Name"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    [void]$p.Start()
    return [PSCustomObject]@{ Name = $Name; Proc = $p; Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync(); Watch = [Diagnostics.Stopwatch]::StartNew() }
}

function Finish-Test($r) {
    $left = [Math]::Max(0, [int](($TimeoutSec - $r.Watch.Elapsed.TotalSeconds) * 1000))
    if (-not $r.Proc.WaitForExit($left)) { try { $r.Proc.Kill() } catch {}; $r.Proc.WaitForExit() }
    $out = $r.Out.Result; $err = $r.Err.Result
    Set-Content -Path "$logDir\$($r.Name).log" -Value $out
    Set-Content -Path "$logDir\$($r.Name).err.log" -Value $err
    # A script error inside a coroutine aborts the test silently but can still end in a
    # PASS marker, so any SCRIPT ERROR in the output fails the test too.
    $scriptErr = ($out + "`n" + $err) -match "SCRIPT ERROR"
    # Engine errors and warnings fail the test too (e.g. the camera's physics-interpolation warning, a leaked
    # object at exit): they are bugs that never show up as a failed check.
    $engineMsg = ($out + "`n" + $err) -match "(?m)^(USER )?(ERROR|WARNING):"
    $ok = ($r.Proc.ExitCode -eq 0) -and ($out -match [regex]::Escape(">>> [TEST PASSED] $($r.Name) <<<")) -and (-not $scriptErr) -and (-not $engineMsg)
    $secs = $r.Watch.Elapsed.TotalSeconds.ToString("F1")
    if ($ok) { Write-Host "  PASS  $($r.Name)  ($secs s)" -ForegroundColor Green }
    else {
        Write-Host "  FAIL  $($r.Name)  ($secs s, exit $($r.Proc.ExitCode))" -ForegroundColor Red
        ($out + "`n" + $err) -split "`n" | Where-Object { $_ -match "ASSERT FAILED|SCRIPT ERROR|Parse Error|ERROR:|WARNING:|TEST FAILED" } | Select-Object -First 15 | ForEach-Object { Write-Host "        $_" }
    }
    return $ok
}

$names = if ($TestAll) { Get-ChildItem "$PSScriptRoot\tests\test_*.gd" | ForEach-Object { $_.BaseName } } else { @($TestName -split '[\s,]+' | Where-Object { $_ -ne "" }) }
$max = [Math]::Max(2, [Math]::Min(12, [Environment]::ProcessorCount - 4))
$running = @(); $failed = @(); $total = 0
foreach ($n in $names) {
    while ($true) {
        $done = @($running | Where-Object { $_.Proc.HasExited -or $_.Watch.Elapsed.TotalSeconds -gt $TimeoutSec })
        foreach ($r in $done) {
            $total += 1
            if (-not (Finish-Test $r)) { $failed += $r.Name }
            $running = @($running | Where-Object { $_ -ne $r })
        }
        if ($running.Count -lt $max) { break }
        Start-Sleep -Milliseconds 100
    }
    $running += Start-Test $n
}
foreach ($r in $running) { $total += 1; if (-not (Finish-Test $r)) { $failed += $r.Name } }

if ($failed.Count -gt 0) { Write-Host "$($failed.Count) of $total test(s) FAILED: $($failed -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host "All $total test(s) passed." -ForegroundColor Green
exit 0
