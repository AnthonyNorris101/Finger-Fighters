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
	if data == null:
		push_warning("BattleUnit.setup called without UnitData.")
		return
	max_hp = data.base_hp
	max_ult = data.skill_bar_max
	current_hp = max_hp
	current_ult = 0
	is_alive = true
	
func get_stat(stat: String):
	if data == null:
		return 0
	var base = data.get(stat)
	if base == null:
		base = 0
	var bonus = equipment_bonuses.get(stat, 0)
	return base + bonus
	
func take_damage(amount: int, attacker_element: ElementSystem.Element, attacker_crit_dmg: float = 1.25) -> int:
	if not is_alive:
		return 0
	var final_damage := ElementSystem.calculate_damage(
		amount,
		int(get_stat("base_def")),
		int(get_stat("base_elem_res")),
		attacker_element,
		data.element if data != null else ElementSystem.Element.NONE,
		attacker_crit_dmg
	)
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
	if not is_alive:
		return
	is_alive = false
	unit_died.emit()
