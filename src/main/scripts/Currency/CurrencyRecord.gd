# CurrencyRecord.gd
# ─────────────────────────────────────────────────────────────
# Typed Resource that holds a snapshot of all currency balances.
# Written to user://currency_save.tres by CurrencyManager.
#
# Keeping this as a dedicated Resource (rather than raw JSON or a
# plain Dictionary) means:
#   • Save data is inspectable in the Godot editor
#   • ResourceSaver handles serialisation — no manual parsing
#   • Adding a new field here is a one-line change
#
# Scope: currencies only — Coins and Summon Tickets.
# Materials and inventory are owned by InventoryManager and
# persisted in a separate save file.
#
# Do NOT read or write this directly. Always go through CurrencyManager.
# ─────────────────────────────────────────────────────────────
class_name CurrencyRecord
extends Resource

@export var coin_balance: int = 0
@export var ticket_balance: int = 0