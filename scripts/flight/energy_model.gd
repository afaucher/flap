class_name EnergyModel
extends RefCounted
## Two reserves, so a bird can't flap forever or infinitely fast (docs/design/flight_model.md, "Energy").
##
## BURST (short term, seconds): the anaerobic sprint. Measured in full-strength flaps. Each flap spends
## one; it refills at burst_regen flaps/s whenever the wings aren't driving. Hard pulls (load factor over
## 2 g) drain it too. With less than one flap left, a flap is weak (weak_flap strength).
##
## STAMINA (medium term, a minute or two): the aerobic tank, 0..1. Every flap spends 1/stamina_flaps of
## it, double on an empty burst. It caps the burst (a tired bird has a smaller sprint) and scales the burst
## refill. It only comes back slowly while gliding and quickly while perched: flying perch to perch is how
## a bird rests.
##
## The wingbeat period (FlightModel) caps how fast flaps come, and flap thrust fades to nothing at
## flap_speed_cap, so flapping can't make you infinitely fast either.
##
## Novice flying (FlightAssist.novice) scales the stamina's wingbeats, its recovery and the burst's refill.

const HIGH_G := 2.0          ## load factor where pulling starts to cost burst
const HIGH_G_DRAIN := 1.0    ## flaps/s per g above HIGH_G

var profile: BirdProfile
var burst := 0.0
var stamina := 1.0


func _init(p: BirdProfile) -> void:
	profile = p
	burst = p.burst_max


## The burst reserve's ceiling right now: a tired bird sprints less.
func burst_cap() -> float:
	return profile.burst_max * (0.3 + 0.7 * stamina)


## Spend one flap; returns its strength (1 = full).
func spend_flap() -> float:
	var strength := 1.0
	var stamina_cost := 1.0 / (profile.stamina_flaps * FlightAssist.stamina_scale())
	if burst >= 1.0:
		burst -= 1.0
	else:
		strength = profile.weak_flap * (0.5 + 0.5 * stamina)
		burst = 0.0
		stamina_cost *= 2.0
	stamina = maxf(0.0, stamina - stamina_cost)
	return strength


## Advance the reserves. `driving`: a downstroke is under way. `load_factor`: lift / weight.
func tick(dt: float, driving: bool, load_factor: float, perched: bool) -> void:
	if load_factor > HIGH_G and not perched:
		burst = maxf(0.0, burst - (load_factor - HIGH_G) * HIGH_G_DRAIN * dt)
	if not driving:
		var rate := profile.burst_regen * FlightAssist.burst_regen_scale() * (0.05 + 0.95 * stamina) * (2.0 if perched else 1.0)
		burst = minf(burst_cap(), burst + rate * dt)
		var regen := profile.stamina_regen_perch if perched else profile.stamina_regen_glide
		stamina = minf(1.0, stamina + regen * FlightAssist.recovery_scale() * dt)
	burst = minf(burst, burst_cap())


func burst_fraction() -> float:
	return burst / profile.burst_max
