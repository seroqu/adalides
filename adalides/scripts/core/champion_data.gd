class_name ChampionData
extends Resource
## Carta de campeón v2: arquetipo × elemento (o héroe de dos arquetipos).

@export var id: StringName
@export var display_name: String
@export var archetype: Rules.Archetype
@export var second_archetype: int = -1 # Solo héroes.
@export var element: int = -1 # -1 en héroes (SUPUESTO: no tienen elemento).
@export var cost: int = 1
@export var attack: int = 1
@export var defense: int = 1
@export var hero: bool = false
## Poder de la carta: { "name", "phase": Rules.Phase, "passive": bool, "req": [Rules.Die...], "text" }.
@export var power: Dictionary = {}


static func make(p_id: String, p_name: String, p_arch: Rules.Archetype, p_elem: int,
		p_cost: int, p_atk: int, p_def: int, p_power: Dictionary = {}) -> ChampionData:
	var c := ChampionData.new()
	c.id = p_id
	c.display_name = p_name
	c.archetype = p_arch
	c.element = p_elem
	c.cost = p_cost
	c.attack = p_atk
	c.defense = p_def
	c.power = p_power
	return c


static func make_hero(p_id: String, p_name: String, p_arch: Rules.Archetype, p_second: Rules.Archetype,
		p_atk: int, p_def: int) -> ChampionData:
	var c := make(p_id, p_name, p_arch, -1, Rules.HERO_COST, p_atk, p_def)
	c.second_archetype = p_second
	c.hero = true
	return c


func archetypes() -> Array[int]:
	var out: Array[int] = [archetype]
	if second_archetype >= 0:
		out.append(second_archetype)
	return out


func has_archetype(a: int) -> bool:
	return archetype == a or second_archetype == a


func reach() -> int:
	var r := Rules.reach_of(archetype)
	if second_archetype >= 0:
		r = maxi(r, Rules.reach_of(second_archetype))
	return r


func has_power() -> bool:
	return not power.is_empty()


func power_phase() -> int:
	return power.get("phase", Rules.Phase.H)


func power_is_passive() -> bool:
	return power.get("passive", false)


func power_requirement() -> Array:
	return power.get("req", [])


func describe() -> String:
	var kind := "Héroe" if hero else Rules.element_label(element)
	var arch := Rules.archetype_label(archetype)
	if second_archetype >= 0:
		arch += " + " + Rules.archetype_label(second_archetype)
	return "%s [%s %s] %d/%d (%d Éter)" % [display_name, arch, kind, attack, defense, cost]
