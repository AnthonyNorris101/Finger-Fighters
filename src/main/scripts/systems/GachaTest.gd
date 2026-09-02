# GachaTest.gd
# Temporary test script — delete before shipping!
# Attach to a new Node in GachaSystem.tscn as a child of the main Node.
extends Node

const CHARACTER_BANNER_PATH := "res://src/main/resources/banners/example_character_banner.tres"
const GEAR_BANNER_PATH := "res://src/main/resources/banners/example_gear_banner.tres"

const B8_RESOURCE_PATHS: Array[String] = [
	"res://src/main/resources/units/unit_03_fire.tres",
	"res://src/main/resources/units/unit_03_earth.tres",
	"res://src/main/resources/units/unit_03_electric.tres",
	"res://src/main/resources/units/unit_03_water.tres",
	"res://src/main/resources/units/unit_03_light.tres",
	"res://src/main/resources/units/unit_03_dark.tres",
	"res://src/main/resources/gear/gear_03_ring.tres",
	"res://src/main/resources/gear/gear_03_bracelet.tres",
	"res://src/main/resources/gear/gear_04_necklace.tres",
	"res://src/main/resources/gear/gear_04_belt.tres",
	"res://src/main/resources/gear/gear_05_crown.tres",
	"res://src/main/resources/gear/gear_05_scepter.tres",
]


func _ready() -> void:
	await _wait_for_resources(B8_RESOURCE_PATHS)

	var gacha = get_parent()  # GachaSystem is the parent node

	var banner_data := load(CHARACTER_BANNER_PATH) as BannerData
	if banner_data == null:
		push_error("[GachaTest] Failed to load BannerData at %s" % CHARACTER_BANNER_PATH)
		return

	if not banner_data.validate_basic():
		push_warning("[GachaTest] BannerData failed validate_basic() — check pool paths.")

	gacha.load_banner(banner_data)

	print("\n=== BANNER: %s ===" % banner_data.banner_name)
	print("=== DOING 10 PULLS ===")
	var results: Array = gacha.pull_ten()

	print("\n=== PITY STATE AFTER ===")
	print("5star pity: ", gacha.get_5star_pity())
	print("4star pity: ", gacha.get_4star_pity())
	print("Guaranteed featured: ", gacha.has_guaranteed_featured())

	_run_step_tests(banner_data, results)
	_test_b3_empty_featured_guard(gacha, banner_data)
	_test_b4_independent_pity_tracks(gacha, banner_data)
	_test_b5_load_banner_and_rates(gacha, banner_data)
	_test_b6_pull_result_and_signal(gacha, banner_data)
	_test_b7_banner_validation(banner_data)
	_test_b8_banner_data(gacha)


func _wait_for_resources(paths: Array[String], max_frames: int = 15) -> void:
	var missing: Array[String] = []
	for _attempt in max_frames:
		missing.clear()
		for path in paths:
			if not ResourceLoader.exists(path):
				missing.append(path)
		if missing.is_empty():
			return
		await get_tree().process_frame

	push_warning(
		"[GachaTest] Resources still missing after %d frames (%d paths) — reimport may be in progress."
		% [max_frames, missing.size()]
	)


func _allowed_gear_names(banner: BannerData) -> Dictionary:
	var names: Dictionary = {}
	var pools: Array = [
		banner.gear_3star_pool,
		banner.gear_4star_pool,
		banner.gear_5star_pool,
	]
	for pool in pools:
		for path in pool:
			var gear: GearData = load(path) as GearData
			if gear:
				names[gear.get_display_name()] = true

	if not banner.featured_5star.is_empty():
		var featured: GearData = load(banner.featured_5star) as GearData
		if featured:
			names[featured.get_display_name()] = true

	return names


func _test_b3_empty_featured_guard(gacha: Node, banner_data: BannerData) -> void:
	print("\n=== B3 TEST: empty featured_5star guard ===")

	var misconfigured: Dictionary = banner_data.to_gacha_dictionary()
	misconfigured["featured_5star"] = ""
	gacha.load_banner(misconfigured)

	var failures := 0
	const TRIALS := 30
	for _trial in TRIALS:
		gacha.debug_set_pity(gacha.HARD_PITY - 1, 0, false)

		var pull: PullResult = gacha.pull_single()
		if pull.unit == null or pull.get_display_name() == "???":
			failures += 1

	if failures == 0:
		print("[PASS] B3: %d forced 5★ pulls with no featured — no ??? fallbacks" % TRIALS)
	else:
		push_error("[FAIL] B3: %d / %d pulls returned ??? (empty-featured bug)" % [failures, TRIALS])

	gacha.load_banner(banner_data)


