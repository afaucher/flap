# Body anatomy: the skeleton behind the body rig

What a bird's trunk, neck, tail and legs are made of and how they move. This is the research behind `docs/design/body_rig_plan.html` and its code, `scripts/bird/body_shape.gd` (`BodyShape`) and the neck, leg and head solves in `scripts/bird/bird_rig.gd`. Companion notes: `wing_anatomy.md` (the wing), `body_poses_and_folded_wings.md` (postures by state), `landing_and_takeoff.md` (the legs at touchdown and take-off).

Tags:
- **[S]** sourced from a paper, a museum or university page.
- **[W]** sourced from Wikipedia or a reference site only.
- **[E]** our own estimate, not sourced.

Source numbers such as [3] refer to the list at the end.

---

## 1. A rigid trunk

A bird's trunk is unusually stiff. Several sets of bones are fused or braced into one box, which is why a single rigid trunk bone is anatomically right.

| Part | What it is | Tag |
|---|---|---|
| **Notarium** | Fused thoracic vertebrae. It is characteristic of five orders and turns up in some families of five more; it arose at least 10 times independently. Proposed reasons are absorbing the shock of landing or striking prey, and stopping the thoracic spine bending down in flight [1][2]. | [S]/[W] |
| **Synsacrum** | The last thoracic, the lumbar, the sacral and the first caudal vertebrae, fused with each other and with the pelvis [3]. | [W] |
| **Keeled sternum** | The breastbone's keel (carina) anchors both flight muscles, the pectoralis and the supracoracoideus [3][4]. | [S]/[W] |
| **Uncinate processes** | Hook-like projections on the ribs that overlap the rib behind. They act as levers that raise the mechanical advantage of the breathing muscles on the dorsal ribs by 2–4×. They are short in walking birds, long in divers and intermediate in generalists [5][6]. | [S] |
| **Furcula** (wishbone) | The fused clavicles. In flying starlings it bends sideways on the downstroke and springs back on the upstroke [7]. | [S] |

**The notarium in our five species** [1][2]:

| Species | Notarium? | Tag |
|---|---|---|
| Falcon | **yes** (Falconidae is on the list) | [S]/[W] |
| Hawk (Accipitridae) | not listed | [W] |
| Owl | not listed | [W] |
| Crow, sparrow | none found in passerines by Storer 1982. Fused thoracic vertebrae were later reported in a few passerines (e.g. penduline tits), not crows or sparrows. | [S], snippet only for the later finding |

None of this changes the rig. The thoracic spine is short and braced by ribs and sternum even without a notarium. **[E]**

## 2. The neck

- **Vertebra counts.** Birds have from about 10 (many parrots) to 26 (swans) cervical vertebrae [8][9][10]. Counts depend on where the neck–thorax boundary is drawn.

  | Group | Cervical vertebrae | Tag |
  |---|---|---|
  | Owls | 14. The American barn owl's cervicals are C1–C14 [11]; three larger owls studied for head rotation also had 14 [12]. | [S] |
  | Hawks and eagles (Accipitriformes) | 12–15 [8] | [S] |
  | Falcons | Not verified. One weak source gives 15. | — |
  | Crows, sparrows (passerines) | 14 is the usual figure for passerines. Seen only in a search snippet of a handbook; not verified. | — |

  `body_rig_plan.html` says "13–14 cervical vertebrae in our five species". The owl's 14 is confirmed. The range for hawks runs to 15, and the falcon and passerine counts are unverified, so treat that line as approximate.
- **The S-curve.** At rest the neck is folded into an S. The barn owl's neck has functionally distinct regions along the S. The upper neck mostly yaws (turns), the lower neck mostly rolls, and the middle contributes least to head rotation [11][13]. **[S]**
- **Neck retraction.** Most of a resting bird's neck is hidden. Retracted, it folds into the S and the head sits on the shoulders; reaching, it shows as a neck. Herons fly with the neck retracted into an S, unlike most other long-necked birds, which fly with it extended [14]. **[W]** "Raptors rest the head on the shoulders when perched" is our reading of photographs. **[E]**
- **Owl head rotation.** The popular figure is about 270° in total [12]. A study of barn owls could not verify it: live owls reached at least 180°, and carcasses more than 360° [13]. **[S]**

