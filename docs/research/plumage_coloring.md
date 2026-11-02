# Plumage colouring: research and proposal

Why our birds don't yet read like the field-guide plate of raptors seen from below, and a cheapest-first plan to get there without going back to the parked feather shader (see `feather_rendering.md`).

**The diagnosis in one line.** Today each species has one tint, darkened or lightened per feather kind (`BirdRig._tint()` and `_colors`). Every feather is the same colour on both faces (`CULL_DISABLED`), and the body is one colour. The reference plate is almost entirely about four things we can't express: **top and underside differ**, **body zones differ**, **underwing coverts differ from flight feathers**, and **a few large marks**: the leading-edge bar, the wrist comma, dark tips, tail bands and the white head. Fine texture barely figures. The parked shader added fine detail and lighting, which is not what the plate shows.

## 1. Plumage pattern elements and what makes them

### Big masses
- **Countershading.** Animals are darker on top and paler underneath, which cancels the self-shadow that would otherwise make the back look darker than the belly. It's sometimes called Thayer's law, after Thayer's 1896 paper in *The Auk* [THAYER][WIKI-CS]. Thayer's example is the ruffed grouse, "dark brown on the back" grading to white underneath. It works best under direct sun. A 2016 PNAS study found that a sharp dark-to-light transition paid off only under direct sun; under diffuse light it gave no advantage over uniform colouring, and a smoother gradient was best [CUTHILL][WIKI-CS]. For us, this is the cheapest single cue for whether we're seeing a bird's top or its belly.
- **Feather-tract colour zones.** Field guides describe plumage by feather tract. The colour placement *within each tract* never changes, whatever the posture, so tract names are reliable across viewing angles [BTO-TOPO][WIKI-TOPO]. The tracts that matter at our scale:
  - head: crown, face/cheek, malar, throat, nape
  - mantle/back, scapulars, rump/uppertail coverts
  - breast, belly, flanks, vent/undertail coverts
  - upperwing coverts (lesser, median, greater), alula, tertials
  - underwing coverts and axillaries
  - primaries, secondaries, and the tail (top and underside)

### Wing marks (mostly seen from below)
- **Patagial bar.** A dark bar along the underwing's leading edge, from the body to the wrist. These are the coverts on the patagium, the skin web from shoulder to wrist. It is the Red-tail's diagnostic mark, "present on all ages and races" [GT].
- **Carpal patch, or "comma".** A dark mark on the under-coverts at the wrist: the Red-tail's dark "comma marks", the Osprey's black wrists [GT][WIKI-OS]. The Rough-legged Hawk's version is pale [GT].
- **Dark trailing edge and dark tips.** Dark tips on the secondaries form a dark band along the rear of the wing; dark outer-primary tips make dark "fingers". Light-morph Red-tails show "dark outer primary tips and a dark trailing edge" [GT].
  - The cause is melanin. Melanised keratin is about 39% harder and resists abrasion [BONSER]. Black wingtips on pale birds are usually explained as wear protection, and pale tips and fringes are the first parts to wear away [HW-TIPS].
- **Two-tone underwing.** Under-coverts contrast with the flight feathers: Turkey Vulture "black on the leading edge" with grey trailing feathers [AUD-V]; condor with "pure white under wing coverts" on black [AUK-CC].
- **Windows and pale bases.** Translucent panels show where "fewer layers of feathers" overlap and the pigment is thinner. They change with sun angle [SIBLEY-T]. A juvenile Red-tail has all ten primaries paler than its secondaries, giving a square panel [CFNO]. Juvenile Golden Eagles show white patches at the primary bases and a white tail base [AAB-GE].
- **Wing bars.** On the upperwing, pale tips on a row of coverts make a bar. The median coverts usually make the upper bar and the greater coverts the lower one [NW][BTO-24]. The House Sparrow has one white bar, from the median coverts [ABSA-HS].
- **Upperwing and back "V".** Pale-mottled scapulars and coverts on a dark back form a pale V, as on the Red-tail [ODFW][MTAUD].

