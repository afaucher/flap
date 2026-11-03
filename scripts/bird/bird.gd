class_name Bird
extends CharacterBody3D
## A bird in the arena: a FlightModel for the air, a perch state machine, collision, and the telemetry
## snapshot the HUD, camera and rig read (they never touch the model). Its controller (PlayerController or
## AIPilot) supplies one FlightInput per physics tick; both have exactly the same authority.
##
## States: FLYING -> (CATCH held as a perch comes into reach slow enough) -> LANDING (a short Hermite blend onto
## the grip point where the bird meets the branch) -> PERCHED -> (FLAP: take off with a free wingbeat, or CATCH: let go and drop) -> FLYING.
## Perched (or on the ground) the stick turns the bird to look around; it leaves the way it faces.
## Settling slowly onto the ground or anything flat stands on it (GROUNDED); FLAP jumps up and takes off.
## Hitting a trunk or branch bounces, costs speed and briefly takes the controls away.

signal perched(perch: Perch)
signal released(perch: Perch)
signal bonked(normal: Vector3, speed: float)

enum State { FLYING, LANDING, PERCHED, GROUNDED }

const BIRD_LAYER := 2
const APPROACH_RADIUS := 8.0   ## perches this close (and ahead) are candidates
const GRAB_BUFFER := 0.25      ## s a quick CATCH tap stays live (holding catch keeps it live indefinitely)
const RELEASE_LOCK := 0.6      ## s before the perch just left can be caught again
const STUN_TIME := 0.35        ## s of no control after hitting a tree
const BOUNCE := 0.3            ## restitution off trunks
const BONK_KEEP := 0.6         ## share of speed kept after a bounce
const BONK_MIN := 1.0          ## m/s into a surface for a hit to count as a bonk (less is a graze)
const TURN_RATE := 150.0       ## deg/s a full stick turns a sitting bird
const AIM_AHEAD := 2.5         ## the landing point is sought along this many catch radii of flight path
const FLARE_PITCH := 55.0      ## deg, how far the body pitches up mid-landing (the braking flare)
const TAKEOFF_GRACE := 0.5     ## s after leaving the ground or a perch before touching down counts as landing
const PUSH_TIME := 0.15        ## s the feet keep pushing on the perch after take-off (the leap)
const LEAP_START := 0.3        ## share of the take-off speed at the first tick; the legs add the rest over PUSH_TIME
const LEAVE_PASS := 0.35       ## s the bird passes through the tree it just left (it may face along a branch)

var profile: BirdProfile
var model: FlightModel
var layout: ArenaLayout
var controller: Object         ## has sample(bird: Bird, dt: float) -> FlightInput
var rig: BirdRig
var arena: ArenaBuilder        ## optional: lets a departing bird pass through its own tree

var state := State.FLYING
var perch: Perch = null        ## held (PERCHED) or being landed on (LANDING)
var candidate: Perch = null
var candidate_status := Perch.Catch.OUT_OF_RANGE
var candidate_distance := INF
var candidate_grip := Vector3.ZERO   ## the candidate's grip point nearest the bird
var perch_grip := Vector3.ZERO       ## where the feet hold on (landing on / sitting on `perch`)
var _land_facing := Vector3.FORWARD
var sit_pitch_deg := 0.0             ## body pitch when perched (+ = upright); per species (BirdRig.POSE)
var ground_pitch_deg := 0.0          ## ... and standing on the ground
var perch_assist := 0.6        ## 0..1: auto-flare and a gentle pull toward a perch in the last few metres
var bonks := 0
var stun := 0.0
## Battle damage: the flight feathers a hit knocked out (BirdRig.feather_key -> true), up to DOWN_FEATHERS; they
## cost their wing its area (FlightModel.wing_loss) and the rig leaves them out. mend() grows them back.
var lost_feathers := {}
const DOWN_FEATHERS := 8
var last_input := FlightInput.new()
var facing := Vector3.FORWARD  ## where a sitting bird looks (turned by the stick); it leaves this way
var look_pitch := 0.0          ## -1..1, a sitting bird looking down/up (camera)

