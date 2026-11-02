# Legs and feet: bones, feathering, scales, pads, talons and colour

What the visible leg and foot of Flap's five species look like, with measurements: how long the two leg bones are,
how far the feathers come down, what covers the bare skin, the toe pads, the claws, and the colours. It checks
the unsourced leg numbers in `BodyShape.DATA` (`scripts/bird/body_shape.gd`) and ends with what a game-scale model
should show. Companion notes:
- `body_anatomy.md` §4–6: the leg bones, the "backward knee", toe arrangements, the tendon lock and the grip.
- `body_poses_and_folded_wings.md` §3: legs and toes when perched.
- `landing_and_takeoff.md`: the legs at touchdown and take-off.
- `plumage_coloring.md` §5: the per-species colour specs; it already gives leg and foot hexes for three species.

The five species stand for: **crow** = American crow; **owl** = a barn owl × great horned owl blend; **hawk** = Red-tailed
hawk (light morph); **falcon** = adult Peregrine; **sparrow** = House sparrow (`bird_aerodynamics_by_species.md`,
`plumage_coloring.md`).

Tags:
- **[S]** sourced from a paper, a museum or university page.
- **[W]** sourced from Wikipedia or a reference site only, or from a search summary of a page we could not open.
- **[E]** our own estimate, not sourced.

Source numbers such as [3] refer to the list at the end. **Sites that refused automated fetches:** the Royal BC
Museum's Bones index page (403; its two raptor list pages loaded), Britannica (403), the HAL archive (bot wall),
`onthewingphotography.com` (403), the UMass "Falcon Project" open book (403). The old USGS Patuxent ID pages and SORA
PDFs now redirect to landing pages. Claims from them rest on search summaries and are tagged **[W]**.

---

## 1. Bone and toe lengths

### 1.1 What is measured
- **Bone length** is the greatest length of the dry bone (tibiotarsus, tarsometatarsus) [1][2]. **[S]**
- **"Tarsus" in field guides** is measured on the skin, from the notch at the back of the intertarsal joint to the
  joint between the tarsus and the toes [10]. It is close to the tarsometatarsus bone. For male American barn owls, live tarsus 77.6 mm, against 74.2 mm mean bone length for the
  Yale *Tyto alba* specimens [1][7]. **[S]**, different birds, so only roughly comparable.
- **Body length L.** In `BirdProfile` the `body_length` is close to the field-guide total length (bill tip to tail
  tip): crow 0.45 m against 40–53 cm, hawk 0.55 m against 45–65 cm, sparrow 0.15 m against 14–18 cm [3][8][9]. So the
  fractions below are of the real **total length**, which is what `BodyShape`'s fractions of L amount to. **[E]**

### 1.2 Measured bones
| Species | Tibiotarsus (mm) | Tarsometatarsus (mm) | Field "tarsus" (mm) | Source / tag |
|---|---|---|---|---|
| Red-tailed hawk | **110** mean (103–117, n = 8); BC key 100–123 | **82.5** mean (74–88, n = 8); BC key 77–94 | 75–96; subspecies means 82–93 | [1][2] **[S]**; [3] **[W]** |
| Peregrine | BC key 74–98 (mid 86) | BC key 44–59 (mid 51.5) | 45–56 | [2] **[S]**; [4] **[W]** |
| Prairie falcon ♂ (stand-in, 560 g) | 76.2 | 50.7 | — | [1] **[S]** |
| Great horned owl | **124** mean (119–129, n = 5); BC key 114–130 | **64.3** mean (61–68, n = 5); BC key 57–67 | 54–80 | [1][2] **[S]**; [5] **[W]** |
| Barn owl (*Tyto alba*, Yale) | **104** mean (99–111, n = 5); BC key 89–116 | **74.2** mean (68–79, n = 5); BC key 61–83 | ♂ 76–78 | [1][2][7] **[S]** |
| American crow | not found; **80–90** | not found | 55–65 | [8] **[W]**; tibia **[E]** |
| House sparrow | not found; **27–29** | not found | 16–25; 19.3 (one ♂); mean 20.2 (n = 42) | [9] **[W]**; [10] **[S]**; tibia **[E]** |

The crow and sparrow tibiotarsi are our estimates: the field tarsus times about 1.4–1.5, the ratio the raptors
above and other perching birds show. No passerines are in the Field et al. dataset [1]. A corvid osteology
(Tomek & Bocheński 2000, *The Comparative Osteology of European Corvids*) has crow bone lengths, but we could not
read it. **[E]**

Femurs, for completeness: Red-tail 84 mm, great horned owl 85 mm, barn owl 60 mm [1]. That is 0.15–0.17 of total
length, against `BodyShape.FEMUR` = 0.09 L. The femur is hidden inside the body (`body_anatomy.md` §4), so this
matters only for where the knee sits. **[S]** for the lengths.

