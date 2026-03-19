# BattleUnit.gd
class_name BattleUnit
extends Node

signal hp_changed(new_hp: int, max_hp: int)
signal ult_changed(new_charge: int, max_charge: int)
signal unit_died()

@export var data: UnitData

var current_hp: int
var max_hp: int
var current_ult: int
var max_ult: int
var is_alive: bool = true
var equipment_bonuses: Dictionary = {}  # e.g. { "atk": 5, "def": 3 }

func setup():
	max_hp = data.base_hp
	max_ult = data.ult_cost
	current_hp = max_hp
	current_ult = 0
	
func get_stat(stat: String) -> int:
	var base = data.get(stat)
	var bonus = equipment_bonuses.get(stat, 0)
	return base + bonus
	
func take_damage(amount: int, element: ElementSystem.Element) -> int:
	if not is_alive:
		return 0
	var multiplier = get_stat("base_crit")
	var defense_reduction = (1 - 10/get_stat("base_def"))
	var final_damage = max(1, int(amount*multiplier*defense_reduction))
	current_hp = clamp(current_hp - final_damage, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		die()
	return final_damage
	
func heal(amount: int):
	if not is_alive:
		return
	current_hp = clamp(current_hp + amount, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	
func can_act() -> bool:
	return is_alive
	
func die():
	is_alive = false
	unit_died.emit()