var _radius := 0.1
var _grab_buffer := 0.0
var _release_lock := 0.0
var _released_perch_id := -1
var _land_t := 0.0
var _land_dur := 0.3
var _land_from := Vector3.ZERO
var _land_vel := Vector3.ZERO
var _land_from_basis := Basis()
var _grace := 0.0
## Pose the rig every rendered frame (_process), for the moment the frame draws the bird (`drawn_lag` behind the last
## tick), with physics interpolation off on the rig: the whole rig -- feathers, lofted surfaces, skinned legs, tack --
## then moves each frame with the interpolated body. False: on the frame's first physics tick, the feathers interpolated
## tick to tick but the lofts and legs only stepping with the ticks (the game's `--rig-tick`, for comparison).
static var rig_in_process := true
var _rig_dt := 0.0
var _rig_due := 0.0   ## simulated time since the rig was last posed
var _rig_frame := -1  ## the rendered frame the rig was last posed in
var _rig_tick := 0
var _per_frame := true   ## this bird's rig posed per frame (rig_in_process when it was set up)
var _sim_t := 0.0     ## simulated time (s): the physics ticks run
var _posed_t := NAN   ## the simulated moment the rig was last posed for (NAN: not yet)
var _pass_body: Node = null
var _pass_left := 0.0
var _state_age := 0.0
var _age_state := -1
var _push_grip := Vector3.ZERO   ## the perch or ground just pushed off from (the legs extend toward it)
var _push_left := 0.0
var _leap := Vector3.ZERO        ## velocity the legs are still to add over the push (m/s, world)


func setup(p: BirdProfile, l: ArenaLayout, ctrl: Object) -> void:
	profile = p
	layout = l
	controller = ctrl
	model = FlightModel.new(p)
	collision_layer = BIRD_LAYER
	collision_mask = ArenaBuilder.WORLD_LAYER
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	_radius = maxf(0.06, p.body_length * 0.28)
	sphere.radius = _radius
	cs.shape = sphere
	add_child(cs)
	rig = BirdRig.new()
	rig.build(p)
	add_child(rig)
	_per_frame = rig_in_process
	if _per_frame:   # (posed every frame for the drawn moment: the engine mustn't interpolate it again)
		rig.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var pose: Dictionary = BirdRig.POSE.get(p.id, BirdRig.POSE["crow"])
	sit_pitch_deg = pose.perch_pitch
	ground_pitch_deg = pose.ground_pitch


## Put the bird on a perch (spawn, respawn).
func perch_at(p: Perch) -> void:
	perch = p
	state = State.PERCHED
	perch_grip = p.position
	global_position = Perch.seat_at(perch_grip, profile)
	model.position = global_position
	model.velocity = Vector3.ZERO
	facing = p.facing
	look_pitch = 0.0
	global_basis = _sit_basis()
	reset_physics_interpolation()


## Start in the air (tests, respawn without a perch).
func fly_from(pos: Vector3, dir: Vector3, spd: float) -> void:
	perch = null
	state = State.FLYING
	global_position = pos
	model.launch(pos, dir, spd)
	global_basis = model.body_basis()
	reset_physics_interpolation()


func _physics_process(dt: float) -> void:
	var p0 := Perf.t()
	var inp: FlightInput = controller.sample(self, dt) if controller != null else FlightInput.new()
	Perf.add("bird.control", p0)
	p0 = Perf.t()
	last_input = inp
	_grace = maxf(0.0, _grace - dt)
	if _pass_body != null:
		_pass_left -= dt
		if _pass_left <= 0.0:
			if is_instance_valid(_pass_body):
				remove_collision_exception_with(_pass_body)
			_pass_body = null
	match state:
		State.FLYING: _fly(dt, inp)
		State.LANDING: _land(dt)
		State.PERCHED, State.GROUNDED: _sit(dt, inp)
	if state != _age_state:
		_age_state = state
		_state_age = 0.0
	else:
		_state_age += dt
	_push_left = maxf(0.0, _push_left - dt)
	Perf.add("bird.move", p0)
	_sim_t += dt
	if _per_frame:
		return
	# (--rig-tick) The rig is posed at most once per rendered frame, on its first physics tick, for the time since it
	# was last posed. A frame catching up runs several ticks but draws once: posing on each was wasted work, and under
	# load it multiplied with the catch-up ticks, so one slow frame made the next slower.
	_rig_due += dt
	var frame := Engine.get_process_frames()
	if frame != _rig_frame:
		_rig_frame = frame
		p0 = Perf.t()
		_animate_rig(_rig_due)
		_rig_due = 0.0
		Perf.add("bird.rig", p0)


