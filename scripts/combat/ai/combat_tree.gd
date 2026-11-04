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
##   |- Ambush                                     (an ambusher) sit high on a perch, drop on a bird passing below
##   |- Fight     [HasTarget?]   -> Selector
##   |    |- Extend    [Outmatched?] -> Extend
##   |    |- BoomZoom  [EnergyFighter?] -> BoomAndZoom   climb above it, stoop through with rockets, zoom back up
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
	root.add_child(Ambush.new())
	var fight := SelectorComposite.new()
	fight.add_child(_seq("Extend", [Outmatched.new(), Extend.new()]))
	fight.add_child(_seq("BoomZoom", [EnergyFighter.new(), BoomAndZoom.new()]))
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

## A round coming that will hit or nearly, a lock on me, or an enemy in firing position (its nose on me, close in or
## behind me out to lock range) -- or a break still being flown.
class Threatened extends ConditionLeaf:
	func tick(_actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		if br.clock < br.defend_until:
			return SUCCESS
		var pic := br.picture
		var reach := FireControl.reach()
		for th in pic.threats:
			if th.kind == Projectile.Kind.GUN:
				continue   # (bullets: too fast to dodge -- the bird firing them, lined up on it, is the reason to break)
			if th.guided or float(th.miss) < reach * 1.5:
				return SUCCESS
		if pic.locked:
			return SUCCESS
		for t in pic.enemies():
			if br.in_firing_position(t):
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


## A style that fights on its energy (hawk, falcon: slow to roll or a high stall), against a target it can see.
class EnergyFighter extends ConditionLeaf:
	func tick(_actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var t := br.picture.track_of(br.target)
		return SUCCESS if br.style.prefers_height and t != null and t.visible else FAILURE


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

## Defend, before the round is in the air where it can (a level break doesn't beat a locked seeker in this flight model,
## nor a rocket fired from inside ~15 m):
##   a seeker coming -- drag it past a trunk (skill.tree_drag): fly to put the trunk between us, so its lead pursuit
##     cuts through the wood; with no trunk in reach, fly across its line (off its gimbal) and break at the style's
##     break time;
##   a rocket coming close -- sidestep across its line at 0.5 s to go;
##   a lock on me, or an enemy in firing position -- jink: hard turns across its line of sight, each a random
##     0.35-0.7 s, alternating sides and up and down, the first toward its side (its nose can't follow; it can't hold
##     the lock cone, or a lead on a bird that keeps changing its mind).
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
		var worst: Variant = null
		for th in br.picture.threats:
			if th.kind != Projectile.Kind.GUN and (worst == null or float(th.tgo) < float(worst.tgo)):
				worst = th
		if worst != null and worst.guided and br.skill.tree_drag:
			var cover := CombatTree._trunk_cover(br, worst)
			if cover != Vector3.INF:
				br.defend_until = 0.0
				i.aim = cover
				i.opts.gamma = 0.0
				return SUCCESS
		if br.clock < br.defend_until:
			i.aim = CombatTree._toward(b, br.defend_dir)
			i.opts.gamma = br.defend_gamma
			i.opts.lift_cap = br.jink_side != 0.0
			return SUCCESS
		if worst != null:
			br.jink_side = 0.0
			var vdir: Vector3 = (worst.vel as Vector3).normalized()
			var rel: Vector3 = pos - (worst.pos as Vector3)
			var off := rel - vdir * rel.dot(vdir)
			var side := CombatTree._across(vdir)
			side *= signf(side.dot(off)) if absf(side.dot(off)) > 0.05 else signf(side.dot(fd))
			var noise := br.rng.randf_range(-1.0, 1.0) * br.skill.break_error
			var break_at: float = br.style.seeker_break_tgo if worst.guided else 0.5
			if float(worst.tgo) <= break_at + noise:
				br.defend_dir = side
				br.defend_gamma = deg_to_rad(8.0)
				br.defend_until = br.clock + 0.6
				i.opts.gamma = br.defend_gamma
				i.aim = CombatTree._toward(b, side)
			elif worst.guided:
				i.aim = CombatTree._toward(b, side)   # (across its line: off its gimbal, if it can't turn with me)
			else:
				i.aim = CombatTree._toward(b, fd)
			return SUCCESS
		var from: Vector3 = br.picture.locked_from if br.picture.locked else Vector3.INF
		if from == Vector3.INF:
			for t in br.picture.enemies():
				if br.in_firing_position(t):
					from = t.pos
					break
		if from == Vector3.INF:
			br.jink_side = 0.0
			i.aim = CombatTree._toward(b, fd)
			return SUCCESS
		# Break into it: turn toward its side, so its nose has to come across mine; re-picked every segment.
		var go := Engagement.side_of(pos, fd, from)
		br.jink_side = go
		br.defend_dir = CombatTree._across(fd) * go
		br.defend_gamma = deg_to_rad(br.rng.randf_range(4.0, 12.0)) * (1.0 if br.rng.randf() < 0.5 else -1.0)
		if pos.y < br.style.height_band.x:
			br.defend_gamma = absf(br.defend_gamma)   # (low down: never jink toward the ground)
		elif b.model.speed < br.style.v_best:
			br.defend_gamma = -absf(br.defend_gamma)   # (slow: never climb in a break, or it stalls)
		br.defend_gamma = clampf(br.defend_gamma, b.model.path_angle - deg_to_rad(12.0), b.model.path_angle + deg_to_rad(12.0))   # (nor pull out of a dive into one)
		i.opts.lift_cap = true   # (breaks one after another are a sustained turn: within what the lift holds)
		br.defend_until = br.clock + br.rng.randf_range(0.35, 0.7)
		i.aim = CombatTree._toward(b, br.defend_dir)
		i.opts.gamma = br.defend_gamma
		return SUCCESS


## Where to fly to drag seeker `th` past a trunk, if one stands within reach -- ahead of me, one I can pass before the
## seeker catches me -- else Vector3.INF. The trunk, once picked, is kept while the seeker comes. The way: close past
## its edge on the side I'm heading for, hook in behind it (as seen from the seeker), then on along that line, so the seeker's lead
## pursuit, cutting the corner, runs into the wood.
static func _trunk_cover(br: CombatBrain, th: Dictionary) -> Vector3:
	var layout := br.world.layout
	if layout == null:
		return Vector3.INF
	var b := br.bird
	var pos := b.global_position
	var sp: Vector3 = th.pos
	var tree: ArenaLayout.TreeData = layout.trees[br.cover_tree] if br.cover_tree >= 0 and br.cover_tree < layout.trees.size() else null
	if tree == null or Vector2(pos.x, pos.z).distance_to(tree.base) > 16.0:
		tree = null
		var fd := b.model.flight_dir()
		var fh := Vector3(fd.x, 0.0, fd.z).normalized()
		var s_speed := maxf((th.vel as Vector3).length(), 1.0)
		var best_t := INF
		for t in layout.trees_near_segment(pos, pos + fh * 10.0, 8.0):
			if t.top().y < pos.y + 1.0:
				continue
			var to := Vector3(t.base.x - pos.x, 0.0, t.base.y - pos.z)
			var d := to.length()
			if d < 1.0 or d > 14.0 or fh.angle_to(to) > deg_to_rad(60.0):
				continue
			var mine := d / maxf(b.model.speed, 1.0)   # (past it before the seeker catches me)
			if mine < best_t and mine < sp.distance_to(pos) / maxf(s_speed - b.model.speed, 5.0):
				best_t = mine
				tree = t
	if tree == null:
		br.cover_tree = -1
		return Vector3.INF
	if tree.id != br.cover_tree:
		br.cover_side = 0.0
	br.cover_tree = tree.id
	var c := Vector3(tree.base.x, pos.y, tree.base.y)
	var away := Vector3(c.x - sp.x, 0.0, c.z - sp.z).normalized()
	var behind := (pos - c).dot(away)
	if behind < -tree.radius:
		# Not yet abeam: to just past its edge, on the side I'm heading for (where I'd be by the time I could roll the
		# other way; kept once picked).
		var lat := CombatTree._across(away)
		if br.cover_side == 0.0:
			var ahead := pos + b.model.velocity * (0.2 + 2.0 * br.style.roll90) - c
			br.cover_side = signf(lat.dot(ahead)) if absf(lat.dot(ahead)) > 0.05 else 1.0
		return c + lat * br.cover_side * (tree.radius + 1.2) + away * 1.5
	return c + away * (tree.radius + 3.0 if behind < tree.radius + 2.0 else 15.0)


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


## Rest: hurt, to the base (feathers grow back only there); tired, the base if near, else a perch in reach -- or, with
## none in reach, the ground.
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
		if br.intent.perch == null:
			# No perch in reach on what it has left: glide down and rest on the ground (CombatPilot sits there).
			var fd := b.model.flight_dir()
			br.intent.aim = CombatTree._toward(b, Vector3(fd.x, -0.3, fd.z))
			br.intent.opts.flap = "none"
		return SUCCESS


## A perch to rest on, kept while it flies there: one the flight AI can reach (AIPilot's rule), the safest -- far from
## the enemies it knows of, not toward them, out of their sight behind the trunks -- of a comfortable hop.
static func _nearest_perch(br: CombatBrain) -> Perch:
	if br.pilot.target != null and br.intent.mode in ["rest", "rearm"]:
		return br.pilot.target
	var pos := br.bird.global_position
	# Where they'll look from: each enemy now and a couple of seconds on, and where it has seen them fly.
	var eyes := []
	for t in br.picture.enemies():
		eyes.append(t.pos)
		eyes.append(t.pos + t.vel * 2.0)
	if br.fight_seen >= 0.0:
		eyes.append(br.fight_area)
	var layout := br.world.layout
	var glide := br.bird.profile.glide_ratio
	return _pick_perch(br, func(c: Perch, d: float) -> float:
		# (AIPilot's own taste: a 25-40 m hop, a little downhill, up in the trees; a tired bird can't climb to one.)
		var score := -absf(d - 32.0) * 0.1 - maxf(0.0, c.position.y - pos.y + 2.0) * 0.6 + minf(c.position.y, 15.0) * 0.15
		score += minf(pos.y - d / (glide * 0.75) - c.position.y, 6.0) * 0.4   # (height in hand to get there: a break on the way mustn't leave it short)
		for e in eyes:
			score += minf(c.position.distance_to(e), 50.0) / 25.0
			if (c.position - pos).dot(e - pos) > 0.0:
				score -= 0.5   # (toward them)
			if layout != null and layout.segment_clear(e, c.position + Vector3.UP * 0.3, 0.0, c.tree_id):
				score -= 3.0   # (in sight)
		return score)


## The best-scoring perch the flight AI can reach from here (AIPilot._best_perch's reach rule: a hop of 12-70 m, high
## enough to approach, low enough to glide or climb to on the stamina it has: `climb` m at full stamina), by
## `score(perch, distance)`.
static func _pick_perch(br: CombatBrain, score: Callable, climb := 6.0) -> Perch:
	var b := br.bird
	var pos := b.global_position
	var p := b.profile
	var budget: float = climb * b.model.energy.stamina
	var floor_y := 2.0 + br.style.v_stall * 0.35
	var best: Perch = null
	var best_score := -INF
	for c in b.layout.perches:
		if c.tree_id == br.pilot._last_tree or br.pilot.clock < float(br.pilot._given_up.get(c.id, -1.0)):
			continue
		var d := Vector2(c.position.x - pos.x, c.position.z - pos.z).length()
		if d < 12.0 or d > 70.0 or c.position.y < floor_y or c.position.y > pos.y - d / (p.glide_ratio * 0.75) + budget:
			continue
		var sc: float = score.call(c, d) - (1000.0 if c.fallback else 0.0)   # (an edge post: only when nothing else)
		if sc > best_score:
			best_score = sc
			best = c
	return best


## Ambush (docs/design/combat_ai.md, 4.7), for an ambusher with rounds: fly to a perch high above where the enemies
## fly, sit and watch (resting meanwhile), and drop off -- leaving the fight to the Fight branch -- when one passes
## below within 30 m, not flying straight at me; or when one has its nose on me inside 25 m (spotted), or after
## skill.ambush_patience.
## Then it fights a while (AMBUSH_AGAIN s) before it looks for another. FAILURE whenever it isn't ambushing, so the
## branches below take over: an enemy close enough to fight now is fought.
class Ambush extends ActionLeaf:
	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var b := actor as Bird
		if not br.style.ambusher or br.ammo_left() == 0 or br.clock < br.amb_again:
			return FAILURE
		var pos := b.global_position
		var enemies := br.picture.enemies()
		if br.fight_seen < 0.0:
			return FAILURE   # (no idea yet where they fly)
		if br.amb_perch != null and br.amb_perch.position.y < br.fight_area.y + 3.0:
			br.amb_perch = null   # (they've been flying higher than it: pick again)
		if br.amb_perch != null and b.state == Bird.State.PERCHED and b.perch == br.amb_perch:
			if br.amb_since < 0.0:
				br.amb_since = br.clock
			for t in enemies:
				if not t.visible:
					continue
				var its_ata: float = Engagement.ata(t.pos, t.vel.normalized(), pos) if t.vel.length() > 1.0 else PI
				var spotted: bool = its_ata < deg_to_rad(15.0) and t.pos.distance_to(pos) < 25.0   # (its nose on my perch)
				var under: bool = pos.y - t.pos.y > 3.0 and Vector2(t.pos.x - pos.x, t.pos.z - pos.z).length() < 30.0 and its_ata > deg_to_rad(25.0)
				if spotted or under:
					if under:
						br.target = t.bird
						br.stats.ambushes = int(br.stats.get("ambushes", 0)) + 1
					CombatTree._end_ambush(br)
					return FAILURE
			if br.clock - br.amb_since > br.skill.ambush_patience:
				CombatTree._end_ambush(br)
				return FAILURE
		else:
			for t in enemies:
				if t.visible and t.pos.distance_to(pos) < 30.0:
					return FAILURE   # (one close enough to fight now)
			if br.amb_perch == null:
				br.amb_perch = CombatTree._ambush_perch(br)
				br.amb_since = -1.0
				if br.amb_perch == null:
					br.amb_again = br.clock + 3.0
					return FAILURE
		br.intent.mode = "ambush"
		br.intent.perch = br.amb_perch
		return SUCCESS


const AMBUSH_AGAIN := 12.0


static func _end_ambush(br: CombatBrain) -> void:
	br.amb_perch = null
	br.amb_again = br.clock + AMBUSH_AGAIN


## A perch for an ambush: 4-15 m above where it has seen the enemies fly (CombatBrain.fight_area), 15-45 m from
## there, not under a known enemy's nose; it may climb a little more to it than to a rest perch.
static func _ambush_perch(br: CombatBrain) -> Perch:
	var enemies := br.picture.enemies()
	var area := br.fight_area
	var score := func(c: Perch, d: float) -> float:
		var up := c.position.y - area.y
		if up < 4.0:
			return -INF
		var flat := Vector2(c.position.x - area.x, c.position.z - area.z).length()
		var sc := minf(up, 15.0) * 0.3 - absf(flat - 28.0) * 0.08 - d * 0.02
		for t in enemies:
			if t.vel.length() > 1.0 and Engagement.ata(t.pos, t.vel.normalized(), c.position) < deg_to_rad(30.0):
				sc -= 2.0   # (under its nose)
		return sc
	return _pick_perch(br, score, 12.0)


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
		if br.launcher.weapon != Launcher.Weapon.SEEKERS:
			aim = br.lead_for(t)   # (rockets, the gun: unguided, so fly the lead)
		else:
			aim = t.pos
		if d < 10.0 and close > 4.0:
			if br.skill.yoyos and close > 6.0:
				i.opts.gamma = deg_to_rad(25.0)   # high yo-yo: out of its plane, then back down on it
			aim = Engagement.lag_point(t.pos, t.vel, 6.0)
			i.opts.flap = "none"
		else:
			# Range control (4.4): hold the weapon's band -- seekers far enough out to keep a jinking bird in the lock
			# cone (and past the lock's 6 m minimum), rockets close enough for a short flight -- by speed.
			var band: Vector2 = {Launcher.Weapon.SEEKERS: SEEKER_BAND, Launcher.Weapon.GUN: GUN_BAND}.get(br.launcher.weapon, ROCKET_BAND)
			var dv := 1.5 if d > band.y else (-2.0 if d < band.x else 0.0)
			i.opts.flap = "hold"
			i.opts.speed = clampf(t.vel.length() + dv, br.style.v_best * 0.85, br.style.v_best * 1.4)
			if d < band.x and close > 0.5:
				i.opts.flap = "none"
		var err := deg_to_rad(br.skill.aim_error_deg)
		var to := aim - pos
		aim = pos + to.rotated(Vector3.UP, br.rng.randf_range(-err, err))
		i.aim = CombatTree._floor(br, aim)
		return SUCCESS


const SEEKER_BAND := Vector2(12.0, 28.0)   ## m behind a target an attacker with seekers holds
const ROCKET_BAND := Vector2(8.0, 22.0)    ## ... with rockets
const GUN_BAND := Vector2(6.0, 18.0)       ## ... with the gun: bullets scatter (Launcher.GUN_SPREAD) and die at ~40 m


## Boom and zoom (docs/design/combat_ai.md, 4.4 and 5), for the birds that can't turn with their targets:
##   climb  -- run out to ROOM m from it, climbing, then turn back at a point STOOP_HEIGHT above it;
##   stoop  -- with the height and it ahead within reach (any aspect: a head-on pass too), dive on its rocket lead
##             (which follows the turn it's seen making; aimed past by how far the gunsight trails it), wings
##             unflapped, weapons free, until past it (close, behind me, or below it) or out of reach;
##   zoom   -- pull up and climb away along my heading, trading the dive's speed for height, then climb again.
class BoomAndZoom extends ActionLeaf:
	const STOOP_HEIGHT := 9.0
	const ROOM := 30.0   ## m out from it before turning back for the next pass
	const CLIMB_DEG := 16.0

	func tick(actor: Node, bb: Blackboard) -> int:
		var br := CombatTree._brain(bb)
		var b := actor as Bird
		var t := br.picture.track_of(br.target)
		var i := br.intent
		i.target = br.target
		var pos := b.global_position
		var fd := b.model.flight_dir()
		var fh := Vector3(fd.x, 0.0, fd.z).normalized()
		var to := t.pos - pos
		var flat := Vector2(to.x, to.z).length()
		var above := pos.y - t.pos.y
		if br.bz_phase == "stoop":
			var passed := to.length() < 4.0 or Engagement.ata(pos, fd, t.pos) > deg_to_rad(100.0) or above < -2.0 or flat > 40.0
			if passed or br.clock > br.bz_until:
				br.bz_phase = "zoom"
				br.bz_until = br.clock + 1.4
			else:
				i.mode = "attack"
				i.fire = true
				var aim := CombatTree._overlead(br, br.lead_for(t))
				i.aim = aim
				i.opts.gamma = clampf(atan2(aim.y - pos.y, maxf(Vector2(aim.x - pos.x, aim.z - pos.z).length(), 1.0)), deg_to_rad(-60.0), deg_to_rad(10.0))
				i.opts.flap = "none"
				return SUCCESS
		if br.bz_phase == "zoom":
			if br.clock < br.bz_until and b.model.speed > br.style.v_best:
				i.mode = "zoom"
				i.aim = pos + fh * 30.0 + Vector3.UP * 15.0
				i.opts.gamma = deg_to_rad(30.0)
				i.opts.flap = "none"
				return SUCCESS
			br.bz_phase = "climb"
		# Climb: run out to room for a pass, then back at a point above it.
		br.bz_phase = "climb"
		i.mode = "engage"
		var ata := Engagement.ata(pos, fd, t.pos)
		if above >= STOOP_HEIGHT * 0.6 and flat > 8.0 and flat < 32.0 and ata < deg_to_rad(45.0):
			br.bz_phase = "stoop"
			br.bz_until = br.clock + 3.0
			br.stats.stoops = int(br.stats.get("stoops", 0)) + 1
			i.mode = "attack"
			i.fire = true
			i.aim = br.lead_for(t)
			i.opts.flap = "none"
			return SUCCESS
		if flat < ROOM and ata > deg_to_rad(60.0):
			i.aim = CombatTree._floor(br, pos + fh * 30.0 + Vector3.UP * 6.0)   # (too close to turn on it: run out, climbing)
		else:
			i.aim = CombatTree._floor(br, t.pos + Vector3.UP * STOOP_HEIGHT)
		if above < STOOP_HEIGHT and b.model.speed > br.style.v_best * 0.95:
			i.opts.gamma = deg_to_rad(CLIMB_DEG)   # (height first: it's what the dive spends; not below v*, or it stalls)
		i.opts.flap = "hold"
		i.opts.speed = br.style.v_best
		return SUCCESS


## Aim past `lead` by how far the gunsight trails it (where my nose points at that range): the guidance lags a
## moving lead by a few degrees, which is a metre or two at 20 m -- outside the fuse.
static func _overlead(br: CombatBrain, lead: Vector3) -> Vector3:
	var l := br.launcher
	var m := l.muzzle()
	var nose := m + l.aim() * m.distance_to(lead)
	return lead + (lead - nose) * OVERLEAD


const OVERLEAD := 1.4


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
const PATROL_RADIUS := 25.0   ## m round the base (or the arena's middle) a bird with nothing to do circles


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
		if rel.length() < PATROL_RADIUS * 0.5:
			# Near the middle, the way round is anyone's guess: fly on out to the circle as it is heading.
			var fd := b.model.flight_dir()
			var ahead := Vector3(fd.x, 0.0, fd.z).normalized() if Vector2(fd.x, fd.z).length() > 1e-3 else b.facing
			i.aim = Vector3(b.global_position.x, y, b.global_position.z) + ahead * PATROL_RADIUS
		else:
			var ang := atan2(rel.z, rel.x) + 0.6
			i.aim = Vector3(c.x + cos(ang) * PATROL_RADIUS, y, c.z + sin(ang) * PATROL_RADIUS)
		i.opts.flap = "auto"
		return SUCCESS
