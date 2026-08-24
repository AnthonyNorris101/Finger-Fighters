class_name PullResult
extends Resource

## One resolved gacha pull — unit, gear, or material/shard grant.
## Built by GachaSystem in Phase B; collection/UI consume this instead of raw dicts.

enum RewardType {
	UNIT,
	GEAR,
	MATERIAL,
}

@export var reward_type: RewardType = RewardType.UNIT
@export var rarity: int = 3
@export var is_featured: bool = false
@export var was_duplicate: bool = false

@export var unit: UnitData
@export var gear: GearData

# Shard / evo material info (MaterialReward stub in A4).
@export var material_id: String = ""
@export var shard_amount: int = 0
@export var source_unit_id: String = ""

## 5★ pity counter after this pull (carried from GachaSystem metadata).
@export var pity_count: int = 0


func get_reward_type_string() -> String:
	match reward_type:
		RewardType.UNIT:
			return "unit"
		RewardType.GEAR:
			return "gear"
		RewardType.MATERIAL:
			return "material"
		_:
			return "unit"


## Short label for logs and placeholder UI.
func get_display_name() -> String:
	match reward_type:
		RewardType.UNIT:
			return unit.unit_name if unit and unit.unit_name != "" else "???"
		RewardType.GEAR:
			return gear.get_display_name() if gear else "???"
		RewardType.MATERIAL:
			if shard_amount > 0 and source_unit_id != "":
				return "%d shards (%s)" % [shard_amount, source_unit_id]
			if material_id != "":
				return material_id
			return "Material"
	return "???"


## Bridge from current GachaSystem unit-only result dictionaries (Phase B removes this path).
static func from_legacy_dictionary(data: Dictionary) -> PullResult:
	var result := PullResult.new()
	result.rarity = data.get("rarity", 3)
	result.is_featured = data.get("is_featured", false)
	result.was_duplicate = data.get("was_duplicate", false)
	result.pity_count = data.get("pity_count", 0)

	if data.has("unit") and data["unit"] != null:
		result.reward_type = RewardType.UNIT
		result.unit = data["unit"]
	elif data.has("gear") and data["gear"] != null:
		result.reward_type = RewardType.GEAR
		result.gear = data["gear"]
	else:
		result.reward_type = RewardType.MATERIAL
		result.material_id = data.get("material_id", "")
		result.shard_amount = data.get("shard_amount", 0)
		result.source_unit_id = data.get("source_unit_id", "")

	return result
