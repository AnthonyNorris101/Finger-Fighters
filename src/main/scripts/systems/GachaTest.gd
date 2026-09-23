# GachaTest.gd
# Temporary test script — delete before shipping!
# Attach to a new Node in GachaSystem.tscn as a child of the main Node.
# Phase C tests kept below (not auto-run). Phase D will add step tests here.
extends Node


func _ready() -> void:
	_test_d3_ticket_spend()
	pass  # Re-enable / add Phase D tests when needed
	# _test_c0_player_save_round_trip()
	# _test_c1_pity_dict_shape()
	# _test_c2_hydrate_pity_from_player_save()
	# _test_c3_persist_pity_after_pull()


func _test_c0_player_save_round_trip() -> void:
	print("\n=== C0 TEST: PlayerSave load/save round-trip ===")

	PlayerSave.delete_save_file()

	var first := PlayerSave.load_or_create()
	if first.coin_balance != 0 or first.summon_ticket_balance != 0 or first.gear_ticket_balance != 0:
		push_error(
			"[FAIL] C0: fresh save should default to 0 — got coins=%d summon=%d gear=%d"
			% [first.coin_balance, first.summon_ticket_balance, first.gear_ticket_balance]
		)
		print("[FAIL] C0: fresh defaults check")
		return

	first.coin_balance = 42
	first.summon_ticket_balance = 7
	first.gear_ticket_balance = 3
	if not first.save_to_disk():
		push_error("[FAIL] C0: save_to_disk() failed")
		print("[FAIL] C0: save_to_disk() failed")
		return

	var second := PlayerSave.load_or_create()
	if second.coin_balance != 42 or second.summon_ticket_balance != 7 or second.gear_ticket_balance != 3:
		push_error(
			"[FAIL] C0: expected coins=42 summon=7 gear=3, got %d / %d / %d"
			% [second.coin_balance, second.summon_ticket_balance, second.gear_ticket_balance]
		)
		print("[FAIL] C0: persist round-trip check")
		return

	print("[C0] After save+reload:")
	second.debug_print()

	PlayerSave.delete_save_file()

	var third := PlayerSave.load_or_create()
	if third.coin_balance != 0 or third.summon_ticket_balance != 0 or third.gear_ticket_balance != 0:
		push_error(
			"[FAIL] C0: after delete, expected defaults 0/0/0 — got %d / %d / %d"
			% [third.coin_balance, third.summon_ticket_balance, third.gear_ticket_balance]
		)
		print("[FAIL] C0: delete → defaults check (ResourceLoader cache?)")
		return

	print("[PASS] C0: missing file → defaults, persist round-trip, delete → defaults")

func _test_c1_pity_dict_shape() -> void:
	print("\n=== C1 TEST: pity dict shape on PlayerSave ===")

	PlayerSave.delete_save_file()

	# Fake a GachaSystem.save_pity_state() payload (no GachaSystem wire yet).
	var fake_gacha_state := {
		"pity_by_banner_type": {
			"character": {"pity_5star": 17, "pity_4star": 4, "guaranteed_featured": true},
			"gear": {"pity_5star": 9, "pity_4star": 2, "guaranteed_featured": false},
		},
		"banner_name": "Test Banner",
	}

	var save := PlayerSave.load_or_create()
	save.apply_pity_from_gacha(fake_gacha_state)
	if not save.save_to_disk():
		push_error("[FAIL] C1: save_to_disk() failed")
		print("[FAIL] C1: save_to_disk() failed")
		return

	var loaded := PlayerSave.load_or_create()
	var character: Dictionary = loaded.pity_by_banner_type.get("character", {})
	var gear: Dictionary = loaded.pity_by_banner_type.get("gear", {})

	if character.get("pity_5star", -1) != 17 or character.get("guaranteed_featured", false) != true:
		push_error("[FAIL] C1: character track did not round-trip — %s" % str(character))
		print("[FAIL] C1: character track round-trip")
		return
	if gear.get("pity_5star", -1) != 9 or gear.get("pity_4star", -1) != 2:
		push_error("[FAIL] C1: gear track did not round-trip — %s" % str(gear))
		print("[FAIL] C1: gear track round-trip")
		return

	var for_gacha: Dictionary = loaded.to_gacha_pity_state()
	if not for_gacha.has("pity_by_banner_type"):
		push_error("[FAIL] C1: to_gacha_pity_state() missing pity_by_banner_type")
		print("[FAIL] C1: to_gacha_pity_state() shape")
		return
	if for_gacha.pity_by_banner_type.character.pity_5star != 17:
		push_error("[FAIL] C1: to_gacha_pity_state() character pity mismatch")
		print("[FAIL] C1: to_gacha_pity_state() values")
		return

	print("[C1] After pity save+reload:")
	loaded.debug_print()
	PlayerSave.delete_save_file()
	print("[PASS] C1: pity_by_banner_type apply → disk → load → to_gacha_pity_state()")


