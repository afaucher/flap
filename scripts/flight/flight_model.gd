class_name FlightModel
extends RefCounted
## Point-mass flight with an attitude state, no rigid-body torques (docs/design/flight_model.md).
##
## The bird's attitude is two numbers relative to its own flight path: angle of attack `alpha` (nose above
## the path) and bank `bank` (roll about the path). The stick commands both; they slew toward the command at
## the profile's rates. So the bird is always coordinated (no sideslip), never tumbles, and "neutral stick"
## is the best-glide angle of attack: let go of the mouse and it settles onto its ideal glide slope. With flap held,
## neutral stick eases over to the climb trim instead (climb_alpha: the fastest steady climb no slower than best glide).
##
## Forces: lift L = q S CL(alpha) along the lift vector (perpendicular to the path, tilted by bank), drag
## D = q S (CD0 + K CL^2 + stall drag) against the path, gravity, flap thrust during a downstroke.
## Pull back -> more CL -> the path curves up and induced drag bleeds speed. Push -> less CL -> the path
## drops and speed builds; past half push the wings tuck (less area, span and parasitic drag: a stoop).
## Bank tilts the lift vector so the path curves sideways; pulling in a bank tightens it (bank-and-yank).
##
## Integration (semi-implicit, per physics tick): lift turns the velocity (a speed-preserving rotation by
## a_L dt / V, which stays stable at low speed), then drag, gravity and thrust are added as accelerations.
##
## Moving air (`wind`, AirField's at the bird): the tick is flown in the air's frame -- the velocity through the air
## is what the wing feels, so speed, path angle, the flight direction and the lift vector are all through the air --
## and the air's own velocity carries the bird over the ground. In rising air the bird keeps its glide through the
## air and rises with it: a thermal stronger than its sink rate lifts it. `velocity` outside step() is over the ground,
## and so are `path_angle` and flight_dir() (where the bird is going: what a pilot, the AI or the HUD steers by);
## `speed`, the angle of attack and the body are through the air.

const UP := Vector3.UP

var profile: BirdProfile
var energy: EnergyModel

# --- State -----------------------------------------------------------------------------------------
var position := Vector3.ZERO
var velocity := Vector3.ZERO
var alpha := 0.0            ## rad, angle of attack
var bank := 0.0             ## rad, + is right wing down
var fold := 0.0             ## 0 spread .. 1 tucked
var flap_time := 0.0        ## s left in the current downstroke
var flap_cooldown := 0.0    ## s until the next wingbeat may start
var flap_strength := 0.0    ## strength of the current downstroke
var flap_phase := 0.0       ## 0..1 through the wingbeat (visual)
var flap_count := 0
var stalled := false
var flare := 0.0            ## 0..1 extra airbrake from the perch assist (visual + drag)
var extra_accel := Vector3.ZERO  ## world-space push this tick (arena boundary)
var ground_height := INF        ## m from the bird's underside to the ground below (set by the Bird each tick)
var wind := Vector3.ZERO        ## m/s, the air's velocity where the bird is (set by the Bird each tick: AirField)
## Battle damage: the share of each wing's area its lost flight feathers took (x left, y right; Bird.lose_feathers).
## The wings lose that lift, and the weaker wing drops: the bird rolls toward it unless the stick holds it level.
var lift_scale := 1.0       ## 0..1 of the wing's lift that's working (a downed bird's flailing wings: Bird.tumble)
var wing_loss := Vector2.ZERO
const LOSS_ROLL := 1.0          ## bank the stick must hold off, as a share of max bank per unit of loss difference

# --- Assists (0 turns one off) ---------------------------------------------------------------------
## Phugoid damper: alpha rises by this * 2 alpha* * (along-path acceleration / g), so the speed-for-height
## bob dies out (1 is about 0.7 of critical damping). It fades out as the stick leaves neutral.
var pitch_damping := 1.0
var turn_assist := 0.6      ## share of the extra lift a bank needs that is added automatically
var auto_sweep := 0.35      ## wing tuck at twice best-glide speed, with no push at all

