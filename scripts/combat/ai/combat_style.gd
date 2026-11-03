class_name CombatStyle
extends RefCounted
## How a species fights (docs/design/combat_ai.md, 5), derived from its BirdProfile rather than typed in: turn
## rates and radius, roll time, energy, and from those the tactics it uses. The flags follow from the numbers:
##   slow to roll or a high stall speed (hawk, falcon): an energy fighter -- stays high, wants the height on a
##   target before it commits, never fights low in the understory, makes passes and climbs out;
##   the fastest roll (sparrow): a turn fighter, happy low among the trunks;
##   a slow roll but a low stall (owl): ambushes from a perch.
## The rest (crow) are all-rounders. Seekers for the all-rounders and ambushers, rockets for the others.

var id := ""
var v_best := 0.0
var v_stall := 0.0
var max_bank := 0.0               ## rad
var roll90 := 0.0                 ## s to roll from level to a 90 deg bank
var sustained_rate := 0.0         ## rad/s, level turn at v* at 95% of the bank limit
var corner_rate := 0.0            ## rad/s, the tightest turn: at the bank limit, just above the stall
var turn_radius := 0.0            ## m, at v* at 95% of the bank limit
var seeker_break_tgo := 0.0       ## s before a seeker arrives to break: roll to 90, then move a burst's reach sideways
var prefers_height := false       ## energy fighter
var understory_ok := false        ## fights down among the trunks
var ambusher := false
var weapon := Launcher.Weapon.ROCKETS   ## what it carries
var want_delta_e := 0.0           ## m of energy height on a target before it commits to an attack
var height_band := Vector2(12.0, 30.0)   ## m it likes to fly at


static var _cache := {}


## The style of a species (cached by its id: profiles are fixed).
static func of(p: BirdProfile) -> CombatStyle:
	if not _cache.has(p.id):
		_cache[p.id] = from(p)
	return _cache[p.id]


static func from(p: BirdProfile) -> CombatStyle:
	var s := CombatStyle.new()
	s.id = p.id
	s.v_best = p.v_best
	s.v_stall = p.v_stall
	s.max_bank = deg_to_rad(p.max_bank_deg)
	s.roll90 = 90.0 / p.roll_rate_deg
	# Sustained at v*: as steep as the lift allows there (n = 1/cos b <= (v*/v_stall)^2), within 95% of the limit.
	var b := minf(s.max_bank * 0.95, acos(clampf(pow(p.v_stall / p.v_best, 2.0), 0.0, 1.0)))
	s.sustained_rate = Engagement.G * tan(b) / p.v_best
	# The corner: the bank limit's load factor n = 1/cos(b) needs v = v_stall * sqrt(n).
	var v_corner := p.v_stall * sqrt(1.0 / cos(s.max_bank))
	s.corner_rate = Engagement.G * tan(s.max_bank) / v_corner
	s.turn_radius = Engagement.turn_radius(p.v_best, b)
	var reach := Projectile.fuse + CombatWorld.blast
	s.seeker_break_tgo = s.roll90 + sqrt(2.0 * reach / (Engagement.G * tan(b)))
	s.prefers_height = s.roll90 > 0.5 or p.v_stall > 8.0   # (slow to roll, or a high stall: needs its speed)
	s.understory_ok = s.roll90 < 0.25                       # (rolls fastest: the slalom among the trunks is its)
	s.ambusher = not s.prefers_height and s.roll90 >= 0.4   # (slow, gentle, floaty)
	s.weapon = Launcher.Weapon.SEEKERS if not s.prefers_height and not s.understory_ok else Launcher.Weapon.ROCKETS
	s.want_delta_e = 5.0 if s.prefers_height else 0.0
	s.height_band = Vector2(16.0, 32.0) if s.prefers_height else (Vector2(5.0, 16.0) if s.understory_ok else Vector2(9.0, 24.0))
	return s


## The steepest bank it can hold level at speed v, with a 15% lift margin (rad, within its bank limit).
func lift_bank(v: float) -> float:
	var n := 0.85 * pow(maxf(v, 0.1) / v_stall, 2.0)
	return clampf(acos(clampf(1.0 / maxf(n, 1.0), 0.0, 1.0)), deg_to_rad(15.0), max_bank)


## The fastest it can turn at speed v (rad/s): the lift's load factor (v / v_stall)^2, capped by the bank limit.
func best_turn_rate(v: float) -> float:
	var n := minf(pow(maxf(v, 0.1) / v_stall, 2.0), 1.0 / cos(max_bank))
	return Engagement.G * sqrt(maxf(n * n - 1.0, 0.0)) / maxf(v, 0.1)


func describe() -> String:
	return "%s: turn %.0f deg/s (corner %.0f), radius %.1f m, roll to 90 %.2f s, seeker break at %.2f s, %s%s%s, %s" % [id,
		rad_to_deg(sustained_rate), rad_to_deg(corner_rate), turn_radius, roll90, seeker_break_tgo,
		"energy fighter" if prefers_height else ("turn fighter" if understory_ok else "all-rounder"),
		", ambusher" if ambusher else "", ", stays out of the understory" if not understory_ok else "",
		"seekers" if weapon == Launcher.Weapon.SEEKERS else "rockets"]