### 1.3 As fractions of total length, against `BodyShape.DATA`
Real fractions use the middle of each total-length range: crow 46.5 cm, barn owl 36 cm (33–39 **[E]**: western birds
33–35 cm [6], American ones larger), great horned owl
53.5 cm (43–64), Red-tail 55 cm, Peregrine 46 cm (34–58), sparrow 16 cm [3][4][5][6][8][9].

| Species | Real tib / L | Real tars / L | Real tib : tars | Rig tib / tars (fraction of L) | Rig in mm (L) | Verdict |
|---|---|---|---|---|---|---|
| Crow | ~0.18 **[E]** | **0.13** | ~1.4 **[E]** | 0.18 / **0.20** | 81 / 90 (0.45 m) | Tarsus about 50 % too long |
| Owl: barn | 0.29 | 0.21 | 1.41 | 0.16 / 0.14 | 61 / 53 (0.38 m) | Both bones short for a barn owl |
| Owl: great horned | 0.23 | 0.12 | 1.93 | (same) | (same) | Tib short; tarsus about right |
| Hawk | 0.20 | 0.15 | 1.34 | 0.17 / 0.17 | 94 / 94 (0.55 m) | Tarsus ~15 % long, tib ~15 % short |
| Falcon | 0.19 | 0.11 | 1.67 | 0.16 / 0.15 | 67 / 63 (0.42 m) | Tarsus ~35 % long |
| Sparrow | ~0.17 **[E]** | 0.12 | ~1.45 **[E]** | 0.16 / 0.14 | 24 / 21 (0.15 m) | Tarsus slightly long |

Tags: the real fractions are **[S]** where the lengths are, divided by a **[W]** total length; they carry the spread
of both (sex, subspecies, how a specimen was stretched), so treat them as ±15 %.

- **The rig's tarsus is too long relative to its tibiotarsus in every species.** Real tib : tars ratios run 1.3–1.9;
  the rig's run 0.9–1.15. The crow and falcon are furthest off. **[S]** for the real ratios.
- **The owl blend is the hard case.** The barn owl is a long-legged bird (tarsus 0.21 of total length); the great
  horned owl a short-shanked, heavy-thighed one (0.12). `BodyShape` must pick. At L = 0.38 m, a barn-owl-sized bird,
  0.16–0.18 for the tarsus is a fair compromise. **[E]**
- **Suggested values** (tib / tars, fraction of L): crow 0.19 / 0.13, owl 0.25 / 0.16, hawk 0.20 / 0.15,
  falcon 0.19 / 0.12, sparrow 0.18 / 0.12. **[E]**, from the table. A longer tibiotarsus mostly changes where the knee
  and hip sit, since it is hidden in feathers (§2); it also raises the perched body unless the pose bends more.

### 1.4 Toes and foot size
| Species | Middle toe (D-III) | Hallux claw | Other | Tag |
|---|---|---|---|---|
| Red-tailed hawk | 38–54 mm, without the talon | 24–34 mm (the largest talon) | — | [3] **[W]** (citing Hull et al. 2008; Preston & Beane 2009) |
| Peregrine | not found; long (falcons have an elongate D-III) | not found | "very big feet" at all ages | [11][30] **[S]** |
| Great horned owl | not found | not found | foot span, talon to talon, about 20 cm | [5] **[W]** |
| Barn owl | not found | ♂ 19.1–19.6 mm (hallux talon) | — | [7] **[S]** |
| American crow | not found | not found | — | — |
| House sparrow | 11.5–12.4 mm (two birds); 12.9 mm (one) | — | middle claw 3.5 mm (arc), mean 4.4 mm (n = 20); hind + middle toe spread, claws included, 24–25 mm | [10] **[S]** |

- **Owls have shorter, more robust toes** than other raptors, especially digits III and IV, which Fowler et al. link to
  grip strength [11]. **[S]**
- **Falcons have an elongate middle toe and relatively narrow toes**; so do *Accipiter* hawks [11]. "Falcons have flat
  feet and relatively long, thin toes" [17]. **[S]**
- **Against the rig.** `BirdRig` draws the three front toes at 0.07 L and the hallux at 0.05 L, so the sparrow's
  stretched span is about 0.12 L = 18 mm against a real 24–25 mm (0.16 L) [10]. The Red-tail's middle toe alone is
  0.07–0.10 of total length before its talon is added [3]. **The rig's toes are roughly 30–40 % short.** **[E]** from [3][10].

## 2. How far the feathers come down

