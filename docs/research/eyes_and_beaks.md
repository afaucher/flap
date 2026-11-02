# Eyes, beaks and head motion: research and proposal

What real eyes, beaks and heads look like and how they move, for our five species, and a cheapest-first plan to get them into the greybox rig (`scripts/bird/bird_rig.gd` `_build_body` and `apply_pose`, `scripts/bird/body_shape.gd` `DATA`) with no art assets.

**The diagnosis in one line.** Today every species has the same face: a sphere, two small black spheres at about 0.18 head radii, and a plain cone. The head turns smoothly toward its target (`look_dir.slerp(..., 1 - exp(-10 dt))`) and stays level with the world. What makes a bird face read at game distance is mostly missing:
- an **iris colour and eye-ring** against the plumage (yellow-eyed owl, dark-eyed falcon with a yellow ring);
- the raptor **brow ridge** that gives the frown;
- the **hooked bill with a yellow cere** on the raptors, versus the crow's long dagger and the sparrow's cone;
- the owl's flat **facial disc**;
- the way birds move their heads: **fast saccades between still fixations**, not a smooth chase, and **head tilts** to look up with one eye.

Confidence tags follow `body_poses_and_folded_wings.md`:
- **[S]** sourced from a paper, a museum, university or agency page, or a society.
- **[F]** secondhand: field guides, Wikipedia, popular or rehab-centre pages, or a search-engine summary of a paper I could not open. Consistent but not checked against the primary source.
- **[E]** our own estimate, from photographs and general knowledge, for the rig to tune.

Source keys like [OROURKE-I] link inline and are listed at the end. All About Birds was avoided (it refused automated fetches last time).

Rig coordinates match `bird_rig.gd`: +Y up, −Z forward (the nose), +X right. In head space the head is a sphere of radius `r = body.head_r`. **All face dimensions below are fractions of r** unless marked mm.

---

## 1. Eyes

### 1.1 Size: the eye is huge, but you only see a small part of it

- **Relative to the body.** Raptors' eyes are about 1.4 times, and owls' about 2.2 times, the mass expected for an average bird of the same weight ([BROOKE] via [WIKI-BV]). **[S]**
- **Relative to the skull and brain.** In non-passerines, eye size tracks brain size more closely than body mass, and most data fit eye–brain isometry: eyes "as large as the head allows" ([BURTON]; course-page summary of Burton 2008, *Vision Research*). **[F]** The Raptor Center (University of Minnesota) says raptor eyes fill about a third of the skull ([UMN-RC]). **[S]** An old note reports single eyes weighing as much as the whole brain in some hawks, owls and flycatchers ([WILSON-1889]); this is anecdotal, so treat it as colour, not data. **[F]**
- **Measured eyes.**

| Species | Eye axial length | Source | Tag |
|---|---|---|---|
| Red-tailed Hawk | 22.8 mm | [OROURKE-I] | [S] |
| Cooper's Hawk | 18.0 mm | [OROURKE-I] | [S] |
| American Kestrel (falcon proxy) | 11.95 mm | [OROURKE-I] | [S] |
| Barn Owl | about 17.5 mm, nearly twice the allometric expectation; f-number 1.3 | [HW-BARN] | [S] |
| Great Horned Owl | "just slightly smaller" than a human eye (human ≈ 24 mm) | [WIKI-GHO] | [F] |
| Rook (crow proxy) | 14.5 mm | [ROOK] | [S] |
| House Sparrow | eye socket 8.8 mm wide; relatively larger eyes than the House Finch | [FJ-SPARROW] | [S] |

- **What shows.** Most of the globe sits inside the orbit, under feathered skin. From outside you see only the cornea in the lid opening: a dark (or coloured) disc. In photographs the visible eye is roughly 0.2–0.25 of the head's feathered width in hawks, falcons, crows and sparrows, and smaller in the Barn Owl, whose eyes look like dark slits in the white disc ("oversized, oblique black eye-slits", [WIKI-BO]). **[E]**, except the Barn Owl wording **[F]**.
- **For the rig:** model the visible eye only, as a shallow lens cap on the head surface. Don't build a globe.

### 1.2 Placement: optic axes and visual fields

Birds' eyes point outward. Even "forward-facing" owl eyes diverge. The optic-axis azimuth is the angle between one eye's axis and the bill direction, so the angle between the two axes is twice that.

| Species | Optic axis (each eye, from the bill line) | Binocular field (max width) | Blind area behind head | Total horizontal field | Tag |
|---|---|---|---|---|---|
| Barn Owl | ≈31° (axes diverge ≈62°) [HW-BARN] | narrower than in Strigidae; no number found [POTIER-OWL] | — | — | [S] axis; [E] fields ≈40°, ≈160°, ≈200° |
| Great Horned Owl | ≈30–35° | not measured. Congener Snowy Owl 34° (the narrowest of 23 owls); owls overall 34–54.5°, mean 45° [POTIER-OWL] | Tawny Owl 160°; in owls no more than 180° [POTIER-OWL] | Tawny Owl ≈201° [VU-RAPTOR] | [S] ranges; [E] GHO axis |
| Red-tailed Hawk | ≈45–50° | 33° at the bill plane; 22° averaged over elevations [OROURKE-I] | ≈82° (abstract); 55° averaged [OROURKE-I] | ≈280° | [S] fields; [E] axis and total |
| Peregrine Falcon | ≈40–45°. The deep fovea needs about a 40° head turn to look ahead [TUCKER] | Kestrel proxy: 33° at the bill plane [OROURKE-I]; diurnal raptors mean 37° [POTIER-OWL] | Kestrel ≈35° averaged | ≈300° | [S] proxies; [E] axis and total |
| American Crow | ≈60°. Large-billed Crow measured 59–63° azimuth, about 33° below horizontal [ITAHARA] | ≈38° (extrapolated) at the bill plane; widest about 20° above the bill; vertical extent 169° [FJ-CROW]. Large-billed Crow 48° [ITAHARA] | narrow: 7.75° averaged [FJ-CROW]; 17° (Large-billed) [ITAHARA] | ≈340° | [S] |
| House Sparrow | ≈65–70° | 29.5° averaged over elevations; vertical extent 200°. Each lateral field is 130–140°, about 90% of the total [FJ-SPARROW] | 25° averaged [FJ-SPARROW] | ≈330° | [S] fields; [E] axis |

Notes:
- **Where the bill sits in the field.** In diurnal raptors the bill tip projects near the widest part of the binocular field. In owls it falls at or below its lower edge [POTIER-OWL]. Crows can see their own bill tip and converge their eyes on it [FJ-CROW]. **[S]**
- **Owl fields are trimmed by feathers.** The binocular field's margin coincides with the facial-disc feathering in every owl tested [POTIER-OWL]. **[S]** So the disc rim is a reasonable visual boundary for the eye.
- **The popular "owls overlap 50–70%, raptors 30–50%"** ([WIKI-BV]) is a percentage-of-field figure. Don't confuse it with the degree widths above. **[F]**
- **For the rig:** place each eye on the head sphere at its optic-axis azimuth, with the eye's surface normal along that axis. The current rig's eyes sit at about 54° azimuth (29° for the owl) and 15° elevation. That placement is close to right; the eyes' size, colour and framing are what's wrong.

### 1.3 Shape: tubular owl eyes, the scleral ring

- **Three eye shapes.** The front half of a bird's eye may be flat (most diurnal birds), globose (raptors), or tubular (owls) ([WIKI-SR]; Cal Academy [CALACAD]). The Barn Owl eye has a concave, elongated middle segment that forms a tube [HW-BARN]. Hawk eyes are more spherical ([UMN-RC]). **[S]/[F]**
- **The scleral ring.** A ring of 12–18 bony plates (most often 14) stiffens the front of the eye [WIKI-BV]; a Long-eared Owl has 15 [VMS-OWL]. The ring and the eye's tight fit in the orbit are why owls can barely move their eyes [HW-BARN][UMN-RC]. **[S]/[F]**
- **For the rig:** none of this shows from outside. It matters only as the reason owls turn the head instead (§1.5). Don't model it.

