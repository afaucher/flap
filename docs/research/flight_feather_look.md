# The large feathers: what reads on a whole bird

**Question (2026-11-02).** The flight feathers (primaries, secondaries, tertials, tail) and the big coverts now
have the least detail on the bird. What does a real bird's large feathers actually show when you look at the
whole bird, not at one feather on a table? At which of our viewing distances does each thing read, which of the
five species show it, and how do we draw it with the existing level-6 setup (`FeatherAtlas` masks,
`feather_texture.gdshader`, `Plumage.TEXTURE`, the card MultiMeshes)?

**Answer, in short.** Most of what makes a real wing look like a wing is not finer texture. It comes from four
things the cards don't do yet:

1. **The two vanes differ.** From above you see mostly outer vanes, and from below mostly inner vanes
   [SIBLEY-WINGS]. A folded wing is a stack of outer-vane strips. The underwing is inner vanes.
2. **Marks keyed to the wing, not to the feather.** Bars and dark trailing bands line up across neighbours.
3. **Light.** Gloss, sheen and translucency are reflectance properties, not spatial detail. So they read at
   every distance, while a 0.5 mm barb never does.
4. **The step between feathers.** Each feather shades the next. Our layer gaps are 0.2-0.4 mm, far below what
   the shadow map can resolve.

The ranked list is at the end ("Ranking"). Its top three are all shader-and-data changes: split the vanes,
gloss per species (the crow most of all), and bands in metres from the tip.

## The current look

Renders from `rig_gallery` at `--time 1.3`, studio light (sky ambient, sun with shadows, SSAO).

- **Hawk, folded, side.** The folded wing reads as a stack of whole, round-ended "tongues", each with a pale
  rim and one centred spot. The real folded wing is long narrow strips, the outer vanes, with stepped edges.
  The primaries show only as a thin striped sliver under the tertials.
- **Hawk, glide, top.**
  - The primaries are flat brown cards: no shaft, no dark tip, no change from vane to vane.
  - The secondaries' spots run in rows along each feather, so the wing reads as polka dots, not as bars.
  - The tail's subterminal band and tip work well.
- **Hawk, glide, under.**
  - The dark primary tips and pale flight feathers are right.
  - The flight feathers are opaque and uniformly pale. They have no silvery sheen and no translucency, and
    the barring is faint.
  - The under-coverts show regular rows of spot-and-ring marks.
- **Falcon, glide, under.** The bars cross each feather square, at the same *fraction* of each feather's
  length. So on primaries of different lengths they step from feather to feather instead of running as bands
  across the hand. Each primary ends in a dark blob.
- **Crow, folded, side.** Flat matte black. The feather rows show only as faint relief, with no gloss or sheen.
  This is the weakest of the five.

## Viewing distances in pixels

The chase camera sits `3.2 m × scale` behind and `0.9 m × scale` above the bird, where scale = span / 1 m,
clamped to 0.5-1.4. Its vertical field of view is 68°, widening to 95° with speed (`ChaseCamera`). At 1080p
one pixel covers about **1.25 mm per metre of distance** (2·tan 34° / 1080). At 95° it is about 2.0 mm/m.

| View | Distance | mm per pixel (1080p, 68°) |
|---|---|---|
| Close-up: the bird fills the screen (gallery, perched, photo mode) | about 0.4 m | about 0.5 (hawk), 0.15 (sparrow) |
| Chase camera, own bird | hawk 4.3 m, owl 3.8, crow 3.2, falcon 3.1, sparrow 1.7 | 5.4, 4.7, 4.0, 3.9, 2.1 |
| Another bird nearby | 5 m | 6 |
| Another bird across the clearing | 20 m | 25 |

**Rough feature sizes (hawk unless noted).**
- **Barbs.** 0.4-0.5 mm apart: flight feathers average 2.0-2.5 barbs per mm along the vane [BARON20].
- **Primaries.**
  - The rachis is roughly 3 mm wide at the base, under 1 mm near the tip.
  - An outer primary's outer vane is about 6-10 mm wide, its inner vane 20-30 mm.
  - The dark primary tips are 3-5 cm.
- **Secondaries.** The trailing-edge band is 1-2 cm, and the flight-feather bars are 2-5 mm wide, about 1 cm
  apart.
- **Tail.** The subterminal band is about 1-1.5 cm.
- **Fringes.** A sparrow tertial's rufous fringe is 2-3 mm.

These sizes are estimates from wing-chord measurements and photos, not measured here.

**Readability rule.** At normal contrast a mark reads at about 2 px or wider. A thin, high-contrast line still
reads as a smear down to about 0.5 px. Below about 0.25 px the mipmaps average it into the colour around it,
which is correct.

So:
- barbs never resolve, even in a close-up (about 1 px at best);
- a pale fringe or a rachis is sub-pixel from the chase camera;
- dark tips, trailing bands, emargination slots and moult gaps read at 20 m;
- gloss, sheen and translucency read at any distance.

## Item by item

Each item gives:
- **(a)** how visible it is at each distance;
- **(b)** which of the five species show it, and how;
- **(c)** a technique that fits the existing setup, with a rough cost.

### 1. The folded wing: outer vanes, stepped edges, primary projection

On a closed wing the feathers stack like a folded fan. The innermost tertial lies on top, and "only the outer
edges of the flight feathers are visible" [SIBLEY-TOPO]. What reads is a set of long parallel strips, each the
exposed outer vane of one feather:
- each strip's free edge is pale where the feather has a fringe;
- the strip is darker toward the shaft, and darkest where the feather above casts its shadow.

Narrow pale edges on secondaries and tertials merge into a pale streak along the closed wing. Broad pale edges
on greater coverts hide their dark centres [SIBLEY-Q21]. **Primary projection** is how far the primary tips
extend past the longest tertial [BTO-24][WIKI-FF]. The number of primary tips you can count beyond the tertials
is itself a field mark [BIRDING-AUS]. Emarginated primaries show as steps on the lower edge of the folded
wingtip [SIBLEY-BLOG].

- **(a)** It reads at every distance. The **projection** is part of the silhouette at 20 m: a hawk's 5-8 cm is
  2-3 px. The **strips** read from the chase camera, where an outer vane is 1-2 px plus a dark step line. The
  **fringes** read only in close-up.
