# ElementSystem.gd
# ─────────────────────────────────────────────────────────────
# Autoload singleton — Project > Project Settings > Autoload
# Name: "ElementSystem"
#
# Elements: Fire, Earth, Electric, Water, Light, Dark
# Cycle:    FIRE → EARTH → ELECTRIC → WATER → FIRE
# Polars:   LIGHT ↔ DARK  (mutually strong against each other)
#
# Advantage  → attacker's CRIT_DMG stat (floor 1.2×, cap 2.25×)
# Neutral    → 1.0×
# Disadvantage → 0.75×
# No RNG. Advantage always crits.
# ─────────────────────────────────────────────────────────────
extends Node


# ─────────────────────────────────────────────────────────────
# ELEMENT ENUM
# ─────────────────────────────────────────────────────────────

enum Element {
	NONE,
	FIRE,
	EARTH,
	ELECTRIC,
	WATER,
	LIGHT,
	DARK
}


# ─────────────────────────────────────────────────────────────
# MULTIPLIERS
# ─────────────────────────────────────────────────────────────

const MULTIPLIER_DISADVANTAGE: float = 0.75
const MULTIPLIER_NEUTRAL: float = 1.0
# Advantage multiplier is NOT a constant — it's the unit's CRIT_DMG stat
const CRIT_DMG_FLOOR: float = 1.25
const CRIT_DMG_CAP: float = 2.25


# ─────────────────────────────────────────────────────────────
# ELEMENTAL CYCLE
#
# FIRE → EARTH → ELECTRIC → WATER → FIRE
# LIGHT ↔ DARK
#
# "A → B" means A is STRONG against B (B is weak to A).
# ─────────────────────────────────────────────────────────────

# What each element is strong against (beats)
const STRONG_AGAINST: Dictionary = {
	Element.FIRE: Element.EARTH,
	Element.EARTH: Element.ELECTRIC,
	Element.ELECTRIC: Element.WATER,
	Element.WATER: Element.FIRE,
	Element.LIGHT: Element.DARK,
	Element.DARK: Element.LIGHT,
	Element.NONE: Element.NONE,
}

# Derived at runtime — what each element is weak to
var _weak_to: Dictionary = {}


func _ready() -> void:
	_build_weakness_table()


func _build_weakness_table() -> void:
	for element in Element.values():
		_weak_to[element] = Element.NONE

	for attacker in STRONG_AGAINST:
		if attacker == Element.DARK or attacker == Element.LIGHT:
			_weak_to[attacker] = Element.NONE
		
		var defender = STRONG_AGAINST[attacker]
		if defender != Element.NONE:
			_weak_to[defender] = attacker


# ─────────────────────────────────────────────────────────────
# CORE: ELEMENTAL RELATIONSHIP
# ─────────────────────────────────────────────────────────────

enum Relationship {ADVANTAGE, NEUTRAL, DISADVANTAGE}

# Returns the relationship from the attacker's perspective
func get_relationship(attacker_element: Element, defender_element: Element) -> Relationship:
	if attacker_element == Element.NONE or defender_element == Element.NONE:
		return Relationship.NEUTRAL

	if STRONG_AGAINST.get(attacker_element) == defender_element:
		return Relationship.ADVANTAGE

	if STRONG_AGAINST.get(defender_element) == attacker_element:
		return Relationship.DISADVANTAGE

	return Relationship.NEUTRAL


# ─────────────────────────────────────────────────────────────
# CORE: ELEMENTAL MULTIPLIER
#
# Returns the elemental portion of the damage formula.
# Advantage uses the attacker's CRIT_DMG stat, clamped to [floor, cap].
# Pass crit_dmg_stat = 0.0 when calling from a context without a unit
# (e.g. preview tooltips) to get the floor value.
# ─────────────────────────────────────────────────────────────

func get_elemental_multiplier(
		attacker_element: Element,
		defender_element: Element,
		crit_dmg_stat: float = CRIT_DMG_FLOOR) -> float:
	match get_relationship(attacker_element, defender_element):
		Relationship.ADVANTAGE:
			return clamp(crit_dmg_stat, CRIT_DMG_FLOOR, CRIT_DMG_CAP)
		Relationship.DISADVANTAGE:
			return MULTIPLIER_DISADVANTAGE
		_:
			return MULTIPLIER_NEUTRAL


