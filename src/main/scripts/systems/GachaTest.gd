# GachaTest.gd
# Legacy step-test host. Phase E tests removed — rate sim is GachaSimTest.gd.
# Set AUTO_RUN true only if you re-add step tests here.
extends Node

const AUTO_RUN := false


func _ready() -> void:
	if not AUTO_RUN:
		return
