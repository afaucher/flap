# mutation_check.ps1 - replay past bugs and prove the tests still catch them.
#
#   .\mutation_check.ps1                                 # every entry (the merge gate, after -TestAll: ~1.5 min)
#   .\mutation_check.ps1 -Changed                        # while iterating: the entries this branch could affect
#   .\mutation_check.ps1 -Only fold-elbow-raised,bom-in-doc
#   .\mutation_check.ps1 -Jobs 8                         # test processes at a time (default 12)
#   .\mutation_check.ps1 -Baseline                       # run the baseline even where test_runner just passed it
#   .\mutation_check.ps1 -Keep                           # leave the scratch trees for inspection
#   .\mutation_check.ps1 -AllChecks                      # an audit (~10 min): every named test to the end, every failing
#                                                        # line in test_logs\mutation_results.csv (is each caught for its bug?)
#
# Each entry reintroduces one bug we have had (exact find/replace edits; an empty find prepends) in a scratch copy
# of the current working tree (committed or not, untracked files included), then runs only the tests it names. At
# least one of them must FAIL, by the test runner's rule (a failed check, a script error, an engine ERROR:/WARNING:
# line, a crash or a timeout):
#   KILLED    a named test failed: that bug would be caught
#   SURVIVED  every named test passed: a gap -- strengthen a test until it fails
#   STALE     a find string no longer matches exactly once: update the entry to today's code
# A bug fixed for good gets an entry here, so the test that pins it is proven able to fail.
#
# What keeps it quick (the verdicts are the same as running every named test to the end, one entry at a time):
#   - Parallel: one scratch tree per entry in flight (a git worktree, and copies of it sharing its assets, docs and
#     imported files through junctions), -Jobs test processes at a time across them.
#   - Fail fast: a test's output is read as it comes, and the first line that fails it under the runner's rule
#     (test_lib.ps1's FlapTestProc.FailLine) decides the entry: its other test processes are stopped there.
#   - The killer first: flap-mutation-kills.csv (in the git common dir, so every worktree shares it) remembers which
#     test (which shard) killed each entry and how soon; that one runs alone first, the entry's other tests only if it
#     passes. Longest entries start first.
#   - Baseline: the named tests must pass on the unmutated tree, or a failure proves nothing. Those that
#     test_runner.ps1 passed on this very tree (test_logs\passed.txt, keyed by the tree's git hash) are not run
#     again; the rest run alongside the entries, and a baseline failure stops the check.
#   - -Changed: only the entries this branch could have changed the verdict of -- those that edit a file changed
#     since the merge-base with -Base (master), name a test that changed, or are new or changed in mutations.json;
#     every entry if the test machinery itself changed (test_case.gd, boot.gd, project.godot, these scripts). Every
#     entry's find text is still checked (STALE costs nothing to find). What -Changed can miss: a change in one file
#     that blunts a test against a bug in another. The full check catches that; see AGENTS.md for when it runs.
param(
    [string[]]$Only = @(),
    [switch]$Changed,
    [string]$Base = "master",
    [int]$Jobs = 0,
    [int]$TimeoutSec = 120,
    [switch]$Baseline,
    [switch]$AllChecks,
    [switch]$Keep
)
$ErrorActionPreference = "Continue"   # (git writes progress to stderr; check exit codes instead)
$root = $PSScriptRoot
. "$root\godot_env.ps1"
. "$root\test_lib.ps1"
$clock = [Diagnostics.Stopwatch]::StartNew()
$enc = New-Object Text.UTF8Encoding $false
$parsed = ConvertFrom-Json (Get-Content -Raw -Encoding UTF8 (Join-Path $root "tests\regressions\mutations.json"))
$muts = @($parsed | ForEach-Object { $_ })   # (PowerShell 5.1 hands a top-level JSON array back as one item)
if ($Only.Count) { $muts = @($muts | Where-Object { $Only -contains $_.id }) }
if ($muts.Count -eq 0) { Write-Host "No mutations selected." -ForegroundColor Yellow; exit 1 }
$slots = if ($Jobs -gt 0) { $Jobs } else { [Math]::Max(2, [Math]::Min(12, [Environment]::ProcessorCount - 4)) }
$godot = Resolve-FlapGodot
$engine = Get-FlapEngine $godot