# --- Flapping trim (part of the stick's mapping, not an assist) ------------------------------------
## Neutral stick is best glide only while gliding. With flap held it slides over to `climb_alpha`, the angle of attack
## of the fastest steady climb on the wing no slower than best-glide speed (best_climb(); docs/design/flight_model.md,
## "Flapping trim"), and back to best glide when the wingbeats stop. The slide eases at FLAP_TRIM_TIME both ways, so
## neither the first wingbeat nor letting go jerks the nose.
const FLAP_TRIM_TIME := 0.4         ## s, time constant of the slide between the glide and the climb trims
## The climb trim flies no slower than this times best-glide speed. The fastest climb of all (Vy) is slower, 1.0-1.3x
## the stall speed, but only 2-9% faster: there letting go dives the bird to the edge of the stall, a turn stalls it,
## and an AI that flaps when slow stays slow and flaps itself out.
const CLIMB_MIN_SPEED := 1.0
## ... and keeps its angle of attack under this share of the one that would tip a flapping climb off the wing into a
## stalled, hovering one (only the sparrow, whose wingbeat lifts more than its weight when slow, comes near it).
const CLIMB_ALPHA_MARGIN := 0.9
var climb_alpha := 0.0      ## rad, neutral stick's angle of attack with full-strength wingbeats held
## 0 .. 1: how far neutral stick has slid to climb_alpha: the held wingbeats' strength, eased (a weak, tired
## wingbeat trims only part of the way: its best climb is near the glide's).
var flap_trim := 0.0
var _duty := -1.0           ## flap_duty(), once worked out

# --- Outputs (read by the HUD, camera, rig) --------------------------------------------------------
var lift_dir := UP
var speed := 0.0
var path_angle := 0.0       ## rad, + climbing (over the ground)
var cl := 0.0
var cd := 0.0
var load_factor := 1.0      ## lift / weight
var wing_area_eff := 0.0    ## m^2, planform area after the tuck
var frontal_area := 0.0     ## m^2, wing area facing the oncoming air: S_eff |sin alpha| (airbrake)
var lift_to_drag := 0.0
var ground_effect := 0.0    ## 0 (clear of the ground) .. 1 (on it)

var _last_drag_accel := 0.0
var _last_dir := Vector3.FORWARD     ## the direction through the air (the wing's, the body's)
var _ground_dir := Vector3.FORWARD   ## the direction over the ground (flight_dir())
var _air_path := 0.0                 ## rad, the path angle through the air
var _heading_dir := Vector3.FORWARD   ## last horizontal direction of flight (survives a vertical path)
var _display_sign := 1.0   ## body_basis: +-1 on lift_dir, so the shown body doesn't flip through a vertical path


func _init(p: BirdProfile) -> void:
	profile = p
	energy = EnergyModel.new(p)
	alpha = p.alpha_best
	climb_alpha = best_climb().x


## Start flying from `pos` along `dir` at `spd` (alpha at best glide, wings level).
func launch(pos: Vector3, dir: Vector3, spd: float) -> void:
	position = pos
	velocity = dir.normalized() * spd
	alpha = profile.alpha_best
	bank = 0.0
	fold = 0.0
	stalled = false
	_last_dir = dir.normalized()
	var flat := Vector3(dir.x, 0.0, dir.z)
	_heading_dir = flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD
	_last_drag_accel = 0.0
	flap_trim = 0.0
	_update_frame()


## Stick pull at which the wing reaches its stall angle; the rest of the travel is the flare.
const STALL_STICK := 0.85


## Neutral stick's angle of attack now: best glide, slid toward climb_alpha while flap is held (flap_trim).
func trim_alpha() -> float:
	return lerpf(profile.alpha_best, climb_alpha, flap_trim)


## Commanded angle of attack for a stick pitch (-1 push .. +1 pull). Full pull and full push are the same whatever
## the trim; the travel between them is laid out from the trim.
func alpha_for_stick(y: float) -> float:
	var p := profile
	var neutral := trim_alpha()
	if y >= 0.0:
		if y <= STALL_STICK:
			return lerpf(neutral, p.alpha_stall * 0.98, y / STALL_STICK)
		var top := p.alpha_stall + deg_to_rad(p.alpha_pull_over_deg)
		return lerpf(p.alpha_stall * 0.98, top, (y - STALL_STICK) / (1.0 - STALL_STICK))
	return lerpf(neutral, deg_to_rad(p.alpha_push_deg), minf(1.0, -y * 2.0))