## 3. The tail

- **Free caudals, then the pygostyle.** Behind the synsacrum come **five to nine free caudal vertebrae**, then the **pygostyle**, three to seven fused vertebrae at the tip of the tail [15]. The pygostyle anchors the tail muscles and the tail feathers. Aerial and terrestrial birds have a short, upturned pygostyle [15]. **[S]**
- **The rectricial bulbs.** Fat and muscle pads on either side of the pygostyle hold the tail feathers and move all of them except the central pair. That is what spreads and twists the fan [16]. **[W]**
- **The fan.** The short tail with a pygostyle and a fan of feathers replaced the long bony tail of *Archaeopteryx* [17]. **[S]** (citation and partial abstract only)

## 4. The leg

| Bone or joint | What it is | Where it shows |
|---|---|---|
| **Femur** | Short, held subhorizontal (near level) | Inside the body. The knee is hidden in the belly feathers and points forward. |
| **Tibiotarsus** | The tibia fused with the upper ankle bones (the "drumstick") | Partly feathered, partly visible below the belly |
| **Intertarsal joint** | The ankle, between the tibiotarsus and the tarsometatarsus | The joint people read as a "backward knee" |
| **Tarsometatarsus** | The fused lower ankle and foot bones | The visible bare "leg" |
| **Toes** | Four in most birds | — |

Sources: [18][19][20].
- **The subhorizontal femur** and a gait driven by flexing the knee are derived, uniquely avian traits [19]. **[S]**
- **The centre of mass moved forward** step by step along the line to birds, driven mainly by the forelimbs growing rather than the tail shrinking [21]. That is why the femur points forward, putting the knee and feet under the centre of mass. **[S]** (abstract) for the centre-of-mass shift; **[E]** for linking it to the femur here.
- **Sizes and postures differ.** Across ground birds from 45 g to 90 kg, once size is scaled out, the remaining differences in gait come from posture and segment lengths [22]. Perching joint angles differ significantly between cockatiels, Amazon parrots and barred owls [23]. **[S]**

## 5. The toes

| Arrangement | Toes | Who | Tag |
|---|---|---|---|
| **Anisodactyl** | Three forward, one back (the hallux) | Nearly all songbirds and most perching birds, including crows, hawks and falcons | [W] [18] |
| **Zygodactyl** | Two forward, two back (toes II and III forward, I and IV back) | Woodpeckers, cuckoos, parrots | [W] [18] |
| **Semi-zygodactyl** (facultatively zygodactyl) | Outer toe IV can swing back or forward | Owls, Osprey, turacos, mousebirds | [S] [24][25] |

- **How toe IV swings back.** In budgerigars, a strong abductor muscle of toe IV turns it backward during development; paralysed embryos stay anisodactyl [24]. **[S]**
- **When the Osprey uses it.** In Ospreys the odds of a zygodactyl grip were 5.7× higher when grasping in flight than when perched, and 4.1× higher when holding a fish in one foot [25]. **[S]**

## 6. The grip: tendon lock and the "automatic perching mechanism"

- **The digital tendon-locking mechanism.** On the underside of each toe's flexor tendon there are small tubercles. They mesh with ridges (plicae) on the inside of the tendon sheath, so a flexed toe can be held with little muscle effort [26]. Owls (Strigidae) have a lock like that of hawks and falcons; barn owls (Tytonidae) differ, with reversed plicae in digit 1 [27]. **[S]** (for [26], the citation and secondary descriptions; the abstract was not readable)
- **The "automatic perching mechanism".** The classic idea: the flexor tendons run behind the ankle, so a bird that crouches tensions them and closes its toes passively, holding it on the branch while it sleeps.
- **Galton & Shepherd 2012 questioned it** [28]. **[S]** (full abstract) In European starlings:
  - Sleeping starlings barely bent the knee and ankle. The distal two-thirds of the toes were *not* flexed on a 6 mm perch.
  - The foot formed an inverted-U "saddle", and the sleeping bird **balanced** over the central foot pad. In the daytime the weight shifted back and the toes gripped actively.
  - Bending the legs of anaesthetised birds did *not* close the toes, and anaesthetised birds could not stay perched.
  - Birds whose flexor tendons were cut, or whose lock was removed surgically, still slept perched.
  - The authors conclude that starlings have no automatic perching mechanism. The tendon lock helps only when the flexor muscles actively contract.
