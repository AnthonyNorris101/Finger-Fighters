class_name BattleHUD
extends Control
var _manager: Node

@export var log_title: String = "Battle Log"
@export var max_log_lines: int = 40
@export var log_use_timestamps: bool = false
@export var log_line_color: Color = Color(0.92, 0.95, 1.0, 1.0)

@onready var _state_label: Label = $MarginContainer/MainColumn/StateLabel
@onready var _queue_label: Label = $MarginContainer/MainColumn/QueueLabel
@onready var _hp_label: Label = $MarginContainer/MainColumn/HpLabel
@onready var _button_row: HBoxContainer = $MarginContainer/MainColumn/ButtonRow
@onready var _log_title_label: Label = $LogPanel/LogMargin/LogColumn/LogTitleLabel
@onready var _log_label: RichTextLabel = $LogPanel/LogMargin/LogColumn/LogLabel

var _log_lines: Array[String] = []


func _ready() -> void:
	_log_title_label.text = log_title
	_log_label.bbcode_enabled = true
	_log_label.clear()
	_append_log("Battle log ready.")


func bind_battle_manager(manager: Node) -> void:
	_manager = manager
	_manager.battle_state_changed.connect(_on_battle_state_changed)
	_manager.queue_preview_changed.connect(_on_queue_preview_changed)
	_manager.hp_snapshot_changed.connect(_on_hp_snapshot_changed)
	_manager.player_turn_started.connect(_on_player_turn_started)
	_manager.battle_log.connect(_on_battle_log)
	_manager.battle_ended.connect(_on_battle_ended)


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
	_append_log(message)


func _on_battle_ended(victory: bool) -> void:
	_clear_buttons()
	var result := "Victory" if victory else "Defeat"
	_on_battle_log("Result: %s" % result)


func _clear_buttons() -> void:
	for child in _button_row.get_children():
		child.queue_free()


func _append_log(message: String) -> void:
	var line := message
	if log_use_timestamps:
		line = "[%s] %s" % [Time.get_time_string_from_system(), line]

	_log_lines.append(line)
	if _log_lines.size() > max_log_lines:
		_log_lines.remove_at(0)

	_log_label.clear()
	for entry in _log_lines:
		_log_label.append_text("[color=%s]%s[/color]\n" % [log_line_color.to_html(), entry])
	_log_label.scroll_to_line(max(0, _log_lines.size() - 1))
