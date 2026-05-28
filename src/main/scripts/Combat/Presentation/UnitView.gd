extends Node2D

const DEFAULT_ICON_PATH := "res://src/main/resources/icon.svg"

@export var base_scale: Vector2 = Vector2.ONE

var _sprite: Sprite2D
var _origin: Vector2 = Vector2.ZERO
var _is_defeated: bool = false


func _ready() -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.centered = true
		add_child(_sprite)
	_origin = position
	scale = base_scale


func setup(texture: Texture2D, spawn_position: Vector2, face_right: bool) -> void:
	_origin = spawn_position
	position = spawn_position
	_is_defeated = false
	modulate = Color.WHITE
	scale = Vector2(absf(base_scale.x), absf(base_scale.y))
	if not face_right:
		scale.x *= -1.0
	_sprite.texture = texture if texture != null else load(DEFAULT_ICON_PATH)


func has_sprite() -> bool:
	return _sprite != null


func reset_to_idle() -> void:
	position = _origin
	rotation = 0.0
	if not _is_defeated:
		modulate = Color.WHITE


func play_attack_lunge(direction: Vector2, distance: float, duration: float) -> void:
	if _is_defeated:
		return
	var tween := create_tween()
	tween.tween_property(self, "position", _origin + direction.normalized() * distance, max(0.01, duration))
	await tween.finished


func play_return(duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "position", _origin, max(0.01, duration))
	await tween.finished


func play_hit_react(direction: Vector2, distance: float, duration: float) -> void:
	if _is_defeated:
		return
	var start := position
	var offset := direction.normalized() * distance
	var tween := create_tween()
	tween.tween_property(self, "position", start + offset, max(0.01, duration * 0.5))
	tween.tween_property(self, "position", start, max(0.01, duration * 0.5))
	await tween.finished


func play_defeat() -> void:
	if _is_defeated:
		return
	_is_defeated = true
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(0.45, 0.45, 0.45, 0.4), 0.2)
	tween.tween_property(self, "rotation_degrees", 90.0, 0.2)
	await tween.finished