## Lift coefficient with a soft stall: linear to the stall angle, then it sags to ~65% over 10 degrees.
func lift_coefficient(a: float) -> float:
	var p := profile
	if a <= p.alpha_stall:
		return maxf(p.cl_alpha * a, -0.6)
	var t := smoothstep(p.alpha_stall, p.alpha_stall + deg_to_rad(10.0), a)
	return p.cl_max * (1.0 - 0.35 * t)


## Drag coefficient for a lift coefficient, angle of attack and wing tuck.
func drag_coefficient(c_l: float, a: float, f: float) -> float:
	var p := profile
	var span_k := 1.0 - p.fold_span_cut * f
	var area_k := 1.0 - p.fold_area_cut * f
	var k := p.k_induced * area_k / (span_k * span_k)   # AR falls as the span folds faster than the area
	var c := p.cd0 * (1.0 - p.fold_drag_cut * f) / area_k + k * c_l * c_l
	if a > p.alpha_stall:
		c += 1.3 * pow(sin(a), 2.0) * smoothstep(p.alpha_stall, p.alpha_stall + deg_to_rad(8.0), a)
	return c


## Wingbeat thrust (m/s^2, during a downstroke at full strength, before ground effect) at airspeed `v`: strongest at a
## standstill, fading as (1 - v/cap)^2 so flapping has a top speed.
func flap_accel_at(v: float) -> float:
	return profile.flap_accel * pow(clampf(1.0 - v / profile.flap_speed_cap, 0.0, 1.0), 2.0)


## How far a wingbeat's thrust tilts up from the flight path (rad) at airspeed `v`: mostly lift when slow, mostly
## forward at best-glide speed and above.
func flap_tilt_at(v: float) -> float:
	return deg_to_rad(lerpf(profile.flap_tilt_slow_deg, profile.flap_tilt_deg, clampf(v / profile.v_best, 0.0, 1.0)))


## The share of the time a held wingbeat drives, as step() counts it: the downstroke and the whole beat each round
## up to whole physics ticks (a sparrow's 0.1 s beat drives 4 ticks in 7 at 60 Hz: 0.57, not the downstroke's 0.5).
func flap_duty() -> float:
	if _duty >= 0.0:
		return _duty
	var dt := 1.0 / Engine.physics_ticks_per_second
	var drive := 0
	var ft := profile.flap_period * profile.downstroke
	while ft > 0.0:
		drive += 1
		ft = maxf(0.0, ft - dt)
	var beat := 1
	var cool := maxf(0.0, profile.flap_period - dt)
	while cool > 0.0:
		beat += 1
		cool = maxf(0.0, cool - dt)
	_duty = float(drive) / beat
	return _duty


## The wingbeat's thrust averaged over the beat at airspeed `v` and strength `s`, split along the path (x) and across
## it toward the lift (y), for a path `gamma` above the horizon: below best-glide speed the thrust is aimed partly from
## the heading (step()), so it tilts up from the path by less the steeper the climb.
func mean_flap_thrust(v: float, s: float, gamma: float) -> Vector2:
	var k := clampf(v / profile.v_best, 0.0, 1.0)
	var theta := flap_tilt_at(v) - (1.0 - k) * gamma
	var t := flap_accel_at(v) * s * flap_duty()
	return Vector2(t * cos(theta), t * sin(theta))


