class_name MenuBackdrop
extends Node3D
## The menu's backdrop: a few birds with their riders perched on an outpost's rail in a corner of the pine
## wood, the trees behind out of focus. Built from the arena's own pieces (ArenaBuilder's trunks, floor and
## outpost; BirdRig + Tack in the perched pose), small enough to build in a moment. The birds idle: they
## breathe and look about, the head snapping from one thing to the next as a bird's does, and every few seconds
## one of IDLES: a flick of the tail, a ruffle and shake of the plumage, a shrug of the wings, a stretch of the
## neck to look over something.

const BIRDS := ["falcon", "crow", "hawk", "sparrow"]   ## along the rail, left to right as the camera sees it
const SPACING := 0.42   ## m between birds on the rail
const IDLES := {   ## name -> [seconds, how often (relative)]
	"flick": [0.35, 3.0], "ruffle": [1.2, 1.0], "shrug": [1.4, 1.0], "stretch": [2.2, 1.5],
}

var cam: Camera3D
var rail_top := 0.0   ## m: the top of the rail the birds sit on
var sun: DirectionalLight3D
var rigs: Array[BirdRig] = []
var _tacks: Array[Tack] = []
var _look: Array[Vector3] = []      ## each bird's look target (world)
var _next: PackedFloat32Array = []  ## s until each picks a new one
var _base: Array[Dictionary] = []   ## each bird's perched pose (the controls the idles move)
var _idle: Array[String] = []       ## each bird's idle now ("" none)
var _idle_t: PackedFloat32Array = []  ## s into it
var _idle_wait: PackedFloat32Array = []  ## s until the next
var _t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 11
	sun = ForestLight.setup(self)   # (the game's light and its look; the sun's colour and height from the look)
	# The sun from behind the camera's left, so the birds are lit on the rail.
	sun.rotation_degrees.y = -35.0
	Lighting.bird_shadows(sun, 30.0, 3.0)
	var layout := ArenaLayout.new()
	layout.style = "pinewood"
	layout.seed = 5
	layout.boundary = 30.0
	layout.half_extent = 40.0
	var home := Pinewood._tree(layout, ArenaLayout.Kind.PINE, Vector2.ZERO, 28.0, 0.55)
	for i in 26:   # the wood behind: pines in a loose ring, none between the camera and the rail
		var a := _rng.randf_range(-PI, PI)
		var d := _rng.randf_range(5.0, 30.0)
		var p := Vector2(sin(a), -absf(cos(a)) - 0.25).normalized() * d
		Pinewood._tree(layout, ArenaLayout.Kind.PINE, p, _rng.randf_range(22.0, 32.0), _rng.randf_range(0.35, 0.6))
	var o := ArenaLayout.OutpostData.new()
	o.tree_id = home.id
	o.out = Vector3.BACK
	o.centre = Vector3(0.0, 6.0, home.radius + o.depth * 0.5 - 0.05)
	layout.outposts.append(o)
	var builder := ArenaBuilder.new()
	add_child(builder)
	builder.layout = layout
	builder._ground()
	builder._pinewood()
	# The birds on the rail, facing out with a little turn each, as birds sit.
	rail_top = o.centre.y + o.rail_radius * 2.0 - o.thickness * 0.2
	var rail_z := o.centre.z + o.depth * 0.5 - o.rail_radius
	var birds := Node3D.new()
	add_child(birds)
	for i in BIRDS.size():
		var r := BirdRig.new()
		birds.add_child(r)
		r.build(BirdProfile.by_id(BIRDS[i]))
		var t := Tack.fit(r, null)
		t.sitting = true
		r.position = Vector3((i - (BIRDS.size() - 1) * 0.5) * SPACING, rail_top, rail_z)
		r.rotation.y = PI + deg_to_rad([18.0, -10.0, 25.0, -30.0][i])
		RigPoses.apply(r, "folded", 0.0)
		# (folded puts the feet on a branch under the hips: lift the bird so that branch is the rail's top)
		var feet := (r.transform * r.foot_targets[0]).y
		r.position.y += rail_top - feet
		RigPoses.apply(r, "folded", 0.0)
		r.grip_radius = o.rail_radius
		rigs.append(r)
		_tacks.append(t)
		_look.append(r.global_position + _level(r) * Vector3(0, -0.15, -1))
		_next.append(_rng.randf_range(0.3, 2.0))
		_base.append({"fold": r.fold, "flap": r.flap, "tail_pitch": r.tail_pitch, "tail_spread": r.tail_spread,
			"fluff": r.fluff, "neck_ext": r.neck_ext})
		_idle.append("")
		_idle_t.append(0.0)
		_idle_wait.append(_rng.randf_range(1.0, 6.0))
	cam = Camera3D.new()
	cam.fov = 38.0
	cam.near = 0.01
	add_child(cam)
	var mid := Vector3(0.1, rail_top + 0.12, rail_z)
	cam.position = mid + Vector3(-0.75, 0.28, 1.9)
	cam.look_at(mid + Vector3(-0.5, 0.02, 0.0))
	var dof := CameraAttributesPractical.new()
	dof.dof_blur_far_enabled = true
	dof.dof_blur_far_distance = 3.2
	dof.dof_blur_far_transition = 5.0
	dof.dof_blur_amount = 0.12
	cam.attributes = dof
	cam.current = true


