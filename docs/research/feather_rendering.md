# Feather rendering: research notes

How feathers are rendered in games and film, which visual effects matter, and what fits Flap. Flap draws about 120 feather instances per bird from one shared mesh (`BirdRig`), so the question is mostly what goes in that mesh's shader.

## How feathers are rendered

| Approach | Where it's used | Cost | Notes |
|---|---|---|---|
| **Feather cards**: textured quads, alpha-tested or alpha-to-coverage | Games: wing and tail feathers, often body feathers too | low | The standard real-time approach. The texture carries the shaft, vane and pattern, and the shader adds the lighting effects. Card cutouts give the art control of the silhouette at hair-card-like cost [UE-FUR]. |
| **Small feather cards over the body** (Falcon Age) | Games: contour feathers | low–medium | Treated "like grass or vegetation". A vertex shader flutters each feather relative to its own normal and tangent, never in world space, because the mesh is skinned. Longer feathers move more, and per-feather timing is stored in vertex colour [FALCON]. |
| **Shells and fins** (stacked translucent layers) | Games: fur, occasionally down | high (overdraw) | "Very few games use fins and shells because the overdraw is so great" [UE-FUR]. |
| **Barb-level geometry with a hair BSDF** (Marschner) | Film and research | very high | Barbs are modelled as curves with a hair scattering model. Research argues barb curves alone miss barbule-scale effects that still show at a distance [UNIZAR-24][PATENT-BTF]. |
| **Substructure and BTF models** | Research | very high | Barbs as elliptical cylinders with a medulla, barbules as smaller cylinders, including masking [UNIZAR-24]. Alternatively a 5D BTF that captures fine shadowing and speculars [PATENT-BTF]. A 2026 *ACM Transactions on Graphics* paper claims real-time rendering from a single photo; I haven't verified the details. |
| **Wave-optics iridescence** | Research, film | very high | Barbule reflection is simulated with wave optics into a spatially varying BRDF [IRID-NSF]. The SIGGRAPH 2022 rock-dove paper folds this into a microfacet-like BSDF with no precomputation [DOVE]. The code is public (FeatherLab). |

**Do people use shaders?** Yes. Real-time work puts the feather's structure into a texture on a card and its optical effects into the shader: an anisotropic highlight, translucency, rim sheen and sometimes thin-film iridescence. Geometry stays at the card level. Film and research model the barbs and barbules themselves.

## The visual effects of feathers (and their causes)

1. **Anisotropic sheen.** The barbs lie parallel across each vane, so highlights stretch across the feather, as on hair. In the patent's words, the specular is "anisotropic due to the parallel barbs", and the vane's UV directions are aligned to the barbs [PATENT-GEN]. This is strongest on dark, glossy plumage such as a crow's.
2. **Structural iridescence.** Colour that shifts with viewing angle: crow and starling purple-green, pigeon necks, peacocks. It comes from thin-film interference in the barbule nanostructure, not from pigment [IRID-NSF][DOVE]. The cheap version is a single-layer thin-film term (layer index and thickness against viewing angle) [PEACOCK]. A subtler effect is a glittery, sparkly variation from one barbule to the next.
3. **Translucency when backlit.** Light comes through the vanes, the shaft shows as a dark line, and the outer vane glows. How much light passes depends on feather thickness, pigment density and colour, and the light's angle. Black (melanin) blocks far more than pale feathers [BIRDING]. DreamWorks added feather translucency for *Kung Fu Panda 2*, where it became a signature of Lord Shen's look [DW].
4. **Soft edges and velvet.** Body and down feathers have a soft, broken silhouette and a velvety rim sheen. Owls look notably matte and soft. Without some scattering or soft term a feather reads as hard plastic [OCTANE, low authority].
5. **Layering and self-shadowing.** Overlapping rows (coverts over flight feathers, scapulars over the wing root) cast soft contact shadows. That's where much of the "stacked feathers" read comes from.
6. **Pattern and shaft.** The light rachis (shaft) line, barring and spots, pale or dark edges, and notches. Feathers differ in barb style by feather type [DW-SYS]. Film pipelines groom by body region (scapulars, coverts, flight feathers) [PIXAR].
7. **Silhouette details.** Emarginated, slotted tips; ragged and worn edges; gaps where feathers separate in slow flight.
8. **Motion.** Flutter in wind and airflow. Tips lag and flex while the base stays fixed [FALCON].

## What fits Flap

Flap already has the pieces this needs:
- one feather mesh in a `MultiMesh` per bird
- per-instance colour
- each feather's kind
- the wing's flight state

So one custom feather shader can do most of it without texture assets.

