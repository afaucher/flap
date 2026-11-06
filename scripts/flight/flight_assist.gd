class_name FlightAssist
extends RefCounted
## Novice flying (`--flying novice`; `--flying realistic`, the default, is the flight model as it is). Two helps:
##
## LANDING ASSIST, while catch is held with a perch highlighted (Bird.candidate):
##   - the player's stick is blended toward what the AI pilot flies to land there (AIPilot.steer with its
##     final-approach options: aim just above the grip, bleed speed, flap only when sinking below the perch, the wood
##     avoided). It eases in over ENGAGE_TIME and lets go at once when catch is released. The player keeps authority:
##     the result is a FlightInput (what any pilot produces), their own stick still `1 - strength` of it, and
##     releasing catch hands it all back;
##   - the bird's perch assist (Bird.novice_landing) works from ASSIST_REACH, at PERCH_ASSIST at least, its flare
##     braking for the height over the perch as well as the speed (an approach from too high comes in too fast);
##   - perches are candidates from APPROACH out (Bird.approach_radius), so there's room to do it;
##   - it stays on the line the player is flying: the perch it engaged on is held (Bird.candidate_lock) so its own
##     turn can't hand it the next tree, it adds at most MAX_BANK_ADD of the stick's bank to the player's; turn away from the perch and it
##     falls out of the held perch's cone (Bird.LOCK_CONE_DEG, round the path the player's turn flies), and the assist
##     lets go.
## `strength` 0 turns all of it off (fit() again after changing it).
##
## WOOD AVOIDED (the player's bird): it rolls away from wood its flight is about to strike, body or wing, at AVOID
## strength (Bird.avoid_assist), paying for it in speed; realistic, 0 (the reflexes that soften a touch stay on).
##
## MORE POWER AND ENDURANCE (EnergyModel, every bird in the scene): stamina lasts STAMINA x as many wingbeats, comes
## back RECOVERY x as fast, and the burst refills BURST_REGEN x as fast. The profiles' readable numbers and the polar
## are untouched.
##
## Use: the scenes call configure(Boot.args()) and fit(the player's bird); a PlayerController applies it to its own
## input (`assist`); `FlightAssist.new(ctl)` wraps any other controller (tests).

static var novice := false     ## --flying novice
static var strength := 0.75    ## 0..1, the assist's share of the stick once engaged (0: no landing assist)

const APPROACH := 14.0         ## m: a novice's perches are candidates (highlighted, landed on) from this far
const ASSIST_REACH := 10.0     ## m: the perch assist works from this far while a novice holds catch (realistic: 6)
const PERCH_ASSIST := 1.0      ## ... at least this strong (Bird.perch_assist; realistic: the bird's own, 0.6)
const BLEED_TO := 0.6          ## of the catch speed: the approach bleeds speed toward this (the AI: 0.8)
const ENGAGE_TIME := 0.3       ## s to ease the assist in once catch is held with a candidate
const MAX_BANK_ADD := 0.35     ## of full stick: the most bank the assist adds to (or takes from) the player's
const STAMINA := 1.5           ## novice: wingbeats a full stamina lasts, x the profile's
const RECOVERY := 2.0          ## novice: stamina regained gliding and perched, x
const BURST_REGEN := 1.3       ## novice: burst refill, x (more full-strength wingbeats in a sprint)
const AVOID := 0.5             ## novice: the bird rolls away from wood coming (Bird.avoid_assist), this strong, at a speed cost

var inner: Object = null       ## the controller it wraps (sample()); null when applied by a PlayerController
var engage := 0.0              ## 0..1, eased in while on
var pilot: AIPilot = null      ## flies the approach it blends toward
var last_assist := FlightInput.new()   ## what the pilot asked for on the last assisted tick (debug, tests)


func _init(ctl: Object = null) -> void:
	inner = ctl


## The scene's flying mode from its options (realistic unless `--flying novice`).
static func configure(args: PackedStringArray) -> void:
	novice = Boot.arg_value(args, "--flying") == "novice"


## The player's bird, for the mode: a novice's candidates reach further out and its perch assist helps the landing
## (Bird.novice_landing); realistic, the bird's own.
static func fit(bird: Bird) -> void:
	var on := novice and strength > 0.0
	bird.approach_radius = APPROACH if on else Bird.APPROACH_RADIUS
	bird.novice_landing = on
	bird.avoid_assist = AVOID if novice else 0.0


static func stamina_scale() -> float:
	return STAMINA if novice else 1.0


static func recovery_scale() -> float:
	return RECOVERY if novice else 1.0


static func burst_regen_scale() -> float:
	return BURST_REGEN if novice else 1.0


## As a controller: the wrapped one's input, assisted.
func sample(bird: Bird, dt: float) -> FlightInput:
	var inp: FlightInput = inner.sample(bird, dt) if inner != null else FlightInput.new()
	return apply(bird, inp, dt)


## `inp` (the player's), blended toward the landing approach while it's on.
func apply(bird: Bird, inp: FlightInput, dt: float) -> FlightInput:
	var on := novice and strength > 0.0 and inp.catch_held and bird.state == Bird.State.FLYING and bird.candidate != null
	if not on:
		engage = 0.0   # (catch released, or nothing to land on: the player's at once)
		if bird != null:
			bird.candidate_lock = null
		return inp
	if bird.candidate_lock != null and bird.candidate != bird.candidate_lock:
		engage = 0.0   # (the held perch went out of the cone: a fresh approach on the new one)
	if bird.candidate_lock == null or engage <= 0.0:
		bird.candidate_lock = bird.candidate
	if pilot == null or pilot.planner.layout != bird.layout:
		pilot = AIPilot.new(bird.layout)
	if engage <= 0.0:
		pilot._stick = inp.stick   # (its smoothed stick starts from the player's)
		engage = minf(1.0, dt / ENGAGE_TIME)
	else:
		engage = minf(1.0, engage + dt / ENGAGE_TIME)
	var ai := approach(bird, dt)
	last_assist = ai
	var w := strength * engage
	# Flapping: the player's, and the approach's too once the assist has most of the say. (Flapping in, the climb trim,
	# FlightModel.trim_alpha, would carry the bird up over the perch; the perch assist's height braking takes it down.)
	var held := inp.flap_held or (ai.flap_held and w >= 0.5)
	var stick := inp.stick.lerp(ai.stick, w)
	stick.x = clampf(stick.x, inp.stick.x - MAX_BANK_ADD, inp.stick.x + MAX_BANK_ADD)   # (it nudges the turn, never makes it)
	return FlightInput.new(stick, inp.flap_pressed, held, inp.catch_pressed, true)



## What the AI pilot flies onto the candidate perch from here: its final approach (AIPilot._fly), aimed at the grip
## the bird's path meets rather than the branch's outer part.
func approach(bird: Bird, dt: float) -> FlightInput:
	var p := bird.profile
	var target := bird.candidate
	pilot.target = target
	var grip := bird.candidate_grip
	var opts := {"bleed_to": p.grab_speed_max * BLEED_TO, "flap_below": grip.y - 0.3}
	if target.position.y < 5.0:
		opts.floor = 0.8   # (landing low)
	if bird.candidate_distance < 4.0:
		opts.recover = false
	return pilot.steer(bird, grip + Vector3.UP * AIPilot.AIM_HIGH, dt, opts)
