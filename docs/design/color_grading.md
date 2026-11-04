# Colour grading

How Flap's look is graded, how we compare it with the concept art, and what's built. Started 2026-11-03 to find
why the game reads cooler and flatter than `docs/images/concepts/r4_aces_outpost.jpg`.

## The pipeline (and where each part of a look belongs)

Godot renders scene-referred, linear HDR light, then applies, in order: depth of field, auto exposure, glow,
**exposure -> tonemapper**, then the **adjustments** (brightness, contrast, saturation, and the colour
correction LUT). So everything in `adjustment_*` happens after the tonemapper, in display space, 0-1.

The practice we follow (Unreal's, Hable's, Frostbite's; sources below):

1. **Most of a look is lighting**: sun colour, angle and energy; sky (Rayleigh blue v Mie haze); ambient colour
   and energy; fog colour, density and sun scatter; volumetric fog (the shafts); glow; exposure. White balance
   (warm or cool light) belongs here, not in the grade.
2. **The tonemapper** rolls the highlights off. We use **AgX**: it keeps hues as colours brighten (a bright orange
   stays orange instead of skewing yellow, as ACES and Filmic do), and it's the one that works with Godot 4.7's
   HDR output. Its contrast is `tonemap_agx_contrast` (better than `adjustment_contrast`, which clips).
3. **A mild grade on top**: a per-channel tone curve (a split-tone: shadows one way, highlights another), with
   saturation and contrast. Keep it gentle. Godot's LUT is SDR-only, so it doesn't apply under HDR output, and
   it can't recover what the tonemapper has already clipped. Don't grade to fix bad lighting.

## The looks (`ForestLight.LOOKS`)

Each look is a set of property overrides on the afternoon (`sun.*`, `sky.*`, `env.*`, with `prop:x` for one
component of a vector) plus an optional `curve`: [level, colour] stops of a `GradientTexture1D` per-channel LUT.
Switching to a look first resets everything every look touches back to the afternoon, so nothing leaks from one
to the next (`tests/test_forest_light.gd`).

- `afternoon`: ForestLight's own light (the default until 2026-11-03). A sun 30 deg up, AgX, a mild warm haze.
- `golden`: **the default**, toward the concept art. The sun lower (20 deg) and more orange, a hazy Mie sky, warm lit haze (the
  shafts), exposure 1.2, warm split-tone (brown shadows, cream-gold highlights).
- `misty_morning`: a pale sun from the other side, low; cool blue mist through the wood; soft contrast; cool
  shadows, warm-white highlights.
- `overcast`: no sun to speak of (0.6 energy, 8 deg wide), a white sky, flat even light, muted colour.

Pick one with `--look <name>` (the game, the range, the menu), or press **F6** in the game or the range to
step through them. The menu's backdrop uses the same light as the game, with its sun turned so the birds on
the rail are lit.

## How we compare a look with the reference

1. **Fixed views**: `tests/probe_grade.gd` renders the pine wood (seed 7) from three cameras at 14 m: `away`
   (the sun behind, everything front-lit), `across`, and `toward` (into the sun: backlit haze and shafts, like
   the concept). Windowed:
   `.\probe.ps1 probe_grade --look golden --out <prefix>`
   `--set '{"env.tonemap_exposure": 1.3}'` tries a value without editing code.
2. **Scopes**: `python tools/grade_scopes.py <out.jpg> "concept=<jpg>" "golden=<png>" ...` puts each image in a
   row with a colourist's charts:
   - **RGB histogram**: where the tones sit. Clipping shows as a spike at the right, crushed blacks at the left.
   - **RGB parade**: a waveform per channel, with brightness up the y axis for each column of the image. The
     red channel riding above the blue in the highlights means the highlights are warm.
   - **Vectorscope**: hue round the circle and saturation out from the centre, with the 75% R/Y/G/C/B/M targets
     and the skin-tone line. A warm image clusters along the line between R and Y; further out is more
     saturated.
   - **Tone chips**: the mean colour of the shadows, mids and highlights (thirds of the tones), shown at their
     real level and normalised so the hue reads, with their warmth (R - B) and saturation.
3. **Numbers**: `python tools/grade_stats.py <reference> <ours> ...` prints luma percentiles and spread,
   warmth and saturation per tone band, the top quarter's colour and local contrast.
4. **Readability**: check that the HUD's warm enemy and teal teammate marks stay apart from the scene's hues,
   and that nothing in play is lost to crushed shadows or blown highlights.

## The gap (measured 2026-11-03)

| | luma p5 / p50 / p95 | spread | warmth R-B shadows / mids / highs | saturation mids |
|---|---|---|---|---|
| concept | 0.11 / 0.33 / 0.72 | 0.20 | +0.12 / +0.21 / +0.29 | 0.52 |
| afternoon, sun behind | 0.08 / 0.28 / 0.46 | 0.13 | +0.10 / +0.24 / +0.18 | 0.67 |
| afternoon, into the sun | 0.03 / 0.35 / 0.67 | 0.19 | +0.10 / +0.30 / +0.21 | 0.66 |
| golden, sun behind | 0.07 / 0.28 / 0.49 | 0.13 | +0.15 / +0.28 / +0.32 | 0.72 |
| golden, into the sun | 0.04 / 0.45 / 0.83 | 0.23 | +0.19 / +0.37 / +0.33 | 0.63 |
| menu, before (old grey light) | 0.11 / 0.34 / 0.85 | | +0.04 / +0.01 / +0.00 | 0.09 |

What the charts showed:

- **The concept's warmth grows into the highlights** (+0.12 -> +0.29). The afternoon's mids are already warm
  (the needle litter), but its highlights are cooler than its mids. That's the sky: a blue Rayleigh sky over a
  pale grey horizon is the biggest, brightest area in many shots, and it fills the fog and ambient light too.
  `golden` fixes the highlights' warmth (+0.32).
- **Our highlights are compressed.** Front-lit, the brightest 5% sits at 0.46-0.49 against the concept's 0.72,
  so it reads flat. Exposure alone over-brightens the into-the-sun view (golden p50 0.45 v 0.33). The next lever
  is AgX's own contrast and white point (`tonemap_agx_contrast`, `tonemap_agx_white`), not more exposure.
- **We're more saturated than the concept in the mids** (0.63-0.72 v 0.52). Its warmth comes from the light's
  colour, not from saturation.
- **The menu used the old grey test-arena light** (Game.add_environment), which was neutral, low in saturation
  and blue-skied. It now uses ForestLight.
- **Not grading**: the flat ground plane ends at a hard grey horizon line where the concept has wood to the
  horizon, and the concept's canopy fills its sky. Both make our frames cooler and emptier than any grade can
  fix.

Charts: `docs/images/grading/scopes_into_sun.jpg`, `scopes_sun_behind.jpg`, `scopes_menu.jpg`; the looks from
the three views: `looks_views.jpg`; the menu in each look: `menu_looks.jpg`.

## Next steps

- Tune each look's contrast with `tonemap_agx_contrast` / `tonemap_agx_white` in place of `adjustment_contrast`,
  to lift the front-lit highlights toward the concept's p95 0.7 without blowing out the into-the-sun view.
- Bring saturation down in `golden`'s mids toward 0.52, keeping the warmth in the light.
- A 3D LUT per look, graded in Resolve or Photoshop: take a neutral screenshot with Godot's neutral 33^3 LUT
  template, grade both together, and import the LUT as a Texture3D (set the slice counts). This replaces the
  1D curve where a look needs hue-specific moves, such as greens toward olive.
- Blend between looks (a time of day, or a match's weather): tween the numeric values, and lerp two LUT images
  on the CPU while the switch runs.
- A look-dev rig in the arena: a colour checker, a grey ball and a chrome ball, a red and a teal marker, and the
  HUD, captured in every look as a screenshot regression.
- The horizon: wood to the edge (a far tree ring, or impostor cards), and more canopy overhead.

## Sources

- Unreal, colour grading and the filmic tonemapper (grading before the tonemapper, the LUT after):
  https://dev.epicgames.com/documentation/en-us/unreal-engine/color-grading-and-the-filmic-tonemapper-in-unreal-engine
- Unreal, LUTs: https://dev.epicgames.com/documentation/en-us/unreal-engine/using-lookup-tables-for-color-grading-in-unreal-engine
- Unity post-processing colour grading (LDR v HDR grading): https://docs.unity3d.com/Packages/com.unity.postprocessing@3.4/manual/Color-Grading.html
- John Hable, minimal colour grading tools (the order of operations): http://filmicworlds.com/blog/minimal-color-grading-tools/
- Hable, Uncharted 2 HDR lighting (GDC 2010): https://gdcvault.com/play/1012351/Uncharted-2-HDR
- Frostbite, HDR colour grading and display (Alex Fry, GDC 2017): https://www.ea.com/frostbite/news/high-dynamic-range-color-grading-and-display-in-frostbite
- AgX in Godot (the proposal and the hue-shift discussion): https://github.com/godotengine/godot-proposals/discussions/7545
- Godot, Environment and post-processing (order, LUTs): https://docs.godotengine.org/en/latest/tutorials/3d/environment_and_post_processing.html
- Godot, Environment class (tonemappers, AgX contrast and white): https://docs.godotengine.org/en/latest/classes/class_environment.html
- Godot 4.7 HDR output: https://godotengine.org/article/hdr-output-arrives-in-godot-4-7/
- Reading scopes (waveform, parade, histogram, vectorscope): https://photography.tutsplus.com/tutorials/how-to-read-scopes-in-resolve-waveform-parade-histogram-vectorscope--cms-41868
- GDC 2019, "LUTious Color: Grading for Games" (Izzy Gramp): https://www.gdcvault.com/play/1026004/LUTious-Color-Grading-for
- Factorio's daytime LUT blending: https://lua-api.factorio.com/latest/types/DaytimeColorLookupTable.html