- **The parrotlet data agree.** Toe wrap and claw use change with perch diameter, so the grip is active and adjusted, not a fixed clamp (`landing_and_takeoff.md` §3) [29]. **[S]**

## 7. Head stabilisation and head-bobbing

- **The head holds still while the body moves.**
  - In flight, a whooper swan's neck acts as a near-critically damped spring (damping ratio about 0.86). The head moves vertically only about a quarter as much as the body, roughly 180° out of phase [30].
  - Pigeons on a moving platform keep the head almost perfectly still against rotations, but mostly follow translations. Vision improves the stabilisation mainly for translations [31].
  - **[S]**
- **Head-bobbing while walking.** The head alternates a **hold phase**, locked in space while the body walks forward under it, with a fast **thrust phase** forward [32][33]. **[S]**
  - It is visual, not for balance: on a treadmill, where the surroundings don't move, pigeons stop bobbing [32].
  - The hold phase drifts very little: about 3 mm/s, against 500–800 mm/s in the thrust phase (as quoted by secondary sources for [33]).
  - It shortens with speed and can vanish [34].
- **Who bobs** (from Necker's review [34], read via the author's summary page) **[S]/[W]:**
  - Bobbers: crows, along with pigeons, blackbirds and chaffinches. Magpies both hop and bob.
  - Small birds often hop rather than walk.
  - Non-bobbers: ducks, geese and swans, gulls, raptors, owls, parrots.
  - I found no source on whether hopping sparrows bob.
- **Landing.** Pigeons also bob during landing flights, at about the wingbeat frequency, through neck flexion and extension. Their head angle tracks the approach path [35]. **[S]**

---

## 8. How the rig maps to this

`BodyShape` holds the landmarks and the lofted trunk shell. `BirdRig` solves the neck, legs, head and tail from them each tick. Rig space: −Z is the nose, +X the right wing, +Y up, lengths as fractions of body length L.

### 8.1 Bones

| Anatomy | Rig bone(s) | How it moves | Section |
|---|---|---|---|
| Notarium, synsacrum, ribs, sternum, furcula | `body`: one rigid trunk bone | Pitches as a whole; never bends | §1 |
| Cervical vertebrae (about 14) | `neck.0`, `neck.1`, `neck.2`: three bones from `neck_base` (0, 0.03 L, −0.25 L) to the head | S-solve: the lower bone bends forward and the middle one back up, so the head stays level | §2 |
| Atlas and skull | `head` | Looks at a target; held still in world space | §7 |
| Free caudals + pygostyle + rectricial bulbs | `tail`, from `tail_base` (0, 0.02 L, 0.24 L) | 12 rectrices fan, pitch and twist as a group | §3 |
| Femur | `femur.L/R`, length 0.09 L (`BodyShape.FEMUR`), from `hip` (±0.05 L, −0.02 L, 0.03 L) | Held near level in the world, angled a little toward the foot; the knee stays inside the shell (tested) | §4 |
| Tibiotarsus, tarsometatarsus | `tibia.L/R`, `tarsus.L/R` | Two-bone IK knee → ankle → foot, poled so the ankle bends aft (the "backward knee") | §4 |
| Toes | four capsules per foot, not bones | 3 + 1, or the owl's outer toe swinging back; curl up to 70° with `toe_grip` | §5–6 |

### 8.2 The trunk shell

