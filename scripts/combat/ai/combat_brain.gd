class_name CombatBrain
extends RefCounted
## A combat AI bird's mind (docs/design/combat_ai.md, 3 and 4): sense -> decide -> an Intent that the two
## controllers act on (CombatPilot flies it, AICombat fires by it). Ticked once per physics tick by whichever
## controller asks first. Deciding is a Beehave behaviour tree (CombatTree), its leaves thin: conditions read
## the blackboard, actions write the Intent; the numbers come from the pure classes (Engagement, FireControl,
## CombatStyle).
## Target choice (4.2) runs every `skill.decide_every` s: closer, on the nose, its tail toward me, my height on
## it, its feathers gone, it attacking me or a teammate; spread from teammates on it; the current one kept unless
## another is clearly better.


## What the brain wants this tick.
class Intent:
	var mode := "patrol"            ## patrol, engage, attack, defend, extend, recover, rest, rearm
	var aim := Vector3.ZERO         ## where to fly (AIPilot.steer)
	var opts := {}                  ## steer() options (bank_frac, gamma, flap, speed)
	var fire := false               ## weapons free (fire control still decides each shot)
	var target: Bird = null
	var perch: Perch = null         ## rest / rearm: land here (the flight is AIPilot's)


var bird: Bird
var world: CombatWorld
## Its launcher, held weakly: the launcher holds AICombat, which holds this brain.
var launcher: Launcher:
	get:
		return _launcher.get_ref() if _launcher != null else null
var _launcher: WeakRef
var style: CombatStyle
var skill: CombatSkill
var sense: CombatSense
var pilot: AIPilot               ## the flight AI it steers with (CombatPilot's)
var picture: CombatSense.Picture
var intent := Intent.new()
var target: Bird = null
var tree: BeehaveTree
var clock := 0.0
var rng := RandomNumberGenerator.new()
var _frame := -1
var _next_decide := 0.0
var _mode_since := 0.0
## Extend / defend timers the tree's actions keep between ticks.
var extend_until := 0.0
var defend_until := 0.0
var defend_dir := Vector3.ZERO
var defend_gamma := 0.0
var jink_side := 0.0            ## the way the last break into an attacker went (+1 right, -1 left; 0: none)
var cover_tree := -1            ## the trunk it is dragging a seeker past
var cover_side := 0.0           ## the side it passes that trunk on (across the seeker's line; 0: not picked)
var stats := {"modes": {}}


func _init(b: Bird, w: CombatWorld, l: Launcher, sk: CombatSkill = null, seed := 1) -> void:
	bird = b
	world = w
	_launcher = weakref(l)
	skill = sk if sk != null else CombatSkill.preset("pilot")
	style = CombatStyle.of(b.profile)
	sense = CombatSense.new(b, w, skill)
	pilot = AIPilot.new(w.layout, seed)
	rng.seed = seed
	tree = CombatTree.build(self)
	b.add_child(tree)


## Sense and decide, once per physics tick (both controllers call it; the second call is a no-op).
func tick(dt: float) -> void:
	var f := Engine.get_physics_frames()
	if f == _frame or launcher == null:   # (no launcher: taken out of the fight)
		return
	_frame = f
	clock += dt
	var p0 := Perf.t()
	picture = sense.update(dt)
	Perf.add("ai.combat.sense", p0)
	p0 = Perf.t()
	if clock >= _next_decide:
		_next_decide = clock + skill.decide_every
		target = choose_target()
	var was := intent.mode
	intent.fire = false
	intent.perch = null
	intent.opts = {"bank_frac": skill.bank_frac}
	tree.tick()
	if intent.mode != "defend":
		# Turn no harder than the lift allows at this speed (with a margin): a sustained over-banked turn bleeds
		# the speed away into a stall spiral. A defensive break pulls to the limit for its moment.
		intent.opts.bank_frac = minf(float(intent.opts.get("bank_frac", skill.bank_frac)), style.lift_bank(bird.model.speed) / style.max_bank)
	if intent.mode != was:
		_mode_since = clock
	stats.modes[intent.mode] = float(stats.modes.get(intent.mode, 0.0)) + dt
	Perf.add("ai.combat.brain", p0)


func mode_age() -> float:
	return clock - _mode_since


