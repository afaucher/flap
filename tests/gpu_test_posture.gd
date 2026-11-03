extends "res://tests/test_posture.gd"
## test_posture with the feathers placed on the GPU (BirdRig.gpu_feathers): a sitting bird's lean then reads its tips
## through LeanProbe, a frame or two late, and must still keep the tail and wingtips out of what it sits on. Windowed.


func setup() -> void:
	BirdRig.gpu_feathers = true
	await super()
	BirdRig.gpu_feathers = false
