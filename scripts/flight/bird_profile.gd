class_name BirdProfile
extends RefCounted
## One species' flight numbers. Designers set the readable ones (mass, span, area, glide ratio, CL max,
## flap and energy budgets); everything aerodynamic is derived from them so a profile is always
## internally consistent with the drag polar in FlightModel:
##   AR = b^2 / S,  K = 1 / (pi e AR),  CD0 = 1 / (4 (L/D)^2 K)        (so L/D max is exactly glide_ratio)
##   CL* = sqrt(CD0 / K)  (best-glide lift coefficient),  alpha* = CL* / CL_alpha
##   V* = sqrt(2 m g / (rho S CL*)),  V_stall = sqrt(2 m g / (rho S CL_max)),  glide angle = atan(1 / (L/D))
## Real-bird sources and the reasoning for each number: docs/research/bird_aerodynamics_by_species.md (its
## proposed-profile table: mass, area, aspect ratio, e, CL max, L/D, wingbeat, bank and roll rate come from there).

const RHO := 1.225
const G := 9.81

var id := ""
var display_name := ""
var blurb := ""

# --- Body and wing ---------------------------------------------------------------------------------
var mass := 0.45            ## kg
var span := 1.0             ## m, tip to tip, wings spread
var wing_area := 0.12       ## m^2, wings + body strip, spread
var oswald := 0.8           ## span efficiency e (slotted primaries push it up)
var glide_ratio := 10.0     ## L/D max: designer-set, CD0 is derived from it
var cl_max := 1.7           ## with alula; the stall
var body_length := 0.45     ## m, visual + collision
var tail_length := 0.18     ## m, visual

# --- Handling --------------------------------------------------------------------------------------
var max_bank_deg := 65.0    ## bank limit (stick fully sideways)
var roll_rate_deg := 220.0  ## how fast bank follows the stick, deg/s
var alpha_rate_deg := 140.0 ## how fast angle of attack follows the stick, deg/s
var alpha_push_deg := -3.0  ## angle of attack at full push (before the wing fold)
var alpha_pull_over_deg := 12.0  ## full pull goes this far past the stall angle (the flare / airbrake)
var fold_area_cut := 0.5    ## full wing tuck removes this share of the area
var fold_span_cut := 0.55   ## ... and this share of the span (aspect ratio drops: K rises)
var fold_drag_cut := 0.45   ## ... and this share of the parasitic drag (a falcon's stoop)

# --- Flapping --------------------------------------------------------------------------------------
var flap_period := 0.25     ## s, one wingbeat: the fastest you can flap
var downstroke := 0.5       ## share of the beat that makes thrust
var flap_accel := 22.0      ## m/s^2 during the downstroke at zero airspeed, full strength (x downstroke = mean)
var flap_speed_cap := 26.0  ## m/s, airspeed at which a flap stops adding thrust (it fades as (1 - v/cap)^2)
var flap_tilt_deg := 30.0   ## at cruise, thrust tilts this far from the flight path toward the lift vector
var flap_tilt_slow_deg := 65.0  ## ... and this far at a standstill (a takeoff flap mostly lifts)

# --- Energy (EnergyModel) --------------------------------------------------------------------------
var burst_max := 16.0       ## short-term reserve, in full-strength flaps (~5-8 s of held flapping)
var burst_regen := 3.0      ## flaps per second refilled while the wings aren't driving (scaled by stamina)
var stamina_flaps := 240.0  ## medium-term reserve: flaps from full to empty
var stamina_regen_glide := 0.004   ## per second while not flapping (0..1 scale)
var stamina_regen_perch := 0.08    ## per second while perched
var weak_flap := 0.25       ## strength of a flap with the burst reserve empty

# --- Ground effect ---------------------------------------------------------------------------------
var ground_effect_lift := 0.25    ## extra lift on the ground (fades out by ground_effect_height)
var ground_effect_thrust := 0.8   ## extra wingbeat thrust on the ground

# --- Perching --------------------------------------------------------------------------------------
var grab_radius := 1.5      ## m, catch sphere around a perch's grip point
var grab_speed_factor := 1.2  ## max closing speed for a catch = this * V_stall
var hop_speed := 3.5        ## m/s, release launch along the perch facing

# --- Derived (call derive() after changing anything above) -----------------------------------------
var aspect_ratio := 0.0
var k_induced := 0.0
var cd0 := 0.0
var cl_alpha := 0.0         ## per radian, finite wing
var cl_best := 0.0
var alpha_best := 0.0       ## rad
var alpha_stall := 0.0      ## rad
var v_best := 0.0           ## m/s, best-glide airspeed
var v_stall := 0.0          ## m/s
var glide_angle := 0.0      ## rad (positive number; the path is that far below the horizon)
var grab_speed_max := 0.0   ## m/s
var ground_effect_height := 0.0   ## m: ground effect fades out by this height (1.5 spans, at least 1.5 m)


func derive() -> BirdProfile:
	aspect_ratio = span * span / wing_area
	k_induced = 1.0 / (PI * oswald * aspect_ratio)
	cd0 = 1.0 / (4.0 * glide_ratio * glide_ratio * k_induced)
	# Helmbold / lifting-line slope for a finite wing.
	cl_alpha = TAU * aspect_ratio / (aspect_ratio + 2.0)
	cl_best = sqrt(cd0 / k_induced)
	alpha_best = cl_best / cl_alpha
	alpha_stall = cl_max / cl_alpha
	var w := 2.0 * mass * G / (RHO * wing_area)
	v_best = sqrt(w / cl_best)
	v_stall = sqrt(w / cl_max)
	glide_angle = atan(1.0 / glide_ratio)
	grab_speed_max = grab_speed_factor * v_stall
	ground_effect_height = maxf(1.5, span * 1.5)
	return self


