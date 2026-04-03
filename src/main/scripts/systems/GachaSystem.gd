# GachaSystem.gd
# Place at: src/main/scripts/systems/GachaSystem.gd
# Attach to: GachaSystem.tscn (Node)
#
# Works with Anthony's UnitData Resource system.
# Banner pools reference .tres file paths — the system loads and duplicates
# them on pull so each player instance is independent.
# ─────────────────────────────────────────────────────────────────────────────

extends Node

# ── Pull Rate Constants ───────────────────────────────────────────────────────
const BASE_5STAR_RATE  := 0.020   # 2.0% base chance
const BASE_4STAR_RATE  := 0.051   # 5.1% base chance
const SOFT_PITY_START  := 40      # Soft pity scaling begins
const HARD_PITY        := 60      # Guaranteed 5★ at this pull count
const GUARANTEED_4STAR := 10      # Guaranteed 4★ every 10 pulls
const PITY_SAVE_PATH   := "user://gacha_pity.json"

# ── Pity State ────────────────────────────────────────────────────────────────
var pity_5star          : int  = 0
var pity_4star          : int  = 0
var guaranteed_featured : bool = false

# ── Active Banner ─────────────────────────────────────────────────────────────
# Banner format:
# {
#   "name": "Stormborn Banner",
#   "featured_5star":      "res://src/main/resources/units/kael.tres",
#   "standard_5star_pool": ["res://...kira.tres", "res://...sela.tres", ...],
#   "4star_pool":          ["res://...unit_a.tres", ...],
#   "3star_pool":          ["res://...filler_a.tres", ...]
# }
var current_banner : Dictionary = {}

# ── Signals ───────────────────────────────────────────────────────────────────
## Emitted after every single pull resolves.
## result contains the pulled UnitData resource + metadata.
signal pull_result(result: Dictionary)
# result = {
#   "unit":        UnitData,   <- the actual resource, ready to use
#   "rarity":      int,        <- 3, 4, or 5
#   "is_featured": bool,
#   "pity_count":  int         <- pity counter after this pull
# }


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

## Load a banner before any pulls happen.
func load_banner(banner: Dictionary) -> void:
	current_banner = banner
	print("[GachaSystem] Banner loaded: ", banner.get("name", "Unnamed"))


## Single pull. Returns result Dictionary and emits pull_result signal.
func pull_single() -> Dictionary:
	assert(current_banner.size() > 0, "[GachaSystem] No banner loaded — call load_banner() first.")
	var result := _resolve_pull()
	pull_result.emit(result)
	return result


## Ten pulls at once. Returns Array of result Dictionaries.
func pull_ten() -> Array:
	assert(current_banner.size() > 0, "[GachaSystem] No banner loaded — call load_banner() first.")
	var results : Array = []
	for i in 10:
		results.append(_resolve_pull())
	return results


## Current pull count toward next 5star.
func get_5star_pity() -> int:
	return pity_5star


## Current pull count toward next guaranteed 4star.
func get_4star_pity() -> int:
	return pity_4star


## Whether the player is guaranteed the featured unit on next 5star.
func has_guaranteed_featured() -> bool:
	return guaranteed_featured


## Serialize the current pity counters and persist them to disk.
## The JSON file stores a master Dictionary keyed by banner_id + banner_type
## so each banner tracks its pity independently.
func save_pity_state(banner_id: Variant = null, banner_type: Variant = null) -> Dictionary:
	var pity_state := _build_pity_state()
	var master_dict := _load_pity_master_dict()
	var banner_key := _get_banner_pity_key(banner_id, banner_type)

	master_dict[banner_key] = pity_state

	var save_file := FileAccess.open(PITY_SAVE_PATH, FileAccess.WRITE)
	if save_file == null:
		push_error("[GachaSystem] Failed to open pity save file for writing: %s" % PITY_SAVE_PATH)
		return pity_state

	save_file.store_string(JSON.stringify(master_dict, "\t"))
	print("[GachaSystem] Pity saved for banner key: %s" % banner_key)
	return pity_state


