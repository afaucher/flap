# concept_art.ps1 - paints Flap's combat concept art using Antigravity's Imagen engine.
# Can be run from ANY terminal (inside or outside Antigravity IDE).
#
# Usage:
#   .\tools\concept_art.ps1                  # render all missing prompts
#   .\tools\concept_art.ps1 -Only nanite     # render prompts matching "nanite"
#   .\tools\concept_art.ps1 -Force           # re-render existing images
param(
    [string]$Only = "",
    [switch]$Force
)

$outDir = Join-Path $PSScriptRoot "..\docs\images\concepts"
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}
$outDir = (Resolve-Path $outDir).Path

$prompts = [ordered]@{
    "field_snatch"   = "Third-person chase view behind a red-tailed hawk diving at a vole in a forest clearing, late morning light, realistic plumage with a brick-red tail and pale underwings, wings half-folded in a stoop, a crow harassing from the left leaving faint white wingtip vapour trails, sparse tall trunks, soft haze, naturalistic colour, cinematic game screenshot, 16:9"
    "field_steal"    = "Chase-camera game screenshot: an eagle pursuing an osprey that carries a silver fish in its talons between tall pine trunks, the osprey struggling with the weight, both birds leaving faint curved wingtip vapour trails, overcast soft light, realistic feathers, a minimal targeting bracket around the osprey with range readout, 16:9"
    "nanite_crows"   = "Dusk game screenshot, chase camera behind a black crow augmented with nanotechnology, glowing cyan circuit lines along its feather shafts, chasing another nanite crow through dark trees with cyan glowing growths, a tiny rocket with a smoke trail curving toward the target, orange flak bursts, cyan particle wingtip trails, minimal sci-fi HUD with ammo pips and a lead marker, moody purple and teal palette, 16:9"
    "nanite_sheet"   = "Concept art sheet: five nanobot-augmented birds (crow, hawk, falcon, owl, sparrow) in side view, black feathers with glowing cyan circuit lines along the feather shafts, tiny rocket pods under the wings, a hive nest of dark wood with glowing nodes, purple dusk palette, clean game concept style"
    "blood_joust"    = "Epic game screenshot at sunset: a giant gene-edited eagle with a ten-metre wingspan ridden by an armoured human holding a long lance, flying through a red sandstone canyon toward a rival rider on another giant bird, long red and gold banners streaming from the birds' tails, a ring gate with flags ahead, dust and warm backlight, crowd stands carved into the cliff, chase camera, 16:9"
    "blood_arena"    = "Bloodsport arena at sunset: armoured riders on gene-edited giant eagles with ten-metre wings, crowd stands carved into a red canyon, ring gates with red and gold banners, long banners streaming from the birds' tails, dramatic backlight, epic game key art, 16:9"
}

$renderScript = Join-Path $PSScriptRoot "render_art.ps1"

foreach ($name in $prompts.Keys) {
    if ($Only -and $name -notmatch [regex]::Escape($Only)) { continue }
    $file = Join-Path $outDir "$name.png"

    if ((Test-Path $file) -and -not $Force) {
        Write-Host "== $name already exists at $file (use -Force to re-render)" -ForegroundColor Cyan
        continue
    }

    Write-Host "========================================"
    Write-Host "== Rendering concept: $name"
    Write-Host "========================================"
    & "$renderScript" -Prompt $prompts[$name] -OutFile $file -Aspect "16:9" -TimeoutSeconds 120

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to render $name"
        exit $LASTEXITCODE
    }
}
