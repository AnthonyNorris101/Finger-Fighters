# GachaTest.gd
# Temporary test script — delete before shipping!
# Attach to a new Node in GachaSystem.tscn as a child of the main Node.
extends Node

func _ready() -> void:
	var gacha = get_parent()  # GachaSystem is the parent node

	var test_banner := {
		"name": "Stormborn Banner — Kael",
		"featured_5star": "res://src/main/resources/units/kael.tres",
		"standard_5star_pool": [
			"res://src/main/resources/units/kira.tres",
			"res://src/main/resources/units/sela.tres",
			"res://src/main/resources/units/bren.tres",
		],
		"4star_pool": [
			"res://src/main/resources/units/lys.tres",
		],
		"3star_pool": [
			"res://src/main/resources/units/vael.tres",
		]
	}

	gacha.load_banner(test_banner)
	gacha.pull_result.connect(_on_pull)

	print("\n=== DOING 10 PULLS ===")
	gacha.pull_ten()

	print("\n=== PITY STATE AFTER ===")
	print("5star pity: ", gacha.get_5star_pity())
	print("4star pity: ", gacha.get_4star_pity())
	print("Guaranteed featured: ", gacha.has_guaranteed_featured())


func _on_pull(result: Dictionary) -> void:
	var stars := "★".repeat(result["rarity"])
	var unit_name : String = result["unit"].unit_name if result["unit"].unit_name != "" else "???"
	var feat  := " [FEATURED]" if result["is_featured"] else ""
	print("%s  %s%s" % [stars, unit_name, feat])
