class_name CombatSkill
extends RefCounted
## Difficulty (docs/design/combat_ai.md, 6): every knob takes skill away from a perfect pilot -- never adds speed,
## ammo or information. The "off" value of each is the honest maximum (ace is close to it). Presets: recruit
## (easy), pilot (medium, the default), ace (hard).

var name := "pilot"
var reaction := 0.25        ## s between the world and what the AI sees
var view_deg := 280.0       ## field of view; the rest, behind, is a blind cone
var scan_every := 0.8       ## s between looks into the blind cone ("checking six")
var aim_error_deg := 2.0    ## noise on where it aims
var min_quality := 1.1      ## fire when the predicted miss is under this x (fuse + blast)
var break_error := 0.15     ## s of error in a defensive break's timing
var bank_frac := 0.85       ## share of the bank limit it uses
var yoyos := true           ## knows the yo-yos
var tree_drag := false      ## drags seekers through trunks
var rest_at := 0.3          ## stamina at which it goes to rest
var ambush_patience := 25.0 ## s an ambusher sits on its perch waiting before it gives up
var decide_every := 0.15    ## s between target and mode decisions


static func preset(n: String) -> CombatSkill:
	var s := CombatSkill.new()
	s.name = n
	match n:
		"recruit":
			s.reaction = 0.45; s.view_deg = 220.0; s.scan_every = 1.5; s.aim_error_deg = 4.0; s.min_quality = 1.6
			s.break_error = 0.35; s.bank_frac = 0.7; s.yoyos = false; s.tree_drag = false; s.rest_at = 0.4
			s.ambush_patience = 12.0
			s.decide_every = 0.25
		"ace":
			s.reaction = 0.12; s.view_deg = 320.0; s.scan_every = 0.3; s.aim_error_deg = 0.5; s.min_quality = 0.9
			s.break_error = 0.05; s.bank_frac = 0.95; s.yoyos = true; s.tree_drag = true; s.rest_at = 0.2
			s.ambush_patience = 40.0
			s.decide_every = 0.1
		_:
			s.name = "pilot"
	return s