### Tail and feather-scale marks
- **Tail bands.** Several types:
  - **Terminal or subterminal band.** The adult Red-tail's red tail ends "in a single black band" [WIKI-RT]. The Peregrine's tail has fine bars, a black tip and a white band at the very end [WIKI-PF].
  - **Evenly banded tails.** Juvenile Red-tail (about six bars) [WIKI-RT], Great Horned Owl (6–7 dusky bands; low-authority source) [GHO-6], Osprey (banded tail, per the reference image).
  - **Contrasting tail base.** Juvenile Golden Eagle (white base, dark band) [AAB-GE]; adult Bald Eagle (all-white tail) [WIKI-BE].
- **Barring, streaking, spotting.**
  - **Barring** runs across the feather. Adult Peregrine underparts are "thin, clean bands" [WIKI-PF]; the underwing is barred pale grey and black [FWS-PF] and reads "plain greyish" at range [QA-PF].
  - **Streaking** runs along the shaft. Juvenile Peregrines are streaked rather than barred [WIKI-PF]; the Red-tail's belly band is made of streaks [WIKI-RT].
  - **Spotting** is spots: the Barn Owl's fine speckling [WIKI-BO].
  - At game distance, barring and streaking average out to a **mid-tone**. That is what to render first.
- **Pale fringes and edges.** A pale margin round a dark-centred feather gives a scaled look: sparrow tertials and greater coverts, and the buff fringes of juvenile raptors [WIKI-OS]. Fringes wear off through the year [HW-TIPS].
- **Iridescence.** The crow's violet-blue gloss is structural, not pigment [WIKI-AC]. See `feather_rendering.md`; it's out of scope here, beyond a slight blue cast in the black.

### Our five species, top and underside
| Species | Top | Underside |
|---|---|---|
| **Crow** (American) | Black all over, glossy, with purple, blue or green hints in sun. Juvenile wing and tail wear brownish [WIKI-AC][BF-AC]. | Black. The flight feathers look slightly paler and greyer than the coverts against the sky (the gloss, and thinner vanes). |
| **Owl** (Barn × Great Horned blend) | Barn: golden-buff with grey veiling and fine black-and-white speckles; flight feathers light brown with darker bands [WIKI-BO][RSPB-BO]. GHO: mottled brown-grey with heavy, complex dark marks; banded primaries; 6–7 tail bands [WIKI-GHO][GHO-6]. | Barn: white to buff, few spots, a pale underwing with no wrist mark, a "large white bird" in flight; some sources give it dark ink-dipped wingtips [WIKI-BO][SWT-OWL]. GHO: pale with brown horizontal barring and a white throat collar [WIKI-GHO]. |
| **Hawk** (Red-tailed, light morph) | Dark brown back; pale-mottled scapulars and coverts form a V; brick-red tail with a dark subterminal band [ODFW][WIKI-RT]. | Pale breast; streaky dark belly band; cream under-coverts with a dark patagial bar and wrist comma; pale, finely barred flight feathers with dark outer tips and trailing edge; tail pale orange-buff below [GT][WIKI-RT]. |
| **Falcon** (Peregrine adult) | Slate to blue-grey, darkening to a black hood and a bold malar "moustache"; black wingtips; tail finely barred with a black band and white tip [WIKI-PF]. | White throat and upper breast; the rest white to rusty with fine, clean dark bars; underwing evenly barred pale grey and black, reading grey at range [WIKI-PF][FWS-PF][QA-PF]. |
| **Sparrow** (House, male) | Grey crown; chestnut nape and sides of the head; warm brown back with broad black streaks; grey-brown rump; one white wing bar; black-centred coverts and tertials with rufous edges [WIKI-HS][ABSA-HS][BZ-HS]. Female: brown head, pale supercilium, no bib [WIKI-HS]. | Pale grey cheeks and underparts; black bib on the throat and chest [WIKI-HS]. The underwing is plain greyish-buff (no source found; from photos). |

The other raptors in the reference image:
- **Osprey:** glossy dark brown above. White below, with a weaker breast band on males, black wrists, and barred flight feathers [WIKI-OS].
- **Turkey Vulture:** two-tone below [AUD-V].
- **Bald Eagle:** dark with a white head and tail. Immatures are diffusely mottled white [AAB-BE].
- **Golden Eagle:** dark brown with a golden nape; juveniles have white patches [AAB-GE].
- **Condor:** black with white under-covert triangles [AUK-CC].