func wing_loading() -> float:
	return mass * G / wing_area


func summary() -> String:
	return "%s: L/D %.1f (%.1f deg), V* %.1f m/s, stall %.1f m/s, CL* %.2f / %.2f, AR %.1f, %.0f N/m2" % [
		display_name, glide_ratio, rad_to_deg(glide_angle), v_best, v_stall, cl_best, cl_max, aspect_ratio, wing_loading()]


# --- Presets ---------------------------------------------------------------------------------------

const IDS: Array[String] = ["crow", "owl", "hawk", "falcon", "sparrow"]


static func by_id(bird_id: String) -> BirdProfile:
	match bird_id:
		"owl": return owl()
		"hawk": return hawk()
		"falcon": return falcon()
		"sparrow": return sparrow()
	return crow()


static func all() -> Array[BirdProfile]:
	var out: Array[BirdProfile] = []
	for i in IDS:
		out.append(by_id(i))
	return out


## The all-rounder: fair glide, cheap flaps, forgiving stall margin.
static func crow() -> BirdProfile:
	var p := BirdProfile.new()
	p.id = "crow"; p.display_name = "Crow"; p.blurb = "All-rounder. Agile, tireless flapper."
	p.mass = 0.55; p.wing_area = 0.16; p.span = sqrt(5.8 * 0.16); p.oswald = 0.82; p.glide_ratio = 10.0; p.cl_max = 1.7
	p.body_length = 0.45; p.tail_length = 0.18
	p.max_bank_deg = 80.0; p.roll_rate_deg = 320.0; p.alpha_rate_deg = 200.0
	p.flap_period = 0.28; p.flap_accel = 22.0; p.flap_speed_cap = 26.0
	p.burst_max = 16.0; p.burst_regen = 3.0; p.stamina_flaps = 260.0
	return p.derive()


## Low wing loading: floats, very slow stall, short-span broad wings; weak at speed.
static func owl() -> BirdProfile:
	var p := BirdProfile.new()
	p.id = "owl"; p.display_name = "Owl"; p.blurb = "Floats. Lowest stall speed, gentle at the perch."
	p.mass = 0.8; p.wing_area = 0.22; p.span = sqrt(5.5 * 0.22); p.oswald = 0.89; p.glide_ratio = 9.0; p.cl_max = 1.9
	p.body_length = 0.38; p.tail_length = 0.12
	p.max_bank_deg = 75.0; p.roll_rate_deg = 180.0; p.alpha_rate_deg = 175.0
	p.flap_period = 0.4; p.flap_accel = 23.0; p.flap_speed_cap = 22.0
	p.burst_max = 12.0; p.burst_regen = 2.2; p.stamina_flaps = 200.0
	p.grab_speed_factor = 1.3
	return p.derive()


## Soarer: best glide by far, slotted tips, but flapping is costly.
static func hawk() -> BirdProfile:
	var p := BirdProfile.new()
	p.id = "hawk"; p.display_name = "Hawk"; p.blurb = "Glides forever. Flapping costs dearly."
	p.mass = 1.2; p.wing_area = 0.28; p.span = sqrt(6.0 * 0.28); p.oswald = 0.89; p.glide_ratio = 12.0; p.cl_max = 1.6
	p.body_length = 0.55; p.tail_length = 0.22
	p.max_bank_deg = 65.0; p.roll_rate_deg = 120.0; p.alpha_rate_deg = 135.0
	p.flap_period = 0.45; p.flap_accel = 22.0; p.flap_speed_cap = 24.0
	p.burst_max = 8.0; p.burst_regen = 1.4; p.stamina_flaps = 130.0
	p.stamina_regen_glide = 0.008
	return p.derive()


## Fast and punishing: high wing loading, thin stall margin, a deep wing tuck for the stoop.
static func falcon() -> BirdProfile:
	var p := BirdProfile.new()
	p.id = "falcon"; p.display_name = "Falcon"; p.blurb = "Fast. Tuck to stoop. Thin stall margin."
	p.mass = 0.8; p.wing_area = 0.107; p.span = sqrt(8.0 * 0.107); p.oswald = 0.63; p.glide_ratio = 10.5; p.cl_max = 1.4
	p.body_length = 0.42; p.tail_length = 0.16
	p.max_bank_deg = 85.0; p.roll_rate_deg = 240.0; p.alpha_rate_deg = 150.0
	p.fold_area_cut = 0.6; p.fold_span_cut = 0.65; p.fold_drag_cut = 0.6
	p.flap_period = 0.2; p.flap_accel = 22.0; p.flap_speed_cap = 36.0
	p.burst_max = 14.0; p.burst_regen = 3.0; p.stamina_flaps = 240.0
	p.grab_speed_factor = 1.15
	return p.derive()


## Tiny and flappy: steep glide, rapid cheap wingbeats, tight turns.
static func sparrow() -> BirdProfile:
	var p := BirdProfile.new()
	p.id = "sparrow"; p.display_name = "Sparrow"; p.blurb = "Steep glide, rapid wingbeats, turns on a dime."
	p.mass = 0.06; p.wing_area = 0.018; p.span = sqrt(6.0 * 0.018); p.oswald = 0.55; p.glide_ratio = 6.5; p.cl_max = 1.5
	p.body_length = 0.15; p.tail_length = 0.07
	p.max_bank_deg = 85.0; p.roll_rate_deg = 420.0; p.alpha_rate_deg = 210.0
	p.flap_period = 0.1; p.flap_accel = 30.0; p.flap_speed_cap = 22.0
	p.burst_max = 40.0; p.burst_regen = 8.0; p.stamina_flaps = 800.0
	p.grab_radius = 1.0; p.hop_speed = 2.5
	return p.derive()