### 1.4 Visible features

**Iris colour by species**

| Species | Adult iris | Young | Tag |
|---|---|---|---|
| Barn Owl | blackish brown; the whole eye reads black [WIKI-BO] | same | [F] |
| Great Horned Owl | yellow; amber in the South American form [WIKI-GHO][AUD-EYES] | same | [F] |
| Red-tailed Hawk | darkens to reddish-brown over about 3–4 years [WIKI-RT][AUD-EYES] | yellowish to pale yellow-brown [WIKI-RT] | [F] |
| Peregrine Falcon | very dark brown (reads black) [NIRSG][WIKI-PF] | dark brown | [F] |
| American Crow | dark brown (reads black) | blue-grey, darkening to brown over the first months [CROW-EYE] | [F] (blue juvenile eye: bird-club and forum sources) |
| House Sparrow | dark brown [ZOO-HS] | dark | [F] (weak: zoo page) |

Birds have no visible white sclera around the iris, which is why iris colour reads so strongly [AUD-EYES]. **[F]**

**Eye-ring and orbital skin**

- **Peregrine Falcon.** A bare yellow orbital ring on adults, blue-grey on juveniles, matching the cere [WIKI-PF][NIRSG]. **[F]** This, with the dark eye and the malar stripe, is the falcon's face.
- **Red-tailed Hawk.** No conspicuous ring. The eye sits under the brow, framed by brown feathering. **[E]**
- **Owls.** The eyelid rims are dark, which makes the Great Horned Owl's yellow iris pop. The Barn Owl's eye sits in a small dark smudge inside the white disc. **[E]**
- **Crow and sparrow.** No visible ring. The dark eye sits in dark (crow) or brown-grey (sparrow) feathering. **[E]**

**Brow (supraorbital ridge)**

- Hawks and eagles have a bony ridge above the eye, the supraorbital ridge. It gives support and protection and shades the eye; it gives them their "fierce look". **Owls lack it** ([UMN-RC]; Peregrine Fund [PF-VISION]). **[S]**
- For the rig, it is the single biggest "raptor" cue on the head after the hooked bill. **[E]**

**Nictitating membrane**

- **What it is.** A thin, semi-transparent third eyelid. It sweeps horizontally across the eye from the inner (front, nasal) corner, "like a windscreen wiper" [WIKI-BV][PF-VISION]. **[S]/[F]**
- **When raptors close it.** While feeding, at prey contact, in fast dives and in heavy rain [PF-VISION]. **[S]** Other sources say it covers the eye just before a raptor hits its prey [NM-BLOG]. **[F]**
- **Eyelids.** Most birds do not blink with their eyelids; in most species the lower lid rises to close the eye in sleep. The horned owls are an exception, with a mobile upper lid [WIKI-BV]. **[F]** The "sleepy owl" look of a half-closed upper lid is an owl thing.

### 1.5 Eye movement in the socket

| Species | Eye movement amplitude | Source | Tag |
|---|---|---|---|
| Owls | under 1–2°. Barn Owl about 2° [HW-BARN]; owls generally under 1° [POTIER-OWL]; Great Horned Owl under 1.5° [VU-RAPTOR] | | [S] |
| American Kestrel (falcon proxy) | 0.9° (≈1°) | [OROURKE-I] | [S] |
| Red-tailed Hawk | 4.9° (≈5°) | [OROURKE-I] | [S] |
| Cooper's Hawk | 8.4° | [OROURKE-I] | [S] |
| American Crow | 16.4° averaged across elevations; most in the horizontal plane [FJ-CROW]. Large-billed Crow 16–17° spontaneous, 34° when induced [ITAHARA] | | [S] |
| House Sparrow | 16.4°; enough to almost abolish binocular overlap when the eyes diverge [FJ-SPARROW] | | [S] |
| Birds in general | typically 10–20° horizontally, more than 80° in some passerines [WIKI-BV] | | [F] |

- **Practical consequences:**
  - The two raptors and the owl effectively do not move their eyes: everything is head motion.
  - The crow and the sparrow can shift gaze about ±8° in the socket. When converged, the crow's eyes widen the binocular field ahead of the bill; when diverged, they abolish it [FJ-CROW]. **[S]**
- **Saccades.**
  - Gaze changes are mostly **head saccades**: fast head rotations separated by still fixations. In pigeons in turning flight they last 4–30 ms, span 5–30°, and peak at 400–1,200°/s ([PIGEON-SAC], Frontiers in Neuroscience 2017). **[S]**
  - Barn Owls turning to a sound make stereotyped head saccades with a latency of about 100 ms and a peak of about 790°/s (Knudsen et al. 1979, via search summary) **[F]**.
  - In raptors, the timing between saccades is irregular: a log-normal distribution of intervals fits best, not a constant rate [OCHS] **[S]**.
- **Blinks ride on saccades.** In peafowl, blink rate rises with gaze-shift rate. 76% of gaze shifts with an eye-in-head movement over 15° came with a blink [YORZINSKI]. **[S]** In foraging chickens, nearly all blinks fall during head movements [FEVO-BLINK]. **[S]**

### 1.6 Head stabilisation and head-bobbing

- **Stabilisation.** Birds hold the head as still as they can while the body moves [WIKI-BV]. In whooper swans in flight, the head moves about 4× less than the body (see `body_poses_and_folded_wings.md` §2). The rig's `head_offset` lag already does this. **[S]**
- **Bobbing while walking.** Bobbing is a hold phase, with the head nearly still in space (drifting about 3 mm/s), then a fast thrust (about 500–800 mm/s, pigeon). It runs one bob per step ([NECKER], citing Frost 1978). **[S]**
  - **Who bobs:** pigeons, chickens, cranes, rails and herons. Among passerines, small species usually hop, and larger ones such as crows walk and bob [NECKER]. **[S]**
  - **Who doesn't:** diurnal raptors and owls do not head-bob when walking [NECKER]. **[S]**
- **Parallax bobbing.** Raptors and owls do bob, circle or tilt the head *while perched* to triangulate distance [PF-VISION].
  - Barn Owls make side-to-side head translations ("peering") before striking [HW-BARN].
  - American Kestrels had the highest rate of translational head movements of three raptors [OROURKE-II].
  - **[S]**
- **For the rig:** the crow's walk on a perch or on the ground bobs, the sparrow's hops don't, and the raptors and the owl peer instead.

---

## 2. Beaks

### 2.1 Shape by species

- **Red-tailed Hawk.** A short, dark, hooked bill, with a yellow cere [WIKI-RT]. The tip curls down well past the lower mandible. **[F]** The bill is deep at the base and laterally compressed. **[E]**
- **Peregrine Falcon.** A short, deep, strongly hooked bill. It has a **tomial tooth**: a sharp triangular projection on the cutting edge of the upper mandible, with a matching notch in the lower. Falcons use it to sever the prey's neck [WIKI-BEAK][WIKI-PF]. Shrikes have a keratin version; buteos and eagles lack it [WIKI-BEAK][FALC-BLOG].
  - Small bony **tubercles** sit in the round nostrils; they are thought to guide airflow in the stoop [WIKI-PF]. **[F]**
  - The bill is very wide in the subspecies *pealei* [WIKI-PF]. **[F]**
- **American Crow.** A long, stout, black bill with a slightly decurved culmen. It is 3–5.5 cm long depending on region [WIKI-AC]. Stiff **bristle-like feathers cover the nostrils** in almost all corvids [BTO-CORV]. Raven bristles run about a quarter of the bill length (by ratio) [WB-RAVEN]. **[S]/[F]**
- **House Sparrow.** Stout and conical, for seeds, with a culmen of 11–15 mm [WIKI-HS]. **[F]**
- **Owls.** A short, hooked bill pointing downward, set snug against the face so sound bounces into the disc ([NATHAB]; Boulder County [BOULDER]). **[F]** Most of it is buried in the facial feathers and bristles. **[E]**
  - **Great Horned Owl:** bill 3.3–5.2 cm in total, but culmen only 2.1–3.3 cm, dark gunmetal grey [WIKI-GHO]. **[F]**
  - **Barn Owl:** a long, narrow, pale bill (pale horn to dark buff) at the bottom of the heart-shaped disc [WIKI-BO]. **[F]**

