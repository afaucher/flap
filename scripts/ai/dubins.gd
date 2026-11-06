class_name Dubins
extends RefCounted
## Turn-straight-turn paths in the plane (Dubins CSC paths): the shortest way from a point and heading to another point
## and heading on circles of a given radius. A racer's go-around (RacePilot) and an AI bird's line-up for its final
## approach (AIPilot) fly them, on the turning circle the bird holds at its speed.


## The shortest turn-straight-turn path (a Dubins CSC path) from `p` heading `d0` to `q` heading `d1` on circles of
## radius `r`, as points about a metre apart (x, z). If none fits (the ends too close), a straight line.
static func path(p: Vector2, d0: Vector2, q: Vector2, d1: Vector2, r: float) -> PackedVector2Array:
	var found := all(p, d0, q, d1, r)
	return found[0] if not found.is_empty() else PackedVector2Array([p, q])


## Every turn-straight-turn path from `p` heading `d0` to `q` heading `d1` on circles of radius `r`, shortest first
## (path).
static func all(p: Vector2, d0: Vector2, q: Vector2, d1: Vector2, r: float) -> Array:
	var found := []   # [length, points]
	var best_pts := PackedVector2Array()
	for s1: float in [1.0, -1.0]:
		for s2: float in [1.0, -1.0]:
			var c1 := p - r * s1 * Vector2(d0.y, -d0.x)   # (the circle's centre: the bird on it, moving along d0 in sense s1)
			var c2 := q - r * s2 * Vector2(d1.y, -d1.x)
			var v := c2 - c1
			var dd := v.length()
			var u: Vector2
			if s1 == s2:
				if dd < 1e-3:   # (one circle: an arc from p round to q)
					var a := fposmod(s1 * ((q - c1).angle() - (p - c1).angle()), TAU)
					best_pts = PackedVector2Array()
					var na := maxi(1, ceili(r * a))
					for k in na + 1:
						best_pts.append(c1 + (p - c1).rotated(s1 * a * k / na))
					found.append([r * a, _dedup(best_pts)])
					continue
				u = v / dd
			else:
				if dd <= 2.0 * r:
					continue
				var phi := v.angle() + asin(clampf(2.0 * r * s1 / dd, -1.0, 1.0))
				u = Vector2.from_angle(phi)
			var t1 := c1 + r * s1 * Vector2(u.y, -u.x)
			var t2 := c2 + r * s2 * Vector2(u.y, -u.x)
			if s1 != s2:
				t2 = c2 - r * s1 * Vector2(u.y, -u.x)
			var a1 := fposmod(s1 * ((t1 - c1).angle() - (p - c1).angle()), TAU)
			var a2 := fposmod(s2 * ((q - c2).angle() - (t2 - c2).angle()), TAU)
			var length := r * (a1 + a2) + t1.distance_to(t2)
			if true:
				best_pts = PackedVector2Array()
				var n1 := maxi(1, ceili(r * a1))
				for k in n1:
					best_pts.append(c1 + (p - c1).rotated(s1 * a1 * k / n1))
				var nl := maxi(1, ceili(t1.distance_to(t2)))
				for k in nl:
					best_pts.append(t1.lerp(t2, float(k) / nl))
				var n2 := ceili(r * a2)
				for k in n2 + 1:
					best_pts.append(c2 + (t2 - c2).rotated(s2 * a2 * k / maxf(n2, 1.0)))
				found.append([length, _dedup(best_pts)])
	found.sort_custom(func(x, y): return x[0] < y[0])
	return found.map(func(x): return x[1])


static func _dedup(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])   # (no repeated points where one piece meets the next)
	for k in range(1, pts.size()):
		if pts[k].distance_to(out[-1]) > 0.05:
			out.append(pts[k])
	return out