## Restore pity state from disk for the requested banner.
## Pass banner_id/banner_type when loading before load_banner(); otherwise
## the current banner is used. The optional state Dictionary is only kept as
## a fallback so older callers do not break if no disk entry exists yet.
func load_pity_state(state: Dictionary = {}, banner_id: Variant = null, banner_type: Variant = null) -> void:
	var pity_state := _get_empty_pity_state()
	var master_dict := _load_pity_master_dict()
	var banner_key := _get_banner_pity_key(banner_id, banner_type)

	if master_dict.has(banner_key):
		var disk_state: Variant = master_dict.get(banner_key, {})
		if disk_state is Dictionary:
			pity_state = disk_state
	elif not state.is_empty():
		pity_state = state.duplicate(true)

	_apply_pity_state(pity_state)
	print("[GachaSystem] Pity restored for banner key %s — 5star pity: %d | guaranteed: %s" \
		% [banner_key, pity_5star, str(guaranteed_featured)])


func _build_pity_state() -> Dictionary:
	return {
		"pity_5star":          pity_5star,
		"pity_4star":          pity_4star,
		"guaranteed_featured": guaranteed_featured,
		"banner_id":           current_banner.get("banner_id", ""),
		"banner_type":         current_banner.get("banner_type", ""),
		"banner_name":         current_banner.get("name", "")
	}


func _get_empty_pity_state() -> Dictionary:
	return {
		"pity_5star":          0,
		"pity_4star":          0,
		"guaranteed_featured": false
	}


func _apply_pity_state(state: Dictionary) -> void:
	pity_5star = int(state.get("pity_5star", 0))
	pity_4star = int(state.get("pity_4star", 0))
	guaranteed_featured = bool(state.get("guaranteed_featured", false))


func _get_banner_pity_key(banner_id: Variant = null, banner_type: Variant = null) -> String:
	# Fall back to current_banner fields so existing banner Dictionaries keep
	# working even if a caller does not pass explicit identifiers yet.
	var resolved_banner_id: Variant = banner_id if banner_id != null else current_banner.get("banner_id", current_banner.get("name", "default_banner"))
	var resolved_banner_type: Variant = banner_type if banner_type != null else current_banner.get("banner_type", "default_type")
	return "%s_%s" % [str(resolved_banner_id), str(resolved_banner_type)]


func _load_pity_master_dict() -> Dictionary:
	if not FileAccess.file_exists(PITY_SAVE_PATH):
		return {}

	var save_file := FileAccess.open(PITY_SAVE_PATH, FileAccess.READ)
	if save_file == null:
		push_error("[GachaSystem] Failed to open pity save file for reading: %s" % PITY_SAVE_PATH)
		return {}

	var raw_json := save_file.get_as_text()
	if raw_json.strip_edges().is_empty():
		return {}

	var parsed_data: Variant = JSON.parse_string(raw_json)
	if not (parsed_data is Dictionary):
		push_error("[GachaSystem] Pity save file is invalid JSON or not a Dictionary: %s" % PITY_SAVE_PATH)
		return {}

	return parsed_data.duplicate(true)


# ─────────────────────────────────────────────────────────────────────────────
# INTERNAL LOGIC
# ─────────────────────────────────────────────────────────────────────────────

func _resolve_pull() -> Dictionary:
	pity_5star += 1
	pity_4star += 1

	var rarity := _determine_rarity()
	var result : Dictionary

	match rarity:
		5:
			result     = _resolve_5star()
			pity_5star = 0
			pity_4star = 0   # 5star resets both counters
		4:
			result     = _resolve_4star()
			pity_4star = 0
		_:
			result     = _resolve_3star()

	result["pity_count"] = pity_5star
	_log_pull(result)
	return result


