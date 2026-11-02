# Bird Wing Shapes and Articulation: Research Notes for Flight Feel

Scope: research to back a third-person 3D bird flight combat demo (Godot 4). The goal is flight
that reads as natural and is easy to pick up, not a full aero sim. Everything here is filtered
for "what should we model, and how do we show it on a greybox mesh".

Numbers marked `~` are approximate figures from the general literature, given only to get the
ratios right between shapes. They are not species-exact.

---

## 1. Wing shape classes

Aspect ratio (AR) = span^2 / wing area. Wing loading (WL) = weight / wing area (N/m^2; to convert
from kg/m^2, multiply by 9.81). Bird WL generally runs ~1-20 kg/m^2 (~10-200 N/m^2) [SLH][NASA].
Watch the conventions: some sources use span / mean chord, or count only one wing, so an AR from
one paper may not compare with another (a Wilson Bulletin study gives sharp-shinned hawk AR
~2.74 on a different convention) [WB].

| Class | Examples | AR (~) | WL (~) | Flight style | Strength / weakness |
|---|---|---|---|---|---|
| **Elliptical** (short, rounded, often slotted) | Passerines, sparrowhawk, pheasant, grouse | 4-6 | low-medium | Burst takeoff, tight turns through clutter | Fast roll, explosive acceleration, short glide; costly to sustain |
| **High-speed** (short-medium, pointed, swept, no slots) | Falcons, swifts, ducks, swallows | 6-9 | high | Fast flapping or fast gliding, dives | High top speed, low drag; poor at slow flight, wide turns at low speed |
| **High-AR soaring** (long, narrow, pointed) | Albatross, gannet, gull, shearwater | 10-18 (albatross ~15) | medium-high (albatross up to ~16 kg/m^2 [NASA]) | Dynamic and slope soaring over sea | Best glide ratio (~20+ : 1); poor takeoff (needs a run or headwind), sluggish roll |
| **Slotted high-lift** (broad, long arm wing, splayed primaries) | Eagles, buzzards, hawks, vultures, storks | 6-8 | low-medium | Thermal soaring, slow circling, carrying prey | High lift at low speed, tight thermal circles; slow in a straight line |

Sources: four-type classification and descriptions [WIKI-BW][RBCM]; slotted type with long, broad
arm wings and large area for thermal soaring [DERG].

**Design read:** our bird should *morph* across these classes instead of being stuck in one.
Wings spread wide = slotted/elliptical (slow, floaty, turns tight); half-swept = high-AR glide
(efficient cruise); fully tucked = high-speed (dive). Swifts show the real effect: picking the
right sweep can **halve sink speed or triple turning rate** [LENTINK]. Extended wings win at low
speed and in turns; swept wings win at high speed and are the only way to carry the big loads of
fast gliding [LENTINK].

---

## 2. Skeletal articulation

The wing is a jointed arm: **shoulder** (humerus) -> **elbow** (radius/ulna) -> **wrist**
(carpometacarpus + digits). The primaries attach to the hand. The secondaries attach to the forearm.

### 2.1 Joints and what they do
- **Shoulder:** big ranges in elevation (flap), protraction/retraction (sweep forward/back), and
  pronation/supination (twist, which sets angle of attack). This is the main flap and pitch-trim
  joint.
- **Elbow + wrist are mechanically coupled.** Bending the elbow automatically bends the wrist,
  and straightening one straightens the other, with no extra muscle effort. The classic
  explanation is "drawing parallels": the radius slides along the ulna (Bergmann 1839; Coues 1871; confirmed surgically by Fisher 1957, all as cited in [PUBMED-2017]). A 2017 study
  showed the motion is strongly non-planar and needs the wrist bones in the model; a six-bar
  linkage with a sliding ulnare fits the data [AUTOMATE][PUBMED-2017]. The propatagial tendon
  also helps extend the wrist when the elbow extends [AUTOMATE].
  -> **Gameplay:** a single scalar `fold` can drive elbow and wrist together. That matches the
  anatomy, not just a simplification.