## The rig, once per rendered frame, for the simulated moment the frame draws (rig_in_process).
func _process(_dt: float) -> void:
	if not _per_frame:
		return
	var at := _sim_t - drawn_lag()
	if is_nan(_posed_t):   # (first drawn: posed for a tick, as the tick it was placed on would have)
		_posed_t = at - 1.0 / Engine.physics_ticks_per_second
	if at <= _posed_t:
		return
	var p0 := Perf.t()
	_animate_rig(at - _posed_t)
	_posed_t = at
	Perf.add("bird.rig", p0)


## How far the drawn world is behind the simulation (s). With physics interpolation on, a frame draws each body between
## its last two ticks, (1 - fraction) of a tick behind the latest; what's placed by hand in _process (the rig, a round in
## flight, smoke, trails) is placed for that same moment, so it moves with the birds every frame.
static func drawn_lag() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or not tree.physics_interpolation:
		return 0.0
	return (1.0 - Engine.get_physics_interpolation_fraction()) / Engine.physics_ticks_per_second


# --- Flying ------------------------------------------------------------------------------------

func _fly(dt: float, inp: FlightInput) -> void:
	_release_lock = maxf(0.0, _release_lock - dt)
	_update_candidate()
	# Catch while it is held (hold it through the approach), and for GRAB_BUFFER after a quick tap.
	if inp.catch_pressed:
		_grab_buffer = GRAB_BUFFER
	if (inp.catch_held or _grab_buffer > 0.0) and candidate_status == Perch.Catch.OK:
		_grab_buffer = 0.0
		_begin_landing(candidate)
		return
	_grab_buffer = maxf(0.0, _grab_buffer - dt)
	if inp.flap_pressed:
		model.flap()
	var ctl := inp
	if stun > 0.0:
		stun -= dt
		ctl = FlightInput.new()
	_apply_assists()
	model.position = global_position
	model.ground_height = global_position.y - ArenaLayout.GROUND_Y - _radius
	model.step(dt, ctl)
	var col := move_and_collide(model.position - global_position)
	if col != null:
		_on_collision(col)
		if state != State.FLYING:
			return
	model.position = global_position
	# Belly on the ground and settling: stand (even if the contact came through a seam the collision missed).
	if _grace <= 0.0 and global_position.y < _radius + 0.03 and model.velocity.y <= 0.0 and model.velocity.length() < profile.grab_speed_max * 1.6:
		_land_on_ground()
		return
	global_basis = model.body_basis()


func _update_candidate() -> void:
	candidate = null
	candidate_status = Perch.Catch.OUT_OF_RANGE
	candidate_distance = INF
	var dir := model.flight_dir()
	for p in layout.perches_near(global_position, APPROACH_RADIUS):
		if p.id == _released_perch_id and _release_lock > 0.0:
			continue
		# Aim at the grip point straight ahead on the flight path, not merely the nearest one.
		var grip := p.aim_grip(global_position, dir, profile.grab_radius * AIM_AHEAD)
		var to := grip - global_position
		var d := to.length()
		if d > profile.grab_radius and dir.dot(to / maxf(d, 1e-4)) < 0.5:
			continue   # behind or off to the side: not where we're headed
		var status := p.catch_status(profile, global_position, model.velocity, grip)
		# The nearest perch ahead is the candidate, unless a further one is actually in reach: that one wins
		# (a branch just out of reach must not hide the treetop the feet can close on).
		if candidate == null or (candidate_status == Perch.Catch.OUT_OF_RANGE and status != Perch.Catch.OUT_OF_RANGE):
			candidate = p
			candidate_grip = grip
			candidate_distance = d
			candidate_status = status
		if candidate_status != Perch.Catch.OUT_OF_RANGE:
			return


