# Gacha integration (for UI / collection)

Branch: `feature/gacha-system`. Do **not** edit pity math (`_determine_rarity` / `_get_5star_rate`) or hand-parse `PlayerSave` blobs.

## Autoloads

- `GachaSystem` — banners, pulls, pity, atomic save
- `CurrencyManager` — ticket balances
- `PlayerCollection` — owned units + shards

Balances, pity, and collection live in one file: `user://player_save.res` (`PlayerSave`). Pulls already spend + apply collection + save in one write — UI should not call a second saver.

## Minimal summon button

```gdscript
# Once per banner screen (BannerData .tres):
GachaSystem.load_banner(preload("res://src/main/resources/banners/example_character_banner.tres"))

func _on_single_pressed() -> void:
	var result: PullResult = GachaSystem.pull_single()
	if result == null:
		# broke — not enough tickets
		return
	_show_results([result])

func _on_ten_pressed() -> void:
	var results: Array = GachaSystem.pull_ten()
	if results.is_empty():
		return
	_show_results(results)

# Preferred signal (multi-pull friendly):
func _ready() -> void:
	GachaSystem.pull_completed.connect(_on_pull_completed)

func _on_pull_completed(results: Array) -> void:
	_show_results(results)
```

Costs (v1): character = `SUMMON_TICKETS` 1 / 10; gear = `GEAR_TICKETS` 1 / 10. Currency follows the loaded banner’s `banner_type`.

## PullResult (UI fields)

- `reward_type` — `UNIT` / `GEAR` / `MATERIAL`
- `rarity` — 3 / 4 / 5 (banner roll; starters still grant as 1★ unit)
- `unit` / `gear` — typed resource (or null)
- `is_featured` — featured 5★ hit
- `is_starter` — special summon VFX
- `was_duplicate` — dupe → shards already applied
- `shard_amount` / `source_unit_id` — set on unit dupes
- `get_display_name()` — safe label helper

Legacy: `pull_result(Dictionary)` still emits; prefer `pull_completed(Array)`.

## Pity UI (active banner track)

- `GachaSystem.get_5star_pity()` / `get_4star_pity()` / `has_guaranteed_featured()`
- Soft pity starts at 40; hard guarantee at 60
- A 10-pull can show a 5★ and only 3★s with no visible 4★. The 4★ pity is a per-pull counter; 5★ satisfies and resets it — not a bug.
- Character and gear pity are independent tracks.

## Currency

```gdscript
CurrencyManager.get_balance(CurrencyManager.Currency.SUMMON_TICKETS)
CurrencyManager.get_balance(CurrencyManager.Currency.GEAR_TICKETS)
CurrencyManager.balance_changed.connect(_on_balance_changed)
```

Spend happens inside `pull_single` / `pull_ten`. Shop/stage rewards: `CurrencyManager.add(...)`.

## Collection

```gdscript
PlayerCollection.has_unit(unit_id)
PlayerCollection.get_shards(unit_id)
PlayerCollection.owned_unit_ids  # roster ids
```

First own → roster; dupe → shards (3★=5, 4★=20, 5★=50). Applied on pull — don’t call `apply_pull_result` from UI.

## Example banners

- `res://src/main/resources/banners/example_character_banner.tres`
- `res://src/main/resources/banners/example_gear_banner.tres`

## Dev test scene

`GachaSystem.tscn` + `GachaTest.gd` auto-runs step tests. Before shipping: set `GachaTest.AUTO_RUN = false` (or remove the node). Main game scene does not load this.

## Out of scope (Anthony later)

Summon VFX (incl. starter anim), unit menu from collection, shop/stage ticket faucet, battle roster wiring.

## Future-proofing (no work now)

If competitive, trading, or online features are added, gacha RNG + pity must move server-side — local `PlayerSave` / memory is trivially editable.
