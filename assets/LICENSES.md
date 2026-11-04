# Asset licences

Every asset in `assets/` and where it came from. Add a row when you add an asset; anything downloaded keeps its
source URL, author and licence here.

## Made in this project

| Path | What | How |
|---|---|---|
| `assets/feathers/` | Feather textures | Baked by `tools/bake_feathers.gd` from the project's own procedural feather shader |
| `assets/legs/` | Leg scale tiles | Baked by `ScaleTile` (`scripts/bird/scale_tile.gd`) |
| `assets/audio/recordings/claws_on_cat_tree.wav` | Nails scratching a cat tree (the perch catch) | Recorded by the user, 2026-11-02 (an .m4a, converted to 44.1 kHz mono WAV) |
| `assets/audio/sfx/` | Every game sound | Baked by `tools/bake_sounds.gd` from `SoundRecipes` (`scripts/audio/sound_recipes.gd`); the bursts are built on the Freesound recording below, the perch catch on the user's recording above |

## Downloaded

All Poly Haven assets are CC0 1.0 (public domain dedication; no attribution required, credited here anyway):
<https://polyhaven.com/license>. Downloaded 2026-11-02 as 2K JPEGs (diffuse, OpenGL normal, AO/rough/metal
packed as `arm`, displacement).

| Path | Asset | Author | Real size | Source | Licence |
|---|---|---|---|---|---|
| `assets/textures/bark/pine_bark/` | Pine Bark | Dimitrios Savva | 2.0 x 2.0 m | <https://polyhaven.com/a/pine_bark> | CC0 1.0 |
| `assets/textures/bark/knotted_pine_bark/` | Knotted Pine Bark | Dimitrios Savva | 1.7 x 1.7 m | <https://polyhaven.com/a/knotted_pine_bark> | CC0 1.0 |
| `assets/textures/bark/jolcham_oak_bark_01/` | Jolcham Oak Bark 01 | Charlotte Baglioni | 1.0 x 2.0 m | <https://polyhaven.com/a/jolcham_oak_bark_01> | CC0 1.0 |
| `assets/textures/ground/forrest_ground_03/` | Forest Ground 03 (pine-needle litter) | Rob Tuytel | 2.0 x 2.0 m | <https://polyhaven.com/a/forrest_ground_03> | CC0 1.0 |
| `assets/textures/ground/forest_leaves_02/` | Forest Leaves 02 (the floor's moss patches; 4K, downloaded 2026-11-03) | Rob Tuytel | 3.0 x 3.0 m | <https://polyhaven.com/a/forest_leaves_02> | CC0 1.0 |
| `assets/textures/planks/weathered_planks/` | Weathered Planks | Dario Barresi, Dimitrios Savva | 2.0 x 2.0 m | <https://polyhaven.com/a/weathered_planks> | CC0 1.0 |

Freesound (CC0 1.0, public domain dedication; no attribution required, credited here anyway). Copied 2026-11-02 from
`../cast/assets/audio/third_party/freesound/`, which downloaded it on 2026-10-18.

| Path | Title | Author | Source | Licence |
|---|---|---|---|---|
| `assets/audio/third_party/freesound/336008__rudmer_rotteveel__whistle-and-explosion-single_firework.wav` | Whistle and Explosion Single_Firework | Rudmer_Rotteveel | <https://freesound.org/people/Rudmer_Rotteveel/sounds/336008/> | CC0 1.0 |

The bird calls (`SoundRecipes.CALLS`), cut from Freesound's HQ MP3 previews, downloaded 2026-11-02 into
`assets/audio/sources/freesound/` (`.gdignore`'d: read by the bake, never imported or exported). CC0 1.0 unless
stated.

| File | Title | Author | Source | Licence |
|---|---|---|---|---|
| `75162__nigelcoop__crow.mp3` | crow.wav | nigelcoop | <https://freesound.org/people/nigelcoop/sounds/75162/> | CC0 1.0 |
| `361470__jofae__crow-caw.mp3` | Crow Caw | Jofae | <https://freesound.org/people/Jofae/sounds/361470/> | CC0 1.0 |
| `101344__raoul_slayer__barnowl.mp3` | BarnOwl.wav | raoul_slayer | <https://freesound.org/people/raoul_slayer/sounds/101344/> | CC0 1.0 |
| `397690__yacob_l__owl-screeches.mp3` | Owl Screeches | Yacob_l | <https://freesound.org/people/Yacob_l/sounds/397690/> | CC0 1.0 (spare; not used yet) |
| `616995__trp__red-tailed-hawk-call.mp3` | 211123 Red-tailed Hawk call, pretty close, noisy roof, Toronto 10am.wav | TRP | <https://freesound.org/people/TRP/sounds/616995/> | CC0 1.0 |
| `616926__trp__red-tailed-hawk-isolated-calls.mp3` | 210227 Red Tailed Hawk, eq isolated calls, roof 77mel 10am.wav | TRP | <https://freesound.org/people/TRP/sounds/616926/> | CC0 1.0 |
| `352263__ylearkisto__kestrel-warning.mp3` | Tuulihaukka, varoitusääni / Kestrel, warning it's nestlings (Falco tinnunculus) | YleArkisto (Yle, the Finnish Broadcasting Company) | <https://freesound.org/people/YleArkisto/sounds/352263/> | **CC BY 4.0**: credit required ("Kestrel call: YleArkisto, CC BY 4.0"); a shipped build needs it in its credits |
| `404663__straget__house-sparrow.mp3` | House sparrow.wav | straget | <https://freesound.org/people/straget/sounds/404663/> | CC0 1.0 |
| `383160__beeproductive__house-sparrow.mp3` | House sparrow.wav | BeeProductive | <https://freesound.org/people/BeeProductive/sounds/383160/> | CC0 1.0 (spare; not used yet) |