## Perch assist (auto-flare + a gentle pull onto the perch line) and the arena's soft walls.
func _apply_assists() -> void:
	var push := Vector3.ZERO
	model.flare = 0.0
	if candidate != null and perch_assist > 0.0 and candidate_distance < 6.0:
		var to := candidate_grip - global_position
		var d := maxf(candidate_distance, 0.01)
		var near_k := smoothstep(6.0, 2.5, d)
		var closing := model.velocity.dot(to / d)
		var target := profile.grab_speed_max * 0.8
		if closing > target:
			model.flare = clampf((closing - target) / (profile.grab_speed_max * 0.5), 0.0, 1.0) * perch_assist * near_k
		# Steer the flight line onto where the body sits once perched (just above the grip), so the bird
		# arrives level with or a little above the branch, feet reaching down -- the catch envelope's sweet spot.
		var dir := model.flight_dir()
		var to_seat := Perch.seat_at(candidate_grip, profile) - global_position
		var lateral := to_seat - dir * to_seat.dot(dir)
		push += lateral * 4.0 * perch_assist * near_k
	if _push_left > 0.0:   # (the leap: the legs extending speed the bird up over the push, not in one tick)
		push += _leap / PUSH_TIME
	var horiz := Vector2(global_position.x, global_position.z)
	if horiz.length() > layout.boundary:
		var back := -horiz.normalized() * (horiz.length() - layout.boundary) * 3.0
		push += Vector3(back.x, 0.0, back.y)
	if global_position.y > layout.ceiling:
		push.y -= (global_position.y - layout.ceiling) * 2.0
	model.extra_accel = push


func _on_collision(col: KinematicCollision3D) -> void:
	var n := col.get_normal()
	var v := model.velocity
	var into := v.dot(n)
	var collider := col.get_collider()
	# Settling slowly onto anything flat (the ground, a trunk top): stand on it.
	if _grace <= 0.0 and n.y > 0.7 and v.length() < profile.grab_speed_max * 1.6:
		_land_on_ground()
		return
	if into < -BONK_MIN:
		v -= (1.0 + BOUNCE) * into * n
		v *= BONK_KEEP
		model.velocity = v
		stun = STUN_TIME
		bonks += 1
		bonked.emit(n, -into)
	elif into < 0.0:
		model.velocity = v - into * n   # a graze: just slide along it
		var rest := col.get_remainder().slide(n)
		if rest.length() > 1e-4:
			move_and_collide(rest)


func _land_on_ground() -> void:
	state = State.GROUNDED
	perch = null
	model.velocity = Vector3.ZERO
	var fwd := model.flight_dir()
	fwd.y = 0.0
	if fwd.length() < 0.1:
		fwd = -global_basis.z
		fwd.y = 0.0
	facing = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	look_pitch = 0.0
	global_basis = _sit_basis()


# --- Landing on a perch --------------------------------------------------------------------------

func _begin_landing(p: Perch) -> void:
	state = State.LANDING
	perch = p
	_land_t = 0.0
	_land_from = global_position
	_land_vel = model.velocity
	_land_from_basis = global_basis
	# Land where the bird's flight path meets the branch (the aim point it was caught at), facing across the
	# branch toward the side it came from.
	perch_grip = candidate_grip if p == candidate else p.aim_grip(global_position, model.flight_dir(), profile.grab_radius * AIM_AHEAD)
	_land_facing = p.facing_for(model.velocity)
	var dist := _land_from.distance_to(Perch.seat_at(perch_grip, profile))
	# Timed from the relative motion: braking evenly from the arrival speed to rest over the distance
	# takes 2 d / v. Long enough to see the flare, short enough to stay responsive.
	_land_dur = clampf(2.0 * dist / maxf(_land_vel.length(), 1.0), 0.3, 0.8)


