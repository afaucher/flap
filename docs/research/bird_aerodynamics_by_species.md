# Bird Aerodynamics by Species: Real Data and Gameplay Profiles

Research notes for the third-person bird flight combat demo. There are two parts:
(1) a comparison of real species with sources, and (2) proposed gameplay profiles that are
internally consistent with a simple lift/drag model. The aim is a natural feel, not a validated simulation.

**How to read the numbers.**
- Values with a citation are taken from that source.
- `~` means a typical value taken from general references (ranges in parentheses).
- **est.** means I derived the value: wing area from span and aspect ratio, wing loading
  from mass/area, wingbeat frequency from Pennycuick's benchmark formula (below), and
  stall speed assuming CL_max = 1.6.
- Treat every est. value as accurate to roughly ±25%. Bird mass varies by about 2x within a species
  (sex, season, subspecies). Female raptors and owls are typically 20-50% heavier than males.

---

## 1. Key anchors from the literature

| Finding | Value | Source |
|---|---|---|
| Harris' hawk (0.702 kg, 1.02 m span) gliding in a tilting wind tunnel | L/D_max 10.9; min glide angle 5.0 deg between 8.0 and 14.7 m/s; 8.5 deg at 6.1 m/s; min sink 0.81 m/s; CL_max measured 1.6 (no stall observed) | Tucker & Heine 1990, JEB 149:469 [S1] |
| Laggar falcon gliding in a wind tunnel | L/D_max ~10 at 12.5 m/s, over a 6.6-15.9 m/s range | Tucker & Parrott 1970 [S2] |
| Black vulture (1.79 kg) gliding | Wing polar similar to the falcon's; parasite drag "conventional" | Parrott 1970 [S2] |
| Jackdaw gliding | L/D_max ~12.6 at ~8.5 m/s; span shrinks with speed; tail furled above 9 m/s | Rosén & Hedenström 2001 [S3] |
| Jackdaw drag breakdown | Body drag coefficient ~0.2 with tail folded, >0.4 with tail spread; tail use lowers span efficiency | KleinHeerenbrink et al. 2016 [S3] |
| Common swift gliding | L/D_max 12.5 at 9.5 m/s; min-sink speed 8.1 m/s; best-glide speed 9.4 m/s; parasite CD 0.30-0.22 | Henningsson & Hedenström 2011, JEB 214:382 [S4] |
| White-backed vulture and Andean condor | Glide ratio ~14; polar assumes CL_max 1.6 | Pennycuick 1971; McGahan 1973 (via [S5], [S6]) |
| Peregrine model morphology | 0.528 kg, span 0.873 m, S 0.0897 m^2, AR 8.49, 5.1 Hz, CL_max 1.6, body CD 0.14 | Mills et al. 2018, Table 4 [S7] |
| Starling model morphology | 0.070 kg, span 0.39 m, S 0.0241 m^2, AR 6.4, 10.5 Hz | Mills et al. 2018 [S7] |
| Simulated level and dive maxima | Falcon: 29 m/s level, 123 m/s terminal dive. Starling: 23 / 52 m/s | Mills et al. 2018 [S7] |
| Ideal-falcon vertical dive | 89-112 m/s with CD_par 0.18; 138-174 m/s if CD_par drops to 0.07 | Tucker 1998, JEB 201:403 [S8] |
| Measured dives | Gyrfalcon ~58 m/s (130 mph). Peregrine >160 mph (~72 m/s) reported secondhand | Tucker, Cade & Tucker 1998; Tucker 1999 essay (via [S8], [S9]) |
| Pigeon horizontal flight | Best L/D ~5.9 (flapping, whole-bird); wingbeat ~6-6.7 Hz in slow flight | Pennycuick 1968 [S10] |
| Owl wing loading (15 N. American species) | 0.211-0.545 g/cm^2 (2.1-5.5 kg/m^2); AR 4.84-8.90; males ~18% lower loading | Johnson 1997 [S11] |
| Owl silent flight | Large wings, low wing loading, low AR, low wingbeat frequency, plus feather edge modifications | Bachmann et al. 2011; Jaworski & Peake 2017 review [S12] |
| Red-tailed hawk vs great horned owl | AR 5.61 vs 5.3 | [S13] |
| Common raven | 0.69-2.0 kg, span 1.0-1.5 m, mean chord 0.21 m, flight 9.8-12.5 m/s; barrel rolls, half rolls, inverted flight | [S14], [S15] |
| Barn swallow | Wingbeat frequency U-shaped with speed, minimum at ~8.7-8.9 m/s; tested 4-14 m/s | Park et al. 2001, JEB 204:2741 [S16] |
| Cruise speed scaling (138 species) | Cruise speed ~ m^0.12 and ~ wing loading^0.32. Raptors fly slower than predicted, songbirds faster. Range 8-23 m/s | Alerstam et al. 2007 [S17] |
| Turn radius | R = 2(W/S) / (rho CL sin(bank)); lower wing loading gives a tighter turn | [S18] |

