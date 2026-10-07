class_name Roster
extends RefCounted
## Requisitos para colocar campeones en el mapa (README: "Requisitos para usar campeones")
## y la IA que elige qué cartas de la reserva llevar al combate.


## Devuelve la lista de problemas de una alineación; vacía si es válida.
static func validate(adalid: Adalid, chosen: Array[Champion]) -> PackedStringArray:
	var errors: PackedStringArray = []
	if chosen.size() > Rules.BOARD_SIZE:
		errors.append("Máximo %d campeones en el mapa." % Rules.BOARD_SIZE)
	var synergies := Synergy.active(chosen)
	var elementals := 0
	var hero_groups := {}
	for ch in chosen:
		if ch.annihilated:
			errors.append("%s fue aniquilado." % ch.data.display_name)
		if ch == adalid.kidnapped:
			errors.append("%s está secuestrado." % ch.data.display_name)
		match ch.data.tier:
			Rules.Tier.ELEMENTAL:
				elementals += 1
				if adalid.level < 2:
					errors.append("%s necesita nivel 2." % ch.data.display_name)
				if not _has_synergy(synergies, ch.data.classes, 3):
					errors.append("%s necesita una sinergia (3) de sus clases." % ch.data.display_name)
			Rules.Tier.HEROE:
				if adalid.level < 3:
					errors.append("%s necesita nivel 3." % ch.data.display_name)
				if not _has_synergy(synergies, ch.data.classes, 5):
					errors.append("%s necesita una sinergia (5) de sus clases." % ch.data.display_name)
				var group := _hero_group(synergies, ch.data.classes)
				if group >= 0 and hero_groups.has(group):
					errors.append("Ya hay un héroe por el grupo %s." % Rules.class_label(group))
				hero_groups[group] = true
			Rules.Tier.LEGENDARIO:
				if adalid.level < 3:
					errors.append("%s necesita nivel 3." % ch.data.display_name)
	var max_elementals: int = Rules.MAX_ELEMENTALS_BY_LEVEL.get(adalid.level, 0)
	if elementals > max_elementals:
		errors.append("Solo puedes usar %d elemental(es) en nivel %d." % [max_elementals, adalid.level])
	return errors


static func _has_synergy(synergies: Dictionary, classes: Array[int], tier: int) -> bool:
	for c in classes:
		if synergies.get(c, 0) >= tier:
			return true
	return false


static func _hero_group(synergies: Dictionary, classes: Array[int]) -> int:
	for c in classes:
		if synergies.get(c, 0) >= 5:
			return c
	return -1


## IA: elige hasta 6 cartas válidas. Primero comunes (las más fuertes); luego
## intenta meter todas las cartas superiores a la vez (los elementales suelen
## necesitarse entre sí para la sinergia) y va quitando las que no cumplan.
static func auto_pick(adalid: Adalid) -> Array[Champion]:
	var usable := adalid.usable_cards()
	usable.sort_custom(func(a: Champion, b: Champion) -> bool:
		return a.attack() + a.max_defense() > b.attack() + b.max_defense())
	var chosen: Array[Champion] = []
	var upper: Array[Champion] = []
	for ch in usable:
		if ch.data.tier == Rules.Tier.COMUN:
			if chosen.size() < Rules.BOARD_SIZE:
				chosen.append(ch)
		else:
			upper.append(ch)
	if upper.is_empty():
		return chosen
	var attempt: Array[Champion] = chosen.duplicate()
	for ch in upper:
		if attempt.size() >= Rules.BOARD_SIZE:
			var weakest := _weakest_common(attempt)
			if weakest < 0:
				break
			attempt.remove_at(weakest)
		attempt.append(ch)
	while not validate(adalid, attempt).is_empty():
		var dropped := false
		for i in range(attempt.size() - 1, -1, -1):
			if attempt[i].data.tier != Rules.Tier.COMUN:
				attempt.remove_at(i)
				dropped = true
				break
		if not dropped:
			return chosen
	# Rellena huecos con las comunes que quedaron fuera.
	for ch in usable:
		if attempt.size() >= Rules.BOARD_SIZE:
			break
		if ch.data.tier == Rules.Tier.COMUN and not attempt.has(ch):
			attempt.append(ch)
	return attempt if validate(adalid, attempt).is_empty() else chosen


static func _weakest_common(list: Array[Champion]) -> int:
	var idx := -1
	for i in list.size():
		if list[i].data.tier != Rules.Tier.COMUN:
			continue
		if idx < 0 or list[i].attack() + list[i].max_defense() < list[idx].attack() + list[idx].max_defense():
			idx = i
	return idx


static func build_board(adalid: Adalid, chosen: Array[Champion]) -> Battlefield:
	var board := Battlefield.new(adalid)
	for i in mini(chosen.size(), Rules.BOARD_SIZE):
		chosen[i].reset_for_combat()
		board.place(chosen[i], i)
	return board
