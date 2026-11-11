# Turning kinematics: rolling into, holding and leaving a banked turn

How birds roll into a banked turn, hold it and roll out: what the wings, tail, head and legs do, with numbers where
studies give them. The use is visual: the bird rig can draw the two wings differing during a roll while the flight
model stays as it is (it sets bank directly at a per-species roll rate, always coordinated). The section that matters
for the code is **§10, For the rig**.

Tags:
- **[S]** sourced: the number or claim is in the paper's text, a table or a figure caption I read.
- **[F]** read by me off a figure in a paper I had (about ±3° or ±10 %).
- **[W]** secondhand: from an abstract, a review or a citing paper only.
- **[E]** our estimate: aerodynamic arithmetic (shown in §9) or judgement.
- **[G]** a gameplay or look choice, with no claim that a bird does it.

Source keys such as [ROS15] refer to the list at the end.

**The short version.** Real data on *gliding* roll is thin: the best onboard study of a soaring eagle could not
detect the roll inputs at all [GIL11]. Data on *flapping* turns is good but comes from slow (3 m/s) indoor turns of
pigeons and cockatoos. What holds across them:
- Roll happens quickly and is stopped quickly. The roll mode settles in tens of milliseconds (§9.3), so **the wings
  differ while the bank is changing and are close to alike in a held turn**. Drive the asymmetry from roll *rate*, not bank.
- The inner wing (the one going down) is flexed shorter and twisted leading-edge down; the outer wing is spread and
  at a higher angle of attack. Flapping, the outer wing also beats wider or further forward.
- The tail twists **against the roll's rate**: opposite the bank as the roll starts, and the other way
  ("overbanked") as the bird rolls out.
- The head stays close to level while the body banks (gain about 0.9 in pigeons), and turns into the turn in quick saccades.
- Legs: airbrakes when descending. I found no primary evidence that birds use them as rudders in turns.

---

## 1. Rolling in while gliding

- **Steppe eagle, onboard IMU and cameras.** The flight was mostly a continuous sequence of banked turns. The control
  inputs that generated roll in banked turns were too subtle to detect. The tail was spread and depressed just before
  a turn and "overbanked" later in the turn. The authors suggest the eagle is inherently stable in pitch and yaw, and
  perhaps in roll [GIL11]. **[W]** (abstract; the paper refused automated fetches)
- **Eagle, roll-overs and other unsteady manoeuvres.** The eagle morphed its wings asymmetrically while adjusting the
  wings' incidence. Over the turns it also showed asymmetric twist [GIL11 via HAR22]. No magnitudes in either. **[W]**
- **Peregrine falcon, gliding into a left roll** (3D surface reconstruction, flight P3): the right wing was **40 mm
  more extended than the left, about 16 % more area**, and the left wrist was forward of the right [DUR19, Fig. 8B-C].
  The span was 562 mm, so 40 mm is about **14 % of a semispan**. **[S]** (one flight)
- **Barn owl, gliding rolls** (same study): twist asymmetry near the body in two rolling flights and near the tip in a
  third. The wing on one side had slightly more camber near the tip, reversed in the flight rolling the other way.
  None of it was quantified [DUR19, Figs 7, 8A]. **[S]** (qualitative)
- **Hen harrier** (Oehme 1976, film): changed its wings' incidence and **folded the right wing at the wrist, and
  rolled right**, so the inner wing was the folded one. It began the turn with a negative tail rotation as well
  [OEH76 via HAR22, PHA23]. **[W]**
- **Two proposed twist methods** (Warrick et al. 2002): reduce the inner wing's twist (incidence) to cut its lift, or
  raise it until the inner wing stalls and use the drag [WAR02 via HAR22]. **[W]** The first matches every other observation here.
- **Raptor-like feathered drone** [PHA23]: for a sharp right turn it folded the **right** (inner) wing together with
  the tail twist. To return to level it folded the **left** wing (the outer wing of the turn) and reversed the tail.
  Wing folding alone could not turn it, because of adverse yaw; the tail twist had to coordinate it [PHA23, Fig. 4,
  Ext. Data Figs 9-11]. **[S]** (a robot, not a bird)
- **Gull wing morphing** (Harvey et al. 2019, 2022): the measurements and models are longitudinal (pitch stability),
  not roll. I found no gull roll numbers. **Swifts** [LEN07]: sweep changes glide and turn performance (extended wings
  turn much faster), but the study measured symmetric sweep only, not roll asymmetry.

**Magnitudes.** No study gives a measured left-minus-right twist angle for a gliding roll. §9.1 estimates it from
aerodynamics: **about 1° per wing per 25-30 deg/s of roll at hawk scale, and per 100 deg/s at sparrow scale**. That
is small enough that cameras miss it, as in [GIL11]. **[E]**

## 2. Rolling while flapping

### 2.1 Pigeons (Columba livia), slow 90° turns at about 3 m/s

