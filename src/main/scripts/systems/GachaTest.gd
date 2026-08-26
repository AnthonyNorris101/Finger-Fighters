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
	gacha.pull_result.connect(_on_pull)

	print("\n=== BANNER: %s ===" % banner_data.banner_name)
	print("=== DOING 10 PULLS ===")
	gacha.pull_ten()

	print("\n=== PITY STATE AFTER ===")
	print("5star pity: ", gacha.get_5star_pity())
	print("4star pity: ", gacha.get_4star_pity())
	print("Guaranteed featured: ", gacha.has_guaranteed_featured())


func _on_pull(result: Dictionary) -> void:
	var stars := "★".repeat(result["rarity"])
	var unit_name: String = result["unit"].unit_name if result["unit"].unit_name != "" else "???"
	var feat := " [FEATURED]" if result["is_featured"] else ""
	print("%s  %s%s" % [stars, unit_name, feat])