func _test_b4_independent_pity_tracks(gacha: Node, character_banner: BannerData) -> void:
	print("\n=== B4 TEST: independent pity tracks ===")

	var gear_banner := load(GEAR_BANNER_PATH) as BannerData
	if gear_banner == null:
		push_error("[GachaTest] Failed to load gear banner at %s" % GEAR_BANNER_PATH)
		return

	gacha.load_pity_state({})

	gacha.load_banner(character_banner)
	gacha.pull_ten()
	var character_pity: int = gacha.get_5star_pity()

	gacha.load_banner(gear_banner)
	if gacha.get_5star_pity() != 0:
		push_error("[FAIL] B4: gear track should start at 0 after banner switch")
		return

	gacha.pull_ten()
	var gear_pity: int = gacha.get_5star_pity()

	gacha.load_banner(character_banner)
	var character_pity_restored: int = gacha.get_5star_pity()

	if character_pity == 10 and gear_pity == 10 and character_pity_restored == 10:
		print("[PASS] B4: character pity stayed %d after %d gear pulls" % [character_pity_restored, gear_pity])
	else:
		push_error(
			"[FAIL] B4: expected character=10/10, gear=10 — got character=%d/%d, gear=%d"
			% [character_pity, character_pity_restored, gear_pity]
		)

	gacha.load_banner(character_banner)


func _test_b5_load_banner_and_rates(gacha: Node, character_banner: BannerData) -> void:
	print("\n=== B5 TEST: load_banner BannerData + rate overrides ===")

	gacha.load_pity_state({})
	gacha.load_banner(character_banner)

	if gacha.current_banner.get("banner_id", "") != character_banner.banner_id:
		push_error("[FAIL] B5: BannerData load did not populate current_banner")
		return

	var dict_banner: Dictionary = character_banner.to_gacha_dictionary()
	dict_banner.hard_pity = 3
	gacha.load_banner(dict_banner)
	gacha.debug_set_pity(2, 0, false)

	var pull: PullResult = gacha.pull_single()
	if pull.rarity == 5:
		print("[PASS] B5: BannerData + Dictionary load; hard_pity=3 override triggers 5★ at pity 3")
	else:
		push_error("[FAIL] B5: expected hard_pity=3 to force 5★, got rarity %d" % pull.rarity)

	gacha.load_banner(character_banner)


func _test_b6_pull_result_and_signal(gacha: Node, character_banner: BannerData) -> void:
	print("\n=== B6 TEST: PullResult + pull_completed ===")

	gacha.load_pity_state({})
	gacha.load_banner(character_banner)

	var signal_holder: Array = []
	gacha.pull_completed.connect(func(results: Array) -> void:
		signal_holder.clear()
		signal_holder.append_array(results)
	)

	var pulls: Array = gacha.pull_ten()
	if pulls.size() != 10:
		push_error("[FAIL] B6: pull_ten returned %d results (expected 10)" % pulls.size())
		return

	if signal_holder.size() != 10:
		push_error("[FAIL] B6: pull_completed emitted %d results (expected 10)" % signal_holder.size())
		return

	for i in pulls.size():
		var pull: PullResult = pulls[i]
		if pull.reward_type != PullResult.RewardType.UNIT:
			push_error("[FAIL] B6: character pull %d is not UNIT" % (i + 1))
			return
		if pull.get_display_name() == "???":
			push_error("[FAIL] B6: character pull %d is ???" % (i + 1))
			return
		if pull.get_reward_type_string() == "":
			push_error("[FAIL] B6: pull %d missing reward type string" % (i + 1))
			return

	var gear_banner := load(GEAR_BANNER_PATH) as BannerData
	if gear_banner == null:
		push_error("[GachaTest] Failed to load gear banner for B6")
		return

	gacha.load_banner(gear_banner)
	var gear_pull: PullResult = gacha.pull_single()
	if gear_pull.reward_type != PullResult.RewardType.GEAR or gear_pull.gear == null:
		push_error("[FAIL] B6: gear banner pull did not return GEAR PullResult")
		return

	var legacy: Dictionary = gear_pull.to_legacy_dictionary()
	if not legacy.has("gear") or legacy["gear"] == null:
		push_error("[FAIL] B6: to_legacy_dictionary() missing gear")
		return

	print("[PASS] B6: PullResult on pull_ten/single, pull_completed signal, gear + legacy bridge")

	gacha.load_banner(character_banner)


func _run_step_tests(banner_data: BannerData, results: Array) -> void:
	var counts := {"passed": 0, "failed": 0}

	print("\n=== STEP TESTS ===")

	_record_assert(
		counts,
		not banner_data.to_gacha_dictionary().has("unit_4star_rate"),
		"B2: banner dict has no unit_4star_rate",
		"B2: unit_4star_rate still present in to_gacha_dictionary()"
	)

	_record_assert(
		counts,
		banner_data.gear_3star_pool.is_empty() and banner_data.gear_4star_pool.is_empty(),
		"B2: character .tres has no gear_3star_pool / gear_4star_pool entries",
		"B2: character banner still has low-tier gear pools in .tres"
	)

	var pull_failures := 0
	for i in results.size():
		var pull: PullResult = results[i]
		var pull_num := i + 1

		if pull.reward_type == PullResult.RewardType.GEAR:
			push_error("[GachaTest] Pull %d: gear dropped on character banner" % pull_num)
			pull_failures += 1
			continue

		if pull.unit == null:
			push_error("[GachaTest] Pull %d: missing unit in PullResult" % pull_num)
			pull_failures += 1
			continue

		if pull.get_display_name() == "???":
			push_error("[GachaTest] Pull %d: ??? fallback unit" % pull_num)
			pull_failures += 1
			continue

		if pull.is_starter and pull.unit.star_level != 1:
			push_error(
				"[GachaTest] Pull %d: starter %s has star_level %d (expected 1)"
				% [pull_num, pull.unit.unit_name, pull.unit.star_level]
			)
			pull_failures += 1

	if pull_failures == 0:
		print("[PASS] B1: %d pulls — units only, no ???, starters at 1★" % results.size())
		counts.passed += 1
	else:
		print("[FAIL] B1: %d pull(s) failed checks (see errors above)" % pull_failures)
		counts.failed += 1

	print("=== %d passed, %d failed ===" % [counts.passed, counts.failed])
	if counts.failed > 0:
		push_error("[GachaTest] Step tests failed — fix before checking off the step.")