- **Warrick & Dial 1998** (200 Hz 3D video): pigeons made the force difference with **downstroke velocity
  asymmetries**, not with angle-of-attack or area asymmetries. The asymmetry is created **early in the downstroke**
  and usually **reversed at the end of the same downstroke**, which arrests the roll. When it isn't reversed, the
  upstroke stops the roll instead, through drag differences between the wings. Bank is held as a "precise average" of
  rapidly alternating opposite forces [WD98]. **[W]** (abstract) Roll accelerations exceeded **1500 rad/s²
  (~86,000 deg/s²)** averaged over 20 ms, about 1/5 of a wingbeat [WD98 via HB07]. **[W]**
- **Pectoralis force** (Warrick, Dial & Biewener 1998): **4-6 successive wingbeats** in which the outside wing's peak
  force exceeded the inside wing's. The turn is saltatory, not one push to bank and one to stop [WDB98]. **[W]**
- **Ros et al. 2015** (11 cameras, 3 birds, 18 turning wingbeats) [ROS15]:
  - Wing speed, area, angle of attack, amplitude and timing showed **no** inside-outside asymmetry that predicted roll. **[S]**
  - Instead, the **outside wing sweeps further forward** and the inside wing runs more laterally and retracted
    (Fig. 6). The whole stroke tilts toward the turn and the net force, acting above the centre of mass, rolls the
    bird in. **[S]**
  - **Pronation**: the inside wing is more pronated (leading edge down) in the first half of the downstroke. The
    difference is about **-12°**, and it reverses to about **+12°** in the second half (Fig. 7A). **[F]** This keeps
    both wings at similar aerodynamic angles of attack, given their different paths. **[S]**
  - **Late in the downstroke** the inside wing is about **1-1.5 m/s faster** (of about 15 m/s, Fig. 7B) and swings
    about **25° more laterally** (Fig. 7C). This damps and stops the roll. **[F]**
  - **Timing**: roll starts early in the downstroke, its velocity peaks at mid-downstroke and it is arrested late in
    the downstroke. Upstroke roll is small (Fig. 5). **[S]**
  - Over the turn the birds **roll in for the first half and roll out for the second**. No held bank in a 90° turn this tight. **[S]**