### 2.2 Measurements and colours

Head radius *r* here means the life head's feathered half-width, for converting millimetres to the rig's fractions. The values are estimates from photographs **[E]**: crow ≈ 23 mm, Red-tail ≈ 30 mm, Peregrine ≈ 25 mm, Barn Owl ≈ 55 mm (the disc is about 110 mm across [WIKI-FD]), Great Horned Owl ≈ 58 mm, sparrow ≈ 10.5 mm.

| Species | Bill length (mm) | Depth at base (mm) | Width at base (mm) | Length / r | Depth / r | Width / r | Tag |
|---|---|---|---|---|---|---|---|
| Crow | exposed culmen ≈ 45–50 (range 30–55 [WIKI-AC]) | ≈ 17–19 at the nostrils | ≈ 13–15 | 2.0 | 0.78 | 0.6 | [F] length; [E] depth, width |
| Red-tailed Hawk | culmen 21.7–30.2; subspecies means 24–29 [WIKI-RTSUB] (+ cere ≈ 6) | ≈ 18 | ≈ 13 | 1.05 incl. cere | 0.6 | 0.45 | [F] length; [E] rest |
| Peregrine (*F. p. peregrinus*) | cere to tip: ♂ 21.0, ♀ 24.8 | ♂ 15.8, ♀ 18.2 | 12.7–12.8 | 1.0 incl. cere | 0.7 | 0.5 | [S] [TAHIR] (small regional journal: moderate) |
| Great Horned Owl | culmen 21–33 [WIKI-GHO]; about half visible | ≈ 12 visible | ≈ 10 | 0.35 visible | 0.2 | 0.17 | [F]/[E] |
| Barn Owl | ≈ 20 culmen, about half visible | ≈ 10 | ≈ 8 | 0.3 visible | 0.18 | 0.15 | [E] |
| House Sparrow | culmen 11–15 [WIKI-HS] | ≈ 8 | ≈ 7.5 | 1.25 | 0.75 | 0.7 | [F] length; [E] rest |

**Colours (bare parts)**

| Species | Bill | Cere | Gape and mouth interior | Tag |
|---|---|---|---|---|
| Crow | black [WIKI-AC] | none (bristles) | adult dark; juvenile pink, darkening with age [CROW-EYE] | [F] |
| Red-tailed Hawk | dark, bluish-grey at the base [WIKI-RT] | yellow [WIKI-RT] | flesh-pink | [F]; [E] base and mouth |
| Peregrine | dark, bluish at the base ("black" in [WIKI-PF]) | yellow; juvenile pale bluish [WIKI-PF] | flesh-pink | [F]; [E] base and mouth |
| Great Horned Owl | dark gunmetal grey [WIKI-GHO] | grey, hidden | pink | [F]; [E] |
| Barn Owl | pale horn to dark buff [WIKI-BO] | hidden | pink | [F]; [E] |
| House Sparrow | male: dark grey, black when breeding; female: brownish-grey; young: light yellow to straw [WIKI-HS] | none | nestlings: yellow gape and swollen gape flanges [WIKI-HS][WIKI-BEAK] | [F] |

Owls are the one group whose nostrils sit beyond (distal to) the cere [WIKI-BEAK]. **[F]** That doesn't show at our scale.

### 2.3 Range of motion

- **Lower jaw (gape).**
  - **Song.** Gape widens with pitch. In White-throated Sparrows, a 0.4 cm gape (15°) went with 3 kHz notes and a 0.7 cm gape (30°) with 4 kHz notes. Swamp Sparrows flare over 1 cm (more than 50°) at 7–8 kHz ([WESTNEAT], via the abstract). **[S]**
  - **Calling, panting, eating.**
    - Corvid caws, open-bill panting and tearing at food are typically 25–40°. **[E]**
    - Panting is held open for seconds with the throat fluttering. Gular flutter and panting are documented across many groups ([SMIT]; RSPB [RSPB-HEAT]). **[S]** The panting gape angle itself is an estimate: about 20–30°. **[E]**
    - Owls hiss and bill-snap in threat displays [WIKI-BEAK]. **[F]** A bill-snap is a fast 0 → ≈15° → 0 click. **[E]**
- **Cranial kinesis.**
  - In most birds the upper bill can rotate as a rigid unit about the nasofrontal hinge where it meets the skull. This is *prokinesis*; the crow (*Corvus corone*) is the textbook prokinetic example ([GUSSEKLOO]; [WIKI-BEAK]). **[S]**
  - **How far.** Measured upper-bill rotations in 2023 video of insectivores and woodpeckers reached **up to 8°**. Means were near 1–3°, and over a third of non-woodpecker cases were under 1° [WOODPECKER]. Parrots have the most kinesis (not our species). **[S]**
  - In White-throated Sparrows the upper and lower jaws move independently during song [HOESE]. **[S]**
  - **For the rig:** a coupled upper-bill lift of 0.1–0.15 × the jaw angle, capped at 5°, is plenty. **[E]**

---

## 3. Head and neck range of motion

### 3.1 Yaw and pitch

- **Owls.**
  - Owls turn the head about 270° ([HW-BARN]; Johns Hopkins study [JHU-OWL]). **[S]**
  - The figure is ambiguous. Popular accounts mean about 270° of total arc. The Peregrine Fund says "at least 180, maybe up to 270 degrees, from a forward-facing position" [PF-VISION].
  - In X-ray work on live Barn Owls, the capacity was at least 180°. Dead specimens could be turned past 360° without injury [KRINGS]. **[S]**
  - **Rig:** ±135° (270° total, the current value) is defensible. ±160° looks more owlish when it stares straight back, which it can. **[E]**
- **Other birds.** I found no measured voluntary yaw range for crows, hawks, falcons or sparrows. All of them sleep with the bill tucked into the scapulars, facing backward (`body_poses_and_folded_wings.md`, sleeping), so the neck can reach about 180°. For looking around, 120–150° is plausible. **[E]**
- **Pitch.**
  - All five can look straight down at their feet or a perch. Kestrels hover looking down.
  - Lateral-eyed birds look up by *rolling* the head (§3.2) more than by pitching it.
  - Tawny Owls dorsiflex the head more than 35° ([KRINGS], citing a tawny owl study). **[S]**
  - **Rig:** pitch −80…+60° for crow, sparrow, hawk and falcon; −80…+80° for the owl. **[E]**

### 3.2 Roll: the one-eyed look up

- **Why birds roll.** With eyes on the sides of the head, birds tip the head sideways to look up rather than tilting it back (Audubon North Carolina [AUD-NC]). **[F]**
  - Australian Magpies look up with the *left* eye in response to an eagle alarm call (Rogers & Kaplan 2006, via search summary). **[F]**
  - Large-billed Crows watched a landed object with the lateral field by rolling the head about its roll axis in a saccade [ITAHARA]. They used the binocular field near the bill for moving targets and the lateral field near the optic axis for still ones, slightly preferring the right eye [ITAHARA]. **[S]**
- **Neck mechanics.** In Barn Owls the upper neck mainly yaws and the lower neck mainly rolls, up to about 40° per joint. The lower neck bends sideways once a turn passes about 45° [KRINGS]. **[S]**
  - So a large head turn naturally carries some roll, and the head shifts sideways off the body axis.
  - Owls also tilt the head to compare the two asymmetric ears when locating sounds (weak sources: forum and a natural-history site [NATHAB]). **[F]**
- **The current rig keeps the head level with the world**, the up vector at `world_up.slerp(UP, 0.3)`. That stays right as the *default*: see the pigeon "eye–bill line held near constant" note in `body_poses_and_folded_wings.md`. But it should allow a deliberate roll when the target is high, or for curiosity cocks.

### 3.3 When the body follows

