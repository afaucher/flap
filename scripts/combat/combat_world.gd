class_name CombatWorld
extends Node3D
## The fight: registered birds and their launchers, projectiles in flight, and what happens when one bursts.
## Steps everything in _physics_process; draws projectiles and their smoke in _process (bursts and knocked-out
## feathers: CombatFx, `fx`), at the
## moment the frame draws the birds (Bird.drawn_lag: between the last two ticks, as physics interpolation draws them).
##
## A burst hurts every bird within `blast` m but its shooter: a short stun (no control, as when hitting a tree)
## and a shove away from it, and it knocks out the flight feathers nearest it (Bird.lose_feathers) -- 2 or 3
## (FEATHERS_PER_HIT on average) within a fuse's reach, 1 from the blast's outer ring -- in a puff. A bird hit again
## within `recover` s of its last hit loses at most RECOVER_FEATHERS: a salvo's rounds are in the air before the first
## lands, and they'd otherwise down a bird before it could do a thing about it (each hit restarts the window).
## Bird.DOWN_FEATHERS lost downs a bird (a long stun; it drops) and `downed` is emitted -- the scene decides what
## happens next.
## A bullet (Projectile GUN) hurts only the bird it hits: no stun, a nudge (GUN_SHOVE), and GUN_FEATHERS feather. Inside
## the recovery window a bullet takes GUN_CHIP of a feather instead (summed per bird, a feather each time the sum
## reaches one), so a stream of hits chips a bird down at about a feather a second rather than downing it in one:
## RECOVER_FEATHERS alone wouldn't bite on a round that takes one anyway. Its tracer is drawn as a bright streak (no
## smoke); it sparks on wood and the ground, and one that runs out just goes (no burst, no signal).

## Teams: each bird is on one (add_bird's `team`; unset, a team of its own, so everyone is an enemy). Locks and
## the HUD's target pick only enemies; bursts still hurt anyone but the shooter (friendly fire stays on). Each
## team may have a base (`bases`: a perch, an outpost's rail) where its birds rearm and mend and where a downed
## bird comes back (respawn: the scene calls it once the down stun is over). `score`: the enemy birds each team
## has downed (downing a teammate scores nothing).

signal downed(bird: Bird)
signal burst(at: Vector3, why: String, kind: int, surface: String)   ## surface: "bird" | "trunk" | "ground" | "air" (Projectile.step)
signal launched(p: Projectile)        ## a round left its launcher (GameAudio: the launch and its motor; p.kind GUN: a shot)
signal struck(bird: Bird, at: Vector3, keys: Array)   ## a burst hurt `bird`, knocking out feathers `keys` (GameAudio: the puff and its call)

static var blast := 1.3     ## m, burst damage radius (tunable; see Projectile.fuse)
const SHOVE := 4.0          ## m/s, push from a burst at its centre
const HIT_STUN := 0.5       ## s
const FEATHERS_PER_HIT := 2.5   ## on average, within a fuse's reach (Projectile.fuse)
static var recover := 1.0   ## s after a hit in which another knocks out at most RECOVER_FEATHERS (0: off)
const RECOVER_FEATHERS := 1
const GUN_FEATHERS := 1         ## a bullet's, outside the recovery window
const GUN_CHIP := 1.0 / 3.0     ## of a feather, a bullet's inside the recovery window (see the header)
const GUN_SHOVE := 0.6          ## m/s, a bullet's nudge
const TRACER_LEN := 0.012       ## s of a bullet's flight its streak covers (about 1.3 m)
const DOWN_STUN := 2.5      ## s
## A downed bird flutters down out of the fight to the ground (Bird.start_tumble: its wings flail, it drops and rolls,
## and comes down on the ground and sits there) rather than gliding on through the down stun. Off: it glides on.
var down_flutter := true
const SMOKE_EVERY := 0.025  ## s between smoke points
const SMOKE_LIFE := 2.2     ## s

