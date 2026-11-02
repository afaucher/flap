# concept_art.ps1 - ask Antigravity's agent to paint Flap's combat concept art (docs/design/combat_concepts.html).
# Run it from a terminal INSIDE Antigravity: its agent bridge (agentapi) needs the session address and token that
# Antigravity sets only in its own terminals. Each prompt starts one Antigravity conversation that should save a
# PNG to docs\images\concepts\<name>.png; check the conversations in Antigravity for progress.
#   .\tools\concept_art.ps1                  # every prompt
#   .\tools\concept_art.ps1 -Only nanite     # just the ones whose name contains "nanite"
#   .\tools\concept_art.ps1 -Model flash     # a cheaper model (flash_lite | flash | pro)
param([string]$Only = "", [string]$Model = "pro")

$agentapi = Join-Path $env:USERPROFILE ".gemini\antigravity\bin\agentapi.bat"
if (-not $env:ANTIGRAVITY_LS_ADDRESS) {
    Write-Host "Run this from a terminal inside Antigravity (ANTIGRAVITY_LS_ADDRESS isn't set here)." -ForegroundColor Yellow
    exit 1
}
$outDir = Join-Path $PSScriptRoot "..\docs\images\concepts" | Resolve-Path -ErrorAction SilentlyContinue
if (-not $outDir) { New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot "..\docs\images\concepts") | Out-Null; $outDir = Resolve-Path (Join-Path $PSScriptRoot "..\docs\images\concepts") }

$prompts = [ordered]@{
    "field_snatch"   = "Third-person chase view behind a red-tailed hawk diving at a vole in a forest clearing, late morning light, realistic plumage with a brick-red tail and pale underwings, wings half-folded in a stoop, a crow harassing from the left leaving faint white wingtip vapour trails, sparse tall trunks, soft haze, naturalistic colour, cinematic game screenshot, 16:9"
    "field_steal"    = "Chase-camera game screenshot: an eagle pursuing an osprey that carries a silver fish in its talons between tall pine trunks, the osprey struggling with the weight, both birds leaving faint curved wingtip vapour trails, overcast soft light, realistic feathers, a minimal targeting bracket around the osprey with range readout, 16:9"
    "nanite_crows"   = "Dusk game screenshot, chase camera behind a black crow augmented with nanotechnology, glowing cyan circuit lines along its feather shafts, chasing another nanite crow through dark trees with cyan glowing growths, a tiny rocket with a smoke trail curving toward the target, orange flak bursts, cyan particle wingtip trails, minimal sci-fi HUD with ammo pips and a lead marker, moody purple and teal palette, 16:9"
    "nanite_sheet"   = "Concept art sheet: five nanobot-augmented birds (crow, hawk, falcon, owl, sparrow) in side view, black feathers with glowing cyan circuit lines along the feather shafts, tiny rocket pods under the wings, a hive nest of dark wood with glowing nodes, purple dusk palette, clean game concept style"
    "blood_joust"    = "Epic game screenshot at sunset: a giant gene-edited eagle with a ten-metre wingspan ridden by an armoured human holding a long lance, flying through a red sandstone canyon toward a rival rider on another giant bird, long red and gold banners streaming from the birds' tails, a ring gate with flags ahead, dust and warm backlight, crowd stands carved into the cliff, chase camera, 16:9"
    "blood_arena"    = "Bloodsport arena at sunset: armoured riders on gene-edited giant eagles with ten-metre wings, crowd stands carved into a red canyon, ring gates with red and gold banners, long banners streaming from the birds' tails, dramatic backlight, epic game key art, 16:9"
}

foreach ($name in $prompts.Keys) {
    if ($Only -and $name -notmatch [regex]::Escape($Only)) { continue }
    $file = Join-Path $outDir "$name.png"
    $ask = "Generate one image and save it as a PNG at exactly this path: $file . Image: $($prompts[$name]). Don't change any other files. When it's saved, reply with the path."
    Write-Host "== $name -> $file"
    & $agentapi new-conversation "--model=$Model" "--title=Flap concept: $name" $ask
}
