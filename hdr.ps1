# hdr.ps1 - play the game with HDR display output (Windows HDR on, an HDR monitor). Godot 4.7's Vulkan renderer
# reports no HDR support on Windows; Direct3D 12 does. Extra args go to the game, as with run.ps1, e.g.
#   .\hdr.ps1 --bird falcon
#   .\hdr.ps1 --scene res://scenes/forest_preview.tscn     # Space: next view
# F4 toggles HDR in game, to compare.
. "$PSScriptRoot\godot_env.ps1"
$godot = Resolve-FlapGodot
& $godot --path $PSScriptRoot --rendering-driver d3d12 -- @args
exit $LASTEXITCODE