# Snapshot the working tree as a commit (test_lib's Get-WorkingTree: the real index is untouched).
$tree = Get-WorkingTree $root
$commit = git -C $root commit-tree $tree -p HEAD -m "mutation check snapshot"
$tag = $commit.Substring(0, 10) + "-" + ([guid]::NewGuid().ToString().Substring(0, 4))
$t0 = Join-Path ([IO.Path]::GetTempPath()) "flap-mutants-$tag"
git -C $root worktree add --detach $t0 $commit 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "Could not create the scratch worktree." -ForegroundColor Red; exit 1 }
$trees = @($t0)
$junctions = @()

# Each entry's edits, worked out against the snapshot: the files it changes and their mutated text, or why it's stale.
function Get-Mutant($m) {
    $files = @{}
    foreach ($e in $m.edits) {
        $text = $files[$e.file]
        if ($null -eq $text) {
            $path = Join-Path $t0 $e.file
            if (-not (Test-Path $path)) { return @{ Stale = "$($e.file) is gone" } }
            $text = [IO.File]::ReadAllText($path)
        }
        if ($e.find -eq "") {
            $text = $e.replace + $text
        } else {
            $n = ([regex]::Matches($text, [regex]::Escape($e.find))).Count
            if ($n -ne 1) { return @{ Stale = "find matches $n times in $($e.file)" } }
            $text = $text.Replace($e.find, $e.replace)
        }
        $files[$e.file] = $text
    }
    return @{ Stale = ""; Files = $files }
}

$results = @()
function Write-Result($Id, $Result, $Detail, $Run = "", $Line = "") {
    $script:results += [PSCustomObject]@{ Id = $Id; Result = $Result; Detail = $Detail; Run = $Run; Line = $Line }
    $color = @{ KILLED = "Green"; SURVIVED = "Red"; STALE = "Yellow" }[$Result]
    Write-Host ("  {0,-9} {1,-30} {2}" -f $Result, $Id, $Detail) -ForegroundColor $color
}