# ─────────────────────────────────────────────────────────────
# CORE: FULL DAMAGE FORMULA
#
# DMG = ATK × DEF_reduction × Elemental_mult × ELEM_RES_reduction
#
# DEF_reduction  = DEF / (DEF + 300)  gives ~25% reduction at 100 DEF
# ELEM_RES_reduction = ELEM_RES / (ELEM_RES + 300)
#   — only applied when elemental_mult != NEUTRAL
#
# Returns final integer damage. Minimum 1.
# ─────────────────────────────────────────────────────────────

func calculate_damage(
		atk: int,
		def_stat: int,
		elem_res: int,
		attacker_element: Element,
		defender_element: Element,
		crit_dmg_stat: float) -> int:
	# DEF reduction — applies to all damage
	var def_factor: float = 1.0 - (float(def_stat) / (float(def_stat) + 300.0))

	# Elemental multiplier
	var elem_mult: float = get_elemental_multiplier(attacker_element, defender_element, crit_dmg_stat)

	# ELEM RES reduction — only when an elemental interaction is present
	var elem_res_factor: float = 1.0
	if elem_mult != MULTIPLIER_NEUTRAL:
		elem_res_factor = 1.0 - (float(elem_res) / (float(elem_res) + 300.0))

	var raw: float = float(atk) * def_factor * elem_mult * elem_res_factor
	return max(1, int(raw))


# ─────────────────────────────────────────────────────────────
# UI HELPERS
# ─────────────────────────────────────────────────────────────

func get_element_name(element: Element) -> String:
	match element:
		Element.FIRE: return "Fire"
		Element.EARTH: return "Earth"
		Element.ELECTRIC: return "Electric"
		Element.WATER: return "Water"
		Element.LIGHT: return "Light"
		Element.DARK: return "Dark"
		_: return "None"

func get_element_color(element: Element) -> Color:
	match element:
		Element.FIRE: return Color(0.95, 0.35, 0.15) # Red-orange
		Element.EARTH: return Color(0.65, 0.42, 0.18) # Earthy brown
		Element.ELECTRIC: return Color(0.98, 0.90, 0.10) # Bright yellow
		Element.WATER: return Color(0.20, 0.55, 0.90) # Ocean blue
		Element.LIGHT: return Color(1.00, 0.96, 0.70) # Warm gold
		Element.DARK: return Color(0.38, 0.18, 0.58) # Deep purple
		_: return Color(0.60, 0.60, 0.60) # Grey

func get_element_icon_path(element: Element) -> String:
	return "res://assets/icons/elements/%s.png" % get_element_name(element).to_lower()

# Returns a short label for floating combat text
# "CRIT!"  on advantage, "WEAK" on disadvantage, "" on neutral
func get_hit_label(attacker_element: Element, defender_element: Element) -> String:
	match get_relationship(attacker_element, defender_element):
		Relationship.ADVANTAGE: return "CRIT!"
		Relationship.DISADVANTAGE: return "WEAK"
		_: return ""

# Returns what element this element is strong against — used in UI tooltips
func get_strength_target(element: Element) -> Element:
	return STRONG_AGAINST.get(element, Element.NONE)

# Returns what element this element is weak to — used in UI tooltips
func get_weakness_source(element: Element) -> Element:
	return _weak_to.get(element, Element.NONE)


# ─────────────────────────────────────────────────────────────
# DEBUG
# ─────────────────────────────────────────────────────────────

func debug_print_chart() -> void:
	print("── Element Chart ─────────────────────────────────")
	for element in Element.values():
		if element == Element.NONE:
			continue
		var strong_vs := get_element_name(STRONG_AGAINST.get(element, Element.NONE))
		var weak_to := get_element_name(_weak_to.get(element, Element.NONE))
		print("  %-10s  strong vs: %-10s  weak to: %s" % [
			get_element_name(element), strong_vs, weak_to
		])
	print("──────────────────────────────────────────────────")

func debug_preview_damage(atk: int, def_stat: int, elem_res: int,
		atk_elem: Element, def_elem: Element, crit_dmg: float) -> void:
	var dmg := calculate_damage(atk, def_stat, elem_res, atk_elem, def_elem, crit_dmg)
	var rel := get_relationship(atk_elem, def_elem)
	var label = ["ADVANTAGE", "NEUTRAL", "DISADVANTAGE"][rel]
	print("DMG preview | ATK:%d DEF:%d ELEM_RES:%d | %s vs %s (%s) → %d dmg" % [
		atk, def_stat, elem_res,
		get_element_name(atk_elem), get_element_name(def_elem),
		label, dmg
	])