| Species | Thigh ("trousers", "flags") | Tarsus | Toes | Tag |
|---|---|---|---|---|
| Red-tailed hawk | Feathered to the intertarsal joint; the flags hang over the top of the tarsus | Bare and yellow below the joint | Bare | [3][23] **[W]** |
| Rough-legged / Ferruginous hawk (contrast) | Feathered | Feathered to the toes ("hare-foot", *lagopus*) | Bare | [23] **[W]** |
| Peregrine | Feathered, barred in adults | Bare, "feathered but a little way down in front" | Bare | [25] **[W]**; the tarsus quote is from a search summary of an old key, unverified |
| Great horned owl | Feathered | Feathered | **Feathered**; "the second-longest" foot feathers of any owl, after the snowy owl | [5] **[W]** |
| Barn owl | Feathered ("dangling, feathered legs") | Feathered; the feathered share of the tarsus is 0.94–0.98 | Bare with bristles ("toes hairy") | [6][7][22] **[S]/[W]** |
| Crow, sparrow | Feathered to about the intertarsal joint | Bare | Bare | **[E]** from photographs |

- **Hawks.** The bare tarsus is the Red-tail's field mark against the Ferruginous hawk, which, like the Rough-legged
  hawk, is feathered to the toes; these are the only two North American hawks that are [23]. **[W]** Old keys give
  *Buteo* "tarsi ... naked ... or feathered to the toes" and *Circus* "feathered a little below the joint" [22]. **[S]** (1835)
- **The Red-tail's trousers.** Western (*calurus*) rufous and dark birds have heavily barred thighs; eastern juveniles
  have dark-spotted leg feathers [3]. **[W]** Light-morph eastern adults show pale, lightly marked leg feathers. **[E]**
  from photographs.
- **The Peregrine's trousers.** Adults are described with a "barred belly and legs", the bars running on to the thighs;
  females are more heavily barred [25]. **[W]**
- **Owls vary.** The 1835 keys already separate them: eagle owls "feathered to the claws", scops owls "tarsi feathered:
  toes naked", the barn owl "toes hairy; middle claw serrated beneath", others "toes either feathered or hairy" [22].
  **[S]** (1835, names as then used). The great horned owl's feathered feet range from white to buff to tawny or mottled
  dusky by subspecies; the skin under them is black [5]. The barn owl's tarsal feathers run from white to reddish buff by
  subspecies [6]. **[W]**
- **The barn-owl ratio.** Daugherty et al. give a "feathered tarsus ratio" of 0.94 (museum) and 0.98 (live) for male
  American barn owls [7]. The table does not define it; we read it as the feathered share of the tarsus length. **[S]**
  for the numbers, **[E]** for the reading.
- **Where the line falls on bare-legged birds.** On the hawk, falcon, crow and sparrow the tibial feathers end at or
  just over the intertarsal joint; in a perched bird the belly and thigh feathers usually hide the joint itself
  (`body_poses_and_folded_wings.md` §3). **[E]** from photographs, **[S]** for the hidden knee.

## 3. The podotheca: scutes and reticulate scales

The **podotheca** is the horny keratin sheath of the lower leg and toes; it is not part of the skeleton [21]. **[W]**

| Scale type | What it is | Where | Tag |
|---|---|---|---|
| **Scutes** (scutellate) | Large, overlapping transverse plates | The front (acrotarsium) of the tarsus and the tops of the toes | [20] **[W]** |
| **Scutellae** | Smaller scutes | Along the sides of the tarsus and toes | [20] **[W]** |
| **Reticulate scales** (reticulae) | Small, non-overlapping polygonal scales; on the sole, small keeled bumps | The sole; the back of the tarsus in many birds; the whole tarsus in some | [20] **[W]** |
| **Booted** tarsus | The front scutes fused into one undivided plate, with two long plates behind | Many songbirds (e.g. thrushes, the robin) | [26] **[W]** |
| **Spicules** | Sharply pointed reticulate scales on the sole | Osprey; "widespread among grasping raptors (e.g., falconids, accipitrids)" | [16] **[S]** |

- **Development.** Foot scales evolved secondarily by suppressing the feather programme; unblocked, feathers grow
  instead of scales on the tarsus and toes. Reticulae are pure alpha keratin and may be highly truncated feathers
  [20] (citing Sawyer & Knapp 2003; Dhouailly 2009). **[W]**/[S] secondhand.
- **Oscines.** In most songbirds the back (plantar) surface of the tarsus is bilaminate: two long plates [26]. A booted
  tarsus is a single plate of fused scutes over the front, "always accompanied by" the pair of plantar plates [26].
  **[W]** (Britannica and a 1959 *Wilson Bulletin* paper, both from search summaries)

**Per species:**