The trunk is lofted once through elliptical rings, each placed from a landmark (`_build_rings()`): throat, front of breast, **shoulders** (through the shoulder joints), **keel** (the deepest ring, at z = −0.04 L), **hips** (plus thigh padding), vent, and **tail base** (the pygostyle). Because the trunk is rigid (§1), the shell never needs re-lofting. The keel ring stands in for the sternum and the pectoralis and supracoracoideus on it (`wing_anatomy.md` §1).

### 8.3 Behaviour

- **Neck.** `neck_ext` runs from 0 (retracted, head on the shoulders) to 1 (reaching).
  - Perched it goes to 0.05.
  - In flight it takes the species' `neck_flight` value.
  - It reaches out (at least 0.85) for 0.3 s after take-off, and draws back toward 0.25 through a landing.
  - The neck's feather tube runs straight from inside the trunk to the head, because the feathers smooth over the S.
- **Head stabilisation** (§7). The head's world position is carried with the bird but lags the trunk's jolts (the touchdown dip, the pitch from flare to perch). It catches up at a rate of 15/s, with the lag limited to 0.1 L. The head's up vector stays close to the world's up.
- **Head range.** ±110° yaw (owl ±135°) and ±60° pitch. The owl's ±135° is the popular 270° split evenly; the measured figure is at least 180° in live barn owls (§2). Treat it as an estimate.
- **Grip** (§6). Toes curl when the bird sits with a grip point, as an active pose. Nothing models a tendon lock, which matches Galton & Shepherd's finding that the grip is muscular.
- **Not built.** The crow's walking head-bob waits on ground walking. No vertebra-level neck, free caudal vertebrae or separate toe bones.

### 8.4 Per-species proportions in `BodyShape.DATA` (estimates)

All values are fractions of L. **None of these per-species values is sourced. They are starting values tuned by eye [E].** What is sourced is the direction of some contrasts: the owl's large head and long but hidden neck (§2), the owl's reversible toe (§5), and the crow walking where the sparrow hops (§7).

| Species | Neck rest / reach | Breast depth | Head radius | Tibiotarsus / tarsus | Neck in flight (0..1) | Head yaw | Reversible toe | Fluff perched |
|---|---|---|---|---|---|---|---|---|
| Crow | 0.14 / 0.26 | 0.32 | 0.105 | 0.18 / 0.20 | 0.75 | 110° | no | 1.0 |
| Owl | 0.10 / 0.18 | 0.34 | 0.15 | 0.16 / 0.14 | 0.3 | 135° | yes | 1.1 |
| Hawk | 0.12 / 0.22 | 0.30 | 0.105 | 0.17 / 0.17 | 0.75 | 110° | no | 1.0 |
| Falcon | 0.10 / 0.18 | 0.32 | 0.10 | 0.16 / 0.15 | 0.8 | 110° | no | 1.0 |
| Sparrow | 0.09 / 0.15 | 0.33 | 0.11 | 0.16 / 0.14 | 0.5 | 110° | no | 1.05 |

The femur (0.09 L for every species) and the landmark positions in `for_profile()` are estimates too.

**This table is the code, not the plan.** `body_rig_plan.html` §5 has older starting values. For example, its crow neck is 0.12 / 0.22, its owl neck 0.05 / 0.15, and its falcon legs 0.15 / 0.12. The code's values are the current ones.

---

## Sources

