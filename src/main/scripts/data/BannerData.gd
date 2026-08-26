class_name BannerData
extends Resource

## Banner configuration for the gacha pull engine.
## Serialize as .tres files under src/main/resources/banners/.

enum BannerType {
	CHARACTER,
	GEAR,
}

const BANNER_TYPE_CHARACTER := "character"
const BANNER_TYPE_GEAR := "gear"

@export var banner_id: String = ""
@export var banner_name: String = ""
@export var banner_type: BannerType = BannerType.CHARACTER

# Unit pools — paths to UnitData .tres files.
@export var featured_5star: String = ""
@export var standard_5star_pool: Array[String] = []
@export var unit_4star_pool: Array[String] = []
@export var unit_3star_pool: Array[String] = []

## Path of the 4★ pool placeholder that expands into starter_pool (equal weight).
@export var starter_slot_path: String = ""
## The 6 starters. When starter_slot_path is rolled from unit_4star_pool, pick one at random (~16.67% each).
@export var starter_pool: Array[String] = []

# Gear pools — paths to GearData .tres files.
@export var gear_5star_pool: Array[String] = []
@export var gear_4star_pool: Array[String] = []
@export var gear_3star_pool: Array[String] = []

## On character banners, chance a 4★ pull is a unit vs 4★ gear (0.0–1.0).
@export_range(0.0, 1.0) var unit_4star_rate: float = 0.5

# Optional rate/pity overrides — mirror GachaSystem defaults until wired in Phase B.
@export var base_5star_rate: float = 0.020
@export var base_4star_rate: float = 0.051
@export var soft_pity_start: int = 40
@export var hard_pity: int = 60
@export var guaranteed_4star: int = 10


func get_banner_type_string() -> String:
	match banner_type:
		BannerType.CHARACTER:
			return BANNER_TYPE_CHARACTER
		BannerType.GEAR:
			return BANNER_TYPE_GEAR
		_:
			return BANNER_TYPE_CHARACTER


## Convert to the Dictionary shape GachaSystem expects today, plus fields for Phase B.
func to_gacha_dictionary() -> Dictionary:
	return {
		"banner_id": banner_id,
		"banner_name": banner_name,
		"banner_type": get_banner_type_string(),
		"name": banner_name,
		"featured_5star": featured_5star,
		"standard_5star_pool": standard_5star_pool.duplicate(),
		"4star_pool": unit_4star_pool.duplicate(),
		"3star_pool": unit_3star_pool.duplicate(),
		"unit_4star_pool": unit_4star_pool.duplicate(),
		"unit_3star_pool": unit_3star_pool.duplicate(),
		"starter_slot_path": starter_slot_path,
		"starter_pool": starter_pool.duplicate(),
		"gear_5star_pool": gear_5star_pool.duplicate(),
		"gear_4star_pool": gear_4star_pool.duplicate(),
		"gear_3star_pool": gear_3star_pool.duplicate(),
		"unit_4star_rate": unit_4star_rate,
		"base_5star_rate": base_5star_rate,
		"base_4star_rate": base_4star_rate,
		"soft_pity_start": soft_pity_start,
		"hard_pity": hard_pity,
		"guaranteed_4star": guaranteed_4star,
	}


## Returns true when required identity fields and banner-type rules pass.
func validate_basic() -> bool:
	var errors: Array[String] = []

	if banner_id.strip_edges().is_empty():
		errors.append("banner_id is required.")
	if banner_name.strip_edges().is_empty():
		errors.append("banner_name is required.")

	match banner_type:
		BannerType.CHARACTER:
			_validate_character_banner(errors)
		BannerType.GEAR:
			_validate_gear_banner(errors)
		_:
			errors.append("banner_type is invalid.")

	for error in errors:
		push_warning("[BannerData:%s] %s" % [banner_id if not banner_id.is_empty() else "?", error])

	return errors.is_empty()


func _validate_character_banner(errors: Array[String]) -> void:
	if featured_5star.strip_edges().is_empty():
		errors.append("character banner requires featured_5star.")

	if not gear_5star_pool.is_empty():
		errors.append("character banner must not include 5★ gear (gear_5star_pool must be empty).")

	if not starter_slot_path.strip_edges().is_empty() and starter_pool.is_empty():
		errors.append("starter_slot_path is set but starter_pool is empty.")
	if starter_slot_path.strip_edges().is_empty() and not starter_pool.is_empty():
		errors.append("starter_pool is set but starter_slot_path is empty.")
	if not starter_slot_path.strip_edges().is_empty() and starter_slot_path not in unit_4star_pool:
		errors.append("starter_slot_path must also appear in unit_4star_pool.")

	var has_unit_pool := not unit_3star_pool.is_empty() or not unit_4star_pool.is_empty()
	var has_gear_pool := not gear_3star_pool.is_empty() or not gear_4star_pool.is_empty()
	if not has_unit_pool and not has_gear_pool:
		errors.append("character banner needs at least one unit or gear pool entry.")


func _validate_gear_banner(errors: Array[String]) -> void:
	if not featured_5star.strip_edges().is_empty():
		errors.append("gear banner must not set featured_5star.")
	if not standard_5star_pool.is_empty():
		errors.append("gear banner must not include standard_5star_pool.")
	if not unit_4star_pool.is_empty() or not unit_3star_pool.is_empty():
		errors.append("gear banner must not include unit pools.")

	var has_gear_pool := not gear_3star_pool.is_empty() \
		or not gear_4star_pool.is_empty() \
		or not gear_5star_pool.is_empty()
	if not has_gear_pool:
		errors.append("gear banner needs at least one gear pool entry.")
