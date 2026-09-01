# GachaTest.gd
# Temporary test script — delete before shipping!
# Attach to a new Node in GachaSystem.tscn as a child of the main Node.
extends Node

const CHARACTER_BANNER_PATH := "res://src/main/resources/banners/example_character_banner.tres"


func _ready() -> void:
	var gacha = get_parent()  # GachaSystem is the parent node

	var banner_data := load(CHARACTER_BANNER_PATH) as BannerData
	if banner_data == null:
		push_error("[GachaTest] Failed to load BannerData at %s" % CHARACTER_BANNER_PATH)
		return

	if not banner_data.validate_basic():
		push_warning("[GachaTest] BannerData failed validate_basic() — check pool paths.")

	gacha.load_banner(banner_data.to_gacha_dictionary())

	print("\n=== BANNER: %s ===" % banner_data.banner_name)
	print("=== DOING 10 PULLS ===")
	var results: Array = gacha.pull_ten()

	print("\n=== PITY STATE AFTER ===")
	print("5star pity: ", gacha.get_5star_pity())
	print("4star pity: ", gacha.get_4star_pity())
	print("Guaranteed featured: ", gacha.has_guaranteed_featured())

	_run_step_tests(banner_data, results)
	_test_b3_empty_featured_guard(gacha, banner_data)


func _test_b3_empty_featured_guard(gacha: Node, banner_data: BannerData) -> void:
	print("\n=== B3 TEST: empty featured_5star guard ===")

	var misconfigured: Dictionary = banner_data.to_gacha_dictionary()
	misconfigured["featured_5star"] = ""
	gacha.load_banner(misconfigured)

	var failures := 0
	const TRIALS := 30
	for _trial in TRIALS:
		gacha.pity_5star = gacha.HARD_PITY - 1
		gacha.pity_4star = 0
		gacha.guaranteed_featured = false

		var result: Dictionary = gacha.pull_single()
		var unit: UnitData = result.get("unit")
		if unit == null or unit.unit_name == "???":
			failures += 1

	if failures == 0:
		print("[PASS] B3: %d forced 5★ pulls with no featured — no ??? fallbacks" % TRIALS)
	else:
		push_error("[FAIL] B3: %d / %d pulls returned ??? (empty-featured bug)" % [failures, TRIALS])

	# Restore the real banner for anything else that runs after this scene loads.
	gacha.load_banner(banner_data.to_gacha_dictionary())


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
		var result: Dictionary = results[i]
		var pull_num := i + 1

		if result.get("gear") != null:
			push_error("[GachaTest] Pull %d: gear dropped on character banner" % pull_num)
			pull_failures += 1
			continue

		var unit: UnitData = result.get("unit")
		if unit == null:
			push_error("[GachaTest] Pull %d: missing unit in result" % pull_num)
			pull_failures += 1
			continue

		if unit.unit_name == "???":
			push_error("[GachaTest] Pull %d: ??? fallback unit" % pull_num)
			pull_failures += 1
			continue

		if result.get("is_starter", false) and unit.star_level != 1:
			push_error(
				"[GachaTest] Pull %d: starter %s has star_level %d (expected 1)"
				% [pull_num, unit.unit_name, unit.star_level]
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


func _record_assert(counts: Dictionary, ok: bool, pass_msg: String, fail_msg: String) -> void:
	if ok:
		print("[PASS] %s" % pass_msg)
		counts.passed += 1
	else:
		print("[FAIL] %s" % fail_msg)
		counts.failed += 1