## Steady flight at airspeed `v` with flap held at strength `s`, wings level and undamaged: Vector2(angle of attack,
## path angle). Per kg, along the path  T_along - D = g sin(gamma)  and across it  L + T_across = g cos(gamma), with
## L and D from the polar (the auto-sweep's tuck included) and T from the wingbeat as step() flies it. The path angle
## that balances them is found by bisection; the angle of attack is the one whose lift is what's left. Vector2(NAN, ..)
## where there is none: the thrust alone outclimbs the weight (a hovering climb, not flight on the wing), or the wing
## can't lift what's left.
func steady_flapping(v: float, s := 1.0) -> Vector2:
	var lo := deg_to_rad(-60.0)
	var hi := deg_to_rad(85.0)
	if _steady_along(v, s, hi) > 0.0 or _steady_along(v, s, lo) < 0.0:
		return Vector2(NAN, hi)
	for i in 40:
		var mid := 0.5 * (lo + hi)
		if _steady_along(v, s, mid) > 0.0:
			lo = mid
		else:
			hi = mid
	var gamma := 0.5 * (lo + hi)
	var c_l := _steady_cl(v, s, gamma)
	if c_l > profile.cl_max or c_l < -0.6:
		return Vector2(NAN, gamma)
	return Vector2(c_l / profile.cl_alpha, gamma)


static var _climb_cache := {}


## The fastest steady climb on the wing with flap held at strength `s`, no slower than `min_speed` (m/s; by default
## CLIMB_MIN_SPEED x best-glide speed, the climb trim): Vector3(angle of attack, airspeed, climb rate). Climb rate is
## v sin(gamma) from steady_flapping, scanned over airspeed. A held wingbeat spends the same burst every second whatever
## the bird does, so the fastest climb is also the most height per wingbeat: the efficient climb, as the minimum-power
## speed is a real bird's (Pennycuick). It stays on the stable side (a slower speed needs more angle of attack, so
## slowing drops the nose), and under CLIMB_ALPHA_MARGIN of the most angle of attack any slower steady flight needs:
## past that a flapping climb tips into a stalled, hovering one (the sparrow's wingbeat lifts more than its weight at a
## standstill). Falls back to best glide if there is no steady climb. Worked out once per set of numbers.
func best_climb(s := 1.0, min_speed := -1.0) -> Vector3:
	var p := profile
	var floor_v := min_speed if min_speed >= 0.0 else CLIMB_MIN_SPEED * p.v_best
	var key := "%s|%f|%f|%f|%f|%f|%f|%f|%f|%f|%f|%f|%f|%f|%f|%f|%f|%f|%f|%d" % [p.id, p.mass, p.wing_area, p.span, p.oswald,
		p.glide_ratio, p.cl_max, p.flap_period, p.downstroke, p.flap_accel, p.flap_speed_cap, p.flap_tilt_deg,
		p.flap_tilt_slow_deg, p.fold_area_cut, p.fold_span_cut, p.fold_drag_cut, auto_sweep, s, floor_v,
		Engine.physics_ticks_per_second]
	if _climb_cache.has(key):
		return _climb_cache[key]
	var best := Vector3(p.alpha_best, p.v_best, -INF)
	var hump := -INF        # the most angle of attack a steady flight slower than this one needs
	var last := INF
	var step := p.v_stall * 0.02
	var v := p.v_stall * 0.5
	while v < p.v_best * 2.5:
		var st := steady_flapping(v, s)
		if not is_nan(st.x):
			var climb := v * sin(st.y)
			if v >= floor_v and st.x < last and st.x <= CLIMB_ALPHA_MARGIN * hump and climb > best.z:
				best = Vector3(st.x, v, climb)
			hump = maxf(hump, st.x)
			last = st.x
		v = floor_v if v < floor_v and v + step > floor_v else v + step   # (the floor itself is one of the speeds tried)
	_climb_cache[key] = best
	return best


## The lift coefficient a steady flapping flight at (v, gamma) needs: what the thrust leaves of the weight's share.
func _steady_cl(v: float, s: float, gamma: float) -> float:
	var p := profile
	var f := auto_sweep * smoothstep(p.v_best, p.v_best * 2.0, v)
	var qs := 0.5 * BirdProfile.RHO * v * v * p.wing_area * (1.0 - p.fold_area_cut * f) / p.mass
	return (BirdProfile.G * cos(gamma) - mean_flap_thrust(v, s, gamma).y) / maxf(qs, 1e-6)


