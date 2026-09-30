# CurrencyRecord.gd
# ─────────────────────────────────────────────────────────────
# Typed Resource snapshot of currency balances (legacy helper type).
# Live balances persist via PlayerSave (user://player_save.res).
# CurrencyManager may still construct this for debug / transitional use.
#
# Do NOT treat this as the player wallet. Always go through CurrencyManager
# or PlayerSave for real progress.
# ─────────────────────────────────────────────────────────────
class_name CurrencyRecord
extends Resource

@export var coin_balance: int = 0
@export var ticket_balance: int = 0
@export var gear_ticket_balance: int = 0