## The way a bird faces, level (its perched body is pitched up: looking "ahead" in its own frame is skyward).
static func _level(r: BirdRig) -> Basis:
	return Basis(Vector3.UP, r.rotation.y)


func _process(dt: float) -> void:
	_t += dt
	for i in rigs.size():
		var r := rigs[i]
		_next[i] -= dt
		if _next[i] <= 0.0:   # a new thing to look at: somewhere ahead, now and then a glance aside or down
			_next[i] = _rng.randf_range(0.6, 3.5)
			var yaw := _rng.randf_range(-1.1, 1.1)
			var pitch := _rng.randf_range(-0.45, 0.25)
			_look[i] = r.global_position + (_level(r) * Vector3(sin(yaw), pitch, -cos(yaw))).normalized()
		var want := (r.global_basis.inverse() * (_look[i] - r.global_position)).normalized()
		r.look_dir = r.look_dir.slerp(want, 1.0 - exp(-14.0 * dt)).normalized()
		r.breath = sin(TAU * 0.3 / sqrt(r._L) * _t + i * 1.7)
		_idle_step(i, dt)
		r.apply_pose()
		_tacks[i].update(dt)


## Bird `i`'s idle this frame: wait, start one (by IDLES' weights), play it as a rise and fall over its time.
func _idle_step(i: int, dt: float) -> void:
	var r := rigs[i]
	var b := _base[i]
	r.fold = b.fold
	r.flap = b.flap
	r.tail_pitch = b.tail_pitch
	r.tail_spread = b.tail_spread
	r.fluff = b.fluff
	r.neck_ext = b.neck_ext
	if _idle[i] == "":
		_idle_wait[i] -= dt
		if _idle_wait[i] > 0.0:
			return
		var total := 0.0
		for k in IDLES:
			total += float(IDLES[k][1])
		var pick := _rng.randf() * total
		for k in IDLES:
			pick -= float(IDLES[k][1])
			if pick <= 0.0:
				_idle[i] = k
				break
		_idle_t[i] = 0.0
	_idle_t[i] += dt
	var u := _idle_t[i] / float(IDLES[_idle[i]][0])
	if u >= 1.0:
		_idle[i] = ""
		_idle_wait[i] = _rng.randf_range(2.5, 8.0)
		return
	var up := sin(PI * u)   # (0 -> 1 -> 0)
	var hold := smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.75, 1.0, u))   # (in, held, out)
	match _idle[i]:
		"flick":   # the tail up and fanned, and down again
			r.tail_pitch = b.tail_pitch - 0.55 * up
			r.tail_spread = b.tail_spread + 0.45 * up
		"ruffle":   # the plumage lifts, shakes and lies down
			r.fluff = b.fluff + 0.13 * up * (0.75 + 0.25 * sin(TAU * 9.0 * _idle_t[i]))
		"shrug":   # the wings eased off the back and settled again
			r.fold = b.fold - 0.16 * up
			r.flap = b.flap + deg_to_rad(12.0) * up
			r.fluff = b.fluff + 0.04 * up
		"stretch":   # the neck up, to look over something
			r.neck_ext = b.neck_ext + 0.4 * hold
