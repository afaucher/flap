# test_lib.ps1 - what test_runner.ps1 and mutation_check.ps1 share (dot-source it): the runs a test splits into,
# how a run is started and judged, the last run's times, and the hash of the working tree.

# One test process, its output read line by line as it comes: the first line that fails the run (FailLine, the
# same rule Test-RunPassed applies to the whole output) is known while the test still runs.
if (-not ('FlapTestProc' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Text;
using System.Text.RegularExpressions;

public class FlapTestProc {
    public static readonly Regex FailLine = new Regex(@"SCRIPT ERROR|^(USER )?(ERROR|WARNING):");
    public readonly Process Proc = new Process();
    public readonly Stopwatch Watch = new Stopwatch();
    readonly StringBuilder _out = new StringBuilder();
    readonly StringBuilder _err = new StringBuilder();
    volatile string _firstFail;

    public FlapTestProc(ProcessStartInfo psi) {
        psi.UseShellExecute = false;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;
        Proc.StartInfo = psi;
        Proc.OutputDataReceived += (s, e) => Take(_out, e.Data);
        Proc.ErrorDataReceived += (s, e) => Take(_err, e.Data);
        Proc.Start();
        Watch.Start();
        Proc.BeginOutputReadLine();
        Proc.BeginErrorReadLine();
    }

    void Take(StringBuilder sb, string line) {
        if (line == null) return;
        lock (sb) sb.Append(line).Append('\n');
        if (_firstFail == null && FailLine.IsMatch(line)) _firstFail = line;
    }

    // The first line that fails this run, or null.
    public string FirstFail { get { return _firstFail; } }
    public bool HasExited { get { return Proc.HasExited; } }
    public void Kill() { try { if (!Proc.HasExited) Proc.Kill(); } catch (Exception) {} }
    // Waits for the exit and the last of the output.
    public void Wait() { Proc.WaitForExit(); }
    public string Out { get { lock (_out) return _out.ToString(); } }
    public string Err { get { lock (_err) return _err.ToString(); } }
    public double WallSec { get { return (Proc.ExitTime - Proc.StartTime).TotalSeconds; } }
    public double CpuSec { get { return Proc.TotalProcessorTime.TotalSeconds; } }
}
'@
}

# The engine itself: the console wrapper only relays its output, and the pipes take it directly.
function Get-FlapEngine([string]$Godot) {
    $engine = $Godot -replace '_console\.exe$', '.exe'
    if (Test-Path $engine) { return $engine }
    return $Godot
}

# The processes `names` run as: one per test, or N for a test declaring `const SHARDS := N` (Shard -1: not sharded).
function Get-TestRuns([string]$Root, [string[]]$Names) {
    $runs = @()
    foreach ($n in $Names) {
        $shards = 0
        $src = Join-Path $Root "tests\$n.gd"
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
    return $runs
}

# Start one run of a test in the project at `root`.
function Start-TestRun([string]$Engine, [string]$Root, $Run) {
    $shardArg = if ($Run.Shard -ge 0) { " --shard $($Run.Shard)" } else { "" }
    $mode = if ($Run.Name -like "gpu_test_*") { "" } else { "--headless " }   # (GPU tests run windowed: headless runs no shaders)
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Engine
    $psi.Arguments = "--path `"$Root`" $mode--fixed-fps 60 -- --run-test $($Run.Name)$shardArg"
    return New-Object FlapTestProc $psi
}

# A run passes only with exit code 0, the PASS marker, and no SCRIPT ERROR or engine ERROR:/WARNING: line. (A script
# error inside a coroutine aborts the test silently but can still end in a PASS marker; engine errors and warnings,
# e.g. a leaked object at exit, are bugs that never show up as a failed check.)
function Test-RunPassed([string]$Name, [int]$ExitCode, [string]$Out, [string]$Err) {
    $failLine = [bool]((($Out + "`n" + $Err) -split "`n") | Where-Object { [FlapTestProc]::FailLine.IsMatch($_.TrimEnd("`r")) } | Select-Object -First 1)
    return ($ExitCode -eq 0) -and ($Out -match [regex]::Escape(">>> [TEST PASSED] $Name <<<")) -and (-not $failLine)
}

# A file in this checkout's test_logs, else the main checkout's (a fresh worktree has none yet).
function Find-TestLog([string]$Root, [string]$File) {
    $p = Join-Path $Root "test_logs\$File"
    if (Test-Path $p) { return $p }
    $common = git -C $Root rev-parse --git-common-dir 2>$null
    if ($common) {
        if (-not [IO.Path]::IsPathRooted($common)) { $common = Join-Path $Root $common }
        $p = Join-Path (Split-Path ([IO.Path]::GetFullPath($common)) -Parent) "test_logs\$File"
        if (Test-Path $p) { return $p }
    }
    return $null
}

# The last run's times: label -> "wall,cpu" (test_logs\durations.csv).
function Read-TestDurations([string]$Root) {
    $times = @{}
    $src = Find-TestLog $Root "durations.csv"
    if ($src) {
        foreach ($line in Get-Content $src) {
            $f = $line -split ","
            if ($f.Count -ge 2) { $times[$f[0]] = ($f[1..($f.Count - 1)] -join ",") }
        }
    }
    return $times
}

# The git tree of the working tree as it is (committed or not, untracked files included), through a copy of the index
# (the real one is untouched; the copy's stat cache spares hashing unchanged files).
function Get-WorkingTree([string]$Root) {
    $idx = Join-Path ([IO.Path]::GetTempPath()) ("flap-index-" + [guid]::NewGuid())
    $real = git -C $Root rev-parse --path-format=absolute --git-path index 2>$null
    $env:GIT_INDEX_FILE = $idx
    try {
        if ($real -and (Test-Path $real)) { Copy-Item $real $idx } else { git -C $Root read-tree HEAD }
        git -C $Root add -A 2>$null
        return (git -C $Root write-tree)
    } finally {
        Remove-Item Env:GIT_INDEX_FILE
        Remove-Item $idx -ErrorAction SilentlyContinue
    }
}

# test_logs\passed.txt: the tree the last runs tested (first line), then each test that passed on it, every shard.
# mutation_check.ps1 skips its baseline for these.
function Read-PassedTests([string]$Root, [string]$Tree) {
    $p = Join-Path $Root "test_logs\passed.txt"
    if (-not (Test-Path $p)) { return @() }
    $lines = @(Get-Content $p)
    if ($lines.Count -eq 0 -or $lines[0] -ne $Tree) { return @() }
    return @($lines | Select-Object -Skip 1)
}

function Write-PassedTests([string]$Root, [string]$Tree, [string[]]$Names) {
    $all = @(Read-PassedTests $Root $Tree) + $Names | Sort-Object -Unique
    New-Item -ItemType Directory -Force -Path (Join-Path $Root "test_logs") | Out-Null
    Set-Content -Path (Join-Path $Root "test_logs\passed.txt") -Value (@($Tree) + $all)
}
