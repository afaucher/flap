class_name Engagement
extends RefCounted
## Air-combat geometry between two birds (docs/design/combat_ai.md, 4.4): pure static functions, no state.
## "Me" is a position and a flight direction; the target is a position and a velocity (as seen).
##   ATA (antenna train angle): the target's angle off my nose, 0 = dead ahead.
##   AA (aspect angle): my angle off the target's tail, 0 = I'm right behind it, 180 = head-on.
##   closure: how fast the range shrinks (m/s, + = closing).
## Pursuit points: lead (where a round meets it), pure (the target itself), lag (behind it on its path).

const G := 9.81


static func ata(my_pos: Vector3, my_dir: Vector3, t_pos: Vector3) -> float:
	var to := t_pos - my_pos
	return my_dir.angle_to(to) if to.length() > 1e-4 and my_dir.length() > 1e-4 else 0.0


static func aa(my_pos: Vector3, t_pos: Vector3, t_vel: Vector3) -> float:
	var from_t := my_pos - t_pos
	if t_vel.length() < 0.1 or from_t.length() < 1e-4:
		return PI * 0.5
	return (-t_vel).angle_to(from_t)


static func closure(my_pos: Vector3, my_vel: Vector3, t_pos: Vector3, t_vel: Vector3) -> float:
	var to := t_pos - my_pos
	if to.length() < 1e-4:
		return 0.0
	return (my_vel - t_vel).dot(to.normalized())


## Height plus the height its speed could buy: E = y + v^2 / 2g (m).
static func energy_height(pos: Vector3, vel: Vector3) -> float:
	return pos.y + vel.length_squared() / (2.0 * G)


## Where to aim so a round of average speed `round_speed` (on top of my own speed `my_speed`) meets a target
## moving at `t_vel`: its position after the flight time, raised by the round's drop. (Launcher.lead_point, from
## seen state.)
static func lead_point(muzzle: Vector3, my_speed: float, t_pos: Vector3, t_vel: Vector3, round_speed := 34.0, gravity := true) -> Vector3:
	var spd := my_speed + round_speed
	var flight := muzzle.distance_to(t_pos) / spd
	for i in 3:
		flight = muzzle.distance_to(t_pos + t_vel * flight) / spd
	return t_pos + t_vel * flight + (Vector3.UP * 0.5 * Projectile.G * flight * flight if gravity else Vector3.ZERO)


## A point `dist` m behind the target along its path (lag pursuit: stay behind its wing line, bleed closure).
static func lag_point(t_pos: Vector3, t_vel: Vector3, dist: float) -> Vector3:
	return t_pos - (t_vel.normalized() if t_vel.length() > 0.1 else Vector3.ZERO) * dist


## The turn radius at speed v and bank b (level, coordinated): v^2 / (g tan b).
static func turn_radius(v: float, bank: float) -> float:
	return v * v / (G * tan(clampf(absf(bank), deg_to_rad(5.0), deg_to_rad(85.0))))


## Seconds to bring my nose onto a direction `angle` rad away: roll to `bank` (at `roll_rate` rad/s), then turn
## at g tan(bank) / v.
static func time_to_point(angle: float, v: float, bank: float, roll_rate: float) -> float:
	var omega := G * tan(clampf(bank, deg_to_rad(5.0), deg_to_rad(85.0))) / maxf(v, 1.0)
	return bank / maxf(roll_rate, 0.1) + angle / omega


## Is the target on my right? (+1 right, -1 left, looking along my flight, horizontally.)
static func side_of(my_pos: Vector3, my_dir: Vector3, p: Vector3) -> float:
	var to := p - my_pos
	var c := my_dir.cross(to).y
	return -1.0 if c > 0.0 else 1.0