- **Hand / digits:** fine control over how the primaries spread, the span, and the area. A
  pigeon-inspired robot (Stanford PigeonBot) got its span and area control from wrist and
  finger action alone [PIGEON-ROBOT].

### 2.2 Morphing states (continuous, not discrete)
- **Sweep / fold:** gliding pigeons sharply cut span, area and AR as speed rises, which keeps L/D
  near its best up to at least 2x the minimum glide speed [PENNY68]. Folded wings also stiffen,
  so they keep their lift at high speed [WONG25].
- **Dive tuck (falcon stoop):** the shape changes in sequence with speed. The wings make a
  "diamond" up to ~190 km/h, then a tight vertical tuck up to ~240 km/h [PONITZ-PLOS]. Top speed
  uses a teardrop (fully tucked) shape. To aim and to brake slightly, the falcon opens its
  hand-wings sideways into a **cupped** shape [SELIM]. Compared with open wings, the cupped shape
  lowers drag and raises lift [PONITZ-OJFD]. Small feathers pop up where the flow separates [PONITZ-PLOS].
- **Slotted primaries:** splayed tip feathers act as winglets. They spread the tip vortex
  vertically and horizontally, which increases the effective span [TUCKER93]. On a live Harris
  hawk, the induced drag factor was 0.56 with slots vs 1.10 with the tips clipped [TUCKER95].
  -> Slots open at slow speed / high lift and close (feathers overlap) when fast or swept.
