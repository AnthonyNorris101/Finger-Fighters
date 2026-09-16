class_name PlayerSave
extends Resource

## Unified player save. One atomic write for currency + pity + collection.
## Disk path: user://player_save.res
## CurrencyManager still writes currency_save.tres until Phase D.

const SAVE_PATH := "user://player_save.res"

# Currency stubs — Phase D migrates CurrencyManager onto these.
@export var coin_balance: int = 0
@export var summon_ticket_balance: int = 0
@export var gear_ticket_balance: int = 0

# Pity — same shape as GachaSystem.save_pity_state()["pity_by_banner_type"].
# Keys: "character" / "gear". Each track: pity_5star, pity_4star, guaranteed_featured.
@export var pity_by_banner_type: Dictionary = {}

# Collection stubs — Phase E fills these in.
@export var owned_unit_ids: Array[String] = []
@export var shards_by_unit_id: Dictionary = {}


static func load_or_create() -> PlayerSave:
	# FileAccess — ResourceLoader.exists can stay true after delete (cache).
	if not FileAccess.file_exists(SAVE_PATH):
		return PlayerSave.new()
	# CACHE_MODE_IGNORE — otherwise a second load returns the same in-memory Resource.
	var loaded = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null or not (loaded is PlayerSave):
		push_error("[PlayerSave] save file missing or invalid — using defaults.")
		return PlayerSave.new()
	return loaded as PlayerSave


func save_to_disk() -> bool:
	var err := ResourceSaver.save(self, SAVE_PATH)
	if err != OK:
		push_error("[PlayerSave] save_to_disk() failed — error code %d" % err)
		return false
	return true


static func delete_save_file() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func apply_pity_from_gacha(state: Dictionary) -> void:
	## Accepts full save_pity_state() dict OR a bare pity_by_banner_type dict.
	var tracks: Dictionary = state.get("pity_by_banner_type", state)
	pity_by_banner_type = {
		BannerData.BANNER_TYPE_CHARACTER: _normalize_pity_track(
			tracks.get(BannerData.BANNER_TYPE_CHARACTER, {})
		),
		BannerData.BANNER_TYPE_GEAR: _normalize_pity_track(
			tracks.get(BannerData.BANNER_TYPE_GEAR, {})
		),
	}


func to_gacha_pity_state() -> Dictionary:
	## Shape expected by GachaSystem.load_pity_state().
	return {
		"pity_by_banner_type": {
			BannerData.BANNER_TYPE_CHARACTER: _normalize_pity_track(
				pity_by_banner_type.get(BannerData.BANNER_TYPE_CHARACTER, {})
			),
			BannerData.BANNER_TYPE_GEAR: _normalize_pity_track(
				pity_by_banner_type.get(BannerData.BANNER_TYPE_GEAR, {})
			),
		},
	}


func _normalize_pity_track(data) -> Dictionary:
	if data is Dictionary:
		return {
			"pity_5star": int(data.get("pity_5star", 0)),
			"pity_4star": int(data.get("pity_4star", 0)),
			"guaranteed_featured": bool(data.get("guaranteed_featured", false)),
		}
	return {"pity_5star": 0, "pity_4star": 0, "guaranteed_featured": false}


func debug_print() -> void:
	print("── PlayerSave ──────────────────────────────────────")
	print("  Coins:           %d" % coin_balance)
	print("  Summon tickets:  %d" % summon_ticket_balance)
	print("  Gear tickets:    %d" % gear_ticket_balance)
	print("  Pity tracks:     %s" % str(pity_by_banner_type))
	print("  Owned units:     %d" % owned_unit_ids.size())
	print("  Shard keys:      %d" % shards_by_unit_id.size())
	print("────────────────────────────────────────────────────")
