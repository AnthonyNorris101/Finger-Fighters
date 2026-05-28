extends Node

@onready var battle_manager: BattleManager = $BattleManager
@onready var battle_hud: BattleHUD = $UI/BattleHUD


func _ready() -> void:
	battle_hud.bind_battle_manager(battle_manager)
	battle_manager.start_battle()
