# test_lib.ps1 - what test_runner.ps1, mutation_check.ps1 and probe.ps1 share (dot-source it): the runs a test splits
# into, how a run is started and judged, the last run's times, and the hash of the working tree.

# One test process, its output read line by line as it comes: the first line that fails the run (FailLine, the
# same rule Test-RunPassed applies to the whole output) is known while the test still runs.
#
# Every run starts on a desktop of its own (FlapHidden: CreateDesktop "FlapHidden" in the user's window station), so
# a windowed run (gpu_test_*, render probes) draws as usual, on the real GPU, but its window is never on screen,
# never in the taskbar and can't take focus. (Off-screen --position is clamped back onto the screen, and a minimized
# window stops Godot drawing.) FLAP_SHOW_WINDOWS=1 starts them on the user's desktop instead, to watch one.
if (-not ('FlapTestProc' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Concurrent;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using Microsoft.Win32.SafeHandles;

public static class FlapHidden {
    public const string DesktopName = "FlapHidden";
    static IntPtr _desk;
    static readonly object _lock = new object();

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX, dwY, dwXSize, dwYSize, dwXCountChars, dwYCountChars, dwFillAttribute, dwFlags;
        public short wShowWindow, cbReserved2; public IntPtr lpReserved2, hStdInput, hStdOutput, hStdError;
    }
    [StructLayout(LayoutKind.Sequential)]
    struct STARTUPINFOEX { public STARTUPINFO StartupInfo; public IntPtr lpAttributeList; }
    [StructLayout(LayoutKind.Sequential)]
    struct PROCESS_INFORMATION { public IntPtr hProcess, hThread; public int dwProcessId, dwThreadId; }
    [StructLayout(LayoutKind.Sequential)]
    struct SECURITY_ATTRIBUTES { public int nLength; public IntPtr lpSecurityDescriptor; public bool bInheritHandle; }

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateDesktopW(string name, IntPtr device, IntPtr devmode, int flags, uint access, IntPtr sa);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CreatePipe(out IntPtr read, out IntPtr write, ref SECURITY_ATTRIBUTES sa, int size);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetHandleInformation(IntPtr h, int mask, int flags);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateFileW(string name, uint access, uint share, ref SECURITY_ATTRIBUTES sa, uint disp, uint flags, IntPtr tmpl);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool InitializeProcThreadAttributeList(IntPtr list, int count, int flags, ref IntPtr size);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool UpdateProcThreadAttribute(IntPtr list, int flags, IntPtr attr, IntPtr value, IntPtr size, IntPtr prev, IntPtr retSize);
    [DllImport("kernel32.dll")]
    static extern void DeleteProcThreadAttributeList(IntPtr list);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CreateProcessW(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags,
        IntPtr env, string cwd, ref STARTUPINFOEX si, out PROCESS_INFORMATION pi);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern uint ResumeThread(IntPtr h);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool TerminateProcess(IntPtr h, uint code);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateJobObjectW(IntPtr sa, string name);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool SetInformationJobObject(IntPtr job, int infoClass, ref JOBOBJECT_EXTENDED_LIMIT_INFORMATION info, int size);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);

    [StructLayout(LayoutKind.Sequential)]
    struct JOBOBJECT_EXTENDED_LIMIT_INFORMATION {
        public long PerProcessUserTimeLimit, PerJobUserTimeLimit; public uint LimitFlags;
        public UIntPtr MinimumWorkingSetSize, MaximumWorkingSetSize; public uint ActiveProcessLimit;
        public UIntPtr Affinity; public uint PriorityClass, SchedulingClass;
        public ulong ReadOperationCount, WriteOperationCount, OtherOperationCount, ReadTransferCount, WriteTransferCount, OtherTransferCount;
        public UIntPtr ProcessMemoryLimit, JobMemoryLimit, PeakProcessMemoryUsed, PeakJobMemoryUsed;
    }
    static IntPtr _job;

    // A job that kills its processes when this process ends: a hidden run can't outlive its launcher (a stopped
    // runner, a probe left running) unseen.
    static IntPtr Job() {
        lock (_lock) {
            if (_job == IntPtr.Zero) {
                IntPtr job = CreateJobObjectW(IntPtr.Zero, null);
                if (job == IntPtr.Zero) throw new Win32Exception();
                var info = new JOBOBJECT_EXTENDED_LIMIT_INFORMATION { LimitFlags = 0x2000 /* KILL_ON_JOB_CLOSE */ };
                if (!SetInformationJobObject(job, 9 /* ExtendedLimitInformation */, ref info, Marshal.SizeOf(info))) throw new Win32Exception();
                _job = job;
            }
            return _job;
        }
    }

    const uint CREATE_SUSPENDED = 0x4, CREATE_NO_WINDOW = 0x08000000, EXTENDED_STARTUPINFO_PRESENT = 0x80000;
    const int STARTF_USESTDHANDLES = 0x100;
    static readonly IntPtr PROC_THREAD_ATTRIBUTE_HANDLE_LIST = (IntPtr)0x20002;

    // "WinSta0\FlapHidden" (made on first use, opened if another process made it), or null: the user's desktop.
    public static string Desktop() {
        if (Environment.GetEnvironmentVariable("FLAP_SHOW_WINDOWS") == "1") return null;
        lock (_lock) {
            if (_desk == IntPtr.Zero) {
                _desk = CreateDesktopW(DesktopName, IntPtr.Zero, IntPtr.Zero, 0, 0x10000000 /* GENERIC_ALL */, IntPtr.Zero);
                if (_desk == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateDesktop " + DesktopName);
            }
            return "WinSta0\\" + DesktopName;
        }
    }

    // `file args` on the hidden desktop, stdin from NUL, stdout/stderr on the streams returned. Only those three
    // handles are inherited (so one run's pipes never stay open in another run started meanwhile), and the process
    // starts suspended until it is in the job and its Process is open, so its exit code and times can be read
    // however soon it exits.
    public static Process Start(string file, string args, out Stream stdout, out Stream stderr) {
        var sa = new SECURITY_ATTRIBUTES { nLength = Marshal.SizeOf(typeof(SECURITY_ATTRIBUTES)), bInheritHandle = true };
        IntPtr outR, outW, errR, errW;
        if (!CreatePipe(out outR, out outW, ref sa, 0)) throw new Win32Exception();
        if (!CreatePipe(out errR, out errW, ref sa, 0)) throw new Win32Exception();
        SetHandleInformation(outR, 1, 0);
        SetHandleInformation(errR, 1, 0);
        stdout = new FileStream(new SafeFileHandle(outR, true), FileAccess.Read, 4096, false);
        stderr = new FileStream(new SafeFileHandle(errR, true), FileAccess.Read, 4096, false);
        IntPtr nul = CreateFileW("NUL", 0x80000000 /* GENERIC_READ */, 3, ref sa, 3 /* OPEN_EXISTING */, 0, IntPtr.Zero);
        var handles = new IntPtr[] { nul, outW, errW };
        IntPtr list = Marshal.AllocHGlobal(IntPtr.Size * handles.Length);
        Marshal.Copy(handles, 0, list, handles.Length);
        IntPtr size = IntPtr.Zero;
        InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref size);
        IntPtr attrs = Marshal.AllocHGlobal(size);
        bool attrsMade = false;
        try {
            if (!InitializeProcThreadAttributeList(attrs, 1, 0, ref size)) throw new Win32Exception();
            attrsMade = true;
            if (!UpdateProcThreadAttribute(attrs, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST, list,
                    (IntPtr)(IntPtr.Size * handles.Length), IntPtr.Zero, IntPtr.Zero)) throw new Win32Exception();
            var si = new STARTUPINFOEX();
            si.StartupInfo.cb = Marshal.SizeOf(typeof(STARTUPINFOEX));
            si.StartupInfo.lpDesktop = Desktop();
            si.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
            si.StartupInfo.hStdInput = nul; si.StartupInfo.hStdOutput = outW; si.StartupInfo.hStdError = errW;
            si.lpAttributeList = attrs;
            PROCESS_INFORMATION pi;
            if (!CreateProcessW(null, new StringBuilder("\"" + file + "\" " + args), IntPtr.Zero, IntPtr.Zero, true,
                    CREATE_SUSPENDED | CREATE_NO_WINDOW | EXTENDED_STARTUPINFO_PRESENT, IntPtr.Zero, null, ref si, out pi))
                throw new Win32Exception();
            bool ready = false;
            try {
                if (!AssignProcessToJobObject(Job(), pi.hProcess)) throw new Win32Exception();
                Process p = Process.GetProcessById(pi.dwProcessId);
                IntPtr opened = p.Handle;   // (the Process keeps this handle: ExitCode, ExitTime, CPU time)
                ready = true;
                return p;
            } finally {
                if (ready) ResumeThread(pi.hThread); else TerminateProcess(pi.hProcess, 1);
                CloseHandle(pi.hThread);
                CloseHandle(pi.hProcess);
            }
        } finally {
            if (attrsMade) DeleteProcThreadAttributeList(attrs);
            Marshal.FreeHGlobal(attrs);
            Marshal.FreeHGlobal(list);
            CloseHandle(outW); CloseHandle(errW); CloseHandle(nul);
        }
    }
}

