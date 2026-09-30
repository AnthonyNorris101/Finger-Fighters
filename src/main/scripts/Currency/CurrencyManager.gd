# CurrencyManager.gd
# ─────────────────────────────────────────────────────────────
# Autoload singleton — Project > Project Settings > Autoload
# Name: "CurrencyManager"
#
# Single source of truth for Coins, Summon Tickets, and Gear Tickets.
# Nothing else should mutate these values directly.
# Materials and stackable items are handled by InventoryManager.
#
# SAVE / LOAD:
#   Balances live in user://player_save.res (PlayerSave) with pity + collection.
#   Use write_balances_into / load_from_player_save for gacha transactions.
#   save() / load_save() write currency fields only (shop / boot helpers).
# ─────────────────────────────────────────────────────────────
extends Node


# ─────────────────────────────────────────────────────────────
# ENUM
# ─────────────────────────────────────────────────────────────

enum Currency {
	COINS,
	SUMMON_TICKETS,
	GEAR_TICKETS,
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

# Absolute cap per Currency — prevents overflow from runaway reward
# loops. Values are intentionally generous placeholders; tune during
# economy balancing.
const CURRENCY_CAP: Dictionary = {
	Currency.COINS:          999_999_999,
	Currency.SUMMON_TICKETS: 9_999,
	Currency.GEAR_TICKETS:   9_999,
}


# ─────────────────────────────────────────────────────────────
# INTERNAL STATE
# ─────────────────────────────────────────────────────────────

var _balances: Dictionary = {
	Currency.COINS:          0,
	Currency.SUMMON_TICKETS: 0,
	Currency.GEAR_TICKETS:   0,
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
	var actual_delta = _balances[currency] - before
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
# SAVE / LOAD  (PlayerSave — user://player_save.res)
# ─────────────────────────────────────────────────────────────

func write_balances_into(save: PlayerSave) -> void:
	save.coin_balance = _balances[Currency.COINS]
	save.summon_ticket_balance = _balances[Currency.SUMMON_TICKETS]
	save.gear_ticket_balance = _balances[Currency.GEAR_TICKETS]


func load_from_player_save(save: PlayerSave = null) -> void:
	if save == null:
		save = PlayerSave.load_or_create()
	_balances[Currency.COINS] = int(save.coin_balance)
	_balances[Currency.SUMMON_TICKETS] = int(save.summon_ticket_balance)
	_balances[Currency.GEAR_TICKETS] = int(save.gear_ticket_balance)


func save() -> void:
	# Shop / rewards: update currency fields only; keep pity/collection.
	var save := PlayerSave.load_or_create()
	write_balances_into(save)
	save.save_to_disk()


func load_save() -> void:
	load_from_player_save()
	# One-time cleanup of old wallet file (Anthony wipe OK).
	var old_path := "user://currency_save.tres"
	if FileAccess.file_exists(old_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))


func reset_all() -> void:
	for key in _balances:
		_balances[key] = 0
	save()

# ─────────────────────────────────────────────────────────────
# DEBUG
# ─────────────────────────────────────────────────────────────

func debug_print() -> void:
	print("── CurrencyManager ─────────────────────────────────")
	print("  Coins:          %d" % _balances[Currency.COINS])
	print("  Summon Tickets: %d" % _balances[Currency.SUMMON_TICKETS])
	print("  Gear Tickets:   %d" % _balances[Currency.GEAR_TICKETS])
	print("────────────────────────────────────────────────────")
