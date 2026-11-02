# Wing anatomy: muscles, tendons and the shape of the wing

What is inside a bird's wing, why the wing is thick at the front and thin behind, and how it folds. The last section maps each part to `scripts/bird/bird_rig.gd` (the `LIMB` table, the fold IK in `build()` and `apply_pose()`) and `scripts/bird/wing_shape.gd`. Companion notes: `wing_shapes_and_articulation.md` (wing classes, joints in flight, the flap cycle) and `body_poses_and_folded_wings.md` (where the folded wing sits on the body).

Tags, as in `body_poses_and_folded_wings.md`:
- **[S]** sourced from a paper, a museum or university page.
- **[W]** sourced from Wikipedia or a reference site only.
- **[E]** our own estimate or reading, not sourced.

Source numbers such as [3] refer to the list at the end.

---

## 1. The flight muscles are in the breast

| Muscle | Where | Job | Size | Tag |
|---|---|---|---|---|
| **Pectoralis** | On the keel of the sternum and the furcula; inserts on the deltopectoral crest of the humerus | Pulls the wing down and forward: the power stroke | about 8–11 % of body mass, the largest flight muscle | [S] [1] |
| **Supracoracoideus** | Under the pectoralis, also on the keel | Raises and supinates (twists) the wing on the upstroke | about one-fifth of the pectoralis, about 2 % of body mass | [S] [1][2] |

- **The pulley.** The supracoracoideus sits *below* the wing, yet it raises it. Its tendon runs up through the **triosseal canal** (the foramen triosseum, the gap where the coracoid, scapula and furcula meet at the shoulder) and turns over the top of the shoulder to insert on the dorsal surface of the humerus [1]. The canal works like a pulley: a muscle on the breast pulls the wing up. **[S]** ("pulley" is the usual description, not a quoted term.)
- **It mostly twists.** Stimulating the supracoracoideus in starlings produced a fast rotation of the humerus about its long axis, with only limited elevation. That rotation sets the wing up for the next downstroke [2]. **[S]**
- **The upstroke is partly free.** At higher speeds the wing is probably raised largely by aerodynamic force. The supracoracoideus matters most at slow speed and in hovering, and its tendon stores a little elastic energy [1]. **[S]**
- **Why it matters for the model.** Both power muscles sit on the body, not on the wing. The wing itself is light, which keeps its inertia down (section 2).

## 2. The arm: muscle near the body, tendon toward the tip

- **The intrinsic wing muscles are short and tendinous.** The biceps and the triceps (humerotriceps and scapulotriceps) flex and extend the elbow. The intrinsic wing muscles are "commonly short fibred and pinnate, and have long tendons", and add little mechanical power; they control the wing's shape [1]. **[S]**
- **They taper outward.** Muscle bellies sit near the shoulder and the elbow, and long tendons carry their pull to the wrist and hand. The hand (carpometacarpus and digits) is mostly bone, tendon and skin. **[E]**, consistent with [1]; I found no source that states the hand's make-up directly.
- **The mass sits near the body.** Across 22 species the wing's centre of gravity sits close to the shoulder, at about 10–27 % of the half-span depending on the elbow and wrist angles [3]. The moment of inertia tracks wing mass × length² closely, and is small when the mass is concentrated near the base [4]. **[S]**
- **The forearm muscles shape the wing rather than power it.** Pigeons with their distal wing muscles denervated could still flap in level flight, but could not take off or land under control [5]. **[S]** (abstract only)

## 3. The leading edge: the propatagium

- **What it is.** The propatagium is the elastic fold of skin from the shoulder to the wrist (the carpal joint). It forms the leading edge of the inner wing, in front of the elbow [6][7]. **[S]/[W]**
- **The tendon that holds it taut.** The tensor propatagialis runs along the fold's front rim:
  - *Pars longa*: an elastic tendon along the leading edge, inserting near the base of the alular digit. It keeps the propatagium taut, and helps extend the wrist when the elbow extends [8]. **[W]** (veterinary reference; the canonical source is Baumel et al. 1993 [9], not checked)
  - *Pars brevis*: a tendon to the forearm muscles [8]. **[W]**
