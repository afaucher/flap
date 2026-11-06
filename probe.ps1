# probe.ps1 - run a diagnostic (tests\probe_*.gd, or any test) by hand, out of the way: it renders on the real GPU
# but on a desktop of its own (test_lib.ps1, FlapHidden), so its window is never on screen and never takes focus.
# Its output comes back as it runs; the exit code is the run's. Extra args go to the test, e.g.
#   .\probe.ps1 probe_timber --out C:\shots\timber.png --warm
#   .\probe.ps1 probe_grade --look golden --out C:\shots\grade
#   .\probe.ps1 -Headless probe_cliff_plan --out C:\cliff\plan     # no renderer needed
#   .\probe.ps1 -Engine --gpu-profile probe_load_time               # an engine option (before --); repeat for more
# As `Godot --path . -- --run-test <name> ...` (no --fixed-fps; add it with -Engine). FLAP_SHOW_WINDOWS=1 shows it;
# it's muted (test_lib.ps1), FLAP_SOUND=1 to hear it.
# (No param block: the test's own --options would bind to it.)
$Headless = $false; $Engine = @(); $rest = @($args | ForEach-Object { $_ })
while ($rest.Count -gt 0 -and ($rest[0] -eq "-Headless" -or ($rest[0] -eq "-Engine" -and $rest.Count -gt 1))) {
    if ($rest[0] -eq "-Headless") { $Headless = $true; $rest = @($rest | Select-Object -Skip 1) }
    else { $Engine += $rest[1]; $rest = @($rest | Select-Object -Skip 2) }
}
$Name = if ($rest.Count -gt 0) { $rest[0] } else { "" }
if (-not $Name) { Write-Host "Usage: .\probe.ps1 [-Headless] [-Engine <opts>] <test name> [test args]" -ForegroundColor Yellow; exit 1 }
. "$PSScriptRoot\godot_env.ps1"
. "$PSScriptRoot\test_lib.ps1"
$godot = Resolve-FlapGodot
Update-FlapImport $godot
$a = @("--path", $PSScriptRoot)
if ($Headless) { $a += "--headless" }
$a += $Engine
$a += @("--", "--run-test", $Name)
$a += @($rest | Select-Object -Skip 1)
Invoke-FlapHidden (Get-FlapEngine $godot) $a
exit $LASTEXITCODE
