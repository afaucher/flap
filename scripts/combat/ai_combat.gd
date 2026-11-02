class_name AICombat
extends RefCounted
## The AI's trigger finger -> CombatInput. Seekers: fire once locked. Rockets: fire when the target is in
## rocket range and the aim is within a few degrees of the lead point. Uses only what the launcher shows the
## player (its lock and lead), so it fights with the player's information as well as their authority.

var prefer := Launcher.Weapon.SEEKERS
var rocket_tolerance := 5.0   ## deg off the lead point it will still fire at


func sample(l: Launcher, _dt: float) -> CombatInput:
	var other := Launcher.Weapon.ROCKETS if l.weapon == Launcher.Weapon.SEEKERS else Launcher.Weapon.SEEKERS
	var next: bool = (l.weapon != prefer and int(l.ammo[prefer]) > 0) or (int(l.ammo[l.weapon]) == 0 and int(l.ammo[other]) > 0)
	if l.weapon == Launcher.Weapon.SEEKERS:
		return CombatInput.new(l.locked(), false, next)
	var t := l.target()
	if t == null:
		return CombatInput.new(false, false, next)
	var lead := l.lead_point(t)
	var to := lead - l.muzzle()
	var ok := to.length() < 28.0 and rad_to_deg(l.aim().angle_to(to)) < rocket_tolerance
	return CombatInput.new(ok, false, next)