## The enemy to fight, or null (4.2).
func choose_target() -> Bird:
	var best: Bird = null
	var best_score := -INF
	var my_pos := bird.global_position
	var fd := bird.model.flight_dir()
	var my_e := Engagement.energy_height(my_pos, bird.model.velocity)
	for tr in picture.enemies():
		var t: CombatSense.Track = tr
		if not is_instance_valid(t.bird) or t.bird.is_down():
			continue
		var rng_m := my_pos.distance_to(t.pos)
		var score := -rng_m / 20.0
		score -= Engagement.ata(my_pos, fd, t.pos) / deg_to_rad(45.0)
		score -= Engagement.aa(my_pos, t.pos, t.vel) / deg_to_rad(90.0)
		score += clampf((my_e - Engagement.energy_height(t.pos, t.vel)) / 5.0, -2.0, 2.0)
		score += 2.0 * (1.0 - t.bird.health())
		if attacking(t, bird):
			score += 2.0
		else:
			for f in picture.tracks:
				if not f.enemy and is_instance_valid(f.bird) and attacking(t, f.bird):
					score += 2.0
					break
		if not t.visible:
			score -= 1.0
		if t.bird == target:
			score += 1.5   # (hysteresis: keep the one it has unless another is clearly better)
		if score > best_score:
			best_score = score
			best = t.bird
	return best


## Is the bird of track `t` attacking `victim`: within 35 m behind it, its nose on it?
func attacking(t: CombatSense.Track, victim: Bird) -> bool:
	var vp := victim.global_position
	var d := t.pos.distance_to(vp)
	return d < 35.0 and t.vel.length() > 1.0 and Engagement.ata(t.pos, t.vel.normalized(), vp) < deg_to_rad(30.0)


## Does the bird of track `t` sit where it could shoot me: its nose within 25 deg of me, inside 30 m from any side,
## or -- carrying seekers -- out to lock range from behind me? (Seen, as a player sees a bird behind them lining up,
## and the pods on its saddle.) A rocket bird further back can't reach me; turning into it would only close the range.
func in_firing_position(t: CombatSense.Track) -> bool:
	if picture.clock - t.seen_at > RECALL or t.vel.length() < 1.0:   # (seen just now, or a moment ago: a bird on my tail is still there between looks)
		return false
	var me := bird.global_position
	var d := t.pos.distance_to(me)
	if d > FIRING_RANGE or Engagement.ata(t.pos, t.vel.normalized(), me) > deg_to_rad(25.0):
		return false
	return d < 30.0 or (t.seekers and Engagement.ata(me, bird.model.flight_dir(), t.pos) > deg_to_rad(100.0))


const FIRING_RANGE := 42.0
const RECALL := 1.0             ## s a bird seen in firing position is still taken to be there


## Give a launcher that isn't armed from mounts the style's one kind of round: six rockets or four seekers.
static func arm(l: Launcher, st: CombatStyle) -> void:
	var rockets := st.weapon == Launcher.Weapon.ROCKETS
	l.capacity = {Launcher.Weapon.ROCKETS: Launcher.AMMO[Launcher.Weapon.ROCKETS] if rockets else 0, Launcher.Weapon.SEEKERS: 0 if rockets else Launcher.AMMO[Launcher.Weapon.SEEKERS]}
	l.ammo = l.capacity.duplicate()
	l.weapon = st.weapon


var _lead_at := -INF
var _lead := Vector3.ZERO
var _lead_for: Bird = null


## Where to fly the gunsight for a rocket to meet track `t` (FireControl.lead, refreshed every LEAD_EVERY s and
## carried along with the target in between).
func rocket_lead(t: CombatSense.Track) -> Vector3:
	if clock - _lead_at >= LEAD_EVERY or _lead_for != t.bird:
		_lead = FireControl.lead(launcher.muzzle(), bird.model.velocity, t.pos, t.vel) - t.pos
		_lead_at = clock
		_lead_for = t.bird
	return t.pos + _lead


const LEAD_EVERY := 0.1


## Ammo left / full.
func ammo_left() -> int:
	return int(launcher.ammo[launcher.weapon])


func ammo_full() -> bool:
	return int(launcher.ammo[launcher.weapon]) >= int(launcher.capacity[launcher.weapon])