- **No measured threshold found.** Perched birds glance with the head and re-orient the body, by shuffling the feet or hopping round, only for sustained interest. **[E]**
- **Rig rule:**
  - When |head yaw| stays over about 90° for more than about 1.5 s, the bird turns the body (owls: over 150°, after more than about 3 s).
  - In flight, the head leads the bank and turn.
  - Peregrines approaching prey hold the head straight and fly a curved, spiral-like path, because turning the head about 40° adds drag [TUCKER]. **[S]**
  - **[E]** for the thresholds.

### 3.4 Scanning while perched

| Species | What it does | Numbers | Tag |
|---|---|---|---|
| Raptors (Red-tail, Cooper's, Kestrel), pooled field data | head movements along one axis, plus translational "peering" | 21.3 ± 2.5 per minute single-axis, 4.7 ± 0.6 per minute translational [OROURKE-II] | [S] |
| Red-tailed Hawk | turns the head slowly; the longest intervals between head movements of the three species; scans open country from perches over 10 m | [OROURKE-I][OROURKE-II] | [S] |
| Cooper's Hawk | the highest head-movement rate; quick sideways movements | [OROURKE-II] | [S] |
| Kestrel (falcon proxy) | the most translational (bobbing) movements: motion parallax | [OROURKE-II] | [S] |
| Goshawk, Cooper's, Red-tail | log-normal intervals between saccades; the larger species redirect gaze more slowly; the goshawk changes gaze less often perched than moving | [OCHS] | [S] |
| American Crow | perched, a faster head-movement rate than scrub jays; mean interval between head movements ≈ 0.81 s; walking or hopping, 23.7 head movements per minute (interval ≈ 0.94 s) | [FJ-CROW] | [S] |
| Barn Owl | fixations, head rotations (always with some translation) and straight or curved translations ("peering") before the strike; heads toward an interception point on moving prey | [HW-BARN] | [S] |
| House Sparrow | lateral fields wide enough to watch for predators while head-down | [FJ-SPARROW] | [S]; the rate is [E]: fast, about 2–4 per second |

**Converted for the rig [E]:**
- The pooled raptor rate of about 21 per minute gives a mean fixation of about 2.8 s. Use about 3–5 s for the Red-tail, about 2–3 s for the falcon, about 0.8–1.2 s for the perched crow, about 0.3–0.6 s for the sparrow, and about 1.5–3 s for the owl, punctuated by peering bursts.
- Draw each interval from a log-normal distribution with σ ≈ 0.5–0.7 (in log space) around that mean [OCHS].
- A saccade's amplitude is mostly 5–30°, with occasional 60–120° re-orientations. Its duration is about amplitude / (≈ 600–900°/s) [PIGEON-SAC]: 20–150 ms, or 1–9 frames at 60 fps.

### 3.5 Blink rates

| Group | Rate | Source | Tag |
|---|---|---|---|
| Owls | under 10 per minute, in all species surveyed | Kirsten & Kirsten 1983, *Condor* (via search summary) [KIRSTEN] | [F] |
| Diurnal species in the same survey | higher | [KIRSTEN] | [F] |
| Wild songbirds and others (1972 field survey) | mean about 18 per minute; up to 70 (Red-winged Blackbird) | [JFO-1972] (via search summary) | [F] |
| Honey-buzzard (raptor) | nictitating membrane 26–32 per minute when undisturbed; more in wind | via search summary | [F] |
| Peafowl | blink rate tracks gaze-shift rate; 76% of big eye-in-head shifts (over 15°) carry a blink | [YORZINSKI] | [S] |
| Chicken (foraging) | 277–285 per minute, mean duration 78–82 ms (46–110 ms) | [FEVO-BLINK] | [S] (context-specific) |

---

## 4. What to build

### 4.1 Head proportions first: an observation

The rig's heads are about 2× life size, except the owl's. This is an estimate **[E]**, from the life half-widths in §2.2 against `head_r = L × DATA.head`:

| Species | Rig `head_r` | Life ≈ | Ratio |
|---|---|---|---|
| Crow | 0.105 × 0.45 m = 47 mm | 23 mm | 2.0 |
| Hawk | 58 mm | 30 mm | 1.9 |
| Falcon | 42 mm | 25 mm | 1.7 |
| Sparrow | 16.5 mm | 10.5 mm | 1.6 |
| Owl | 57 mm | 55–58 mm | 1.0 |

Oversized heads read well from a chase camera, but they force short beaks. A life-proportioned crow bill (2 r) on a 47 mm head would be 94 mm long. Two options:
- **(A) Shrink the non-owl heads** toward life, at about 1.2× for readability: crow 0.06, hawk 0.065, falcon 0.07, sparrow 0.08; the owl stays at 0.15. The fractions below then apply as written.
- **(B) Keep the heads** and scale the beak *lengths* below by ≈ 0.6 for crow, hawk, falcon and sparrow. This is the compromise if the big-head read is wanted.

All other fractions (eye size, placement, depths) can stay as written either way. **[E]**

### 4.2 Head shape per species

Build all heads from the existing `SphereMesh`, scaled per axis (cheap). Add at most one extra mesh per feature.

- **Crow:** elongated and slightly flat-crowned: scale (x 0.88, y 0.9, z 1.15). The forehead runs into the bill base with no step; the bill's base ring overlaps the sphere. The bristle tuft is a small dark wedge over the basal 0.3 of the bill.
- **Hawk:** broad and flat-crowned: (1.0, 0.88, 1.08). Add the **brow**: one squashed capsule per side, along the top front of each eye, pitched about 15° nose-down. It protrudes 0.12 r, its lower edge 0.35 eye radii above the eye centre, and it is coloured with the crown.
- **Falcon:** round and compact: (1.0, 0.95, 1.02). A lighter brow (0.7 × the hawk's). The dark hood and malar stripe come from the head vertex-colour zones already specified in `plumage_coloring.md` §4.
- **Owl (Barn, default; it matches the plumage doc's Barn face):** (1.0, 1.05, 0.8), so the face is flatter.
  - Add a **facial disc**: a shallow dish (a lathe of 8 rings × 24 segments) whose outline in the head's x–y plane is heart-shaped:
    - x = 0.95 r · sin t
    - y = r · (0.75 cos t − 0.25 cos 2t)
    - indented at the top centre and pointed at the chin.
  - The dish sits in front of the head sphere (centre at z = −0.62 r) and is 0.12 r deep at its centre.
  - The rim is a ring tube 0.06 r thick, in the disc-rim colour.
  - The eyes and bill sit inside the dish.
- **Owl (Great Horned variant):** (1.08, 0.95, 0.85).
  - The disc is round, x = 0.9 r · sin t, y = 0.85 r · cos t, with the dark side "brackets" as rim colour [WIKI-GHO].
  - Two ear-tuft cones (plumicorns, which play no part in hearing [WIKI-GHO]): 0.45 r long, at x = ±0.45 r, y = +0.85 r, raked 25° back and 20° out.
- **Sparrow:** "a large, rounded head" [WIKI-HS]: (1.0, 1.0, 1.02).

### 4.3 Eyes: size, placement, colour

**Placement.** The eye centre sits at azimuth θ from the bill line and elevation φ, sunk to depth s:

```
dir    = Vector3(±sin θ cos φ, sin φ, −cos θ cos φ)
centre = dir × r × (1 − s)
```

Orient the eye's normal along `dir`, then rotate it by `tilt` toward the optic-axis elevation. For example, the crow's optic axis points about 20° below its bill line [ITAHARA]; that is a small effect, so `tilt` is optional.

**Mesh.** A **lens cap**, not a sphere: a disc of radius `eye_r` with 3 concentric vertex-coloured rings (pupil, iris, eye-ring), domed out 0.25 × `eye_r`. That is one `SurfaceTool` mesh per eye: about 4 rings × 16 segments, unshaded-ish (roughness 0.25, a small specular for the wet glint).

**Lids.** One dark ring at the outer edge (0.08 × `eye_r`) stands in for the lid rim.

**Pupil.** Size is set by `pupil_frac` (pupil radius / iris radius). Owl pupils can widen at dusk. Keep it static at first.

### 4.4 Beak: a small lofted mesh

Reuse `BodyShape.tube_mesh` with rings, as the trunk does. Use two meshes, the upper and lower mandibles, so the jaw can open.

Parameters: `len, depth, width, upper` (the share of base depth in the upper mandible), `taper` (exponent), `droop` (centre-line drop at the tip / len), `hook` (the share of length where the upper bill overhangs and curls past the lower), `tooth` (the falcon tomial tooth's position along the upper bill, 0 = none), `cere` (the cere band's length / len, from the base), `bristle` (the length of the nasal-bristle cover / len), `pitch` (the beak's pitch relative to head forward; owls point down).

For each ring at u = 0 … 1 (base → tip), with 6–8 rings:

```
z(u)       = −(r·0.85) − len·u                     # base sits inside the head sphere
yc(u)      = −droop·len·u²                          # culmen centre line
half_w(u)  = 0.5·width·(1−u)^taper
d_up(u)    = upper·depth·(1−u)^taper                # upper mandible: above the commissure
d_lo(u)    = (1−upper)·depth·(1−u/(1−hook))^taper   # lower mandible ends at u = 1−hook
hook zone (u > 1−hook): yc −= hook_curl·len·((u−(1−hook))/hook)²,  d_up *= 0.6
```

- Each ring is two half-ellipses, as in `BodyShape`: upper `top = d_up`, `bottom ≈ 0.02 r`; the lower mandible's ring is mirrored.
- Raptors use `hook_curl ≈ 0.6·hook`; the crow uses a tiny overhang (`hook` 0.04).
- **Tomial tooth (falcon):** at u = `tooth`, add a downward bump of 0.06 r on the upper ring's bottom edge, with a matching notch in the lower mandible.
- **Cere:** colour the rings with u < `cere` by vertex colour, in the cere colour. Add a small dark nostril dot at u ≈ 0.6·`cere`, with a centre tubercle on the falcon.
- **Crow bristles:** a separate small wedge (a 4-vertex fan) over u < `bristle`, in plumage black.
- **Owls:** add `pitch` −30° to −35° and bury the base half in the disc. The disc dish covers it.

### 4.5 Joints to add

| Joint | Rig node | Range | Drives | Source |
|---|---|---|---|---|
| `jaw` (lower mandible) | Node3D pivot at the gape corner, z = −0.85 r, y = −0.1 r | 0 … `gape_max` (crow 40°, raptors 45°, owl 30°, sparrow 50°) | calls (15–35°), song (15–50° for the sparrow), panting (held 20–30°), bill-snap (owl) | [WESTNEAT] [S]; rest [E] |
| `kinesis` (upper bill) | pivot at the bill base, the nasofrontal hinge | 0 … 5°, = 0.12 × jaw angle | adds life to big gapes | [WOODPECKER] [S] magnitude |
| `eye_yaw`, `eye_pitch` (each eye) | rotates the eye cap's normal about the eye centre | ± `eye_rom`/2: owl 0.5°, falcon 0.5°, hawk 2.5°, crow 8°, sparrow 8° | the gaze leads a head saccade by about 50 ms in crow and sparrow; zero for owl and falcon | [OROURKE-I] [FJ-CROW] [FJ-SPARROW] [S] |
| `nictitate` (each eye) | a translucent (α 0.6, bluish-white) disc wedge sweeping from the front (nasal) corner toward the rear, over 80–120 ms and back | 0 … 1 | blinks (§4.6); held closed in a stoop, at a strike and while feeding | [WIKI-BV] [PF-VISION] [FEVO-BLINK] [S] |
| `lid` (owls only, upper lid) | a cap of plumage colour lowered over the eye | 0 … 1 | sleepy or roosting owl; slow blinks | [WIKI-BV] [F] |
| `head_roll` | added to the head basis after yaw and pitch | ± `head_roll`: crow and sparrow 60°, raptors 45°, owl 90° | the one-eyed look up, curiosity cocks, owl sound-tilt | [ITAHARA] [AUD-NC] [S]/[F]; ranges [E] |

The existing clamps change to per-species `head_yaw` (crow and sparrow 150°, hawk and falcon 130°, owl 160° or the current 135°) and `head_pitch` [−80, +60] (owl [−80, +80]). **[E]**

AGENTS.md says every assist stays switchable to 0. These are cosmetic, not assists, but keep a `face_anim := true` switch so tests and comparisons can freeze them.

### 4.6 Behaviour

All of it lives in `BirdRig`, reading only `telemetry()` and `look_target`, as the existing head-look does.

1. **Saccade-and-fixate head look** (replaces the continuous slerp).
   - Hold `look_dir` fixed for a fixation time drawn log-normally around the species mean (§3.4).
   - Then snap to the current target (plus a small random offset of ±5–15° when idle-scanning) over a time of amplitude / `sac_speed`, with an ease-out.
   - If the target moves more than about 10° from the held gaze, or the bird is in flight with a look target, the fixation ends early.
   - In flight, keep the existing stabilisation.
2. **Blink on big saccades.**
   - On a head saccade over 15–20°, fire a nictitating blink with probability ≈ 0.75 [YORZINSKI].
   - Add background blinks at the species rate (§3.5): owl about 4 per minute, raptors about 15, crow and sparrow about 18 **[E]**.
   - At most one blink per 0.5 s.
3. **One-eyed look up.**
   - When the target is more than about 40° above the head's horizon, lateral-eyed species roll the head instead of pitching it. Crow and sparrow fully: roll ≈ (elevation − 20°), so the upper eye's axis meets the target. Hawk and falcon half that.
   - Pick the eye nearer the target, with a slight right-eye bias for the crow [ITAHARA].
   - Hold the roll for the fixation and level out after.
   - Owls pitch up instead.
   - **[E]**, built on [AUD-NC][ITAHARA].
4. **Curiosity cock.** When perched and idle, with a probability of about 0.1 per fixation, roll the head 20–35° toward a nearby point of interest for one fixation (crow, sparrow, owl). **[E]**
5. **Parallax peering (owl, falcon).**
   - When a ground target is selected while perched, run a burst of 2–4 side-to-side head translations: ±0.6 r for the owl, ±0.3 r for the falcon, at about 1.5–2 Hz, with gaze locked on the target. Use `head_offset` sideways, and keep the eye–target line fixed.
   - Optionally add a vertical bob of half that amplitude.
   - **[S]** that they do it [HW-BARN][OROURKE-II][PF-VISION]; **[E]** for the numbers.
6. **Walking bob (crow only)** on perch or ground walking: hold the head still in world space for the stance phase, then thrust it forward with the step [NECKER]. Sparrows hop; raptors and owls don't bob.
7. **Body follows** the head after a sustained large yaw (§3.3).
8. **Jaw.**
   - **Calls:** the crow caws at 25–35°, about 0.25 s each, in sets of 2–4. **[E]**
   - **Song:** the sparrow's chirps run 15–30°, at about 3–5 per second. [WESTNEAT] supports the angles; the rate is **[E]**.
   - **Panting** is driven by an `EnergyModel` "hot or exhausted" state if one exists: held 20–30° with a 0.2 r throat-flutter wobble.
   - **Feeding** on a perch with prey (later): 20–45° bites.

### 4.7 Per-species data table

This follows `BodyShape.DATA`: angles in degrees, sizes in head radii, colours as sRGB hex strings (`Color.html()`).
- **Hex values are estimates [E]** unless a matching value already exists in `plumage_coloring.md` (crow bill `#121214`, hawk cere `#e3c04a`, falcon cere and ring `#e8c547`).
- Beak lengths assume option A head sizes (§4.1); multiply them by ≈ 0.6 under option B.

```gdscript
## Faces: head shape, eyes, beak, head range of motion and behaviour (docs/research/eyes_and_beaks.md).
## Sizes in head radii r; angles in degrees; colours sRGB hex.
const FACE := {
	"crow": {
		"head_scale": Vector3(0.88, 0.9, 1.15), "brow": 0.15, "disc": "",
		"eye": {"r": 0.2, "az": 62.0, "el": 14.0, "sink": 0.3, "tilt": -20.0, "rom": 16.0},
		"iris": "#2a1e18", "pupil": "#050505", "pupil_frac": 0.55, "ring": "#1b1b1f", "ring_w": 0.08,
		"beak": {"len": 2.0, "depth": 0.78, "width": 0.6, "upper": 0.55, "taper": 0.9, "droop": 0.08,
				"hook": 0.04, "tooth": 0.0, "cere": 0.0, "bristle": 0.3, "pitch": 0.0},
		"bill": "#121214", "bill_tip": "#121214", "cere_col": "", "gape_col": "#2b2326",
		"gape_max": 40.0, "kinesis": 5.0,
		"head_yaw": 150.0, "head_pitch": [-80.0, 60.0], "head_roll": 60.0,
		"fix_s": 1.0, "sac_speed": 700.0, "blink_pm": 18.0, "look_up": 1.0, "peer": 0.0, "walk_bob": true,
		"juvenile": {"iris": "#8fa3b3", "gape_col": "#d98a8f"},
	},
	"owl": {   # Barn Owl face (matches plumage_coloring.md's Barn top and face)
		"head_scale": Vector3(1.0, 1.05, 0.8), "brow": 0.0, "disc": "heart",
		"eye": {"r": 0.12, "az": 31.0, "el": 8.0, "sink": 0.15, "tilt": 0.0, "rom": 1.0},
		"iris": "#1a120e", "pupil": "#050404", "pupil_frac": 0.7, "ring": "#3a2c26", "ring_w": 0.25,
		"beak": {"len": 0.3, "depth": 0.18, "width": 0.15, "upper": 0.7, "taper": 1.0, "droop": 0.3,
				"hook": 0.35, "tooth": 0.0, "cere": 0.0, "bristle": 0.0, "pitch": -35.0},
		"bill": "#e2d3b6", "bill_tip": "#cdb68f", "cere_col": "", "gape_col": "#d9a0a0",
		"gape_max": 30.0, "kinesis": 3.0,
		"head_yaw": 160.0, "head_pitch": [-80.0, 80.0], "head_roll": 90.0,
		"fix_s": 2.0, "sac_speed": 600.0, "blink_pm": 4.0, "look_up": 0.0, "peer": 0.6, "walk_bob": false,
	},
	"owl_gho": {   # Great Horned Owl variant: yellow eyes, round disc, ear tufts, dark bill
		"head_scale": Vector3(1.08, 0.95, 0.85), "brow": 0.0, "disc": "round", "tufts": 0.45,
		"eye": {"r": 0.2, "az": 32.0, "el": 10.0, "sink": 0.15, "tilt": 0.0, "rom": 1.0},
		"iris": "#f0b429", "pupil": "#080706", "pupil_frac": 0.5, "ring": "#151312", "ring_w": 0.1,
		"beak": {"len": 0.35, "depth": 0.2, "width": 0.17, "upper": 0.7, "taper": 1.0, "droop": 0.3,
				"hook": 0.35, "tooth": 0.0, "cere": 0.3, "bristle": 0.0, "pitch": -30.0},
		"bill": "#3b3e43", "bill_tip": "#2a2c30", "cere_col": "#55585e", "gape_col": "#d9a0a0",
		"gape_max": 30.0, "kinesis": 3.0,
		"head_yaw": 160.0, "head_pitch": [-80.0, 80.0], "head_roll": 90.0,
		"fix_s": 2.5, "sac_speed": 500.0, "blink_pm": 4.0, "look_up": 0.0, "peer": 0.5, "walk_bob": false,
	},
	"hawk": {   # Red-tailed Hawk, adult
		"head_scale": Vector3(1.0, 0.88, 1.08), "brow": 1.0, "disc": "",
		"eye": {"r": 0.24, "az": 48.0, "el": 10.0, "sink": 0.25, "tilt": 0.0, "rom": 5.0},
		"iris": "#5a321e", "pupil": "#070606", "pupil_frac": 0.45, "ring": "#3a2a20", "ring_w": 0.08,
		"beak": {"len": 1.05, "depth": 0.6, "width": 0.45, "upper": 0.65, "taper": 0.8, "droop": 0.15,
				"hook": 0.22, "tooth": 0.0, "cere": 0.25, "bristle": 0.0, "pitch": 0.0},
		"bill": "#4a4d55", "bill_tip": "#18181b", "cere_col": "#e3c04a", "gape_col": "#e8b9a6",
		"gape_max": 45.0, "kinesis": 4.0,
		"head_yaw": 130.0, "head_pitch": [-80.0, 60.0], "head_roll": 45.0,
		"fix_s": 4.0, "sac_speed": 450.0, "blink_pm": 15.0, "look_up": 0.5, "peer": 0.15, "walk_bob": false,
		"juvenile": {"iris": "#d6c27a"},
	},
	"falcon": {   # Peregrine, adult
		"head_scale": Vector3(1.0, 0.95, 1.02), "brow": 0.7, "disc": "",
		"eye": {"r": 0.25, "az": 44.0, "el": 10.0, "sink": 0.25, "tilt": 0.0, "rom": 1.0},
		"iris": "#24170f", "pupil": "#050404", "pupil_frac": 0.5, "ring": "#e8c547", "ring_w": 0.3,
		"beak": {"len": 1.0, "depth": 0.7, "width": 0.5, "upper": 0.65, "taper": 0.8, "droop": 0.15,
				"hook": 0.25, "tooth": 0.7, "cere": 0.2, "bristle": 0.0, "pitch": 0.0},
		"bill": "#6f7f93", "bill_tip": "#1d1f24", "cere_col": "#e8c547", "gape_col": "#e8b9a6",
		"gape_max": 45.0, "kinesis": 4.0,
		"head_yaw": 130.0, "head_pitch": [-80.0, 60.0], "head_roll": 45.0,
		"fix_s": 2.5, "sac_speed": 600.0, "blink_pm": 15.0, "look_up": 0.5, "peer": 0.3, "walk_bob": false,
		"juvenile": {"ring": "#9fb0bd", "cere_col": "#9fb0bd"},
	},
	"sparrow": {   # House Sparrow, male (breeding bill)
		"head_scale": Vector3(1.0, 1.0, 1.02), "brow": 0.0, "disc": "",
		"eye": {"r": 0.22, "az": 68.0, "el": 12.0, "sink": 0.3, "tilt": -15.0, "rom": 16.0},
		"iris": "#3a2516", "pupil": "#070606", "pupil_frac": 0.55, "ring": "#2a221c", "ring_w": 0.08,
		"beak": {"len": 1.25, "depth": 0.75, "width": 0.7, "upper": 0.5, "taper": 1.0, "droop": 0.04,
				"hook": 0.0, "tooth": 0.0, "cere": 0.0, "bristle": 0.0, "pitch": 0.0},
		"bill": "#1c1c1e", "bill_tip": "#1c1c1e", "cere_col": "", "gape_col": "#c98a7a",
		"gape_max": 50.0, "kinesis": 3.0,
		"head_yaw": 150.0, "head_pitch": [-80.0, 60.0], "head_roll": 60.0,
		"fix_s": 0.45, "sac_speed": 900.0, "blink_pm": 18.0, "look_up": 1.0, "peer": 0.0, "walk_bob": false,
		"female": {"bill": "#8a7d66", "bill_tip": "#6b6152"}, "nonbreeding": {"bill": "#6b6357"},
		"juvenile": {"bill": "#d9c27a", "gape_col": "#f2d36b"},
	},
}
```

Where each value comes from:
- `eye.az`: §1.2 (owl and crow [S]; the rest [E]).
- `eye.rom`: §1.5 [S]. The falcon uses the Kestrel proxy, and owl values are tiny on purpose.
- `eye.r`, `el`, `sink`, `tilt`: [E] from photographs. The crow's `tilt` follows [ITAHARA].
- `beak` lengths, depths and widths: §2.2. The falcon is [S] (moderate); the others mix [F] lengths with [E] depths.
- `gape_max`, `kinesis`: §2.3. The song gapes and the 8° kinesis cap are [S]; the per-species maxima are [E].
- `head_yaw`: §3.1. The owl's figure is [S], with the ambiguity noted; the rest are [E]. `head_pitch` and `head_roll` are [E].
- `fix_s`: §3.4, converted [E]. The crow's 0.8–1.0 s comes from [FJ-CROW] [S].
- `sac_speed`: [E], in the [PIGEON-SAC] range of 400–1,200°/s; larger birds are slower [OCHS].
- `blink_pm`: §3.5; the owl's figure is [F], the rest [E].
- `peer`: [E] amplitude, for a behaviour sourced in [HW-BARN][OROURKE-II].
- `look_up`: the share of the one-eyed roll (§4.6); [E].

### 4.8 Build order (biggest visual win first)

**Status (built, `scripts/bird/face.gd` and `BirdRig._build_face` / `_gaze`):** items 1-4 -- lens-cap eyes (pupil, iris, eye-ring, lid rim), brow ridges, lofted two-piece beaks (taper, droop, hook, falcon tooth, cere, crow bristles), option A head sizes (§4.1), the saccade-and-fixate head with blinks (a nictitating membrane sweeping from the bill side), and the Barn Owl's heart-shaped disc. One deviation: the eye caps sit on the head's surface rather than sunk by `sink` (a lens cap sunk 0.3 r would be hidden inside the head). The jaw has its pivot but isn't driven yet; head roll, peering, the crow's walking bob and eye-in-socket movement (items 5-8) are not built. A/B: `docs/images/faces_before_after.png`.

1. **Eyes that read** (about half a day).
   - Replace the black spheres with lens caps: iris, pupil and lid ring as vertex colours. Use the per-species size and placement, the falcon's yellow ring and the owl's dark rim.
   - Add the **brow ridge** on hawk and falcon.
   - Wins: it separates the species' faces at a glance, gives the raptor frown, and shows the look direction at chase-cam distance.
   - Needs only `FACE.eye`, `iris`, `pupil`, `ring`, `brow`.
2. **Lofted beaks plus head proportions** (about a day).
   - Two-piece upper and lower mandible tube meshes with hook, droop, cere band, falcon tooth and crow bristles.
   - Apply option A or B (§4.1), and the per-species head scale.
   - The cone is the least bird-like thing on the head today.
3. **Saccade-and-fixate head motion, with blinks on big saccades** (about half a day, code only).
   - Replace the continuous `look_dir` slerp with log-normal fixations and fast saccades. Fire a nictitating blink on gaze shifts over 15–20°, plus the background rate.
   - This is the cheapest "it's alive" change: a still bird stops looking like a turret.
4. **Owl facial disc** (heart for the Barn Owl, round plus ear tufts for the GHO), with the flattened owl head and the buried, down-pointing bill. The owl becomes an owl.
5. **Jaw joint, with coupled kinesis.** Calls, song, panting and bill-snaps. The visible payoff is small at range, but the crow's caw and the sparrow's chirp land in close-ups.
6. **Head roll:** the one-eyed look up, and curiosity cocks. This needs the level-head rule relaxed to a roll channel.
7. **Peering (owl, falcon), the crow's walking bob, and the body turning to follow the head.**
8. **Eye-in-socket yaw and pitch** for the crow and sparrow (±8°), and the owls' upper lid (sleepy and roosting).

Tests:
- Extend `TestCase`: per species, the beak tip lies within ±10% of `len × r` ahead of the head centre.
- Eye centres lie on the head shell, within 0.02 r of `(1 − sink) r`.
- No eye penetrates the disc or brow.
- The saccade scheduler's fixation mean over 1,000 draws lies within ±10% of `fix_s`.
- Head yaw, pitch and roll never exceed their `FACE` limits.

---

## Sources

Peer-reviewed and institutional sources first. Weak sources are flagged.

**Visual fields, eyes and eye movement**
- [OROURKE-I] O'Rourke et al. 2010, "Hawk Eyes I: diurnal raptors differ in visual fields and degree of eye movement", *PLoS ONE* 5: e12802: https://pmc.ncbi.nlm.nih.gov/articles/PMC2943905/
- [OROURKE-II] O'Rourke et al. 2010, "Hawk Eyes II: diurnal raptors differ in head movement strategies when scanning from perches", *PLoS ONE* 5: e12169: https://pmc.ncbi.nlm.nih.gov/articles/PMC2943910/
- [FJ-CROW] Fernández-Juricic et al. 2010, "Visual coverage and scanning behavior in two corvid species: American crow and Western scrub jay", *J. Comp. Physiol. A* 196: 879–888: https://estebanfj.bio.purdue.edu/papers/JCompPhysA%20196.pdf
- [FJ-SPARROW] Fernández-Juricic et al. 2008, "The visual fields of two ground-foraging birds, House Finches and House Sparrows…", *Ibis* 150: 779–787: https://estebanfj.bio.purdue.edu/papers/Ibis%20150.pdf (record: https://research.birmingham.ac.uk/en/publications/the-visual-fields-of-two-ground-foraging-birds-house-finches-and-/)
- [ITAHARA] Itahara & Kano 2024, large-billed crow visual fields and gaze, *J. Exp. Biol.* (doi 10.1242/jeb.246514): https://kops.uni-konstanz.de/entities/publication/ec3493ba-d485-41cd-ac01-277994d170f1
- [POTIER-OWL] Potier et al. 2023, "Binocular field configuration in owls: the role of foraging ecology", *Proc. R. Soc. B*: https://pmc.ncbi.nlm.nih.gov/articles/PMC10581762/
- [HW-BARN] Harmening & Wagner 2011, "From optics to attention: visual perception in barn owls", *J. Comp. Physiol. A*: https://ao.ukbonn.de/pdfs/Harmening,%20Wagner_2011_From%20optics%20to%20attention%20visual%20perception%20in%20barn%20owls.pdf
- [VU-RAPTOR] Review of raptor vision (Tawny Owl cyclopean field 201°, Great Horned Owl eye movement); seen only through search summaries: https://epublications.vu.lt/object/elaba:67617417/67617417.pdf **[F]**
- [TUCKER] Tucker et al. 2000, "Curved flight paths and sideways vision in peregrine falcons", *J. Exp. Biol.* 203: 3755–3763 (abstract): https://scholars.duke.edu/publication/842264
- [ROOK] Schematic eye of the rook, *Corvus frugilegus* (University College Cork): https://research.ucc.ie/en/publications/the-schematic-eye-of-the-rook-corvus-frugilegus/
- [BROOKE] Brooke, Hanley & Laughlin 1999, "The scaling of eye size with body mass in birds", *Proc. R. Soc. B*: https://pmc.ncbi.nlm.nih.gov/articles/PMC1690967 (the figures were read via [WIKI-BV])
- [BURTON] Summary of Burton 2008, "The scaling of eye size in adult birds…", *Vision Research* (University of Maryland course page): https://science.umd.edu/faculty/wilkinson/BSCI338/Rev092/Burton08.htm **[F]**
- [WILSON-1889] Early note on eye weight vs brain weight, *Wilson Bulletin* 1(1): https://sora.unm.edu/sites/default/files/journals/wilson/v001n01/p0044-p0045.pdf **[F, anecdotal]**
- [UMN-RC] The Raptor Center, University of Minnesota, "What makes a raptor, part 3: keen eyesight": https://raptor.umn.edu/about-us/news/what-makes-raptor-part-3-keen-eyesight
- [PF-VISION] The Peregrine Fund, "Keen vision": https://www.peregrinefund.org/keen-vision
- [WIKI-BV] Bird vision, Wikipedia: https://en.wikipedia.org/wiki/Bird_vision **[F]**
- [WIKI-SR] Scleral ring, Wikipedia (mirror): https://wiki.krisyotam.com/content/wikipedia_en_all_nopic_2026-03/Scleral_Ring **[F]**
- [CALACAD] California Academy of Sciences, "The bird eyes have it": https://www.calacademy.org/blogs/project-lab/the-bird-eyes-have-it
- [VMS-OWL] Long-eared owl scleral ring study, *Veterinary Medicine and Science* 2022: https://doaj.org/article/25402af009c74ddebaac2fa6d2c3d4fd

**Head motion, saccades, bobbing, blinking**
- [PIGEON-SAC] Pigeon head saccades in turning flight, *Frontiers in Neuroscience* 2017: https://www.frontiersin.org/journals/neuroscience/articles/10.3389/fnins.2017.00655/full
- [OCHS] Ochs et al. 2017, "Sneak peek: raptors search for prey using stochastic head turns", *The Auk* 134: 104–115: https://bioone.org/journals/the-auk/volume-134/issue-1/AUK-15-230.1/Sneak-peek--Raptors-search-for-prey-using-stochastic-head/10.1642/AUK-15-230.1.short (abstract only)
- [KRINGS] Krings et al. 2017, "Barn owls maximize head rotations by a combination of yawing and rolling…", *J. Anat.* 231: 12–22: https://pmc.ncbi.nlm.nih.gov/articles/PMC5472525
- [JHU-OWL] de Kok-Mercado et al. 2013 (Johns Hopkins), owl head rotation, reported by Phys.org: https://phys.org/news/2013-01-scientists-owl-rotate-blood.pdf **[F]**
- [NECKER] Necker, "Head-bobbing of walking birds: a review": https://reinhold-necker.de/seite10.html
- [YORZINSKI] Yorzinski 2016, "Eye blinking in an avian species is associated with gaze shifts", *Sci. Rep.*: https://pmc.ncbi.nlm.nih.gov/articles/PMC5004160
- [FEVO-BLINK] Blinking and head movements in foraging chickens, *Frontiers in Ecology and Evolution* 2017: https://www.frontiersin.org/journals/ecology-and-evolution/articles/10.3389/fevo.2017.00131/full
- [KIRSTEN] Kirsten & Kirsten 1983, blink rates of owls and diurnal birds, *Condor* 85: https://sora.unm.edu/sites/default/files/journals/condor/v085n01/p0092-p0093.pdf (redirects; numbers via search summary) **[F]**
- [JFO-1972] Nictitation rates of wild birds, *J. Field Ornithol.* (formerly *Bird-Banding*) 43(4): https://sora.unm.edu/sites/default/files/journals/jfo/v043n04/p0289-p0290.pdf (numbers via search summary) **[F]**
- [AUD-NC] Audubon North Carolina, shorebirds tilting the head to look up: https://nc.audubon.org/node/6531 **[F]**

**Beaks and jaws**
- [WIKI-BEAK] Beak, Wikipedia: https://en.wikipedia.org/wiki/Beak **[F]**
- [WOODPECKER] Upper beak depression instead of elevation dominates cranial kinesis in woodpeckers, *Biol. Lett.* 2023: https://pmc.ncbi.nlm.nih.gov/articles/PMC10244965/
- [GUSSEKLOO] Gussekloo, Vosselman & Bout 2001, 3-D kinematics of prokinetic and rhynchokinetic skulls, *J. Exp. Biol.* 204: 1735–1744 (record): https://research-portal.uu.nl/en/publications/three-dimensional-kinematics-of-skeletal-elements-in-avian-prokin/
- [HOESE] Hoese & Westneat 1996, cranial kinesis in the White-throated Sparrow, *J. Morphol.* 227: 305–320 (abstract): https://bvbvf1.bib-bvb.de/vufind/PrimoRecord/cdi_proquest_miscellaneous_2049549866
- [WESTNEAT] Westneat et al. 1993, "Kinematics of birdsong…", *J. Exp. Biol.* 182: 147–171: https://cob.silverchair.com/jeb/article-pdf/182/1/147/3383607/jexbio_182_1_147.pdf
- [TAHIR] Tahir et al., morphometrics of *Falco peregrinus peregrinus* rescued in Pakistan, *Sarhad J. Zool.*: https://media.researcherslinks.com/uploads/currentIssues/pdf/1778339397SAJZ_44_1_37-41.pdf (small regional journal: moderate)
- [FALC-BLOG] "Notch in peregrine falcon's beak" (tomial tooth absent in buteos and eagles): https://redandthepeanut.blogspot.com/2012/02/notch-in-peregrine-falcons-beak.html **[F, weak]**
- [BTO-CORV] BTO, Corvidae (bristle-covered nostrils): https://www.bto.org/learn/about-birds/bird-families/corvidae-crows
- [WB-RAVEN] "A quantitative study of nasal bristle length in the Common and Chihuahuan ravens", *Western Birds*: https://www.journal.westernfieldornithologists.org/index.php/westernbirds/article/view/865
- [SMIT] Smit et al. 2018, panting and gular flutter, *J. Exp. Biol.*: https://cob.silverchair.com/jeb/article-pdf/doi/10.1242/jeb.174870/2041601/jeb_174870v1.pdf
- [RSPB-HEAT] RSPB, "How to help birds beat the heat": https://www.rspb.org.uk/whats-happening/news/how-to-help-birds-beat-the-heat

**Species accounts and colours**
- [WIKI-RT] Red-tailed hawk: https://en.wikipedia.org/wiki/Red-tailed_hawk ; [WIKI-RTSUB] subspecies culmen means, e.g. https://en.wikipedia.org/wiki/Western_red-tailed_hawk **[F]**
- [WIKI-PF] Peregrine falcon: https://en.wikipedia.org/wiki/Peregrine_falcon **[F]**
- [NIRSG] Northern Ireland Raptor Study Group, Peregrine (yellow cere and eye-ring, dark eye): https://www.nirsg.com/?p=297 **[F]**
- [WIKI-GHO] Great horned owl: https://en.wikipedia.org/wiki/Great_horned_owl **[F]**
- [WIKI-BO] Western barn owl: https://en.wikipedia.org/wiki/Western_barn_owl **[F]**
- [WIKI-FD] Facial disc: https://en.wikipedia.org/wiki/Facial_disc **[F]**
- [NATHAB] Natural Habitat Adventures, owl heads built for hearing (downward bill): https://www.nathab.com/blog/video-owls-have-heads-designed-for-hearing **[F]**
- [BOULDER] Boulder County Open Space, how an owl hears: https://bouldercountyopenspace.org/naturalhistory/pdf/owl-hears.pdf
- [WIKI-AC] American crow: https://en.wikipedia.org/wiki/American_crow **[F]**
- [CROW-EYE] Juvenile crow blue eyes and pink mouth: Santa Clara Valley Bird Alliance, https://scvbirdalliance.org/backyard-bird-blog/notes-and-tips-may2021 ; Tweeters list, https://mailman1.u.washington.edu/pipermail/tweeters/2025-June/007208.html **[F, weak]**
- [WIKI-HS] House sparrow: https://en.wikipedia.org/wiki/House_sparrow **[F]**
- [ZOO-HS] Wereldtuinen Mondo Verde, house sparrow (dark brown iris): https://www.wereldtuinenmondoverde.nl/en/zoo/house-sparrow/ **[F, weak]**
- [AUD-EYES] Audubon, "Why do birds' eyes change colors?": https://www.audubon.org/news/why-do-birds-eyes-change-colors
- [NM-BLOG] Nictitating membrane examples (quoting Birkhead): https://todd-henson.squarespace.com/blog/examples-bird-third-eyelid-nictitating-membrane **[F, weak]**

**Gaps worth closing later:**
- measured voluntary head-yaw ranges for non-owl birds;
- measured visual fields of the Barn Owl, the Great Horned Owl and the Peregrine (Kestrel and Snowy Owl stand in);
- bill depth and width for crow, hawk and sparrow (the AVONET dataset, Tobias et al. 2022, *Ecology Letters*, has beak depth and width at the nostrils for every species);
- cranial-kinesis angles specifically for corvids (Gussekloo et al. 2001, full text);
- head-saccade kinematics in raptors (only pigeon and Barn Owl numbers here).
