# TurnQueueManager.gd
# ─────────────────────────────────────────────────────────────
# Manages turn order for up to 4 friendly + N enemy units
# using the Action Value (AV) system.
#
# Principle (from Honkai: Star Rail):
#   • Each unit starts with AV = 10000 / SPD
#   • Every tick the lowest AV unit acts, then refills by 10000 / SPD
#   • Faster units refill less → they act more often
#   • No RNG. Pure speed math.
#
# Team size: 4 units per side (per design doc)
# Positioning: removed — no front/back row
# ─────────────────────────────────────────────────────────────
class_name TurnQueueManager
extends Node


const BASE_GAUGE: float = 10000.0
const MAX_TEAM_SIZE: int = 4

var _units: Array[BattleUnit] = []
var _action_values: Dictionary = {}   # BattleUnit → float AV

# Emitted when a unit's turn begins. BattleManager listens to this.
signal turn_started(unit: BattleUnit)

# Emitted whenever the upcoming turn order changes. HUD listens to this.
signal queue_updated(preview: Array[BattleUnit])


# ─────────────────────────────────────────────────────────────
# SETUP
# ─────────────────────────────────────────────────────────────

func register_unit(unit: BattleUnit) -> void:
	_units.append(unit)
	_action_values[unit] = _av_refill(unit)    # First turn AV = one full cycle
	unit.unit_died.connect(_on_unit_died.bind(unit))

func _on_unit_died(unit: BattleUnit) -> void:
	_units.erase(unit)
	_action_values.erase(unit)
	queue_updated.emit(get_queue_preview())

# Returns how much AV a unit refills after each turn — core formula
func _av_refill(unit: BattleUnit) -> float:
	var spd: int = max(1, unit.get_stat("base_spd"))   # guard against div/0
	return BASE_GAUGE / float(spd)


# ─────────────────────────────────────────────────────────────
# CORE: ADVANCE TO NEXT TURN
# ─────────────────────────────────────────────────────────────

# Advances the AV clock and returns the next unit to act.
# Call once per turn from BattleManager; wait for that turn to resolve
# before calling again.
func advance_to_next_turn() -> BattleUnit:
	if _units.is_empty():
		return null

	_advance_av()
	var acting_unit := _pop_next_unit()
	if acting_unit == null:
		return null

	queue_updated.emit(get_queue_preview())
	turn_started.emit(acting_unit)
	return acting_unit


# Subtract the minimum AV from everyone, bringing the next unit to 0
func _advance_av() -> void:
	var min_av: float = INF
	for unit in _units:
		if _action_values[unit] < min_av:
			min_av = _action_values[unit]

	if min_av == INF or min_av == 0.0:
		return

	for unit in _units:
		_action_values[unit] -= min_av


# Selects the unit at (or nearest to) 0 AV, deducts their slot,
# and refills their AV for the next turn.
func _pop_next_unit() -> BattleUnit:
	var min_av: float = INF
	for unit in _units:
		if _action_values[unit] < min_av:
			min_av = _action_values[unit]

	# Collect all units at minimum (tiebreak candidates)
	var candidates: Array[BattleUnit] = []
	for unit in _units:
		if absf(_action_values[unit] - min_av) < 0.001:
			candidates.append(unit)

	candidates.sort_custom(_tiebreak_sort)
	var acting_unit: BattleUnit = candidates[0]

	# Refill from current AV (not from 0) so carry-over is preserved
	_action_values[acting_unit] += _av_refill(acting_unit)

	return acting_unit


# Tiebreak: higher SPD first → friends before enemies
func _tiebreak_sort(a: BattleUnit, b: BattleUnit) -> bool:
	var spd_a := a.get_stat("base_spd")
	var spd_b := b.get_stat("base_spd")
	if spd_a != spd_b:
		return spd_a > spd_b
	# Same speed: friendly units act before enemies
	if a.data.is_friend != b.data.is_friend:
		return a.data.is_friend
	return false


