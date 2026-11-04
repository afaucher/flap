# run.ps1 - play the game (windowed). Extra args go to the game, e.g.
#   .\run.ps1 --bird falcon
#   .\run.ps1 --seed 7 --shot C:\shots\arena.png     # save a screenshot after --shot-after seconds (default 2) and quit
# A run that saves a picture and quits (--shot, --sheet), or one given -Hidden, runs on the hidden desktop
# (test_lib.ps1, FlapHidden): it renders as usual but never shows a window or takes focus.
. "$PSScriptRoot\godot_env.ps1"
$godot = Resolve-FlapGodot
Update-FlapImport $godot
$game = @($args | Where-Object { $_ -ne "-Hidden" })
if ($args -contains "-Hidden" -or $game -contains "--shot" -or $game -contains "--sheet") {
    . "$PSScriptRoot\test_lib.ps1"
    Invoke-FlapHidden (Get-FlapEngine $godot) (@("--path", $PSScriptRoot, "--") + $game)
    exit $LASTEXITCODE
}
& $godot --path $PSScriptRoot -- @game
exit $LASTEXITCODE