- **(b)**
  - **Hawk.** Dark brown strips with faint buff edges. The wingtips fall a little short of the tail tip.
    (Harlan's hawk, with shorter primaries, "don't reach the tail" [WIKI-RT].)
  - **Falcon.** Long projection: the tips nearly reach the tail tip (from photos). Blackish primaries under
    blue-grey tertials, with faint pale fringes on fresh feathers.
  - **Owl.** The wingtips reach to or past the short tail (from photos). Buff and grey strips, finely marked.
  - **Crow.** Black strips that show only by gloss and the step shadow.
  - **Sparrow.** The strongest fringe look of the five: black-centred tertials and coverts with rufous or buff
    edges [ABSA-HS][BZ-HS]. The primaries' buff outer edges form a pale panel. The projection is short, about
    1-1.5 cm.
- **(c)** The geometry already stacks the cards in the right order: inner feathers on top, with
  `layer = 0.0004 * (10 - i)` for primaries (`WingShape.feathers`). What is missing is in the shading.
  - The outer vane gets its own colour and fringe (item 2).
  - The step shadow is drawn in the shader (item 4).
  - The centred spot is moved off the shaft for flight feathers, or dropped there (it is what makes the
    tertials read as "tongues").
  - Primary projection is `WingShape` geometry per species. Check it against photos when tuning, but it needs
    no texture work.

### 2. Outer vane against inner vane: colour and width

Each feather is "slightly darker on top and paler underneath". The two faces also show different vanes
[SIBLEY-WINGS]:

- **Above, outer vanes.** Each feather's outer vane lies over the inner vane of its outward neighbour. So the
  upperwing is mostly outer vanes.
- **Below, inner vanes.** The inner vanes dominate the underwing.
- **Patches split between the vanes.** A kingfisher's small white patch at the base of the primaries from
  above "is just the edge of a much larger white area on the inner webs" [SIBLEY-WINGS].
- **Width.** The outer vane is the narrow one. On secondaries the difference is slight; on raptor primaries
  the inner vane is "much wider" [FWS-GLOSS]. Narrow leading vanes also have smaller barb angles [FEO15].
- **Pigment.** Exposed, melanised keratin resists abrasion [BONSER][BURTT], and dark outer webs and wingtips
  are often explained that way.

- **(a)** It reads at every distance as the overall tone: a dark folded wing, a pale underwing, and pale
  windows. Per feather, it reads from the chase camera and closer, where the outer vane is 1-2 px against a
  4-6 px inner vane.
- **(b)**
  - **Hawk.** Primaries: dark brown outer vane; inner vane greyish, paling to whitish toward the base, with
    narrow dark bars. That gives a dark upperwing and a pale, finely barred underwing.
  - **Falcon.** Blackish outer vanes. The inner vanes carry pale oval spots between dark bars: Prum and
    Williamson's "rows of paired spots", a form of bar [PRUM02]. From below this reads as dense even barring,
    "plain greyish" at range [QA-PF].
  - **Owl.** Buff and grey outer vanes with dark marks; inner vanes paler, to white below.
  - **Sparrow.** Brown with a buff or rufous outer-vane edge.
  - **Crow.** Black on both vanes. The difference is gloss: the vanes catch light at different angles (item 6).
- **(c)**
  - **Shader.** The shader already knows which vane it is on: `us` against `cell_shape[ci].x`, the shaft.
    Add one per-row `vec4 vane[18]`:
    - outer-vane tint (rgb), and how much of it to apply;
    - optionally a second vec4 for an inner-vane base tint that fades in toward the feather base.
  - **Fringe.** Make the fringe vane-aware: edge distance × (outer ? 1 : inner amount). Sparrows and the
    tertials want the fringe mainly on the outer edge.
  - **Spots and bars.** Put them on one vane: the B mask already places flight-feather spots per vane. Scale
    them by vane, e.g. `spot_amount * (outer ? a.x : a.y)`.
  - **Cost.** About 6 ALU and one uniform array. Nothing to bake.
  - **Data.** `Plumage.TEXTURE` gains `vane: [outer colour, outer amount, inner colour, inner amount]` per
    group and face.

### 3. The rachis: how visible, above and below

- **(a)** The shaft is 1-3 mm wide.
  - **Close-up:** clearly visible, 2-6 px.
  - **Chase camera:** 0.2-0.6 px. It reads only where it contrasts: a pale or glossy shaft on a dark vane, or a
    dark shaft against the light.
  - **5-20 m:** invisible.
  - **Backlit:** the shaft is the thickest, most opaque line on the feather. It shows as a dark line at
    distances where it is invisible in front light [BIRDING] (and item 7).
- **(b)**
  - **Hawk, falcon.** Brownish horn above, lighter than the vane on dark primaries. Pale below. (From photos.)
  - **Owl.** Pale both sides.
  - **Crow.** Black and glossy: it shows as a highlight line, not as a colour.
  - **Sparrow.** Dark.
- **(c)**
  - **Tone.** The G mask and per-row `shaft` tone exist, so this is mostly data.
  - **Gloss.** Lower the roughness on the shaft: `ROUGHNESS = mix(vane_r, 0.4, t.g)`. Smooth keratin is
    glossier than the barb surface, and it gives the crow its shaft line.
  - **Transmission.** Use `1 - t.g` as an opacity term (item 7).
  - **Cost.** Nearly free. Mipmaps already fade the shaft at distance, which is correct: don't add a
    distance-independent line.

### 4. The stepped shadow each feather casts on the next

Where one feather overlies the next, its edge throws a narrow shadow, and the occluded vane sits a fraction
darker. Together that gives each strip of a folded wing a dark line beside it, and the rows read as steps. It
is a large part of the "every feather an individual" read in photos.

- **(a)**
  - **Close-up:** a 2-5 mm soft band.
  - **Chase camera:** a 0.5-1 px dark line per feather edge. This is what separates the folded wing's strips.
  - **Beyond:** it only darkens the wing a little overall.
- **(b)** All five species, folded wing and spread wing.
  - It is strongest on the folded wing and the closed tail.
  - It is weakest on a crow in direct light, where it is the only thing separating the feathers.
- **(c)** Real shadows can't do this.
  - **Why.** Our layers are 0.2-0.4 mm apart. The sun's shadow has `shadow_normal_bias = 0.6` and
    `shadow_bias = 0.02` (`Lighting.bird_shadows`), so a step that small never self-shadows. SSAO at 8 cm
    radius sees no depth step either.
  - **The atlas already darkens the base** (R: the row in front covers 34-45 % of the length). It needs the
    same across the vane.
  - **Bake a "cover" coordinate** into the free `atlas_n` B channel (it is 255 today): the distance across the
    inner vane from its free edge toward the shaft, 0..1.
  - **Shade with it.** Darken where `cover < c`, with a soft edge just past `c`:
    `shade *= mix(0.65, 1.0, smoothstep(c - 0.05, c + 0.12, cover))`. Here `c` is how much of the inner vane
    the neighbour hides.
  - **Where `c` comes from.** About 0.9 when folded, about 0.5 spread. It is zero past the emargination on
    slotted primaries, where the fingers separate.
  - **Feeding `c`.** Pass it per bird as a uniform driven by `fold` (each rig has its own `marks_material`, so
    this is free per instance). Optionally refine it per group with a per-row `vec2(c_spread, c_folded)`.
  - **Exact version.** Compute in `WingShape` where the neighbour's edge crosses each feather (a UV.x at 2-3
    stations along v) and pass it per instance.
    - `INSTANCE_CUSTOM` is full, but `.r` (row, 0..17) and `.b` (cell 0..15 and lead sign) are small integers.
      Packing them into one float frees a channel.
  - **Cost.** One texture channel already fetched, and 3 ALU. A rebake for the channel.
  - **Underside.** The step inverts, and in transmission the overlap darkens instead of shading (item 7).

