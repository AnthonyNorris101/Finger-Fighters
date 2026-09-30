class_name MaterialReward
extends Resource

## Stub reward for shard / evo-mats grants from duplicate unit pulls
## PlayerCollection will apply these in Phase E.

enum MaterialKind {
    SHARD,
    EVO_MAT,
}

@export var material_id: String = ""
@export var material_name: String = ""
@export var kind: MaterialKind = MaterialKind.SHARD
@export var amount: int = 0
@export var source_unit_id: String = ""
@export var rarity: int = 3

func get_display_name() -> String:
    if material_name != "":
        return material_name
    if material_id != "":
        return material_id
    return "???"

func get_short_summary() -> String:
    var label := get_display_name()
    if amount > 0:
        return "%dx %s" % [amount, label]
    return label