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
const TAKEOFF_GRACE := 0.5     ## s after leaving the ground or a perch before touching down counts as landing
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
var perch_assist := 0.6        ## 0..1: auto-flare and a gentle pull toward a perch in the last few metres
var bonks := 0
var stun := 0.0
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
var _rig_dt := 0.0
var _rig_tick := 0
var _pass_body: Node = null
var _pass_left := 0.0


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
	global_basis = Basis.looking_at(facing, Vector3.UP)
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
	var inp: FlightInput = controller.sample(self, dt) if controller != null else FlightInput.new()
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
	_animate_rig(dt)


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
		candidate = p
		candidate_grip = grip
		candidate_distance = d
		candidate_status = p.catch_status(profile, global_position, model.velocity, grip)
		return


## Perch assist (auto-flare + a gentle pull onto the perch line) and the arena's soft walls.
func _apply_assists() -> void:
	var push := Vector3.ZERO
	model.flare = 0.0
	if candidate != null and perch_assist > 0.0 and candidate_distance < 5.0:
		var to := candidate_grip - global_position
		var d := maxf(candidate_distance, 0.01)
		var near_k := smoothstep(5.0, 1.5, d)
		var closing := model.velocity.dot(to / d)
		var target := profile.grab_speed_max * 0.85
		if closing > target:
			model.flare = clampf((closing - target) / (profile.grab_speed_max * 0.5), 0.0, 1.0) * perch_assist * near_k
		var dir := model.flight_dir()
		var lateral := to - dir * to.dot(dir)
		push += lateral * 4.0 * perch_assist * near_k
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
	global_basis = Basis.looking_at(facing, Vector3.UP)


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
	_land_dur = clampf(dist / maxf(_land_vel.length(), 1.0) * 1.6, 0.15, 0.45)


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
	var sit := Basis.looking_at(_land_facing, Vector3.UP)
	global_basis = _land_from_basis.slerp(sit, smoothstep(0.0, 1.0, s)).orthonormalized()
	model.energy.tick(dt, false, 0.0, true)
	if s >= 1.0:
		state = State.PERCHED
		model.velocity = Vector3.ZERO
		facing = _land_facing
		look_pitch = 0.0
		perched.emit(perch)


# --- Sitting (perch or ground) -----------------------------------------------------------------

func _sit(dt: float, inp: FlightInput) -> void:
	model.energy.tick(dt, false, 0.0, true)
	candidate = null
	candidate_status = Perch.Catch.OUT_OF_RANGE
	# Look around: the stick turns the bird (and so where it will leave toward) and tilts its gaze.
	facing = facing.rotated(Vector3.UP, -deg_to_rad(TURN_RATE) * inp.stick.x * dt).normalized()
	look_pitch = lerpf(look_pitch, clampf(inp.stick.y, -1.0, 1.0), 1.0 - exp(-6.0 * dt))
	global_basis = Basis.looking_at(facing, Vector3.UP)
	if state == State.PERCHED:
		if inp.flap_pressed or inp.catch_pressed:
			_leave_perch(inp.flap_pressed)
	elif inp.flap_pressed:
		# Jump and beat: mostly up, a little forward, with ground effect helping the first wingbeats.
		var v := facing * profile.hop_speed * 0.6 + Vector3.UP * maxf(3.5, profile.hop_speed * 1.1)
		model.launch(global_position + Vector3.UP * 0.05, v.normalized(), v.length())
		model.flap(true)
		_grace = TAKEOFF_GRACE
		state = State.FLYING


## FLAP: push off with a free wingbeat; CATCH: just let go and drop.
func _leave_perch(with_flap: bool) -> void:
	var left := perch
	var dir := (facing + Vector3.DOWN * (0.1 if with_flap else 0.35)).normalized()
	global_position = Perch.seat_at(perch_grip, profile) + facing * (left.thickness + profile.body_length * 0.35 + 0.05)
	model.launch(global_position, dir, profile.hop_speed)
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

# --- Telemetry (the only thing the HUD, camera and rig read) ------------------------------------

func telemetry() -> Dictionary:
	var m := model
	var p := profile
	return {
		"bird": p.display_name,
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
		"landing_t": clampf(_land_t / _land_dur, 0.0, 1.0) if state == State.LANDING else 0.0,
	}


## Where the head looks: the perch being landed on or caught, else ahead (sitting: where it faces, tilted
## by its gaze).
func _look_target() -> Vector3:
	if perch != null and state == State.LANDING:
		return perch_grip
	if state == State.FLYING:
		if candidate != null:
			return candidate_grip
		return global_position + model.flight_dir() * 8.0
	return global_position + facing * 8.0 + Vector3.UP * look_pitch * 4.0


## Where the feet reach for (world), or null: the perch while landing on or sitting on it, the ground
## under a grounded bird, a catchable perch a few metres ahead.
func _grip_point() -> Variant:
	match state:
		State.LANDING, State.PERCHED:
			return perch_grip if perch != null else null
		State.GROUNDED:
			return Vector3(global_position.x, ArenaLayout.GROUND_Y, global_position.z)
	if candidate != null and candidate_distance < 3.0:
		return candidate_grip
	return null


## Pose the rig (about 150 us of feather maths per bird): every tick up close, every 2nd tick past 30 m,
## every 4th past 60 m from the camera; not at all while it's hidden.
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