### 5. The vane's cup and curvature, and its twist

- **Cup.** A flight feather is not flat. It is cambered along its length, and its vane curves down from the
  shaft toward the edges, convex above.
- **Twist.** Where the rachis sits ahead of the centre of pressure, the feather twists "like venetian blinds"
  under load [FEO14]. Spread outer primaries twist nose-down toward the tip in flight, so each finger is lit a
  little differently from its neighbours.

- **(a)**
  - **Close-up and chase camera:** a tone gradient across each 4 cm feather (8 px) and a lifted, shadow-casting
    edge. These separate neighbours.
  - **5 m:** the fingers' alternating tones.
  - **20 m:** only the silhouette.
- **(b)** All five. It is most visible on the hawk's and crow's slotted fingers and on the owl's broad, soft
  wing.
- **(c)**
  - **Today.** The cup is a shading-normal lean only (`cup` 0.35), plus a 3 % arch along the length (`CAMBER`).
    The card mesh has just two columns, the two edges (`BirdRig._feather_mesh`), so it can't bend across.
  - **Shaft column.** Add a third column of vertices on the shaft, at the cell's `asym` offset. That takes a
    card from 14 to 28 triangles.
  - **Cup in the vertex shader.** Drop the vertices off the shaft by `cup * UV.x²`, and mirror it on the under
    copy.
  - **Twist** about the shaft, growing toward the tip: `angle = twist * UV.y²`. Feed `twist` from the per-bird
    load or slot uniform, or put it in `bend`'s sign bits.
  - **Gains.** Real silhouettes at the wingtip. Edges that actually lift, so the sun's shadow can catch the
    larger steps. Normals that agree with the relief map.
  - **Cost.** About 7k more triangles per bird across both faces, which is negligible, and a few ALU in the
    vertex shader.

### 6. Specular sheen, and its anisotropy along the barbs

- **Black feathers, glossy and matte.** Black feathers have low diffuse reflectance, "all under 5 per cent".
  Matte species reach under 15 % specular at a 75° geometry, and glossy species "above 20 per cent"
  [MAIA10].
  - The **glossy** set includes the common raven, fish crow and turkey vulture.
  - The **matte** set includes the **house sparrow** [MAIA10].
  - Gloss comes from a thin, regular keratin cortex over a continuous melanin layer, and is "weakly chromatic
    iridescence" [MAIA10][SICB-GLOSS].
- **Silvery sheen on dark feathers.** It can come from "lengthened and twisted" distal barbules with a
  translucent upper side. It is fragile, and abrasion removes it [GALVAN09].
- **Anisotropy.** It is measured: reflectance is anisotropic, its direction changes across the vane, and it is
  predictable from the orientation of the barb's branches [HARVEY]. Maia's specular measurements had to rotate
  each sample "to the azimuth of maximum reflectance" [MAIA10].
- **What it looks like.**
  - The highlight stretches across the barbs, as on hair [PATENT-GEN].
  - The outer and inner vanes' barbs leave the shaft at different angles (24° and 40° in our atlas), so the two
    vanes catch the light at different view angles. One half of a feather flashes while the other stays dark.
  - **Underside.** The underwing's "pale silvery gray" [SIBLEY-WINGS] is this sheen at grazing angles on the
    paler inner vanes.

- **(a)** It reads at all distances, because it is a reflectance, not a feature size:
  - a gloss on a crow's back and wings at 20 m;
  - a silvery flash of the underwing when a hawk banks at 20 m;
  - the per-vane flicker from the chase camera.
- **(b)**
  - **Crow:** strong gloss (inferred from the raven and fish crow in [MAIA10]).
  - **Hawk, falcon:** moderate sheen on the flight feathers, mostly seen from below.
  - **Owl:** matte, from the velvety upper surface [BACHMANN07][SICB-OWL].
  - **Sparrow:** matte [MAIA10].