## Along-path force per kg left over in a steady flapping flight at (v, gamma): falls as the path steepens.
func _steady_along(v: float, s: float, gamma: float) -> float:
	var p := profile
	var f := auto_sweep * smoothstep(p.v_best, p.v_best * 2.0, v)
	var qs := 0.5 * BirdProfile.RHO * v * v * p.wing_area * (1.0 - p.fold_area_cut * f) / p.mass
	var c_l := _steady_cl(v, s, gamma)
	var c_d := drag_coefficient(c_l, c_l / p.cl_alpha, f)
	return mean_flap_thrust(v, s, gamma).x - qs * c_d - BirdProfile.G * sin(gamma)


## Can a wingbeat start now?
func can_flap() -> bool:
	return flap_cooldown <= 0.0


## Start a wingbeat (energy permitting it is full strength, else weak). Returns false if mid-beat.
func flap(free := false) -> bool:
	if not can_flap():
		return false
	flap_strength = 1.0 if free else energy.spend_flap()
	flap_time = profile.flap_period * profile.downstroke
	flap_cooldown = profile.flap_period
	flap_phase = 0.0
	flap_count += 1
	return true


func step(dt: float, input: FlightInput) -> void:
	var p := profile
	velocity -= wind   # (through the air, for the tick; speed and the path are already through it, from the last tick)
	# --- Attitude follows the stick -------------------------------------------------------------
	var stick := input.stick.clamp(Vector2(-1, -1), Vector2(1, 1))
	var bank_target := stick.x * deg_to_rad(p.max_bank_deg) + (wing_loss.y - wing_loss.x) * LOSS_ROLL * deg_to_rad(p.max_bank_deg)
	bank = move_toward(bank, bank_target, deg_to_rad(p.roll_rate_deg) * dt)
	# Flapping trim: neutral slides toward the climb's angle of attack as far as the held wingbeats are strong.
	var held := flap_strength if input.flap_held and flap_count > 0 else 0.0
	flap_trim = lerpf(flap_trim, held, 1.0 - exp(-dt / FLAP_TRIM_TIME))
	var alpha_target := alpha_for_stick(stick.y)
	# Turn assist: some of the extra lift a bank needs (1/cos) comes without pulling.
	if alpha_target > 0.0 and alpha_target < p.alpha_stall:
		var need := 1.0 / maxf(cos(bank), 0.35) - 1.0
		alpha_target = minf(p.alpha_stall * 0.97, alpha_target * (1.0 + turn_assist * need))
	# Phugoid damping. In the bob, speed and path angle trade: dV/dt ~ -g dGamma. Feeding the unpowered
	# along-path acceleration (zero in a steady glide) back into alpha adds lift while speed is building and
	# sheds it while speed bleeds, which damps the swing. (Feeding back the path's rate instead only changes
	# the bob's stiffness, and chatters.)
	# With flap held the steady state is a climb, not a glide: there the wingbeat's mean thrust along the path
	# (as flap_trim has it) balances the drag and the climb. Left out, the damper read that steady climb as speed
	# bleeding away and held the nose ~5 deg low, so flapping flew fast and shallow instead of climbing.
	# The damper never takes the wing past the stall itself (accelerating down a steep dive, it would): only the stick can.
	if not stalled and pitch_damping > 0.0:
		var a_along := -BirdProfile.G * sin(_air_path) - _last_drag_accel   # (through the air)
		a_along += mean_flap_thrust(speed, flap_trim, _air_path).x
		var authority := 1.0 - minf(1.0, absf(stick.y) * 1.5)
		var damped := alpha_target + pitch_damping * 2.0 * p.alpha_best * clampf(a_along / BirdProfile.G, -0.5, 0.5) * authority
		alpha_target = minf(damped, maxf(alpha_target, p.alpha_stall * 0.97))
	if stalled:
		# A stalled wing won't hold a high angle: the nose drops toward best glide unless you keep pulling.
		alpha_target = minf(alpha_target, p.alpha_stall + deg_to_rad(p.alpha_pull_over_deg) * maxf(stick.y, 0.0))
	alpha = move_toward(alpha, alpha_target, deg_to_rad(p.alpha_rate_deg) * dt)
	# Wing tuck: the push past half stick, plus some automatic sweep with speed.
	var fold_push := clampf((-stick.y - 0.5) * 2.0, 0.0, 1.0)
	var fold_speed := auto_sweep * smoothstep(p.v_best, p.v_best * 2.0, speed)
	var fold_target := maxf(fold_push, fold_speed) * (1.0 - flare)
	fold = move_toward(fold, fold_target, 3.0 * dt)
	# Stall hysteresis: in past the stall angle (or well below stall speed), out once clearly back under it.
	if not stalled and (alpha > p.alpha_stall or (speed < 0.85 * p.v_stall and alpha > p.alpha_best * 0.5)):
		stalled = true
	elif stalled and alpha < p.alpha_stall * 0.85 and speed > p.v_stall:
		stalled = false

	# --- Wingbeat --------------------------------------------------------------------------------
	if input.flap_held and can_flap():
		flap()
	flap_cooldown = maxf(0.0, flap_cooldown - dt)
	var driving := flap_time > 0.0
	flap_phase = clampf(1.0 - flap_cooldown / p.flap_period, 0.0, 1.0) if flap_cooldown > 0.0 else 1.0

	# --- Forces ----------------------------------------------------------------------------------
	_update_frame()
	var dir := _last_dir
	var q := 0.5 * BirdProfile.RHO * speed * speed
	var area := p.wing_area * (1.0 - p.fold_area_cut * fold) * (1.0 - 0.5 * (wing_loss.x + wing_loss.y))
	# Ground effect: within ground_effect_height the ground cuts the wingtip vortices (less induced drag),
	# cushions the wing (a little more lift) and gives the downstroke something to push against (stronger
	# wingbeats, below). Exaggerated past the real thing on purpose: it's what lets a downed bird get back up.
	ground_effect = clampf(1.0 - ground_height / p.ground_effect_height, 0.0, 1.0)
	cl = lift_coefficient(alpha) * (1.0 + p.ground_effect_lift * ground_effect)
	if flare > 0.0:
		# A flaring bird pitches up as it slows and holds its lift near its weight (perching studies see no
		# lift spike and no sag): it brakes without dropping. Top the lift up toward the weight, within the
		# extra lift a deep-stall, unsteady flare can make (1.6 x CL max).
		var hold_cl := p.mass * BirdProfile.G / maxf(q * area, 1e-3)
		cl = lerpf(cl, clampf(hold_cl, cl, p.cl_max * 1.6), flare)
	var induced_cut := p.k_induced * 0.5 * ground_effect * cl * cl
	cd = drag_coefficient(cl, alpha, fold) - induced_cut + 1.2 * flare
	var aero_fade := smoothstep(0.5, 2.0, speed)   # no aero at a standstill (dropping off a perch)
	var a_lift := q * area * cl / p.mass * aero_fade * lift_scale
	var a_drag := q * area * cd / p.mass * aero_fade
	_last_drag_accel = a_drag
	load_factor = a_lift / BirdProfile.G
	wing_area_eff = area
	frontal_area = area * absf(sin(alpha))
	lift_to_drag = cl / cd if cd > 0.0 else 0.0

	# Lift: rotate the velocity toward the lift vector without changing its speed. Half the turn goes
	# before the linear accelerations and half after (Strang splitting): turning all of it first makes
	# gravity act on a path already pitched up by the whole turn, which steepens the glide by ~half a degree.
	var turn := 0.0
	var axis := Vector3.ZERO
	if speed > 0.05:
		turn = minf(a_lift * dt / speed, 0.5)
		axis = dir.cross(lift_dir)
		if axis.length_squared() > 1e-8:
			axis = axis.normalized()
			velocity = velocity.rotated(axis, turn * 0.5)
		else:
			turn = 0.0
	# Drag (never more than half the speed in one tick), gravity, thrust, external push.
	var dv := minf(a_drag * dt, speed * 0.5)
	if speed > 0.0:
		velocity -= velocity.normalized() * dv
	velocity += Vector3(0, -BirdProfile.G, 0) * dt
	if driving:
		# Slow, a wingbeat mostly lifts (takeoff); at cruise it mostly drives forward. Thrust is strongest at
		# a standstill and fades with the square of airspeed, so flapping has a top speed.
		# Slow thrust is aimed forward-and-up from the bird's heading (not its path, which may point straight up
		# or down at low speed: aiming along it would let a bird helicopter vertically).
		var cruise_k := clampf(speed / p.v_best, 0.0, 1.0)
		var tilt := flap_tilt_at(speed)
		var cruise_dir := (dir * cos(tilt) + lift_dir * sin(tilt)).normalized()
		var slow_dir := (_heading_dir * cos(tilt) + UP * sin(tilt)).normalized()
		var thrust_dir := slow_dir.slerp(cruise_dir, cruise_k)
		var cushion := 1.0 + p.ground_effect_thrust * ground_effect
		velocity += thrust_dir * flap_accel_at(speed) * flap_strength * cushion * dt
		flap_time = maxf(0.0, flap_time - dt)
	velocity += extra_accel * dt
	if turn != 0.0:
		velocity = velocity.rotated(axis, turn * 0.5)
	position += (velocity + wind) * dt

	energy.tick(dt, driving, load_factor, false)
	_update_frame()
	velocity += wind   # (over the ground again; speed and the lift stay as through the air, the path is over it)
	_ground_frame()