func _test_b7_banner_validation(character_banner: BannerData) -> void:
	print("\n=== B7 TEST: BannerData validation ===")

	if not character_banner.validate_basic():
		push_error("[FAIL] B7: example character banner should pass validate_basic()")
		return

	# Character banner must reject any gear pool tier.
	var bad_character := character_banner.duplicate() as BannerData
	bad_character.gear_3star_pool = ["res://src/main/resources/gear/gear_03_ring.tres"]
	if bad_character.validate_basic():
		push_error("[FAIL] B7: character banner with gear_3star_pool should fail validation")
		return

	# Gear banner must require featured_5star.
	var bad_gear := BannerData.new()
	bad_gear.banner_id = "test_gear_invalid"
	bad_gear.banner_name = "Test Gear Invalid"
	bad_gear.banner_type = BannerData.BannerType.GEAR
	bad_gear.gear_3star_pool = ["res://src/main/resources/gear/gear_03_ring.tres"]
	bad_gear.gear_4star_pool = ["res://src/main/resources/gear/gear_04_necklace.tres"]
	bad_gear.gear_5star_pool = ["res://src/main/resources/gear/gear_05_crown.tres"]
	if bad_gear.validate_basic():
		push_error("[FAIL] B7: gear banner without featured_5star should fail validation")
		return

	# Featured must not also sit in gear_5star_pool (50/50 chase bug).
	var bad_featured_dup := bad_gear.duplicate() as BannerData
	bad_featured_dup.featured_5star = "res://src/main/resources/gear/gear_05_crown.tres"
	if bad_featured_dup.validate_basic():
		push_error("[FAIL] B7: gear banner with featured in gear_5star_pool should fail validation")
		return

	print("[PASS] B7: character/gear validation rules enforced")


func _test_b8_banner_data(gacha: Node) -> void:
	print("\n=== B8 TEST: banner data pools ===")

	var character_banner := load(CHARACTER_BANNER_PATH) as BannerData
	var gear_banner := load(GEAR_BANNER_PATH) as BannerData
	if character_banner == null or gear_banner == null:
		push_error("[FAIL] B8: failed to load example banners")
		return

	if character_banner.unit_3star_pool.size() != 6:
		push_error(
			"[FAIL] B8: character unit_3star_pool has %d entries (expected 6)"
			% character_banner.unit_3star_pool.size()
		)
		return

	if not gear_banner.validate_basic():
		push_error("[FAIL] B8: example gear banner should pass validate_basic()")
		return

	if gear_banner.featured_5star in gear_banner.gear_5star_pool:
		push_error("[FAIL] B8: featured_5star must not be in gear_5star_pool")
		return

	if gear_banner.gear_3star_pool.size() < 2 or gear_banner.gear_4star_pool.size() < 2:
		push_error("[FAIL] B8: gear banner needs 2+ entries in 3★ and 4★ pools")
		return

	gacha.load_pity_state({})
	gacha.load_banner(gear_banner)

	var allowed_gear := _allowed_gear_names(gear_banner)
	if allowed_gear.size() != 6:
		push_error("[FAIL] B8: expected 6 gear names in pools, got %d" % allowed_gear.size())
		return

	print("=== B8: gear banner 10-pull ===")
	var pulls: Array = gacha.pull_ten()
	var seen_gear: Dictionary = {}

	for i in pulls.size():
		var pull: PullResult = pulls[i]
		if pull.reward_type != PullResult.RewardType.GEAR or pull.gear == null:
			push_error("[FAIL] B8: gear 10-pull slot %d was not GEAR" % (i + 1))
			return

		var label: String = pull.get_display_name()
		if not allowed_gear.has(label):
			push_error("[FAIL] B8: unknown gear '%s' — not in banner pools" % label)
			return

		seen_gear[label] = true

	print("[B8] Gear 10-pull pulled: %s" % ", ".join(seen_gear.keys()))
	print("[PASS] B8: 6 element 3★ pool, gear validates, 10-pull all from pool (%d unique)" % seen_gear.size())


func _record_assert(counts: Dictionary, ok: bool, pass_msg: String, fail_msg: String) -> void:
	if ok:
		print("[PASS] %s" % pass_msg)
		counts.passed += 1
	else:
		print("[FAIL] %s" % fail_msg)
		counts.failed += 1