**Wingbeat benchmark (used for the est. Hz values):** Pennycuick 2001 [S19] gives
`f = m^(3/8) g^(1/2) b^(-23/24) S^(-1/3) rho^(-3/8)`. Observed frequencies fall at 0.81-1.05x
this benchmark. Checking it against data: it predicts 5.8 Hz for the Mills peregrine (5.1 measured)
and 9.1 Hz for the starling (10.5 measured), so the est. values are good to about 15%.

---

## 2. Species comparison table

Wing loading: kg/m^2 multiplied by 9.81 gives N/m^2. Speeds are airspeeds in m/s.

| Species | Mass kg | Span m | Wing area m^2 | AR | Wing loading kg/m^2 (N/m^2) | Best L/D (min glide angle) | Min sink m/s | Cruise | Max level | Dive | Stall/min | Flap Hz |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Barn owl | ~0.40 (0.25-0.7) | ~0.90 (0.80-0.95) | ~0.13 est. | ~6.2 est. | ~3.1 (30) est. (Johnson range low end) | ~8-10 est. (~6 deg) | ~0.7 est. | ~5-8 (quartering, slow) | ~15 est. | n/a | ~5.5 est. | ~3-4.5 est. (low by design) |
| Great horned owl | ~1.4 (0.9-2.5) | ~1.22 (0.91-1.53) | ~0.28 est. | 5.3 [S13] | ~5.0 (49) est. | ~8-10 est. | ~0.9 est. | ~8-11 | ~18 est. | short powered stoops | ~7 est. | ~3-4 est. |
| Red-tailed hawk | ~1.1 (0.7-1.5) | ~1.24 (1.14-1.33) | ~0.27 est. | 5.61 [S13] | ~4.0 (39) est. | ~11 (5.0 deg), by analogy with Harris' hawk [S1] | ~0.8 [S1 analog] | ~9-13 (soars; glides 8-15) | ~20 est. | ~35-50 (stoop to prey) est. | ~6.1 [S1 low end] | ~3-4 est. |
| Peregrine falcon | 0.53 (m) to 1.0 (f) | 0.87 [S7] | 0.090 [S7] | 8.49 [S7] | 5.9 (58) | ~10 (5.7 deg) [S2 laggar] | ~1.0 est. | ~12-18 | 29 (sim) [S7] | 58-72 measured; 89-112 ideal [S8] | ~7.7 est. | 5.1 [S7] |
| American crow | ~0.45 (0.32-0.62) | ~0.92 (0.85-1.0) | ~0.145 est. | ~5.8 est. | ~3.1 (30) est. | ~12 (4.6 deg), by analogy with jackdaw [S3] | ~0.6 est. | ~12-13 (46 km/h field) | ~18 est. | n/a | ~5.6 est. | ~4 est. |
| Common raven | ~1.2 (0.7-2.0) | ~1.30 (1.0-1.5) | ~0.30 est. | ~5.6 est. | ~4.0 (39) est. | ~12 est. | ~0.7 est. | 9.8-12.5 [S14] | ~18 [S15] | aerobatic dives | ~6.3 est. | ~3.6 est. |
| House sparrow | ~0.030 (0.024-0.039) | ~0.24 | ~0.0095 est. | ~6.1 est. | ~3.2 (31) est. | ~4-6 est. (low Re) | ~1.2 est. | ~9-11 | ~11 (25 mph, secondary) | n/a | ~5.6 est. | ~12-14 |
| Barn swallow | ~0.019 (0.017-0.025) [S16] | ~0.33 | ~0.0125 est. | ~8.7 est. | ~1.5 (15) est. | ~8-10 est. | ~0.6 est. | 8-10 (U-curve min ~8.8) [S16] | ~14+ | n/a | ~3.9 est. | ~7-8 est.; 2.5-8.5 effective incl. bounds |
| Common swift | ~0.045 | 0.42-0.48 | ~0.017 est. | ~11 est. | ~2.65 (26) est. | 12.5 (4.6 deg) [S4] | ~0.7 (at 8.1 m/s) [S4] | 8-10 [S4] | ~25-30 (screaming parties) est. | n/a | ~5 est. | ~7-9 est. |
| Rock pigeon | ~0.40 | ~0.66 | ~0.065 est. | ~6.7 est. | ~6.2 (60) est. | ~6 flapping [S10]; ~7-8 gliding est. | ~1.4 est. | ~15-20 | ~25 | n/a | ~7.8 est. | 6-6.7 [S10] |
| White-backed vulture (soarer reference) | ~5.4 | ~2.2 | ~0.69 | ~6.9 | ~7.8 (76) | ~14-15 (~4 deg) [S5][S6] | ~0.9-1.0 est. | 10-18 (glide) | n/a (soars) | n/a | ~8.8 est. | ~2.9 est. |

