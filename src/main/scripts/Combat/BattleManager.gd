class_name BattleManager
extends Node

signal battle_log(message: String)
signal battle_state_changed(state: String)
signal queue_preview_changed(preview_names: Array)
signal hp_snapshot_changed(lines: Array)
signal player_turn_started(actor_name: String, target_names: Array)
signal battle_ended(victory: bool)

enum BattleState {
	INIT,
	BATTLE_START,
	TURN_START,
	ACTION_SELECT,
	ACTION_RESOLVE,
	TURN_END,
	BATTLE_END,
}

const DEFAULT_ICON_PATH := "res://src/main/resources/icon.svg"
const FALLBACK_FRIEND_NAMES: Array[String] = ["Astra", "Volt"]
const FALLBACK_ENEMY_NAMES: Array[String] = ["Mire", "Shade"]

@export var friend_roster_paths: Array[String] = []
@export var enemy_roster_paths: Array[String] = []
@export var debug_logging: bool = true

var _state: BattleState = BattleState.INIT
var _turn_queue: TurnQueueManager
var _friends: Array[BattleUnit] = []
var _enemies: Array[BattleUnit] = []
var _all_units: Array[BattleUnit] = []

var _current_actor: BattleUnit
var _pending_targets: Array[BattleUnit] = []
var _awaiting_player_input: bool = false
var _battle_over: bool = false


func start_battle() -> void:
	_initialize_queue()
	_create_battle_rosters()
	_register_units()
	_set_state(BattleState.BATTLE_START)
	_emit_hp_snapshot()
	_emit_queue_preview(_turn_queue.get_queue_preview())
	_log("Battle started.")
	_set_state(BattleState.TURN_START)
	advance_turn()


func player_basic_attack(target_index: int) -> void:
	if _battle_over or not _awaiting_player_input:
		return
	if _current_actor == null or not is_instance_valid(_current_actor):
		_awaiting_player_input = false
		advance_turn()
		return
	if target_index < 0 or target_index >= _pending_targets.size():
		_log("Invalid target selection.")
		return
	var target := _pending_targets[target_index]
	if target == null or not is_instance_valid(target) or not target.is_alive:
		_log("That target is no longer available.")
		_refresh_player_targets()
		return
	_awaiting_player_input = false
	_set_state(BattleState.ACTION_RESOLVE)
	_resolve_basic_attack(_current_actor, target)
	_finish_turn()


func advance_turn() -> void:
	if _battle_over:
		return
	if _check_battle_end():
		return
	_set_state(BattleState.TURN_START)
	var actor := _turn_queue.advance_to_next_turn()
	if actor == null:
		_log("No valid actor could be selected.")
		return
	if not is_instance_valid(actor) or not actor.can_act():
		call_deferred("advance_turn")
		return
	_current_actor = actor
	_log("Turn: %s" % _safe_unit_name(actor))
	if actor.data != null and actor.data.is_friend:
		_handle_player_turn(actor)
	else:
		_handle_enemy_turn(actor)


func _initialize_queue() -> void:
	_turn_queue = TurnQueueManager.new()
	add_child(_turn_queue)
	_turn_queue.turn_started.connect(_on_queue_turn_started)
	_turn_queue.queue_updated.connect(_emit_queue_preview)


func _create_battle_rosters() -> void:
	_friends.clear()
	_enemies.clear()
	_all_units.clear()

	var friend_data := _load_roster_data(friend_roster_paths, true, FALLBACK_FRIEND_NAMES)
	var enemy_data := _load_roster_data(enemy_roster_paths, false, FALLBACK_ENEMY_NAMES)

	for data in friend_data:
		_add_unit(data)
	for data in enemy_data:
		_add_unit(data)

	_log("Loaded roster: %d friend(s), %d enemy(ies)." % [_friends.size(), _enemies.size()])


func _load_roster_data(paths: Array[String], is_friend: bool, fallback_names: Array[String]) -> Array[UnitData]:
	var loaded: Array[UnitData] = []
	for path in paths:
		var resource := load(path)
		if resource is UnitData:
			var data: UnitData = resource.duplicate(true)
			data.is_friend = is_friend
			loaded.append(data)
		else:
			_log("Missing UnitData at %s. Using fallback unit(s)." % path)
	if loaded.is_empty():
		for i in range(fallback_names.size()):
			loaded.append(_create_fallback_unit_data(fallback_names[i], is_friend, i))
	return loaded


func _create_fallback_unit_data(unit_name: String, is_friend: bool, index: int) -> UnitData:
	var data := UnitData.new()
	data.unit_name = unit_name
	data.unit_id = "%s_%d" % [unit_name.to_lower(), index]
	data.is_friend = is_friend
	data.element = ElementSystem.Element.FIRE if is_friend else ElementSystem.Element.EARTH
	data.base_hp = 100 + index * 20
	data.base_atk = 24 + index * 4
	data.base_def = 20 + index * 3
	data.base_elem_res = 12 + index * 2
	data.base_spd = 95 + index * 8
	data.base_crit_dmg = 1.35 + float(index) * 0.05
	data.skill_bar_max = 100
	data.current_level = 1
	data.max_level = 80
	data.star_level = 1
	var texture: Texture2D = load(DEFAULT_ICON_PATH)
	data.sprite = texture
	return data


