# GachaSystem.gd
# Place at: src/main/scripts/systems/GachaSystem.gd
# Attach to: GachaSystem.tscn (Node)
#
# Works with Anthony's UnitData Resource system.
# Banner pools reference .tres file paths — the system loads and duplicates
# them on pull so each player instance is independent.
# ─────────────────────────────────────────────────────────────────────────────

extends Node

# ── Pull Rate Constants (defaults — overridden per banner in load_banner) ─────
const BASE_5STAR_RATE  := 0.020   # 2.0% base chance
const BASE_4STAR_RATE  := 0.051   # 5.1% base chance
const SOFT_PITY_START  := 40      # Soft pity scaling begins
const HARD_PITY        := 60      # Guaranteed 5★ at this pull count
const GUARANTEED_4STAR := 10      # Pity counter: 4★+ on 10th pull of streak (5★ satisfies; 5★ resets counter)

# Active rate table — copied from the loaded banner (falls back to const defaults).
var _base_5star_rate  : float = BASE_5STAR_RATE
var _base_4star_rate  : float = BASE_4STAR_RATE
var _soft_pity_start  : int   = SOFT_PITY_START
var _hard_pity        : int   = HARD_PITY
var _guaranteed_4star : int   = GUARANTEED_4STAR

# ── Pity State (independent track per banner_type) ───────────────────────────
var _pity: Dictionary = {
	BannerData.BANNER_TYPE_CHARACTER: {
		"pity_5star": 0, "pity_4star": 0, "guaranteed_featured": false,
	},
	BannerData.BANNER_TYPE_GEAR: {
		"pity_5star": 0, "pity_4star": 0, "guaranteed_featured": false,
	},
}

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
## Emitted after every single pull resolves (legacy Dictionary bridge).
signal pull_result(result: Dictionary)

## Emitted after pull_single (1 result) or pull_ten (10 results) completes.
signal pull_completed(results: Array)  # Array of PullResult


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────────────────

## Load a banner before any pulls happen. Accepts BannerData or Dictionary.
func load_banner(banner) -> void:
	if banner is BannerData:
		current_banner = banner.to_gacha_dictionary()
	elif banner is Dictionary:
		current_banner = banner
	else:
		push_error("[GachaSystem] load_banner() expects BannerData or Dictionary.")
		return

	_apply_banner_rates(current_banner)
	print("[GachaSystem] Banner loaded: ", current_banner.get("name", "Unnamed"))


## Single pull. Returns PullResult; emits pull_result (legacy dict) and pull_completed.
func pull_single() -> PullResult:
	assert(current_banner.size() > 0, "[GachaSystem] No banner loaded — call load_banner() first.")
	var pull := _resolve_pull_result()
	pull_result.emit(pull.to_legacy_dictionary())
	pull_completed.emit([pull])
	return pull


## Ten pulls at once. Returns Array of PullResult; emits pull_completed once.
func pull_ten() -> Array:
	assert(current_banner.size() > 0, "[GachaSystem] No banner loaded — call load_banner() first.")
	var pulls : Array = []
	for i in 10:
		pulls.append(_resolve_pull_result())
	pull_completed.emit(pulls)
	return pulls


## Current pull count toward next 5star on the active banner's pity track.
func get_5star_pity() -> int:
	return _active_pity().pity_5star


## Current pull count toward next guaranteed 4star on the active banner's pity track.
func get_4star_pity() -> int:
	return _active_pity().pity_4star


## Whether the player is guaranteed the featured item on next 5star (active track).
func has_guaranteed_featured() -> bool:
	return _active_pity().guaranteed_featured


## Dev/test helper — sets pity on the currently loaded banner's track.
func debug_set_pity(pity_5star: int, pity_4star: int, guaranteed_featured: bool = false) -> void:
	var track := _active_pity()
	track.pity_5star = pity_5star
	track.pity_4star = pity_4star
	track.guaranteed_featured = guaranteed_featured


## Serialize pity state for saving. Pass result to your SaveManager.
func save_pity_state() -> Dictionary:
	return {
		"pity_by_banner_type": {
			BannerData.BANNER_TYPE_CHARACTER: _pity[BannerData.BANNER_TYPE_CHARACTER].duplicate(),
			BannerData.BANNER_TYPE_GEAR: _pity[BannerData.BANNER_TYPE_GEAR].duplicate(),
		},
		"banner_name": current_banner.get("name", ""),
	}