*Vulture morphology (5.38 kg, 2.18 m, 0.69 m^2) is from my memory of Pennycuick 1971 [S5]
and was not re-checked against the paper (the PDF refused automated fetches). Tucker 1991 [S20] gives a
typical span of 2.2 m and mass of 5.4 kg for this species, which agrees. Treat the area as ~ quality.*

### Special traits (qualitative)
- **Owls (barn, great horned):** Very low wing loading and large, highly cambered wings give slow,
  buoyant, low-stall-speed flight with a low wingbeat frequency. Serrated leading edges, fringed
  trailing edges and a velvety surface suppress noise [S12]. Barn owls quarter about 1-3 m above
  ground at walking-to-jogging airspeeds. Owls are poor at sustained high speed because a high-camber
  wing has high profile drag, so they do not stoop like falcons. Great horned owls are much heavier
  for their span (~5 kg/m^2), so they are faster and more powerful but less floaty.
- **Red-tailed hawk:** A broad, slotted, low-AR (~5.6) soaring wing. It is efficient at thermal
  circling at low speed and has a small turn radius for its size. It flaps sparingly and
  slowly. Its best glide (L/D ~11) is good but not exceptional; tail spread trades drag for lift and
  pitch control [S1][S3].
- **Peregrine falcon:** High aspect ratio (8.5), pointed and swept, with high wing loading (~6 kg/m^2).
  Its stoop progressively tucks the wings (cupped, then fully tucked), which cuts drag area and lets
  speed climb well past level-flight maximum. The pull-out is load-limited: the model in [S7]/[S8]
  cites more than 18 g. It is a poor slow flier, with a high stall speed for its size and a wide turn
  radius at low speed.
- **Crows and ravens:** A generalist wing (AR ~5.6-5.8, ~3-4 kg/m^2) with a good glide (jackdaw
  L/D 12.6). They are exceptionally agile, rolling, flying inverted and tumbling [S15]. Their rowing
  wingbeat is steady and rather slow. Ravens soar, but American crows rarely do.
- **Sparrows and finches:** Small birds have a poor glide ratio because the low Reynolds number
  raises profile drag. Fast wingbeats, often bounding flight (flap bursts with folded-wing ballistic
  hops), and very high roll and pitch agility make up for it. Effective L/D is low (~4-6).
- **Swallows and swifts:** Swifts have a very high AR (~11), low wing loading, and morph their wings
  by sweeping back at speed. Swift L/D of 12.5 is excellent for a 45 g bird [S4], and swifts are
  efficient enough to stay airborne for months. Swallows are slower and more acrobatic than swifts,
  with forked tails for tight turns.
- **Pigeon:** High wing loading for its size and a powerful pectoral muscle. It is fast and steep
  climbing, takes off almost vertically with a loud wing clap, and glides only so-so.
- **Vulture (reference):** Its large size and broad slotted wings give the best glide in the set
  (L/D ~14-15) at a moderate sink rate. It almost never flaps once airborne. This is the "sailplane"
  end of the spectrum.