func _land(dt: float) -> void:
	_land_t += dt
	var s := clampf(_land_t / _land_dur, 0.0, 1.0)
	var target := Perch.seat_at(perch_grip, profile)
	# Cubic Hermite: leaves at the flight velocity, arrives at rest.
	var s2 := s * s
	var s3 := s2 * s
	var pos := _land_from * (2.0 * s3 - 3.0 * s2 + 1.0) + _land_vel * _land_dur * (s3 - 2.0 * s2 + s) + target * (-2.0 * s3 + 3.0 * s2)
	model.velocity = (pos - global_position) / dt if dt > 0.0 else Vector3.ZERO
	global_position = pos
	model.position = pos
	global_basis = _landing_basis(s)
	model.energy.tick(dt, false, 0.0, true)
	if s >= 1.0:
		state = State.PERCHED
		model.velocity = Vector3.ZERO
		facing = _land_facing
		look_pitch = 0.0
		perched.emit(perch)


## A sitting bird's body: facing `facing`, pitched up to its species' posture (upright raptors and owls,
## level-ish crows and sparrows; a little more level on the ground).
func _sit_basis() -> Basis:
	var pitch := sit_pitch_deg if state == State.PERCHED or state == State.LANDING else ground_pitch_deg
	return (Basis.looking_at(facing, Vector3.UP) * Basis(Vector3.RIGHT, deg_to_rad(pitch))).orthonormalized()


## The body through a landing: from the flight attitude it turns toward the landing facing and pitches up
## into the flare (peaking about two-thirds of the way), then settles to the perched posture.
func _landing_basis(s: float) -> Basis:
	var flat := Vector3(_land_vel.x, 0.0, _land_vel.z)
	var from_dir := flat.normalized() if flat.length() > 0.05 else _land_facing
	var yaw_dir := from_dir.slerp(_land_facing, smoothstep(0.1, 0.85, s)).normalized()
	var flare := deg_to_rad(FLARE_PITCH) * sin(PI * clampf(s / 0.85, 0.0, 1.0))
	var pitch := lerpf(flare, deg_to_rad(sit_pitch_deg), smoothstep(0.7, 1.0, s))
	var target := Basis.looking_at(yaw_dir, Vector3.UP) * Basis(Vector3.RIGHT, pitch)
	return _land_from_basis.slerp(target.orthonormalized(), smoothstep(0.0, 0.3, s)).orthonormalized() if s < 0.3 else target.orthonormalized()


# --- Sitting (perch or ground) -----------------------------------------------------------------

func _sit(dt: float, inp: FlightInput) -> void:
	model.energy.tick(dt, false, 0.0, true)
	candidate = null
	candidate_status = Perch.Catch.OUT_OF_RANGE
	# Look around: the stick turns the bird (and so where it will leave toward) and tilts its gaze.
	facing = facing.rotated(Vector3.UP, -deg_to_rad(TURN_RATE) * inp.stick.x * dt).normalized()
	look_pitch = lerpf(look_pitch, clampf(inp.stick.y, -1.0, 1.0), 1.0 - exp(-6.0 * dt))
	global_basis = _sit_basis()
	if state == State.PERCHED:
		if inp.flap_pressed or inp.catch_pressed:
			_leave_perch(inp.flap_pressed)
	elif inp.flap_pressed:
		_push_grip = Vector3(global_position.x, ArenaLayout.GROUND_Y, global_position.z)
		_push_left = PUSH_TIME
		# Jump and beat: mostly up, a little forward, with ground effect helping the first wingbeats. The legs
		# build the speed up over the push (_leap) rather than in one tick.
		var v := facing * profile.hop_speed * 0.6 + Vector3.UP * maxf(3.5, profile.hop_speed * 1.1)
		model.launch(global_position, v.normalized(), v.length() * LEAP_START)
		_leap = v * (1.0 - LEAP_START)
		model.flap(true)
		_grace = TAKEOFF_GRACE
		state = State.FLYING


## FLAP: push off with a free wingbeat; CATCH: just let go and drop. From the seat, as it sits: the bird passes
## through its own tree for a moment (_pass_through), so it needn't be moved clear of the branch first -- that jump
## (a third of a metre for a hawk, in one tick) read as a shove off the perch. The push leaves a little upward so the
## body rises over the branch; letting go, it tips forward and falls.
func _leave_perch(with_flap: bool) -> void:
	var left := perch
	_push_grip = perch_grip
	_push_left = PUSH_TIME
	var dir := (facing + (Vector3.UP * 0.15 if with_flap else Vector3.DOWN * 0.35)).normalized()
	global_position = Perch.seat_at(perch_grip, profile)
	model.launch(global_position, dir, profile.hop_speed * LEAP_START)
	_leap = dir * profile.hop_speed * (1.0 - LEAP_START)
	if with_flap:
		model.flap(true)   # the push-off wingbeat is free
	_released_perch_id = left.id
	_release_lock = RELEASE_LOCK
	_grace = TAKEOFF_GRACE
	_pass_through(left.tree_id)
	perch = null
	state = State.FLYING
	released.emit(left)