- **Alula** (small feathered thumb at the wrist's leading edge): it deploys in slow, high-AoA
  flight such as landing and is usually compared to a leading-edge slat that delays stall
  [ALULA-PRINCETON]. The evidence is mixed. Lee et al. 2015 found it lets birds make **steeper
  descents with bigger changes in body orientation**, but it does not reduce sink speed [LEE15].
  Engineered alulas act like a slat plus a vortex generator, letting the wing sustain higher
  pressure gradients [ITO19][MANDADZHIEV]. It is still open whether birds deploy it actively or
  passively [LEE15].
  -> **Gameplay:** model the alula as "**extra control authority at low speed / high AoA**", not
  "extra lift".

### 2.3 Tail as control surface
- Aerodynamically the tail is a **low-AR delta wing** (Thomas 1993). It is a drag-reducing flap
  and a trim control: **furled at fast cruise** for low drag, **spread at low speed and in
  turns** to cut induced drag and add lift [THOMAS96].
- In a pigeon-tail robot, the force change from spreading came mainly from the extra area, which
  keeps the control simple: force roughly proportional to spread [TAIL-TURB].
- **Twist** (rolling the tail about its long axis): because the tail sits close behind the
  wings, twisting it creates asymmetric lift that gives roll and **proverse yaw**, which helps
  coordinate a banked turn. Twist also adds **nose-up pitch**, which raises the wings' AoA and
  recovers the lift lost when banking [DRONE-TAIL][PHAN24].
- Tail fan + pitch-up = the main **airbrake** at landing (see section 4).

---

## 3. Flap cycle

### 3.1 Downstroke vs upstroke
- **Downstroke** = power stroke. The wing is fully extended (max span), primaries closed into a
  continuous surface, leading edge pitched slightly down. It makes almost all the weight support
  and thrust.
- **Upstroke** = recovery. Nearly all birds except hummingbirds **flex/fold the wing** on the
  upstroke to cut drag and inertia [UPSTROKE-JEB]. There are two styles [UPSTROKE-JEB][UMT]:
  - **Flexed-wing upstroke** (most small/medium birds, e.g. zebra finch): the whole wing is drawn
    in toward the body, the tip moves slowly at mid-upstroke, and it makes essentially no
    aerodynamic force.
  - **Tip-reversal upstroke** (pointed, high-AR wings, e.g. pigeon/dove at slow speed): the hand
    stays extended but supinates and flicks backward. The tip moves fast, and some studies
    measure it making ~14% of the downstroke's net force in a cockatiel [HEDRICK04].
  - The supination comes from the carpometacarpus sliding across the wrist bones [UPSTROKE-JEB].
- Primaries **separate (venetian-blind)** on the upstroke to let air through, then close on the
  downstroke.
- Hummingbirds are the exception. They keep the wing straight and invert it, so the upstroke
  also makes lift (hovering).

### 3.2 Frequency vs body size
- Wingbeat frequency drops with size. Pennycuick's model (1990, and refined since) predicts it
  from mass, span, area, gravity and air density [PENNY-JEB90][PENNY-AUK96]. The 1996 form is
  roughly f ∝ m^(3/8) g^(1/2) b^(-23/24) S^(-1/3) ρ^(-3/8). So with the wing held fixed, a
  heavier bird flaps faster; a longer span or bigger area flaps slower. Across
  real birds (bigger mass comes with longer wings) the net trend is about **f ∝ m^-1/3**
  [PHASIANID-JEB]. A 414-point dataset from swans to hummingbirds confirms it holds across sizes
  [PHYSWORLD].
- Rough reference values (~; general figures, not taken from a single cited source): hummingbird 40-80 Hz; sparrow/finch 12-20 Hz; pigeon 6-9 Hz; crow
  3-5 Hz; hawk/buzzard 3-5 Hz; heron/stork/eagle 2-3 Hz; swan ~3 Hz.
- Birds also **change amplitude and frequency with demand**: highest at takeoff and climb,
  lowest at cruise. Many species use flap-glide or flap-bound (folded ballistic) gaits.

---

## 4. Landing / perching maneuver

Observed in hawks and steppe eagles; it is quite stereotyped [OXF-THESIS][STEPPE][SCIDAILY]:

1. **Approach glide / swoop.** Hawks often **dive below the perch while flapping**, then
   **swoop up** to it with wings spread. Trading speed for height bleeds energy without stalling
   far from the perch. Hawks pick paths that **minimise the distance flown stalled** [SCIDAILY].
2. **Rapid pitch-up.** Body and wings rotate nose-up hard. The wings sweep forward, the
   underwing coverts deploy (phased with the sweep), the alula protracts, and the tail fans and
   pitches down [STEPPE]. This is the main braking event in raptors [OXF-THESIS].
3. **Deep stall.** The wing works at very high AoA as an **airbrake**. Drag is high; lift shows
   no matching peak [OXF-THESIS][CARR10]. Unsteady models suggest pitching up lets the bird keep
   high lift *and* drag together while it decelerates [POLET-JFM].
4. **Feet forward + grab.** The legs swing forward and the feet open to take up the impact.
   For short hops, birds brake by flapping (backward strokes) instead of a pure glide pitch-up
   [OXF-THESIS].

Key insight for us: perching is **energy management**. Arrive low and fast, convert the speed
into height, and arrive at the perch at near-zero airspeed with the wings acting as a parachute.

---

## 5. Gameplay takeaways (parameters and numbers)

### 5.1 Articulation state to model (all floats, smoothed with damped springs)
| Param | Range | Driven by | Rest | Smoothing (time constant) |
|---|---|---|---|---|
| `wing_sweep` (fold) | 0 = fully spread, 1 = tucked | pitch-down input + speed (auto-sweep with speed) + dive key | 0.15 | 0.12-0.20 s |
| `flap_phase` | 0..1 cycle | flap input (space) | - | n/a (procedural) |
| `flap_amplitude` | 0..1 | flap held vs tapped | 0 | 0.08 s |
| `tail_spread` | 0 = furled, 1 = full fan (~120 deg fan arc) | low speed, braking, high AoA, turn rate | 0.3 | 0.10 s |
| `tail_twist` | -1..1 (~ +/-30 deg) | yaw/bank input | 0 | 0.08 s |
| `tail_pitch` | -1..1 (~ +/-25 deg) | pitch input, brake | 0 | 0.08 s |
| `primary_slot` | 0 closed .. 1 splayed (~5-25 deg fingers) | `(1 - wing_sweep) * low_speed_factor` | derived | derived |
| `alula` | 0..1 | AoA > ~12 deg AND speed < ~0.5 * cruise | derived | 0.05 s |
| `brake` (pitch-up flare) | 0..1 | brake input / perch-approach auto-flare | 0 | 0.15 s |
| `legs_forward` | 0..1 | brake + perch within ~3 m | 0 | 0.2 s |

Wire the elbow and wrist from `wing_sweep` together (anatomy couples them; see 2.1). Never expose
them as separate inputs.

### 5.2 How the state maps to flight (tuning starting points)
- **Sweep modulates the aero coefficients** (interpolate spread -> tucked):
  - Effective wing area: 1.0 -> ~0.35. Span: 1.0 -> ~0.45.
  - Lift slope / max CL: 1.0 -> ~0.4. Parasitic drag: 1.0 -> ~0.35.
  - Turn authority (max bank rate, yank rate): 1.0 -> ~0.35. Swifts get ~3x the turn rate when
    spread vs swept [LENTINK], so a **~3:1 turn-authority ratio** is grounded.
  - Glide sink rate at low speed: spread is ~2x better than swept [LENTINK]. Above cruise speed,
    swept gives the better glide, so auto-sweep with speed is "correct".
- **Auto-sweep curve:** `wing_sweep_auto = smoothstep(cruise, 2.0 * cruise, speed) * 0.6`, then
  add the player's pitch-down dive input on top (clamped to 1). This mirrors pigeons shrinking
  span with speed up to 2x the minimum glide speed [PENNY68].
- **Falcon dive sequence:** sweep 0.5-0.7 = "diamond" (a little steerable); sweep >0.85 =
  "teardrop" (max speed, steering ~0.2x). Opening from teardrop into "cupped" (~0.6) gives a
  gentle brake plus precision aim [PONITZ-PLOS][SELIM]. Cap the dive at ~2.5-3x cruise speed so
  it stays readable.
- **Tail:** spread adds lift and drag roughly proportional to area [TAIL-TURB]. Use
  `tail_lift = k * tail_spread * q` with `k` about 10-15% of the wing at the same AoA. Twist
  adds proverse yaw and a nose-up pitch while banking. **Use it to auto-coordinate turns** so a
  mouse bank never needs a rudder key [PHAN24].
- **Alula:** when deployed, raise the stall AoA by ~+5 deg and boost pitch/roll authority by
  ~+25% at low speed. Don't add lift; it is a control aid [LEE15].
- **Slots:** when splayed, cut induced drag at low speed by up to ~40% (Harris hawk factor 0.56
  vs 1.10 [TUCKER95], softened for game balance). This is what makes slow thermal-style circling
  feel floaty.
- **Flap:**
  - Game-scale bird (crow-to-hawk sized) **3-5 Hz** visual cadence. Hold flap -> 4-5 Hz full
    amplitude. Tap -> a single stroke.
  - Thrust impulse only on the downstroke (~60% of the cycle). Upstroke ~0 force, with wings at
    `wing_sweep` ~0.5 (flexed upstroke).
  - Downstroke at sweep 0 with the primaries closed (`primary_slot` 0). Upstroke with the slots
    open.
  - Ramp the flap rate up when slow (takeoff / climb), and allow flap-bounding (brief full
    tuck between strokes) at speed.
- **Perch landing (auto-assist):**
  - Within ~6-8 m of a targeted perch and below ~0.6x cruise speed, ramp `brake` -> 1.
  - On flare: body pitch goes up to ~60-80 deg, `tail_spread` 1, `tail_pitch` down, `alula` 1,
    `wing_sweep` -0.1 (wings *forward* past spread; allow a slight negative), and drag coeff x3-4.
  - Lift held roughly constant (not spiked) through the flare, per the perching studies [OXF-THESIS][CARR10].
  - `legs_forward` 1 within ~3 m. Snap to the perch if relative speed < ~2 m/s.
  - Teach "**dive under, swoop up**" as the skilled approach: arriving fast and converting speed
    into a climb onto the perch should give the cleanest flare [SCIDAILY].

### 5.3 Greybox mesh (body capsule + 2 segments per wing + tail fan)
- **Body:** capsule, length ~1.0 unit, radius ~0.18. Pivot at the center of mass (~40% back
  from the beak).
- **Inner arm segment** (humerus + forearm, carries the secondaries): box ~0.45 long x 0.28 chord
  x 0.03 thick. Hinge = shoulder at the body side, ~30% back from the front of the capsule.
  - Shoulder drives flap elevation (+/-60 deg at full amplitude), sweep back (0 -> ~35 deg at
    sweep 1), and twist/AoA (+/-15 deg).
- **Outer hand segment** (primaries): tapered box/trapezoid ~0.55 long, chord 0.24 -> 0.10 at the
  tip. Hinge = wrist at the end of the inner segment.
  - Wrist fold: 0 -> ~-150 deg (fold back under the arm) at sweep 1.
  - Hand sweep should lead the arm sweep, so the hand folds first; in the swift, the hand does
    most of the sweeping [LENTINK].
  - Upstroke: extra wrist flex of ~40-60 deg (flexed-wing upstroke).
  - Optional 3-5 thin "finger" quads at the tip that rotate apart with `primary_slot`, for the
    slotted look.
- **Alula:** a tiny quad at the wrist's leading edge that rotates forward/up ~20-30 deg with
  `alula`. It is a strong visual cue for "I'm in slow-flight mode".
- **Tail fan:** 5-7 thin quads hinged at a single point at the tail base. They fan out to
  +/-60 deg (total ~120 deg arc) with `tail_spread` and rotate as a group for `tail_pitch` and
  `tail_twist`.
- **Legs:** two thin capsules tucked flat under the body; they rotate forward ~90 deg with
  `legs_forward`.
- **Reading at distance (combat):** silhouette changes carry the state. Spread "plank" = slow
  and agile. Swept "arrow" = fast. Tuck "teardrop" = dive. Splayed fingers + fanned tail = braking.
  Make each one readable at 30+ m. Opponents' perceived state should drive these same params
  (per project guardrail: drive the visuals from received state).

---

## Sources
- [WIKI-BW] Bird wing, Wikipedia: https://en.wikipedia.org/wiki/Bird_wing
- [RBCM] Royal BC Museum, Bird Wing Types: https://learning.royalbcmuseum.bc.ca/wp-content/uploads/2017/12/Bird-Wing-Types2-1.pdf
- [DERG] Wing type classification (Savile), DergiPark: https://dergipark.org.tr/en/download/article-file/2296245
- [SLH] Science Learning Hub, Wing loading: https://www.sciencelearn.org.nz/resources/301-wing-loading
- [NASA] NASA NTRS technical memo (bird wing loading): https://ntrs.nasa.gov/api/citations/19930090809/downloads/19930090809.pdf
- [WB] Wilson Bulletin, hawk wing morphology: https://sora.unm.edu/sites/default/files/journals/wilson/v093n04/p0491-p0499.pdf
- [LENTINK] Lentink D, Müller UK, Stamhuis EJ, et al. 2007, How swifts control their glide performance with morphing wings, Nature 446:1082-1085: https://www.nature.com/articles/nature05733 ; summary: https://physicstoday.aip.org/news/morphing-wings-help-birds-control-gliding
- [AUTOMATE] Vazquez RJ 1994, The automating skeletal and muscular mechanisms of the avian wing (Aves), Zoomorphology 114:59-71, doi:10.1007/BF00574915: https://link.springer.com/doi/10.1007/BF00574915
- [PUBMED-2017] Stowers AK, Matloff LY, Lentink D 2017, How pigeons couple three-dimensional elbow and wrist motion to morph their wings, J R Soc Interface 14:20170224, doi:10.1098/rsif.2017.0224: https://pubmed.ncbi.nlm.nih.gov/28794161/ (full text: https://pmc.ncbi.nlm.nih.gov/articles/PMC5582118/)
- [PIGEON-ROBOT] PigeonBot / feathered morphing wing (MDPI Biomimetics overview): https://mdpi.com/2313-7673/9/9/555 ; primary paper: Chang E, Matloff LY, Stowers AK, Lentink D 2020, Soft biohybrid morphing wings with feathers underactuated by wrist and finger motion, Science Robotics 5:eaay1246, doi:10.1126/scirobotics.aay1246
- [PENNY68] Pennycuick 1968, A wind-tunnel study of gliding flight in the pigeon: https://scilit.com/publications/448c2860dd71f7fd126b473c3f059ca2
- [WONG25] Wong et al. 2025, Wing extension-flexion coupled aeroelastic effects, J. R. Soc. Interface: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12055289/
- [PONITZ-PLOS] Ponitz B, Schmitz A, Fischer D, Bleckmann H, Brücker C 2014, Diving-flight aerodynamics of a peregrine falcon (Falco peregrinus), PLOS ONE 9:e86506: https://pmc.ncbi.nlm.nih.gov/articles/PMC3914994
- [PONITZ-OJFD] Ponitz et al. 2014, cupped-wing CFD: https://openaccess.city.ac.uk/id/eprint/12942/1/2014-PonitzFalke.pdf
- [SELIM] Selim, Gowree, Brucker, The peregrine falcon's dive: pull-out and wing morphing: https://ar5iv.labs.arxiv.org/html/2008.03948
- [TUCKER93] Tucker VA 1993, Gliding birds: reduction of induced drag by wing tip slots between the primary feathers, J Exp Biol 180:285-310: https://scilit.com/publications/0cb2e90ed7bc9c8a041ec08b2d5be9ed
- [TUCKER95] Tucker VA 1995, Drag reduction by wing tip slots in a gliding Harris' hawk, Parabuteo unicinctus, J Exp Biol 198:775-781 (the link is a library index entry, a weak pointer): https://acnpsearch.tweb-dev.unibo.it/singlejournalindex/25807025
- [ALULA-PRINCETON] Princeton BAM lab alula papers: https://bamlab.princeton.edu/_files/ugd/8339e9_9100cd4c8c8348058d2aa59d0a14fc75.pdf
- [LEE15] Lee S, Kim J, Park H, Jabłoński PG, Choi H 2015, The function of the alula in avian flight, Scientific Reports 5:9914: https://www.doi.org/10.1038/srep09914
- [ITO19] Ito et al. 2019, alula-inspired leading-edge device: https://collaborate.princeton.edu/en/publications/the-function-of-the-alula-on-engineered-wings-a-detailed-experime/
- [MANDADZHIEV] Mandadzhiev et al., alula at low Re: https://par.nsf.gov/servlets/purl/10097588
- [THOMAS96] Thomas ALR 1996, Why do birds have tails? The tail as a drag reducing flap, and trim control, J Theor Biol 183:247-253 (the link is a library index entry, a weak pointer): https://acnpsearch.tweb-dev.unibo.it/singlejournalindex/264695
- [TAIL-TURB] Turbulence enhances bird tail aerodynamic performance (2025): https://arxiv.org/html/2512.24168v1
- [DRONE-TAIL] Raptor-informed feathered drone, tail twist (bioRxiv): https://www.biorxiv.org/content/10.1101/2023.12.29.573672.full.pdf
- [PHAN24] Phan HV, Floreano D 2024, A twist of the tail in turning maneuvers of bird-inspired drones, Science Robotics 9:eado3890, doi:10.1126/scirobotics.ado3890: https://api.crossref.org/works/10.1126%2FSCIROBOTICS.ADO3890
- [UPSTROKE-JEB] Kinematics and aerodynamics of avian upstrokes, J Exp Biol 218: https://cob.silverchair.com/jeb/article/218/16/2518/14222/Kinematics-and-aerodynamics-of-avian-upstrokes
- [UMT] Kinematics and aerodynamics of avian upstrokes during slow flight: https://umimpact.umt.edu/en/publications/kinematics-and-aerodynamics-of-avian-upstrokes-during-slow-flight/
- [HEDRICK04] Hedrick et al. 2004, Wing inertia and whole-body acceleration (cockatiel), J Exp Biol 207: https://cob.silverchair.com/jeb/article/207/10/1689/14706/Wing-inertia-and-whole-body-acceleration-an
- [PENNY-JEB90] Pennycuick 1990, Predicting wingbeat frequency, J Exp Biol 150: https://cob.silverchair.com/jeb/article-pdf/150/1/171/2640396/jexbio_150_1_171.pdf
- [PENNY-AUK96] Pennycuick 1996, wingbeat frequency, The Auk 113: https://sora.unm.edu/sites/default/files/journals/auk/v113n01/p0151-p0177.pdf
- [PHASIANID-JEB] Body size and take-off performance in Phasianidae, J Exp Biol 203: https://cob.silverchair.com/jeb/article-pdf/2608202/jexbio_203_21_3319.pdf
- [PHYSWORLD] Simple equation predicts how quickly animals flap their wings: https://physicsworld.com/a/simple-equation-predicts-how-quickly-animals-flap-their-wings/
- [OXF-THESIS] France LA 2019, Mechanics and control of perching flight, DPhil thesis, University of Oxford (hawks brake by pitching up, with high drag and no matching lift peak; flapping brakes on the shortest flights): https://ora.ox.ac.uk/objects/uuid:a439bd30-3916-4fe9-ba06-c65fd1547048
- [STEPPE] Steppe eagle perching, wing-tail morphing in deep stall (ScienceOpen record; refused automated fetches): https://scienceopen.com/document/vid/28814b54-7865-430c-adde-ffdb3e812d2f . The covert, alula and tail claims are in Carruthers AC, Thomas ALR, Taylor GK 2007, Automatic aeroelastic devices in the wings of a steppe eagle Aquila nipalensis, J Exp Biol 210:4136-4149, doi:10.1242/jeb.011197: https://journals.biologists.com/jeb/article/210/23/4136/17202/Automatic-aeroelastic-devices-in-the-wings-of-a . That paper did not measure lift.
- [CARR10] Carruthers AC, Thomas ALR, Walker SM, Taylor GK 2010, Mechanics and aerodynamics of perching manoeuvres in a large bird of prey, Aeronautical Journal 114:673-680 (abstract snippets only: the key to perching is wing and tail morphing into a deep stall, not high-lift aerodynamics)
- [POLET-JFM] Polet et al., unsteady perching aerodynamics, JFM: https://eprints.soton.ac.uk/380552/1/JFMResubmission.pdf
- [SCIDAILY] ScienceDaily 2022, hawks minimise stall when perching: https://sciencedaily.com/releases/2022/06/220630142218.htm ; paper: KleinHeerenbrink M, France LA, Brighton CH, Taylor GK 2022, Optimization of avian perching manoeuvres, Nature 607:91-96, doi:10.1038/s41586-022-04861-4: https://pmc.ncbi.nlm.nih.gov/articles/PMC9259480/ . See `landing_and_takeoff.md` for its numbers.

Note on the references: the full author, title and page details added to [LENTINK], [PONITZ-PLOS], [TUCKER93], [TUCKER95], [THOMAS96], [LEE15] and [PHAN24] are the standard citations, added without re-fetching each paper. [TUCKER95] and [THOMAS96] link only to library index entries. Section 5 numbers are design starting points, not measurements.