**Spectrum summary:** In this set, wing loading only spans about 1.5-8 kg/m^2, so stall speeds
cluster at **4-9 m/s** for all species. The real differences between species come from **L/D
(4-15), aspect ratio (5-11), how much thrust the bird can produce, and agility**. Do not try to
separate the birds mainly by stall speed.

---

## 3. Flight model used for the profiles

The model is a fixed wing per bird, with lift and drag referenced to wing area S:

```
L = 0.5 * rho * v^2 * S * CL
D = 0.5 * rho * v^2 * S * (CD0 + K * CL^2)      rho = 1.225 kg/m^3, g = 9.81
K = 1 / (pi * e * AR)
```

In steady glide, the best glide occurs where CD0 = K CL^2:
```
CL*        = sqrt(CD0 / K)
(L/D)max   = 1 / (2 sqrt(CD0 K))
gamma_min  = atan(1 / (L/D)max)
V_bg       = sqrt(2 (W/S) / (rho CL*))
CL_minsink = sqrt(3) CL*  (capped at CL_max),  V_ms = V_bg / 3^(1/4),  (L/D)_ms = 0.866 (L/D)max
V_stall    = sqrt(2 (W/S) / (rho CL_max))
```

**Design-target inversion.** We pick the feel targets (L/D)max and CL*, then solve for drag:
```
CD0 = CL* / (2 (L/D)max)          K = 1 / (2 (L/D)max CL*)          e = 1 / (pi AR K)
```
This guarantees the glide angle and best-glide speed you designed. AR stays near the real bird's
value, and the "Oswald" e absorbs body and tail losses. A low e (0.55-0.65) is legitimate for small,
low-Reynolds-number birds and for the falcon's compact planform.

**Worked example (Hawk):** m = 1.2 kg and S = 0.28 m^2 give W/S = 42.0 N/m^2. With targets L/D 12
and CL* 0.70, CD0 = 0.70/24 = 0.0292 and K = 1/(24 x 0.70) = 0.0595. At AR 6 that gives e = 0.89.
V_bg = sqrt(2 x 42.0 / (1.225 x 0.70)) = 9.9 m/s and gamma = atan(1/12) = 4.8 deg.
V_stall = sqrt(2 x 42.0 / (1.225 x 1.6)) = 6.5 m/s.

**Flap model (discrete impulse on Space).** Each flap adds impulse J along the body-forward/up
thrust vector, and flaps repeat at most every T_flap seconds while Space is held. J is derived from a
designed sustained climb at cruise speed (V_cr = 1.25 V_bg):
```
T_avg = D(V_cr) + W sin(gamma_climb)        J = T_avg * T_flap        dv_per_flap = J / m
```
Above V_cr, scale thrust as T_avg * V_cr / v (constant power). This mirrors the torque-limited
thrust threshold in Mills et al. [S7], and it gives a natural top speed in level flight instead of
endless acceleration.

**Dive and tuck.** With spread wings and CL near 0, theory allows terminal V = sqrt(2W/(rho S CD0)),
which is unrealistically high because real birds partially fold or brake. Give each bird a
**V_ne** (never-exceed speed). Above it, spread wings add brake drag, which feels like the bird
flinching. Tuck (an input such as a hold-modifier, or automatic below -45 deg pitch) swaps the
wing polar for a body-only drag area CdA_tuck, with terminal V_t = sqrt(2W/(rho CdA_tuck)), and
disables lift and flap.

**Turning.** Bank-and-yank turning is limited by load factor n_max = L/W. The corner speed is
V_c = V_stall sqrt(n_max) and the minimum turn radius is R_min = V_c^2 / (g sqrt(n_max^2 - 1)).
The pitch-rate cap below is set near the physics value g n_max / V_c.

---

## 4. Proposed gameplay bird profiles

**Scaling notes, for gameplay:**
- **Sparrow mass is doubled** (0.06 kg against a real 0.03 kg) and its span is scaled to 0.33 m, so it
  reads in a tree arena. Wing loading stays real-ish, so the speeds are unchanged.