## Recompute speed, path angle, flight direction and lift vector from the velocity and bank.
func _update_frame() -> void:
	speed = velocity.length()
	if speed > 0.05:
		_last_dir = velocity / speed
	var dir := _last_dir
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() > 0.2:
		_heading_dir = flat.normalized()
	_air_path = asin(clampf(dir.y, -1.0, 1.0))
	path_angle = _air_path
	_ground_dir = dir
	var up_perp := UP - dir * dir.dot(UP)
	if up_perp.length_squared() < 1e-6:
		up_perp = lift_dir - dir * dir.dot(lift_dir)   # straight up/down: keep the last lift plane
	up_perp = up_perp.normalized()
	var right := dir.cross(up_perp).normalized()
	lift_dir = (up_perp * cos(bank) + right * sin(bank)).normalized()
	# The body as shown keeps its back away from its heading through a near-vertical path: there the lift plane
	# (from world up) flips whenever the path wobbles past straight up -- a hovering climb's sideways drift changing
	# sign -- and the body would flip 180 deg with it. Display only: the forces use lift_dir as it is.
	_display_sign = -1.0 if absf(dir.y) > 0.85 and lift_dir.dot(_heading_dir) > 0.0 else 1.0


## Over the ground: the direction and path angle the bird is travelling (in still air, the same as through it).
func _ground_frame() -> void:
	if wind == Vector3.ZERO:
		return
	var v := velocity.length()
	if v > 0.05:
		_ground_dir = velocity / v
	path_angle = asin(clampf(_ground_dir.y, -1.0, 1.0))


