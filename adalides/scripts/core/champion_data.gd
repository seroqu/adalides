class_name ChampionData
extends Resource
## Definición estática de una carta de campeón.

@export var id: StringName
@export var display_name: String
@export var classes: Array[int] = [] # Rules.ClassType
@export var tier: Rules.Tier = Rules.Tier.COMUN
@export var cost: int = 1
@export var attack: int = 1
@export var defense: int = 1
@export var reach: Rules.Reach = Rules.Reach.CUERPO_A_CUERPO
## Tabla de acciones: [{ "min": 1, "max": 3, "keywords": [Rules.Keyword.MOV] }, ...]
@export var actions: Array[Dictionary] = []
## Texto de habilidades que aún no están implementadas en código.
@export_multiline var notes: String = ""
## true si la carta es un relleno inventado para poder probar (no está en las reglas).
@export var placeholder: bool = false


static func make(p_id: String, p_name: String, p_classes: Array[int], p_tier: Rules.Tier,
		p_cost: int, p_attack: int, p_defense: int, p_reach: Rules.Reach,
		p_actions: Array[Dictionary], p_notes := "", p_placeholder := false) -> ChampionData:
	var c := ChampionData.new()
	c.id = p_id
	c.display_name = p_name
	c.classes = p_classes
	c.tier = p_tier
	c.cost = p_cost
	c.attack = p_attack
	c.defense = p_defense
	c.reach = p_reach
	c.actions = p_actions
	c.notes = p_notes
	c.placeholder = p_placeholder
	return c


## Atajo para construir una fila de la tabla de acciones.
static func action(p_min: int, p_max: int, keywords: Array[int]) -> Dictionary:
	return { "min": p_min, "max": p_max, "keywords": keywords }


## Palabras clave que ejecuta el campeón con un resultado de DA dado.
func keywords_for(roll: int) -> Array[int]:
	for row in actions:
		if roll >= row["min"] and roll <= row["max"]:
			var out: Array[int] = []
			out.assign(row["keywords"])
			return out
	return []


func has_class(c: int) -> bool:
	return classes.has(c)


func strength() -> int:
	return Rules.STRENGTH_BY_TIER.get(tier, 1)


func describe() -> String:
	var names: PackedStringArray = []
	for c in classes:
		names.append(Rules.class_label(c))
	return "%s [%s] %d/%d (%s, coste %d)" % [
		display_name, ", ".join(names), attack, defense, Rules.tier_label(tier), cost]
