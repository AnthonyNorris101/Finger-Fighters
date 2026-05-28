extends Node2D
# Legacy test scene: `turn_queue.tscn`. The game now boots from `battle_scene.tscn` (see Project Settings).

const BattleManagerScript := preload("res://src/main/scripts/Combat/BattleManager.gd")
const BattleHUDScene := preload("res://src/main/scenes/Combat/BattleHUD.tscn")

func _ready():
	_clear_scene_placeholders()
	var battle_manager = BattleManagerScript.new()
	add_child(battle_manager)

	var battle_hud: BattleHUD = BattleHUDScene.instantiate()
	add_child(battle_hud)
	battle_hud.bind_battle_manager(battle_manager)

	battle_manager.start_battle()


func _clear_scene_placeholders() -> void:
	for child in get_children():
		if child is Sprite2D or child.name == "UnitName":
			child.queue_free()