- **(c)**
  - **Per-row roughness and specular** (a `vec2` in a new per-row array, or the free `misc` space). This alone
    gives most of the payoff:
    - crow flight feathers: roughness 0.45-0.55, specular 0.5;
    - raptor undersides: 0.6, specular 0.45;
    - owl: 0.95;
    - sparrow: 0.9.
  - **Anisotropy** (Godot `ANISOTROPY` and `ANISOTROPY_FLOW`, a 2D direction in the card's tangent frame
    [GODOT-SS]).
    - Put the barb angles into the unused `cell_shape[ci].zw`.
    - In the fragment, `flow = normalize(vec2(sin(a) * side * lead, cos(a)))` with `a` the barb angle of the
      vane the fragment is on.
    - Set `ANISOTROPY` to about 0.4-0.6 on glossy rows and 0 on matte ones.
    - Check the sign both ways (the highlight must stretch across the barbs). The cards carry tangents (+X), so
      this needs no new vertex data.
  - **Cost.** About 5 ALU, and Godot's anisotropic GGX path.
  - **Risks.**
    - The parked `feather.gdshader`'s sheen "flooded". Keep the specular masked by the relief, and off on
      fringes for the owl.
    - Turn on `rendering/anti_aliasing/screen_space_roughness_limiter`. Glossy anisotropic shading on
      normal-mapped cards shimmers in motion.
  - **Kajiya-Kay.** A shifted-tangent highlight [SCHEUERMANN04] is the alternative if Godot's anisotropy looks
    wrong. It needs a `light()` function, and that replaces the whole lighting model for this shader: more work.

### 7. Translucency when backlit

- **Where light passes.** It comes through where "fewer layers of feathers" overlap and where the feathers
  carry less pigment [SIBLEY-T].
- **It depends on the sun.** It is brightest with the back square to the sun and gone at glancing angles
  [SIBLEY-T].
- **What blocks it.** The shaft shows as a dark line, and black feathers block far more than pale ones
  [BIRDING].
  - Melanin sits in the barbs' ramus [TRANSMIT], so dark bars stay dark against the light. Bars on the hidden
    face show through.
  - Overlaps show as darker bands: two layers.
- **Field marks.** A juvenile red-tail's ten primaries are paler than its secondaries and make a square,
  translucent panel, "the #1 field mark" [CFNO]. Owl flight feathers are measurably more translucent than a
  pigeon's [BACHMANN07].

- **(a)** It reads at all distances, but only when backlit. That means birds overhead against the sky, which
  is a common view of other birds at 5-20 m.
- **(b)**
  - **Hawk:** glowing flight feathers with dark tips, trailing edge and bars. The adult tail glows red from
    below; it is "light buff-orange below" in front light [WIKI-RT].
  - **Owl:** the whole wing glows warm white, with faint bars.
  - **Falcon:** grey, with the barring sharpened.
  - **Sparrow:** a little.
  - **Crow:** almost none. A faint brown glow at the thinnest wingtips (melanin blocks it).
- **(c)** Two options in Godot [GODOT-SS]:
  - **`BACKLIGHT`** (vec3): diffuse light received from behind. It is the cheapest: one output, a few ALU.
    Set `BACKLIGHT = transmit_colour * mask`.
    - The mask is `(1 - t.g)` (the shaft is opaque) × the pigment darkness (the strip's luminance; bars and
      dark tips block) × `(1 - covered)` (item 4).
    - The colour: the strip of the *other* face (`row ^ 1`, one more fetch) multiplied with this face's, so
      bars on either side show through.
    - Check whether the light's shadow attenuation zeroes it. Each card is shadowed by its own twin face.
  - **`SSS_TRANSMITTANCE_COLOR`, `_DEPTH`, `_BOOST`.** This uses the shadow map's depth to estimate the
    thickness toward the light. That suits stacked cards well: a feather under two others is "thicker" and
    darker, which is exactly Sibley's "fewer layers" rule. Depth a few mm.
    - Its cost is higher, but bounded, because only feather cards use it.
    - Try `BACKLIGHT` first. Keep `--sun back` in the gallery as the test view.
  - **Per species**, a per-row transmission amount: crow 0.05, hawk and falcon 0.5, owl 0.8.

### 8. Iridescence (the crow)

- **Hue.** The American crow is described as iridescent black [WIKI-AC]. A UV-inclusive study of 28
  specimens, however, says American crows "are not known for iridescence" of the purple or green kind seen in
  fish crows and grackles [YORZ].
  - Hue changes with age, on the sides, the back and under the tail.
  - The forehead is the blackest region and reflects least.
  - Yearlings' poor-quality feathers look brownish until their first moult [YORZ].
  - So the crow's look is a **gloss with a faint blue-violet cast**, not a rainbow.
- **Thin-film model.** It predicts gloss hues from UV-violet (100 nm cortex) to copper (180 nm) [MAIA10].

- **(a)** It reads at all distances, wherever the gloss does (item 6). The tint is subtle: visible on a
  highlight from the chase camera, not as colour patches at 20 m.
- **(b)** The crow only. No other of the five is glossy enough to matter.
- **(c)**
  - **Tint the specular without a `light()` function.** On crow rows set `METALLIC` to about 0.4-0.5 and
    `ALBEDO` to a dark blue-violet (about 0.06, 0.06, 0.11).
    - The diffuse becomes `albedo × (1 - metallic)`, still under 5 %.
    - F0 takes the blue tint, so highlights and sky reflections go blue-violet while the body stays black.
  - **Shift the hue a little with view.** Ramp the albedo from blue (facing) toward violet (grazing) with
    `dot(NORMAL, VIEW)`.
  - **Cost.** About 4 ALU.
  - **Physical version.** The Belcour-Barla thin-film microfacet model [BELCOUR17] in a `light()` function.
    Only worth it if the crow becomes a showcase.
  - **Wear.** Keep a per-feather wear value (item 9) that cuts the gloss and shifts the tint toward brown.

### 9. Wear, fraying, moult gaps

- **Wear.** Feathers are "essentially dead structures" that "become worn and abraded" [WIKI-FF].
  - Pale tips and fringes wear first [HW-TIPS].
  - The wingtip primaries lose the most vane [BURTT].
  - Juvenile feathers wear faster [WIKI-FF].
  - Crows look brown and dull in late summer before the moult, against glossy new feathers (several nature
    sources, low authority [NS-CROW]).
  - Fault bars are translucent stress lines across the vane, commonest on the tail and rarest on primaries
    [JOVANI].
- **Moult.**
  - Accipitrid raptors replace primaries from the inside out, from p1 outward.
  - Many retain some juvenile secondaries for an extra year [PYLE05].
  - A moulting red-tail flies with gaps, and adjusts its wing to close them [EARTH-RT].

- **(a)**
  - **Moult gaps:** missing or half-grown feathers, readable at 20 m as notches in the trailing edge in flight.
  - **Old-against-new contrast** (bleaching, lost gloss): chase camera and 5 m.
  - **Fraying, ragged tips, fault bars:** close-up only.