- **Sparrow L/D is raised** from about 4-6 to 6.5, so gliding is not a brick.
- **Falcon wing loading is raised** to about 7.5 kg/m^2 (real ~5.9) to separate it from the other
  birds: a faster best-glide speed and a higher stall speed. Falcon tuck terminal speed is
  **reduced** to 70 m/s (real ~90-110) so arena collisions stay readable.
- The owl is a barn owl and great horned owl blend (0.8 kg, 3.6 kg/m^2). The hawk is a slightly
  scaled red-tail (1.2 kg, 1.3 m span).
- Load factors and roll rates are game values chosen for feel. Real small birds and falcons exceed
  them; the starling model in [S7] averages n ~3.4, and falcons pull more than 10 g.
- If the arena feels too slow, scale all **masses by k^2 with S fixed**. Every speed then scales by
  k while glide angles, CL, and L/D stay unchanged. For example, k = 1.2 gives speeds +20%.

### 4a. Aerodynamic inputs and derived glide numbers

| Param | Owl | Hawk | Falcon | Crow | Sparrow |
|---|---|---|---|---|---|
| Mass m (kg) | 0.80 | 1.20 | 0.80 | 0.55 | 0.06 |
| Wing area S (m^2) | 0.22 | 0.28 | 0.107 | 0.16 | 0.018 |
| Span b (m) = sqrt(AR S) | 1.10 | 1.30 | 0.93 | 0.96 | 0.33 |
| Aspect ratio AR | 5.5 | 6.0 | 8.0 | 5.8 | 6.0 |
| Wing loading kg/m^2 (N/m^2) | 3.6 (35.7) | 4.3 (42.0) | 7.5 (73.3) | 3.4 (33.7) | 3.3 (32.7) |
| Target (L/D)max | 9.0 | 12.0 | 10.5 | 10.0 | 6.5 |
| Target CL* (best glide) | 0.85 | 0.70 | 0.75 | 0.75 | 0.80 |
| CD0 (derived) | 0.047 | 0.029 | 0.036 | 0.038 | 0.062 |
| K (derived) | 0.065 | 0.060 | 0.064 | 0.067 | 0.096 |
| Oswald e (implied) | 0.89 | 0.89 | 0.63 | 0.82 | 0.55 |
| CL_max | 1.9 (owl camber) | 1.6 | 1.4 | 1.7 | 1.5 |
| **Best-glide angle (deg)** | **6.3** | **4.8** | **5.4** | **5.7** | **8.7** |
| Best-glide speed V_bg (m/s) | 8.3 | 9.9 | 12.6 | 8.6 | 8.2 |
| Min-sink speed / sink (m/s) | 6.3 / 0.81 | 7.5 / 0.72 | 9.6 / 1.06 | 6.5 / 0.75 | 6.2 / 1.10 |
| **Stall speed (m/s)** | **5.5** | **6.5** | **9.2** | **5.7** | **6.0** |
| Cruise V_cr = 1.25 V_bg | 10.3 | 12.4 | 15.8 | 10.7 | 10.2 |

### 4b. Flap, dive, and handling

| Param | Owl | Hawk | Falcon | Crow | Sparrow |
|---|---|---|---|---|---|
| Design climb angle at cruise (deg) | 12 | 8 | 14 | 15 | 25 |
| Avg max thrust T_avg (N), T/W | 2.59, 0.33 | 2.72, 0.23 | 2.72, 0.35 | 1.99, 0.37 | 0.348, 0.59 |
| **Flap cooldown T_flap (s), rate** | **0.40 (2.5 Hz)** | **0.45 (2.2 Hz)** | **0.20 (5 Hz)** | **0.28 (3.6 Hz)** | **0.08 (12.5 Hz)** |
| **Flap impulse J (N s)** | **1.04** | **1.22** | **0.544** | **0.557** | **0.0279** |
| dv per flap (m/s) | 1.30 | 1.02 | 0.68 | 1.01 | 0.46 |
| Climb rate at cruise, full flap (m/s) | 2.2 | 1.7 | 3.8 | 2.8 | 4.3 |
| Max level speed, power-limited (m/s) | 15.7 | 18.4 | 25.9 | 17.7 | 17.1 |
| V_ne, spread wings (m/s) | 25 | 30 | 35 | 28 | 22 |
| Tuck CdA (m^2) / terminal (m/s) | 0.0125 / 32 | 0.0109 / 42 | 0.00262 / 70 | 0.0061 / 38 | 0.00123 / 28 |
| Max load factor n_max | 3.0 | 2.5 | 6.0 | 4.0 | 5.0 |
| Corner speed V_c (m/s) / min turn radius (m) | 9.6 / 3.3 | 10.4 / 4.8 | 22.7 / 8.8 | 11.4 / 3.4 | 13.3 / 3.7 |
| **Max bank (deg)** | **75** | **65** | **85** | **unlimited (barrel rolls)** | **85** |
| **Roll rate (deg/s)** | **180** | **120** | **240** | **320** | **420** |
| **Pitch rate cap (deg/s)** | **175** | **135** | **150** | **200** | **210** |
| Signature trait | Silent: halve the audio and sensor detection radius; best low-speed turn; perches easily | Best glide and soar; wide, stable, forgiving; weak flap | Tuck stoop to 70 m/s, 6 g pull-out; poor slow flight, needs a run-up to perch | Most agile; inverted flight; good glide; average at everything else | Burst flapper and fastest climber; poor glide; bounding flight (flap bursts, then fold) |

