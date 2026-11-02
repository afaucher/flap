# mutation_check.ps1 - replay past bugs and prove the tests still catch them.
#
#   .\mutation_check.ps1                                 # every entry in tests\regressions\mutations.json
#   .\mutation_check.ps1 -Only fold-elbow-raised,bom-in-doc
#   .\mutation_check.ps1 -Keep                           # leave the scratch worktree for inspection
#
# Each entry reintroduces one bug we have had (exact find/replace edits; an empty find prepends) in a scratch
# git worktree made from the current working tree (committed or not, untracked files included), then runs only
# the tests it names. At least one of them must FAIL:
#   KILLED    a named test failed: that bug would be caught
#   SURVIVED  every named test passed: a gap -- strengthen a test until it fails
#   STALE     a find string no longer matches exactly once: update the entry to today's code
# A bug fixed for good gets an entry here, so the test that pins it is proven able to fail.
param([string[]]$Only = @(), [switch]$Keep)
$ErrorActionPreference = "Continue"   # (git writes progress to stderr; check exit codes instead)
$root = $PSScriptRoot
$enc = New-Object Text.UTF8Encoding $false
$parsed = ConvertFrom-Json (Get-Content -Raw -Encoding UTF8 (Join-Path $root "tests\regressions\mutations.json"))
$muts = @($parsed | ForEach-Object { $_ })   # (PowerShell 5.1 hands a top-level JSON array back as one item)
if ($Only.Count) { $muts = @($muts | Where-Object { $Only -contains $_.id }) }
if ($muts.Count -eq 0) { Write-Host "No mutations selected." -ForegroundColor Yellow; exit 1 }

# Snapshot the working tree as a commit through a throwaway index (the real index is untouched).
$idx = Join-Path ([IO.Path]::GetTempPath()) ("flap-mut-index-" + [guid]::NewGuid())
$env:GIT_INDEX_FILE = $idx
try {
    git -C $root read-tree HEAD
    git -C $root add -A 2>$null
    $tree = git -C $root write-tree
} finally {
    Remove-Item Env:GIT_INDEX_FILE
    Remove-Item $idx -ErrorAction SilentlyContinue
}
$commit = git -C $root commit-tree $tree -p HEAD -m "mutation check snapshot"
$wt = Join-Path ([IO.Path]::GetTempPath()) ("flap-mutants-" + $commit.Substring(0, 10))
git -C $root worktree add --detach $wt $commit 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "Could not create the scratch worktree." -ForegroundColor Red; exit 1 }
Write-Host "Scratch worktree: $wt" -ForegroundColor DarkGray

function Invoke-Tests([string[]]$Names, [switch]$Import) {
    $a = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $wt "test_runner.ps1"), "-TestName", ($Names -join ","))
    if (-not $Import) { $a += "-NoImport" }
    $out = & powershell @a 2>&1 | Out-String
    return [PSCustomObject]@{ Ok = ($LASTEXITCODE -eq 0); Out = $out }
}

$results = @()
try {
    # Baseline: the named tests must pass on the unmutated snapshot, or a failure proves nothing.
    $all = @($muts | ForEach-Object { $_.tests } | Sort-Object -Unique)
    $base = Invoke-Tests $all -Import
    if (-not $base.Ok) {
        Write-Host $base.Out
        Write-Host "Baseline failed: fix the suite before checking mutations." -ForegroundColor Red
        exit 1
    }
    foreach ($m in $muts) {
        git -C $wt checkout -- . 2>&1 | Out-Null
        $stale = ""
        foreach ($e in $m.edits) {
            $path = Join-Path $wt $e.file
            if (-not (Test-Path $path)) { $stale = "$($e.file) is gone"; break }
            $text = [IO.File]::ReadAllText($path)
            if ($e.find -eq "") {
                $text = $e.replace + $text
            } else {
                $n = ([regex]::Matches($text, [regex]::Escape($e.find))).Count
                if ($n -ne 1) { $stale = "find matches $n times in $($e.file)"; break }
                $text = $text.Replace($e.find, $e.replace)
            }
            [IO.File]::WriteAllText($path, $text, $enc)
        }
        if ($stale) {
            $results += [PSCustomObject]@{ Id = $m.id; Result = "STALE"; Detail = $stale }
        } else {
            $r = Invoke-Tests @($m.tests)
            $failed = @(($r.Out -split "`n") | Where-Object { $_ -match "^\s*FAIL\s+(\S+)" } | ForEach-Object { $Matches[1] })
            if ($r.Ok) { $results += [PSCustomObject]@{ Id = $m.id; Result = "SURVIVED"; Detail = "passed: " + ($m.tests -join ", ") } }
            else { $results += [PSCustomObject]@{ Id = $m.id; Result = "KILLED"; Detail = "failed: " + ($failed -join ", ") } }
        }
        $last = $results[-1]
        $color = @{ KILLED = "Green"; SURVIVED = "Red"; STALE = "Yellow" }[$last.Result]
        Write-Host ("  {0,-9} {1,-30} {2}" -f $last.Result, $last.Id, $last.Detail) -ForegroundColor $color
    }
} finally {
    if (-not $Keep) { git -C $root worktree remove --force $wt 2>&1 | Out-Null }
}

$bad = @($results | Where-Object { $_.Result -ne "KILLED" })
$killed = $results.Count - $bad.Count
if ($bad.Count) { Write-Host "$killed of $($results.Count) bugs caught; $($bad.Count) not: $(($bad | ForEach-Object { $_.Id }) -join ', ')" -ForegroundColor Red; exit 1 }
Write-Host "All $($results.Count) replayed bugs are caught by the tests." -ForegroundColor Green
exit 0
