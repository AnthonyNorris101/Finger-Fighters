class_name UnitHpTag
extends Control

@export var world_offset: Vector2 = Vector2(0, -56)
@export var bar_width: float = 88.0
@export var ally_fill_color: Color = Color(0.25, 0.85, 0.45, 1.0)
@export var enemy_fill_color: Color = Color(0.9, 0.3, 0.3, 1.0)

var _name_label: Label
var _hp_bar: ProgressBar
var _hp_text_label: Label
var _is_ally: bool = true


func _ready() -> void:
	custom_minimum_size = Vector2(bar_width, 40)
	_build_ui()


func _build_ui() -> void:
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(column)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	column.add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(bar_width, 14)
	_hp_bar.show_percentage = false
	_hp_bar.max_value = 100.0
	_hp_bar.value = 100.0
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.12, 0.14, 0.9)
	_hp_bar.add_theme_stylebox_override("background", bg_style)
	column.add_child(_hp_bar)

	_hp_text_label = Label.new()
	_hp_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text_label.add_theme_font_size_override("font_size", 11)
	column.add_child(_hp_text_label)


func setup(unit_name: String, is_ally: bool) -> void:
	_is_ally = is_ally
	_name_label.text = unit_name
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = ally_fill_color if is_ally else enemy_fill_color
	_hp_bar.add_theme_stylebox_override("fill", fill_style)


func update_hp(current_hp: int, max_hp: int) -> void:
	var safe_max := maxi(1, max_hp)
	_hp_bar.max_value = float(safe_max)
	_hp_bar.value = float(clamp(current_hp, 0, safe_max))
	_hp_text_label.text = "%d / %d" % [current_hp, safe_max]


func follow_world_position(world_pos: Vector2) -> void:
	var half_width := size.x * 0.5 if size.x > 0.0 else bar_width * 0.5
	global_position = world_pos + world_offset - Vector2(half_width, size.y)
