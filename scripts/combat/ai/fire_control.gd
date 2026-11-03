class_name FireControl
extends RefCounted
## "Would this round hit?" (docs/design/combat_ai.md, 4.5), answered by flying the real Projectile code forward
## against a dummy that moves as the target was seen moving -- straight, or turning at a given rate -- rather
## than by a hand-tuned cone. Pure and headless: no CombatWorld, no physics.

const STEP := 1.0 / 60.0


## A stand-in target: where it is and how it moves (Projectile reads `global_position` and `model.velocity`).
class Dummy:
	class Motion:
		var velocity := Vector3.ZERO
	var global_position := Vector3.ZERO
	var model := Motion.new()


## The closest a round of `kind` fired now would pass a target at `t_pos` moving at `t_vel`, turning at
## `t_turn` rad/s about the vertical (+ = to its right; 0 = straight on): m, or INF if it bursts on the wood
## first (`layout`; null = open air). A seeker is fired locked on the target; a rocket flies free.
static func miss(kind: int, muzzle: Vector3, carrier_vel: Vector3, aim: Vector3, t_pos: Vector3, t_vel: Vector3, t_turn := 0.0, layout: ArenaLayout = null) -> float:
	var d := Dummy.new()
	d.global_position = t_pos
	d.model.velocity = t_vel
	var p := Projectile.launch(kind, muzzle, carrier_vel, aim, null, d)
	var best := INF
	var life: float = Projectile.SPEC[kind].life
	var t := 0.0
	var no_birds: Array = []
	while t < life:
		var from := p.pos
		var ev := p.step(STEP, layout, no_birds)
		d.model.velocity = d.model.velocity.rotated(Vector3.UP, -t_turn * STEP)
		d.global_position += d.model.velocity * STEP
		var q := Geometry3D.get_closest_point_to_segment(d.global_position, from, p.pos)
		if p.travelled >= Projectile.ARM:
			best = minf(best, q.distance_to(d.global_position))
		if not ev.is_empty():
			return INF if String(ev.why) == "impact" and best > Projectile.fuse else best
		t += STEP
	return best


## The distance within which a round hurts (its fuse sets it off this close, its blast reaches this far).
static func reach() -> float:
	return Projectile.fuse + CombatWorld.blast