- **(b)** All five.
  - Strongest: crow (brown old feathers) and hawk (retained secondaries; a ragged trailing edge in summer).
  - Sparrow: fringes worn away by spring.
- **(c)**
  - **Per-feather `age` (0 new .. 1 worn)**, from the seed plus a per-individual seed. In the shader:
    - fringe width × (1 - age);
    - colour toward a bleached tone;
    - roughness up and specular down;
    - extra rag at the tip, from the A channel: raise the alpha cut-off near v = 1 with noise.
  - **Moult gaps** are geometry: in `WingShape`, per individual, skip one symmetric pair or shorten a growing
    feather.
  - **Cost.** Small, but it needs a per-instance value. Use the packed `INSTANCE_CUSTOM` slot from item 4, or
    derive `age` from the seed and a per-bird uniform.
  - **Hold it back.** It is realism for close inspection, and it multiplies tuning.

### 10. Emarginations and notches on the outer primaries

- **Terms.** An emargination is a gradual narrowing of the *anterior* (outer) vane. A notch is a distinct
  narrowing of the *posterior* (inner) vane [FWS-GLOSS]. A notch is abrupt and found only on the wider trailing
  edge [WIKI-FF].
- **Effect.** Together they make the "fingers" and slots of soaring birds [WIKI-FF].
- **Falcons.** Only one or two outer primaries are emarginated, near the tip [COUES]. Falcons show less than
  eagles because their primaries are already narrow [CONDOR-27].

- **(a)** It reads at every distance as silhouette slots on a spread wing, at 20 m. On the folded wing it shows
  as steps on the lower edge of the wingtip, from the chase camera and closer [SIBLEY-BLOG].
- **(b)**
  - **Hawk:** the outer 4-5 primaries emarginated; one source says the leading five [MTAUD-RT].
  - **Crow:** 5-6 deep fingers (from photos).
  - **Owl:** weak. Its barn-owl leading-edge comb is about 1-2 mm and close-up only [BACHMANN-SER].
  - **Falcon:** 1-2, slight.
  - **Sparrow:** none visible.
- **(c)**
  - **The outline is wrong today.** The `EMARG_PROFILE` narrows both edges together, at 0.55-0.62 of the
    length.
  - **Make it asymmetric in the atlas's A channel** (rebake only):
    - narrow the outer vane gradually over about 0.45-0.65 of the length;
    - step the inner vane down sharply at about 0.5.
  - **Mesh.** Keep the mesh outline as the envelope.
  - **Per-species finger count** is already `WingShape` data.
  - **Cost.** Zero at runtime.

### 11. The trailing-edge band and dark tips

- **What.** Dark tips on the secondaries make a dark band along the rear of the wing, and dark outer-primary
  tips make dark fingers [GT] (`plumage_coloring.md`).
- **Ageing.** The adult red-tail has the band. Juveniles lack it [CFNO].

- **(a)** It reads at every distance.
  - **Dark tips:** 3-5 cm, readable at 20 m.
  - **The band:** 1-2 cm; about 1 px at 20 m. Because it runs the whole span, it still reads as a dark edge
    line against the sky.
- **(b)**
  - **Hawk:** the band and dark tips, below and above.
  - **Falcon:** a subtle band; blackish wingtips above.
  - **Owl:** faint dark tips on some individuals [SWT-OWL].
  - **Crow, sparrow:** none.
- **(c)** It exists already (`bars_tip` and `subterm` in the strip), but keyed to the *fraction* of each
  feather's length. So the band is wider on longer feathers, and it steps where lengths change. Key it to
  **metres from the tip** instead (item 12). Width then stays constant along the trailing edge, as on a real
  wing.

### 12. Bars lining up across neighbouring feathers

- **On the bird.** Bars on adjacent flight feathers line up into continuous bands across the spread wing and
  tail (field guides and photos; within-feather bars and chevrons come from the growing follicle [PRUM02]).
- **Growth bars.** The faint alternating bands laid down during growth, about one pair a day [GROWTH], line up
  across feathers grown together.
- **Today.** The study already keeps bars in register by reading every feather at the same `UV.y`. That holds
  only where the neighbours are the same length.

- **(a)**
  - **Owl bars** (about 3 cm apart): readable to 10-20 m.
  - **Hawk flight-feather bars** (about 1 cm): readable from the chase camera, averaged to a mid-tone at 20 m.
  - **Falcon underwing:** reads grey beyond 10 m [QA-PF].
  - **Growth bars:** close-up only, and subtle. Skip them.
- **(b)**
  - **Owl:** about 4 broad bars on remiges and tail, as bands across the wing.
  - **Falcon:** fine, dense bands below; tail bands.
  - **Hawk:** fine bars on the flight feathers. A juvenile has about six tail bars [WIKI-RT].
  - **Crow, sparrow:** none.
- **(c)** Bands in **metres from the tip**.
  - **Feather length is free.** For a MultiMesh, `MODEL_MATRIX` includes the instance transform, so
    `len = length(MODEL_MATRIX[2].xyz)` is the feather's length in world metres. That needs no new instance
    data. Pass it as a varying. (Godot 4's scene shader folds the instance transform into `MODEL_MATRIX`
    before `vertex()`. Confirm it with a one-line debug colour before relying on it.)
  - **Key the strip** by `d = (1 - v) * len / band_scale`:
    - `band_scale` per species: hawk about 0.25 m, owl 0.3, falcon 0.2. It sets where along the strip
      texture a metre lands.
    - Or replace the bar pattern with an analytic bar: `fract(d / spacing)`, with spacing in metres per row.
  - **Secondaries** keep their fraction-based reading (they are near-equal in length). Primaries and the tail
    switch.
  - **Cost.** A few ALU.
  - **On the folded wing** the bands then run as slanted lines across the stack, which is also what real
    folded wings show.

### 13. The underwing

This sums up items 2, 6, 7, 11 and 12. From below you see:
- the inner vanes, paler;
- the under-coverts, a different set of feathers [SIBLEY-WINGS];
- the silvery sheen at grazing angles;
- dark tips and the trailing band;
- barring that averages to grey at range;
- translucency against the sky.

