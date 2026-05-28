class_name BattleHUD
extends Control
var _manager: Node

var _state_label: Label
var _queue_label: Label
var _hp_label: Label
var _log_label: RichTextLabel
var _button_row: HBoxContainer


func _ready() -> void:
	_build_ui()


func bind_battle_manager(manager: Node) -> void:
	_manager = manager
	_manager.battle_state_changed.connect(_on_battle_state_changed)
	_manager.queue_preview_changed.connect(_on_queue_preview_changed)
	_manager.hp_snapshot_changed.connect(_on_hp_snapshot_changed)
	_manager.player_turn_started.connect(_on_player_turn_started)
	_manager.battle_log.connect(_on_battle_log)
	_manager.battle_ended.connect(_on_battle_ended)


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(column)

	_state_label = Label.new()
	_state_label.text = "State: INIT"
	column.add_child(_state_label)

	_queue_label = Label.new()
	_queue_label.text = "Queue: -"
	column.add_child(_queue_label)

	_hp_label = Label.new()
	_hp_label.text = "HP Snapshot: -"
	column.add_child(_hp_label)

	var action_title := Label.new()
	action_title.text = "Player Action"
	column.add_child(action_title)

	_button_row = HBoxContainer.new()
	column.add_child(_button_row)

	_log_label = RichTextLabel.new()
	_log_label.fit_content = true
	_log_label.scroll_active = true
	_log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_label.text = "Battle log ready."
	column.add_child(_log_label)


func _on_battle_state_changed(state: String) -> void:
	_state_label.text = "State: %s" % state


func _on_queue_preview_changed(names: Array) -> void:
	_queue_label.text = "Queue: %s" % ", ".join(names) if not names.is_empty() else "Queue: -"


func _on_hp_snapshot_changed(lines: Array) -> void:
	_hp_label.text = "HP Snapshot:\n%s" % "\n".join(lines)


func _on_player_turn_started(actor_name: String, target_names: Array) -> void:
	_clear_buttons()
	for i in range(target_names.size()):
		var button := Button.new()
		button.text = "Attack %s" % target_names[i]
		button.pressed.connect(_on_attack_button_pressed.bind(i))
		_button_row.add_child(button)
	_on_battle_log("%s: choose a target." % actor_name)


func _on_attack_button_pressed(target_index: int) -> void:
	if _manager == null:
		return
	_manager.player_basic_attack(target_index)
	_clear_buttons()


func _on_battle_log(message: String) -> void:
	_log_label.text += "\n%s" % message


func _on_battle_ended(victory: bool) -> void:
	_clear_buttons()
	var result := "Victory" if victory else "Defeat"
	_on_battle_log("Result: %s" % result)


func _clear_buttons() -> void:
	for child in _button_row.get_children():
		child.queue_free()
