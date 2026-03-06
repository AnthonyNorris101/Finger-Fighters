
class_name UnitData
extends Resource


@export var unit_name: String = ""
@export var unit_id: String = ""
@export var lore: String = ""
@export var element: ElementSystem.Element = ElementSystem.Element.NONE
@export var is_friend: bool = true
@export var base_hp: int = 100
@export var base_atk: int = 10
@export var base_def: int = 10
@export var base_elem_res: int = 10
@export var base_spd: int = 10
@export var base_crit_dmg: int = 0
@export var skills: Array[Resource] = []
@export var passives: Array[Resource] = []
@export var leader_passive: Array[Resource] = []
@export var current_level: int = 1
@export var current_xp: float = 0
@export var star_level: int = 0
@export var max_level: int = 100
@export var ult_cost: int = 80
@export var sprite: Texture2D