- **It holds the camber.** In great horned owls, networks of collagen and elastic fibres between the leading-edge ligament and the forearm support a cambered propatagium [6]. In a later study, intact wings extended by themselves in an airflow, roughly in proportion to its speed. The propatagial ligaments, together with the deltoideus pars propatagialis, stop the elbow over-extending and keep the camber; they form the wing's extension control [7]. **[S]**
- **It makes a straight leading edge.** Because the fold spans shoulder to wrist across the angle of the elbow, the arm wing's leading edge runs straight from shoulder to wrist, and the elbow lies behind it. **[S]** for the fold's span [6][7]; **[E]** for "straight".

## 4. The trailing edge: flight feathers on bone and ligament

- **Secondaries sit on the ulna.** Their quills are bound by ligaments to small bumps along the back of the ulna, the **quill knobs** (ulnar papillae). They are well enough marked that they are found in fossils, for example six on a *Velociraptor* ulna [10][11]. Some species lack visible knobs [11]. **[S]/[W]**
- **Primaries sit on the hand** [12][11]. **[S]/[W]**

  | Primaries | Attached to |
  |---|---|
  | p1–p6 | the carpometacarpus (7 in grebes, storks and flamingos) |
  | p7 | phalanx 1 of the minor digit |
  | p8–p9 | phalanx 1 of the major digit |
  | p10 (and the small remicle, p11) | phalanx 2 of the major digit |

- **Elastic tissue links the feathers.** The quills are embedded in the postpatagium, the skin web behind the arm [13]:
  - An elastic ligament runs through the bases of the flight feathers from the hand to the elbow (the interremigial or postpatagial ligament). It spreads and closes them together as the skeleton moves [14]. **[S]** for the function (abstract only); the ligament's name is from secondary sources and was not verified.
  - Smooth muscle attached to the follicles by elastic tendons coordinates groups of feathers [13][15]. **[S]**
  - Hooked microstructures on neighbouring feathers lock them together as the wing spreads. Barn owls lack them [14]. **[S]** (abstract only)

## 5. The cross-section is an airfoil

- **Thick in front, thin behind.** The bones, the muscle bellies and the propatagium's tendon all run along the front of the wing. Behind them there are only feathers. So the section is rounded and thick near the leading edge, then thins to a sharp trailing edge of feathers. **[E]** (standard anatomy, not quantified in a source I could read)
- **Cambered.** The propatagium and the arm wing are cambered [6][7]. Laser scans of seagull, merganser, teal and owl wings give analytic fits for the camber line and thickness distribution [16]. **[S]** (abstract only; I did not see the numbers)
- **The thickest part is the arm.** The humerus and forearm, with their muscle, are thick. The hand is thin bone and tendon. **[E]**, consistent with section 2.

## 6. The fold: a Z, coupled at elbow and wrist

- **The Z-fold.** Folded, the humerus lies aft along the body from the shoulder, the forearm folds back forward along it, and the hand folds aft again against the forearm. The wrist, the "bend of the wing", forms the front corner [17] (see `body_poses_and_folded_wings.md` §1.1). **[S]** (1911 Britannica description); Stowers et al. say only that the wrist's range lets the wing fold fully against the body [18].
- **Elbow and wrist move together.** Bending the elbow bends the wrist, and straightening one straightens the other.
  - The classic explanation is the **"drawing parallels"** mechanism. The radius and ulna act like the two rules of a parallel ruler. When the elbow flexes, the radius slides along the ulna and pushes the wrist into flexion. It goes back to Bergmann 1839 and was described by Coues 1871. Fisher confirmed the coupling surgically in pigeons in 1957 [18][19][20]. **[S]**
  - The flexor carpi ulnaris works with the bones, so the hand swings in toward the body automatically when the elbow flexes [21]. **[S]** (abstract only)
  - The propatagial tendon does the reverse on extension: elbow extension tensions it, which extends the wrist [7][8]. **[S]/[W]**
  - Measured in 3D, the bones' motion is strongly non-planar, which rules out a flat four-bar linkage. Both wrist bones take part, especially a sliding ulnare. A six-bar linkage with a parallel radius and ulna and a sliding ulnare fits pigeon wings accurately [18]. **[S]**