| Species | Front of tarsus | Back of tarsus | Toes (top) | Sole | Tag |
|---|---|---|---|---|---|
| Hawk (*Buteo*) | Scutellate: a row of transverse scutes | Reticulate | Scutes, about one per phalanx, widest near the claw | Reticulate pads with spicules | [22] **[S]** (1835, genus level); [16] **[S]**; rest **[E]** |
| Accipiter (contrast) | Scutellate, but in *Accipiter* "the sutures of the scales obsolete": it looks smooth and booted | — | — | — | [22] **[S]** (1835) |
| Falcon (*Falco*) | **Reticulate**: small hexagonal scales all round ("acrotarsia reticulated") | Reticulate | Scutes | Reticulate with spicules | [22] **[S]**; [16] **[S]**; toes **[E]** |
| Owl | Feathered (§2) | Feathered | Feathered (great horned) or bristled, with a few scutes at the tips (barn) | Reticulate, papillate pads | [5][22]; sole **[E]** |
| Crow | Scutellate: a row of large plates | Two long plantar plates (oscine) | Scutes | Flat reticulate pads | [26] **[W]**; front **[E]** from photographs |
| Sparrow | Scutellate, finer | Two long plantar plates (oscine) | Scutes | Flat reticulate pads | [26] **[W]**; front **[E]** from photographs |

Lucas & Stettenheim's *Avian Anatomy: Integument* (1972) is the standard reference for this terminology [27]; we found
only catalogue records, not its text.

## 4. Toe pads, phalanges and toe arrangement

- **Phalanx counts.** Toes I–IV have 2, 3, 4 and 5 phalanges in a typical perching bird; the claw sits on the last
  phalanx of each toe [21]. **[W]** All five of our species follow it. **[E]**
- **Pads at the joints or between them.** Pittman et al. (2022) contrast **arthral** pads, aligned with the
  interphalangeal joints and "characteristic of the raptorial species", with **mesarthral** pads, aligned with the
  phalanx itself and found in non-raptorial birds. Pad position "appears to be driven by prey choice and feeding
  behaviour rather than common ancestry" [16]. **[S]**
- **Pad shape.** Well-developed, protrusive pads are found mainly in birds that hunt with their feet; perching and
  ground birds have flattened pads [16]. **[S]** So the hawk, falcon and owl toes read as a string of bulging knuckle
  pads, the crow's and sparrow's as a flatter, evenly padded sole. **[E]**
- **The metatarsal pad.** A single central pad under the joint of the toes and tarsus, where the toes meet **[E]**.
  Overgrown talons can puncture it [17]; under it, organised fat lies only in falcons and owls, and its main artery wraps round
  it in falcons and owls but runs straighter in goshawks and buzzards [18]. **[S]** (the [18] detail from a search
  summary of the paper; the abstract confirms the study)
- **Sole skin and perching.** In 21 species from 17 families, the sole's scales are part of the perching adaptation
  together with partial fusion of the toe bases (syndactyly), which enlarges the sole [19]. **[S]** (abstract only)
- **Toe arrangement.** Anisodactyl (3 + 1) in the crow, sparrow, hawk and falcon; the owl's outer toe IV swings back
  for a 2 + 2 grip, as in the Osprey (`body_anatomy.md` §5) [17][21]. **[S]/[W]** Owls and Ospreys are "the only raptors
  whose outer toes are reversible" [24]. **[W]**
- **How the toes wrap.** See `body_anatomy.md` §6 and `landing_and_takeoff.md` §3: the grip is active, and sleeping
  starlings balance on the central pad with the toes largely open. **[S]**

## 5. Claws and talons

### 5.1 Relative size by toe (Fowler et al. 2009)
Outer-arc length of each talon divided by that of digit IV, family means [11]. **[S]**

| Group (n species) | D-I (hallux) | D-II (inner) | D-III (middle) | D-IV (outer) | Reading |
|---|---|---|---|---|---|
| Accipitridae (15) | **1.80** | **1.65** | 1.20 | 1 | Hallux and inner talons "hypertrophied", to restrain large struggling prey |
| Falconidae (4) | 1.27 | 1.13 | 1.11 | 1 | "Smaller, subequally sized talons"; the kill is made with the bill's tomial tooth |
| Strigiformes (9) | 1.05 | 1.19 | 1.16 | 1 | Near-uniform talons |
| Pandionidae (1) | 0.95 | 0.90 | 0.92 | 1 | All talons enlarged and strongly recurved |
| Non-raptors (8) | 1.31 | 1.08 | 1.29 | 1 | Middle and hind claws largest |

- **Falcons kill with the bill**, biting the neck with the tomial "tooth"; they may also strike with a clenched foot
  [11][4]. **[S]/[W]**