func _test_c2_hydrate_pity_from_player_save() -> void:
	print("\n=== C2 TEST: hydrate GachaSystem pity from PlayerSave ===")

	var gacha = get_parent()
	var character_banner := load("res://src/main/resources/banners/example_character_banner.tres") as BannerData
	var gear_banner := load("res://src/main/resources/banners/example_gear_banner.tres") as BannerData
	if character_banner == null or gear_banner == null:
		push_error("[FAIL] C2: could not load example banners")
		print("[FAIL] C2: banner load")
		return

	PlayerSave.delete_save_file()

	var save := PlayerSave.load_or_create()
	save.apply_pity_from_gacha({
		"pity_by_banner_type": {
			"character": {"pity_5star": 23, "pity_4star": 6, "guaranteed_featured": true},
			"gear": {"pity_5star": 11, "pity_4star": 3, "guaranteed_featured": false},
		},
	})
	if not save.save_to_disk():
		push_error("[FAIL] C2: save_to_disk() failed")
		print("[FAIL] C2: save_to_disk() failed")
		return

	# Simulate boot after a prior session wrote pity to disk.
	gacha.load_player_save()
	gacha.load_banner(character_banner)

	if gacha.get_5star_pity() != 23 or gacha.get_4star_pity() != 6 or not gacha.has_guaranteed_featured():
		push_error(
			"[FAIL] C2: character track expected 23/6/true — got %d/%d/%s"
			% [gacha.get_5star_pity(), gacha.get_4star_pity(), str(gacha.has_guaranteed_featured())]
		)
		print("[FAIL] C2: character hydrate")
		return

	gacha.load_banner(gear_banner)
	if gacha.get_5star_pity() != 11 or gacha.get_4star_pity() != 3 or gacha.has_guaranteed_featured():
		push_error(
			"[FAIL] C2: gear track expected 11/3/false — got %d/%d/%s"
			% [gacha.get_5star_pity(), gacha.get_4star_pity(), str(gacha.has_guaranteed_featured())]
		)
		print("[FAIL] C2: gear hydrate")
		return

	# Banner switch must NOT wipe the other track (in-memory per-type pity).
	gacha.load_banner(character_banner)
	if gacha.get_5star_pity() != 23 or not gacha.has_guaranteed_featured():
		push_error("[FAIL] C2: character track lost after gear banner switch")
		print("[FAIL] C2: character track after switch")
		return

	print("[C2] Hydrated pity — character 23/6/true, gear 11/3/false")
	PlayerSave.delete_save_file()
	print("[PASS] C2: PlayerSave → load_player_save → load_banner hydrates both tracks")


