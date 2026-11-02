# lab.ps1 - open the bird lab (scenes/bird_lab.tscn): species, poses, take-offs and landings, slow-mo, ghosts.
#   .\lab.ps1                                         # opens on the first pose
#   .\lab.ps1 hawk land_above                         # a species and a scenario (ids in scripts/app/lab_scenarios.gd)
#   .\lab.ps1 hawk land_above -Speed 0.25 -Onion      # slow motion, onion-skin ghosts on
#   .\lab.ps1 -List                                   # list the scenario ids
param(
    [string]$Bird = "",
    [string]$Scenario = "",
    [double]$Speed = 0,
    [switch]$Onion,
    [string]$View = "",
    [switch]$List
)
if ($List) {
    Select-String -Path "$PSScriptRoot\scripts\app\lab_scenarios.gd" -Pattern '"id": "([^"]+)", "label": "([^"]+)"' |
        ForEach-Object { "{0,-14} {1}" -f $_.Matches[0].Groups[1].Value, $_.Matches[0].Groups[2].Value }
    "Birds: crow owl hawk falcon sparrow"
    return
}
$a = @("--scene", "res://scenes/bird_lab.tscn")
if ($Bird) { $a += @("--bird", $Bird) }
if ($Scenario) { $a += @("--scenario", $Scenario) }
if ($Speed -gt 0) { $a += @("--speed", "$Speed") }
if ($Onion) { $a += "--onion" }
if ($View) { $a += @("--view", $View) }
& "$PSScriptRoot\run.ps1" @a