public class FlapTestProc {
    public static readonly Regex FailLine = new Regex(@"SCRIPT ERROR|^(USER )?(ERROR|WARNING):");
    public readonly Process Proc;
    public readonly Stopwatch Watch = new Stopwatch();
    readonly StringBuilder _out = new StringBuilder();
    readonly StringBuilder _err = new StringBuilder();
    readonly ConcurrentQueue<string> _lines = new ConcurrentQueue<string>();
    readonly Thread[] _readers;
    volatile string _firstFail;

    // `file args`, started on the hidden desktop (FlapHidden).
    public FlapTestProc(string file, string args) {
        Stream o, e;
        Proc = FlapHidden.Start(file, args, out o, out e);
        Watch.Start();
        _readers = new Thread[] { Reader(o, _out), Reader(e, _err) };
    }

    Thread Reader(Stream s, StringBuilder sb) {
        var t = new Thread(() => {
            using (var r = new StreamReader(s)) { string line; while ((line = r.ReadLine()) != null) Take(sb, line); }
        });
        t.IsBackground = true;
        t.Start();
        return t;
    }

    void Take(StringBuilder sb, string line) {
        lock (sb) sb.Append(line).Append('\n');
        _lines.Enqueue(line);
        if (_firstFail == null && FailLine.IsMatch(line)) _firstFail = line;
    }