func _add_unit(data: UnitData) -> void:
	if data == null:
		return
	var unit := BattleUnit.new()
	unit.data = data
	unit.setup()
	unit.unit_died.connect(_on_unit_died.bind(unit))
	unit.hp_changed.connect(_on_hp_changed)
	add_child(unit)
	_all_units.append(unit)
	if data.is_friend:
		_friends.append(unit)
	else:
		_enemies.append(unit)


func _register_units() -> void:
	for unit in _all_units:
		_turn_queue.register_unit(unit)
	_emit_queue_preview(_turn_queue.get_queue_preview())
	if debug_logging:
		_turn_queue.debug_print_av()


func _handle_player_turn(actor: BattleUnit) -> void:
	_set_state(BattleState.ACTION_SELECT)
	_pending_targets = _get_living_units(_enemies)
	if _pending_targets.is_empty():
		_check_battle_end()
		return
	_awaiting_player_input = true
	var target_names: Array = []
	for target in _pending_targets:
		target_names.append(_safe_unit_name(target))
	player_turn_started.emit(_safe_unit_name(actor), target_names)
	_log("%s is waiting for player input." % _safe_unit_name(actor))


func _handle_enemy_turn(actor: BattleUnit) -> void:
	_set_state(BattleState.ACTION_RESOLVE)
	var targets := _get_living_units(_friends)
	if targets.is_empty():
		_check_battle_end()
		return
	var target := targets[0]
	_resolve_basic_attack(actor, target)
	_finish_turn()


func _resolve_basic_attack(attacker: BattleUnit, target: BattleUnit) -> void:
	if attacker == null or target == null:
		return
	if not attacker.is_alive or not target.is_alive:
		return
	var damage: int = int(target.call(
		"take_damage",
		int(attacker.get_stat("base_atk")),
		attacker.data.element,
		float(attacker.get_stat("base_crit_dmg"))
	))
	_log("%s attacked %s for %d damage." % [_safe_unit_name(attacker), _safe_unit_name(target), damage])
	_emit_hp_snapshot()


func _finish_turn() -> void:
	_set_state(BattleState.TURN_END)
	if _check_battle_end():
		return
	call_deferred("advance_turn")


func _check_battle_end() -> bool:
	var living_friends := _get_living_units(_friends)
	var living_enemies := _get_living_units(_enemies)
	if living_friends.is_empty():
		_end_battle(false)
		return true
	if living_enemies.is_empty():
		_end_battle(true)
		return true
	return false


func _end_battle(victory: bool) -> void:
	if _battle_over:
		return
	_battle_over = true
	_awaiting_player_input = false
	_set_state(BattleState.BATTLE_END)
	_log("Battle ended: %s" % ("Victory" if victory else "Defeat"))
	battle_ended.emit(victory)


func _refresh_player_targets() -> void:
	if not _awaiting_player_input:
		return
	_pending_targets = _get_living_units(_enemies)
	var target_names: Array = []
	for target in _pending_targets:
		target_names.append(_safe_unit_name(target))
	player_turn_started.emit(_safe_unit_name(_current_actor), target_names)


func _get_living_units(units: Array[BattleUnit]) -> Array[BattleUnit]:
	var living: Array[BattleUnit] = []
	for unit in units:
		if unit != null and is_instance_valid(unit) and unit.is_alive:
			living.append(unit)
	return living


func _on_unit_died(unit: BattleUnit) -> void:
	_log("%s was defeated." % _safe_unit_name(unit))
	_emit_hp_snapshot()
	_emit_queue_preview(_turn_queue.get_queue_preview())
	_refresh_player_targets()
	_check_battle_end()


func _on_hp_changed(_new_hp: int, _max_hp: int) -> void:
	_emit_hp_snapshot()


func _on_queue_turn_started(unit: BattleUnit) -> void:
	if debug_logging:
		_log("Queue selected: %s" % _safe_unit_name(unit))


func _emit_queue_preview(preview: Array) -> void:
	var names: Array = []
	for unit in preview:
		if unit is BattleUnit:
			names.append(_safe_unit_name(unit))
	queue_preview_changed.emit(names)


func _emit_hp_snapshot() -> void:
	var lines: Array = []
	for unit in _all_units:
		if unit == null or not is_instance_valid(unit):
			continue
		var side := "ALLY" if unit.data != null and unit.data.is_friend else "ENEMY"
		lines.append("%s %s: %d/%d" % [side, _safe_unit_name(unit), unit.current_hp, unit.max_hp])
	hp_snapshot_changed.emit(lines)


func _set_state(next_state: BattleState) -> void:
	_state = next_state
	battle_state_changed.emit(_state_name(_state))


func _state_name(value: BattleState) -> String:
	match value:
		BattleState.INIT:
			return "INIT"
		BattleState.BATTLE_START:
			return "BATTLE_START"
		BattleState.TURN_START:
			return "TURN_START"
		BattleState.ACTION_SELECT:
			return "ACTION_SELECT"
		BattleState.ACTION_RESOLVE:
			return "ACTION_RESOLVE"
		BattleState.TURN_END:
			return "TURN_END"
		BattleState.BATTLE_END:
			return "BATTLE_END"
		_:
			return "UNKNOWN"


func _safe_unit_name(unit: BattleUnit) -> String:
	if unit == null or unit.data == null or unit.data.unit_name.is_empty():
		return "Unknown"
	return unit.data.unit_name


func _log(message: String) -> void:
	if debug_logging:
		print("[Battle] %s" % message)
	battle_log.emit(message)
