class_name Battlefield
extends RefCounted
## El mapa de combate de un adalid: BOARD_SIZE posiciones numeradas (1..6).
## SUPUESTO: los dos mapas se enfrentan como dos filas; la posición i es
## adyacente a las enemigas i-1, i, i+1 y a las propias i-1, i+1.
## El "espacio contrario" (Emboscador) es la posición enemiga con el mismo número.

var owner: Adalid
var slots: Array = [] # Champion o null, índice 0..BOARD_SIZE-1
var synergies: Dictionary = {} # { ClassType: 3|5|7 }


func _init(p_owner: Adalid) -> void:
	owner = p_owner
	slots.resize(Rules.BOARD_SIZE)
	slots.fill(null)


func place(champion: Champion, index: int) -> void:
	slots[index] = champion
	_refresh_synergies()


func champion_at(index: int) -> Champion:
	if index < 0 or index >= Rules.BOARD_SIZE:
		return null
	return slots[index]


func index_of(champion: Champion) -> int:
	return slots.find(champion)


func alive() -> Array[Champion]:
	var out: Array[Champion] = []
	for ch in slots:
		if ch != null and ch.alive:
			out.append(ch)
	return out


func alive_count() -> int:
	return alive().size()


## Suma de fuerza de los supervivientes (común 1, elemental 2, héroe 3).
func strength() -> int:
	var total := 0
	for ch in alive():
		total += ch.data.strength()
	return total


func synergy(c: int) -> int:
	return synergies.get(c, 0)


func adjacent_own(index: int) -> Array[int]:
	var out: Array[int] = []
	for i in [index - 1, index + 1]:
		if i >= 0 and i < Rules.BOARD_SIZE:
			out.append(i)
	return out


func adjacent_enemy(index: int) -> Array[int]:
	var out: Array[int] = []
	for i in [index - 1, index, index + 1]:
		if i >= 0 and i < Rules.BOARD_SIZE:
			out.append(i)
	return out


func opposite(index: int) -> int:
	return index


func remove_dead() -> Array[Champion]:
	var removed: Array[Champion] = []
	for i in Rules.BOARD_SIZE:
		var ch: Champion = slots[i]
		if ch != null and not ch.alive:
			removed.append(ch)
			slots[i] = null
	return removed


func describe() -> PackedStringArray:
	var lines: PackedStringArray = []
	for i in Rules.BOARD_SIZE:
		var ch: Champion = slots[i]
		lines.append("%d. %s" % [i + 1, "—" if ch == null else ch.label()])
	return lines


func _refresh_synergies() -> void:
	var present: Array = []
	for ch in slots:
		if ch != null:
			present.append(ch)
	synergies = Synergy.active(present)