func _determine_rarity() -> int:
	# Hard pity — always 5star
	if pity_5star >= HARD_PITY:
		return 5

	# Guaranteed 4star window — still possible to spike into 5star
	if pity_4star >= GUARANTEED_4STAR:
		if randf() < _get_5star_rate():
			return 5
		return 4

	# Normal RNG
	var roll := randf()
	if roll < _get_5star_rate():
		return 5
	elif roll < _get_5star_rate() + BASE_4STAR_RATE:
		return 4
	return 3


## 5star rate with soft pity scaling.
## Scales linearly from BASE_5STAR_RATE to 100% between pulls 40 and 60.
func _get_5star_rate() -> float:
	if pity_5star < SOFT_PITY_START:
		return BASE_5STAR_RATE
	var range_size    := float(HARD_PITY - SOFT_PITY_START)
	var pulls_in_soft := float(pity_5star - SOFT_PITY_START)
	return lerp(BASE_5STAR_RATE, 1.0, pulls_in_soft / range_size)


func _resolve_5star() -> Dictionary:
	var featured_path  : String = current_banner.get("featured_5star", "")
	var standard_paths : Array  = current_banner.get("standard_5star_pool", [])

	# Guaranteed featured — skip the 50/50 flip
	if guaranteed_featured or standard_paths.is_empty():
		guaranteed_featured = false
		return _load_unit_result(5, featured_path, true)

	# 50/50 flip
	if randf() < 0.5:
		guaranteed_featured = false
		return _load_unit_result(5, featured_path, true)
	else:
		# Lost 50/50 — give standard unit, save guarantee for next time
		guaranteed_featured = true
		var path : String = standard_paths[randi() % standard_paths.size()]
		return _load_unit_result(5, path, false)


func _resolve_4star() -> Dictionary:
	var pool : Array = current_banner.get("4star_pool", [])
	if pool.is_empty():
		push_error("[GachaSystem] 4star pool is empty! Check banner data.")
		return _make_fallback_result(4)
	var path : String = pool[randi() % pool.size()]
	return _load_unit_result(4, path, false)


func _resolve_3star() -> Dictionary:
	var pool : Array = current_banner.get("3star_pool", [])
	if pool.is_empty():
		push_error("[GachaSystem] 3star pool is empty! Check banner data.")
		return _make_fallback_result(3)
	var path : String = pool[randi() % pool.size()]
	return _load_unit_result(3, path, false)


## Loads a UnitData .tres file, duplicates it so each instance is independent,
## and wraps it in a result Dictionary.
## duplicate(true) is critical — without it all players share the same Resource
## object and modifying one unit's level would modify ALL of them.
func _load_unit_result(rarity: int, path: String, is_featured: bool) -> Dictionary:
	if path == "" or not ResourceLoader.exists(path):
		push_error("[GachaSystem] Unit resource not found: %s" % path)
		return _make_fallback_result(rarity)

	var unit : UnitData = load(path).duplicate(true)
	unit.star_level = rarity

	return {
		"unit":        unit,
		"rarity":      rarity,
		"is_featured": is_featured,
		"pity_count":  pity_5star
	}


## Placeholder result when a resource path is broken.
## Should only appear during dev if banner data is misconfigured.
func _make_fallback_result(rarity: int) -> Dictionary:
	var fallback       := UnitData.new()
	fallback.unit_name  = "???"
	fallback.unit_id    = "fallback_%d" % rarity
	fallback.star_level = rarity
	return {
		"unit":        fallback,
		"rarity":      rarity,
		"is_featured": false,
		"pity_count":  pity_5star
	}


func _log_pull(result: Dictionary) -> void:
	var unit     : UnitData = result["unit"]
	var stars    := "★".repeat(result["rarity"])
	var featured := " [FEATURED]" if result["is_featured"] else ""
	print("[GachaSystem] %s %s%s" % [stars, unit.unit_name, featured])