- **One input runs it.** A pigeon-inspired robot wing (PigeonBot) moves 40 real feathers on elastic links using only 4 servo-driven wrist and finger joints [22]. **[S]** (abstract only)

---

## 7. How the rig maps to this

The wing is three bones per side, `humerus`, `forearm` and `hand` (`WingShape.Bone`), driven by `flap`, `fold`, `sweep`, `twist`, `alula`, plus `hand_lift` for the upstroke and `slot`. The anatomy above maps onto it as follows.

### 7.1 Muscle, tendon and skin: the `LIMB` table

`BirdRig.LIMB` gives the wing its thickness: four lofted pieces per wing, each with an airfoil section. Thickness and chord are fractions of the wing's root chord (`WingShape.root_chord()`). `u` runs 0 at the piece's root end to 1 at its far end.

| Piece | Anatomy it stands for | Thickness, root → far end | Chord, root → far end | Muscle belly | Notes in code |
|---|---|---|---|---|---|
| 0 Propatagium | The skin fold, shoulder → wrist, with the tensor propatagialis along its rim (§3) | 0.06 → 0.035 | a hump: 0.15 + 0.85·sin(πu)^0.6, deepest mid-span | none | Laid from shoulder to wrist, so its leading edge *is* the straight line (no nose offset). Its depth is set each pose so it reaches back over the elbow (`web` in `apply_pose()`). It fades out with `1 − fold`: the fold slackens. |
| 1 Humerus | Biceps, triceps, deltoid (§2) | 0.12 → 0.08 | 0.40 → 0.32 | at u = 0.35 | The thickest piece. |
| 2 Forearm | Muscle bellies by the elbow, tendons toward the wrist (§2) | 0.11 → 0.045 | 0.34 → 0.24 | at u = 0.15 | Tapers hard: tendon, not muscle, near the wrist. |
| 3 Hand | Bone and tendon (§2) | 0.05 → 0.022 | 0.22 → 0.10 | none | Thin. |

- **Muscle belly.** Where a piece has one, `limb_section()` adds a Gaussian bulge of up to +30 % thickness (width 0.22 in `u`).
- **Section** (`_limb_mesh()`). A NACA 4-digit thickness form, round and thick at the front and thin behind (§5). It has a slight camber of 0.02 chord. The bone runs just behind the nose (6 % of chord).
- **The breast muscles** (§1) are not on the wing. They are the body shell's deep breast ring (the keel ring in `BodyShape`; see `body_anatomy.md`).
- **The trailing edge** is the flight feathers, laid behind the limb pieces.

The thickness numbers are estimates chosen to read right. No source gives wing thickness as a fraction of chord per segment. **[E]**

### 7.2 Feathers on bones

`WingShape.feathers()` defines every feather on a bone: (bone, position along it, angle to it, length, width).

| Anatomy | Rig | Match |
|---|---|---|
| Secondaries on the ulna's quill knobs (§4) | `SECONDARY` on `FOREARM`, 9–14 per species (`nsec`), wrist to elbow | yes |
| Primaries p1–p6 on the carpometacarpus, p7–p10 on the digits (§4) | All 10 `PRIMARY` on the single `HAND` bone, spread along it (`t`) | The rig has no separate digits. The hand bone stands for the carpometacarpus and digits together. |
| Tertials at the elbow end of the humerus | 3 `TERTIAL` on `HUMERUS` near its far end | yes |
| Coverts over the feather bases | `GREATER_COVERT` over p1–p7 and every secondary; `LESSER_COVERT` rows on all three bones | Upper coverts only (see `plumage_coloring.md`). |
| Alula on digit I, at the wrist | 3 `ALULA` at the far end of `FOREARM` (`t` = 1, the wrist) | Placed at the wrist rather than on a thumb bone. It deploys 25° forward and lifts off the surface with `alula`. |
| Elastic ligament spreading and closing the feathers together (§4) | Each feather's angle to its bone (`rel`) is a function of `fold` (and `slot` for the emarginated tips), so the whole row fans and closes together. | Same behaviour, with no ligament modelled. |

### 7.3 The fold

