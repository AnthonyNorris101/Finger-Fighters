class_name PlayerCollection
extends Node

## In-memory roster + shards. Duplicate conversion = E2. Persist = E3.
## Autoload registration = F1 — call as a normal node / class until then.

var owned_unit_ids: Array[String] = []
var shards_by_unit_id: Dictionary = {}  # unit_id -> int


func has_unit(unit_id: String) -> bool:
	return owned_unit_ids.has(unit_id)


func get_shards(unit_id: String) -> int:
	return int(shards_by_unit_id.get(unit_id, 0))


func write_into(save: PlayerSave) -> void:
	save.owned_unit_ids = owned_unit_ids.duplicate()
	save.shards_by_unit_id = shards_by_unit_id.duplicate()


func load_from_player_save(save: PlayerSave) -> void:
	owned_unit_ids.clear()
	for id in save.owned_unit_ids:
		owned_unit_ids.append(str(id))
	shards_by_unit_id.clear()
	for key in save.shards_by_unit_id:
		shards_by_unit_id[str(key)] = int(save.shards_by_unit_id[key])


const SHARDS_BY_RARITY: Dictionary = {
	3: 5,
	4: 20,
	5: 50,
}


func _shard_amount_for_rarity(rarity: int) -> int:
	return int(SHARDS_BY_RARITY.get(rarity, 5))


## First own → roster. Dupe → shards + was_duplicate (starters included).
func apply_pull_result(result: PullResult) -> void:
	if result == null:
		push_error("[PlayerCollection] apply_pull_result(): result is null")
		return
	if result.reward_type != PullResult.RewardType.UNIT:
		return
	if result.unit == null or result.unit.unit_id == "":
		push_error("[PlayerCollection] apply_pull_result(): unit missing unit_id")
		return

	var unit_id: String = result.unit.unit_id
	if has_unit(unit_id):
		var amount: int = _shard_amount_for_rarity(result.rarity)
		shards_by_unit_id[unit_id] = get_shards(unit_id) + amount
		result.was_duplicate = true
		result.shard_amount = amount
		result.source_unit_id = unit_id
	else:
		owned_unit_ids.append(unit_id)
		result.was_duplicate = false


func debug_print() -> void:
	print("── PlayerCollection ────────────────────────────────")
	print("  Owned units: %d" % owned_unit_ids.size())
	print("  Shard keys:  %d" % shards_by_unit_id.size())
	print("────────────────────────────────────────────────────")
