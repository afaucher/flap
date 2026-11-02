# range.ps1 - open the combat range (scenes/combat_range.tscn): rockets and seekers against a target bird.
#   .\range.ps1                           # fly it yourself: fire = left mouse / F / RT, switch = Q / RB
#   .\range.ps1 -Bird hawk -Target sparrow
#   .\range.ps1 -Seekers                  # start with seekers selected
#   .\range.ps1 -Demo                     # your bird flies itself and fires (watch it)
#   .\range.ps1 -Loadout rockets,rockets  # the pods each side of the rider (left,right): rockets (3) or seekers (2)
param([string]$Bird = "", [string]$Target = "", [switch]$Seekers, [switch]$Demo, [string]$Loadout = "")
$a = @("--scene", "res://scenes/combat_range.tscn")
if ($Bird) { $a += @("--bird", $Bird) }
if ($Target) { $a += @("--target", $Target) }
if ($Seekers) { $a += "--seekers" }
if ($Demo) { $a += "--demo" }
if ($Loadout) { $a += @("--loadout", $Loadout) }
& "$PSScriptRoot\run.ps1" @a