**One value couples the elbow and wrist** (§6). `WingShape.bone_angles(fold)` sets all three bone directions in the wing plane from `fold` alone. Angles are measured with 0° outboard and positive aft.

| Bone | fold 0 (spread) | fold 1 (folded) |
|---|---|---|
| Humerus | 30° | 80° (running aft) |
| Forearm | −25° | −165° (running forward) |
| Hand | 8° | 92° (running aft) |

That is the Z of §6: humerus aft, forearm forward, hand aft. No input moves the elbow or the wrist alone, which is the drawing-parallels coupling. The rig drives it in the plane only; the non-planar six-bar motion [18] is not modelled. **[E]**

**Fold IK: `build()` sets each species' Z on its own body.**
1. The **folded elbow** (`fold_elbow`) starts one humerus length from the shoulder, aft and slightly down (direction (0, −0.25, 1)). It is slid onto the trunk shell (`BodyShape.onto_flank`, 1 % L of padding) four times, keeping the bone length.
2. The **folded wrist** (`fold_anchor`) is one forearm length from that elbow, toward a point ahead of and below the shoulder (shoulder + (0, −0.06 L, −0.10 L)). It is slid onto the shell the same way. So the wrist is the front corner, at the side of the breast.
3. The **hand** keeps its FK direction, which at fold 1 is aft.

**`apply_pose()` blends from FK to IK** as `ik_w = smoothstep(0.55, 1, fold)`:
- The wrist target slides from its FK place to `fold_anchor`, and the elbow pole from its FK place to `fold_elbow`.
- A two-bone IK (`two_bone`, `chain_end`) solves the elbow and wrist with the bone lengths kept.
- The wing surface's normal turns to face outward (`side_n`), so the folded wing is a panel on the flank.
- Feather directions blend to a folded direction: aft, about 6° down and 3° in. The folded wing lies flat, and the primaries cross over the tail.

**Other wing poses.**
- `hand_lift` (the upstroke) flexes the hand back in the wing plane and droops it about the forearm axis: the flexed-wing upstroke in `wing_shapes_and_articulation.md` §3.1.
- `sweep` swings the whole wing about the shoulder (protraction and retraction). `twist` sets the arm wing's incidence (pronation and supination).

### 7.4 What the rig leaves out
- The supracoracoideus pulley and the pectoralis act only through `flap`. No muscle is simulated.
- The wing's moment of inertia is not used: the flight model is a point mass (`docs/design/flight_model.md`).
- The digits, the ulnare and radiale, and the separate radius and ulna are not separate bones.
- The postpatagium has no mesh of its own. The secondaries and coverts cover it.

---

## Sources