- **(b)**
  - **Hawk:** pale, finely barred remiges; dark tips and trailing edge; patagial bar and carpal comma
    [GT][WIKI-RT].
  - **Falcon:** evenly barred, grey at range [QA-PF].
  - **Owl:** white, nearly unmarked [WIKI-BO].
  - **Crow:** the flight feathers a little paler and greyer than the coverts, through gloss and thinner vanes
    (`plumage_coloring.md`).
  - **Sparrow:** plain greyish-buff.
- **(c)**
  - **Under-coverts.** The `under_covert_under` row's spot-and-ring look reads as rings in the render. Lower
    its fringe and `detail`, and use soft streaks instead of drops. The study already noted it.
  - **Silvery sheen.** Give the underside flight-feather rows a sheen: roughness about 0.6, specular 0.45,
    anisotropy 0.3.

### 14. The tail from above and below

- **Stacking.** A closed tail stacks like the wing: the central pair on top, the outer pairs below. From above
  you see the central pair and the outer vanes of the rest. From below you see the outermost pair's undersides.
- **Hawk:** "uniformly brick-red above and light buff-orange below", with a single dark subterminal band
  [WIKI-RT]. It glows red when backlit.
- **Falcon:** finely barred, with a black subterminal band and a white tip [WIKI-PF].
- **Owl:** short, buff, with a few bars.
- **Crow:** black, with a rounded fan.
- **Sparrow:** plain brown with paler fringes.

- **(a)** The spread tail's band and tip read at 20 m. The closed tail's stacked outer vanes read from the chase
  camera, which looks straight at the tail.
- **(c)**
  - **Already done.** The bands and tips exist, and the subterminal band works well.
  - **Add:** the vane split (item 2), with the closed tail's outer vanes slightly darker; translucency (item
    7); bands in metres from the tip (item 12); and the step shadow (item 4), using `tail_spread` the way the
    wing uses `fold`.
  - **Watch the tip.** The hawk's tip band reads as a zigzag in the top render: each rounded tip gets its own
    white crescent. Real white tips are about 3-5 mm and wear quickly. Narrow it.

### 15. What is *not* visible at these distances

- **Individual barbs** (0.4-0.5 mm) are at most about 1 px even in a close-up.
  - The atlas's 12 striations per half-width are about 4× coarser than real barbs. That is right: they stand
    for barb *clumping*, not barbs.
  - At the chase camera they average out through the mipmaps.
  - Never sharpen them, and keep the relief's barb term small (it already is: 0.006).
- **Barbules, hooklets, owl serrations, fault bars and growth bars** are close-up only, or not at all.
- **Pale fringes narrower than about 3 mm** vanish beyond the chase camera. **Vane splits** are close-up only.
- **The rachis on a front-lit bird** is invisible beyond about 5 m.
- **What survives at distance:** silhouette (projection, fingers, moult gaps), big marks (tips, bands, patagial
  bar), tone (vane split, countershading), and reflectance (gloss, sheen, translucency).
- **Practical consequence.** Fade `detail` (barbs, splits, rim) with the screen-space size of the feather,
  `fwidth(UV.y)`. Then a distant bird shows clean colour and light instead of mip-averaged noise. This is cheap
  insurance against the "masks read as noise at chase distance" failure the study warned about.

## Ranking: visual payoff per effort

| # | Item | Payoff (where) | Effort | Technique |
|---|---|---|---|---|
| 1 | **Outer and inner vane split** (items 1, 2, 13) | High: the folded wing's strips, the dark-above and pale-below wing, windows. All species, all distances. | Low | Per-row vane tints and vane-aware fringes and spots, from `us` against the shaft. One uniform array, about 6 ALU, `Plumage.TEXTURE` data. |
| 2 | **Gloss per species, and the crow's tinted sheen** (items 3, 6, 8) | High: the crow goes from matte plastic to a crow. Silvery raptor undersides. All distances. | Low | Per-row roughness and specular. Glossy rachis via `t.g`. Crow `METALLIC` about 0.45 on a dark blue-violet albedo, with a view ramp. |
| 3 | **Bands in metres from the tip** (items 11, 12, 14) | Medium-high: bars line up into bands, an even trailing edge, the falcon and owl underwing. | Low | Feather length from `MODEL_MATRIX[2]`. Strip or analytic bars keyed to `(1 - v) * len`. |
| 4 | **Stepped overlap shadow** (items 1, 4) | High at chase and close range: separates every strip of the folded wing and closed tail. | Medium | A baked cross-vane `cover` coordinate in `atlas_n.B`. A per-bird `fold` (and `tail_spread`) uniform sets the covered share. Exact version: per instance from `WingShape`. |
| 5 | **Translucency** (item 7) | High for birds overhead: hawk windows, the glowing red tail, the owl's glowing wing. | Medium | `BACKLIGHT` masked by the shaft, pigment and cover, tinted by both faces' strips. `SSS_TRANSMITTANCE` if layer thickness should count. |
| 6 | **Geometric cup and twist** (item 5) | Medium: real lifted edges and finger silhouettes; the sun's shadows start to catch steps. | Low-medium | A shaft column of vertices (14 to 28 triangles per card). Cup and twist in the vertex shader. |
| 7 | **Emargination and notch outline** (item 10) | Medium: the folded wingtip's stepped lower edge, finger shape. | Low | An asymmetric outline in the atlas's A channel: a gradual outer emargination and an abrupt inner notch. Rebake only. |
| 8 | **Anisotropic sheen along the barbs** (item 6) | Medium: vane-half flashes, the crow and raptor undersides in motion. | Medium (tuning, shimmer) | `ANISOTROPY_FLOW` from the barb angles in `cell_shape.zw`, per vane. The roughness limiter on. |
| 9 | Distance fade of fine detail (item 15) | Low-medium: cleaner distant birds, no noise. | Very low | Scale `detail` by `fwidth(UV.y)`. |
| 10 | Wear, bleaching and moult (item 9) | Medium at chase range (the crow's brown cast); moult gaps at 20 m. | Medium | Per-feather `age` (fringe, tint, gloss, ragged tip). Gaps in `WingShape`. |

Items 1-3 and 9 are shader and data only, with no bake. Items 4 and 7 share one rebake. Do 1 and 2 first and
render the folded hawk, folded sparrow and folded crow from the side, and the falcon from below, against
today's renders. Do 5 with `--sun back`.

## Sources

1. [SIBLEY-WINGS] David Sibley, *Wings, above and below* (blog): https://www.goodreads.com/author_blog_posts/2192451-wings-above-and-below
   (outer webs seen from above, inner from below; darker above and paler below; the kingfisher's inner-web
   patch).
2. [SIBLEY-TOPO] Sibley Field Guide topography illustrations, reproduced at
   https://swartzentrover.com/cotor/Photos/Hiking/Birds/BirdPages/Anatomy/Anatomy.htm (on a folded wing only
   the outer edges of the flight feathers show; the innermost tertial is on top).
