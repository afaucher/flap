# Landing and take-off

How birds land on a perch and how they leave it, with the numbers from the studies, and how Flap's landing and take-off compare. This note gathers and extends what was spread across `wing_shapes_and_articulation.md` §4 (the perching manoeuvre) and `body_poses_and_folded_wings.md` §2–3 (landing flare, take-off, toes). The code it backs is the LANDING and take-off logic in `scripts/bird/bird.gd`, the flare in `scripts/flight/flight_model.gd`, and the landing and leap poses in `scripts/bird/bird_rig.gd`. The design is in `docs/design/flight_model.md` §3.

Tags:
- **[S]** sourced from a paper or thesis.
- **[E]** our own estimate or a design choice.

Source numbers such as [3] refer to the list at the end.

---

## 1. Landing: the sequence

Across hawks, eagles, pigeons, lovebirds and parrotlets, landing follows the same order:
1. approach;
2. pitch up into a flare;
3. brake with the wings;
4. swing the feet forward;
5. take up what is left of the momentum with the legs.

### 1.1 Approach: dive under, swoop up (Harris's hawks)

The Oxford flight group (Graham Taylor's lab) flew four Harris's hawks between perches 5–12 m apart, 1,576 flights in all [1]:
- **The path.** The hawks jump into a powered dive, then swoop up to the perch unpowered. The low point is at about 61 % of the perch spacing, and the dive is shallow, about 3 % of the spacing.
- **Speeds.** About 3.8–4.0 m/s at take-off and 2.3–2.5 m/s at landing.
- **What they optimise.** The swoop's shape minimises the **distance flown at high lift** (lift coefficients above about 4, where the wing is effectively stalled). It does not minimise time or energy.
- **At contact** the body is near vertical, with the wings outstretched.
- **Learning.** The three naive juveniles learned the manoeuvre by flying it.
- **[S]**

A DPhil thesis from the same group [2] covers more than 1,000 hawk flights, plus steppe eagles and wild passerines:
- The hawks brake by **pitching up** at the end of the glide. That gives high drag, with **no matching lift peak**.
- They used the same pitch-up at every distance, and added flapping to brake on the shortest flights.
- Braking followed **tau theory**: the rate of change of the time-to-contact stayed constant. The passerines did not follow it.
- **[S]** (abstract)

The Oxford group's later work, which tests the hawk result on a morphing-wing drone [3], is listed in the sources. I found no hawk-perching paper by an author named Krishnan with Taylor.

### 1.2 Pitch-up and deep stall (steppe eagle)

- **The stall.** A steppe eagle perching outdoors goes from glide, to a pitch-up, to a deep stall in which the wings and tail sit near 90° angle of attack and act as a "cross-parachute" [4]. **[S]**
- **The feathers.** In the pitch-up, the underwing coverts deploy in a wave from the wrist to the shoulder, starting within a few tens of milliseconds of peak wing flexion. The alula peels up and then sweeps about 45° forward. The authors propose both act as automatic leading-edge high-lift devices [4]. **[S]**
- **The lift.** Lift was not measured in [4]. A related paper concludes that the key to perching is not high-lift aerodynamics but the wing and tail morphing into the deep stall [5]. **[S]** (abstract snippets only)
- **Unsteady forces.** In a pitching, decelerating airfoil, peak lift and drag were "more than 10 times the quasi-steady values", mostly from added mass and leading- and trailing-edge separation [6]. So the extra drag of a flare is physical. **[S]**

### 1.3 Pigeons

- **Everything rotates up** (Berg & Biewener 2010) [7]. Seven pigeons flew between two perches. **[S]** (full text)
  - The **body angle** at mid-downstroke rose from −13° on the first take-off wingbeat to 72° on the last landing wingbeat.
  - The **tail angle** rose from 4° to 78°.
  - The **wing planes** rotated by more than 90° between take-off and landing.
  - The **stroke plane** tilted up from about −1° to 17° on landing, so the wingbeats push forward and brake.
  - Speed fell from 4.2 to 1.0 m/s over the landing wingbeats.
  - The peak deceleration was 8.5 m/s² on the last landing wingbeat.
- **Landing forces** (Green & Cheng 1998) [8]. Ten landings on an unfamiliar perch. **[S]** (abstract)
  - The kinetic energy just before touchdown varied about 20-fold, mostly from horizontal speed.
  - The peak force on the perch was 2–8× body weight, directed 40–90° below horizontal.
  - Faster landings had straighter paths and larger, shallower peak forces.
- **The head during landing.** Pigeons bob the head during landing flights. The head's angle tracks the upward approach path [9]. **[S]**

### 1.4 Parrotlets and lovebirds: the feet and legs

- **Wings, then legs** (Roderick et al. 2019) [10]. Pacific parrotlets landing on perches of different sizes and surfaces. **[S]** (full text)
  - The wings brake only enough to keep the rate of change of time-to-contact near constant, about 0.8–0.9.
  - The **legs absorb the remaining momentum**, mostly while the feet are still slipping on the perch.
  - Leg and wing motion stays the same whatever the perch's diameter or texture. The *feet* adapt (§3).
- **Same strategy in short flights** (Chin & Lentink 2017) [11]. Parrotlets flying between perches brake with the wings only enough for a controlled collision, and the legs bring the bird to a stop. **[S]**
- **Lovebirds** (Bhagavatula & Biewener 2025) [12]. Peach-faced lovebirds landing on a swinging perch. **[S]**
  - They approached on a shallow path (about −13°).
  - They landed with the body pitched up to 81.9° on average.
  - About half the landings came near the swing's extremes, where the perch is nearly still.
  - The horizontal force was larger than the vertical in every condition. It reached 2.2 body weights when the perch swung toward the bird fast.
  - Flexing the legs reduced the landing torque.

## 2. Take-off: legs first

### 2.1 How much the legs give

The legs make most of the take-off speed. The wings take over in the first beats.

| Species | Legs' share | Peak leg force | Study | Tag |
|---|---|---|---|---|
| Starling | 80–90 % of take-off velocity | 4× body weight (countermovement jump) | Earls 2000 [13] | [S] (abstract) |
| Quail | 80–90 % of take-off velocity | 7.8× body weight (squat jump) | Earls 2000 [13] | [S] (abstract) |
| Zebra finch | 85 % of the acceleration on the perch; **94 %** of the velocity at lift-off | 4.9× body weight | Provini et al. 2012 [14] | [S] |
| Diamond dove | 77 % of the acceleration on the perch; **95 %** of the velocity at lift-off | 2.7× body weight | Provini et al. 2012 [14] | [S] |
| Pigeon, jump take-off | Leg thrust 1.3–2.3× body weight; wings overhead (the "clap") as the feet leave | 1.3–2.3× body weight | Heppner & Anderson 1985 [15] | [S] (snippet) |
| Pigeon, perch-to-perch flight | Legs about **one quarter** of the acceleration; the wings give most | — | Berg & Biewener 2010 [7] | [S] |
| Hummingbirds | 59 % of take-off velocity (46–47 % in escape and aggressive take-offs) | — | Tobalske et al. 2004 [16] | [S] |
| Parrotlet, 20–75 cm hops | Legs accelerate the bird to 80–100 % of its average flight speed; long jumps up to 20 cm need no wingbeat | — | Chin & Lentink 2017 [11] | [S] |

How to read the table:
- The leg share depends on the task. Jumps into the air give 80–95 %. In a pigeon's perch-to-perch flight, where the bird builds speed over several wingbeats, the legs give a quarter.
- "Share of acceleration on the perch" and "share of velocity at lift-off" are different measures. Provini et al. report both.

### 2.2 The sequence

- **The crouch.** First comes a slow preparatory crouch: the head moves, the body lines up with the take-off direction, and the trunk pitches down. The ankle and hip flex, and the knee flexes less. The crouch is deeper in the heavier dove than in the zebra finch, and may store elastic energy [17]. **[S]** (abstract)
- **The push.** Then a fast push: the limb extends as a unit, with the hip and ankle doing the most [17]. **[S]**
- **The first downstroke** starts just *after* the toes leave the perch: about 2 ms later in the finch and 6 ms in the dove. It already gives a good share of the lift of later wingbeats [14]. **[S]**
- **The stroke plane.** The first take-off downstrokes are steeply forward-down, from −60° to −47° over the first four wingbeats (pigeon). Speed rose from 1.5 to 4.5 m/s over those beats [7]. **[S]**

## 3. The feet at touchdown

Pacific parrotlets [10] **[S]**:

| Phase | Timing |
|---|---|
| Toes spread | starts about 100 ms before touchdown |
| Toes pre-shape to the perch | starts about 30 ms before touchdown |
| Toes wrap after contact | 19 ± 7 ms |
| Claws curl | over about 185 ms |

- **How far the toes wrap depends on the perch.** On a 6 mm perch they wrap more than 110 % of the circumference (the toes overlap), with no claw phase. On 19 mm they wrap about 50 %; on 38 mm, under 25 %, with the strongest claw curl.
- **Settling.** Birds took about 2 extra steps after anchoring.
- **The grip is active.** It adapts on contact. That fits Galton & Shepherd's finding that starlings have no passive automatic perching mechanism (`body_anatomy.md` §6).

---

## 4. How Flap compares

| Real bird | Flap | Where | Match |
|---|---|---|---|
| Dive under, swoop up; minimise the distance stalled [1] | The AI routes to an approach point below and out from the perch and swoops up into the catch. The catch envelope reaches further below the flight line (0.9 R) than above (0.35 R), so swooping up is how you catch. | `ai_pilot.gd`, `flight_planner.gd`, `Perch.in_reach` | qualitative |
| Pitch-up into a flare: body to 72° (pigeon), 82° (lovebird), near vertical (hawk) [1][7][12] | The body pitches up to `FLARE_PITCH` = 55°, peaking about two-thirds of the way through the landing, then settles to the perched pitch. | `bird.gd` | lower than measured, for a readable landing [E] |
| High drag in the flare, no lift peak [2][5] | The flare adds drag (+1.2 CD at full flare). It holds CL near the value that supports the weight, capped at 1.6 × CL max. | `flight_model.gd` | yes |
| Unsteady forces more than 10× quasi-steady [6] | The extra flare drag is a tuned constant, not an unsteady model. | `flight_model.gd` | motivated by [6] |
| Braking wingbeats with the stroke plane tilted up [7] | Two braking wingbeats with the wings swept forward 18° at a high twist (40°), alula out, tail fanned and pitched down. The wings start to fold in the last fifth. | `bird_rig.gd` `animate()` | qualitative |
| Covert and alula deployment in the pitch-up [4] | The alula deploys 25° forward with the flare or at high angle of attack. Underwing coverts are not modelled. | `bird_rig.gd` | partial |
| Constant rate of change of time-to-contact (tau) [2][10] | The landing blend brakes evenly: it lasts 2 × distance / speed, clamped to 0.3–0.8 s. | `bird.gd` | similar in spirit [E] |
| Landing speeds 2.3–2.5 m/s (hawk) [1]; 1.0 m/s (pigeon) [7] | Catch speed up to 1.15–1.3 × V_stall: about 6.8 m/s for the crow, 7.8 for the hawk, 10.6 for the falcon. | `bird_profile.gd` | much faster than real, for gameplay [E] |
| Feet forward, toes spread 100 ms and pre-shape 30 ms before contact [10] | In a flare the feet reach forward and down from the hip; on a grip point they go to it. Toes curl when sitting. | `bird_rig.gd` | partial; no pre-shaping |
| Legs absorb the remaining momentum [10][11][12] | On touchdown the trunk dips on flexing legs (up to 0.12 L over 0.4 s), with the feet on the grip. The tail pumps a few times for balance. | `bird_rig.gd` | qualitative |
| Head steady, angle tied to the approach [9] | The head is held still in world space through the flare and touchdown, and looks at the perch. | `bird_rig.gd` | yes |
| Crouch before take-off [17] | Not built. It needs a short delay before the bird leaves (`body_rig_plan.html`, build step 4). | — | missing |
| Legs give 80–95 % of jump take-off speed [13][14] | The bird leaves at `hop_speed` (2.5–3.5 m/s) along its facing, with one free wingbeat on a flap take-off. The feet keep pushing on the perch for `PUSH_TIME` = 0.15 s, so the legs extend. From the ground the jump is at least 3.5 m/s upward. | `bird.gd`, `bird_rig.gd` | yes in spirit: the hop is the leg push, the free wingbeat the first downstroke |
| First downstroke just after toe-off [14] | The free wingbeat starts at launch. | `bird.gd` | close enough at 60 Hz (a few ms) |
| Hawks take off at 3.8–4.0 m/s [1] | `hop_speed` 3.5 m/s for most birds, 2.5 m/s for the sparrow | `bird_profile.gd` | similar |

---

## Sources

1. KleinHeerenbrink M, France LA, Brighton CH, Taylor GK 2022, "Optimization of avian perching manoeuvres", *Nature* 607:91–96, doi:10.1038/s41586-022-04861-4. https://pmc.ncbi.nlm.nih.gov/articles/PMC9259480/
2. France LA 2019, *Mechanics and control of perching flight*, DPhil thesis, University of Oxford (supervisor G. K. Taylor). https://ora.ox.ac.uk/objects/uuid:a439bd30-3916-4fe9-ba06-c65fd1547048 (abstract)
3. Wüest V et al. 2024, "Agile perching maneuvers in birds and morphing-wing drones", *Nature Communications* 15, doi:10.1038/s41467-024-52369-4. (DOI from search; not read)
4. Carruthers AC, Thomas ALR, Taylor GK 2007, "Automatic aeroelastic devices in the wings of a steppe eagle *Aquila nipalensis*", *J Exp Biol* 210:4136–4149, doi:10.1242/jeb.011197. https://journals.biologists.com/jeb/article/210/23/4136/17202/Automatic-aeroelastic-devices-in-the-wings-of-a
5. Carruthers AC, Thomas ALR, Walker SM, Taylor GK 2010, "Mechanics and aerodynamics of perching manoeuvres in a large bird of prey", *Aeronautical Journal* 114:673–680. (abstract snippets only; no DOI found)
6. Polet DT, Rival DE, Weymouth GD 2015, "Unsteady dynamics of rapid perching manoeuvres", *J Fluid Mech* 767:323–341, doi:10.1017/jfm.2015.61. https://www.cambridge.org/core/journals/journal-of-fluid-mechanics/article/abs/unsteady-dynamics-of-rapid-perching-manoeuvres/B0CD5CFC7735B9BD3732E98FE11ED02A
7. Berg AM, Biewener AA 2010, "Wing and body kinematics of takeoff and landing flight in the pigeon (*Columba livia*)", *J Exp Biol* 213:1651–1658, doi:10.1242/jeb.038109. https://journals.biologists.com/jeb/article/213/10/1651/9685/Wing-and-body-kinematics-of-takeoff-and-landing
8. Green PR, Cheng P 1998, "Variation in kinematics and dynamics of the landing flights of pigeons on a novel perch", *J Exp Biol* 201:3309–3316, doi:10.1242/jeb.201.24.3309. https://researchportal.hw.ac.uk/en/publications/variation-in-kinematics-and-dynamics-of-the-landing-flights-of-pi/
9. Green PR, Davies MNO, Thorpe PH 1994, "Head-bobbing and head orientation during landing flights of pigeons", *J Comp Physiol A* 174:249–256, doi:10.1007/BF00193791.
10. Roderick WRT, Chin DD, Cutkosky MR, Lentink D 2019, "Birds land reliably on complex surfaces by adapting their foot-surface interactions upon contact", *eLife* 8:e46415, doi:10.7554/eLife.46415. https://elifesciences.org/articles/46415
11. Chin DD, Lentink D 2017, "How birds direct impulse to minimize the energetic cost of foraging flight", *Science Advances* 3:e1603041, doi:10.1126/sciadv.1603041. https://pmc.ncbi.nlm.nih.gov/articles/PMC5435416/
12. Bhagavatula PS, Biewener AA 2025, "Landing on a swinging perch: peach-faced lovebirds prefer extremes", *J Exp Biol* 228:jeb249692, doi:10.1242/jeb.249692. https://journals.biologists.com/jeb/article/228/8/jeb249692/367743/Landing-on-a-swinging-perch-peach-faced-lovebirds
13. Earls KD 2000, "Kinematics and mechanics of ground take-off in the starling *Sturnis vulgaris* and the quail *Coturnix coturnix*", *J Exp Biol* 203:725–739, doi:10.1242/jeb.203.4.725 (the paper spells the starling "*Sturnis*"). https://journals.biologists.com/jeb/article/203/4/725/8377/Kinematics-and-Mechanics-of-Ground-Take-Off-in-the
14. Provini P, Tobalske BW, Crandell KE, Abourachid A 2012, "Transition from leg to wing forces during take-off in birds", *J Exp Biol* 215:4115–4124, doi:10.1242/jeb.074484. https://journals.biologists.com/jeb/article/doi/10.1242/jeb.074484/257959/Transition-from-leg-to-wing-forces-during-take-off
15. Heppner FH, Anderson JGT 1985, "Leg thrust important in flight take-off in the pigeon", *J Exp Biol* 114:285–288. https://core.ac.uk/download/212937614.pdf (abstract via search snippet)
16. Tobalske BW, Altshuler DL, Powers DR 2004, "Take-off mechanics in hummingbirds (Trochilidae)", *J Exp Biol* 207:1345–1352, doi:10.1242/jeb.00889. https://journals.biologists.com/jeb/article/207/8/1345/15063/Take-off-mechanics-in-hummingbirds-Trochilidae
17. Provini P, Abourachid A 2018, "Whole-body 3D kinematics of bird take-off: key role of the legs to propel the trunk", *Naturwissenschaften* 105:12, doi:10.1007/s00114-017-1535-8. https://pubmed.ncbi.nlm.nih.gov/29330588/ (abstract)

**Weak or unverified:** the Heppner & Anderson numbers (search snippet); the Carruthers et al. 2010 abstract (snippets, no DOI); [3], which was not read. Green & Cheng's abstract does not mention the feet or legs, so it is cited only for the speeds and forces. "Legs swing forward before contact" is supported by the parrotlet toe timing [10] and the hawk's contact pose [1], not by a direct measurement of leg angle.
