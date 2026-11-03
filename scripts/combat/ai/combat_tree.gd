class_name CombatTree
extends RefCounted
## The combat AI's behaviour tree (docs/design/combat_ai.md, 3.2), built in code on Beehave. Ticked by hand once
## per physics tick from CombatBrain.tick. Every action returns SUCCESS (so the tree runs from the top each tick
## and a higher branch takes over the moment its condition holds); manoeuvres that last are kept by the brain's
## timers (defend_until, extend_until), not by RUNNING nodes.
##
##   Selector
##   |- Defend    [Threatened?]  -> Defend         rounds, locks, a nose on my tail
##   |- Recover   [Stunned?]     -> HoldLevel
##   |- Rearm     [OutOfAmmo?]   -> GoRearm        home to the base: the only place rounds restock
##   |- Rest      [NeedsRest?]   -> GoRest         tired: a perch; hurt: the base (feathers grow back there)
##   |- Fight     [HasTarget?]   -> Selector
##   |    |- Extend    [Outmatched?] -> Extend
##   |    |- Attack    [InEnvelope?] -> Attack     pursuit for the weapon, weapons free
##   |    '- Reposition                            behind and (by style) above it
##   '- Patrol                                     loiter near the base at the style's height


static func build(brain: CombatBrain) -> BeehaveTree:
	var tree := BeehaveTree.new()
	tree.process_thread = BeehaveTree.ProcessThread.MANUAL
	tree.actor = brain.bird
	tree.blackboard.blackboard = {"brain": brain}   # (the exported dictionary: set_value() is wiped when the blackboard enters the tree)
	var root := SelectorComposite.new()
	root.add_child(_seq("Defend", [Threatened.new(), Defend.new()]))
	root.add_child(_seq("Recover", [Stunned.new(), HoldLevel.new()]))
	root.add_child(_seq("Rearm", [OutOfAmmo.new(), GoRearm.new()]))
	root.add_child(_seq("Rest", [NeedsRest.new(), GoRest.new()]))
	var fight := SelectorComposite.new()
	fight.add_child(_seq("Extend", [Outmatched.new(), Extend.new()]))
	fight.add_child(_seq("Attack", [InEnvelope.new(), Attack.new()]))
	fight.add_child(Reposition.new())
	root.add_child(_seq("Fight", [HasTarget.new(), fight]))
	root.add_child(Patrol.new())
	tree.add_child(root)
	return tree


static func _seq(n: String, kids: Array) -> SequenceComposite:
	var s := SequenceComposite.new()
	s.name = n
	for k in kids:
		s.add_child(k)
	return s


static func _brain(bb: Blackboard) -> CombatBrain:
	return bb.get_value("brain")


## Horizontal unit vector at right angles to `v` (+ = its right).
static func _across(v: Vector3) -> Vector3:
	var h := Vector3(v.x, 0.0, v.z)
	return Vector3(-h.z, 0.0, h.x).normalized() if h.length() > 1e-3 else Vector3.RIGHT


## The point to steer at to fly along `dir` from the bird.
static func _toward(b: Bird, dir: Vector3, dist := 30.0) -> Vector3:
	return b.global_position + dir.normalized() * dist


## Keep a bird that doesn't fight low out of the understory.
static func _floor(brain: CombatBrain, p: Vector3) -> Vector3:
	if not brain.style.understory_ok:
		p.y = maxf(p.y, ArenaLayout.TIERS[0].h.y + 1.0)
	return p


# --- Conditions -------------------------------------------------------------------------------------

