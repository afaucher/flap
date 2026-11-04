class_name AirField
extends RefCounted
## The air's own movement over the arena (pure data, headless-testable): what a bird soars on. at(p, t) is the
## air's velocity (m/s) at a point; the flight model flies the bird in that moving air (FlightModel.wind), so
## rising air lifts it exactly as it would a glider, and it rises through still air's sink rate when the air goes up
## faster than that.
##   thermals  over open ground the sun warms (Pinewood's clearing and glades): a column of rising air, strongest
##             in its core and fading out to its edge, ringed by gentle sinking air; weak low down (gathering off the
##             floor), full from about treetop height, holding to most of its top and dying away there; it pulses as
##             bubbles of warm air lift off
##   ridges    wind blowing onto a cliff face is turned up it: rising air in front of the face and over its top
##             edge, strongest a little out from the edge and up to about the cliff's height above it; none behind
##             the edge (the lee) nor past the face's ends. add_ridge() takes the top edge, its outward face normal
##             and the cliff's height.
## `enabled` false (--calm) turns all of it off.

static var enabled := true

var thermals: Array = []   ## of {centre: Vector2, radius: float, lift: float (m/s, the core), top: float (m), phase: float}
var ridges: Array = []     ## of {a: Vector3, b: Vector3 (the top edge), out: Vector3 (horizontal), height: float, lift: float}

const THERMAL_FLOOR := Vector2(4.0, 16.0)   ## m: the column builds from here to full strength (below, the warm air is
                                            ## still gathering off the floor: weak where birds land on low limbs)
const THERMAL_PULSE := 0.25    ## share of the core's lift a bubble adds or takes
const THERMAL_PERIOD := 18.0   ## s between bubbles
const SINK_RING := 0.22        ## share of the core's lift the ring round it sinks at


func add_thermal(centre: Vector2, radius: float, lift: float, top: float) -> void:
	thermals.append({"centre": centre, "radius": radius, "lift": lift, "top": top, "phase": fmod(absf(centre.x * 0.37 + centre.y * 0.61), 1.0)})


func add_ridge(a: Vector3, b: Vector3, out: Vector3, height: float, lift: float) -> void:
	var o := Vector3(out.x, 0.0, out.z).normalized()
	ridges.append({"a": a, "b": b, "out": o, "height": height, "lift": lift})


## The air's velocity at `p` (world, m) at time `t` (s).
func at(p: Vector3, t := 0.0) -> Vector3:
	if not enabled:
		return Vector3.ZERO
	var w := 0.0
	for th in thermals:
		w += _thermal(th, p, t)
	for r in ridges:
		w += _ridge(r, p)
	return Vector3(0.0, w, 0.0)


## A thermal's rising air at `p`: lift * the core's bell (exp(-2 (r/R)^2)) - the sinking ring just outside, all
## times the column's height profile and the bubbles' pulse.
static func _thermal(th: Dictionary, p: Vector3, t: float) -> float:
	var r := Vector2(p.x, p.z).distance_to(th.centre) / float(th.radius)
	if r > 2.2:
		return 0.0
	var h := p.y - ArenaLayout.GROUND_Y
	var top: float = th.top
	var column := smoothstep(THERMAL_FLOOR.x, THERMAL_FLOOR.y, h) * (1.0 - smoothstep(top * 0.75, top, h))
	if column <= 0.0:
		return 0.0
	var core := exp(-2.0 * r * r)
	var ring := SINK_RING * exp(-pow((r - 1.35) / 0.35, 2.0))
	var pulse := 1.0 + THERMAL_PULSE * sin(TAU * (t / THERMAL_PERIOD + float(th.phase)))
	return float(th.lift) * column * (core * pulse - ring)


## Ridge lift at `p`: in front of the face (d m out from the edge) and about the edge's height (h m above it), a bell
## out from the face centred a quarter of the cliff's height out, rising from part way down the face and fading by
## twice its height above the top; fading out past the face's ends; nothing behind the edge.
static func _ridge(r: Dictionary, p: Vector3) -> float:
	var a: Vector3 = r.a
	var b: Vector3 = r.b
	var along := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var len := along.length()
	if len < 1e-3:
		return 0.0
	along /= len
	var rel := Vector3(p.x - a.x, 0.0, p.z - a.z)
	var s := rel.dot(along)
	var ends := smoothstep(-0.25 * float(r.height), 0.0, s) * (1.0 - smoothstep(len, len + 0.25 * float(r.height), s))
	if ends <= 0.0:
		return 0.0
	var d := rel.dot(r.out)   # out from the edge (in front of the face +)
	var H: float = r.height
	if d < -0.15 * H:
		return 0.0
	var top_y := lerpf(a.y, b.y, clampf(s / len, 0.0, 1.0))
	var h := p.y - top_y
	var out_bell := exp(-pow((d - 0.25 * H) / (0.7 * H), 2.0)) * smoothstep(-0.15 * H, 0.05 * H, d)
	var up_bell := smoothstep(-0.8 * H, -0.1 * H, h) * (1.0 - smoothstep(0.6 * H, 2.0 * H, h))
	return float(r.lift) * ends * out_bell * up_bell
