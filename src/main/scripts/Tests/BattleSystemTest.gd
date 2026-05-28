extends Node

const BattleManagerScript := preload("res://src/main/scripts/Combat/BattleManager.gd")
const BattleUnitScript := preload("res://src/main/scripts/Combat/BattleUnit.gd")
const TurnQueueManagerScript := preload("res://src/main/scripts/Combat/TurnSystem/TurnQueueManager.gd")
const UnitDataScript := preload("res://src/main/scripts/Combat/UnitData.gd")
const UnitViewScript := preload("res://src/main/scripts/Combat/Presentation/UnitView.gd")
const AttackChoreographyScript := preload("res://src/main/scripts/Combat/Presentation/AttackChoreography.gd")

var _failures: Array[String] = []


func _ready() -> void:
	await _run_all_tests()
	_finish()


func _run_all_tests() -> void:
	_test_turn_queue_orders_by_speed()
	_test_battle_unit_takes_damage()
	await _test_attack_choreography_impact_timing()
	await _test_battle_manager_reaches_end_state()


func _test_turn_queue_orders_by_speed() -> void:
	var queue = TurnQueueManagerScript.new()
	add_child(queue)

	var slow := _make_unit("Slow", true, 80, 100, 20)
	var fast := _make_unit("Fast", true, 120, 100, 20)
	var enemy := _make_unit("Enemy", false, 100, 100, 20)

	queue.register_unit(slow)
	queue.register_unit(fast)
	queue.register_unit(enemy)

	var actor = queue.advance_to_next_turn()
	_assert(actor == fast, "Turn queue should select fastest unit first.")
	queue.queue_free()


func _test_battle_unit_takes_damage() -> void:
	var target := _make_unit("Target", false, 100, 140, 40, ElementSystem.Element.EARTH)
	var hp_before := target.current_hp
	var dealt := target.take_damage(80, ElementSystem.Element.FIRE, 1.5)

	_assert(dealt > 0, "Damage should always be greater than zero.")
	_assert(target.current_hp < hp_before, "Target HP should decrease after taking damage.")


func _test_battle_manager_reaches_end_state() -> void:
	var manager = BattleManagerScript.new()
	add_child(manager)
	manager.debug_logging = false

	var ended := {"value": false}
	manager.battle_ended.connect(func(_victory: bool) -> void:
		ended["value"] = true
	)

	manager.start_battle()

	for i in range(60):
		if ended["value"]:
			break
		await get_tree().process_frame
		var targets: Array[BattleUnit] = manager.get("_pending_targets")
		if manager.get("_awaiting_player_input") and not targets.is_empty():
			manager.player_basic_attack(0)

	_assert(ended["value"], "Battle should end after repeated player actions.")
	manager.queue_free()


func _test_attack_choreography_impact_timing() -> void:
	var attacker = UnitViewScript.new()
	var target = UnitViewScript.new()
	add_child(attacker)
	add_child(target)
	attacker.setup(null, Vector2.ZERO, true)
	target.setup(null, Vector2(120, 0), false)

	var choreography = AttackChoreographyScript.new()
	var callback_state := {"called": false, "attacker_pos_at_impact": Vector2.ZERO}
	await choreography.play_basic_attack(attacker, target, func() -> void:
		callback_state["called"] = true
		callback_state["attacker_pos_at_impact"] = attacker.position
	)

	_assert(callback_state["called"], "Impact callback should be invoked during choreography.")
	_assert(callback_state["attacker_pos_at_impact"] != Vector2.ZERO, "Impact callback should occur after attacker lunge motion.")
	attacker.queue_free()
	target.queue_free()


func _make_unit(
		unit_name: String,
		is_friend: bool,
		spd: int,
		hp: int,
		atk: int,
		element: ElementSystem.Element = ElementSystem.Element.FIRE) -> BattleUnit:
	var data = UnitDataScript.new()
	data.unit_name = unit_name
	data.unit_id = unit_name.to_lower()
	data.is_friend = is_friend
	data.element = element
	data.base_hp = hp
	data.base_atk = atk
	data.base_def = 25
	data.base_elem_res = 10
	data.base_spd = spd
	data.base_crit_dmg = 1.35
	data.skill_bar_max = 100
	data.current_level = 1
	data.max_level = 80
	data.star_level = 1

	var unit = BattleUnitScript.new()
	unit.data = data
	unit.setup()
	add_child(unit)
	return unit


func _assert(condition: bool, message: String) -> void:
	if condition:
		print("[PASS] %s" % message)
	else:
		var failure := "[FAIL] %s" % message
		push_error(failure)
		_failures.append(failure)


func _finish() -> void:
	if _failures.is_empty():
		print("[TEST RESULT] PASS")
		get_tree().quit(0)
		return

	print("[TEST RESULT] FAIL (%d)" % _failures.size())
	for failure in _failures:
		print("  - %s" % failure)
	get_tree().quit(1)