## Direction of flight over the ground (unit), even at a standstill.
func flight_dir() -> Vector3:
	return _ground_dir


## The body's orientation: nose `alpha` above the flight path, rolled by `bank`. -Z is the nose. (Near vertical
## its back keeps facing away from its heading: _display_sign, _update_frame.)
func body_basis() -> Basis:
	var dir := _last_dir
	var lift := lift_dir * _display_sign
	var nose := (dir * cos(alpha) + lift * sin(alpha)).normalized()
	var up := (lift * cos(alpha) - dir * sin(alpha)).normalized()
	var right := nose.cross(up).normalized()
	return Basis(right, up, -nose).orthonormalized()


## Nose pitch above the horizon, rad.
func nose_pitch() -> float:
	var nose := -body_basis().z
	return asin(clampf(nose.y, -1.0, 1.0))


## The last horizontal direction of flight (unit): kept through a vertical climb or dive.
func heading_dir() -> Vector3:
	return _heading_dir


## Heading of the flight path in the horizontal plane (rad, 0 = -Z, + toward +X).
func heading() -> float:
	return atan2(_ground_dir.x, -_ground_dir.z)


## Total mechanical energy per kg (m^2/s^2): what a glide trades between height and speed.
func specific_energy() -> float:
	return 0.5 * speed * speed + BirdProfile.G * position.y
