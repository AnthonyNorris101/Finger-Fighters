# GachaSimTest.gd
# Seeded rate sim — G1. Attach under GachaSystem.tscn. Does not spend or save.
extends Node

const AUTO_RUN := true
const SIM_SEED := 42
const PULL_COUNT := 10000


func _ready() -> void:
	if not AUTO_RUN:
		print("[GachaSimTest] AUTO_RUN false — skipped")
		return
	_run_g1()


func _run_g1() -> void:
	print("\n=== G1 SIM: %d pulls, seed=%d ===" % [PULL_COUNT, SIM_SEED])

	var banner = load("res://src/main/resources/banners/example_character_banner.tres")
	if banner == null:
		push_error("[FAIL] G1: could not load example_character_banner.tres")
		print("[FAIL] G1: banner load")
		return

	GachaSystem.load_banner(banner)
	GachaSystem.log_pulls = false

	var first: Dictionary = _sim_once()
	var second: Dictionary = _sim_once()

	GachaSystem.log_pulls = true

	if first.is_empty() or second.is_empty():
		return

	if first["counts"][3] != second["counts"][3] \
			or first["counts"][4] != second["counts"][4] \
			or first["counts"][5] != second["counts"][5]:
		push_error("[FAIL] G1: same seed produced different rarity counts")
		print("[FAIL] G1: seed not reproducible")
		return

	var c3: int = first["counts"][3]
	var c4: int = first["counts"][4]
	var c5: int = first["counts"][5]
	var total: int = c3 + c4 + c5
	if total != PULL_COUNT:
		push_error("[FAIL] G1: counts sum %d != %d" % [total, PULL_COUNT])
		print("[FAIL] G1: count sum")
		return

	if first["max_gap_5"] > GachaSystem.HARD_PITY:
		push_error("[FAIL] G1: 5★ gap %d exceeded hard pity %d"
			% [first["max_gap_5"], GachaSystem.HARD_PITY])
		print("[FAIL] G1: hard pity")
		return

	var rate5: float = float(c5) / float(PULL_COUNT)
	# Soft/hard pity lifts effective 5★ above base 2%; band is a sanity check.
	if rate5 < 0.015 or rate5 > 0.08:
		push_error("[FAIL] G1: 5★ rate %.3f outside 1.5%%–8%%" % rate5)
		print("[FAIL] G1: 5★ rate")
		return

	print("  3★=%d (%.2f%%)  4★=%d (%.2f%%)  5★=%d (%.2f%%)"
		% [c3, 100.0 * c3 / PULL_COUNT, c4, 100.0 * c4 / PULL_COUNT,
			c5, 100.0 * rate5])
	print("  max pulls between 5★: %d (hard=%d)" % [first["max_gap_5"], GachaSystem.HARD_PITY])
	print("  featured among 5★: %d / %d" % [first["featured_5"], c5])
	print("[PASS] G1: seeded 10k reproducible; hard pity held; 5★ rate in band")


func _sim_once() -> Dictionary:
	seed(SIM_SEED)
	GachaSystem.load_pity_state({})

	var counts := {3: 0, 4: 0, 5: 0}
	var featured_5: int = 0
	var since_5: int = 0
	var max_gap_5: int = 0

	for i in PULL_COUNT:
		var pull: PullResult = GachaSystem._resolve_pull_result()
		if pull == null:
			push_error("[FAIL] G1: null pull at %d" % i)
			print("[FAIL] G1: null pull")
			return {}
		var r: int = pull.rarity
		if not counts.has(r):
			push_error("[FAIL] G1: bad rarity %d" % r)
			print("[FAIL] G1: rarity")
			return {}
		counts[r] += 1
		since_5 += 1
		if r == 5:
			if since_5 > max_gap_5:
				max_gap_5 = since_5
			since_5 = 0
			if pull.is_featured:
				featured_5 += 1

	if since_5 > max_gap_5:
		max_gap_5 = since_5

	return {
		"counts": counts,
		"featured_5": featured_5,
		"max_gap_5": max_gap_5,
	}