## 2. What the rig gives us to colour (from the code)

- **Feathers.** `WingShape.feathers()` yields, per wing, primaries `i` 1..10 (10 = outermost; the emarginated ones go to the second MultiMesh) and secondaries `i` 1..nsec (1 at the wrist). It also yields greater coverts over primaries 1..7 (bone HAND) and over every secondary (bone FOREARM), 3 tertials, and 10 lesser coverts: `i` 0–3 humerus, 4–7 forearm, 8–9 hand. Then 3 alula feathers, and in `BirdRig` 12 rectrices (k 0..11, central pair 5 and 6). **All coverts are upper coverts** (layer +n), so from below you see the backs of the flight feathers and the four fairings. **Nothing represents the underwing coverts.**
- **Fairings.** Four ellipsoids per wing: patagium, humerus, forearm, hand. Local axes are X = aft, Y = wing normal, Z = along the bone (`_place_fairing`), and the front edge is local −X. Their *underside is where the underwing coverts would be*, and their front underside is exactly where the patagial bar and the wrist comma go.
- **Body.** A capsule for the body and a sphere for the head (the owl's is bigger), all in one colour.
- **Material.** The plain `StandardMaterial3D` reads per-instance sRGB colour (`vertex_color_is_srgb`), so sRGB hex specs map 1:1. Custom data is currently `(kind, seed, emarg, 0)` and is read only by the parked shader.

## 3. Proposal, cheapest to richest

### A. Two-sided feathers and zoned body (no shader, no textures)

1. **Two-sided colour, the no-shader way.** Draw each feather MultiMesh twice. One copy uses `CULL_BACK` with the top colours. The other uses a mirrored mesh: `_feather_mesh(profile, flip=true)`, built with reversed winding and normal `DOWN`. It also uses `CULL_BACK`, with the under colours.
   - Each copy draws only its own face, so there's no z-fighting and lighting is right on both sides. Don't rely on `CULL_FRONT` and hope the engine flips the normal.
   - Cost: 4 feather draws per bird instead of 2, and about 120 more `set_instance_*` calls per rig update (rig budget ~150 µs). To recover it, write each MultiMesh with one `buffer` assignment (12 floats of transform, 4 of colour, 4 of custom per instance) instead of one call per instance.
   - Instance basis is right-handed for both wings (`_feather_xform`), so "front" is always the wing's top (+n). No mirrored-wing special case.
   - *Alternative, if a 15-line shader is acceptable.* A ShaderMaterial that reproduces the plain look exactly: lit, `ALBEDO = FRONT_FACING ? top : under`, `ROUGHNESS = 0.9`, no other terms, `cull_disabled`. The under colour goes in `INSTANCE_CUSTOM.rgb`, passed through a varying, since custom data is vertex-only. `FRONT_FACING` is a fragment built-in [GODOT-SS]. It's one draw, but it's a shader; keep it strictly albedo-only so it can't drift from the preferred look. Convert sRGB to linear by hand.
2. **An under-covert row.** Add `Kind.UNDER_COVERT` in `WingShape`: copies of the greater coverts at layer **−0.006**, under the flight feathers. Make them a little longer (about 0.5× the secondaries) and also give them to the hand and humerus.
   - That's about 40 instances per bird. They're hidden from above by the flight feathers.
   - They carry the under-covert colour: the condor's white triangle, the vulture's black band, the Red-tail's cream.
   - Real wings have greater, median and lesser under-coverts plus the axillaries; one row plus the fairing underside reads the same at our scale.
   - `test_bird_rig`'s feather counts and kind lists need updating.
3. **Fairing vertex colours.** Build the fairing ellipsoid as an `ArrayMesh` from `SphereMesh.get_mesh_arrays()` and colour each vertex from its local position, then use the plain material with `vertex_color_use_as_albedo`:
   - **Top** (`y > 0`): upperwing lesser-covert colour.
   - **Underside** (`y < 0`): under-covert colour.
   - **Patagial bar:** underside, `x < −0.15`, on the patagium, humerus and forearm pieces.
   - **Wrist comma:** underside of the hand piece, front half, plus the hand's lesser coverts 8–9 and the alula in the comma colour.
   - Blend edges over about 0.1 so there's no hard seam. Patagium and humerus overlap, so give them the same colour rules.
4. **Body and head zones by vertex colour.** The same trick on the capsule and sphere, colour from local position and normal:
   - **Countershade line** on the body: dorsal colour above, ventral below, with a set height (−1..1) and softness.
   - **Bands along the body:** breast (front third), belly, vent (rear), flanks (the sides of the ventral half). Plus a **belly band** (z-range, ventral) and a **rump** (rear dorsal).
   - **Head:** crown (top cap), nape (rear), face (front), throat (lower front), and two optional marks. The **malar** is a downward stripe under each eye (falcon). The **facial disc** is a front-hemisphere disc in a face colour with a dark rim (owl). A **bib** covers the throat plus the front breast (sparrow).
   - Cost is zero at runtime, since the meshes are built once.
5. **Colour by feather index (row patterns).**
   - *Primaries:* gradient from p1 to p10; the outer N (or the emarginated "fingers") darker, as wingtips.
   - *Secondaries:* inner to outer gradient.
   - *Greater coverts over the primaries vs over the secondaries:* the condor's pale upperwing bar, the Golden Eagle's tawny bar.
   - *Tail:* central pair vs outer feathers. Many species have different outer rectrices; sparrows, for example, have pale-edged outers.
   - Index patterns can't give within-feather marks: dark *tips*, a tail band, fringes. That's step B.

### B. Within-feather marks with no texture assets, then textures
6. **A 1D mark strip** (recommended next step). Every within-feather mark on the plate is a function of position *along* the feather: dark tip, subterminal band plus pale tip, pale base or window, n bars. Only fringe and streak also need the *across* position.
   - Bake each pattern id into one row of a tiny `Image` (64 × N, R = mark amount along `UV.y`, G = fringe width), generated **at build time from the plumage spec**. No asset files; designers edit numbers, not PNGs.
   - The shader is still albedo-only: `albedo = mix(base, mark, strip(UV.y, pattern_row))`, plus `smoothstep` on `abs(UV.x)` against G for fringes, and the streak as the inverse.
   - Per instance it needs a pattern row and a mark colour. Pack them in custom data: `.rgb` = under colour, `.a` = `row + 0.5*side_flag`; or use the second (under) MultiMesh's own colour.
   - Cost: one 64 × 16 texture fetch per fragment. Visually it adds dark tips, trailing edges and tail bands, the most visible remaining marks on the plate.
   - **Without any shader,** the closest fallback is per-vertex colour on extra stations of the feather mesh (8–9 stations now; add more near the tip). Godot multiplies the MultiMesh instance colour into the vertex colour, so a "dark-tip" mesh works. But it can only darken, and it needs one mesh and MultiMesh per pattern × side. It does the job for "dark-tipped primaries" alone; beyond that it isn't worth it.
7. **A painted pattern atlas** (4–8 feather patterns: plain, tipped, barred, fringed, banded, spotted), picked per feather via custom data. It gives the richest close-up, but it costs painting, needs mipmaps to avoid shimmer on small cards, and drifts toward the busy look that was rejected. Only for a close-up or hero camera, and after step 6.

**Render rule for fine patterns.** At our camera distances, barring and speckling should **average to a mid-tone** (base mixed with mark at the bar duty cycle), with real bars only on the tail and where `n ≤ 6`. That's how the Peregrine's underwing reads "plain greyish" [QA-PF] and how the plate paints the Osprey.

**Lighting note.** The plate is evenly lit. In game, an underwing seen from below is lit only by the sky, so a cream underwing renders grey-brown.
- Before judging any colours, check the scene has sky ambient light and some ground bounce.
- `StandardMaterial3D.backlight_enabled` with a pale `backlight` is a cheap built-in way to let sunlight through thin pale feathers [SIBLEY-T] without the parked shader.
- Keep "white" at about `#f2ece2` and "black" at about `#1c1c22` so form still shades.

## 4. Data format: the plumage spec
A per-species dictionary in `scripts/bird/plumage.gd`, in the same style as `WingShape.DATA` and `FEATHER_LOOK`. Move it to a `PlumageSpec` `Resource` (`.tres`, exported `Color`s) when a designer wants colour pickers. Every colour is an sRGB hex string.

```gdscript
const PLUMAGE := {"hawk": {
  "body": {"back": "#5a3e2b", "rump": "#5e4230", "breast": "#f1e7d6", "belly": "#efe4d2", "flanks": "#c9ae8a",
           "vent": "#f3ece2", "belly_band": ["#a88a6c", 0.15, 0.45],   # colour (streaks averaged), z0, z1
           "countershade": [0.05, 0.25]},                              # line height, softness
  "head": {"crown": "#5e4230", "nape": "#6b4a32", "face": "#8a6a4e", "throat": "#e8dccb"},
  "wing_top": {"lesser": "#5a3f2c", "greater": "#6b4c34", "tertial": "#64482f", "alula": "#4e3626"},
  "wing_under": {"coverts": "#f0e6d6", "patagial": "#4a3324", "carpal": "#3f2c20"},
  "groups": {   # [top, under, pattern_top, pattern_under]; pattern = [id, mark colour, params...]
    "primary":   ["#3e2e22", "#e9e4dc", ["plain"], ["bars_tip", "#b8aea2", 5, 0.25, "#2e2621", 0.78]],
    "secondary": ["#5e4632", "#e6e0d6", ["bars", "#4a3828", 5, 0.2], ["bars_tip", "#b8aea2", 6, 0.2, "#6a5c50", 0.88]],
    "tail":      ["#b8532a", "#e8c9a6", ["subterm", "#3a2a20", 0.85, 0.92, "#e9dccb"], ["subterm", "#b89a7c", 0.85, 0.92, "#f2e6d6"]]},
  "index": {"primary_outer_dark": [3, 0.35]}   # outermost 3 primaries darkened 35% (fingers)
}}
```
**Pattern ids** (all along the feather, `t` 0 base to 1 tip):
- `plain`
- `tip` (mark, t0)
- `base` (mark, t1), for pale bases and windows
- `subterm` (mark, t0, t1, tip colour)
- `bars` (mark, n, duty)
- `bars_tip` (bars plus a tip)
- `fringe` (mark, width)
- `streak` (mark, width)

Until step 6 exists, the build uses `mix(base, mark, coverage)` as the flat feather colour, and `tip`/`subterm` fall back to the index darkening. The spec is valid from day one.

## 5. Per-species specs (approximate sRGB)
Values are judgement calls from the descriptions above and reference photos, tuned for our matte material. "→" means a gradient from inner to outer feathers.

**Crow** (American). Blue-black; reads black with a faint cool cast.
| Zone / group | Top | Under | Pattern |
|---|---|---|---|
| Body: back, rump / breast, belly, vent | `#1c1c22` | `#1f1f24` | none; countershade 0 (uniform) |
| Head; bill and legs | `#1b1b21`; `#121214` | — | — |
| Lesser and greater coverts; tertials | `#1e1e25` | under-coverts `#1c1c21` | — |
| Primaries; secondaries | `#202026`; `#202027` | `#2c2c31`; `#2a2a30` | plain (the paler underside is the cue) |
| Tail | `#1e1e24` | `#2a2a2f` | plain; juvenile/worn variant `#2a2522` |

**Owl** (blend: Barn top and face with Great Horned barring and bands). For a stronger GHO look, darken the top 20%, set the under to `#d9c9ac` with bars, and the throat collar to `#f2eee6`.
| Zone / group | Top | Under | Pattern |
|---|---|---|---|
| Back, nape / rump | `#a8875a` / `#b8996a` | — | speckle averaged in |
| Breast / belly / flanks / vent | — | `#efe4cf` / `#f1e8d6` / `#e6d3b0` / `#f3ece0` | countershade line at 0.2, soft 0.3 |
| Head: crown; facial disc; disc rim; throat | `#a8875a`; `#f2ece0`; `#8a6a48`; `#efe6d6` | — | facial disc on |
| Lesser, greater coverts | `#a07c50`, `#b08a58` | under-coverts `#f4ede0` | greater: grey fringe `#8e8676` |
| Primaries | `#b8905c` | `#e8dcc6` | top `bars` `#6e5a46` ×4; under `bars_tip` `#c9b89c` ×4, tip `#9a8c78` 0.85 |
| Secondaries; tertials | `#b89462`; `#b08a5a` | `#ebe0cc` | top `bars` ×4; under faint bars `#d2c4ac` |
| Tail | `#c09a64` | `#ece2cf` | `bars` `#7a6650` ×4 (GHO: ×6) |

**Hawk** (Red-tailed, light morph). Values as in the §4 example, plus:
| Zone / group | Top | Under | Pattern |
|---|---|---|---|
| Back / scapular "V" (dorsal shoulder patch) | `#5a3e2b` / `#a8875f` | — | V via body zone |
| Head / throat | `#6b4a32` / `#e8dccb` | — | — |
| Breast / belly band / flanks / vent | — | `#f1e7d6` / `#a88a6c` / `#c9ae8a` / `#f3ece2` | band z 0.15–0.45 |
| Lesser / greater coverts | `#5a3f2c` / `#6b4c34` | under-coverts `#f0e6d6` | greater: pale tips `#8a6c50` |
| Patagial bar / wrist comma | — | `#4a3324` / `#3f2c20` | fairings + hand lesser coverts 8–9 + alula (under) |
| Primaries (p1 → p10) | `#4a3628` → `#33261c` | `#e9e4dc` | under `bars_tip`, tip `#2e2621` from 0.78; outer 3 darkest |
| Secondaries | `#5e4632` | `#e6e0d6` | under `bars_tip`, dark trailing edge `#6a5c50` from 0.88 |
| Tail | `#b8532a` | `#e8c9a6` | `subterm` `#3a2a20` 0.85–0.92, tip `#e9dccb`. Juvenile: top `#7a5e44` `bars` ×6 `#4e3a2a`; under primaries paler (window). |
| Cere and feet | `#e3c04a` | — | — |

**Falcon** (Peregrine adult). The *anatum* belly washes to `#e2c9ae`.
| Zone / group | Top | Under | Pattern |
|---|---|---|---|
| Hood (crown, nape, malar) | `#2a2e35` | — | malar stripe on |
| Cheek and throat / upper breast | `#f4efe6` | `#f3ece2` | unbarred |
| Back / rump | `#5f6b78` / `#7d8a98` | — | darkening toward the head |
| Belly, flanks, vent | — | `#bdb6ae` | fine bars averaged (white + black) |
| Coverts (lesser, greater) | `#66727f` | under-coverts `#b9b2aa` | top: faint bars `#55606c` |
| Primaries | `#2b2f36` | `#cfc9c2` | under `bars_tip` `#8a8580` ×7, tip `#5a5550` 0.85 |
| Secondaries; tertials | `#4f5a66`; `#5a6672` | `#cbc5be` | under `bars` ×7 |
| Tail | `#5d6874` | `#c9c4bd` | `bars` `#3e4650` ×6 + `subterm` `#23262b` 0.86–0.94, tip `#ece8e0` |
| Cere, eye ring, feet | `#e8c547` | — | — |

**Sparrow** (House, male; female differences at the end of the table)
| Zone / group | Top | Under | Pattern |
|---|---|---|---|
| Crown / nape and head sides / cheek | `#8a8e8f` / `#7b4a2c` / `#c9c6bd` | — | — |
| Bib (throat + front breast) | — | `#1f1d1b` | bib on |
| Back / rump | `#8b6440` / `#8a8578` | — | `streak` `#2a211b` (averaged: `#6e5236`) |
| Breast, belly / flanks / vent | — | `#c4c1b8` / `#b7ae9d` / `#d6d0c3` | countershade line at 0, soft 0.15 |
| Lesser coverts (forearm, `i` 4–7) | `#7a4a2c` | under-coverts `#c8c2b6` | `tip` `#eeeae0` 0.7: **the white wing bar** (stands in for the median coverts) |
| Greater coverts; tertials | `#2a221c`; `#2e241d` | — | `fringe` `#a0663a`; `fringe` `#b07a46` |
| Primaries; secondaries | `#4d3d30`; `#5a4632` | `#8f8a82` | `fringe` `#9a7a58` narrow |
| Tail | `#5a4a3c` | `#7f786e` | `fringe` `#8e7a62` |
| Female | crown `#8c7660`, supercilium `#d9ccb0`, back `#93704c` | breast `#c9c0ae`, no bib | — |

**Reference raptors (optional species skins):**
| Species | Top | Under | Key marks |
|---|---|---|---|
| Osprey | back and wings `#4a3a2e`; head `#f4f2ec`, eye stripe `#3a2c22` | body and under-coverts `#f6f4ef`; flight feathers `#d9d4cc` | carpal `#262019`; under flight `bars` `#6f6459` ×6 with tip `#2b241e`; tail `bars` ×6; breast band `#8b6e55` (female) |
| Turkey Vulture | `#2a2420`; head `#b33a2e` | under-coverts `#2a2420`; flight feathers `#a9a6a2` | two-tone; tail under `#8e8a85` |
| Bald Eagle | `#3a2a1f`; head and tail `#f6f4ee` | `#33261d` | bill and feet `#e9b83a`; immature: under-coverts mottled `#8a7a68` |
| Golden Eagle | `#4a3626`; nape `#b98a46`; upperwing covert bar `#8a6a48` | flight feathers `#6a5a4a` | under `base`-pale, dark trailing edge `#3a2c22`. Juvenile: `base` `#f0ece4` to 0.45 on inner primaries; tail `#f0ece4` base + terminal `#2e241c` |
| California Condor | `#1a1817`; upperwing greater-covert bar `#9a9894`; head `#d9875a` | under-coverts (front) `#f2f0ea`; flight feathers `#1f1d1c` | the white triangle is the under-covert row plus the fairing undersides, i.e. the inverse of a patagial bar |

## 6. What makes the biggest difference first (greybox geometry)
1. **Two-sided flight feathers and tail, plus body countershading** (steps 1 and 4, body only). One change turns hawk, falcon and owl into "dark above, pale below", which is most of the plate. It also gives the Red-tail's red top and buff tail underside. Cheapest, and highest value.
2. **Under-covert row and fairing undersides** (steps 2 and 3). The underwing becomes two-tone (vulture, condor), and the Red-tail gets its patagial bar and wrist comma: the plate's signature marks.
3. **Dark outer primaries by index** (step 5). The wingtip "fingers" read at any distance, at no cost.
4. **Head zones:** falcon hood and malar, owl facial disc, sparrow crown, nape and bib, Bald Eagle head. These identify the species in the gameplay camera.
5. **The 1D mark strip** (step 6) for dark tips and trailing edges, tail terminal bands and the sparrow wing bar. It's the only step that needs a (tiny, albedo-only) shader, so do it once 1–4 are judged.
6. Fringes, barring and spots last, as averaged mid-tones before real stripes. Don't use the atlas (step 7) unless there's a close-up camera.

Throughout, evaluate in the real in-game lighting (see the lighting note) and from the gameplay camera, not the rig gallery's top view.

## Sources
- [THAYER] Thayer 1896, *The Auk* 13: https://sora.unm.edu/sites/default/files/journals/auk/v013n02/p0124-p0129.pdf
- [WIKI-CS] Countershading: https://en.wikipedia.org/wiki/Countershading
- [CUTHILL] Cuthill IC et al. 2016, Optimizing countershading camouflage, *PNAS* 113:13093-13097, doi:10.1073/pnas.1611589113: https://pmc.ncbi.nlm.nih.gov/articles/PMC5135326/
- [BTO-TOPO] BTO, bird topography (Field craft, spring 2023): https://www.bto.org/sites/default/files/bird_topography_-_field_craft_bto_news_spring_2023.pdf
- [BTO-24] BTO Field craft, summer 2024 (median coverts): https://ociweb.bto.org/sites/default/files/field_craft_bto_news_summer_2024.pdf
- [WIKI-TOPO] Terms used in bird topography: https://en.wikipedia.org/wiki/List_of_terms_used_in_bird_topography
- [NW] Northern Woodlands, bird morphology (wing bars): https://northernwoodlands.org/articles/article/bird-morphology
- [BONSER] Bonser 1995, melanin and abrasion, *Condor* 97: https://sora.unm.edu/sites/default/files/journals/condor/v097n02/p0590-p0591.pdf
- [HW-TIPS] HawkWatch International, "Black wing tips": https://hawkwatch.org/?p=8863
- [SIBLEY-T] Sibley, wing translucence: https://sibleyguides.com/the-finer-points-of-wing-translucence/
- [GT] Green Timbers, Red-tailed Hawk (patagial, carpal, dark tips and trailing edge): https://www.greentimbers.ca/vegetation-wildlife/wildlife/birds/red-tailed-hawk/
- [WIKI-RT] Red-tailed hawk: https://en.wikipedia.org/wiki/Red-tailed_hawk
- [ODFW] Oregon Dept. of Fish and Wildlife, Red-tailed Hawk (scapular V): https://myodfw.com/taxonomy/term/1217
- [MTAUD] Montana Audubon raptor ID: https://mtaudubon.org/wp-content/uploads/2020/10/MT-Audubon-Raptor-ID_online_web.pdf
- [CFNO] Juvenile Red-tail field marks (primary panel): https://cfno.blogspot.com/2013/09/in-flight-field-marks-of-juvenile-red.html
- [WIKI-PF] Peregrine falcon: https://en.wikipedia.org/wiki/Peregrine_falcon
- [FWS-PF] US FWS, Peregrine falcon: https://www.fws.gov/species/peregrine-falcon-falco-peregrinus
- [QA-PF] Qatar e-Nature, Peregrine (plain greyish barred underwing): https://enature.qa/specie/falcon-peregrine
- [WIKI-BO] Western barn owl: https://en.wikipedia.org/wiki/Western_barn_owl
- [RSPB-BO] RSPB, Barn owl: https://www.rspb.org.uk/birds-and-wildlife/barn-owl
- [SWT-OWL] Sussex Wildlife Trust, identifying owls: https://sussexwildlifetrust.org.uk/news/how-to-identify-owls
- [WIKI-GHO] Great horned owl: https://en.wikipedia.org/wiki/Great_horned_owl
- [GHO-6] Avibirds, Great Horned Owl (tail bands; low authority): https://avibirds.com/?p=43055
- [WIKI-HS] House sparrow: https://en.wikipedia.org/wiki/House_sparrow
- [ABSA-HS] Australian Bird Study Assoc., sparrow ID (single vs double wing bar): https://www.absa.asn.au/wp-content/uploads/2014/12/B4360.pdf
- [BZ-HS] Blasco-Zumeta, House Sparrow ageing and sexing guide: https://www.blascozumeta.com/specie_files/15910_ENG_Passer_domesticus_aranzadi.pdf
- [WIKI-AC] American crow: https://en.wikipedia.org/wiki/American_crow
- [BF-AC] Birdfact, American Crow (juvenile brown wear; low authority): https://www.birdfact.com/birds/american-crow
- [WIKI-OS] Osprey: https://en.wikipedia.org/wiki/Osprey
- [AUD-V] Audubon, "Birdist Rule #60" (vultures): https://www.audubon.org/magazine/birdist-rule-60-figure-out-what-kind-of-vulture-circling-you
- [AUK-CC] *The Auk* 46(3), condor white under-coverts: https://sora.unm.edu/sites/default/files/journals/auk/v046n03/p0386-p0386.pdf
- [AAB-GE] All About Birds, Golden Eagle similar species: https://www.allaboutbirds.org/guide/Golden_Eagle/species-compare
- [WIKI-BE] Bald eagle: https://en.wikipedia.org/wiki/Bald_eagle
- [AAB-BE] All About Birds, Bald Eagle ID (archived): https://webarchive.library.unt.edu/web/20170107115439/http://www.allaboutbirds.org/guide/Bald_Eagle/id
- [GODOT-SS] Godot spatial shader reference (FRONT_FACING, INSTANCE_CUSTOM): https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html

All About Birds species ID pages refused automated fetches (HTTP 403), so species descriptions lean on Wikipedia, agency and society pages. The hex values are estimates, not measured reflectance.

**Weak sources:** [GHO-6] (Avibirds) and [BF-AC] (Birdfact) are low-authority, and [CFNO] is a blog. The Osprey's banded tail is taken from the reference image, and the House Sparrow's plain underwing from photos; neither has a written source.