3. [SIBLEY-Q21] David Sibley, *Quiz 21: Wing patterns*: https://www.goodreads.com/author_blog_posts/2287476-quiz-21-wing-patterns
   (pale edges merge on the closed wing; broad fringes hide dark centres).
4. [SIBLEY-BLOG] David Sibley's blog, page 17 (primary projection against the folded secondaries; emarginated
   primaries on the folded wingtip): https://www.goodreads.com/author/show/9798.David_Allen_Sibley/blog?page=17
5. [SIBLEY-T] David Sibley, *The finer points of wing translucence*: https://www.goodreads.com/author_blog_posts/1618561-the-finer-points-of-wing-translucence
   (fewer layers and less pigment; dependence on the sun's angle).
6. [BTO-24] BTO Field craft, summer 2024 (primary projection): https://ociweb.bto.org/sites/default/files/field_craft_bto_news_summer_2024.pdf
7. [BIRDING-AUS] Birding-Aus thread on primary projection and counting primary tips:
   https://www.cse.unsw.edu.au/birding-aus/2011-06/msg00057.html
8. [WIKI-FF] Wikipedia, *Flight feather* (emargination against notch; primary extension; wear; juvenile
   feathers): https://en.wikipedia.org/wiki/Flight_feather
9. [FWS-GLOSS] US Fish & Wildlife Service, *The Feather Atlas*, glossary and position guide (emargination:
   anterior vane; notch: posterior vane; raptor primaries' inner vanes much wider):
   https://www.fws.gov/Lab/featheratlas/glossary.php
10. [FEO15] Feo, Field & Prum (2015), *Barb geometry of asymmetrical feathers…*, Proc. R. Soc. B:
    https://pmc.ncbi.nlm.nih.gov/articles/PMC4345455/
11. [FEO14] Feo & Prum (2014), *Theoretical morphology and development of flight feather vane asymmetry…*, J. Exp.
    Zool. B 322 (the rachis ahead of the centre of pressure lets the feather twist like a venetian blind):
    https://prumlab.yale.edu/sites/default/files/feo_prum_2014.pdf
12. [BARON20] Baron, Trail & Patterson, *Computer-Aided Visual Analysis of Feathers* (VAIB 2020; 2.0-2.5 barbs
    per mm on flight feathers, 102 Feather Atlas scans): https://homepages.inf.ed.ac.uk/rbf/VAIB20PAPERS/vaibjb20.pdf
13. [MAIA10] Maia, D'Alba & Shawkey (2011), *What makes a feather shine? A nanostructural basis for glossy black
    colours in feathers*, Proc. R. Soc. B 278:1973-1980 (glossy and matte species; diffuse under 5 %, specular
    above 20 %; rotated to the azimuth of maximum reflectance; gloss as weak iridescence):
    https://pmc.ncbi.nlm.nih.gov/articles/PMC3107640/
14. [SICB-GLOSS] Maia, D'Alba & Shawkey, SICB abstract (thin-film cortex 110-180 nm): https://sicb.org/?p=24914
15. [HARVEY] Harvey, Bostwick & Marschner, *Spatially- and directionally-varying reflectance of milli-scale
    feather morphology*, SICB abstract (anisotropic; direction varies across the vane, predicted by barb branch
    orientation): https://sicb.org/?p=21098
16. [GALVAN09] Galván, Negro, Bortolotti & Margalida (2009), *On silver wings: a fragile structural mechanism
    increases plumage conspicuousness*, J. Avian Biol. (twisted distal barbules; sheen lost to abrasion):
    https://digital.csic.es/handle/10261/38925
17. [YORZ] Binghamton University news on Yorzinski & Clark, *Inter- and intra-individual variation in the
    feather coloration of American crows*, J. Avian Biol.:
    https://www.binghamton.edu/news/story/6207/beyond-black-research-explores-the-feather-color-of-american-crows-as-seen-by-crows
18. [WIKI-AC] Wikipedia, *American crow*: https://en.wikipedia.org/wiki/American_crow
19. [NS-CROW] Moulting crows looking brown and patchy (nature columns; low authority):
    https://www.newwestrecord.ca/local-news/this-is-the-reasons-crows-are-looking-ruffled-and-patchy-lately-5804530 ;
    https://naturesmart.com/molting/
20. [BACHMANN07] Bachmann et al. (2007), *Morphometric characterisation of wing feathers of the barn owl and the
    pigeon* (owl feathers more translucent, longer pennula):
    https://typeset.io/papers/morphometric-characterisation-of-wing-feathers-of-the-barn-2bkm7x3179
21. [SICB-OWL] Bachmann et al., *The silent flight of owls*, SICB abstract (velvet-like upper surface):
    https://sicb.org/?p=24405
22. [BACHMANN-SER] Bachmann, Wagner & Tropea, leading-edge serrations of the barn owl wing:
    https://pmc.ncbi.nlm.nih.gov/articles/PMC3390528/
23. [BIRDING] *Birds and light: translucency* (blog; the shaft dark, melanin blocks):
    https://birdingimagequalitytool.blogspot.com/2014/11/birds-and-light-translucency.html
24. [TRANSMIT] Pigment in the barb's ramus; reflectance and transmission of feathers:
    https://pmc.ncbi.nlm.nih.gov/articles/PMC8331237/
25. [CFNO] Juvenile red-tail field marks (the translucent primary panel; juveniles lack the dark trailing edge;
    blog): https://cfno.blogspot.com/2013/09/in-flight-field-marks-of-juvenile-red.html
26. [WIKI-RT] Wikipedia, *Red-tailed hawk* (tail brick-red above, buff-orange below; one subterminal band;
    juvenile about six bars): https://en.wikipedia.org/wiki/Red-tailed_hawk
27. [GT] Green Timbers, *Red-tailed Hawk* (patagial bar, comma, dark tips and trailing edge):
    https://www.greentimbers.ca/vegetation-wildlife/wildlife/birds/red-tailed-hawk/
28. [MTAUD-RT] Raptors on the Wing (Wetlands Institute; the leading five primaries emarginated):
    https://wetlandsinstitute.org/wp-content/uploads/2024/10/Raptors-on-the-Wing-Branching-Activities.pdf
29. [WIKI-PF] Wikipedia, *Peregrine falcon*: https://en.wikipedia.org/wiki/Peregrine_falcon
30. [QA-PF] Qatar e-Nature, *Peregrine* (the barred underwing reads plain greyish): https://enature.qa/specie/falcon-peregrine
31. [COUES] Coues via Birding-Aus (falcons: one or two outer primaries emarginated near the tip; terminology):
    https://www.cse.unsw.edu.au/birding-aus/1998-05/msg00107.html
32. [CONDOR-27] *The Condor* 29(1):17-18 (falcons show less emargination than eagles):
    https://sora.unm.edu/sites/default/files/journals/condor/v029n01/p0017-p0018.pdf
33. [WIKI-BO] Wikipedia, *Western barn owl*: https://en.wikipedia.org/wiki/Western_barn_owl
34. [SWT-OWL] Sussex Wildlife Trust, *How to identify owls*: https://sussexwildlifetrust.org.uk/news/how-to-identify-owls
35. [ABSA-HS] Australian Bird Study Association, sparrow identification: https://www.absa.asn.au/wp-content/uploads/2014/12/B4360.pdf
36. [BZ-HS] Blasco-Zumeta, *House Sparrow* ageing and sexing: https://www.blascozumeta.com/specie_files/15910_ENG_Passer_domesticus_aranzadi.pdf
37. [BONSER] Bonser (1995), melanin and abrasion, *Condor* 97: https://sora.unm.edu/sites/default/files/journals/condor/v097n02/p0590-p0591.pdf
38. [BURTT] Burtt's melanin-abrasion work as summarised in *Are melanized feather barbs stronger?*, J. Exp.
    Biol. 207:285 (wingtip primaries lose the most vane): https://cob.silverchair.com/jeb/article/207/2/285/2620/Are-melanized-feather-barbs-stronger
39. [HW-TIPS] HawkWatch International, *Black wing tips*: https://hawkwatch.org/?p=8863
40. [PRUM02] Prum & Williamson (2002), *Reaction-diffusion models of within-feather pigmentation patterning*,
    Proc. R. Soc. B 269:781-792 (bars, chevrons, paired spots, dot arrays, and transitions between them):
    https://pmc.ncbi.nlm.nih.gov/articles/PMC1690965/
41. [GROWTH] Growth bars and ptilochronology (*The Auk* 106; one dark-light pair per day of growth):
    https://sora.unm.edu/sites/default/files/journals/auk/v106n02/p0314-p0320.pdf
42. [JOVANI] Fault bars: Jovani & Blas (2004) and later work, as summarised in *PeerJ*:
    https://peerj.com/articles/814
43. [PYLE05] Pyle (2005), *Remigial molt patterns in North American Falconiformes*:
    https://www.birdpop.org/docs/pubs/Pyle_2005_Remigial_Molt_Patterns_in_NA_Falconiformes.pdf
44. [EARTH-RT] Red-tailed hawks adapt their flight to missing feathers (UC Davis study, press summary):
    https://www.earth.com/news/red-tailed-hawks-adapt-their-flight-to-overcome-missing-feathers/
45. [PATENT-GEN] *Digital generation, placement, animation and display of feathers*, US patent 7427991 (the
    specular anisotropic along the barbs): https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/7427991
46. [GODOT-SS] Godot spatial shader reference (`ANISOTROPY`, `ANISOTROPY_FLOW`, `BACKLIGHT`,
    `SSS_TRANSMITTANCE_*`, `light()`): https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html
47. [SCHEUERMANN04] Scheuermann, *Practical Real-Time Hair Rendering and Shading*, SIGGRAPH 2004 sketch (a
    Kajiya-Kay shifted-tangent highlight): https://history.siggraph.org/wp-content/uploads/2022/12/2004-Talks-Scheuermann_Practical-Real-Time-Hair-Rendering-and-Shading.pdf
48. [BELCOUR17] Belcour & Barla (2017), *A Practical Extension to Microfacet Theory for the Modeling of Varying
    Iridescence*, ACM TOG 36(4): https://hal.archives-ouvertes.fr/hal-01518344v2
49. [BB11] Barré-Brisebois & Bouchard, *Approximating Translucency for a Fast, Cheap and Convincing
    Subsurface Scattering Look*, GDC 2011 (the cheap thickness-based translucency behind item 7's options):
    https://ea.com/frostbite/news/approximating-translucency-for-a-fast-cheap-and-convincing-subsurface-scattering-look
50. Within the repo:
    - `feather_texture_study.md` (the atlas, the layer shadow, the parked sheen);
    - `feather_rendering.md` (effects and their causes);
    - `plumage_coloring.md` (species marks and the sources behind them).

**Source quality.**
- **Primary and peer-reviewed:** [MAIA10], [FEO14], [FEO15], [PRUM02], [BONSER], [BURTT], [PYLE05],
  [BELCOUR17], [GALVAN09] (abstract and press only), [BACHMANN07] (abstract only).
- **Abstracts only:** [HARVEY], [SICB-GLOSS] and [SICB-OWL] are conference abstracts with no numbers.
- **Field guides and authors:** Sibley's blog posts.
- **Blogs and low authority:** [CFNO], [BIRDING], [NS-CROW].
- **Not from a written source** (photos, or estimates from wing chord): the per-species primary-projection
  lengths, the crow's and owl's finger counts, the rachis tones, and every feature size in "Viewing distances".
- **All About Birds** ID pages refused automated fetches (HTTP 403), as they did for `plumage_coloring.md`.
- **Conflict on the crow.** [WIKI-AC] calls it iridescent black, while [YORZ] says it lacks the purple-green
  iridescence of fish crows. The doc takes the middle: a gloss with a faint blue-violet cast.
