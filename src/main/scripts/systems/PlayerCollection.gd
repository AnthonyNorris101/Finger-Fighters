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


## E2 fills this in. Stub only for E1.
func apply_pull_result(_result: PullResult) -> void:
	pass


func debug_print() -> void:
	print("── PlayerCollection ────────────────────────────────")
	print("  Owned units: %d" % owned_unit_ids.size())
	print("  Shard keys:  %d" % shards_by_unit_id.size())
	print("────────────────────────────────────────────────────")