- **Shape, not just size.** In a 3-D study of hallux talons, raptors that take larger prey have longer, more curved
  talons; falcons sit in their own region of shape space with higher stress along the curve, consistent with killing
  by bill; the barn owl's talon is distinctive, with a large flexor tubercle [12]. **[S]**

### 5.2 Curvature
- **Owls are less hooked.** Inner curvature of the D-II talon: owls 92° (s.d. 17°) against 113° (s.d. 16°) for hawks,
  falcons and Osprey together; the Osprey's outer arc is 166°, inner 156° [11]. Falcons have the highest inner
  curvature among raptors [11]. **[S]**
- **Perchers and raptors overlap.** Outer curvature of the middle claw does not separate predatory from perching birds;
  climbers are more hooked, ground birds less [13]. Pike & Maitland measured 120 species: claw radius scales with
  mass^0.34, and claw angle rises with mass in predatory and climbing birds but not in perching ones [14]. Owl talons
  differ in geometry from hawks' and non-raptors', with falcons intermediate [15]. **[S]** ([14][15] abstracts only)
- **For the rig:** an arc of about 90° for owls, 110–120° for hawk and falcon talons and the crow's and sparrow's
  claws (which are perching claws of similar hook). **[E]** from the above.

### 5.3 Cross-section and colour
- **Cross-section.** A bony core (the ungual phalanx) under keratin sheets [17]. **[S]** Raptor talons are laterally
  compressed, with a narrow, sharp underside. **[E]** from photographs. The Osprey's are "rounded, rather than grooved"
  underneath, with backward-facing scales [24][22]. **[S]/[W]** The barn owl's middle talon has a comb-like ("pectinate", "serrated beneath") inner edge
  [17][22]. **[S]**
- **Colour.** Peregrine claws black [4]; great horned owl talons "dark gunmetal-gray", like the bill [5]; barn owl talons
  black [6]; crow legs and feet black [8]. **[W]** Red-tail talons black, sparrow claws dark horn-brown. **[E]** from photographs.

### 5.4 Talon lengths we have
Red-tail hallux claw 24–34 mm [3] **[W]**; barn owl hallux talon about 19–20 mm (males) [7] **[S]**; sparrow middle
claw 3.5–4.4 mm [10] **[S]**. Not found: Peregrine, great horned owl, crow. Using Fowler's ratios, the Red-tail's middle
talon is about two-thirds of its hallux talon (1.20 / 1.80), so roughly 16–22 mm. **[E]**

## 6. Leg and foot colours

The bird's bare skin colours (cere and eye-ring excluded). Hexes are approximate sRGB for our matte material, as in
`plumage_coloring.md` §5; where that note already set one, it is repeated here.

| Species | Tarsus and toes | Claws | Leg feathers (trousers) | Tag |
|---|---|---|---|---|
| Crow | Black `#121214` | Black `#0e0e10` | Black, as the belly `#1f1f24` | colour [8] **[W]**; hexes **[E]** (legs from `plumage_coloring.md`) |
| Owl (blend) | Feathered pale buff `#e6d8bd` (barn: white to reddish buff; great horned: white, buff or tawny); bare toe bits and bristles pinkish grey `#958280` | Blackish grey `#2e3035` (barn black, great horned gunmetal) | As the tarsus | [5][6] **[W]**; hexes **[E]** |
| Hawk | Yellow `#e3c04a` | Black `#161514` | Light-morph eastern adult: pale `#e2d4bc` (lightly barred, averaged); western *calurus*: barred rufous, averaged `#b48c6a` | [3] **[W]**; hexes **[E]** (yellow from `plumage_coloring.md`) |
| Falcon | Adult yellow `#e8c547`; juvenile greenish yellow `#c6c27a` | Black `#141416` | Barred white and black, averaged `#bdb6ae` (as the belly in `plumage_coloring.md`) | [4][25][28] **[W]**; hexes **[E]** |
| Sparrow | Pinkish brown `#b38b7c` | Dark horn `#4e423a` | As the flanks `#b7ae9d` | "pink legs" [29] **[W]**; hexes **[E]** |

- **Juvenile Peregrines.** Their feet and lower legs are described as greenish yellow, and the cere and orbital ring
  pale bluish; "bluish legs" appear only in a falconry forum post [28]. **[W]**, weak. Use the adult colour by default.
- **Owl skin.** The great horned owl's foot skin is black but "almost entirely obscured by feathers" [5]; the barn owl's
  toes are "pink to dark pinkish-grey" [6]. **[W]**
- **Today's rig** draws every species' tarsus and toes in one tan, `Color(0.72, 0.6, 0.32)` ≈ `#b89952`
  (`BirdRig._build_body`), and the tibia capsule in the body colour. Only the sparrow is near that tan; the crow should
  be black, the hawk and falcon a clearer yellow, and the owl's tarsus should be feathered (§2).