    // The first line that fails this run, or null.
    public string FirstFail { get { return _firstFail; } }
    public bool HasExited { get { return Proc.HasExited; } }
    public void Kill() { try { if (!Proc.HasExited) Proc.Kill(); } catch (Exception) {} }
    // Waits for the exit and the last of the output.
    public void Wait() { Proc.WaitForExit(); foreach (var t in _readers) t.Join(); }
    public string Out { get { lock (_out) return _out.ToString(); } }
    public string Err { get { lock (_err) return _err.ToString(); } }
    // The lines (stdout and stderr, as they came) since the last call: probe.ps1 relays them.
    public string[] NewLines() { var a = new System.Collections.Generic.List<string>(); string l; while (_lines.TryDequeue(out l)) a.Add(l); return a.ToArray(); }
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
    # (GPU tests run windowed, on the hidden desktop: headless runs no shaders)
    $mode = if ($Run.Name -like "gpu_test_*") { "" } else { "--headless " }
    return New-Object FlapTestProc $Engine, "--path `"$Root`" $mode--fixed-fps 60 -- --run-test $($Run.Name)$shardArg"
}

# Arguments as one command line (the quoting CommandLineToArgvW undoes).
function Join-FlapArgs([string[]]$Arguments) {
    return (@($Arguments | ForEach-Object {
        if ($_ -ne "" -and $_ -notmatch '[\s"]') { $_ }
        else { '"' + (($_ -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"' }
    }) -join " ")
}

# Runs `exe args` on the hidden desktop (probe.ps1, run.ps1 -Hidden): its output (stdout and stderr) relayed as it
# comes, its exit code in $LASTEXITCODE.
function Invoke-FlapHidden([string]$Exe, [string[]]$Arguments) {
    $p = New-Object FlapTestProc $Exe, (Join-FlapArgs $Arguments)
    while (-not $p.HasExited) {
        $p.NewLines()
        Start-Sleep -Milliseconds 50
    }
    $p.Wait()
    $p.NewLines()
    $global:LASTEXITCODE = $p.Proc.ExitCode
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
