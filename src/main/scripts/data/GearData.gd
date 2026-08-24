class_name GearData
extends Resource

## Stub gear resource for gacha pulls and placeholder UI text.
## Full gear upgrade/equip systems are out of scope for the gacha PR.

@export var gear_id: String = ""
@export var gear_name: String = ""
@export var rarity: int = 3
@export var description: String = ""

# Placeholder stats — enough for pull results and UI labels for now.
@export var bonus_hp: int = 0
@export var bonus_atk: int = 0
@export var bonus_def: int = 0


func get_display_name() -> String:
	return gear_name if gear_name != "" else "???"


func get_short_summary() -> String:
	var name_text := get_display_name()
	var stars := "★".repeat(clampi(rarity, 0, 5))
	return "%s %s" % [stars, name_text]
