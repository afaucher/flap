# Body poses and folded wings

This note covers how real birds hold a folded wing, how they hold the body, legs and tail in each state, and what that means for `scripts/bird/bird_rig.gd`. It is written to fix two visible problems in the greybox rig:

- The folded wings stand up and out in a "V" above the back.
- The body is a horizontal capsule in every state, perched included.

Each claim carries a confidence tag:

- **[S]** is sourced from a paper, a museum or university page, or Cornell.
- **[F]** comes from field-guide summaries, birding forums or blogs. It is consistent across several of them but secondhand.
- **[E]** is our own estimate, from general field knowledge and photographs, for the rig to tune.

Source numbers such as [3] refer to the list at the end.

Rig coordinates used below match `bird_rig.gd`: +Y up, −Z forward (the head sits at z = −0.3 L), and +Z aft (the tail base sits at z = +0.24 L). L is `body_length`. The body capsule has a radius of 0.15 L and is 0.62 L long, so the back line is at y ≈ +0.15 L. The shoulder is at (±half-width, +0.06 L, −0.12 L).

---

## 1. The folded wing

### 1.1 Skeleton: the Z-fold

- **The bones fold into a flat Z.** The humerus runs aft along the body from the shoulder. The forearm (radius and ulna) folds back forward along the humerus. The hand (carpometacarpus) folds aft again, against the forearm. The 1911 Britannica describes the folded radius lying parallel to the humerus, with the hand folded back against the ulnar side of the forearm [2]. **[S]**
- **The fold is coupled.** Elbow and wrist flex together through the radius and ulna sliding past each other. The classic model is a "drawing-parallels" four-bar linkage, in use since 1839. Pigeon motion data fit a six-bar model better: parallel radius and ulna, plus a sliding ulnare [4][5]. The wedge-shaped radiale and the convex trochlea of the carpometacarpus let the wrist bend far enough to fold [6]. This supports our single `fold` value driving both joints. **[S]**
- **The patagium folds with the wing.** The patagialis muscle in the skin fold between the upper arm and forearm helps fold the wing at rest [3]. Shrinking the fairing as the wing folds is correct. **[S]**
- **Where each joint ends up:**
  - The **wrist** (the "bend of the wing", the carpal joint; birders often call this area the "shoulder") forms the front corner of the folded wing, at the side of the breast. The carpal joint is where the inner and outer wing bones meet, forming the bend in the leading edge [8]. **[S]**
  - The **elbow** is hidden aft, under the scapulars and the flank feathers. **[F]**
  - The **hand** runs aft from the wrist along the side of the body. **[F]**

### 1.2 Feathers: stacking order and what covers what

- **Stacking order.** On a folded passerine wing, the innermost tertial lies on top and the outermost primary at the bottom. Only the outer edges of the remiges show [7]. From the top down, the stack is: tertials, then secondaries, then primaries. The primaries are the feathers that stick out alongside the tail [7]. **[F]**
- **The wing sits in a pocket.** The scapulars cover the boundary between the body and the wing [7]. The side and flank feathers cover the lower edge and the lesser coverts. On a folded passerine wing, the lesser coverts are "usually concealed by scapular and side feathers" [9]. The flank is the lateral body feathering up to the base of the wing [10]. In a side view, then, the folded wing reads as a panel let into the body's outline, not as a plate on top of it. **[F]**
- **What shows from the side.** In a side view you see the greater-covert row, the tertials, a strip of secondaries and the primary tips. From above you see the scapulars and the tertials, with the two wings' primary tips converging over the rump and tail. **[F]/[E]**

### 1.3 Three wing-length measurements

Field guides use three different measurements. Keep them apart:

| Term | Meaning | Source |
|---|---|---|
| **Primary projection** | How far the primary tips extend beyond the longest tertial, often quoted as a fraction of tertial length. On a Chiffchaff it is about half the tertial length. | Sibley's *Birding Basics*; BTO [11][12] **[F]** |
| **Wing projection** (Collins), also called **wing point** (*The Shorebird Guide*) | How far the wingtips reach past the tail tip on a perched bird. Negative when the tips fall short. | [12] **[F]** |
| **Visible primary tips** | The number of primary tips showing past the tertials. | [12] **[F]** |

