# GachaTest.gd
# Dev step tests on GachaSystem.tscn. Gate with AUTO_RUN before shipping.
extends Node

## Set false (or remove this node) before shipping builds.
const AUTO_RUN := true


func _ready() -> void:
	if not AUTO_RUN:
		print("[GachaTest] AUTO_RUN false — skipped")
		return
	_test_e2_duplicate_shards()
	_test_e3_collection_in_player_save()


func _test_e2_duplicate_shards() -> void:
	print("\n=== E2 TEST: first own + duplicate → shards ===")

	var collection = PlayerCollection
	collection.owned_unit_ids.clear()
	collection.shards_by_unit_id.clear()

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


func _test_e3_collection_in_player_save() -> void:
	print("\n=== E3 TEST: collection + shards in PlayerSave ===")

	var gacha = GachaSystem
	PlayerSave.delete_save_file()
	gacha.load_player_save()

	var collection: PlayerCollection = gacha.get_collection()
	collection.owned_unit_ids.clear()
	collection.shards_by_unit_id.clear()

	var unit := UnitData.new()
	unit.unit_id = "test_earth_03"
	unit.unit_name = "Test Earth"

	var first := PullResult.new()
	first.reward_type = PullResult.RewardType.UNIT
	first.rarity = 3
	first.unit = unit
	collection.apply_pull_result(first)

	var dupe := PullResult.new()
	dupe.reward_type = PullResult.RewardType.UNIT
	dupe.rarity = 3
	dupe.unit = unit
	collection.apply_pull_result(dupe)

	gacha._persist_pity_to_player_save()

	var disk := PlayerSave.load_or_create()
	if not disk.owned_unit_ids.has("test_earth_03"):
		push_error("[FAIL] E3: disk missing owned unit")
		print("[FAIL] E3: disk owned")
		return
	if int(disk.shards_by_unit_id.get("test_earth_03", -1)) != 5:
		push_error("[FAIL] E3: disk shards expected 5, got %s"
			% str(disk.shards_by_unit_id.get("test_earth_03", null)))
		print("[FAIL] E3: disk shards")
		return

	gacha.load_player_save()
	var reloaded: PlayerCollection = gacha.get_collection()
	if not reloaded.has_unit("test_earth_03"):
		push_error("[FAIL] E3: collection missing unit after reload")
		print("[FAIL] E3: hydrate owned")
		return
	if reloaded.get_shards("test_earth_03") != 5:
		push_error("[FAIL] E3: shards expected 5 after reload, got %d"
			% reloaded.get_shards("test_earth_03"))
		print("[FAIL] E3: hydrate shards")
		return

	PlayerSave.delete_save_file()
	print("[PASS] E3: collection + shards → one PlayerSave; survives reload")
