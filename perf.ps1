# perf.ps1 - profile the game: where each rendered frame's time goes (scripts/app/perf.gd).
#
#   .\perf.ps1                          # crow on autopilot, 3 AI birds, 15 s after a 3 s warm-up
#   .\perf.ps1 -Bird hawk -Ai 6 -Seconds 30 -Out C:\perf\run1
#   .\perf.ps1 -Engine --gpu-profile    # engine options (before --): --gpu-profile adds the GPU by render pass
#   .\perf.ps1 -Hidden                  # on the hidden desktop (test_lib.ps1): no window on screen, no focus taken
#                                       # (vsync still paces it, as on screen)
#
# Runs the game windowed (rendering is part of the cost) and writes <Out>.csv (one row per frame) and <Out>.txt
# (the summary). While it runs, samples the whole machine's CPU load and counts other Godot processes, so a
# report taken while builds and tests run elsewhere says so: background load shows as uneven frames that no
# section of our code accounts for.
param([string]$Bird = "crow", [int]$Ai = 3, [double]$Seconds = 15, [string]$Out = "", [string[]]$Extra = @(), [string[]]$Engine = @(), [switch]$Hidden)
. "$PSScriptRoot\godot_env.ps1"
$godot = Resolve-FlapGodot
Update-FlapImport $godot
if ($Out -eq "") { $Out = Join-Path $PSScriptRoot ("test_logs\perf_" + (Get-Date -Format "yyyyMMdd_HHmmss")) }
New-Item -ItemType Directory -Force -Path (Split-Path $Out) | Out-Null
$others = @(Get-Process | Where-Object { $_.ProcessName -like "Godot*" }).Count
$load = Start-Job -ScriptBlock {
    param($n)
    (Get-Counter '\Processor(_Total)\% Processor Time' -SampleInterval 1 -MaxSamples $n).CounterSamples | ForEach-Object { $_.CookedValue }
} -ArgumentList ([int]($Seconds + 3))
$a = @("--path", $PSScriptRoot) + $Engine + @("--", "--bird", $Bird, "--ai", "$Ai", "--autopilot", "--perf", "$Seconds", "--perf-out", $Out) + $Extra
if ($Hidden) { . "$PSScriptRoot\test_lib.ps1"; Invoke-FlapHidden (Get-FlapEngine $godot) $a | Out-Null }
else { & $godot @a | Out-Null }
$samples = @(Receive-Job $load -Wait -AutoRemoveJob)
$mean = if ($samples.Count) { ($samples | Measure-Object -Average).Average } else { 0 }
$max = if ($samples.Count) { ($samples | Measure-Object -Maximum).Maximum } else { 0 }
$note = "`nMachine while profiling: CPU load mean {0:N0} %, max {1:N0} % ({2} samples); {3} other Godot process(es) running at the start." -f $mean, $max, $samples.Count, $others
Add-Content -Path "$Out.txt" -Value $note
Get-Content "$Out.txt"
