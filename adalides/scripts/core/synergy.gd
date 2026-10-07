class_name Synergy
extends RefCounted
## Conteo de campeones por clase y nivel de sinergia alcanzado (3 / 5 / 7).


static func count_by_class(champions: Array) -> Dictionary:
	var counts := {}
	for ch in champions:
		var data: ChampionData = ch.data if ch is Champion else ch
		for c in data.classes:
			counts[c] = counts.get(c, 0) + 1
	return counts


## Devuelve 0, 3, 5 o 7 según cuántos campeones de la clase haya.
static func tier_for_count(count: int) -> int:
	var reached := 0
	for t in Rules.SYNERGY_TIERS:
		if count >= t:
			reached = t
	return reached


static func tier(champions: Array, c: int) -> int:
	return tier_for_count(count_by_class(champions).get(c, 0))


## { ClassType: 3|5|7 } solo para las clases con sinergia activa.
static func active(champions: Array) -> Dictionary:
	var out := {}
	for c in count_by_class(champions):
		var t := tier_for_count(count_by_class(champions)[c])
		if t > 0:
			out[c] = t
	return out
