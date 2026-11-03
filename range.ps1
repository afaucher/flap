# range.ps1 - open the combat range (scenes/combat_range.tscn): rockets and seekers against a target bird.
#   .\range.ps1                           # fly it yourself: fire = left mouse / F / RT, switch = Q / RB
#   .\range.ps1 -Bird hawk -Target sparrow
#   .\range.ps1 -Seekers                  # carry four seekers instead of six rockets
#   .\range.ps1 -Demo                     # your bird flies itself and fires (watch it)
#   .\range.ps1 -Match [-Skill pilot] [-Team crow,hawk] [-Enemy falcon,owl,crow]   # you + 2 AI wingmen v 3 AI
param([string]$Bird = "", [string]$Target = "", [switch]$Seekers, [switch]$Demo, [switch]$Match, [string]$Skill = "",
    [string]$Team = "", [string]$Enemy = "")
$a = @("--scene", "res://scenes/combat_range.tscn")
if ($Bird) { $a += @("--bird", $Bird) }
if ($Target) { $a += @("--target", $Target) }
if ($Seekers) { $a += "--seekers" }
if ($Demo) { $a += "--demo" }
if ($Match) { $a += "--match" }
if ($Skill) { $a += @("--skill", $Skill) }
if ($Team) { $a += @("--team", $Team) }
if ($Enemy) { $a += @("--enemy", $Enemy) }
& "$PSScriptRoot\run.ps1" @a
