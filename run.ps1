# run.ps1 - play the game (windowed). Extra args go to the game, e.g.
#   .\run.ps1 --bird falcon
#   .\run.ps1 --seed 7 --shot C:\shots\arena.png     # save a screenshot after --shot-after seconds (default 2) and quit
. "$PSScriptRoot\godot_env.ps1"
$godot = Resolve-FlapGodot
& $godot --path $PSScriptRoot -- @args
exit $LASTEXITCODE