func _test_c3_persist_pity_after_pull() -> void:
	print("\n=== C3 TEST: persist pity after pull ===")

	var gacha = get_parent()
	var character_banner := load("res://src/main/resources/banners/example_character_banner.tres") as BannerData
	if character_banner == null:
		push_error("[FAIL] C3: could not character banners")
		print("[FAIL] C3: banner load")
		return

	PlayerSave.delete_save_file()
	gacha.load_player_save()
	gacha.load_banner(character_banner)
	gacha.debug_set_pity(5, 2, false)

	gacha.pull_ten()
	var pity_after_pull: int = gacha.get_5star_pity()

	# Simulate restart: reload save from disk and rehydrate.
	gacha.load_player_save()
	gacha.load_banner(character_banner)

	if gacha.get_5star_pity() != pity_after_pull:
		push_error(
			"[FAIL] C3: expected pity %d after restart, got %d"
			% [pity_after_pull, gacha.get_5star_pity()]
		)
		print("[FAIL] C3: pity did not survive restart")
		return

	var disk := PlayerSave.load_or_create()
	var character: Dictionary = disk.pity_by_banner_type.get("character", {})
	if int(character.get("pity_5star", -1)) != pity_after_pull:
		push_error(
			"[FAIL] C3: disk pity_5star=%s expected %d"
			% [str(character.get("pity_5star", null)), pity_after_pull]
		)
		print("[FAIL] C3: disk pity mismatch")
		return
		
	print("[C3] After pull_ten + restart: character 5★ pity=%d" % pity_after_pull)
	disk.debug_print()
	PlayerSave.delete_save_file()
	print("[PASS] C3: pull_ten persists pity; survives load_player_save restart")


func _test_d3_ticket_spend() -> void:
	print("\n=== D3 TEST: ticket spend before pull ===")

	var gacha = get_parent()
	var character_banner := load("res://src/main/resources/banners/example_character_banner.tres") as BannerData
	var gear_banner := load("res://src/main/resources/banners/example_gear_banner.tres") as BannerData
	if character_banner == null or gear_banner == null:
		push_error("[FAIL] D3: could not load example banners")
		print("[FAIL] D3: banner load")
		return

	CurrencyManager.reset_all()
	CurrencyManager.add(CurrencyManager.Currency.SUMMON_TICKETS, 3)
	CurrencyManager.add(CurrencyManager.Currency.GEAR_TICKETS, 12)
	CurrencyManager.save()

	# Character single: drains 1 SUMMON, not GEAR
	gacha.load_banner(character_banner)
	var pull = gacha.pull_single()
	if pull == null:
		push_error("[FAIL] D3: character pull_single returned null with tickets")
		print("[FAIL] D3: character affordable pull")
		return
	if CurrencyManager.get_balance(CurrencyManager.Currency.SUMMON_TICKETS) != 2:
		push_error("[FAIL] D3: expected 2 summon tickets after single, got %d"
			% CurrencyManager.get_balance(CurrencyManager.Currency.SUMMON_TICKETS))
		print("[FAIL] D3: summon drain")
		return
	if CurrencyManager.get_balance(CurrencyManager.Currency.GEAR_TICKETS) != 12:
		push_error("[FAIL] D3: gear tickets changed on character pull")
		print("[FAIL] D3: wrong currency on character")
		return

	# Broke abort: 0 summon → null, balances unchanged
	CurrencyManager.spend(CurrencyManager.Currency.SUMMON_TICKETS, 2)
	CurrencyManager.save()
	var broke = gacha.pull_single()
	if broke != null:
		push_error("[FAIL] D3: expected null when broke")
		print("[FAIL] D3: broke abort")
		return
	if CurrencyManager.get_balance(CurrencyManager.Currency.SUMMON_TICKETS) != 0:
		push_error("[FAIL] D3: broke pull mutated summon balance")
		print("[FAIL] D3: broke mutate")
		return

	# Gear ten: drains 10 GEAR, not SUMMON
	gacha.load_banner(gear_banner)
	var gear_pulls: Array = gacha.pull_ten()
	if gear_pulls.size() != 10:
		push_error("[FAIL] D3: gear pull_ten expected 10 results, got %d" % gear_pulls.size())
		print("[FAIL] D3: gear pull_ten")
		return
	if CurrencyManager.get_balance(CurrencyManager.Currency.GEAR_TICKETS) != 2:
		push_error("[FAIL] D3: expected 2 gear tickets after ten, got %d"
			% CurrencyManager.get_balance(CurrencyManager.Currency.GEAR_TICKETS))
		print("[FAIL] D3: gear drain")
		return
	if CurrencyManager.get_balance(CurrencyManager.Currency.SUMMON_TICKETS) != 0:
		push_error("[FAIL] D3: summon tickets changed on gear pull")
		print("[FAIL] D3: wrong currency on gear")
		return

	print("[PASS] D3: character spends SUMMON, gear spends GEAR, broke aborts")