---

## 7. What the rig should show

`BirdRig` draws each leg as capsules: tibia (radius 0.03 L, body colour), tarsus (0.018 L) and four toe capsules
(0.01 L; 0.07 L forward, 0.05 L hallux), and no claws (`_build_body` and the Legs block of `apply_pose`; the detailed legs behind `LegRig.enabled` replace them, `docs/design/legs_and_feet.md`).

### 7.1 What reads at game scale
The chase camera sits 3.2 m × (span / 1 m, clamped 0.5–1.4) behind, with a vertical FOV of 68° and up
(`chase_camera.gd`). At 1080 p that is about 800 / d pixels per metre at distance d. **[E]** (arithmetic)

| Bird (camera distance) | Tarsus length | Tarsus width | Biggest claw | Toe span |
|---|---|---|---|---|
| Hawk (≈ 4.2 m, ≈ 190 px/m) | 8 cm ≈ 15 px | 7 mm ≈ 1–2 px | 3 cm ≈ 6 px | ≈ 12 cm ≈ 23 px |
| Crow (≈ 3.2 m, ≈ 250 px/m) | 6 cm ≈ 15 px | 5 mm ≈ 1 px | ≈ 1 cm ≈ 2 px | ≈ 8 cm ≈ 20 px |
| Sparrow (≈ 1.6 m, ≈ 500 px/m) | 2 cm ≈ 10 px | 2 mm ≈ 1 px | 4 mm ≈ 2 px | 2.5 cm ≈ 12 px |

Widths: Red-tail tarsometatarsus 5.5–7.8 mm, barn owl 4.6–5.3 mm bone [1] and 5.2–5.6 mm on the skin [7] **[S]**; crow
and sparrow **[E]**. Claw sizes from §5.4, toe spans from §1.4 **[E]**.

**Reads at that scale** (and more so in the bird lab and rig gallery close-ups) **[E]**:
1. **Leg colour against the belly**: black crow, yellow hawk and falcon, pink-brown sparrow, a pale feathered owl leg.
   One material colour per species, the cheapest and most visible fix.
2. **Bone proportions**: a short, stout tarsus (falcon, great horned owl, crow) against a longer one (hawk, barn owl).
   Fix the `legs` fractions (§1.3).
3. **The feather line**: trousers that bulge down to the ankle on the hawk and falcon (the tibia capsule in the trouser
   colour and a little fatter, ending at the ankle), and a fully feathered, thicker owl tarsus with feathered toes.
4. **Foot size and the talons when perched or striking**: longer toes (about 0.10 L forward, 0.07 L hallux, §1.4) and a
   dark claw cone on each toe, sized by Fowler's ratios (§5.1): the hawk's big hallux and inner talons, the falcon's
   even ones, the owl's even, less hooked ones.
5. **The owl's 2 + 2 grip**: already built (`zygo`).

**Doesn't read; leave out or fake later** **[E]**:
- Scutes against reticulate scales, pads, spicules, toe bristles, the talon's cross-section and the barn owl's comb.
  At most a normal-mapped tarsus in close-ups; scutes as faint bands on the hawk, crow and sparrow tarsus front.
- Tarsus width below about 1 px. Keep the capsule at about 0.015–0.018 L (slightly fat for the hawk and falcon, right for
  the feathered owl) so the legs don't flicker.
- Juvenile leg colours and subspecies differences in the trousers.

### 7.2 Per-species summary for the rig
| Species | `legs` tib / tars (now → suggested) | Feather line | Tarsus scales | Claws (colour; relative size D-I : II : III : IV) | Leg colour |
|---|---|---|---|---|---|
| Crow | 0.18 / 0.20 → 0.19 / 0.13 | To the ankle; bare tarsus | Scutes in front, plates behind | Black; 1.3 : 1.1 : 1.3 : 1 (non-raptor) | `#121214` |
| Owl | 0.16 / 0.14 → 0.25 / 0.16 | Tarsus and toes feathered | Hidden | Blackish grey; ≈ 1.05 : 1.2 : 1.15 : 1, ≈ 90° arc | `#e6d8bd` (feathered) |
| Hawk | 0.17 / 0.17 → 0.20 / 0.15 | Trousers to the ankle; bare tarsus | Scutes in front, reticulate behind | Black; 1.8 : 1.65 : 1.2 : 1, ≈ 115° | `#e3c04a` |
| Falcon | 0.16 / 0.15 → 0.19 / 0.12 | Barred trousers over the top of the tarsus | Reticulate all round | Black; 1.27 : 1.13 : 1.1 : 1, ≈ 115° | `#e8c547` |
| Sparrow | 0.16 / 0.14 → 0.18 / 0.12 | To the ankle; bare tarsus | Fine scutes in front, plates behind | Dark horn; 1.3 : 1.1 : 1.3 : 1 | `#b38b7c` |

