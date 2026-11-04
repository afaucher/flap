# cliff_section_prompts.ps1 - the Gemini cross-sections of the cliff concept (docs/design/cliff_from_concept.md).
#
#   .\tools\cliff_section_prompts.ps1            # renders the three (Antigravity open; about a minute each)
#   .\tools\cliff_section_prompts.ps1 -Only bay
#
# Each is a vertical slice through the concept's front view (docs/images/edge/concept_cliff_ortho.png), square to its
# face, seen side-on with a square grid, so tools/cliff_section.py can read the face's angles off it. Re-render only if
# the concept changes: the three in docs/images/edge are the targets the scorecard uses.
param([string]$Only = "")
$dir = Join-Path (Split-Path -Parent $PSScriptRoot) "docs\images\edge"
$ref = "Use the reference image at '$dir\concept_cliff_ortho.png': a straight-on front view of a grey, horizontally bedded, heavily jointed limestone cliff with stepped faces, ledges with soil and grass, and an angular talus slope at its foot."
$how = "seen exactly side-on in orthographic projection (no perspective, the camera level and square to the cut), the face looking to the right: the flat plateau on the left, the cliff's profile in the middle, the talus slope and the flat ground in front of it on the right. Draw the cut surface as solid pale rock showing its horizontal bedding planes and thin soft partings, every face, overhang and bed step at its true angle and the ledges and talus in true proportion to the reference: do not make the faces more vertical or more sloping than they are in it. Nothing behind the cut: a plain white background. Overlay a thin grey square grid of equal squares, ten squares up the cliff's full height. Bright, even, high-key daylight, no cast shadows on the cut. No text, no labels, no people, no birds. 16:9."
$cut = "Show the same cliff as a geological cross-section: a vertical slice cut straight through it, perpendicular to its face,"
$prompts = [ordered]@{
    "left"  = "$ref $cut one quarter of the way across the reference from the left (through the stepped blocky faces and the big rounded block), $how"
    "bay"   = "$ref $cut through the dark recessed bay a little right of the reference's middle (the tall shadowed face with the low blocks and ledge in front of it), $how"
    "right" = "$ref $cut four fifths of the way across the reference from the left (through the tall pale fluted face and the talus mound below it), $how"
}
foreach ($k in $prompts.Keys) {
    if ($Only -and $k -ne $Only) { continue }
    & "$PSScriptRoot\render_art.ps1" -Prompt $prompts[$k] -OutFile "$dir\concept_section_$k.png" -Aspect "16:9" -TimeoutSeconds 240
}