func _pass_through(tree_id: int) -> void:
	if arena == null or tree_id < 0 or tree_id >= arena.tree_bodies.size():
		return
	if _pass_body != null and is_instance_valid(_pass_body):
		remove_collision_exception_with(_pass_body)
	_pass_body = arena.tree_bodies[tree_id]
	_pass_left = LEAVE_PASS
	add_collision_exception_with(_pass_body)

# --- Battle damage -------------------------------------------------------------------------------

## Knock out up to `n` flight feathers nearest `at` (world; never past DOWN_FEATHERS lost in all). Returns the keys lost.
func lose_feathers(at: Vector3, n: int) -> Array:
	n = mini(n, DOWN_FEATHERS - lost_feathers.size())
	if n <= 0:
		return []
	var local := rig.global_transform.affine_inverse() * at
	var near := []
	for f in rig.flight_feathers():
		if not lost_feathers.has(f.key):
			near.append([(f.mid as Vector3).distance_squared_to(local), f.key])
	near.sort_custom(func(a, b): return a[0] < b[0])
	var out := []
	for e in near.slice(0, n):
		lost_feathers[e[1]] = true
		out.append(e[1])
	_wing_loss()
	return out


## 1 whole .. 0 at DOWN_FEATHERS lost.
func health() -> float:
	return clampf(1.0 - float(lost_feathers.size()) / DOWN_FEATHERS, 0.0, 1.0)


func is_down() -> bool:
	return lost_feathers.size() >= DOWN_FEATHERS


## Every feather back (the nest, a rearm, a respawn).
func mend() -> void:
	lost_feathers.clear()
	_wing_loss()


func _wing_loss() -> void:
	var loss := Vector2.ZERO
	var half := profile.wing_area * 0.5
	for key in lost_feathers:
		var side := BirdRig.feather_side(key)
		if side < 0:
			loss.x += rig.feather_area(key) / half
		elif side > 0:
			loss.y += rig.feather_area(key) / half
	model.wing_loss = loss.clamp(Vector2.ZERO, Vector2.ONE * 0.9)


# --- Telemetry (the only thing the HUD, camera and rig read) ------------------------------------

func telemetry() -> Dictionary:
	var m := model
	var p := profile
	return {
		"bird": p.display_name,
		"species": p.id,
		"state": state,
		"position": global_position,
		"velocity": m.velocity,
		"flight_dir": m.flight_dir(),
		"candidate_grip": candidate_grip,
		"facing": facing if state == State.PERCHED or state == State.GROUNDED else -global_basis.z,
		"look_pitch": look_pitch,
		"flap_count": m.flap_count,
		"ground_effect": m.ground_effect if state == State.FLYING else 0.0,
		"catch_armed": _grab_buffer > 0.0 or last_input.catch_held,
		"look_target": _look_target(),
		"has_grip": _grip_point() != null,
		"grip": _grip_point() if _grip_point() != null else Vector3.ZERO,
		"grip_radius": perch.thickness if perch != null and state in [State.LANDING, State.PERCHED] else 0.0,   # (the branch the toes wrap)
		"surface": _surface(),
		"speed": m.speed if state == State.FLYING else m.velocity.length(),
		"v_best": p.v_best,
		"v_stall": p.v_stall,
		"grab_speed": p.grab_speed_max,
		"path_angle": m.path_angle if state == State.FLYING else 0.0,
		"nose_pitch": m.nose_pitch() if state == State.FLYING else 0.0,
		"glide_angle": p.glide_angle,
		"bank": m.bank if state == State.FLYING else 0.0,
		"max_bank": deg_to_rad(p.max_bank_deg),
		"alpha": m.alpha,
		"alpha_stall": p.alpha_stall,
		"stalled": m.stalled and state == State.FLYING,
		"load": m.load_factor,
		"cl": m.cl,
		"cd": m.cd,
		"ld": m.lift_to_drag,
		"wing_area": p.wing_area,
		"wing_area_eff": m.wing_area_eff,
		"frontal_area": m.frontal_area,
		"fold": m.fold,
		"flare": m.flare,
		"flap_phase": m.flap_phase,
		"flapping": m.flap_cooldown > 0.0,
		"burst": m.energy.burst,
		"burst_cap": m.energy.burst_cap(),
		"burst_max": p.burst_max,
		"stamina": m.energy.stamina,
		"stick": last_input.stick,
		"candidate_status": candidate_status,
		"candidate_distance": candidate_distance,
		"altitude": global_position.y,
		"bonks": bonks,
		"stunned": stun > 0.0,
		"health": health(),
		"lost_feathers": lost_feathers,
		"wing_loss": model.wing_loss,
		"landing_t": clampf(_land_t / _land_dur, 0.0, 1.0) if state == State.LANDING else 0.0,
		"state_age": _state_age,
	}