### 4c. Implementation hints
- **Perch approach:** Allow a short "flare" (tail spread and alula) of +0.3 CL_max for 0.5 s with extra
  drag. This lets the falcon (9.2 m/s stall) land without needing a runway.
- **Wing morphing:** Lerp S and AR down with speed (sweep), as jackdaws and swifts do [S3][S4]. For
  example, S at V_ne is 0.7 x S. This flattens the drag curve at high speed and gives each bird a
  wider usable speed band.
- **Glide-slope cue:** Show the player the ideal glide pitch, which is -gamma_min from the table
  (about 5-9 deg nose-down). It is the "free speed" attitude.
- **Fairness:** Wing loading is close for every bird except the falcon, so the arena layout (perch
  spacing about 10-20 m, at least 4 m clear around trunks) works for all of them. The falcon's
  8.8 m turn radius is its main weakness in tight canopy.
- **Networking (per AGENTS.md):** These parameters live in the host's simulation data model only.
  Client UI shows perceived state from `receive_perceived_state` and never reads these constants directly.

---

## 5. Sources

- [S1] Tucker & Heine 1990, *Aerodynamics of gliding flight in a Harris' hawk*, JEB 149:469-489. https://cob.silverchair.com/jeb/article-pdf/3284090/jexbio_149_1_469.pdf, https://scholars.duke.edu/individual/pub919673
- [S2] Tucker VA, Parrott GC 1970, *Aerodynamics of gliding flight in a falcon and other birds*, JEB 52:345-367 (laggar falcon); Parrott 1970, *Aerodynamics of gliding flight of a black vulture*, JEB 53:363. https://cob.silverchair.com/jeb/article/53/2/363/21469/Aerodynamics-of-Gliding-Flight-of-a-Black-Vulture
- [S3] Rosén & Hedenström 2001, *Gliding flight in a jackdaw: a wind tunnel study*, JEB. https://www.lunduniversity.lu.se/lup/publication/f405ca38-d3cc-4afe-9223-dd2e4eaaa312 ; KleinHeerenbrink, Warfvinge & Hedenström 2016, JEB 219:1572. https://cob.silverchair.com/jeb/article-pdf/219/10/1572/1916162/jeb132480.pdf
- [S4] Henningsson & Hedenström 2011, *Aerodynamics of gliding flight in common swifts*, JEB 214:382. https://cob.silverchair.com/jeb/article-split/214/3/382/33508/Aerodynamics-of-gliding-flight-in-common-swifts , https://lup.lub.lu.se/record/1777556
- [S5] Pennycuick 1971, *Gliding flight of the white-backed vulture Gyps africanus*, JEB 55:13. https://cob.silverchair.com/jeb/article-pdf/55/1/13/2388835/jexbio_55_1_13.pdf
- [S6] Akos et al., *Thermal soaring flight of birds and unmanned aerial vehicles* (cites glide ratio 14 for the vulture and condor). https://arxiv.org/pdf/1012.0434
- [S7] Mills, Hildenbrandt, Taylor & Hemelrijk 2018, *Physics-based simulations of aerial attacks by peregrine falcons...*, PLoS Comput Biol (Table 4 morphology). https://pmc.ncbi.nlm.nih.gov/articles/PMC5896925/
- [S8] Tucker 1998, *Gliding flight: speed and acceleration of ideal falcons during diving and pull out*, JEB 201:403. https://scilit.net/publications/92269e2167f93eca0d5de8e50066447a , https://scholars.duke.edu/person/vtucker/publications
- [S9] Tucker 1999 essay quoted on MOU-net (gyrfalcon 130 mph; peregrine >160 mph, secondhand). https://moumn.org/archive/mou-net/2003-October/001359.html
- [S10] Pennycuick 1968, *Power requirements for horizontal flight in the pigeon*, JEB 49:527. https://cob.silverchair.com/jeb/article-pdf/49/3/527/2374318/jexbio_49_3_527.pdf , https://scilit.net/publications/3e94361f509614788fadf4acd9820abc
- [S11] Johnson 1997, *Wing loading in 15 species of North American owls*. https://research.fs.usda.gov/treesearch/15634
- [S12] Bachmann et al. 2011, *The barn owl wing: an inspiration for silent flight* (SPIE). https://journals.spiedigitallibrary.org/conference-proceedings-of-spie/7975/79750N/The-barn-owl-wing--an-inspiration-for-silent-flight/10.1117/12.882703.full ; owl wing review (Interface Focus 2017). https://pmc.ncbi.nlm.nih.gov/articles/PMC5206597
- [S13] Red-tailed hawk / great horned owl AR comparison and soaring notes (search summary; primary source not verified). https://pmc.ncbi.nlm.nih.gov/articles/PMC4146594
- [S14] Raven-inspired robotics paper (mass, span, chord, flight speed). https://core.ac.uk/download/56111567.pdf
- [S15] Raven aerobatics: https://www.eastsideaudubon.org/corvid-crier/2018/1/common-raven , https://www.tn.gov/twra/wildlife/birds/forest-birds/common-raven.html
- [S16] Park, Rosén & Hedenström 2001, *Flight kinematics of the barn swallow over a wide range of speeds*, JEB 204:2741. https://cob.silverchair.com/jeb/article-pdf/204/15/2741/1238033/2741.pdf
- [S17] Alerstam et al. 2007, *Flight speeds among bird species: allometric and phylogenetic effects*, PLoS Biol 5:e197. https://journals.plos.org/plosbiology/article/info:doi/10.1371/journal.pbio.0050197
- [S18] Wing loading and turn radius. https://en.wikipedia.org/wiki/Wing_loading
- [S19] Pennycuick 2001, *Speeds and wingbeat frequencies of migrating birds compared with calculated benchmarks*, JEB 204:3283. https://research-information.bris.ac.uk/en/publications/speeds-and-wingbeat-frequencies-of-migrating-birds-compared-with-/
- General mass and span ranges: Wikipedia and Cornell species accounts (great horned owl https://www.wikipedia.com/wiki/Great_horned_owl ; American crow https://wikiwand.com/en/articles/American_crow). House sparrow wingbeat and speed figures come from a secondary encyclopedia (https://www.DavidDarling.info/encyclopedia/S/sparrow.html) and are unverified.

- [S20] Tucker 1991, *The Auk* 108:1-7 (typical span and mass of the white-backed vulture; seen via search summary). https://sora.unm.edu/sites/default/files/journals/auk/v108n01/p0001-p0007.pdf

**Weak or unverified sources:**
- [S13]: the red-tailed hawk and great horned owl aspect ratios come from a search summary; the primary source was not identified.
- [S9]: the peregrine dive speed is secondhand, from a mailing-list quote of a Tucker essay.
- [S15]: Audubon chapter and state-agency pages; fine for behaviour, not for numbers.
- The house sparrow wingbeat and speed figures come from a secondary encyclopedia.
- The American crow "46 km/h field" cruise speed and the falcon's "more than 18 g" pull-out have no recorded source.

**Known gaps:** I could not read the per-species values in Johnson 1997 (scanned PDF), the Pennycuick
2001 species table, or the Usherwood 2020 owl and goshawk L/D numbers. The owl, crow, and sparrow wing
areas are estimates. If precision matters later, these primary sources are worth pulling. For a
game-feel model, the ±25% uncertainty is well inside the tuning range.
