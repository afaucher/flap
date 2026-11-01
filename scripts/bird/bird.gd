class_name Bird
extends CharacterBody3D
## A bird in the arena: a FlightModel for the air, a perch state machine, collision, and the telemetry
## snapshot the HUD, camera and rig read (they never touch the model). Its controller (PlayerController or
## AIPilot) supplies one FlightInput per physics tick; both have exactly the same authority.
##
## States: FLYING -> (SPACE with a perch in reach and slow enough) -> LANDING (a short Hermite blend onto
## the perch seat) -> PERCHED -> (SPACE) -> FLYING (drops off along the perch facing with a free wingbeat).
## Settling slowly onto the ground or anything flat stands on it (GROUNDED); SPACE takes off. Hitting a trunk or branch bounces,
## costs speed and briefly takes the controls away.

signal perched(perch: Perch)
signal released(perch: Perch)
signal bonked(normal: Vector3, speed: float)

enum State { FLYING, LANDING, PERCHED, GROUNDED }

const BIRD_LAYER := 2
const APPROACH_RADIUS := 8.0   ## perches this close (and ahead) are candidates
const GRAB_BUFFER := 0.25      ## s a SPACE press stays live for a catch (pressed a touch early, or too fast)
const RELEASE_LOCK := 0.6      ## s before the perch just left can be caught again
const STUN_TIME := 0.35        ## s of no control after hitting a tree
const BOUNCE := 0.3            ## restitution off trunks
const BONK_KEEP := 0.6         ## share of speed kept after a bounce
const BONK_MIN := 1.0          ## m/s into a surface for a hit to count as a bonk (less is a graze)

var profile: BirdProfile
var model: FlightModel
var layout: ArenaLayout
var controller: Object         ## has sample(bird: Bird, dt: float) -> FlightInput
var rig: BirdRig

var state := State.FLYING
var perch: Perch = null        ## held (PERCHED) or being landed on (LANDING)
var candidate: Perch = null
var candidate_status := Perch.Catch.OUT_OF_RANGE
var candidate_distance := INF
var perch_assist := 0.6        ## 0..1: auto-flare and a gentle pull toward a perch in the last few metres
var bonks := 0
var stun := 0.0
var last_input := FlightInput.new()

var _radius := 0.1
var _grab_buffer := 0.0
var _release_lock := 0.0
var _released_perch_id := -1
var _land_t := 0.0
var _land_dur := 0.3
var _land_from := Vector3.ZERO
var _land_vel := Vector3.ZERO
var _land_from_basis := Basis()


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
	global_position = p.seat(profile)
	model.position = global_position
	model.velocity = Vector3.ZERO
	global_basis = Basis.looking_at(p.facing, Vector3.UP)
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
	match state:
		State.FLYING: _fly(dt, inp)
		State.LANDING: _land(dt)
		State.PERCHED, State.GROUNDED: _sit(dt, inp)
	if rig != null:
		rig.animate(telemetry(), dt)


# --- Flying ------------------------------------------------------------------------------------

func _fly(dt: float, inp: FlightInput) -> void:
	_release_lock = maxf(0.0, _release_lock - dt)
	_update_candidate()
	# A press counts as a catch attempt (not a flap) when a perch is in reach, or will be within the buffer.
	if inp.action_pressed and candidate != null and candidate_distance < profile.grab_radius + model.speed * GRAB_BUFFER:
		_grab_buffer = GRAB_BUFFER
	if _grab_buffer > 0.0:
		if candidate_status == Perch.Catch.OK:
			_grab_buffer = 0.0
			_begin_landing(candidate)
			return
		_grab_buffer -= dt
	elif inp.action_pressed:
		model.flap()
	var ctl := inp
	if stun > 0.0:
		stun -= dt
		ctl = FlightInput.new(Vector2.ZERO, false, false)
	_apply_assists()
	model.position = global_position
	model.step(dt, ctl)
	var col := move_and_collide(model.position - global_position)
	if col != null:
		_on_collision(col)
		if state != State.FLYING:
			return
	model.position = global_position
	# Belly on the ground and settling: stand (even if the contact came through a seam the collision missed).
	if global_position.y < _radius + 0.03 and model.velocity.y <= 0.0 and model.velocity.length() < profile.grab_speed_max * 1.6:
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
		var to := p.position - global_position
		var d := to.length()
		if d > profile.grab_radius and dir.dot(to / d) < 0.5:
			continue   # behind or off to the side: not where we're headed
		candidate = p
		candidate_distance = d
		candidate_status = p.catch_status(profile, global_position, model.velocity)
		return


## Perch assist (auto-flare + a gentle pull onto the perch line) and the arena's soft walls.
func _apply_assists() -> void:
	var push := Vector3.ZERO
	model.flare = 0.0
	if candidate != null and perch_assist > 0.0 and candidate_distance < 5.0:
		var to := candidate.position - global_position
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
	if n.y > 0.7 and v.length() < profile.grab_speed_max * 1.6:
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
	global_basis = Basis.looking_at(fwd.normalized(), Vector3.UP)


# --- Landing on a perch --------------------------------------------------------------------------

func _begin_landing(p: Perch) -> void:
	state = State.LANDING
	perch = p
	_land_t = 0.0
	_land_from = global_position
	_land_vel = model.velocity
	_land_from_basis = global_basis
	var dist := _land_from.distance_to(p.seat(profile))
	_land_dur = clampf(dist / maxf(_land_vel.length(), 1.0) * 1.6, 0.15, 0.45)


func _land(dt: float) -> void:
	_land_t += dt
	var s := clampf(_land_t / _land_dur, 0.0, 1.0)
	var target := perch.seat(profile)
	# Cubic Hermite: leaves at the flight velocity, arrives at rest.
	var s2 := s * s
	var s3 := s2 * s
	var pos := _land_from * (2.0 * s3 - 3.0 * s2 + 1.0) + _land_vel * _land_dur * (s3 - 2.0 * s2 + s) + target * (-2.0 * s3 + 3.0 * s2)
	model.velocity = (pos - global_position) / dt if dt > 0.0 else Vector3.ZERO
	global_position = pos
	model.position = pos
	var sit := Basis.looking_at(perch.facing, Vector3.UP)
	global_basis = _land_from_basis.slerp(sit, smoothstep(0.0, 1.0, s)).orthonormalized()
	model.energy.tick(dt, false, 0.0, true)
	if s >= 1.0:
		state = State.PERCHED
		model.velocity = Vector3.ZERO
		perched.emit(perch)


# --- Sitting (perch or ground) -----------------------------------------------------------------

func _sit(dt: float, inp: FlightInput) -> void:
	model.energy.tick(dt, false, 0.0, true)
	candidate = null
	candidate_status = Perch.Catch.OUT_OF_RANGE
	if not inp.action_pressed:
		return
	if state == State.PERCHED:
		var left := perch
		var dir := (left.facing + Vector3.DOWN * 0.35).normalized()
		global_position = left.drop_off(profile)
		model.launch(global_position, dir, profile.hop_speed)
		model.flap(true)   # the push-off wingbeat is free
		_released_perch_id = left.id
		_release_lock = RELEASE_LOCK
		perch = null
		state = State.FLYING
		released.emit(left)
	else:
		var fwd := -global_basis.z
		fwd.y = 0.0
		var dir := (fwd.normalized() + Vector3.UP * 0.9).normalized()
		model.launch(global_position + Vector3.UP * 0.1, dir, profile.hop_speed * 1.3)
		model.flap(true)
		state = State.FLYING


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
		"facing": perch.facing if perch != null else -global_basis.z,
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