## Where the head looks: the perch being landed on or caught, else ahead (sitting: where it faces, tilted
## by its gaze).
func _look_target() -> Vector3:
	if perch != null and state == State.LANDING:
		return perch_grip
	if state == State.FLYING:
		if candidate != null:
			return candidate_grip
		# Where it's going, but held near the horizon, as birds hold their heads: a steep climb out of a take-off
		# would otherwise point the beak at the sky (a third of the path's pitch, at most 25 deg).
		var dir := model.flight_dir()
		var flat := Vector3(dir.x, 0.0, dir.z)
		flat = flat.normalized() if flat.length() > 0.2 else model.heading_dir()   # (straight up: its heading)
		var pitch := clampf(asin(clampf(dir.y, -1.0, 1.0)) * 0.35, deg_to_rad(-25.0), deg_to_rad(25.0))
		return global_position + (flat * cos(pitch) + Vector3.UP * sin(pitch)) * 8.0
	return global_position + facing * 8.0 + Vector3.UP * look_pitch * 4.0


## What the bird sits on, for the rig to keep its tail and wingtips out of (world): {kind "branch" (a..b its axis,
## radius), "disc" (a treetop: centre on its top, radius) or "ground" (centre on it)}; empty in the air.
func _surface() -> Dictionary:
	if state == State.GROUNDED:
		return {"kind": "ground", "centre": Vector3(global_position.x, ArenaLayout.GROUND_Y, global_position.z)}
	if perch == null or not (state == State.PERCHED or state == State.LANDING):
		return {}
	if perch.kind == Perch.Kind.BRANCH:
		var down := Vector3.DOWN * perch.thickness
		return {"kind": "branch", "a": perch.a + down, "b": perch.b + down, "radius": perch.thickness}
	return {"kind": "disc", "centre": perch_grip, "radius": perch.disc}


## Where the feet reach for (world), or null: the perch while landing on or sitting on it, the ground
## under a grounded bird, a catchable perch a few metres ahead.
func _grip_point() -> Variant:
	match state:
		State.LANDING, State.PERCHED:
			return perch_grip if perch != null else null
		State.GROUNDED:
			return Vector3(global_position.x, ArenaLayout.GROUND_Y, global_position.z)
	if _push_left > 0.0:
		return _push_grip   # the leap: the feet stay on what they pushed off from while the legs extend
	if candidate != null and candidate_distance < 3.0:
		return candidate_grip
	return null


## Pose the rig for `dt` of simulated time: every time up close, every 2nd time past 30 m, every 4th past 60 m from
## the camera; not at all while it's hidden.
func _animate_rig(dt: float) -> void:
	if rig == null or not rig.visible:
		return
	_rig_dt += dt
	_rig_tick += 1
	var every := 1
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		var d := cam.global_position.distance_to(global_position)
		every = 1 if d < 30.0 else (2 if d < 60.0 else 4)
	if _rig_tick % every != 0 and state == State.FLYING:
		return
	rig.animate(telemetry(), _rig_dt)
	_rig_dt = 0.0
