# cliff_measure.ps1 - measure the escarpment against its concept, in one go (docs/design/cliff_from_concept.md).
#
#   .\tools\cliff_measure.ps1 [-Out test_logs\cliff] [-Seed 7]
#
# 1. probe_cliff_plan (headless): our cliff's exact height field, from above.
# 2. cliff_segment: the concept's plan picture, zoned by its colours (concept_plan_segmented.jpg), and ours from the
#    heights (flat / face / talus by slope), in the same 120 x 40 m frame.
# 3. cliff_shapes: the edges between the zones and the ledges, typed and measured, for both.
# 4. cliff_section: the concept's three Gemini cross-sections (concept_section_*.png) and three cuts through ours at
#    the same places along the frame.
# 5. cliff_score: the scorecard (score.md), concept against ours, with what each row can be trusted for.
param(
    [string]$Out = "test_logs\cliff",
    [int]$Seed = 7
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
. "$root\godot_env.ps1"
$godot = Resolve-FlapGodot
Update-FlapImport $godot
$out = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Out)
New-Item -ItemType Directory -Force "$out\plan", "$out\zones", "$out\shapes", "$out\sections" | Out-Null
$img = "$root\docs\images\edge"

& $godot --path $root --headless -- --run-test probe_cliff_plan --out "$out\plan" --seed $Seed 2>&1 | Select-String "ERROR|SCRIPT" | ForEach-Object { Write-Host $_ }
if (-not (Test-Path "$out\plan\plan.json")) { Write-Error "probe_cliff_plan wrote no plan.json"; exit 1 }

python "$root\tools\cliff_segment.py" concept "$img\concept_plan_segmented.jpg" "$out\zones" | Out-Null
python "$root\tools\cliff_segment.py" model "$out\plan" "$out\zones" | Out-Null
python "$root\tools\cliff_shapes.py" "$out\shapes" "concept=$img\concept_plan_segmented.jpg" "model=$out\plan" | Out-Null
# (the cuts: the concept's left quarter, the bay right of the middle, four fifths across; ours at the same places)
python "$root\tools\cliff_section.py" "$out\sections" `
    "concept_left=$img\concept_section_left.png" "concept_bay=$img\concept_section_bay.png" "concept_right=$img\concept_section_right.png" `
    "ours_left=plan:$out\plan@-30" "ours_bay=plan:$out\plan@8" "ours_right=plan:$out\plan@36" | Out-Null
python "$root\tools\cliff_score.py" $out
Write-Host ""
Write-Host "Pictures: $out\zones, $out\shapes\shapes.png, $out\sections\*_profile.png; scorecard: $out\score.md"
