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
const GUARANTEED_4STAR := 10      # Pity counter: 4★+ on 10th pull of streak (5★ satisfies; 5★ resets counter)

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


## Serialize pity state for saving. Pass result to your SaveManager.
func save_pity_state() -> Dictionary:
	return {
		"pity_5star":          pity_5star,
		"pity_4star":          pity_4star,
		"guaranteed_featured": guaranteed_featured,
		"banner_name":         current_banner.get("name", "")
	}


## Restore pity state from a save Dictionary.
## Call this on game load BEFORE calling load_banner().
func load_pity_state(state: Dictionary) -> void:
	pity_5star          = state.get("pity_5star", 0)
	pity_4star          = state.get("pity_4star", 0)
	guaranteed_featured = state.get("guaranteed_featured", false)
	print("[GachaSystem] Pity restored — 5star pity: %d | guaranteed: %s" \
		% [pity_5star, str(guaranteed_featured)])


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
			result     = _resolve_from_pool(4)
			pity_4star = 0
		_:
			result     = _resolve_from_pool(3)

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


# ── Category resolution ───────────────────────────────────────────────────────

## Raw dictionaries without the key are treated as character banners.
func _banner_type() -> String:
	return current_banner.get("banner_type", BannerData.BANNER_TYPE_CHARACTER)


func _is_gear_banner() -> bool:
	return _banner_type() == BannerData.BANNER_TYPE_GEAR


## Pool this banner draws from at a given rarity.
## 5star units live in standard_5star_pool because featured_5star is separate;
## everything else follows the unit_Nstar_pool / gear_Nstar_pool naming.
func _pick_pool(rarity: int) -> Array:
	if _is_gear_banner():
		return current_banner.get("gear_%dstar_pool" % rarity, [])
	if rarity == 5:
		return current_banner.get("standard_5star_pool", [])
	return current_banner.get("unit_%dstar_pool" % rarity, [])


## 3star and 4star buckets — no featured logic at these rarities.
func _resolve_from_pool(rarity: int) -> Dictionary:
	var pool := _pick_pool(rarity)
	if pool.is_empty():
		push_error("[GachaSystem] %dstar pool is empty on %s banner! Check banner data." \
			% [rarity, _banner_type()])
		return _make_fallback_result(rarity)

	var path : String = pool[randi() % pool.size()]

	if _is_gear_banner():
		return _build_gear_result(rarity, path)

	path = _resolve_starter_slot_if_needed(path)
	return _build_unit_result(rarity, path, false)


## Featured 50/50 + guarantee. Identical on both banner types — only the pool
## the 50/50 loses into differs (standard_5star_pool vs gear_5star_pool).
func _resolve_5star() -> Dictionary:
	var featured_path : String = current_banner.get("featured_5star", "")
	var standard_paths := _pick_pool(5)

	# Misconfigured banner. Roll from the pool rather than loading "" and
	# showing the player a ???.
	if featured_path.strip_edges().is_empty():
		push_warning("[GachaSystem] %s banner has no featured_5star — rolling from pool." \
			% _banner_type())
		return _resolve_from_pool(5)

	# Guaranteed featured, or nothing to lose the 50/50 into
	if guaranteed_featured or standard_paths.is_empty():
		guaranteed_featured = false
		return _build_featured_result(featured_path)

	# 50/50 flip
	if randf() < 0.5:
		guaranteed_featured = false
		return _build_featured_result(featured_path)

	# Lost 50/50 — standard reward, save the guarantee for next time
	guaranteed_featured = true
	var path : String = standard_paths[randi() % standard_paths.size()]
	if _is_gear_banner():
		return _build_gear_result(5, path)
	return _build_unit_result(5, path, false)


func _build_featured_result(path: String) -> Dictionary:
	if _is_gear_banner():
		return _build_gear_result(5, path, true)
	return _build_unit_result(5, path, true)


## If the pick is the starter slot placeholder, roll uniformly among starter_pool (~16.67% each).
func _resolve_starter_slot_if_needed(path: String) -> String:
	var starter_slot: String = current_banner.get("starter_slot_path", "")
	if starter_slot.is_empty() or path != starter_slot:
		return path

	var starter_pool: Array = current_banner.get("starter_pool", [])
	if starter_pool.is_empty():
		push_error("[GachaSystem] starter_slot_path rolled but starter_pool is empty.")
		return path

	return starter_pool[randi() % starter_pool.size()]


## True when the resolved path is one of the six starters (checked post-lottery).
func _is_starter_path(path: String) -> bool:
	var starter_pool : Array = current_banner.get("starter_pool", [])
	return path in starter_pool


# ── Result builders ───────────────────────────────────────────────────────────

## duplicate(true) is critical — without it every pull shares one Resource
## object and levelling one unit would level all of them.
func _build_unit_result(rarity: int, path: String, is_featured: bool) -> Dictionary:
	if path.strip_edges().is_empty() or not ResourceLoader.exists(path):
		push_error("[GachaSystem] Unit resource not found: %s" % path)
		return _make_fallback_result(rarity)

	var unit : UnitData = load(path).duplicate(true)
	var is_starter := _is_starter_path(path)

	# Starters always grant as their 1star base form — the pull's rarity bucket
	# is not their star level. Evolution is progression, not a banner product.
	unit.star_level = 1 if is_starter else rarity

	return {
		"unit":        unit,
		"rarity":      rarity,
		"is_featured": is_featured,
		"is_starter":  is_starter,
		"pity_count":  pity_5star,
	}


func _build_gear_result(rarity: int, path: String, is_featured: bool = false) -> Dictionary:
	if path.strip_edges().is_empty() or not ResourceLoader.exists(path):
		push_error("[GachaSystem] Gear resource not found: %s" % path)
		return _make_fallback_result(rarity)

	# GearData.rarity comes from the .tres — do NOT overwrite it with the pull
	# bucket the way units get star_level assigned.
	var gear : GearData = load(path).duplicate(true)

	return {
		"gear":        gear,
		"rarity":      rarity,
		"is_featured": is_featured,
		"is_starter":  false,
		"pity_count":  pity_5star,
	}


## Placeholder result when a resource path is broken.
## Should only appear during dev if banner data is misconfigured.
func _make_fallback_result(rarity: int) -> Dictionary:
	if _is_gear_banner():
		var fallback_gear := GearData.new()
		fallback_gear.gear_id   = "fallback_%d" % rarity
		fallback_gear.gear_name = "???"
		fallback_gear.rarity    = rarity
		return {
			"gear":        fallback_gear,
			"rarity":      rarity,
			"is_featured": false,
			"is_starter":  false,
			"pity_count":  pity_5star,
		}

	var fallback       := UnitData.new()
	fallback.unit_name  = "???"
	fallback.unit_id    = "fallback_%d" % rarity
	fallback.star_level = rarity
	return {
		"unit":        fallback,
		"rarity":      rarity,
		"is_featured": false,
		"is_starter":  false,
		"pity_count":  pity_5star,
	}


func _log_pull(result: Dictionary) -> void:
	var stars := "★".repeat(result["rarity"])
	var label := "???"
	if result.get("unit") != null:
		label = result["unit"].unit_name
	elif result.get("gear") != null:
		label = result["gear"].get_display_name()

	var tags := ""
	if result.get("is_featured", false):
		tags += " [FEATURED]"
	if result.get("is_starter", false):
		tags += " [STARTER]"

	print("[GachaSystem] %s %s%s" % [stars, label, tags])