- **Ros et al. 2011**: the downstroke force points **38 ± 7° forward** of the body's dorsoventral axis. About 65-70
  % of body rotation in early wingbeats redirects that force (helicopter-like). The upstroke gives lift at mid-stroke
  (peak 2.3 BW against the downstroke's 4.5 BW). The upstroke is 42 % of the wingbeat, at 8.3 Hz [ROS11, Figs 4-6]. **[S]**

### 2.2 Rose-breasted cockatoo, 90° corridor turn [HB07, HUB07]

- Banked flapping turns, radius **0.92 m**. Heading rate in each downstroke is predicted by roll angle at
  mid-downstroke (r² = 0.95). Heading changes **2.1×** faster in the downstroke than in the upstroke [HB07]. **[S]**
- **Amplitude asymmetries** dominate, rather than timing: right-left peak-to-peak differences **over 20° at the
  wrist and 30° at the tip** on occasion. Their simulation used 90° against 70° [HB07]. **[S]** Asymmetries were
  biggest at the stroke reversals and small at mid-stroke (Fig. 5). Asymmetric wrist flexion and wingtip paths were
  visible but did **not** correlate with roll (Fig. 11). **[S]**
- **Roll within a wingbeat**: about **16° peak-to-peak** at wingbeat frequency (7.5 Hz), largely inertial from the
  wings' swing. **Over wingbeats**: about **45° peak-to-peak** over about 3 wingbeats. Change per wingbeat 13.9 ± 11°;
  inertia accounts for only 1-3° of it [HB07, Fig. 8]. **[S]**
- **Roll damping** coefficient about **-1.5**, 2-6× an aircraft's (-0.45): flapping wings damp roll strongly [HUB07]. **[S]** (abstract)
- A larger outside-pectoralis EMG burst went with roll toward the inside [HB07]. **[S]**

### 2.3 Hummingbirds (arcing turns at a revolving feeder) [READ16]

- Body and both stroke planes bank into the turn together. The **outer wingtip path is higher and flatter**, the inner
  lower and more deviated. Turn radius is controlled by these asymmetries, speed by symmetric changes. **[W]** (abstract)

**What to draw for a flapping roll**: the outer wing beats wider and further forward in the downstroke; the inner wing
beats narrower, more retracted and pronated. The difference peaks in the first half of the downstroke and flips
briefly in the second half. The upstroke is nearly symmetric.

## 3. The held turn

- **Wings back to near-symmetric.** Soaring raptors "execute steady banked turns without exhibiting observable wing
  movements apart from tail twisting around the body axis" [PHA23, abstract]. The eagle's roll inputs were undetectable,
  and no input to end a turn was found [GIL11; HAR22 on GIL11]. **[S]** / **[W]**
- **A small held asymmetry is expected.** In a turn the outer wing moves faster than the inner, so it makes more lift
  (overbanking). Cancelling that needs the inner wing at about **+1 to +1.5° incidence** against the outer: about 1°
  for a vulture thermalling, 1.4° for a hawk in a tight turn (§9.4). Dihedral and a little sideslip can do the job
  instead. Either way it is invisible at game distance. **[E]**
- **Load.** At bank φ in a level turn the load factor is n = 1/cos φ: 1.15 at 30°, 1.41 at 45°, 2 at 60°. At the
  same speed, the angle of attack above zero-lift scales by n, so the wings sit visibly nose-up in steep turns, and
  the primaries flex up more under the load. **[E]** (standard flight mechanics)
- **Thermalling bank angles.** Griffon vultures' median bank per bird was **25-35°**, starting near 30° and easing to
  about 22° higher up. Turn radius was about 14 m at airspeeds of 13-14 m/s [WIL18, Table 1]. **[S]**
- **Sweep.** For turning, extended wings beat swept ones: in swifts, extended wings turn much faster at low speed [LEN07]. **[S]**
- **Tail spread.** The eagle spread and depressed its tail just before turns [GIL11]. Tails are spread in slow
  flight and furled in fast cruise [THO93]. **[W]**
- **Tail pitch from twist.** On the drone, twisting the tail cut the tail's lift and pitched the nose up, raising the
  wings' angle of attack. This is the elevator's job in an aircraft turn [PHA23, Fig. 2a-b]. **[S]** (robot)

## 4. The tail

- **Direction.** "In the entry phase of a banked turn, birds twist the tail in the opposite direction to the bank,
  and in the exit phase reverse the tail rotation" [PHA23, citing GIL11 and OEH76]. The eagle's tail was "overbanked"
  late in the turn [GIL11]. **[W]** So **the tail twists against the roll's rate**:
  - rolling in, the tail lags the body and looks more level than it;
  - rolling out, the tail stays banked past the body.
- **Why**, on the drone: with the wings ahead, the raised half of a twisted tail sits in the wings' wake, so the lower
  half lifts more. The roll moment is **opposite to the tail's own rotation**. Without wings it reverses. The twist
  also gives proverse yaw [PHA23, Fig. 2c-i]. **[S]** (robot)
- **Holding vs rate.** The drone held **±30°** of tail twist (where its roll moment peaked) through a turn. Holding
  it kept the roll increasing until the drone tumbled, and a reversed twist was needed to level out [PHA23, Fig. 3].
  The tail behaves like a **roll-rate command**, not a bank-angle setting. Drone turns: bank 31 ± 9°, radius 11 ± 3 m;
  sharp turns: bank 84 ± 5°, radius 1.9 ± 0.3 m [PHA23]. **[S]** (robot)
- **Magnitudes on birds.**
  - Eagle: tail bank angle changed by **up to 30° within a few seconds**, with continual changes of spread [TAY07]. **[W]** (abstract)
  - Gliding barn owls: tail twist **-4.7°, 12.6°, -5.2°** in three flights with body roll under 9°.
  - Gliding peregrines: **11.0°, -0.3°, 5.1°** in three flights.
  - The tail AoA was 18-28° throughout [DUR19, Table 1]. So **5-13° of tail twist accompanies mild rolls**. **[S]**
- **Reflex tail response** (pigeons rolled on a platform, in "flight" with airflow on): a compensatory tail movement
  against the roll, gain **0.28** in flight vs **0.14** at rest. Platform roll was slow: peak 5-20 deg/s, 0.25-1 Hz.
  The measured axis is the tail's **yaw (dorsoventral)** axis, which the authors call a "twist", so it may be partly
  a sideways swing [MD11, Table 3]. **[S]**
- **Sign confusion in the literature.** The review [HAR22] reports the eagle with "steady positive rotation at the
  start" of a right turn (against spiral instability) and "transient negative tail rotations" against adverse yaw.
  Its sign convention isn't recoverable from the text I had. I rely on [PHA23]'s physical description above. **[W]**
- **Tail-twist roll authority is weak** on fixed-wing models with a flat rotating tail, too small to be primary roll
  control [HAR22, citing Hummel and Parga et al.]. The drone result disagrees, because its tail sits in the wings' wake. **[W]**

## 5. The head

- **Pigeons, platform roll in simulated flight** [MD11, Tables 1-2]:
  - **head roll gain 0.91** in flight (0.80 at rest);
  - gaze gain with the head free 0.96;
  - phase about -180°: fully compensatory, no visible lag at 0.25-1 Hz.
  - At rest the gain fell to about 0.5 at 5 deg/s and reached about 0.8 at 20 deg/s. In flight it was near 1 at all
    velocities tested. Small amplitudes only (peak 5-20 deg/s). **[S]**
- **Pigeons in 90° turns** [ROS17]:
  - The head is held still in all three axes between **saccades**: quick repositionings in **yaw and roll** (little
    pitch), always **into the turn**, in 63 % of turning wingbeats, each lasting 17.6 % of a wingbeat.
  - Head and body rotations are uncorrelated.
  - A 90° turn took 5.5 wingbeats, 0.63 s. **[S]**
- **Lovebirds** [KRE15] (yaw only): head saccades of median **28°** (up to 60°), lasting **median 30 ms** (up to 45
  ms), peaking at up to **2700 deg/s**. Visuomotor delay 30-70 ms. Saccades start about 3/4 of the way through the downstroke. **[S]**
- **Why it matters**: pigeons in collars that stopped the neck isolating the head lost the horizon in **50 %** of
  flights with induced rolls, and could not keep controlled flight [WAR02]. **[W]** (abstract)
- **Steppe eagle**: head movements stabilise gaze during deliberate turns, like nystagmus in humans [TAY07]. **[W]**
- **Free-flying pigeons** (head-mounted IMU): head roll relative to gravity stayed within about **±20°** (s.d. 17°) [KAN18]. **[W]** (search snippet)
- **Large banks**: no study gives the head's roll at 45-80° of body bank. A gain near 0.9 to the neck's limit is our
  extrapolation [E]. Owls' eyes barely move in the skull, so an owl's gaze depends on the head even more. **[E]**
  (general anatomy, not a turning measurement)

## 6. Legs and feet

- **Airbrakes, yes.** Rüppell's griffon vulture: lowering the legs and feet adds controllable drag. The legs and feet
  have a drag coefficient of about 1.08, and lowered they give **more than twice the drag of the body** with the feet
  raised. Pigeons in a wind tunnel use their feet constantly for small adjustments [PEN71]. **[W]** (abstract and
  search snippets) Fulmars use their feet, not the tail, to add drag in descent [PW59 via HAR22]. **[W]**
- **Rudders in turns: no evidence found.** None of the turning studies above (pigeon, cockatoo, eagle, owl, falcon,
  swallow) reports leg use in turns. Raptors cruise with the feet tucked under the flank feathers. **[E]** for "rare".

## 7. Rolling out

- **Pigeons**: the velocity asymmetry is reversed at the end of the same downstroke, or the upstroke's drag
  asymmetry stops the roll [WD98]. **[W]** The pronation difference flips sign at mid-downstroke, and the inside
  wing's late speed and lateral swing damp the roll passively [ROS15, Fig. 7]. **[S]/[F]**
- **Cockatoos**: roll damping 2-6× an aircraft's, so the roll stops soon after the asymmetry ends [HUB07]. **[S]**
- **Eagle**: no input to end a turn was found; inherent stability is suggested [GIL11 via HAR22]. **[W]**
- **Drone**: reversing the tail twist ended the turn; folding the turn's outer wing as well leveled it faster
  [PHA23, Figs 3-4]. **[S]** (robot)
- So **the roll-out mirrors the roll-in**: the wing that was outer becomes the inner one of the roll back to level.
  It is usually shorter and gentler, because damping and dihedral help. **[E]**

## 8. Roll rates and how long the asymmetry lasts

| Bird, manoeuvre | Number | Grade |
|---|---|---|
| Pigeon, 90° turn: peak roll velocity within a downstroke | mean ~500 deg/s (Fig. 5A), individual peaks ~900 deg/s; acceleration to ~7×10⁴ deg/s² | [F] / [S] [ROS15] |
| Pigeon, same: net roll accumulated over the turn | 77 ± 14° (Table 2) in 0.63 s, so ~120 deg/s averaged | [S] [ROS15, ROS17]; average [E] |
| Pigeon, same: roll oscillation within a wingbeat | 13 ± 6° per wingbeat | [S] [ROS11, Table 1] |
| Pigeon (Warrick & Dial) | roll acceleration > 1500 rad/s² over 20 ms | [W] [WD98 via HB07] |
| Cockatoo, 90° turn | whole-wingbeat roll velocity 117 ± 27 deg/s; quarter-stroke 236 ± 73 deg/s; peak bank > 40° | [S] [HB07] |
| Barn swallow, foraging turns | turn duration 0.6 ± 0.3 s (0.2-1.5); heading rate 210 ± 194 deg/s (up to 716); 4.4 g peak | [S] [WAR16, Table 4] |
| Cliff swallow | bank up to 78° | [S] [SHE14] |
| Steppe eagle, soaring | heading rates typically ±60 deg/s; loads 0-2.5 g | [W] [TAY07] |
| Griffon vulture, thermalling | bank 25-35° | [S] [WIL18] |
| Roll mode time constant | ~15-40 ms (hawk, pigeon scale) | [E] §9.3 |

Flap's roll rates (`BirdProfile.roll_rate_deg`): crow 320, owl 180, hawk 120, falcon 240, sparrow 420 deg/s. These sit
between the birds' wingbeat-averaged rates (100-250 deg/s) and their within-stroke peaks (500-900 deg/s). A roll from
level to 45° takes:

| Species | 0 → 45° | Wingbeats in that time |
|---|---|---|
| Crow | 0.14 s | 0.5 |
| Owl | 0.25 s | 0.6 |
| Hawk | 0.38 s | 0.8 |
| Falcon | 0.19 s | 0.9 |
| Sparrow | 0.11 s | ~1 |

So the asymmetry is on screen for a fraction of a second: it must be clear to be seen at all. **[E]**

## 9. Aerodynamic arithmetic (the estimates' basis)

Strip theory on an elliptic wing, lift slope a, span b, airspeed V. The lift slope cancels in every ratio below.

### 9.1 Twist per roll rate (gliding)

- A differential incidence of ±δ on the whole wings gives a rolling moment coefficient Cl = (2/3π)·a·δ ≈ 0.21 a δ.
- The roll damping is Cl_p = -a/8 per unit pb/2V.
- So the steady roll rate is **pb/2V ≈ 1.7 δ**, or **δ (each wing) ≈ 0.29 · p · b / V** (δ and p in the same angle units, p per second).
- Twisting only the hand (the outer half of the semispan) carries about 65 % of the moment arm, so it needs ×1.5.
- Plausible gliding speeds (CL ≈ 0.8) and Flap's spans give, at each species' full roll rate:

| Species | b (m) | V (m/s) | Each wing, whole-wing twist | Hand-only twist | Per 100 deg/s, whole wing |
|---|---|---|---|---|---|
| Crow (320 deg/s) | 0.96 | 8.3 | 10.9° | 16.8° | 3.4° |
| Owl (180) | 1.10 | 8.5 | 6.8° | 10.5° | 3.8° |
| Hawk (120) | 1.30 | 9.3 | 4.9° | 7.6° | 4.1° |
| Falcon (240) | 0.93 | 12.2 | 5.3° | 8.2° | 2.2° |
| Sparrow (420) | 0.33 | 8.2 | 5.0° | 7.6° | 1.2° |

- The required twist goes as 1/V: double it at half speed. Near stall the outer wing can't take more angle of attack,
  so the twist runs out and the fold (below) takes over. **[E]**

### 9.2 Inner-wing fold per roll rate

- Cutting a fraction f off the inner semispan's tip removes (1-(1-f)²)^1.5 of that wing's rolling moment. For f = 0.14
  (the peregrine) that is 13 %, a ΔCl of about 0.014 CL.
- At CL ≈ 1 that rolls a hawk at about **25 deg/s**, and **in proportion to CL**. So folding is weak when fast (low CL)
  and strong when slow (high CL), the opposite of twist. This fits folding being seen in slow manoeuvres (the harrier,
  the drone's slowed sharp turn) and subtle twist in fast gliding. **[E]**
- Folding also cuts the inner wing's drag, while the twisted-down inner wing loses drag too. Either way the outer wing
  has more drag: adverse yaw, which the tail corrects (§4). **[E]**

### 9.3 Roll time constant

- τ = I_xx · 2V / (-Cl_p · q · S · b²). Take the wings at about 6 % of body mass each, with radius of gyration ~0.35
  of the semispan.
- That gives τ ≈ **15 ms** for both a pigeon (0.32 kg, 10 m/s) and a hawk (1.2 kg, 9 m/s). Allow ×2 for feathers'
  flex and unsteady lag. Flapping adds 2-6× more damping [HUB07].
- So the roll rate follows the wing asymmetry almost at once. **The asymmetry should be proportional to roll rate,
  with only a brief extra kick as the rate changes**, which is roll acceleration. **[E]**

### 9.4 Held-turn trim

- In a coordinated turn of radius R, the outer wing's extra speed gives a rolling moment Cl ≈ (CL/4)(b/2R)cos φ.
- Cancelling it with differential incidence needs δ ≈ (CL/4)(b/2R)cos φ / 0.21a. With a ≈ 4.7 per rad:
  - vulture (CL 0.81, b 2.5 m, R 14 m, φ 30°): **0.9°** per wing;
  - hawk (CL 1.2, b 1.3 m, R 5 m, φ 50°): **1.4°** per wing.
- The inner wing is the one that is nose-up. **[E]**

## 10. For the rig

The rig already carries a roll shape (`BirdRig._roll_shape`): `roll_cmd` (the drawn bank's rate, normalised to the
species' `roll_rate_deg`, with a lead), `ROLL_TWIST_DEG`, `ROLL_FOLD`, `ROLL_SWEEP_DEG`, `ROLL_BEAT`, `TAIL_ROLL_DEG`
and a tail bank term (-0.25 × bank). Below, each control with a number and its grade. "Full rate" means
|roll_cmd| = 1.

1. **Drive the asymmetry from roll rate, not bank.** Keep the current design: asymmetry ∝ roll_cmd, wings alike in a
   held turn.
   - Grade: **[E]** from §9.3; supported by the drone's held tail twist rolling on [PHA23] **[S]** and the eagle's
     undetectable held inputs [GIL11] **[W]**.
   - `ROLL_TAU` 0.03-0.04 s **[E]**.
   - `ROLL_LEAD` 0.02-0.03 s, so a roll's start and stop show as a brief overshoot of about 0.3-0.5 of the entry shape **[E]**.
2. **Wing twist, outer up and inner down.**
   - Direction: **[S]** for flapping (inner pronated in the first half of the downstroke [ROS15]); **[W]** for gliding [HAR22, GIL11].
   - Magnitude per wing at full rate, from §9.1 (whole-wing, so the arm's `twist`): **crow 11°, owl 7°, hawk 5°,
     falcon 5°, sparrow 5°**. Or one constant: **5-6° (the current 6° is in band)** with crow up to about 10°. **[E]**
   - Better still, per unit roll rate: **δ ≈ 0.3 · p · b / V** (deg, with p in deg/s, b in m, V the current airspeed
     in m/s). Clamp to about 12°, and to 0.5-2× its cruise value at extreme speeds. This makes slow rolls twist more,
     as they should. **[E]**
   - Exaggerating 1.5-2× so it reads at game distance is a fair **[G]** choice. The real thing is subtle enough that
     an eagle's onboard camera missed it.
3. **Inner wing flex (`ROLL_FOLD`).**
   - Shorten the inner semispan by **10-15 % at full rate**. Grade: **[S]** for the one peregrine sample (14 %, 16 %
     area [DUR19]); **[W]** direction from the harrier [OEH76] and the drone [PHA23].
   - Convert `ROLL_FOLD` 0.18 (of `fold`) to span to check it lands there. **[E]**
   - Weight it by lift coefficient: about × (CL / CL_max) + 0.3, so slow, high-lift rolls fold visibly and fast rolls
     mostly twist (§9.2). **[E]**
   - Flexing at the elbow brings the inner wrist **forward** and the hand back, as on the peregrine. A separate
     shoulder sweep isn't needed: `ROLL_SWEEP_DEG` 0, or at most 3-5°. **[S]** for the wrist; **[G]** for the value.
4. **Flapping: outer wing wider and further forward.**
   - `ROLL_BEAT` about **0.25** (outer +25 %, inner -25 % of amplitude at full rate) **[S]**: cockatoo differences
     over 20° at the wrist and 30° at the tip, and their 90° vs 70° simulation [HB07].
   - Pigeons show the same effect as a forward-tilted outer stroke (outer wing more anterior in the downstroke [ROS15]),
     which can stand in for, or add to, the amplitude difference **[S]**.
   - **Phase-weight it**:
     - full asymmetry in the first half of the downstroke;
     - reversed at about **1/3** in the second half (the pigeon's pronation difference flips -12° → +12°, and the
       inner wing swings ~25° more laterally late [ROS15, Fig. 7]);
     - near zero on the upstroke.
     - Grade: **[F]** for the shape, **[E]** for 1/3.
   - For the sparrow a full roll lasts about one wingbeat (§8), so the beat asymmetry is the cue to show. **[E]**
5. **Held turn.**
   - Wings symmetric except an optional inner-wing **+1°** of incidence held **∝ CL·b/R**. Grade: **[E]**, §9.4; skip
     it, it's invisible.
   - Nose-up and primaries flexed more under load n = 1/cos φ. This comes free if the rig's `twist` already follows
     the flight model's angle of attack. **[E]**
   - Tail spread rising with |bank| (the current `spread_t`) **[W]**: the eagle spreads before turning [GIL11].
6. **Tail twist: against the roll rate.**
   - `tail_twist_relative_to_body = -K_r · roll_cmd`, with **K_r ≈ 12-20° at full rate, capped at ±30°**:
     - entry: twisted opposite the roll, the tail looking more level than the body;
     - exit: the reverse, the tail overbanked.
   - Grades: direction **[W]/[S]** ([PHA23] citing eagle and harrier; drone physics); cap **[S]** (the drone's ±30°;
     the eagle's 30° in seconds [TAY07]); 12-20° **[E]** (birds show 5-13° in mild rolls [DUR19]).
   - Check the rig's sign convention against this physical description. The current comment says "with the bank",
     which may be the overbank sense, right for the exit but not the entry.
   - **Bank term**: 0 to 0.25 × bank, compensatory (the tail nearer world-level). The current 0.25 matches the
     pigeon's reflex tail gain of 0.28 [MD11] **[S]**, but that was measured at small slow rolls on the yaw axis. The
     eagle's late "overbank" [GIL11] **[W]** argues for less. Suggest about **0.1** and let the rate term carry the
     look **[G]**.
7. **Head: counter-roll toward level.**
   - Head roll relative to the body = **-0.9 × body bank** **[S]** (pigeon in flight, 0.91 [MD11], small angles).
     Saturate at the neck's limit, about **±60°** **[E]**. A gain of 0.95-1.0 for the owl **[E]**.
   - No visible lag in steady rolling (phase ≈ -180° at ≤ 1 Hz [MD11]) **[S]**. Ease with τ ≈ 20-40 ms **[E]**.
   - Add **saccadic head yaw into the turn**: 20-30° steps in about 30 ms, leading the body's heading, repeated each
     wingbeat or two while turning (**[S]** pigeon direction [ROS17], lovebird size and duration [KRE15]). Use smooth
     look-ahead if saccades look jittery **[G]**.
8. **Legs: nothing for roll.** No evidence of rudder use **[E]**. Lower them only for airbrake or steep descent and
   landing [PEN71] **[W]**.
9. **Roll-out.**
   - It's the same mapping with the rate's sign flipped: the wing that was outer becomes inner. Grade: **[S]** for
     pigeons ([WD98], [ROS15]) and the drone [PHA23].
   - Make it 0.6-0.8× as strong as the entry for the same rate, because dihedral and damping help **[E]**.
   - The lead term's brief reversal at the end of each roll is the "check" **[S]** in pigeons, where the asymmetry is
     reversed within the same downstroke [WD98].

**What would firm this up**: the full text of [GIL11] (tail angles through a turn and any wing-twist magnitudes);
[WD98] Tables (pigeon velocity asymmetry in m/s); and a frame-by-frame look at hawk or kite gliding turns. Kites
(Milvus) twist their forked tails conspicuously; the drone authors drew on hawk video.

---

## Sources

1. [ROS15] Ros IG, Badger MA, Pierson AN, Bassman LC, Biewener AA 2015 (online Dec 2014), "Pigeons produce aerodynamic torques through changes in wing trajectory during low speed aerial turns", *J Exp Biol* 218:480-490, doi:10.1242/jeb.104141. Author manuscript (read in full, Figs 5-7 read off): http://nrs.harvard.edu/urn-3:HUL.InstRepos:14117004
2. [ROS11] Ros IG, Bassman LC, Badger MA, Pierson AN, Biewener AA 2011, "Pigeons steer like helicopters and generate down- and upstroke lift during low speed turns", *PNAS* 108:19990-19995, doi:10.1073/pnas.1107519108. https://pmc.ncbi.nlm.nih.gov/articles/PMC3250151/
3. [ROS17] Ros IG, Biewener AA 2017, "Pigeons (C. livia) follow their head during turning flight: head stabilization underlies the visual control of flight", *Front Neurosci* 11:655, doi:10.3389/fnins.2017.00655. https://pmc.ncbi.nlm.nih.gov/articles/PMC5717024/
4. [WD98] Warrick DR, Dial KP 1998, "Kinematic, aerodynamic and anatomical mechanisms in the slow, maneuvering flight of pigeons", *J Exp Biol* 201:655-672, doi:10.1242/jeb.201.5.655 (abstract; full text refused automated fetch)
5. [WDB98] Warrick DR, Dial KP, Biewener AA 1998, "Asymmetrical force production in the maneuvering flight of pigeons", *The Auk* 115:916-928, doi:10.2307/4089510 (abstract via search)
6. [HB07] Hedrick TL, Biewener AA 2007, "Low speed maneuvering flight of the rose-breasted cockatoo (Eolophus roseicapillus). I. Kinematic and neuromuscular control of turning", *J Exp Biol* 210:1897-1911, doi:10.1242/jeb.002055. Read in full: https://cdr.lib.unc.edu/downloads/s1784v80g
7. [HUB07] Hedrick TL, Usherwood JR, Biewener AA 2007, "... II. Inertial and aerodynamic reorientation", *J Exp Biol* 210:1912-1924, doi:10.1242/jeb.002063 (abstract)
8. [READ16] Read TJ, Segre PS, Middleton KM, Altshuler DL 2016, "Hummingbirds control turning velocity using body orientation and turning radius using asymmetrical wingbeat kinematics", *J R Soc Interface* 13:20160110, doi:10.1098/rsif.2016.0110 (abstract)
9. [GIL11] Gillies JA, Thomas ALR, Taylor GK 2011, "Soaring and manoeuvring flight of a steppe eagle Aquila nipalensis", *J Avian Biol* 42:377-386, doi:10.1111/j.1600-048X.2011.05105.x (abstract via search; publisher refused fetch)
10. [TAY07] Taylor GK, Bacic M, Carruthers AC, Gillies J, Ozawa Y, Thomas ALR 2007, "Flight control mechanisms in birds of prey", 45th AIAA Aerospace Sciences Meeting, doi:10.2514/6.2007-39 (abstract on ORA: https://ora.ox.ac.uk/objects/uuid:08ae7cb8-ca1c-4075-a314-b39f082b07dc)
11. [DUR19] Durston NE, Wan X, Liu JG, Windsor SP 2019, "Avian surface reconstruction in free flight with application to flight stability analysis of a barn owl and peregrine falcon", *J Exp Biol* 222:jeb185488, doi:10.1242/jeb.185488. https://pmc.ncbi.nlm.nih.gov/articles/PMC6525094/
12. [PHA23] Phan H-V, Floreano D 2023, "Raptor-informed feathered drone reveals tail-twist functions in avian turning manoeuvres", bioRxiv, doi:10.1101/2023.12.29.573672 (read in full). Published as "A twist of the tail in turning maneuvers of bird-inspired drones", *Sci Robot* 9(96):eado3890, 2024, doi:10.1126/scirobotics.ado3890 (not read; numbers here are the preprint's)
13. [HAR22] Harvey C, Gamble LL, Bolander CR, Hunsaker DF, Joo JJ, Inman DJ 2022, "A review of avian-inspired morphing for UAV flight control", *Prog Aerosp Sci* 132:100825, doi:10.1016/j.paerosci.2022.100825. https://par.nsf.gov/servlets/purl/10378245
14. [OEH76] Oehme H 1976, "Die Flugsteuerung des Vogels. III. Flugmanöver der Kornweihe (Circus cyaneus)", *Beitr Vogelkd* 22:73-82 (via [HAR22], [PHA23]; not read)
15. [WAR02] Warrick DR, Bundle MW, Dial KP 2002, "Bird maneuvering flight: blurred bodies, clear heads", *Integr Comp Biol* 42:141-148, doi:10.1093/icb/42.1.141 (abstract)
16. [MD11] McArthur KL, Dickman JD 2011, "State-dependent sensorimotor processing: gaze and posture stability during simulated flight in birds", *J Neurophysiol* 105:1689-1700, doi:10.1152/jn.00981.2010. https://pmc.ncbi.nlm.nih.gov/articles/PMC3075286/
17. [KRE15] Kress D, van Bokhorst E, Lentink D 2015, "How lovebirds maneuver rapidly using super-fast head saccades and image feature stabilization", *PLoS ONE* 10:e0129287, doi:10.1371/journal.pone.0129287. https://pmc.ncbi.nlm.nih.gov/articles/PMC4481315/
18. [KAN18] Kano F, Walker J, Sasaki T, Biro D 2018, "Head-mounted sensors reveal visual attention of free-flying homing pigeons", *J Exp Biol* 221:jeb183475 (search snippet only). https://journals.biologists.com/jeb/article/221/17/jeb183475/19611/Head-mounted-sensors-reveal-visual-attention-of
19. [WAR16] Warrick DR, Hedrick TL, Biewener AA, Crandell KE, Tobalske BW 2016, "Foraging at the edge of the world: low-altitude, high-speed manoeuvering in barn swallows", *Phil Trans R Soc B* 371:20150391, doi:10.1098/rstb.2015.0391. https://pmc.ncbi.nlm.nih.gov/articles/PMC4992715/
20. [SHE14] Shelton RM, Jackson BE, Hedrick TL 2014, "The mechanics and behavior of cliff swallows during tandem flights", *J Exp Biol* 217:2717-2725, doi:10.1242/jeb.101329
21. [WIL18] Williams HJ, Duriez O, Holton MD, Dell'Omo G, Wilson RP, Shepard ELC 2018, "Vultures respond to challenges of near-ground thermal soaring by varying bank angle", *J Exp Biol* 221:jeb174995, doi:10.1242/jeb.174995
22. [LEN07] Lentink D, Müller UK, Stamhuis EJ, de Kat R, van Gestel W, Veldhuis LLM, Henningsson P, Hedenström A, Videler JJ, van Leeuwen JL 2007, "How swifts control their glide performance with morphing wings", *Nature* 446:1082-1085, doi:10.1038/nature05733
23. [THO93] Thomas ALR 1993, "On the aerodynamics of birds' tails", *Phil Trans R Soc Lond B* 340:361-380, doi:10.1098/rstb.1993.0079 (via citing papers)
24. [PEN71] Pennycuick CJ 1971, "Control of gliding angle in Rüppell's griffon vulture Gyps rüppellii", *J Exp Biol* 55:39-46, doi:10.1242/jeb.55.1.39 (search snippets)
25. [PW59] Pennycuick CJ, Webbe D 1959, "Observations on the fulmar in Spitsbergen", *Brit Birds* 52:321-332 (via [HAR22])

**Weak or unverified:** everything tagged [W]. Above all [GIL11], the one gliding-raptor turning study, rests on
its abstract and on how [HAR22] and [PHA23] describe it. The sign conventions of its tail rotations are unknown.
[PHA23] numbers are from the preprint, and the published version may differ. [MD11]'s tail axis is the yaw axis,
not certainly a twist about the tail's long axis. Harvey et al.'s gull papers (J R Soc Interface 2019; Nature 2022)
are named from memory and were not fetched. They are longitudinal, so nothing here rests on them. The Figs 5-7
readings from [ROS15] are mine, off the author manuscript's plots.