var layout: ArenaLayout
var birds: Array = []
var launchers: Array = []
var projectiles: Array = []
var hits := {}              ## Bird -> hits taken
var teams := {}             ## Bird -> team id
var bases := {}             ## team id -> Perch: where its birds rearm, mend and respawn
var score := {}             ## team id -> enemy birds it has downed
var friendly_hits := 0      ## bursts that hurt a teammate of the shooter (friendly fire is on)
var _next_team := 100       ## (the teams of birds added without one)
const WARN_RANGE := 25.0    ## m: rounds closer than this, heading at a bird, are warned of
const LANE := 1.3           ## m off the line of fire within which a teammate is in the way (a burst's reach)
var _rng := RandomNumberGenerator.new()
## The combat AI doesn't read the air yet (its aim and its stoops reckon on still air): the range and the duels fly
## in still air until it does (Duel.setup, CombatRange). False: the arena's thermals, as in flight.
static var calm_air := true

var _last_hit := {}         ## Bird -> _clock at its last hit (the recovery window)
var _chip := {}             ## Bird -> bullets' feather fractions summed inside the window
var stats := {"shots": 0, "hits": 0, "kills": 0}   ## for the player's launcher (`player`)
var player: Launcher = null

var _next_id := 0
var _smoke: Array = []      ## [{id, pts: [[pos, t]], open}]
var fx: CombatFx            ## what a burst and a hit look like
var _clock := 0.0
var _smoke_mesh: ImmediateMesh
var _tracer_mesh: ImmediateMesh
var tracers_drawn: Array = []   ## [tail, head] of each bullet's streak as last drawn (tests)
var _bodies: Array = []     ## MeshInstance3D per live projectile (pooled)
var _rocket_mesh: Mesh
var _seeker_mesh: Mesh


func _ready() -> void:
	_rng.seed = 7
	_smoke_mesh = ImmediateMesh.new()
	add_child(_mesh_node(_smoke_mesh, _fx_material(false)))
	_tracer_mesh = ImmediateMesh.new()
	add_child(_mesh_node(_tracer_mesh, CombatFx._material(true)))
	fx = CombatFx.new()
	add_child(fx)
	# The rounds as they fly: the very rocket and seeker the pods carry (Saddle.flying_round), at the riders' scale.
	_rocket_mesh = Saddle.flying_round("rockets", Tack.rider_height)
	_seeker_mesh = Saddle.flying_round("seekers", Tack.rider_height)