| Effect | Implementation in Godot 4.7 | Cost |
|---|---|---|
| Shaft, vane, barring, notch, soft edge | Procedural, from the feather's UV in the fragment shader. The feather kind and per-species pattern go in per-instance `INSTANCE_CUSTOM` data. Soft edges use alpha-to-coverage (`alpha_antialiasing_mode`) instead of hard alpha scissor. | low |
| Anisotropic sheen | A Kajiya-Kay style lobe (as for hair) with its tangent along the barbs, angled off the shaft. `StandardMaterial3D` also has `anisotropy` with a flow map. | low |
| Backlit translucency | A transmission and back-light term scaled by pigment darkness: pale feathers glow, black ones barely. Godot's `backlight` property does a simple version. | low |
| Iridescence (crow; a starling or pigeon later) | A thin-film hue ramp by viewing angle, masked to the species. | low |
| Velvet and rim on the body and owl | A fresnel rim or sheen lobe (Godot's `rim`). | low |
| Layer shadows | Darken each feather toward its base (it sits under the row above), plus SSAO. | low |
| Flutter | Vertex shader, along each feather's own normal and tangent, scaled by distance from the base and airspeed [FALCON]. | low |
| Barbule-level or wave-optics models | Not for this project. | — |

**Order.** A procedural vane and soft edge first (biggest visual jump), then the anisotropic sheen and backlight, then flutter, then crow iridescence.

## As built (scripts/bird/feather.gdshader). Parked.

**Status:** parked. Side by side, the flat-colour feathers looked better than this first shader pass, so the game uses plain feathers (`BirdRig.plain_feathers = true`). The shader stays in the repo to come back to. Try it with `--feather-shader` in the rig gallery, or by setting `plain_feathers` false.

One spatial shader runs on both feather MultiMeshes:
- `UV.x` runs -1..1 across the vane, and `UV.y` 0..1 base to tip.
- Each instance carries its kind and a seed in `INSTANCE_CUSTOM`.
- Species looks are uniforms set from `BirdRig.FEATHER_LOOK`.

What it draws:
- **Surface.**
  - Shaft, barb ridges, and a soft ragged edge (alpha to coverage, raggedness by species).
  - Bars and dark tips on flight and tail feathers, pale margins, and the sparrow's dark centre streak.
  - Darkening toward each feather's base, where the row in front covers it.
- **Light.**
  - Wrapped diffuse.
  - Transmission when backlit, strongest looking toward the light. The shaft and dark pigment block it.
  - A Ward anisotropic highlight streaked by the barbs.
  - Iridescence (the crow) tints that highlight from violet to green with viewing angle.
  - The shading normal tilts across each barb ridge. Without that, a flat card mirrors the highlight across the whole wing, which was the first attempt's problem.
- **Flutter.** Only the tip moves, along the feather's own normal and across it. It scales with airspeed through the `flutter` uniform, set by the rig each tick.

Body and wing fairings get a soft rim sheen.

Before/after: `docs/images/feathers_before_after.png`. To reproduce it, run `scenes/rig_gallery.tscn` without (before) and with `--feather-shader` (after); `--time` freezes the flutter.

## Sources
- [UE-FUR] Unreal forums, "Fur shader": https://forums.unrealengine.com/t/fur-shader/5738/20
- [FALCON] Game Design Deep Dive: Falcon Age's feathered companion: https://gamedeveloper.com/design/game-design-deep-dive-creating-i-falcon-age-s-i-feathered-companion (mirror: https://www.jikguard.com/news/game-design-deep-dive-creating-falcon-ages-feathered-companion)
- [PATENT-GEN] Digital generation, placement, animation and display of feathers (patent 7427991): https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/7427991
- [PATENT-BTF] Modeling and rendering of realistic feathers (patent 7042456): https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/7042456
- [UNIZAR-24] A Surface-based Appearance Model for Pennaceous Feathers (SIGGRAPH 2024 poster): https://graphics.unizar.es/projects/FeathersAppearance_2024/A%20Surface-based%20Appearance%20Model%20for%20Pennaceous%20Feathers_files/feathers_appearance_SIGGRAPH_2024_poster.pdf
- [IRID-NSF] Appearance modeling of iridescent feathers with diverse nanostructures: https://par.nsf.gov/biblio/10592960 ; Cornell news: https://www.news.cornell.edu/stories/2025/01/researchers-put-shine-digitally-rendered-feathers
- [DOVE] Rendering Iridescent Rock Dove Neck Feathers: https://light.informatik.uni-bonn.de/?p=852 ; slides: https://projet.liris.cnrs.fr/origami/topics/gdl/gdl_talk_61/RenduDePigeon.pdf
- [PEACOCK] Stanford CS348B, Modeling and Rendering Peacock Tail Feathers: https://graphics.stanford.edu/courses/cs348b-competition/cs348b-05/peacock/index.html
- [BIRDING] Birds and light: translucency: https://birdingimagequalitytool.blogspot.com/2014/11/birds-and-light-translucency.html
- [DW] / [DW-SYS] DreamWorks, Artistic Rendering of Feathers for Animated Films: https://research.dreamworks.com/wp-content/uploads/2018/07/67-xie-Edited.pdf
- [PIXAR] Pixar SIGGRAPH 2026 talk: https://research.pixar.com/docs/2026.SiggraphTalks.PCB.pdf
- [OCTANE] Low-authority texture-shading tip page (soft look needs scattering); cited only as a rule of thumb.
- Feather/fur card shader (VRChat): https://normalizedcrow.gumroad.com/l/FeathersAndFur ; SideFX feather tools: https://www.sidefx.com/learn/learning-paths/cfx/feathers/
