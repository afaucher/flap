# godot_env.ps1 - locate the Godot 4.7 console binary for this project (ported from ..\cast).
# Order: $env:FLAP_GODOT, then the copy Hero-Reader's tools/setup.py installed next door
# (..\Hero-Reader\third_party\godot), then cast's build deps (..\cast\build\deps). No machine-wide fallback.
function Resolve-FlapGodot {
    if ($env:FLAP_GODOT -and (Test-Path $env:FLAP_GODOT)) { return $env:FLAP_GODOT }
    foreach ($rel in @("..\Hero-Reader\third_party\godot\Godot_v4.7-stable_win64_console.exe",
                       "..\cast\build\deps\Godot_v4.7-stable_win64_console.exe")) {
        $p = Join-Path $PSScriptRoot $rel
        if (Test-Path $p) { return (Resolve-Path $p).Path }
    }
    throw "Godot 4.7 not found. Set FLAP_GODOT to Godot_v4.7-stable_win64_console.exe."
}

# Import (or reimport) the project once so class_name caches and .import files exist.
function Invoke-FlapImport([string]$Godot) {
    & $Godot --path $PSScriptRoot --headless --import 2>&1 | Out-Null
}
