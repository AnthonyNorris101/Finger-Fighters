# CurrencyManager.gd
# ─────────────────────────────────────────────────────────────
# Autoload singleton — Project > Project Settings > Autoload
# Name: "CurrencyManager"
#
# Single source of truth for Coins and Summon Tickets.
# Nothing else should mutate these values directly.
# Materials and stackable items are handled by InventoryManager.
#
# CURRENCIES (from rpg_design_doc_v2):
#   COINS          — Soft grind currency. Earned through normal play.
#   SUMMON_TICKETS — Gacha stub. Full summon design TBD.
#
# SAVE / LOAD:
#   Balances are persisted to user://currency_save.tres via
#   CurrencyRecord (a typed Resource). Call save() after any
#   transaction you want to persist between sessions.
#   load_save() is called automatically in _ready().
# ─────────────────────────────────────────────────────────────
extends Node


# ─────────────────────────────────────────────────────────────
# ENUM
# ─────────────────────────────────────────────────────────────

enum Currency {
	COINS,
	SUMMON_TICKETS,
}


# ─────────────────────────────────────────────────────────────
# SIGNALS
#
# delta is positive for gains, negative for spends.
# UI reward popups should read delta to display "+250 Coins"
# without doing their own subtraction.
# ─────────────────────────────────────────────────────────────

signal balance_changed(currency: Currency, new_amount: int, delta: int)


# ─────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────

const SAVE_PATH: String = "user://currency_save.tres"

# Absolute cap per Currency — prevents overflow from runaway reward
# loops. Values are intentionally generous placeholders; tune during
# economy balancing.
const CURRENCY_CAP: Dictionary = {
	Currency.COINS:          999_999_999,
	Currency.SUMMON_TICKETS: 9_999,
}


# ─────────────────────────────────────────────────────────────
# INTERNAL STATE
# ─────────────────────────────────────────────────────────────

var _balances: Dictionary = {
	Currency.COINS:          0,
	Currency.SUMMON_TICKETS: 0,
}


# ─────────────────────────────────────────────────────────────
# LIFECYCLE
# ─────────────────────────────────────────────────────────────

func _ready() -> void:
	load_save()


# ─────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────

func get_balance(currency: Currency) -> int:
	return _balances.get(currency, 0)


# Adds amount to a currency. Clamps to CURRENCY_CAP.
# Always succeeds — use this for rewards, not purchases.
func add(currency: Currency, amount: int) -> void:
	if amount <= 0:
		push_warning("CurrencyManager.add(): amount must be positive (got %d)" % amount)
		return
	var cap: int = CURRENCY_CAP.get(currency, 999_999_999)
	var before: int = _balances[currency]
	_balances[currency] = mini(before + amount, cap)
	var actual_delta := _balances[currency] - before
	if actual_delta > 0:
		balance_changed.emit(currency, _balances[currency], actual_delta)


# Deducts amount from a currency.
# Returns true on success, false if the balance is insufficient.
# Does NOT modify the balance on failure — callers can check
# can_afford() first if they want to show disabled states in the UI.
func spend(currency: Currency, amount: int) -> bool:
	if amount <= 0:
		push_warning("CurrencyManager.spend(): amount must be positive (got %d)" % amount)
		return false
	if _balances[currency] < amount:
		return false
	_balances[currency] -= amount
	balance_changed.emit(currency, _balances[currency], -amount)
	return true


func can_afford(currency: Currency, amount: int) -> bool:
	return _balances.get(currency, 0) >= amount


# ─────────────────────────────────────────────────────────────
# BATCH OPERATIONS
#
# Useful for reward screens that grant multiple currencies at once,
# or purchases that cost both Coins and Tickets simultaneously.
# For transactions that also require materials, call InventoryManager
# separately and use its can_afford checks before spending either system.
# ─────────────────────────────────────────────────────────────

# Grants a batch of currency rewards in one call.
# Example: { Currency.COINS: 250, Currency.SUMMON_TICKETS: 1 }
func add_batch(currency_map: Dictionary) -> void:
	for currency in currency_map:
		add(currency, currency_map[currency])


# Returns true only if every currency cost in the map can be covered.
# Does not modify any balances.
func can_afford_batch(currency_costs: Dictionary) -> bool:
	for currency in currency_costs:
		if not can_afford(currency, currency_costs[currency]):
			return false
	return true


# Spends all costs atomically — either all succeed or none do.
# Returns true on success, false if any single cost cannot be met.
func spend_batch(currency_costs: Dictionary) -> bool:
	if not can_afford_batch(currency_costs):
		return false
	for currency in currency_costs:
		spend(currency, currency_costs[currency])
	return true


# ─────────────────────────────────────────────────────────────
# SAVE / LOAD
# ─────────────────────────────────────────────────────────────

func save() -> void:
	var record := CurrencyRecord.new()
	record.coin_balance   = _balances[Currency.COINS]
	record.ticket_balance = _balances[Currency.SUMMON_TICKETS]
	var err := ResourceSaver.save(record, SAVE_PATH)
	if err != OK:
		push_error("CurrencyManager.save() failed — error code %d" % err)


func load_save() -> void:
	if not ResourceLoader.exists(SAVE_PATH):
		return  # Fresh install — defaults already set in _balances
	var record = ResourceLoader.load(SAVE_PATH)
	if not record is CurrencyRecord:
		push_error("CurrencyManager.load_save(): save file is not a CurrencyRecord")
		return
	_balances[Currency.COINS]          = record.coin_balance
	_balances[Currency.SUMMON_TICKETS] = record.ticket_balance


# Wipes all balances and deletes the save file.
# Use for "New Game" or debug reset — not exposed to normal players.
func reset_all() -> void:
	for key in _balances:
		_balances[key] = 0
	if ResourceLoader.exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ─────────────────────────────────────────────────────────────
# DEBUG
# ─────────────────────────────────────────────────────────────

func debug_print() -> void:
	print("── CurrencyManager ─────────────────────────────────")
	print("  Coins:          %d" % _balances[Currency.COINS])
	print("  Summon Tickets: %d" % _balances[Currency.SUMMON_TICKETS])
	print("────────────────────────────────────────────────────")