All suggestions **[E]**, derived from the sourced numbers above.

---

## Sources

1. Field DJ, Lynner C, Brown C, Darroch SAF 2013, "Skeletal correlates for body mass estimation in modern and fossil flying birds", *PLoS ONE* 8:e82000, doi:10.1371/journal.pone.0082000. Per-specimen limb lengths (Yale Peabody Museum) in Table S1, `pone.0082000.s003.csv`, read via the PLoS supplementary link. https://pmc.ncbi.nlm.nih.gov/articles/PMC3843728
2. Royal BC Museum, "Bones" identification key: "List of the total length of tibiotarsus for the different species of Falconiformes and Strigiformes in British Columbia" and the matching tarsometatarsus list. https://royalbcmuseum.bc.ca/Natural_History/Bones/Raptor/raptor-tibia.htm and `.../raptor-tarsus.htm` (both redirect to rbcm.ca; the Bones index returned 403)
3. Wikipedia, "Red-tailed hawk" (middle toe and hallux claw citing Hull et al. 2008 and Preston & Beane 2009; yellow legs; total length citing Ferguson-Lees & Christie 2001), with "Eastern red-tailed hawk" and "Western red-tailed hawk" (tarsus averages and thigh barring, from search summaries). https://en.wikipedia.org/wiki/Red-tailed_hawk
4. Wikipedia, "Peregrine falcon" (tarsus 4.5–5.6 cm; feet yellow, claws black; clenched-talon strike). https://en.wikipedia.org/wiki/Peregrine_falcon
5. Wikipedia, "Great horned owl" (tarsus 54–80 mm; feathered feet; black foot skin; gunmetal talons; foot span ~20 cm). https://en.wikipedia.org/wiki/Great_horned_owl
6. Wikipedia, "Western barn owl" (feathered legs; tarsal feathers white to reddish buff; toes pink to dark pinkish-grey; talons black; 33–35 cm). https://en.wikipedia.org/wiki/Western_barn_owl
7. Daugherty RL, Brown AJ III, Salas VG, Contreras FJ, Chávez R, Mendes GC, Nestler JR, Johnson DH 2026, "Morphological assessment of the Common Barn Owl *Tyto alba* (Strigiformes: Tytonidae) supports three species", *Zootaxa* 5752(3):403, doi:10.11646/zootaxa.5752.3.5. Table 2 (male American barn owls, Washington, Oregon, Idaho) read via Zenodo: https://zenodo.org/records/19697805
8. Wikipedia, "American crow" (tarsus 5.5–6.5 cm; legs, feet and bill black; 40–53 cm). https://en.wikipedia.org/wiki/American_crow
9. Wikipedia, "House sparrow" (tarsus 1.6–2.5 cm; 14–18 cm; hops). https://en.wikipedia.org/wiki/House_sparrow
10. Sankpal R, Lonkar R, Pande S 2024, "Morphometry of various organs and flight feathers of House Sparrows (*Passer domesticus*) from India and comparison with global feather web databases", *Ela Journal of Forestry and Wildlife* 13(4), Table 4 (also citing Albayrak & Pekgöz 2021 for means). https://elafoundation.org/ela/wp-content/uploads/2025/02/EJFW-13-4.pdf
11. Fowler DW, Freedman EA, Scannella JB 2009, "Predatory functional morphology in raptors: interdigital variation in talon size is related to prey restraint and immobilisation technique", *PLoS ONE* 4:e7999, doi:10.1371/journal.pone.0007999. https://pmc.ncbi.nlm.nih.gov/articles/PMC2776979
12. Tsang LR, Wilson LAB, Ledogar J, Wroe S, Attard M, Sansalone G 2019, "Raptor talon shape and biomechanical performance are controlled by relative prey size but not by allometry", *Sci Rep* 9:7076, doi:10.1038/s41598-019-43654-0. https://pmc.ncbi.nlm.nih.gov/articles/PMC6506530
13. Birn-Jeffery AV, Miller CE, Naish D, Rayfield EJ, Hone DWE 2012, "Pedal claw curvature in birds, lizards and Mesozoic dinosaurs: complicated categories and compensating for mass-specific and phylogenetic control", *PLoS ONE* 7:e50555, doi:10.1371/journal.pone.0050555. https://pmc.ncbi.nlm.nih.gov/articles/PMC3515613/
14. Pike AVL, Maitland DP 2004, "Scaling of bird claws", *J Zool* 262:73–81. (citation and secondary summaries only)
15. Rossi O, Csermely D 2006, "Bird claws and bird of prey talons: where is the difference?", *Ital J Zool* 73:43–53, doi:10.1080/11250000500502368; and Csermely D, Rossi O, Nasi F 2012, *Ital J Zool* 79 (claw geometry of owls, accipitrids and falcons). (abstracts only)
16. Pittman M, Bell PR, Miller CV, Enriquez NJ, Wang X, Zheng X, Tsang LR, Tse YT, Landes M, Kaye TG 2022, "Exceptional preservation and foot structure reveal ecological transitions and lifestyles of early theropod flyers", *Nat Commun* 13:7684, doi:10.1038/s41467-022-35039-1. https://pmc.ncbi.nlm.nih.gov/articles/PMC9768147
17. Arent L, Pollock C 2012 (updated 2023), "Raptor anatomy fundamentals", LafeberVet. https://lafeber.com/vet/raptor-anatomy-fundamentals/
18. Schwehn R, Engelke E, Seiler C, Fischer D, Seifert H, Pfarrer C, Fehr M, Legler M 2024, "Blood vessel topography of the feet in selected species of birds of prey and owls", *Vet Sci* 11:88, doi:10.3390/vetsci11020088. https://pubmed.ncbi.nlm.nih.gov/38393107/ (abstract; pad details from a search summary)
19. Höfling E, Abourachid A 2021, "The skin of birds' feet: morphological adaptations of the plantar surface", *J Morphol* 282:88–97, doi:10.1002/jmor.21284. (abstract via search; the HAL copy was blocked)
20. Wikipedia, "Scute" (bird scutes, scutellae and reticulae; citing Sawyer & Knapp 2003, *J Exp Zool B* 298:57–72; Dhouailly 2009, *J Anat* 214:587–606, doi:10.1111/j.1469-7580.2008.01041.x; Zheng et al. 2013, *Science* 339:1309). https://en.wikipedia.org/wiki/Scute
21. Wikipedia, "Bird feet and legs" (podotheca; phalanges 3, 4, 5 and 2 for toes II–IV and I). https://en.wikipedia.org/wiki/Bird_feet_and_legs
22. Jenyns L 1835, *A Manual of British Vertebrate Animals*, the Raptores genus keys (acrotarsia scutellated or reticulated; owl leg and toe feathering; the barn owl's serrated middle claw; Osprey claws "rounded beneath"). https://chestofbooks.com/animals/zoology/Vertebrate/Class-II-Aves-Order-I-Raptores.html
23. Wikipedia, "Rough-legged buzzard" (legs feathered, toes not; *lagopus* "hare-foot"; small talons) and "Ferruginous hawk" (feathered to the talons; tarsus 81–92 mm). https://en.wikipedia.org/wiki/Rough-legged_buzzard , https://en.wikipedia.org/wiki/Ferruginous_hawk
24. Wikipedia, "Osprey" (spicules under the toes; reversible outer toe; talons rounded, not grooved; backward-facing scales). https://en.wikipedia.org/wiki/Osprey
25. Virginia Department of Wildlife Resources, Peregrine falcon species page ("barred belly and legs"), from a search summary. https://dwr.virginia.gov/?p=8843
26. Britannica, "Passeriform: form and function" (bilaminate plantar tarsus in most oscines), and a 1959 *Wilson Bulletin* paper, vol. 71(3):274–277, on the booted tarsus. Both from search summaries; Britannica returned 403. Coues 1884's figure "Booted laminiplanter tarsus of a Robin" (ClipArt ETC, University of South Florida) seen as a caption only.
27. Lucas AM, Stettenheim PR 1972, *Avian Anatomy: Integument*, USDA Agriculture Handbook 362. (catalogue records only; not read)
28. Juvenile Peregrine foot colour (greenish yellow): secondary species sites (birdfact.com) and a falconry forum, from a search summary. Weak.
29. USGS Patuxent Bird Identification InfoCenter, House sparrow ("pink legs"), from a search summary; the page now redirects. https://www.mbr-pwrc.usgs.gov/id/htmid/h6882id.html
30. Chappell MA, "Peregrine juveniles" photo page, University of California, Riverside ("very big feet" at all ages). https://faculty.ucr.edu/~chappell/INW/birds8falcons/peregrinejuveniles.shtml

**Not sourced or not verified:** crow and house sparrow bone lengths (the tibiotarsus is estimated from the field tarsus); Peregrine, crow and great horned owl toe and claw lengths; the Red-tail's tarsal scutes (sourced only at genus level, 1835); the crow's and sparrow's front-of-tarsus scutes (from photographs); how far the Peregrine's tarsus is feathered (an unverified old-key quote); the definition of Daugherty et al.'s "feathered tarsus ratio"; the claw colours for the Red-tail and sparrow; every hex value.
