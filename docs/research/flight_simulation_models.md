# Flight Simulation Models: Simple to Complex, and What Flap Should Use

Scope: a third-person 3D bird flight/combat demo in Godot 4 (GDScript). The mouse controls pitch and roll. Space flaps, and also grabs or releases a perch. Turns are bank-and-yank. The player looks for an "ideal glide slope", and the bird stalls if it gets too slow. The goal is a natural feel that is easy to pick up. Maximum realism is not the goal.

Conventions: Godot axes. `basis.x` = right wing, `basis.y` = up (the wing normal), `-basis.z` = nose/forward.
Symbols: rho is air density, S is wing area, m is mass, q = 0.5·rho·v² is dynamic pressure, alpha is angle of attack (AoA), phi is bank angle, gamma is flight-path angle, n is load factor.

---

## 1. Arcade models

These models make no aerodynamic claims. Velocity is derived from (or pulled toward) where the nose points.

**1a. Pure kinematic ("velocity = nose · speed").** Each tick: rotate the body from input, set `velocity = -basis.z * speed`, then change `speed` with throttle or lerp. The KidsCanCode Godot 4 recipes use this pattern: arcade airplane and spaceship controllers lerp pitch, roll and forward speed toward targets each physics frame, then move along the nose ([airplane](https://kidscancode.org/godot_recipes/4.x/3d/simple_airplane/), [spaceship](https://kidscancode.org/godot_recipes/4.x/3d/spaceship/)).
- Pros: it is impossible to lose control, and it responds instantly.
- Cons: there is no AoA, no stall and no energy. It feels like steering a camera, and gravity is cosmetic.

**1b. Energy-based arcade ("speed from altitude").** This is still nose-aligned, but speed follows an energy budget:
`dv/dt = -g·sin(gamma) - k_drag·v² - k_turn·(turn_rate)² + thrust`.
Diving trades height for speed, climbing bleeds speed, and hard turns cost speed. A stall is just `speed < v_min`: control authority drops and the nose falls. A Vintage Story glider mod describes exactly this design. It requires a minimum speed, and climbing, turning and air resistance all drain speed ([Glider Revamp](https://mods.vintagestory.at/gliderrevamp)). The physics underneath is conservation of specific energy, `e = g·h + v²/2`, minus drag losses ([NASA Glenn, energy](https://www.grc.nasa.gov/WWW/k-12/VirtualAero/BottleRocket/BGA/Mike/energy_act.htm)).

**1c. Lagged alignment ("velocity chases the nose").** The velocity *direction* slerps toward the nose at rate k (1/s): `v_dir = v_dir.slerp(nose, 1 - exp(-k·dt))`. A small k gives drift or "mush". A large k feels on-rails. The gap between nose and velocity *is* a pseudo-AoA that you can use for drag and stall. A common bug in naive arcade code is velocity drifting away from the nose with no corrective term ([html5gamedevs thread](https://html5gamedevs.com/topic/44052-arcade-physics-incorrect-velocity-vector-when-trying-to-fly-forward)).

**Shipped-game "feels right" techniques.** These are widely used design patterns. I found no published internals for Pilotwings, Flower or Ace Combat, so treat the game attributions as observations, not documented implementations.
- *Velocity aligns to nose:* the single biggest "it goes where I point" factor. Remove sideslip almost completely, and remove pitch-plane AoA only partly.
- *Auto-coordination:* when the player banks, yaw follows automatically, so no rudder input is needed. Ace Combat's "Standard" control mode goes further: a left/right input becomes an automatic bank-and-turn.
- *Auto-leveling:* with no roll input, the bird eases back to wings-level. Godot community examples damp roll by lerping toward 0 ([Godot forum: auto-leveling](https://forum.godotengine.org/t/how-to-do-auto-leveling-for-arcade-style-airplane-combat-ala-rogue-squadron-3d/22154)).
- *Rate-limited, speed-scaled steering:* turn authority grows with speed, and is capped at high speed by a G limit (see 3b).
- *Pitch/roll clamps:* wingsuit controllers add max-rotation limits to avoid glitches and disorientation ([wingsuit asset notes](https://www.fab.com/listings/c1903b9c-6f4a-428a-a4fa-1185a11b5d2c)).
- *Easy modes:* "A Glider's Journey" ships a "Very Easy" mode with simplified physics on top of its physics model ([store](https://store.steampowered.com/sub/372233/)). This shows that the same game can expose an assist slider.
- *Flap balance:* an itch.io bird prototype notes that "infinite flaps" trivialize the game, so flaps need cost or diminishing returns ([Wing](https://internal-utopia.itch.io/wing)).

---

## 2. Point-mass energy model (lift/drag polar)

The bird is a point with velocity **v**. Its orientation only sets alpha, and forces are summed and integrated.

- Lift: `L = q·S·CL(alpha)`, acting perpendicular to **v** in the plane of the wing normal.
- Drag: `D = q·S·CD`, acting along `-v_hat`.
- Gravity: `m·g` down. Thrust comes from flap impulses (Section 4).
- Lift curve: `CL = CL_alpha·(alpha - alpha0)` up to `alpha_stall` (CL_max). Thin-airfoil theory gives `CL_alpha ≈ 2π`/rad. A finite wing is lower, roughly `2π·AR/(AR+2)`.
- Drag polar: `CD = CD0 + K·CL²`, with `K = 1/(π·e·AR)`. Here e is the Oswald efficiency, about 0.7–0.9 ([Drag polar](https://wiki.riteme.site/wiki/Drag_polar); induced-drag form also in [Roblox DevForum](https://devforum.roblox.com/t/bodylinearvelocity-for-airplanes-aerodynamics/3412855)).

**Glide relations** (unpowered, steady):
- `tan(gamma) = D/L = CD/CL`, so `gamma = atan(1/(L/D))` ([LibreTexts, gliding performance](https://eng.libretexts.org/Bookshelves/Aerospace_Engineering/Fundamentals_of_Aerospace_Engineering_(Arnedo)/07%3A_Mechanics_of_flight/7.01%3A_Performances/7.1.07%3A_Performances_in_gliding)).
- Best glide (max range) is at `CL* = sqrt(CD0/K)`, which gives `(L/D)max = 1/(2·sqrt(K·CD0))` and the flattest glide `gamma* = atan(2·sqrt(K·CD0))`. On the polar plot this is the tangent from the origin ([Drag curve](https://www.wikipedia.com/wiki/Drag_curve)).
- Best-glide speed: `v* = sqrt(2·m·g·cos(gamma*) / (rho·S·CL*))`.
- Minimum sink (max endurance) is at `CL = sqrt(3·CD0/K)`. It is slower than v*, and the glide is steeper.
- Wings-level stall speed: `v_s = sqrt(2·m·g / (rho·S·CL_max))`.

**Trim / "ideal glide".** In a real bird or glider, pitch stability holds a trim AoA. If that trim AoA equals `alpha* = CL*/CL_alpha`, the bird settles at v* on the gamma* path. For the HUD, the "ideal glide slope" is gamma*, a line `atan(1/(L/D)max)` below the horizon. Two things help the player find it:
- the flight-path marker (FPM) relative to that line, and
- current speed relative to v* (scaled by `sqrt(n)` in a turn, see Section 6).

**Designer-friendly parameterization (recommended).** Don't tune rho, S and m. Instead, pick feel targets and back-solve:
- `c = 0.5·rho·S/m` (lumped, in 1/m) `= g / (CL_max · v_s²)`
- `CL* = g / (c · v*²)`, `K = 1/(2·CL*·(L/D)max)`, `CD0 = K·CL*²`, `alpha_stall = CL_max / CL_alpha`

Worked example: v_s = 8 m/s, v* = 14 m/s, (L/D)max = 8, CL_max = 1.4, CL_alpha = 5/rad. This gives:
- c = 0.1095, CL* = 0.457, K = 0.137, CD0 = 0.0286
- alpha_stall ≈ 16°, alpha* ≈ 5.2°
- gamma* = 7.1°, sink rate at best glide ≈ 1.74 m/s

Pros: few parameters, and stall, energy and "pull costs speed" all emerge from `K·CL²`. It is stable and cheap.
Cons: no rotational dynamics, so orientation must be driven directly by input (fine for us).

---

## 3. Rigid-body 6DOF with aerodynamic surfaces

**3a. Per-surface force model.** Each surface (wing halves, tail, fuselage) computes its own local airflow: `v_body + ω × r`. From that it gets local alpha, then lift, drag and pitching moment at its aerodynamic center. The force and torque are summed into a rigid body.
- The best-known Unity example is gasgiant's **Aircraft-Physics** (MIT), based on Khan & Nahon 2015. Each `AeroSurface` has lift slope, zero-lift AoA, stall angles, chord, span, aspect ratio and a flap fraction ([repo](https://github.com/gasgiant/Aircraft-Physics)). (I could not find "JoeBrow/Khaki". This repo and its "Aircraft physics in Unity" video are the closest match.)
- Khan & Nahon use a component-breakdown model that is valid across the full AoA range, including post-stall, and is cheap enough for pilot-in-the-loop real time ([IEEE record](https://manuscript.isc.ac/Inventory/49/720521.htm), [Khan PhD thesis, McGill](https://escholarship.mcgill.ca/downloads/dj52w7317)).
- Pitfalls the repo notes: engine rigid-body drag must be zeroed, and center of mass is hard to place. The model also over-predicted Cessna drag by about 1.5×, so the author scaled thrust to compensate.
- The repo's force code (from memory, not re-verified) averages the force at the current state with the force at a predicted state, for stability. That is a useful trick if you go this route.
- SimpleWings (brihernandez) is a lighter variant: per-wing lift and drag come from editable AnimationCurves ([mirror](https://gitee.com/break0/SimpleWings)).

**3b. Simplified rigid body (vazgriz "Flight Simulator in Unity3D").** Forces are real-ish, but steering is faked ([blog](https://vazgriz.com/346/flight-simulator-in-unity3d-part-1/), [repo](https://github.com/vazgriz/FlightSim)).
- Lift uses a hand-made CL(alpha) curve on velocity projected perpendicular to the span. Induced drag is ∝ CL².
- Parasitic drag has six direction-dependent coefficients.
- Input becomes a *target angular velocity*, reached by clamped torque. There are no control surfaces, so there is no unwanted coupling.
- A G limiter estimates `G ≈ |v × ω|` and scales input down when the limit would be exceeded. With a speed-scaled steering curve, this creates a natural "corner speed".

Pros of 6DOF: emergent weathervaning, spins, wing drop and realistic stall breaks. It is great for sims.
Cons for us:
- Mouse rate control turns into an autopilot/PID problem.
- Small birds have tiny inertia, which means stiff, oscillation-prone dynamics at 60 Hz.
- Every tweak couples into everything else.
- Players "fight" the stability.
- Multiplayer/host determinism is harder.

Use 6DOF only if you want physical tumbling as a feature.

---

## 4. Flapping flight models

**4a. Quasi-steady blade-element (BET).** Split each wing into spanwise strips. Each strip sees `v_body + ω_flap × r`, and its local alpha gives dL and dD from steady coefficients, integrated along the span every sub-step.
- This is the standard research approach: Flappy Hummingbird ([arXiv 1902.09628](https://arxiv.org/pdf/1902.09628)), flapping-robot simulators ([arXiv 2303.04395](https://arxiv.org/abs/2303.04395v1)), and bird studies such as the red-winged blackbird thesis ([Cornell](https://ecommons.cornell.edu/entities/publication/1755d05c-3ccf-44ef-8058-7ce434d8dd59)).
- Known limits: it misses unsteady effects such as the leading-edge vortex and added mass. An MIT comparison found 2D CFD 44% more accurate at small scales ([MIT ICRA 2014](https://smrl.mit.edu/wp-content/uploads/2019/10/icra2014_acomputationaltool.pdf)).
- It needs about 10+ samples per wingbeat. A 5 Hz beat at 60 Hz physics gives only 12. It is also hard to control: thrust depends on stroke timing.

**4b. Data-driven / articulated.** Ju et al. track motion-captured dove wingbeats with a physics controller ([SIGGRAPH/TOG 2013](https://mrl.snu.ac.kr/research/ProjectBird/birdFlight.htm)). It is beautiful and far too heavy for us.

**4c. Cycle-averaged.** Treat flapping as mean thrust T plus a lift boost while flapping is held. It is simple, but it loses the satisfying "beat".

**4d. Flap impulse (game standard).** Each press adds Δv, or a short force pulse, along a direction between up and forward. Hobbyist Unity bird controllers do exactly this, scaling the pulse by flap strength ([Unity forum](https://discussions.unity.com/t/using-physics-to-fly/499921)). We recommend a **pulse over the downstroke**: about 0.15–0.25 s, synced to the animation. It reads physically, is camera-friendly and still responsive. Good details:
- Direction: about `normalize(0.6·nose + 0.8·up)`, tilted forward at speed and more upward when slow.
- Efficacy: `eff = clamp(1 - v/v_flap_max, 0.2, 1)`. Real flapping thrust falls off with speed, and this stops flap-spam from giving unbounded speed.
- Costs: a cooldown or stamina. Small optional rewards for rhythmic timing.
- A flap briefly raises CL_max or clears the stall flag (an "unstick").

---

## 5. Stall, post-stall, perching, landing assists

**Stall.** Above alpha_stall, CL drops and CD rises sharply. A simple, smooth post-stall model blends from CL_max toward flat-plate values over about 10°:
- `CL_fp = C_N·sin(alpha)·cos(alpha)`, `CD_fp = C_N·sin²(alpha)`, with C_N ≈ 1.2–2.0.
- The airflow is then "broken": lower roll/pitch authority, the nose weathervanes down toward the velocity, and flight-path assist turns off.
- Use hysteresis: enter at `alpha > alpha_stall` or `v < 0.9·v_s`. Exit at `alpha < 0.8·alpha_stall` and `v > v_s`.
- Telegraph the stall with buffet (camera shake), feather flutter audio and a HUD AoA band. Don't add random wing-drop in "easy" mode.
- A gameplay stall-indicator bug is common when the stall is keyed only to AoA. Also key it to speed ([bugnet note](https://bugnet.io/blog/how-to-fix-aircraft-stall-not-triggering-at-low-airspeed)).

**Perching = deliberate stall.** Landing birds pitch to very high AoA while decelerating. Polet, Rival & Weymouth measured peak lift and drag at **more than 10×** the quasi-steady values in rapid perching manoeuvres, driven by added mass and separation ([JFM paper, Southampton eprint](https://eprints.soton.ac.uk/380552/1/JFMResubmission.pdf), [Cambridge](https://www.cambridge.org/core/journals/journal-of-fluid-mechanics/article/abs/unsteady-dynamics-of-rapid-perching-manoeuvres/B0CD5CFC7735B9BD3732E98FE11ED02A)). Some species sweep or fold their wings instead ([AvWeb summary](https://www.avweb.com/aviation-news/new-research-suggests-theres-still-a-lot-to-learn-from-birds/)). So an exaggerated "flare brake" (an extra drag multiplier at high alpha near a perch) is *physically motivated*, not just a cheat.

**Forgiving landing recipe:**
1. *Target acquisition:* find the best perch inside a forward cone (about 35°, range 6–10 m), scored by angle × distance. Use raycasts or shape queries in `_physics_process`.
2. *Approach magnetism:* inside `assist_r`, slerp the velocity direction toward the grab point at a rate that grows as distance shrinks. Leave speed to the flare.
3. *Auto-flare:* in the final ~3 m, scale drag up and allow alpha past stall without stall penalties (perch mode).
4. *Capture tolerances:* capture radius 0.8–1.5 m, `speed < v_grab_max` (about 6–8 m/s, generous), approach angle within ±50°.
5. *Input buffering / coyote time:* a grab pressed up to 0.25 s before entering the capture window still counts. Overshooting by less than 0.3 s also still counts.
6. *Latch:* blend position and orientation onto the perch over 0.1–0.2 s with a critically damped spring, not a hard snap.
7. *Release:* the same Space press hops up and forward and gives a free flap, so take-off never stalls.

---

## 6. Bank-and-yank

Lift acts along the wing normal (projected perpendicular to v). Banking by phi tilts lift sideways, and the horizontal component `L·sin(phi)` turns the flight path. To hold altitude, the vertical component must equal the weight, which gives:

- Load factor `n = L/W = 1/cos(phi)`. So 60° bank needs n = 2, and n → ∞ as phi → 90°.
- Level-turn radius `r = v² / (g·tan(phi))`, and turn rate `ω = g·tan(phi) / v` ([St. Olaf soaring](https://stolaf.edu/people/hansonr/soaring/speeds.htm), [aerodynamics4students](https://aerodynamics4students.com/aircraft-performance/manoeuvres.php), [Banked turn](https://wikipedia.classicistranieri.com/en/articles/b/a/n/Banked_turn.html)).
- In terms of n: `tan(phi) = sqrt(n² - 1)`, so `r = v² / (g·sqrt(n² - 1))`.
- Stall speed in a turn: `v_s,turn = v_s·sqrt(n)`. At 60° bank, stall speed rises by 41%.
- Induced drag ∝ CL² ∝ n², so a tight turn bleeds energy fast. This is your "pull back costs speed".

"Yank" means pulling back in a bank. That raises alpha, which raises CL and therefore n. The radius tightens until CL_max (stall) or a soft G cap is reached. In the point-mass model this is fully emergent.

**Bank limits for an easy game:**
- Soft clamp at 70–80°: roll input past the limit is ignored and a spring returns the bank.
- Auto-level when there is no roll input.
- Optional "assisted yank": in a steep bank, add a little back-pressure automatically so the bird doesn't sink. Many arcade games do this.

The vazgriz-style G estimate `|v × ω|` is a cheap way to cap pull rate at high speed.

---

## 7. Numerical integration in Godot `_physics_process`

- Godot physics ticks at a fixed rate, 60 Hz by default (Project Settings → Physics → Common). Turn on **physics interpolation** for smooth rendering at high refresh rates ([Godot docs](https://docs.godotengine.org/en/latest/tutorials/physics/interpolation/physics_interpolation_introduction.html)). For why a fixed step matters (determinism, no explosion from variable dt), see [Fiedler, "Fix Your Timestep!"](https://gafferongames.com/post/fix_your_timestep/).
- Use **semi-implicit (symplectic) Euler**: `v += a·dt` first, then `x += v·dt`. It is stable for oscillatory systems where explicit Euler gains energy ([gamedev.net explanation](https://gamedev.net/forums/topic/702904-projectile-motion-not-behaving-as-expected/?page=1)).
- **Drag overshoot at high AoA:** a flat-plate CD with a big q can make `|D/m|·dt > v`, which reverses the velocity and causes jitter. Clamp the per-step drag Δv to at most 50% of speed. Or use the exact quadratic-drag update `v ← v / (1 + k·v·dt)`, with `k = c·CD`.
- **Lift adds spurious speed:** adding a perpendicular `a_L·dt` grows |v| by `sqrt(1 + (a_L·dt/v)²)`, which is noticeable at low speed. Fix it by applying lift as a *rotation* of v (angle `a_L·dt/v` about the lift-normal axis), which preserves speed.
- **Low-speed singularity:** alpha is undefined as v → 0. Below about 2 m/s, fade aero forces by speed and treat the bird as falling or hovering.
- Read the mouse in `_unhandled_input` (`event.relative`), accumulate it, and consume and clear it in `_physics_process`. Never apply rotation in `_process`.
- Re-orthonormalize the basis every tick. Use `move_and_slide()` on a `CharacterBody3D` (it uses `velocity`) for tree collisions, and keep aero in your own code rather than in a RigidBody3D.
- Optional: 120 Hz ticks or 2 sub-steps if perch-flare forces still jitter.

---

## 8. Recommended hybrid model for Flap

**Pick:** a point-mass energy model (Section 2), with orientation set directly from mouse rates, plus a few tunable assists. Stall, energy and bank-and-yank come from real formulas. Feel comes from assist gains that can be turned down for "expert" play. Skip 6DOF and blade-element flapping.

```gdscript
extends CharacterBody3D
# ---- feel targets (back-solve aero, Section 2) ----
@export var v_stall := 8.0;  @export var v_best := 14.0;  @export var ld_max := 8.0
@export var cl_max := 1.4;   @export var cl_alpha := 5.0;  @export var cn_flat := 1.3
@export var pitch_rate := 2.5;  @export var roll_rate := 4.0      # rad/s at full input
@export var max_bank := deg_to_rad(75.0)
@export var side_align := 6.0   # 1/s: kills sideslip (auto-coordination)
@export var path_align := 0.8   # 1/s: extra velocity->nose pull; keep SMALL so lift dominates
@export var align_cost := 0.15  # speed lost per radian the assist turns v
@export var level_rate := 1.5   # 1/s auto-level when no roll input
@export var flap_dv := 3.5;  @export var flap_time := 0.2;  @export var v_flap_max := 22.0
@export var wing_area := 0.25   # m^2, real S for the HUD only
const G := 9.81
var c: float; var K: float; var cd0: float; var a_stall: float; var a_best: float
var stalled := false; var flap_t := 0.0; var mouse := Vector2.ZERO

func _ready() -> void:
    c = G / (cl_max * v_stall * v_stall)            # 0.5*rho*S/m
    var cl_best := G / (c * v_best * v_best)
    K = 1.0 / (2.0 * cl_best * ld_max);  cd0 = K * cl_best * cl_best
    a_stall = cl_max / cl_alpha;  a_best = cl_best / cl_alpha

func coeffs(a: float) -> Vector2:                   # returns (CL, CD)
    var cl_lin := cl_alpha * a
    var cl := cl_lin
    var cd := cd0 + K * cl_lin * cl_lin
    var over := absf(a) - a_stall
    if over > 0.0:                                  # blend to flat plate over 10 deg
        var t := clampf(over / deg_to_rad(10.0), 0.0, 1.0)
        cl = lerpf(signf(a) * cl_max, cn_flat * sin(a) * cos(a), t)
        cd = maxf(cd0 + K * cl_max * cl_max, cn_flat * sin(a) * sin(a))
    return Vector2(cl, cd)

func _physics_process(dt: float) -> void:
    var b := global_transform.basis
    # 1) ORIENTATION: kinematic rate control (no torques)
    var pitch_in := mouse.y; var roll_in := mouse.x; mouse = Vector2.ZERO
    var auth := 0.5 if stalled else 1.0
    var bank := atan2(-b.x.y, b.y.y)
    if absf(roll_in) < 0.01: roll_in = -bank * level_rate / roll_rate          # auto-level
    if absf(bank) > max_bank and signf(roll_in) == signf(bank): roll_in = 0.0  # bank limit
    b = b * Basis(Vector3.RIGHT, pitch_in * pitch_rate * auth * dt)    # + = nose up
    b = b * Basis(Vector3.FORWARD, roll_in * roll_rate * auth * dt)    # + = right wing down
    # 2) AERO STATE
    var speed := velocity.length()
    var vdir := velocity / maxf(speed, 0.01)
    var vl := b.transposed() * velocity
    var alpha := atan2(-vl.y, -vl.z)                # nose above path => +
    var cf := coeffs(alpha)
    var q := c * speed * speed * clampf(speed / 2.0, 0.0, 1.0)   # fade at very low speed
    stalled = (alpha > a_stall or speed < 0.9 * v_stall) if not stalled \
              else not (alpha < 0.8 * a_stall and speed > v_stall)
    if stalled: b = b * Basis(Vector3.RIGHT, -minf(alpha, 0.6) * 1.5 * dt)  # nose drops
    # 3) FORCES (accelerations)
    var lift_dir := b.x.cross(vdir).normalized()    # perp to v, in wing-normal plane
    var a_lift := q * cf.x
    var acc := Vector3.DOWN * G
    if flap_t > 0.0:
        var fdir := (-b.z * 0.6 + b.y * 0.8).normalized()
        acc += fdir * (flap_dv / flap_time) * clampf(1.0 - speed / v_flap_max, 0.2, 1.0)
        flap_t -= dt
    # 4) INTEGRATE (semi-implicit): lift as rotation (speed-preserving), drag clamped
    velocity += acc * dt
    var axis := vdir.cross(lift_dir).normalized()    # zero if v is along the span
    if speed > 0.5 and axis.is_normalized():
        velocity = velocity.rotated(axis, a_lift * dt / speed)
    var drag_dv := minf(q * cf.y * dt, velocity.length() * 0.5)
    velocity -= velocity.normalized() * drag_dv
    # 5) ASSISTS: kill sideslip, gentle path->nose pull with an energy cost
    speed = velocity.length(); vdir = velocity / maxf(speed, 0.01)
    var nose := -b.z
    var no_side := (vdir - b.x * vdir.dot(b.x)).normalized()
    var d1 := vdir.slerp(no_side, 1.0 - exp(-side_align * dt))
    var k := 0.0 if stalled else path_align
    var d2 := d1.slerp(nose, 1.0 - exp(-k * dt))
    speed *= 1.0 - align_cost * d1.angle_to(d2)
    velocity = d2 * speed
    # 6) COMMIT
    global_transform.basis = b.orthonormalized()
    move_and_slide()

func flap() -> void:
    if flap_t <= 0.0: flap_t = flap_time; stalled = false   # cooldown/stamina elsewhere

func hud_glide() -> Dictionary:
    var horiz := Vector2(velocity.x, velocity.z).length()
    var sink := -velocity.y
    var n := 1.0 / maxf(cos(atan2(-global_transform.basis.x.y, global_transform.basis.y.y)), 0.2)
    var cf := coeffs(_alpha())
    return {
        "gamma": atan2(sink, horiz),               # current path angle (+ = descending)
        "gamma_best": atan(1.0 / ld_max),          # the ideal glide line
        "glide_ratio": horiz / maxf(sink, 0.01),   # achieved (includes accel/decel)
        "aero_ld": cf.x / maxf(cf.y, 1e-4),        # efficiency of current AoA
        "v_best_now": v_best * sqrt(n),            # best-glide speed in this bank
        "v_stall_now": v_stall * sqrt(n),
        "alpha": _alpha(), "alpha_best": a_best, "alpha_stall": a_stall,
        "s_eff": wing_area * absf(global_transform.basis.y.dot(velocity.normalized())),
    }
# _alpha(): same atan2 as step 2. Perch assist (Section 5) runs before step 5 when a target is locked.
```

**Notes on the design:**
- **"Pull back raises path at speed cost":** a higher alpha gives more CL. The lift rotation bends the path upward, and `K·CL²` drag plus climbing against gravity bleeds speed.
- **"Push forward to gain speed":** a lower alpha gives less lift. Gravity then dominates, the bird dives and speed rises, while low CL keeps drag low.
- **Stall:** past alpha_stall, lift collapses and drag spikes. The nose drops and the assists turn off, so recovery is "push forward or flap".
- **Keep `path_align` small (0.5–1.5/s).** Lift should do the real path bending. Otherwise the assist hides AoA and stall. `side_align` can be large because real birds have essentially no useful sideslip. `align_cost` keeps the assist from becoming free energy.
- **Optional auto-trim:** with no pitch input, add `pitch_cmd = k_trim·(a_best - alpha)` (k_trim about 0.5/s). The bird then drifts toward the ideal glide but still rewards a player who finds it faster. Expose it as an assist level.
- **Ideal glide on the HUD:** draw a horizon-relative line at `gamma_best` below the horizon, plus the flight-path marker. Color the AoA tape green near `a_best`, amber toward `a_stall`, red past it. `aero_ld` is better than the achieved glide ratio for "am I efficient now", because the achieved ratio is skewed while accelerating.

**Effective wing area: definition and meaning.** `S_eff = S · |dot(wing_normal, v_hat)| = S · |sin(alpha_eff)|`. This is the wing area *projected onto the plane perpendicular to travel*, the "frontal/blocking" area the air hits.
- At alpha ≈ 0 it is about 0. In a 90° flare it equals S.
- It tracks flat-plate (post-stall) normal force and braking drag, **not lift**. Lift peaks at moderate alpha, where S_eff is only about S·sin(16°) ≈ 0.28 S.
- On the HUD it works as an "air-brake / exposure" meter, ideal for the perch flare. If you want a "lifting area" readout instead, use the span-normal-to-flow projection `S · (1 - (b.x · v_hat)²)`. That drops with sideslip and with wing folding (`S = S_max·fold`) and stays near S in normal flight.
- Label whichever you show clearly. Players will otherwise read "more area = more lift".

---

## Model comparison

| Model | Feel / control | Emergent stall & energy | Tuning effort | Fit for Flap |
|---|---|---|---|---|
| Kinematic arcade (1a) | Instant, on-rails | None | Trivial | Too floaty-free |
| Energy arcade (1b/1c) | Very easy | Faked by rules | Low | Good fallback |
| **Point-mass polar + assists (2 + 8)** | Easy, assist-scalable | Yes (CL/CD) | Low–medium | **Recommended** |
| Simplified rigid body (3b) | Good with rate control | Yes | Medium | Overkill |
| Per-surface 6DOF (3a) | Realistic, harder | Yes, rich | High | Not for v1 |
| Blade-element flapping (4a) | Hard to control | Yes | Very high | No; use 4d pulses |

## Sources
- KidsCanCode Godot recipes: https://kidscancode.org/godot_recipes/4.x/3d/simple_airplane/ , https://kidscancode.org/godot_recipes/4.x/3d/spaceship/
- Godot forum, auto-leveling: https://forum.godotengine.org/t/how-to-do-auto-leveling-for-arcade-style-airplane-combat-ala-rogue-squadron-3d/22154
- html5gamedevs velocity-vs-nose: https://html5gamedevs.com/topic/44052-arcade-physics-incorrect-velocity-vector-when-trying-to-fly-forward
- Vintage Story Glider Revamp: https://mods.vintagestory.at/gliderrevamp
- NASA Glenn energy: https://www.grc.nasa.gov/WWW/k-12/VirtualAero/BottleRocket/BGA/Mike/energy_act.htm
- A Glider's Journey: https://store.steampowered.com/sub/372233/ ; Wing prototype: https://internal-utopia.itch.io/wing ; Wingsuit asset: https://www.fab.com/listings/c1903b9c-6f4a-428a-a4fa-1185a11b5d2c
- Drag polar / drag curve: https://wiki.riteme.site/wiki/Drag_polar , https://www.wikipedia.com/wiki/Drag_curve
- LibreTexts gliding performance: https://eng.libretexts.org/Bookshelves/Aerospace_Engineering/Fundamentals_of_Aerospace_Engineering_(Arnedo)/07%3A_Mechanics_of_flight/7.01%3A_Performances/7.1.07%3A_Performances_in_gliding
- Induced drag form (Roblox DevForum): https://devforum.roblox.com/t/bodylinearvelocity-for-airplanes-aerodynamics/3412855
- gasgiant Aircraft-Physics: https://github.com/gasgiant/Aircraft-Physics ; SimpleWings: https://gitee.com/break0/SimpleWings
- Khan & Nahon 2015: https://manuscript.isc.ac/Inventory/49/720521.htm ; Khan thesis: https://escholarship.mcgill.ca/downloads/dj52w7317
- vazgriz flight sim: https://vazgriz.com/346/flight-simulator-in-unity3d-part-1/ , https://github.com/vazgriz/FlightSim
- Flapping BET: https://arxiv.org/pdf/1902.09628 , https://arxiv.org/abs/2303.04395v1 , https://ecommons.cornell.edu/entities/publication/1755d05c-3ccf-44ef-8058-7ce434d8dd59 , https://smrl.mit.edu/wp-content/uploads/2019/10/icra2014_acomputationaltool.pdf
- Ju et al. data-driven flapping: https://mrl.snu.ac.kr/research/ProjectBird/birdFlight.htm ; Unity flap-impulse thread: https://discussions.unity.com/t/using-physics-to-fly/499921
- Perching (Polet, Rival, Weymouth): https://eprints.soton.ac.uk/380552/1/JFMResubmission.pdf , https://www.cambridge.org/core/journals/journal-of-fluid-mechanics/article/abs/unsteady-dynamics-of-rapid-perching-manoeuvres/B0CD5CFC7735B9BD3732E98FE11ED02A ; AvWeb: https://www.avweb.com/aviation-news/new-research-suggests-theres-still-a-lot-to-learn-from-birds/
- Stall trigger note: https://bugnet.io/blog/how-to-fix-aircraft-stall-not-triggering-at-low-airspeed
- Turn formulas: https://stolaf.edu/people/hansonr/soaring/speeds.htm , https://aerodynamics4students.com/aircraft-performance/manoeuvres.php , https://wikipedia.classicistranieri.com/en/articles/b/a/n/Banked_turn.html
- Godot physics interpolation: https://docs.godotengine.org/en/latest/tutorials/physics/interpolation/physics_interpolation_introduction.html ; Fix Your Timestep: https://gafferongames.com/post/fix_your_timestep/ ; semi-implicit Euler: https://gamedev.net/forums/topic/702904-projectile-motion-not-behaving-as-expected/?page=1
