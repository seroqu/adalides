class_name Tiers
extends RefCounted
## Tiers elementales (3/6/9) y de arquetipo (2/4/6) de un bando, contando los
## campeones que están en la batalla (decisión del autor).


static func count_elements(champions: Array[Champion]) -> Dictionary:
	var counts := {}
	for ch in champions:
		if ch.data.element >= 0:
			counts[ch.data.element] = counts.get(ch.data.element, 0) + 1
	return counts


static func count_archetypes(champions: Array[Champion]) -> Dictionary:
	var counts := {}
	for ch in champions:
		for a in ch.data.archetypes():
			counts[a] = counts.get(a, 0) + 1
	return counts


## { Element: 1|2|3 } para los elementos con tier activo.
static func elements(champions: Array[Champion]) -> Dictionary:
	var out := {}
	var counts := count_elements(champions)
	for e in counts:
		var t := Rules.tier_index(counts[e], Rules.ELEMENT_TIERS)
		if t > 0:
			out[e] = t
	return out


## { Archetype: 1|2|3 } para los arquetipos con tier activo.
static func archetypes(champions: Array[Champion]) -> Dictionary:
	var out := {}
	var counts := count_archetypes(champions)
	for a in counts:
		var t := Rules.tier_index(counts[a], Rules.ARCHETYPE_TIERS)
		if t > 0:
			out[a] = t
	return out


## Valor de una habilidad escalonada (a/b/c) según el tier 1..3; 0 si no hay tier.
static func scaled(tier: int, values: Array) -> int:
	if tier <= 0:
		return 0
	return values[mini(tier, values.size()) - 1]


static func describe(champions: Array[Champion]) -> String:
	var parts: PackedStringArray = []
	var el := elements(champions)
	for e in el:
		parts.append("%s %d" % [Rules.element_label(e), Rules.ELEMENT_TIERS[el[e] - 1]])
	var ar := archetypes(champions)
	for a in ar:
		parts.append("%s %d" % [Rules.archetype_label(a), Rules.ARCHETYPE_TIERS[ar[a] - 1]])
	return ", ".join(parts)
