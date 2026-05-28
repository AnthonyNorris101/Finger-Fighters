class_name BattleHUD
extends Control

const UnitHpTagScript := preload("res://src/main/scripts/Combat/Presentation/UnitHpTag.gd")

@export var log_title: String = "Battle Log"
@export var max_log_lines: int = 40
@export var log_use_timestamps: bool = false
@export var log_line_color: Color = Color(0.92, 0.95, 1.0, 1.0)

@export var player_phase_text: String = "Your Turn"
@export var enemy_phase_text: String = "Enemy Turn"
@export var phase_popup_hold_seconds: float = 0.9
@export var phase_popup_fade_seconds: float = 0.25

@onready var _queue_label: Label = $TopCenterPanel/QueueLabel
@onready var _action_title_label: Label = $TopCenterPanel/ActionTitleLabel
@onready var _phase_popup: PanelContainer = $PhasePopup
@onready var _phase_popup_label: Label = $PhasePopup/PhasePopupLabel
@onready var _button_row: HBoxContainer = $ActionButtonsPanel/ButtonRow
@onready var _hp_tag_container: Control = $WorldHpLayer/HpTagContainer
@onready var _log_title_label: Label = $LogPanel/LogMargin/LogColumn/LogTitleLabel
@onready var _log_label: RichTextLabel = $LogPanel/LogMargin/LogColumn/LogLabel

var _manager: BattleManager
var _log_lines: Array[String] = []
var _hp_tags: Dictionary = {}
var _hp_unit_views: Dictionary = {}
var _phase_popup_tween: Tween


func _ready() -> void:
	_log_title_label.text = log_title
	_log_label.bbcode_enabled = true
	_log_label.clear()
	_append_log("Battle log ready.")
	_phase_popup.visible = false


func _process(_delta: float) -> void:
	_sync_hp_tag_positions()


func bind_battle_manager(manager: Node) -> void:
	if manager == null or not manager is BattleManager:
		push_warning("BattleHUD.bind_battle_manager expected BattleManager.")
		return
	_manager = manager
	_manager.queue_preview_changed.connect(_on_queue_preview_changed)
	_manager.unit_hp_changed.connect(_on_unit_hp_changed)
	_manager.player_turn_started.connect(_on_player_turn_started)
	_manager.turn_phase_changed.connect(_on_turn_phase_changed)
	_manager.battle_log.connect(_on_battle_log)
	_manager.battle_ended.connect(_on_battle_ended)
	_manager.unit_views_ready.connect(_on_unit_views_ready)


func _on_unit_views_ready() -> void:
	_setup_hp_tags()


func _setup_hp_tags() -> void:
	_clear_hp_tags()
	if _manager == null:
		return
	for unit in _manager.get_all_battle_units():
		if unit == null or not is_instance_valid(unit):
			continue
		var view: Node2D = _manager.get_unit_view(unit)
		if view == null:
			continue
		var tag = UnitHpTagScript.new()
		_hp_tag_container.add_child(tag)
		var unit_name := "Unknown"
		var is_ally := true
		if unit.data != null:
			unit_name = unit.data.unit_name if not unit.data.unit_name.is_empty() else unit_name
			is_ally = unit.data.is_friend
		tag.setup(unit_name, is_ally)
		tag.update_hp(unit.current_hp, unit.max_hp)
		_hp_tags[unit] = tag
		_hp_unit_views[unit] = view
		tag.follow_world_position(view.global_position)


func _sync_hp_tag_positions() -> void:
	for unit in _hp_tags:
		var tag = _hp_tags[unit]
		var view: Node2D = _hp_unit_views.get(unit, null) as Node2D
		if tag == null or not is_instance_valid(tag):
			continue
		if view == null or not is_instance_valid(view):
			continue
		tag.follow_world_position(view.global_position)


func _on_queue_preview_changed(names: Array) -> void:
	if names.is_empty():
		_queue_label.text = "Turn Queue: -"
		return
	_queue_label.text = "Turn Queue: %s" % " → ".join(names)


func _on_unit_hp_changed(unit: BattleUnit, current_hp: int, max_hp: int) -> void:
	var tag = _hp_tags.get(unit, null)
	if tag == null:
		return
	tag.update_hp(current_hp, max_hp)
	if current_hp <= 0:
		tag.modulate = Color(0.55, 0.55, 0.55, 0.65)


func _on_player_turn_started(actor_name: String, target_names: Array) -> void:
	_action_title_label.text = "%s — choose a target" % actor_name
	_clear_buttons()
	for i in range(target_names.size()):
		var button := Button.new()
		button.text = "Attack %s" % target_names[i]
		button.pressed.connect(_on_attack_button_pressed.bind(i))
		_button_row.add_child(button)
	_on_battle_log("%s: choose a target." % actor_name)


func _on_turn_phase_changed(phase: String) -> void:
	if phase == "PLAYER":
		_action_title_label.text = "Player Turn"
	elif phase == "ENEMY":
		_action_title_label.text = "Enemy Turn"
		_clear_buttons()
	_show_phase_popup(phase)


func _show_phase_popup(phase: String) -> void:
	var text := player_phase_text if phase == "PLAYER" else enemy_phase_text
	if phase != "PLAYER" and phase != "ENEMY":
		return
	_phase_popup_label.text = text
	_phase_popup.visible = true
	_phase_popup.scale = Vector2(0.85, 0.85)
	_phase_popup.modulate = Color(1, 1, 1, 0)

	if _phase_popup_tween != null and _phase_popup_tween.is_valid():
		_phase_popup_tween.kill()
	_phase_popup_tween = create_tween()
	_phase_popup_tween.set_parallel(true)
	_phase_popup_tween.tween_property(_phase_popup, "modulate:a", 1.0, phase_popup_fade_seconds)
	_phase_popup_tween.tween_property(_phase_popup, "scale", Vector2.ONE, phase_popup_fade_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_phase_popup_tween.chain().tween_interval(phase_popup_hold_seconds)
	_phase_popup_tween.chain().tween_property(_phase_popup, "modulate:a", 0.0, phase_popup_fade_seconds)
	_phase_popup_tween.chain().tween_callback(func() -> void:
		_phase_popup.visible = false
	)


func _on_attack_button_pressed(target_index: int) -> void:
	if _manager == null:
		return
	_manager.player_basic_attack(target_index)
	_clear_buttons()


func _on_battle_log(message: String) -> void:
	_append_log(message)


func _on_battle_ended(victory: bool) -> void:
	_clear_buttons()
	_action_title_label.text = "Victory" if victory else "Defeat"
	var result := "Victory" if victory else "Defeat"
	_on_battle_log("Result: %s" % result)


func _clear_buttons() -> void:
	for child in _button_row.get_children():
		child.queue_free()


func _clear_hp_tags() -> void:
	for unit in _hp_tags:
		var tag = _hp_tags[unit]
		if tag != null and is_instance_valid(tag):
			tag.queue_free()
	_hp_tags.clear()
	_hp_unit_views.clear()


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
	_log_label.scroll_to_line(maxi(0, _log_lines.size() - 1))