## Restore pity state from a save Dictionary.
## Call this on game load BEFORE calling load_banner().
## Accepts the new per-type format or legacy flat character-track saves.
func load_pity_state(state: Dictionary) -> void:
	if state.has("pity_by_banner_type"):
		var saved: Dictionary = state.pity_by_banner_type
		for banner_type in saved:
			_pity[banner_type] = _normalize_pity_track(saved[banner_type])
	elif state.is_empty():
		_pity[BannerData.BANNER_TYPE_CHARACTER] = _new_pity_track()
		_pity[BannerData.BANNER_TYPE_GEAR] = _new_pity_track()
	else:
		_pity[BannerData.BANNER_TYPE_CHARACTER] = _normalize_pity_track(state)

	var active := _active_pity()
	print("[GachaSystem] Pity restored — %s track: 5★=%d 4★=%d guaranteed=%s" \
		% [_banner_type(), active.pity_5star, active.pity_4star, str(active.guaranteed_featured)])


# ─────────────────────────────────────────────────────────────────────────────
# INTERNAL LOGIC
# ─────────────────────────────────────────────────────────────────────────────

func _resolve_pull_result() -> PullResult:
	var result_dict := _resolve_pull()
	return PullResult.from_legacy_dictionary(result_dict)


func _resolve_pull() -> Dictionary:
	var track := _active_pity()
	track.pity_5star += 1
	track.pity_4star += 1

	var rarity := _determine_rarity()
	var result : Dictionary

	match rarity:
		5:
			result          = _resolve_5star()
			track.pity_5star = 0
			track.pity_4star = 0   # 5star resets both counters
		4:
			result          = _resolve_from_pool(4)
			track.pity_4star = 0
		_:
			result = _resolve_from_pool(3)

	result["pity_count"] = track.pity_5star
	_log_pull(result)
	return result


func _determine_rarity() -> int:
	var track := _active_pity()
	# Hard pity — always 5star
	if track.pity_5star >= _hard_pity:
		return 5

	# Guaranteed 4star window — still possible to spike into 5star
	if track.pity_4star >= _guaranteed_4star:
		if randf() < _get_5star_rate():
			return 5
		return 4

	# Normal RNG
	var roll := randf()
	if roll < _get_5star_rate():
		return 5
	elif roll < _get_5star_rate() + _base_4star_rate:
		return 4
	return 3


## 5star rate with soft pity scaling.
## Scales linearly from base rate to 100% between soft pity start and hard pity.
func _get_5star_rate() -> float:
	var track := _active_pity()
	if track.pity_5star < _soft_pity_start:
		return _base_5star_rate
	var range_size    := float(_hard_pity - _soft_pity_start)
	if range_size <= 0.0:
		return 1.0
	var pulls_in_soft := float(track.pity_5star - _soft_pity_start)
	return lerp(_base_5star_rate, 1.0, pulls_in_soft / range_size)


func _apply_banner_rates(banner: Dictionary) -> void:
	_base_5star_rate  = banner.get("base_5star_rate", BASE_5STAR_RATE)
	_base_4star_rate  = banner.get("base_4star_rate", BASE_4STAR_RATE)
	_soft_pity_start  = banner.get("soft_pity_start", SOFT_PITY_START)
	_hard_pity        = banner.get("hard_pity", HARD_PITY)
	_guaranteed_4star = banner.get("guaranteed_4star", GUARANTEED_4STAR)


func _new_pity_track() -> Dictionary:
	return {"pity_5star": 0, "pity_4star": 0, "guaranteed_featured": false}


func _normalize_pity_track(data) -> Dictionary:
	if data is Dictionary:
		return {
			"pity_5star": data.get("pity_5star", 0),
			"pity_4star": data.get("pity_4star", 0),
			"guaranteed_featured": data.get("guaranteed_featured", false),
		}
	return _new_pity_track()


func _ensure_pity_track(banner_type: String) -> Dictionary:
	if not _pity.has(banner_type):
		_pity[banner_type] = _new_pity_track()
	return _pity[banner_type]


func _active_pity() -> Dictionary:
	return _ensure_pity_track(_banner_type())


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
	var track := _active_pity()
	if track.guaranteed_featured or standard_paths.is_empty():
		track.guaranteed_featured = false
		return _build_featured_result(featured_path)

	# 50/50 flip
	if randf() < 0.5:
		track.guaranteed_featured = false
		return _build_featured_result(featured_path)

	# Lost 50/50 — standard reward, save the guarantee for next time
	track.guaranteed_featured = true
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
		"pity_count":  _active_pity().pity_5star,
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
		"pity_count":  _active_pity().pity_5star,
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
			"pity_count":  _active_pity().pity_5star,
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
		"pity_count":  _active_pity().pity_5star,
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