1. Storer RW 1982, "Fused thoracic vertebrae in birds: their occurrence and possible significance", *J Yamashina Inst Ornithol* 14:86–95, doi:10.3312/jyio1952.14.86. https://www.jstage.jst.go.jp/article/jyio1952/14/2-3/14_2-3_86/_article/-char/en (abstract)
2. Wikipedia, "Notarium" (lists the families, citing Storer). https://en.wikipedia.org/wiki/Notarium
3. Wikipedia, "Bird anatomy". https://en.wikipedia.org/wiki/Bird_anatomy
4. Biewener AA 2011, "Muscle function in avian flight: achieving power and control", *Phil Trans R Soc B* 366:1496–1506, doi:10.1098/rstb.2010.0353. https://pmc.ncbi.nlm.nih.gov/articles/PMC3130450/
5. Tickle PG, Ennos AR, Lennox LE, Perry SF, Codd JR 2007, "Functional significance of the uncinate processes in birds", *J Exp Biol* 210:3955–3961, doi:10.1242/jeb.008953. (abstract)
6. Codd JR, Boggs DF, Perry SF, Carrier DR 2005, "Activity of three muscles associated with the uncinate processes of the giant Canada goose *Branta canadensis maximus*", *J Exp Biol* 208:849–857, doi:10.1242/jeb.01489. (abstract)
7. Jenkins FA Jr, Dial KP, Goslow GE Jr 1988, "A cineradiographic analysis of bird flight: the wishbone in starlings is a spring", *Science* 241:1495–1498, doi:10.1126/science.241.4872.1495. https://pubmed.ncbi.nlm.nih.gov/17790043/
8. Böhmer C, Plateau O, Cornette R, Abourachid A 2019, "Correlated evolution of neck length and leg length in birds", *R Soc Open Sci* 6:181588, doi:10.1098/rsos.181588. https://pmc.ncbi.nlm.nih.gov/articles/PMC6549945/
9. Terray L et al. 2020, "Modularity of the neck in birds (Aves)", *Evolutionary Biology* 47:97–110, doi:10.1007/s11692-020-09495-w.
10. Marek RD et al. 2021, "Evolutionary versatility of the avian neck", *Proc R Soc B* 288:20203150, doi:10.1098/rspb.2020.3150.
11. Krings M, Nyakatura JA, Fischer MS, Wagner H 2014, "The cervical spine of the American barn owl (*Tyto furcata pratincola*): I. Anatomy of the vertebrae and regionalization in their S-shaped arrangement", *PLoS ONE* 9:e91653, doi:10.1371/journal.pone.0091653.
12. de Kok-Mercado F, Habib M, Phelps T, Gregg L, Gailloud P 2013, "Adaptations of the owl's cervical & cephalic arteries in relation to extreme neck rotation", visualisation-challenge entry, *Science* 339:514–515, doi:10.1126/science.339.6119.514. Figures checked only via press coverage (ScienceDaily, 31 January 2013). The challenge entry is not a research article.
13. Krings M, Nyakatura JA, Boumans MLLM, Fischer MS, Wagner H 2017, "Barn owls maximize head rotations by a combination of yawing and rolling in functionally diverse regions of the neck", *J Anat* 231:12–22, doi:10.1111/joa.12616. https://pmc.ncbi.nlm.nih.gov/articles/PMC5472525/
14. Wikipedia, "Heron" (neck retracted in flight). https://en.wikipedia.org/wiki/Heron
15. Felice RN, O'Connor PM 2014, "Ecology and caudal skeletal morphology in birds: the convergent evolution of pygostyle shape in underwater foraging taxa", *PLoS ONE* 9:e89737, doi:10.1371/journal.pone.0089737. https://pmc.ncbi.nlm.nih.gov/articles/PMC3935938/
16. Wikipedia, "Pygostyle" (rectricial bulbs). https://en.wikipedia.org/wiki/Pygostyle
17. Gatesy SM, Dial KP 1996, "From frond to fan: *Archaeopteryx* and the evolution of short-tailed birds", *Evolution* 50:2037–2048.
18. Wikipedia, "Bird feet and legs". https://en.wikipedia.org/wiki/Bird_feet_and_legs
19. Gatesy SM 1990, "Caudofemoral musculature and the evolution of theropod locomotion", *Paleobiology* 16:170–186, doi:10.1017/S0094837300009866. (abstract)
20. North Dakota Game & Fish, "A look at bird legs" (cited in `body_poses_and_folded_wings.md` [36]). https://gf.nd.gov/wildlife-notes/look-bird-legs
21. Allen V, Bates KT, Li Z, Hutchinson JR 2013, "Linking the evolution of body shape and locomotor biomechanics in bird-line archosaurs", *Nature* 497:104–107, doi:10.1038/nature12059. (abstract and press only)
22. Gatesy SM, Biewener AA 1991, "Bipedal locomotion: effects of speed, size and limb posture in birds and humans", *J Zool* 224:127–147, doi:10.1111/j.1469-7998.1991.tb04794.x. (abstract)
23. Radiographic evaluation of perching joint angles in cockatiels, Amazon parrots and barred owls, *J Avian Med Surg* 23 (2009) (cited in `body_poses_and_folded_wings.md` [41]). https://bioone.org/journals/journal-of-avian-medicine-and-surgery/volume-23/issue-2/2008-028.1/Radiographic-Evaluation-of-Perching-joint-Angles-in-Cockatiels-Nymphicus-hollandicus/10.1647/2008-028.1.full
24. Botelho JF, Smith-Paredes D, Nuñez-Leon D, Soto-Acuña S, Vargas AO 2014, "The developmental origin of zygodactyl feet and its possible loss in the evolution of Passeriformes", *Proc R Soc B* 281:20140765, doi:10.1098/rspb.2014.0765. https://pmc.ncbi.nlm.nih.gov/articles/PMC4083792/
25. Sustaita D et al. 2019, "Behavioral correlates of semi-zygodactyly in Ospreys (*Pandion haliaetus*) based on analysis of internet images", *PeerJ* 7:e6243, doi:10.7717/peerj.6243. https://peerj.com/articles/6243
26. Quinn TH, Baumel JJ 1990, "The digital tendon locking mechanism of the avian foot (Aves)", *Zoomorphology* 109:281–293, doi:10.1007/BF00312195.
27. Einoder L, Richardson A 2007, on the digital tendon locking mechanism of owls, *Emu* 107:223–230, doi:10.1071/MU06019. (full title not recorded)
28. Galton PM, Shepherd JD 2012, "Experimental analysis of perching in the European starling (*Sturnus vulgaris*: Passeriformes; Passeres), and the automatic perching mechanism of birds", *J Exp Zool A* 317:205–215, doi:10.1002/jez.1714. https://pubmed.ncbi.nlm.nih.gov/22539208/
29. Roderick WRT, Chin DD, Cutkosky MR, Lentink D 2019, "Birds land reliably on complex surfaces by adapting their foot-surface interactions upon contact", *eLife* 8:e46415, doi:10.7554/eLife.46415. https://elifesciences.org/articles/46415
30. Pete AE, Kress D, Dimitrov MA, Lentink D 2015, "The role of passive avian head stabilization in flapping flight", *J R Soc Interface* 12:20150508, doi:10.1098/rsif.2015.0508. https://pmc.ncbi.nlm.nih.gov/articles/PMC4614461/
31. Theunissen LM, Troje NF 2017, "Head stabilization in the pigeon: role of vision to correct for translational and rotational disturbances", *Front Neurosci* 11:551, doi:10.3389/fnins.2017.00551. https://www.frontiersin.org/articles/10.3389/fnins.2017.00551/full
32. Frost BJ 1978, "The optokinetic basis of head-bobbing in the pigeon", *J Exp Biol* 74:187–195, doi:10.1242/jeb.74.1.187. (abstract)
33. Troje NF, Frost BJ 2000, "Head-bobbing in pigeons: how stable is the hold phase?", *J Exp Biol* 203:935–940. (abstract)
34. Necker R 2007, "Head-bobbing of walking birds", *J Comp Physiol A* 193:1177–1183, doi:10.1007/s00359-007-0281-3. Read via the author's summary page: https://reinhold-necker.de/seite10.html
35. Green PR, Davies MNO, Thorpe PH 1994, "Head-bobbing and head orientation during landing flights of pigeons", *J Comp Physiol A* 174:249–256, doi:10.1007/BF00193791.

**Not sourced or not verified:** cervical counts for falcons, hawks of the genus *Buteo*, crows and house sparrows; whether hawks and owls have a notarium (they are absent from the list, not confirmed absent); raptors resting the head on the shoulders; whether sparrows bob; every per-species proportion in `BodyShape.DATA`.