static func _mesh_node(m: ImmediateMesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _fx_material(bright: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	if bright:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	return m


func add_bird(b: Bird, controller: Object = null, team := -1) -> Launcher:
	birds.append(b)
	hits[b] = 0
	if team < 0:
		team = _next_team
		_next_team += 1
	teams[b] = team
	var l := Launcher.new(b, controller)
	launchers.append(l)
	return l


func remove_bird(b: Bird) -> void:
	birds.erase(b)
	_last_hit.erase(b)
	_chip.erase(b)
	hits.erase(b)
	teams.erase(b)
	for l in launchers.duplicate():
		if l.bird == b:
			launchers.erase(l)


func spawn(p: Projectile) -> void:
	p.id = _next_id
	_next_id += 1
	projectiles.append(p)
	if p.kind == Projectile.Kind.GUN:
		fx.muzzle_flash(p.pos, p.vel - p.carrier, p.carrier, p.gun_mouth if is_instance_valid(p.shooter) else Callable(), p.shooter)
	else:
		_smoke.append({"id": p.id, "pts": [[p.pos, _clock]], "open": true, "kind": p.kind})
	if player != null and p.shooter == player.bird:
		stats.shots += 1
	launched.emit(p)


func _physics_process(dt: float) -> void:
	_clock += dt
	fx.clock = _clock
	for l in launchers:
		if is_instance_valid(l.bird):
			l.step(dt, self)
	for p in projectiles:
		var ev: Dictionary = p.step(dt, layout, birds)
		var trail: Variant = _trail(p.id)
		if trail != null and (trail.pts.is_empty() or _clock - float(trail.pts[-1][1]) >= SMOKE_EVERY or not p.alive):
			trail.pts.append([p.pos, _clock])
		if not ev.is_empty():
			if trail != null:
				trail.open = false
			_burst(ev.burst, p.shooter, String(ev.why), p.kind, String(ev.get("surface", "air")), ev.get("near"))
	projectiles = projectiles.filter(func(q): return q.alive)
	fx.step(dt, self)


## `b`'s team's base, or null.
func base_of(b: Bird) -> Perch:
	return bases.get(teams.get(b, -1), null)


## Bring a downed bird back at its team's base (if it has one): on the rail, every feather back, a full rack.
## Returns whether it was moved.
func respawn(b: Bird) -> bool:
	var at := base_of(b)
	b.mend()
	b.stun = 0.0
	for l in launchers:
		if l.bird == b:
			l.ammo = l.capacity.duplicate()
	if at == null:
		return false
	b.perch_at(at)
	return true


## The rail perch of the outpost farthest from `from` (across the ground), for the other side's base; with no
## outposts, the perch farthest from it.
static func far_base(layout: ArenaLayout, from: Vector3) -> Perch:
	var best: Perch = null
	var best_d := -1.0
	for o in layout.outposts:
		var od := o as ArenaLayout.OutpostData
		var d := Vector2(od.centre.x - from.x, od.centre.z - from.z).length()
		if od.rail_perch_id >= 0 and d > best_d:
			best_d = d
			best = layout.perches[od.rail_perch_id]
	if best != null:
		return best
	for p in layout.perches:
		var d := Vector2(p.position.x - from.x, p.position.z - from.z).length()
		if d > best_d:
			best_d = d
			best = p
	return best


## Are `a` and `b` on the same team? (A bird is its own friend.)
func friends(a: Bird, b: Bird) -> bool:
	return teams.get(a, -1) == teams.get(b, -2)


## The nearest teammate of `l`'s bird in its line of fire: ahead along the aim, 2 to 45 m out, within LANE of the
## line. Null when the lane is clear. (The HUD shows it; firing isn't blocked.)
func friend_in_line(l: Launcher) -> Bird:
	var from := l.muzzle()
	var aim := l.aim()
	var best: Bird = null
	var best_d := INF
	for b in birds:
		if b == l.bird or not is_instance_valid(b) or not friends(b, l.bird):
			continue
		var d: Vector3 = b.global_position - from
		var along := d.dot(aim)
		if along < 2.0 or along > 45.0:
			continue
		if (d - aim * along).length() < LANE and along < best_d:
			best = b
			best_d = along
	return best


## What threatens `b` that it could see (for evading): the nearest projectile within 25 m heading at it, else a
## launcher with a lock on it. Returns the threat's position, or null.
func threat_to(b: Bird) -> Variant:
	var w := warnings_for(b)
	if not (w.rounds as Array).is_empty():
		return w.rounds[0].pos
	if not (w.locks as Array).is_empty():
		return w.locks[0].from
	return null


## What `b` is warned of -- the same for the player's HUD and for any AI (it knows nothing the player isn't
## shown): {rounds: rounds in flight within WARN_RANGE heading at it (within 35 deg) that aren't its own,
## nearest in time first, each {pos, vel, tgo (s to reach it), kind}; locks: launchers holding a lock above half
## on it, strongest first, each {from (the locker's position), lock (0..1), locked}}.
func warnings_for(b: Bird) -> Dictionary:
	var rounds := []
	for p in projectiles:
		if p.shooter == b or not p.alive:
			continue
		var to: Vector3 = b.global_position - p.pos
		var d := to.length()
		var spd: float = p.vel.length()
		if d < WARN_RANGE and spd > 1.0 and p.vel.angle_to(to) < deg_to_rad(35.0):
			rounds.append({"pos": p.pos, "vel": p.vel, "tgo": d / spd, "kind": p.kind})
	rounds.sort_custom(func(x, y): return float(x.tgo) < float(y.tgo))
	var locks := []
	for l in launchers:
		if is_instance_valid(l.bird) and l.bird != b and l.lock_target == b and l.lock > 0.5:
			locks.append({"from": l.bird.global_position, "lock": l.lock, "locked": l.locked()})
	locks.sort_custom(func(x, y): return float(x.lock) > float(y.lock))
	return {"rounds": rounds, "locks": locks}


func _trail(id: int) -> Variant:
	for s in _smoke:
		if s.id == id:
			return s
	return null


func _burst(at: Vector3, by: Variant, why: String, kind := Projectile.Kind.ROCKET, surface := "bird", near: Variant = null) -> void:   # (by: the shooter, possibly freed by now)
	if kind == Projectile.Kind.GUN:
		if why == "expired":
			return   # (a bullet that ran out just goes)
		fx.burst(at, why, kind)
		burst.emit(at, why, kind, surface)
		if why == "hit" and is_instance_valid(near) and birds.has(near):
			hit(near, at, 1.0, by, kind)
		return
	fx.burst(at, why, kind)
	burst.emit(at, why, kind, surface)
	if why == "expired":
		return
	for b in birds:
		if not is_instance_valid(b) or (is_instance_valid(by) and b == by):
			continue
		var d: float = b.global_position.distance_to(at)
		if d > blast:
			continue
		hit(b, at, 1.0 - d / blast, by)


## How many feathers a burst of `strength` (1 - distance / blast) knocks out: within a proximity fuse's reach
## FEATHERS_PER_HIT, rounded up or down at random (2 or 3); beyond it, in the blast's outer ring, 1. (Not graded by
## distance inside the fuse's reach: a fuse goes off as the round enters it, so nearly every burst is at its edge.)
func feathers_for(strength: float) -> int:
	if strength < 1.0 - Projectile.fuse / blast - 1e-4:
		return 1
	return int(floor(FEATHERS_PER_HIT + _rng.randf()))


## How many feathers a bullet hitting `b` now knocks out: GUN_FEATHERS, or inside its recovery window GUN_CHIP of
## one (the fractions summed: a feather each time they make one).
func gun_feathers(b: Bird) -> int:
	if recover <= 0.0 or _clock - float(_last_hit.get(b, -INF)) >= recover:
		_chip[b] = 0.0
		return GUN_FEATHERS
	var c := float(_chip.get(b, 0.0)) + GUN_CHIP
	var n := floori(c + 1e-6)
	_chip[b] = c - n
	return n


## Apply a hit to `b` from a burst at `at` (strength 0..1), or (kind GUN) a bullet striking it there.
func hit(b: Bird, at: Vector3, strength: float, by: Variant = null, kind := Projectile.Kind.ROCKET) -> void:
	var gun := kind == Projectile.Kind.GUN
	hits[b] = int(hits.get(b, 0)) + 1
	if is_instance_valid(by) and by != b and teams.has(by) and friends(by, b):
		friendly_hits += 1
	var was_up := not b.is_down()
	var by_player: bool = player != null and is_instance_valid(by) and by == player.bird
	if by_player:
		stats.hits += 1
	var away: Vector3 = (b.global_position - at)
	away = away.normalized() if away.length() > 0.01 else Vector3.UP
	b.model.velocity += away * (GUN_SHOVE if gun else SHOVE * (0.4 + 0.6 * strength))
	if not gun:
		b.stun = maxf(b.stun, HIT_STUN)
	var n := gun_feathers(b) if gun else feathers_for(strength)
	if not gun and recover > 0.0 and _clock - float(_last_hit.get(b, -INF)) < recover:
		n = mini(n, RECOVER_FEATHERS)
	_last_hit[b] = _clock
	var keys := b.lose_feathers(at, n)
	fx.knocked_out(b, at, keys, away)
	struck.emit(b, at, keys)
	if was_up and b.is_down():
		b.stun = DOWN_STUN
		if down_flutter:
			b.start_tumble()
		if by_player:
			stats.kills += 1
		if is_instance_valid(by) and teams.has(by) and not friends(by, b):
			score[teams[by]] = int(score.get(teams[by], 0)) + 1
		downed.emit(b)


# --- Drawing ----------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var eye := cam.global_position if cam != null else Vector3.ZERO
	var lag := Bird.drawn_lag()
	var heads := _draw_bodies(lag)
	_draw_smoke(eye, _clock - lag, heads)
	_draw_tracers(eye, heads, lag)
	fx.draw(eye, _clock - lag, lag)
	# Forget what has faded.
	_smoke = _smoke.filter(func(s): return s.open or (s.pts.size() > 0 and _clock - float(s.pts[-1][1]) < SMOKE_LIFE))


const ROUND_GROW := 2.0   ## a rocket or seeker in flight is drawn up to this x its true size
const GROW_OVER := 4.0    ## m it flies before it's drawn that big


## Each projectile where it is at the drawn moment: between its last two ticks, as the birds are (placed here each
## frame, so not interpolated again by the engine). Returns {id: drawn position}, where its smoke starts.
func _draw_bodies(lag: float) -> Dictionary:
	var f := 1.0 - lag * Engine.physics_ticks_per_second
	var heads := {}
	while _bodies.size() < projectiles.size():
		var mi := MeshInstance3D.new()
		mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_bodies.append(mi)
	for i in _bodies.size():
		var mi: MeshInstance3D = _bodies[i]
		if i >= projectiles.size():
			mi.visible = false
			continue
		var p: Projectile = projectiles[i]
		if p.kind == Projectile.Kind.GUN:   # (a bullet: its tracer streak, _draw_tracers)
			mi.visible = false
			heads[p.id] = p.last_pos.lerp(p.pos, f)
			continue
		mi.visible = true
		mi.mesh = _rocket_mesh if p.kind == Projectile.Kind.ROCKET else _seeker_mesh
		var d := p.vel.normalized() if p.vel.length() > 0.1 else Vector3.FORWARD
		var side := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
		# (leaving the pod at its true size, growing to ROUND_GROW of it over its first GROW_OVER m, so it still reads
		# out there; its smoke trail carries it further)
		var grow := lerpf(1.0, ROUND_GROW, smoothstep(0.0, GROW_OVER, p.travelled))
		var at := p.last_pos.lerp(p.pos, f)
		heads[p.id] = at
		mi.global_transform = Transform3D(Basis(side, d, side.cross(d)).scaled(Vector3.ONE * grow), at)   # capsule's long axis is Y
	return heads


## Bullets: a hot streak each, from where it's drawn back along its flight (TRACER_LEN s of it, no further back than
## the gun's mouth: the gun flies on with its bird, so not to where it left the gun -- the bird has flown past that,
## and the streak would come out of its back), facing the camera, a little wider far off so it still reads as a line.
## `tracers_drawn`: each streak's [tail, head] this frame (tests).
func _draw_tracers(eye: Vector3, heads: Dictionary, lag := 0.0) -> void:
	_tracer_mesh.clear_surfaces()
	tracers_drawn.clear()
	var started := false
	for p: Projectile in projectiles:
		if p.kind != Projectile.Kind.GUN or not heads.has(p.id):
			continue
		var a: Vector3 = heads[p.id]
		var back := p.vel * TRACER_LEN
		var ahead := (p.vel - p.carrier).length() * maxf(p.age - lag, 0.0)   # (how far it's out of the gun, at the drawn moment)
		if p.gun_mouth.is_valid() and is_instance_valid(p.shooter):   # (better: from the barrel as it's drawn now)
			ahead = maxf((a - (p.gun_mouth.call() as Vector3)).dot(p.vel.normalized()), 0.0)
		if back.length() > ahead:
			back = back.normalized() * ahead
		var b := a - back
		tracers_drawn.append([b, a])
		var seg := a - b
		if seg.length() < 1e-3:
			continue
		var side := seg.cross(eye - a).normalized()
		var w := clampf(eye.distance_to(a) * 0.0022, 0.006, 0.08)   # (about 1.5 px wide at any range)
		var head := Color(2.6, 1.7, 0.7, 1.0)
		var tail := Color(1.2, 0.5, 0.15, 0.0)
		if not started:
			_tracer_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			started = true
		_quad(_tracer_mesh, b - side * w * 0.5, b + side * w * 0.5, a + side * w, a - side * w, tail, tail, head, head)
	if started:
		_tracer_mesh.surface_end()


## Smoke ribbons: each trail's points as a camera-facing strip that widens and fades with age, as of `now` (the drawn
## moment): the points laid since then left out, a live round's trail running on to where it is drawn (`heads`).
func _draw_smoke(eye: Vector3, now: float, heads: Dictionary) -> void:
	_smoke_mesh.clear_surfaces()
	var any := false
	for s in _smoke:
		if s.pts.size() >= 2:
			any = true
			break
	if not any:
		return
	var started := false
	for s in _smoke:
		var pts := smoke_points(s, now, heads)
		var seeker: bool = s.kind == Projectile.Kind.SEEKER
		for i in range(1, pts.size()):
			var a: Vector3 = pts[i - 1][0]
			var b: Vector3 = pts[i][0]
			var age_a := now - float(pts[i - 1][1])
			var age_b := now - float(pts[i][1])
			if age_b > SMOKE_LIFE:
				continue
			var seg := b - a
			if seg.length() < 1e-4:
				continue
			var side := seg.cross(eye - b).normalized()
			var wa := _smoke_w(age_a)
			var wb := _smoke_w(age_b)
			var ca := _smoke_col(age_a, seeker)
			var cb := _smoke_col(age_b, seeker)
			# Smoke right by the camera would fill the screen: fade it out up close (your own launch is thin
			# enough to show from the chase camera).
			ca.a *= smoothstep(0.3, 1.5, eye.distance_to(a))
			cb.a *= smoothstep(0.3, 1.5, eye.distance_to(b))
			if ca.a < 0.01 and cb.a < 0.01:
				continue
			if not started:
				_smoke_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
				started = true
			_quad(_smoke_mesh, a - side * wa, a + side * wa, b + side * wb, b - side * wb, ca, ca, cb, cb)
	if started:
		_smoke_mesh.surface_end()


## A smoke trail's points [pos, t] as of `now`: those laid by then, and a live round's (in `heads`) drawn position.
static func smoke_points(s: Dictionary, now: float, heads: Dictionary) -> Array:
	var pts: Array = (s.pts as Array).filter(func(q): return float(q[1]) <= now)
	if heads.has(s.id):
		pts.append([heads[s.id], now])
	return pts


## A trail's half width at `age` s: a thread at the pod's mouth, puffing out over the first moments, then
## spreading as it hangs.
func _smoke_w(age: float) -> float:
	return 0.004 + 0.026 * smoothstep(0.0, 0.2, age) + 0.18 * minf(age / SMOKE_LIFE, 1.0)


func _smoke_col(age: float, seeker: bool) -> Color:
	var a := 0.75 * (1.0 - clampf(age / SMOKE_LIFE, 0.0, 1.0))
	return Color(0.93, 0.92, 0.9, a) if not seeker else Color(0.95, 0.9, 0.86, a)


## Bursts (a flash disc and a ring of sparks) and drifting feathers, all camera-facing, as of `now` (the drawn moment,
## `lag` behind the last tick).
static func _quad(m: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	for v in [[a, ca], [b, cb], [c, cc], [a, ca], [c, cc], [d, cd]]:
		m.surface_set_color(v[1])
		m.surface_add_vertex(v[0])
