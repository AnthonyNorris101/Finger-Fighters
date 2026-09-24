# GachaTest.gd
# Temporary test script — delete before shipping!
# Attach to a new Node in GachaSystem.tscn as a child of the main Node.
# Phase E step tests.
extends Node


func _ready() -> void:
	_test_e2_duplicate_shards()


func _test_e2_duplicate_shards() -> void:
	print("\n=== E2 TEST: first own + duplicate → shards ===")

	var collection := PlayerCollection.new()

	var unit := UnitData.new()
	unit.unit_id = "test_fire_03"
	unit.unit_name = "Test Fire"

	var first := PullResult.new()
	first.reward_type = PullResult.RewardType.UNIT
	first.rarity = 3
	first.unit = unit
	collection.apply_pull_result(first)

	if not collection.has_unit("test_fire_03"):
		push_error("[FAIL] E2: first pull should own unit")
		print("[FAIL] E2: first own")
		return
	if first.was_duplicate:
		push_error("[FAIL] E2: first pull should not be duplicate")
		print("[FAIL] E2: first was_duplicate")
		return
	if collection.owned_unit_ids.size() != 1:
		push_error("[FAIL] E2: expected 1 owned, got %d" % collection.owned_unit_ids.size())
		print("[FAIL] E2: roster size")
		return

	var dupe := PullResult.new()
	dupe.reward_type = PullResult.RewardType.UNIT
	dupe.rarity = 3
	dupe.unit = unit
	collection.apply_pull_result(dupe)

	if collection.owned_unit_ids.size() != 1:
		push_error("[FAIL] E2: dupe should not grow roster")
		print("[FAIL] E2: roster dupe")
		return
	if not dupe.was_duplicate:
		push_error("[FAIL] E2: dupe should set was_duplicate")
		print("[FAIL] E2: was_duplicate")
		return
	if collection.get_shards("test_fire_03") != 5:
		push_error("[FAIL] E2: expected 5 shards for 3★, got %d"
			% collection.get_shards("test_fire_03"))
		print("[FAIL] E2: shard amount")
		return
	if dupe.shard_amount != 5:
		push_error("[FAIL] E2: result.shard_amount expected 5, got %d" % dupe.shard_amount)
		print("[FAIL] E2: result shards")
		return

	# Starter path: same unit_id rules (1★ form, still shards on dupe)
	var starter := UnitData.new()
	starter.unit_id = "kael"
	starter.unit_name = "Kael"
	starter.star_level = 1

	var starter_first := PullResult.new()
	starter_first.reward_type = PullResult.RewardType.UNIT
	starter_first.rarity = 4
	starter_first.is_starter = true
	starter_first.unit = starter
	collection.apply_pull_result(starter_first)

	var starter_dupe := PullResult.new()
	starter_dupe.reward_type = PullResult.RewardType.UNIT
	starter_dupe.rarity = 4
	starter_dupe.is_starter = true
	starter_dupe.unit = starter
	collection.apply_pull_result(starter_dupe)

	if collection.get_shards("kael") != 20:
		push_error("[FAIL] E2: starter 4★ dupe expected 20 shards, got %d"
			% collection.get_shards("kael"))
		print("[FAIL] E2: starter shards")
		return
	if not starter_dupe.was_duplicate:
		push_error("[FAIL] E2: starter dupe should set was_duplicate")
		print("[FAIL] E2: starter was_duplicate")
		return

	print("[PASS] E2: first own + dupe shards (3★=5, starter 4★=20); no roster dupes")