For the rig, the useful measure is **wingtip position along the tail**: 0 = tail base (the uppertail coverts), 1 = tail tip, more than 1 = beyond the tail tip.

### 1.4 Wingtip position by species

| Species or group | Folded-wing look | Wingtip on tail (0..1+) | Tag |
|---|---|---|---|
| Peregrine Falcon | Long pointed wings. The tips reach the tail tip or pass it ("as long or even longer than the tail") [13][14]. | 0.95–1.05 | [F] |
| Gyrfalcon, American Kestrel, Aplomado Falcon | The tail extends beyond the wingtips. Cornell notes this for Gyrfalcon and Aplomado [15]. | 0.7–0.85 | [S]/[E] |
| Cooper's Hawk (accipiter) | Short rounded wings on a long tail. The wings reach about ⅓ of the way down the tail [13][14]. | 0.3–0.4 | [F] |
| Red-tailed Hawk (buteo) | Broad wings on a short, wide tail [16]. The tips sit near the tail tip. | 0.8–0.95 | [E] |
| American Crow | Square tail. The tips fall a little short of the tail tip. | 0.75–0.85 | [E] |
| Common Raven | Longer, wedge-shaped tail [17][18]. The tips sit near the tail tip but short of the wedge's point. | 0.8–0.9 | [E] |
| Great Horned Owl and other large *Strix*/*Bubo* owls | The wing is rounded and mostly sunk into the fluffy flank and breast feathering. The tips fall short of the tail tip and barely show. | 0.6–0.8 | [E] |
| Barn Owl | Short, square, stubby tail [19]. The long wings reach past it. | 1.05–1.2 | [F]/[E] |
| House Sparrow and sparrows generally | Short primary projection (about 30–60 % of tertial length). The tips reach only the base third of the tail. | 0.25–0.4 | [E] |

### 1.5 How high the folded wing sits

The rig currently has the wings in a "V" above the back. Real birds never hold a folded wing like that.

- **Top edge.** The top of the folded wing is flush with the back line or just below it. The scapulars lap over the joint between the two. **[F]**
- **Primary tips.** The tips converge over the rump and tail at about the height of the tail's upper surface. Swallows, swifts and some falcons have tips that cross. Most other birds have tips that touch or nearly touch. **[E]**
- **Side and front views.** In both views the folded wing stays inside the body's silhouette, except for the primary tips, which project aft over the tail. **[F]/[E]**
- **The rig target.** Keep the outer wing surface within about 0.01–0.02 L of the body capsule. The upper edge (the tertials and secondaries) should be at about y ≈ +0.10…+0.15 L. **[E]**
- **The cause of the "V".** The feathers rise because their roots follow bones whose IK places the wrist above or outside the flank, while their directions blend to "straight aft". Fix the anchor (section 4) and give the folded feather direction a slight downward and inward slope, about 3–8° down and 2–5° in, so the tips meet over the tail. **[E]**

### 1.6 Other wing postures

- **Drooped wings.** Hot, sunning or relaxed birds let the wings hang loose. The tips drop below the tail and the wrists hang off the flank by about 0.02–0.05 L. **[E]**
- **Mantling.** Raptors mantle over prey: wings half-spread and drooped forward. **[E]**
- **Owl "erect" or concealing pose.** Owls stand upright, compress the plumage, raise the ear tufts and close the eyes [20][21]. Bondrup-Nielsen lists the wing nearer the observer among the pose's four features [20], but the source text was truncated, so the exact wing placement is unconfirmed. **[S]/[F]**

---

## 2. Body posture by state

Body pitch below is the angle of the body's long axis above horizontal. The rig's capsule axis is that line.

- **Perched, by group.** Flycatchers, hawks and owls sit upright with the tail pointing straight down. Vireos, shrikes, crows and warblers hold the body more horizontally, with the tail angled out from the body. The classic distance cue is an upright Red-tailed Hawk next to a horizontal American Crow [22]. Cornell describes the Peregrine as having an "upright posture with a long tail" [15]. It describes the Cooper's Hawk perched as "slim and straight-backed" and the Red-shouldered Hawk as "hunchbacked" [16]. **[F]/[S]**
- **Typical pitch angles** (estimates for the rig) **[E]:**
  - Owls: 65–80°
  - Falcons: 60–75°
  - Hawks: 55–70°
  - Crows: 25–40°
  - Sparrows on a twig: 20–35°
  - Sparrows hopping on the ground: 5–20°
  - Crows walking on the ground: 5–15°
- **Resting versus alert** **[E]:**
  - A *resting* bird fluffs out its plumage, so the body grows by about 10–25 % in radius. The head sinks into the shoulders and the neck vanishes. The body angle drops 5–10° (it leans back onto the tail line).
  - An *alert* bird sleeks its plumage, stretches the neck up and lifts the head. Songbirds often flick the wings or tail, and kestrels pump the tail [23].
- **Sleeping.** The bird turns its head and tucks the bill into the scapulars. The body fluffs and covers the legs and feet [24][25]. **[S]**
- **Preening.** The neck curls to reach the flanks, back, uropygial gland and the underside of a half-raised wing. One wing lifts or droops at a time. **[E]**
- **Flight.** The body is near horizontal in cruise. For the rig, use 0–10° nose-up in cruise, rising with slowness. The head is stretched forward and stabilised. In whooper swans the neck acts as a near-critically damped spring-damper: the head's vertical motion is about 4× smaller than the body's, and roughly 180° out of phase [26]. Herons, by contrast, fly with the neck retracted into an S, while ducks and storks fly with it extended. **[S]** for the swans; **[E]** for herons, ducks and storks.
- **Head angle.** A pigeon study (as summarised by the search, not checked against the paper) reports that the eye-to-bill line stays near 35° below horizontal in flight, walking, perching and standing [27]. This supports the rig's "head stays level with the world" rule. **[F]**
- **Landing flare.** Body angle, tail angle and the wing planes all rotate from near horizontal during take-off to near vertical during landing, raising drag. The stroke plane tilts up from about −1° to 17° on landing. All these rotations correlate strongly with body angle (pigeon) [28]. Lovebirds landing on a swinging perch held a uniform body pitch of 81.9° [29]. The wings brake first. The legs then absorb the remaining momentum (parrotlets) [30]. The legs swing forward, and the tail spreads and pitches down; a spread tail passively changes the bird's pitch (pigeon tail robot) [31]. **[S]**, except that legs-forward is **[E]**.
- **Take-off.**
  1. A slow preparatory crouch. The trunk pitches *down*, the head moving first. The ankle flexes most, then the hip, with the knee flexing least. The crouch is deeper in the heavier dove than in the zebra finch [32].
  2. A fast push-off. The hip and ankle extend to drive the trunk up and forward [32].
  3. The legs supply 80–90 % of take-off velocity in starlings and quail [33]. Hummingbirds supply only 59 % [34].
  4. The first downstrokes have a steeply forward-down stroke plane, from −60° to −47° (pigeon) [28].

  **[S]**

---

## 3. Legs and feet when perched

- **Joints.** The visible "backward knee" is the ankle (intertarsal joint). The real knee points forward and is hidden in the body feathers. The femur is short and buried in the body [35][36]. So when perched, normally only the tarsometatarsus and the toes show below the belly feathers. **[S]**
- **Zig-zag, with the weight over the feet.** From the foot up, the leg zig-zags:
  - The tarsus leans up and back to the ankle, 15–40° from vertical. It leans more when crouched or resting.
  - The tibiotarsus runs up and forward to the knee.
  - The femur runs back up to the hip.

  The centre of mass sits plumb over the grip point. Upright perchers are near this balance by default. Horizontal perchers keep the hips over the perch and counterbalance the head and breast with the tail. **[E]**
- **Grip.** Bending the ankle and knee tensions the flexor tendons, which pulls the toes shut. Tubercles on the tendons mesh with ridges in the tendon sheath, a digital tendon-locking mechanism [37][38]. Sleeping starlings, however, seem to balance mainly on the foot pad, with the toes largely unbent [25]. **[S]**
- **Toe arrangements:**
  - *Anisodactyl* (songbirds, crows, hawks, falcons): three toes forward and one back. The hallux opposes the middle toe across the branch.
  - *Semi-zygodactyl* (owls, Osprey): the outer toe can rotate back, giving two forward and two back [39]. Ospreys were 5.7× more likely to use the zygodactyl grip when grasping in flight than when perched [40].

  **[S]**
- **How the toes wrap** (parrotlets) **[S]** [30]:
  - Toes spread about 100 ms before touchdown and pre-shape about 30 ms before contact.
  - They wrap in about 19 ms after contact, and the claws curl over about 185 ms.
  - Wrap depends on perch size: more than 110 % of the circumference on a 6 mm perch, about 50 % on 19 mm and under 25 % on 38 mm.
  - Birds took about 2 adjustment steps after anchoring.
- **Joint angles differ by species.** Perching hip, stifle (knee) and intertarsal angles differ significantly among cockatiels, Amazon parrots and Barred Owls (radiographic study) [41]. Per-species leg poses are justified. **[S]**
- **Belly feathers.** Fluffed belly feathers can cover both feet, or the bird tucks one leg up into them [24][25]. In the greybox, hide or shorten the tibia capsule when perched. Show only the tarsus, starting just below the belly line, which reads much more bird-like. **[S]** for the feathers, **[E]** for the rig.
- **Tail position.** The tail goes down and behind the perch:
  - Upright perchers hang the tail roughly in line with the body, pointing down: the tail is 0–10° down relative to the body axis.
  - Horizontal perchers angle the tail down from the body: 10–30° relative to the body axis.
  - Wrens, and sparrows when alert, may cock the tail up.

  **[F]/[E]**

---

## 4. Rig guidance

### 4.1 Folded-wing anchor (`fold_anchor`)

The current anchor is `sh + normalize(0.35, −0.3, 0.6) · reach`, with `reach ≈ max(1.4·|hum−fore|, 0.08 L)`.

- **Where the wrist should go.** Replace the anchor with a target on the capsule surface, beside the *breast*: **[E]**
  - x = ±(0.15–0.16) L, that is, the body radius plus feather thickness
  - y = shoulder − (0.03–0.06) L, about +0.01…+0.03 L
  - z = shoulder + (0.02–0.06) L, about −0.10…−0.06 L
- **Elbow pole.** Pole the elbow aft and slightly up, toward (±0.13 L, +0.08 L, +0.05 L), so the elbow tucks under the scapulars rather than sticking out. **[E]**
- **Folded feather direction.** Point it aft, with 3–8° down along the body's top contour and 2–5° inward. Choose the primaries' length and the sweep so the tips land at the species' "wingtip on tail" fraction from the table below. **[E]**
- **Body-relative anchor.** Express all of this relative to the body bone, so pitching the body (perched upright) carries the folded wing with it. **[E]**

### 4.2 Posture state machine (body pitch is a new rig value; rotate about the grip point)

| State | Body pitch | Tail rel. body | Head | Legs | Transition time |
|---|---|---|---|---|---|
| Cruise flight | 0–10° (add slowness × 15°) | 0–5° down, closed | forward, stabilised | tucked aft under the tail coverts | — |
| Landing flare | ramps to 60–85° over the last 3–4 beats | 20–35° down, fan fully spread | locked on the grip point | swing forward. Toes open about 100 ms and pre-shape about 30 ms before contact | 0.3–0.6 s |
| Touchdown | overshoot 5–10° forward, then settle | settles | stays level | ankle and knee flex (absorb). Toes wrap in about 20 ms | 0.15–0.3 s |
| Perched alert | species value (table below) | species value | raised, looking around | species zig-zag. CoM over grip | — |
| Perched resting | species value − 5–10° | +5° down | sunk (neck shortened about 50 %) | deeper flex. Belly covers the tarsi | 1–2 s |
| Sleeping | resting pose | resting pose | turned back into the scapulars | one leg tucked, optionally | 1–2 s |
| Pre-take-off crouch | species value − 10–25° (pitch down, head first) | lifts slightly | forward, toward the launch direction | ankle flexes most, then hip; knee least. Drop about 15–25 % of leg length | 0.1–0.3 s |
| Take-off push | rotates to about 20–40° | spreads | forward | extend hip and ankle. Legs supply 80–90 % of launch speed | 0.05–0.15 s |
| First downstrokes | 10–30° | spread, down | forward | trail aft | 2–4 beats |

### 4.3 Per-species pose parameters (fractions are of L or of tail length)

| Parameter | Sparrow | Crow | Hawk (buteo) | Falcon | Owl |
|---|---|---|---|---|---|
| Body pitch, perched alert | 25° [E] | 35° [E] | 60° [E/F] | 65° [E/F] | 72° [E/F] |
| Body pitch, on the ground | 10° [E] | 10° [E] | 30° [E] | 35° [E] | 45° [E] |
| Tail rel. body, perched (+ = down) | 15° [E] | 20° [E] | 5° [F/E] | 5° [F/E] | 5° [F/E] |
| Wingtip on tail (0 base … 1 tip) | 0.3 [E] | 0.8 [E] | 0.9 [E] (Cooper's 0.35 [F]) | 1.0 [F] (kestrel 0.75 [E]) | 0.7 [E] (Barn Owl 1.1 [F/E]) |
| Top of the folded wing vs back line | −0.01 L | 0 | −0.01 L | 0 | −0.03 L (sunk in the flank) |
| Wrist anchor rel. shoulder (dx, dy, dz) | (+0.02, −0.04, +0.04) L | (+0.02, −0.04, +0.05) L | (+0.02, −0.05, +0.04) L | (+0.02, −0.04, +0.05) L | (+0.03, −0.06, +0.03) L |
| Wing drop to the side (resting) | 0.01 L | 0.02 L | 0.03 L (hunched) | 0.01 L | 0.0 (hidden) |
| Fluff when resting (radius ×) | 1.25 | 1.1 | 1.15 | 1.1 | 1.3 |
| Tarsus from vertical, perched | 35° | 25° | 15° | 15° | 10° (feathered legs) |
| Toes | 3 + 1 | 3 + 1 | 3 + 1 | 3 + 1 | 2 + 2 (outer toe reversed) [S] |
| Crouch depth before take-off | 25 % leg | 20 % leg | 15 % leg (often drops off the perch) | 15 % leg (drops) | 15 % leg (drops) |

Notes:

- For the wrist anchor, dx is measured outward from the shoulder's x (which already sits at the body's half-width). Clamp the anchor so it is never inside the capsule.
- The upright species (hawk, falcon, owl) often launch by dropping forward off the perch rather than leaping. That is our estimate, not sourced.
- The contrasts between groups are sourced. The individual angles are estimates; tune them by eye against photographs. The sourced relations are:
  - upright raptors and owls versus horizontal crows and songbirds [22]
  - falcon wingtips at the tail tip versus accipiter wingtips short of it [13][14]
  - Barn Owl's short tail [19]
  - the landing pitch (82° in lovebirds) [29]
  - the take-off crouch sequence [32] and the leg share [33]
  - the toe timing and wrap [30]
  - semi-zygodactyl owls [39][40]

---

## Sources

1. Bird Wing Anatomy, Birdfact. https://birdfact.com/anatomy-and-physiology/wings-and-flight/bird-wing-anatomy
2. Encyclopaedia Britannica 1911, Vol. 3 ("Bird"), Wikisource mirror. https://kwx.liehendr.com/content/wikisource_en_all_maxi_2022-09/A/Page%3AEB1911_-_Volume_03.djvu/988
3. Vertebrate Zoology Lab 8 handout (patagialis). https://www-archiv.fdm.uni-hamburg.de/b-online/library/crone/3051/labwk08.html
4. Stowers et al., pigeon wing linkage (four-bar vs six-bar), via scite. https://scite.ai/authors/amanda-k-stowers-6M1jAr
5. SICB abstracts on the automatic wing linkage. https://sicb.org/?p=12414 and https://sicb.org/?p=21119
6. PMC article on pigeon wrist morphology, citing Vazquez 1992. https://pmc.ncbi.nlm.nih.gov/articles/PMC2880093
7. Flight feather, Wikipedia. https://en.wikipedia.org/wiki/Flight_feather ; Sibley topography figures (mirror). https://swartzentrover.com/cotor/Photos/Hiking/Birds/BirdPages/Anatomy/Anatomy.htm
8. Birds of East Asia: Glossary (carpal joint). https://sites.google.com/site/birdsofeastasia/Home/Birds-of-East-Asia-Glossary
9. Parts of a Bird: Flight Feathers, Avian Report. https://avianreport.com/?p=2662
10. Glossary of bird parts, BirdSpot. https://www.birdspot.co.uk/identifying-birds/glossary-of-bird-parts
11. BTO Field craft: the importance of structure. https://ociweb.bto.org/sites/default/files/field_craft_the_importance_of_structure_in_bird_identification.pdf
12. Birding-Aus thread on primary projection and wing projection (Collins, Sibley, *Shorebird Guide*). https://www.cse.unsw.edu.au/birding-aus/2011-06/msg00051.html and https://cgi.cse.unsw.edu.au/~cs6714/bio/archives/html/birding-aus/2011-06/msg00057.html
13. Ohio Peregrine Falcons blog (wingtip vs tail, Peregrine vs Cooper's). https://ohioperegrinefalcons.blogspot.com/2010/02/interesting-shadow.html
14. BirdForum ID thread (falcon vs accipiter wing reach). https://www.birdforum.net/threads/identification-help.405997/
15. Cornell All About Birds: Cooper's Hawk, Gyrfalcon and Aplomado Falcon species comparisons. https://www.allaboutbirds.org/guide/Coopers_Hawk/species-compare/ , https://www.allaboutbirds.org/guide/Gyrfalcon/species-compare/ and https://www.allaboutbirds.org/guide/Aplomado_Falcon/species-compare/
16. Cornell All About Birds: Red-tailed Hawk ID and Red-shouldered Hawk comparison. https://www.allaboutbirds.org/guide/Red-tailed_Hawk/id and https://www.allaboutbirds.org/guide/Red-shouldered_Hawk/species-compare/
17. eBird: Crows and ravens. https://ebird.org/news/crows_and_ravens
18. Corvid Research: distinguishing crows and ravens. https://corvidresearch.blog/2025-05-12/the-definitive-guide-for-distinguishing-american-crows-common-ravens/ ; Bedford Audubon. https://bedfordaudubon.org/american-crow-common-raven/
19. Feathered Photography, "A Tale of a Barn Owl Tail". https://featheredphotography.com/blog/2013/page/23/
20. Johnsgard, *North American Owls* (Bondrup-Nielsen on concealing poses). https://digitalcommons.unl.edu/johnsgard/27
21. The Owl Pages: owl behaviour. https://owlpages.com/owls/articles.php?i=1
22. "Posture", Info on Birds (upright vs horizontal perchers). https://info-on-birds.blogspot.com/2009_01_18_archive.html
23. BLM Snake River Birds of Prey: Meet the Raptors (kestrel tail-bobbing). https://www.blm.gov/sites/blm.gov/files/documents/files/Morley-Nelson-Snake-River-Birds-of-Prey_Meet-The-Raptors.pdf
24. Audubon: How do birds spend cold winter nights? https://www.audubon.org/magazine/how-do-birds-spend-cold-winter-nights
25. ScienceABC: why birds don't fall off branches (the starling study). https://www.scienceabc.com/nature/animals/why-dont-birds-fall-off-branches-when-they-sleep.html ; BirdNote. https://birdnote.org/node/16863
26. Pete, Kress, Dimitrov & Lentink 2015, "The role of passive avian head stabilization in flapping flight", *J R Soc Interface*. https://pmc.ncbi.nlm.nih.gov/articles/PMC4614461
27. Pigeon head-posture study, *J Comp Physiol A*. https://doi.org/10.1007/BF00193791 (as summarised by search; not verified against the paper)
28. Berg & Biewener 2010, "Wing and body kinematics of takeoff and landing flight in the pigeon", *J Exp Biol*. https://biewenerlab.oeb.harvard.edu/publications/wing-and-body-kinematics-takeoff-and-landing-flight-pigeon-columba-livia (doi 10.1242/jeb.038109)
29. Biewener lab, "Landing on a swinging perch: peach-faced lovebirds prefer extremes". https://biewenerlab.oeb.harvard.edu/publication/landing-swinging-perch-peach-faced-lovebirds-prefer-extremes
30. Roderick, Chin, Cutkosky & Lentink 2019, "Birds land reliably on complex surfaces…", *eLife*. https://elifesciences.org/articles/46415
31. Gayout, Onn & Lentink 2023, "Passive pitch induced by a spreading pigeon tail", APS DFD abstract. https://meetings-archive.aps.org/dfd/2023/r01/4/
32. Provini & Abourachid 2018, "Whole-body 3D kinematics of bird take-off", *Naturwissenschaften*. https://pubmed.ncbi.nlm.nih.gov/29330588/
33. Earls 2000, "Kinematics and mechanics of ground take-off in the starling and quail", *J Exp Biol*. https://www.sciencegate.app/document/10.1242/jeb.203.4.725
34. Tobalske et al. 2004, "Take-off mechanics in hummingbirds", *J Exp Biol*. https://cob.silverchair.com/jeb/article/207/8/1345/15063/Take-off-mechanics-in-hummingbirds-Trochilidae
35. Bird feet and legs, Wikipedia. https://en.wikipedia.org/wiki/Bird_feet_and_legs
36. North Dakota Game & Fish: A look at bird legs. https://gf.nd.gov/wildlife-notes/look-bird-legs
37. Raptor Resource Project: ratcheting raptor toes. https://www.raptorresource.org/2021/01/22/racheting-raptor-toes-an-upside-down-eagle-at-great-spirit-bluff/
38. Galton & Shepherd 2010, digital tendon-locking mechanism, *J Exp Zool* (record). https://bvbvf1.bib-bvb.de/vufind/PrimoRecord/cdi_proquest_miscellaneous_1010232799
39. Bird feet and legs (owls and Osprey with a reversible outer toe). https://en.wikipedia.org/wiki/Bird_feet_and_legs
40. Sustaita et al. 2019, "Behavioral correlates of semi-zygodactyly in Ospreys", *PeerJ*. https://peerj.com/articles/6243
41. Radiographic evaluation of perching joint angles in cockatiels, Amazon parrots and Barred Owls, *J Avian Med Surg* 2009. https://bioone.org/journals/journal-of-avian-medicine-and-surgery/volume-23/issue-2/2008-028.1/Radiographic-Evaluation-of-Perching-joint-Angles-in-Cockatiels-Nymphicus-hollandicus/10.1647/2008-028.1.full

Unreachable during research (HTTP 403 or DNS failure): the All About Birds ID pages, the BTO PDFs, the Biewener lab pages and the bioone full text. Their claims above come from search-result summaries.