# ─────────────────────────────────────────────────────────────
# ACTION ADVANCE & DELAY
#
# Action Advance: moves a unit earlier in the queue
#   percent 0.0–1.0 → removes that fraction of BASE_GAUGE from their AV
#   e.g. 0.30 = 30% advance = removes 3000 AV
#
# Action Delay: pushes a unit later in the queue
#   e.g. Electric "Paralyze" can delay the target by 20%
# ─────────────────────────────────────────────────────────────

func action_advance(unit: BattleUnit, percent: float) -> void:
	if not _action_values.has(unit):
		return
	_action_values[unit] -= (BASE_GAUGE/unit.get_stat("base_spd")) * clamp(percent, 0.0, 1.0)
	# AV can go negative — they'll act at the very front of the next advance
	queue_updated.emit(get_queue_preview())

func action_delay(unit: BattleUnit, percent: float) -> void:
	if not _action_values.has(unit):
		return
	_action_values[unit] += BASE_GAUGE * clamp(percent, 0.0, 1.0)
	queue_updated.emit(get_queue_preview())


# ─────────────────────────────────────────────────────────────
# QUEUE PREVIEW (for UI)
#
# Simulates future turns on a copy of the AV state.
# Returns the next `lookahead` units in turn order.
# Safe to call any time — does not mutate real state.
# ─────────────────────────────────────────────────────────────

func get_queue_preview(lookahead: int = 8) -> Array[BattleUnit]:
	if _units.is_empty():
		return []

	var sim: Dictionary = {}
	for unit in _units:
		sim[unit] = _action_values[unit]

	var preview: Array[BattleUnit] = []

	while preview.size() < lookahead:
		# Find minimum sim AV
		var min_av: float = INF
		for unit in _units:
			if sim[unit] < min_av:
				min_av = sim[unit]
		if min_av == INF:
			break

		# Advance all
		for unit in _units:
			sim[unit] -= min_av

		# Collect at minimum
		var candidates: Array[BattleUnit] = []
		for unit in _units:
			if absf(sim[unit]) < 0.001:
				candidates.append(unit)

		candidates.sort_custom(func(a, b):
			return a.get_stat("base_spd") > b.get_stat("base_spd")
		)

		for unit in candidates:
			sim[unit] += BASE_GAUGE / float(max(1, unit.get_stat("base_spd")))
			preview.append(unit)
			if preview.size() >= lookahead:
				break

	return preview


# ─────────────────────────────────────────────────────────────
# SPEED CHANGE HOOK
#
# Call when a speed buff/debuff is applied mid-battle.
# Current AV is unchanged — only future refill amounts are affected.
# ─────────────────────────────────────────────────────────────

func on_speed_changed(_unit: BattleUnit) -> void:
	queue_updated.emit(get_queue_preview())


# ─────────────────────────────────────────────────────────────
# UTILITY
# ─────────────────────────────────────────────────────────────

# Returns the current AV of a unit as a 0.0–1.0 progress value
# Useful for a "time until next turn" indicator in the HUD
func get_turn_progress(unit: BattleUnit) -> float:
	if not _action_values.has(unit):
		return 0.0
	var av = _action_values[unit]
	var refill := _av_refill(unit)
	return clamp(1.0 - (av / refill), 0.0, 1.0)

func get_units_sorted_by_av() -> Array[BattleUnit]:
	var sorted := _units.duplicate()
	sorted.sort_custom(func(a, b): return _action_values[a] < _action_values[b])
	return sorted


# ─────────────────────────────────────────────────────────────
# DEBUG
# ─────────────────────────────────────────────────────────────

func debug_print_av() -> void:
	print("── Turn Queue ──────────────────────────────────────")
	for unit in get_units_sorted_by_av():
		print("  %-12s | SPD %-4d | AV %7.1f | refill %7.1f | progress %3.0f%%" % [
			unit.data.unit_name,
			unit.get_stat("base_spd"),
			_action_values[unit],
			_av_refill(unit),
			get_turn_progress(unit) * 100.0
		])
	print("────────────────────────────────────────────────────")
