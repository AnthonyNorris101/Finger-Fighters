class_name UnitData
extends Resource


@export var unit_name: String
@export var unit_id: String
@export var lore: String
@export var element: ElementSystem.Element
@export var is_friend: bool
@export var base_hp: int
@export var base_atk: int
@export var base_def: int
@export var base_elem_res: int
@export var base_spd: int
@export var base_crit_dmg: float
@export var skills: Array[Resource]
@export var passives: Array[Resource]
@export var leader_passive: Array[Resource]
@export var current_level: int
@export var current_xp: float
@export var star_level: int
@export var max_level: int
@export var skill_bar_max: int
@export var sprite: Texture2D