1. Biewener AA 2011, "Muscle function in avian flight: achieving power and control", *Phil Trans R Soc B* 366:1496–1506, doi:10.1098/rstb.2010.0353. https://pmc.ncbi.nlm.nih.gov/articles/PMC3130450/ (full text)
2. Poore SO, Sánchez-Haiman A, Goslow GE 1997, "Wing upstroke and the evolution of flapping flight", *Nature* 387:799–802, doi:10.1038/42930. https://www.nature.com/articles/42930 (abstract)
3. Harvey C, Baliga VB, Wong JCM, Altshuler DL, Inman DJ 2022, "Birds can transition between stable and unstable states via wing morphing", *Nature* 603:648–653, doi:10.1038/s41586-022-04477-8. https://pmc.ncbi.nlm.nih.gov/articles/PMC8942853/
4. Van den Berg C, Rayner JMV 1995, "The moment of inertia of bird wings and the inertial power requirement for flapping flight", *J Exp Biol* 198:1655–1664. https://journals.biologists.com/jeb/article/198/8/1655/7027 (abstract)
5. Dial KP 1992, "Avian forelimb muscles and nonsteady flight: can birds fly without using the muscles in their wings?", *The Auk* 109:874–885, doi:10.2307/4088162. (abstract only)
6. Brown RE, Baumel JJ, Klemm RD 1994, "Anatomy of the propatagium: the great horned owl (*Bubo virginianus*)", *J Morphol* 219:205–224, doi:10.1002/jmor.1052190209. (search summary only)
7. Brown RE, Baumel JJ, Klemm RD 1995, "Mechanics of the avian propatagium: flexion-extension mechanism of the avian wing", *J Morphol* 225:91–105, doi:10.1002/jmor.1052250108. https://pubmed.ncbi.nlm.nih.gov/29865338/ (abstract)
8. DocCheck Flexikon, entry on the tensor propatagialis muscle (German veterinary reference, chicken; secondary; found by search, URL not recorded).
9. Baumel JJ et al. (eds) 1993, *Handbook of Avian Anatomy: Nomina Anatomica Avium*, 2nd ed., Nuttall Ornithological Club. Print reference; not checked.
10. Turner AH, Makovicky PJ, Norell MA 2007, "Feather quill knobs in the dinosaur *Velociraptor*", *Science* 317:1721, doi:10.1126/science.1145076. (abstract)
11. Wikipedia, "Quill knob" and "Flight feather". https://en.wikipedia.org/wiki/Quill_knob , https://en.wikipedia.org/wiki/Flight_feather
12. Stresemann E 1963, "Variations in the number of primaries", *The Condor* 65:449–459, doi:10.2307/1365506. (OCR text and search summary)
13. Navalón G, Marugán-Lobón J, Chiappe LM, Sanz JL, Buscalioni ÁD 2015, "Soft-tissue and dermal arrangement in the wing of an Early Cretaceous bird: implications for the evolution of avian flight", *Sci Rep* 5:14864, doi:10.1038/srep14864. https://pmc.ncbi.nlm.nih.gov/articles/PMC4594305/ (reviews the living-bird arrangement)
14. Matloff LY, Chang E, Feo TJ, Jeffries L, Stowers AK, Thomson C, Lentink D 2020, "How flight feathers stick together to form a continuous morphing wing", *Science* 367:293–297, doi:10.1126/science.aaz3358. (abstract)
15. Hieronymus TL 2016, "Flight feather attachment in rock pigeons (*Columba livia*): covert feathers and smooth muscle coordinate a morphing wing", *J Anat* 229:631–656. (abstract; DOI not confirmed)
16. Liu T, Kuykendoll K, Rhew R, Jones S 2006, "Avian wing geometry and kinematics", *AIAA J* 44:954–963, doi:10.2514/1.16224. Conference version: https://ntrs.nasa.gov/citations/20040075526 (abstract)
17. Encyclopaedia Britannica 1911, "Bird" (folded-wing bone positions); cited in `body_poses_and_folded_wings.md` [2].
18. Stowers AK, Matloff LY, Lentink D 2017, "How pigeons couple three-dimensional elbow and wrist motion to morph their wings", *J R Soc Interface* 14:20170224, doi:10.1098/rsif.2017.0224. https://pmc.ncbi.nlm.nih.gov/articles/PMC5582118/ (full text)
19. Coues E 1871, "Mechanism of flexion and extension in birds' wings", *American Naturalist* 5:513–514, doi:10.1086/270813. (as cited by [18]; Bergmann 1839, *Arch Anat Physiol wiss Med* 6:296–300, also via [18])
20. Fisher HI 1957, "Bony mechanism of automatic flexion and extension in the pigeon's wing", *Science* 126:446, doi:10.1126/science.126.3271.446. (as cited by [18])
21. Vazquez RJ 1994, "The automating skeletal and muscular mechanisms of the avian wing (Aves)", *Zoomorphology* 114:59–71, doi:10.1007/BF00574915. https://link.springer.com/doi/10.1007/BF00574915 (abstract)
22. Chang E, Matloff LY, Stowers AK, Lentink D 2020, "Soft biohybrid morphing wings with feathers underactuated by wrist and finger motion", *Science Robotics* 5:eaay1246, doi:10.1126/scirobotics.aay1246. (abstract)

**Not sourced:** the hand being "mostly bone, tendon and skin"; the deltoid's role in the upstroke; the per-segment thickness of the wing section; the name "ligamentum elasticum" for the feather-linking ligament. A general-interest figure of 15–25 % of body mass for the pectorals (repeated on Wikipedia's "Bird anatomy") is higher than the peer-reviewed 8–11 % [1], so this note uses [1]. The Hieronymus 2016 DOI was not confirmed.