## A round coming that will hit or nearly, a lock on me, or an enemy's nose on my tail close in -- or a break
## still being flown.
class Threatened extends ConditionLeaf:
	func tick(_actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		if br.clock < br.defend_until:
			return SUCCESS
		var pic := br.picture
		var reach := FireControl.reach()
		for th in pic.threats:
			if th.guided or float(th.miss) < reach * 1.5:
				return SUCCESS
		if pic.locked:
			return SUCCESS
		for t in pic.enemies():
			if t.visible and br.attacking(t, br.bird) and t.pos.distance_to(br.bird.global_position) < 30.0:
				return SUCCESS
		return FAILURE


class Stunned extends ConditionLeaf:
	func tick(actor: Node, _bb: Blackboard) -> int:
		return SUCCESS if (actor as Bird).stun > 0.0 else FAILURE


## Out of rounds (and, once on the way, until the rack is full again).
class OutOfAmmo extends ConditionLeaf:
	func tick(_actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		if int(br.launcher.capacity[br.launcher.weapon]) == 0:
			return FAILURE
		if br.ammo_left() == 0 or (br.intent.mode == "rearm" and not br.ammo_full()):
			return SUCCESS
		return FAILURE


## Tired (stamina under skill.rest_at) or hurt (half its feathers gone); once resting, until rested and mended.
class NeedsRest extends ConditionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var b := actor as Bird
		var st: float = b.model.energy.stamina
		if st < br.skill.rest_at or b.health() <= 0.5:
			return SUCCESS
		if br.intent.mode == "rest" and (st < 0.6 or (b.health() < 1.0 and br.world.base_of(b) != null)):
			return SUCCESS
		return FAILURE


class HasTarget extends ConditionLeaf:
	func tick(_actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		return SUCCESS if br.target != null and is_instance_valid(br.target) and br.picture.track_of(br.target) != null else FAILURE


## An enemy on my tail with the energy on me (or an extension still being flown).
class Outmatched extends ConditionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		if br.clock < br.extend_until:
			return SUCCESS
		var b := actor as Bird
		var my_e := Engagement.energy_height(b.global_position, b.model.velocity)
		for t in br.picture.enemies():
			if br.attacking(t, b) and Engagement.energy_height(t.pos, t.vel) > my_e + 2.0 and br.style.prefers_height:
				br.extend_until = br.clock + 2.0
				return SUCCESS
		return FAILURE


## The target close enough and near enough my nose to fly a shot at it.
class InEnvelope extends ConditionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var b := actor as Bird
		var t := br.picture.track_of(br.target)
		if t == null or not t.visible:
			return FAILURE
		var d := b.global_position.distance_to(t.pos)
		var off := Engagement.ata(b.global_position, b.model.flight_dir(), t.pos)
		var keep := 1.3 if br.intent.mode == "attack" else 1.0   # (hysteresis)
		return SUCCESS if d < 40.0 * keep and off < deg_to_rad(55.0) * keep else FAILURE


# --- Actions ----------------------------------------------------------------------------------------

## Break across the threat: a seeker (late, at its break time; before that, run from it), a rocket (sidestep
## its line), a lock (turn across the attacker's line of sight), a nose on my tail (break toward its side).
class Defend extends ActionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var b := actor as Bird
		var i := br.intent
		i.mode = "defend"
		i.opts.bank_frac = maxf(br.skill.bank_frac, 0.95)
		i.opts.flap = "sprint"
		var pos := b.global_position
		var fd := b.model.flight_dir()
		if br.clock < br.defend_until:
			i.aim = CombatTree._toward(b, br.defend_dir)
			return SUCCESS
		var worst: Variant = null
		for th in br.picture.threats:
			if worst == null or float(th.tgo) < float(worst.tgo):
				worst = th
		if worst != null:
			var vdir: Vector3 = (worst.vel as Vector3).normalized()
			var rel: Vector3 = pos - (worst.pos as Vector3)
			var off := rel - vdir * rel.dot(vdir)
			var side := CombatTree._across(vdir)
			side *= signf(side.dot(off)) if absf(side.dot(off)) > 0.05 else signf(side.dot(fd))
			var noise := br.rng.randf_range(-1.0, 1.0) * br.skill.break_error
			var break_at: float = br.style.seeker_break_tgo if worst.guided else 0.5
			if float(worst.tgo) <= break_at + noise:
				br.defend_dir = side
				br.defend_until = br.clock + 0.6
				i.opts.gamma = deg_to_rad(8.0)
				i.aim = CombatTree._toward(b, side)
			elif worst.guided:
				i.aim = CombatTree._toward(b, Vector3(rel.x, 0.0, rel.z))   # (drag it: run, so it burns out)
			else:
				i.aim = CombatTree._toward(b, fd)
			return SUCCESS
		var from: Vector3 = br.picture.locked_from if br.picture.locked else Vector3.INF
		if from == Vector3.INF:
			for t in br.picture.enemies():
				if t.visible and br.attacking(t, b):
					from = t.pos
					break
		if from != Vector3.INF:
			var side := CombatTree._across(fd) * Engagement.side_of(pos, fd, from)   # (toward its side: its nose can't follow)
			br.defend_dir = side
			br.defend_until = br.clock + 0.8
			i.aim = CombatTree._toward(b, side)
		else:
			i.aim = CombatTree._toward(b, fd)
		return SUCCESS


class HoldLevel extends ActionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var b := actor as Bird
		br.intent.mode = "recover"
		br.intent.aim = CombatTree._toward(b, Vector3(b.model.flight_dir().x, 0.0, b.model.flight_dir().z))
		br.intent.opts.gamma = 0.0
		return SUCCESS


## Home to the team's base to rearm (with no base, any perch in reach rearms).
class GoRearm extends ActionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		br.intent.mode = "rearm"
		var base := br.world.base_of(actor as Bird)
		br.intent.perch = base if base != null else CombatTree._nearest_perch(br)
		return SUCCESS if br.intent.perch != null else FAILURE


## Rest: hurt, to the base (feathers grow back only there); tired, the base if near, else a perch in reach.
class GoRest extends ActionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var b := actor as Bird
		br.intent.mode = "rest"
		var base := br.world.base_of(b)
		if base != null and (b.health() < 1.0 or base.position.distance_to(b.global_position) < 60.0):
			br.intent.perch = base
		elif b.state == Bird.State.PERCHED and b.perch != null:
			br.intent.perch = b.perch
		else:
			br.intent.perch = CombatTree._nearest_perch(br)
		return SUCCESS if br.intent.perch != null else FAILURE


## A perch the flight AI can reach from here (its own choice, kept while it flies there).
static func _nearest_perch(br: CombatBrain) -> Perch:
	if br.pilot.target != null and br.intent.mode in ["rest", "rearm"]:
		return br.pilot.target
	var budget: float = 6.0 * br.bird.model.energy.stamina
	return br.pilot._best_perch(br.bird, budget, 2.0 + br.style.v_stall * 0.35)


## Run along the clearest line away from the enemies, flapping, a little downhill for speed.
class Extend extends ActionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var b := actor as Bird
		br.intent.mode = "extend"
		var away := Vector3.ZERO
		for t in br.picture.enemies():
			var d: Vector3 = b.global_position - t.pos
			away += d / maxf(d.length_squared(), 1.0)
		if away.length() < 1e-4:
			away = b.model.flight_dir()
		br.intent.aim = CombatTree._floor(br, CombatTree._toward(b, Vector3(away.x, -0.1, away.z)))
		br.intent.opts.flap = "sprint"
		return SUCCESS


## Fly the shot: rockets lead the target (cut inside its turn), seekers point at it to hold the lock cone.
## Too close and closing fast, lag behind its wing line (or, knowing the yo-yo, climb out of its plane).
class Attack extends ActionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var b := actor as Bird
		var t := br.picture.track_of(br.target)
		var i := br.intent
		i.mode = "attack"
		i.target = br.target
		i.fire = true
		var pos := b.global_position
		var d := pos.distance_to(t.pos)
		var close := Engagement.closure(pos, b.model.velocity, t.pos, t.vel)
		var aim: Vector3
		if br.launcher.weapon == Launcher.Weapon.ROCKETS:
			aim = br.rocket_lead(t)
		else:
			aim = t.pos
		if d < 10.0 and close > 4.0:
			if br.skill.yoyos and close > 6.0:
				i.opts.gamma = deg_to_rad(25.0)   # high yo-yo: out of its plane, then back down on it
			aim = Engagement.lag_point(t.pos, t.vel, 6.0)
			i.opts.flap = "none"
		else:
			i.opts.flap = "hold"
			i.opts.speed = clampf(t.vel.length() + 1.5, br.style.v_best * 0.9, br.style.v_best * 1.4)
		var err := deg_to_rad(br.skill.aim_error_deg)
		var to := aim - pos
		aim = pos + to.rotated(Vector3.UP, br.rng.randf_range(-err, err))
		i.aim = CombatTree._floor(br, aim)
		return SUCCESS


## Get into a shooting position: behind it, and above by the style's energy wanted.
class Reposition extends ActionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var b := actor as Bird
		var t := br.picture.track_of(br.target)
		var i := br.intent
		i.mode = "engage"
		i.target = br.target
		var d := b.global_position.distance_to(t.pos)
		if br.launcher.weapon == Launcher.Weapon.SEEKERS and d < Launcher.LOCK_RANGE.y and t.visible:
			# In lock range with seekers: point at it (a lock needs it in the cone for a second), from above if wanted.
			i.aim = CombatTree._floor(br, t.pos + Vector3.UP * (2.0 if br.style.prefers_height else 0.0))
			i.opts.flap = "hold"
			i.opts.speed = br.style.v_best * 1.1
			return SUCCESS
		var behind := Engagement.lag_point(t.pos, t.vel, 15.0)
		var my_e := Engagement.energy_height(b.global_position, b.model.velocity)
		var short := br.style.want_delta_e - (my_e - Engagement.energy_height(t.pos, t.vel))
		behind.y += clampf(short, 0.0, 10.0) + (3.0 if br.style.prefers_height else 1.0)
		i.aim = CombatTree._floor(br, behind)
		i.opts.flap = "hold"
		i.opts.speed = br.style.v_best * 1.1
		return SUCCESS


## No target: loiter in a wide circle over the base (or the arena's middle) at the style's height, looking.
class Patrol extends ActionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var b := actor as Bird
		var i := br.intent
		i.mode = "patrol"
		var base := br.world.base_of(b)
		var c := base.position if base != null else Vector3.ZERO
		var y := (br.style.height_band.x + br.style.height_band.y) * 0.5
		var rel := Vector3(b.global_position.x - c.x, 0.0, b.global_position.z - c.z)
		var ang := atan2(rel.z, rel.x) + 0.6
		i.aim = Vector3(c.x + cos(ang) * 25.0, y, c.z + sin(ang) * 25.0)
		i.opts.flap = "auto"
		return SUCCESS
