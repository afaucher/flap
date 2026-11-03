# godot_env.ps1 - locate the Godot 4.7 console binary for this project (ported from ..\cast).
# Order: $env:FLAP_GODOT, then Flap's own copy in build\deps (gitignored: Godot_v4.7-stable_win64.exe and its
# _console.exe), then cast's build deps (..\cast\build\deps), then the copy Hero-Reader's tools/setup.py installed
# next door (..\Hero-Reader\third_party\godot). No machine-wide fallback. Flap's own copy comes first because screen
# recorders such as Nvidia's name a capture after the program's folder: Hero-Reader's showed up as "Hero Reader".
function Resolve-FlapGodot {
    if ($env:FLAP_GODOT -and (Test-Path $env:FLAP_GODOT)) { return $env:FLAP_GODOT }
    # From a git worktree (.claude\worktrees\<name>), look next to the main checkout too.
    $roots = @($PSScriptRoot)
    $common = git -C $PSScriptRoot rev-parse --git-common-dir 2>$null
    if ($common) {
        if (-not [IO.Path]::IsPathRooted($common)) { $common = Join-Path $PSScriptRoot $common }
        $roots += Split-Path ([IO.Path]::GetFullPath($common)) -Parent
    }
    foreach ($root in $roots) {
        foreach ($rel in @("build\deps\Godot_v4.7-stable_win64_console.exe",
                           "..\cast\build\deps\Godot_v4.7-stable_win64_console.exe",
                           "..\Hero-Reader\third_party\godot\Godot_v4.7-stable_win64_console.exe")) {
            $p = Join-Path $root $rel
            if (Test-Path $p) { return (Resolve-Path $p).Path }
        }
    }
    throw "Godot 4.7 not found. Set FLAP_GODOT to Godot_v4.7-stable_win64_console.exe."
}

# Import (or reimport) the project once so class_name caches and .import files exist; stamp when it ran.
function Invoke-FlapImport([string]$Godot) {
    & $Godot --path $PSScriptRoot --headless --import 2>&1 | Out-Null
    $stamp = Join-Path $PSScriptRoot ".godot\flap_imported.stamp"
    if (Test-Path (Split-Path $stamp)) { Set-Content -Path $stamp -Value (Get-Date -Format o) }
}


# Import only when something changed since the last import: a script, scene, asset or test newer than its stamp
# (a pull, a merge, an edit or another session's landing). Without it a new class_name is unknown ("Could not find
# type"). The stamp, not the class cache: the engine leaves the cache alone when no class changed.
function Update-FlapImport([string]$Godot) {
    $since = $null
    foreach ($f in @(".godot\flap_imported.stamp", ".godot\global_script_class_cache.cfg")) {
        $p = Join-Path $PSScriptRoot $f
        if (Test-Path $p) { $since = (Get-Item $p).LastWriteTime; break }
    }
    $stale = $null -eq $since -or -not (Test-Path (Join-Path $PSScriptRoot ".godot\global_script_class_cache.cfg"))
    if (-not $stale) {
        $stale = [bool](Get-ChildItem -Recurse -File -Path (Join-Path $PSScriptRoot "scripts"), (Join-Path $PSScriptRoot "scenes"),
                (Join-Path $PSScriptRoot "assets"), (Join-Path $PSScriptRoot "tools"), (Join-Path $PSScriptRoot "tests") -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -gt $since -and $_.Extension -ne ".import" } | Select-Object -First 1)
    }
    if ($stale) {
        Write-Host "Importing (scripts or assets changed since the last import)..."
        Invoke-FlapImport $Godot
    }
}