try {
    $all = @($parsed | ForEach-Object { $_ })
    $live = @()
    $byId = @{}
    foreach ($m in $all) { $byId[$m.id] = Get-Mutant $m }

    if ($Changed) {
        # What this branch changed since it left -Base, committed or not.
        $mb = git -C $root merge-base HEAD $Base
        if ($LASTEXITCODE -ne 0) { Write-Host "No merge-base with $Base." -ForegroundColor Red; exit 1 }
        $changedFiles = @(git -C $root diff --name-only $mb) + @(git -C $root ls-files --others --exclude-standard)
        $oldEntries = @{}
        $oldJson = git -C $root show "${mb}:tests/regressions/mutations.json" 2>$null
        if ($LASTEXITCODE -eq 0) {
            foreach ($o in @(ConvertFrom-Json ($oldJson -join "`n") | ForEach-Object { $_ })) { $oldEntries[$o.id] = ConvertTo-Json $o -Compress -Depth 8 }
        }
        $machinery = @("scripts/test_support/test_case.gd", "scripts/app/boot.gd", "project.godot", "test_runner.ps1", "test_lib.ps1",
            "mutation_check.ps1", "godot_env.ps1")
        $everything = @($changedFiles | Where-Object { $machinery -contains $_ })
        if ($everything.Count) { Write-Host "Test machinery changed ($($everything -join ', ')): every entry." -ForegroundColor DarkGray }
        $picked = @()
        foreach ($m in $muts) {
            $why = ""
            if ($everything.Count) { $why = "machinery" }
            elseif ($byId[$m.id].Stale) { $why = "stale" }
            elseif ($oldEntries[$m.id] -ne (ConvertTo-Json $m -Compress -Depth 8)) { $why = "entry" }
            elseif (@($m.edits | Where-Object { $changedFiles -contains $_.file }).Count) { $why = "edits" }
            elseif (@($m.tests | Where-Object { $changedFiles -contains "tests/$_.gd" }).Count) { $why = "tests" }
            if ($why) { $picked += $m }
        }
        Write-Host "-Changed: $($picked.Count) of $($muts.Count) entries (since $($mb.Substring(0, 10)) on $Base; $($changedFiles.Count) files changed)." -ForegroundColor DarkGray
        $muts = $picked
    }
    foreach ($m in $muts) {
        if ($byId[$m.id].Stale) { Write-Result $m.id "STALE" $byId[$m.id].Stale } else { $live += $m }
    }

    # The baseline: the named tests, less those test_runner.ps1 passed on this same tree.
    $named = @($live | ForEach-Object { $_.tests } | Sort-Object -Unique)
    $known = if ($Baseline) { @() } else { @(Read-PassedTests $root $tree) }
    $baseNames = @($named | Where-Object { $known -notcontains $_ })
    if ($named.Count -and $baseNames.Count -lt $named.Count) {
        Write-Host "Baseline: $($named.Count - $baseNames.Count) of $($named.Count) tests passed on this tree in the last test_runner run." -ForegroundColor DarkGray
    }

    if ($live.Count) {
        # The scratch trees: the worktree, imported once, and copies of it (assets, docs and the imported files shared
        # through junctions, unless an entry edits them), copied all at once.
        & $godot --path $t0 --headless --import 2>&1 | Out-Null
        $edited = @($live | ForEach-Object { $_.edits } | ForEach-Object { $_.file })
        $share = @(@("assets", "docs", ".godot\imported") | Where-Object {
            $d = $_.Replace("\", "/"); (Test-Path (Join-Path $t0 $_)) -and -not ($edited | Where-Object { $_.StartsWith("$d/") })
        })
        $count = [Math]::Min($live.Count + [int]($baseNames.Count -gt 0), $slots + 2)
        $xd = (@($share | ForEach-Object { "`"$(Join-Path $t0 $_)`"" }) -join " ")
        $copies = @(for ($i = 1; $i -lt $count; $i++) {
            $psi = New-Object Diagnostics.ProcessStartInfo "robocopy", "`"$t0`" `"$t0-$i`" /E /MT:4 /XF .git /XD $xd /NFL /NDL /NJH /NJS /NP"
            $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
            [PSCustomObject]@{ Tree = "$t0-$i"; Proc = [Diagnostics.Process]::Start($psi) }
        })
        $trees += @($copies | ForEach-Object { $_.Tree })
        foreach ($c in $copies) { $c.Proc.WaitForExit() }
        foreach ($c in $copies) {
            if ($c.Proc.ExitCode -ge 8) { throw "Could not copy the scratch tree to $($c.Tree)." }
            $ti = $c.Tree
            foreach ($d in $share) {
                $link = Join-Path $ti $d
                New-Item -ItemType Junction -Path $link -Target (Join-Path $t0 $d) | Out-Null
                $script:junctions += $link
            }
        }

        $durations = Read-TestDurations $root
        $killFile = Join-Path (git -C $root rev-parse --path-format=absolute --git-common-dir) "flap-mutation-kills.csv"
        function Read-Kills {
            $k = @{}
            if (Test-Path $killFile) {
                foreach ($line in Get-Content $killFile) { $f = $line -split ","; if ($f.Count -ge 3) { $k[$f[0]] = @{ Label = $f[1]; Sec = [double]$f[2] } } }
            }
            return $k
        }
        $kills = Read-Kills
        function Get-Dur($label) { if ($durations.ContainsKey($label)) { return [double](($durations[$label] -split ",")[0]) } return 60.0 }

        # A job: the baseline or one entry, its test runs in order; Released of them may start (the rest wait for the
        # remembered killer to pass).
        $queue = New-Object System.Collections.ArrayList
        foreach ($m in $live) {
            $runs = @(Get-TestRuns $t0 @($m.tests) | Sort-Object -Property @{ Expression = { Get-Dur $_.Label }; Descending = $true })
            $k = $kills[$m.id]
            $first = @(if ($k) { $runs | Where-Object { $_.Label -eq $k.Label } })   # (inside @(): PowerShell 5.1's lone object has no Count)
            if ($first.Count) { $runs = @($first) + @($runs | Where-Object { $_.Label -ne $k.Label }) }
            $est = if ($first.Count) { $k.Sec } else { ($runs | ForEach-Object { Get-Dur $_.Label } | Measure-Object -Maximum).Maximum }
            [void]$queue.Add([PSCustomObject]@{ Id = $m.id; Mutant = $m; Files = $byId[$m.id].Files; Runs = $runs; Released = $(if ($first.Count -and -not $AllChecks) { 1 } else { $runs.Count })
                Next = 0; Ended = 0; Procs = @(); Tree = $null; Saved = @{}; Failed = $null; Est = $est; Watch = $null; Lines = @() })
        }
        $sorted = @($queue | Sort-Object -Property @{ Expression = { $_.Est }; Descending = $true })
        $queue = New-Object System.Collections.ArrayList
        if ($baseNames.Count) {
            $runs = @(Get-TestRuns $t0 $baseNames | Sort-Object -Property @{ Expression = { Get-Dur $_.Label }; Descending = $true })
            [void]$queue.Add([PSCustomObject]@{ Id = "(baseline)"; Mutant = $null; Files = @{}; Runs = $runs; Released = $runs.Count
                Next = 0; Ended = 0; Procs = @(); Tree = $null; Saved = @{}; Failed = $null; Est = 0; Watch = $null; Lines = @() })
        }
        foreach ($j in $sorted) { [void]$queue.Add($j) }
        $base = if ($baseNames.Count) { "baseline $($baseNames.Count) tests" } else { "no baseline to run" }
        Write-Host ("{0} entries, {1}; {2} at a time over {3} trees (set up in {4:F0} s)." -f $live.Count, $base, $slots, $trees.Count, $clock.Elapsed.TotalSeconds) -ForegroundColor DarkGray

        $free = New-Object System.Collections.Queue
        foreach ($t in $trees) { $free.Enqueue($t) }
        $active = New-Object System.Collections.ArrayList
        $running = 0
        $procSec = 0.0; $loop = [Diagnostics.Stopwatch]::StartNew(); $tick = 0
        $runLog = New-Object Collections.ArrayList   # (FLAP_MUT_DEBUG=1: every run, to test_logs\mutation_runs.csv, and a timeline)
        function Add-RunLog($j, $p) {
            $script:procSec += $p.Proc.Watch.Elapsed.TotalSeconds
            if ($env:FLAP_MUT_DEBUG) { [void]$runLog.Add(("{0},{1},{2:F2},{3:F2},{4}" -f $j.Id, $p.Run.Label, $p.T0, $loop.Elapsed.TotalSeconds, [bool]$p.Proc.FirstFail)) }
        }
        $newKills = @{}
        while ($queue.Count -or $active.Count) {
            $busy = $false
            # Reap: a run ends at its first failing line, its exit, or the timeout.
            foreach ($j in @($active)) {
                foreach ($p in @($j.Procs)) {
                    $tp = $p.Proc
                    if (-not (($tp.FirstFail -and -not $AllChecks) -or $tp.HasExited -or $tp.Watch.Elapsed.TotalSeconds -gt $TimeoutSec)) { continue }
                    $tp.Kill(); $tp.Wait(); Add-RunLog $j $p
                    $j.Procs = @($j.Procs | Where-Object { $_ -ne $p }); $j.Ended += 1; $running -= 1; $busy = $true
                    $ok = (-not $tp.FirstFail) -and (Test-RunPassed $p.Run.Name $tp.Proc.ExitCode $tp.Out $tp.Err)
                    if ($AllChecks) { $lbl = $p.Run.Label; $j.Lines += @((($tp.Out + "`n" + $tp.Err) -split "`n") | Where-Object { [FlapTestProc]::FailLine.IsMatch($_) } | ForEach-Object { "${lbl}: $($_.Trim())" }) }
                    if (-not $ok -and -not $j.Failed) {
                        $why = if ($tp.FirstFail) { $tp.FirstFail.Trim() } elseif ($tp.Watch.Elapsed.TotalSeconds -gt $TimeoutSec) { "timed out" } else { "exit $($tp.Proc.ExitCode)" }
                        $j.Failed = [PSCustomObject]@{ Label = $p.Run.Label; Why = $why; Sec = $tp.Watch.Elapsed.TotalSeconds; Out = $tp.Out + "`n" + $tp.Err }
                    }
                }
                if ($j.Failed -and -not $AllChecks) {
                    foreach ($p in $j.Procs) { $p.Proc.Kill(); $p.Proc.Wait(); $running -= 1; Add-RunLog $j $p }
                    $j.Procs = @()
                } elseif ($j.Ended -eq $j.Released -and $j.Released -lt $j.Runs.Count) {
                    $j.Released = $j.Runs.Count   # (the remembered killer passed: the rest now)
                    continue
                } elseif ($j.Ended -lt $j.Runs.Count) { continue }

                # Decided: put the tree back.
                foreach ($f in $j.Saved.Keys) { [IO.File]::WriteAllBytes((Join-Path $j.Tree $f), $j.Saved[$f]) }
                $free.Enqueue($j.Tree); [void]$active.Remove($j)
                if (-not $j.Mutant) {
                    if ($j.Failed) {
                        foreach ($o in $active) { foreach ($p in $o.Procs) { $p.Proc.Kill(); $p.Proc.Wait() } }
                        ($j.Failed.Out -split "`n") | Where-Object { $_ -match "ASSERT FAILED|SCRIPT ERROR|Parse Error|ERROR:|WARNING:|TEST FAILED" } | Select-Object -First 15 | ForEach-Object { Write-Host "        $_" }
                        Write-Host "Baseline failed ($($j.Failed.Label): $($j.Failed.Why)): fix the suite before checking mutations." -ForegroundColor Red
                        exit 1
                    }
                    Write-Host ("  baseline passed ({0:F0} s)" -f $j.Watch.Elapsed.TotalSeconds) -ForegroundColor DarkGray
                } elseif ($j.Failed) {
                    if (-not $AllChecks) { $newKills[$j.Id] = "{0},{1:F1}" -f $j.Failed.Label, $j.Failed.Sec }
                    $why = $j.Failed.Why; if ($why.Length -gt 70) { $why = $why.Substring(0, 70) + "..." }
                    Write-Result $j.Id "KILLED" ("failed: {0} at {1:F1} s ({2})" -f $j.Failed.Label, $j.Failed.Sec, $why) $j.Failed.Label $(if ($AllChecks) { $j.Lines -join " || " } else { $j.Failed.Why })
                } else {
                    Write-Result $j.Id "SURVIVED" ("passed: " + ($j.Mutant.tests -join ", "))
                }
            }
            # A free tree takes the next job: its edits applied (the original bytes kept to put back).
            while ($free.Count -and $queue.Count) {
                $j = $queue[0]; $queue.RemoveAt(0)
                $j.Tree = $free.Dequeue()
                foreach ($f in $j.Files.Keys) {
                    $path = Join-Path $j.Tree $f
                    $j.Saved[$f] = [IO.File]::ReadAllBytes($path)
                    [IO.File]::WriteAllText($path, $j.Files[$f], $enc)
                }
                $j.Watch = [Diagnostics.Stopwatch]::StartNew()
                [void]$active.Add($j); $busy = $true
            }
            # Fill the slots, the earliest jobs first.
            foreach ($j in $active) {
                while ($running -lt $slots -and $j.Next -lt $j.Released) {
                    $run = $j.Runs[$j.Next]; $j.Next += 1
                    $j.Procs += [PSCustomObject]@{ Run = $run; Proc = (Start-TestRun $engine $j.Tree $run); T0 = $loop.Elapsed.TotalSeconds }
                    $running += 1; $busy = $true
                }
            }
            if ($env:FLAP_MUT_DEBUG -and $loop.Elapsed.TotalSeconds -gt $tick) {
                $tick += 5; Write-Host ("    [{0,4:F0} s] running {1}, jobs {2}, queued {3}, free trees {4}" -f $loop.Elapsed.TotalSeconds, $running, $active.Count, $queue.Count, $free.Count) -ForegroundColor DarkGray
            }
            if (-not $busy) { Start-Sleep -Milliseconds 50 }
        }

        if ($env:FLAP_MUT_DEBUG) { $runLog | Set-Content (Join-Path $root "test_logs\mutation_runs.csv") }
        Write-Host ("Test processes busy {0:P0} of {1} slots over {2:F0} s." -f ($procSec / [Math]::Max(1, $slots * $loop.Elapsed.TotalSeconds)), $slots, $loop.Elapsed.TotalSeconds) -ForegroundColor DarkGray
        # Remember the killers for next time, over what other checkouts have written since (only a hint: last one wins).
        $kills = Read-Kills
        foreach ($id in $newKills.Keys) { $kills[$id] = $null }
        $rows = @($kills.Keys | Where-Object { $kills[$_] } | ForEach-Object { "$_,$($kills[$_].Label),$($kills[$_].Sec)" }) +
            @($newKills.Keys | ForEach-Object { "$_,$($newKills[$_])" })
        $rows | Sort-Object | Set-Content -Path $killFile
    }
} finally {
    if ($Keep) {
        Write-Host "Scratch trees kept: $($trees -join ', ')" -ForegroundColor DarkGray
    } else {
        # The junctions first (rmdir takes the link, never what it points at), then the copies, then the worktree.
        foreach ($link in $junctions) { cmd /c rmdir "$link" 2>&1 | Out-Null }
        foreach ($ti in @($trees | Select-Object -Skip 1)) {
            if (@($junctions | Where-Object { $_.StartsWith("$ti\") -and (Test-Path $_) }).Count) { Write-Host "Left $ti (a junction would not come off)." -ForegroundColor Yellow; continue }
            cmd /c rmdir /s /q "$ti" 2>&1 | Out-Null
        }
        git -C $root worktree remove --force $t0 2>&1 | Out-Null
    }
}

# Every verdict with the whole line that decided it (what each test caught: is it still the bug the entry describes?).
if ($results.Count) {
    New-Item -ItemType Directory -Force -Path (Join-Path $root "test_logs") | Out-Null
    $results | Select-Object Id, Result, Run, Line, Detail | Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $root "test_logs\mutation_results.csv")
}
$bad = @($results | Where-Object { $_.Result -ne "KILLED" })
$killed = $results.Count - $bad.Count
$secs = $clock.Elapsed.TotalSeconds.ToString("F0")
if ($bad.Count) { Write-Host "$killed of $($results.Count) bugs caught in $secs s; $($bad.Count) not: $(($bad | ForEach-Object { $_.Id }) -join ', ')" -ForegroundColor Red; exit 1 }
if ($results.Count -eq 0) { Write-Host "No entries to check (-Changed: nothing this branch changed touches them)." -ForegroundColor Green; exit 0 }
Write-Host "All $($results.Count) replayed bugs are caught by the tests ($secs s)." -ForegroundColor Green
exit 0
