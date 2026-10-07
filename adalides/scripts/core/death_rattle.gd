class_name DeathRattle
extends RefCounted
## Estertores: lo que recibe el asesino cuando elimina a un adalid
## (README: "Muerte de un adalid y estertores").

const NAMES := {
	Rules.ClassType.FUEGO: "Venganza ígnea", Rules.ClassType.ELECTRICO: "Descarga",
	Rules.ClassType.TIERRA: "Desmoronar", Rules.ClassType.AIRE: "Vientos en contra",
	Rules.ClassType.HIELO: "Cristalizar", Rules.ClassType.MAL: "Fantasma",
	Rules.ClassType.BIEN: "Resurrección", Rules.ClassType.SALVAJE: "Veneno",
	Rules.ClassType.ROBOT: "Hackeo", Rules.ClassType.MAGO: "Encantamiento",
	Rules.ClassType.PROTECTOR: "Deshonor", Rules.ClassType.ASESINO: "Secuestro",
}


## Clase con más campeones en la reserva del muerto. SUPUESTO: en empate se
## elige al azar (el muerto escogería; aquí no hay jugador humano).
static func dominant_class(victim: Adalid, rng: RandomNumberGenerator) -> int:
	var counts := Synergy.count_by_class(victim.reserve)
	if counts.is_empty():
		return -1
	var best: Array[int] = []
	var best_count := 0
	for c in counts:
		if counts[c] > best_count:
			best_count = counts[c]
			best = [c]
		elif counts[c] == best_count:
			best.append(c)
	return best[rng.randi_range(0, best.size() - 1)]


## Aplica el estertor y devuelve las líneas de registro.
static func apply(killer: Adalid, victim: Adalid, rng: RandomNumberGenerator) -> PackedStringArray:
	var lines: PackedStringArray = []
	var c := dominant_class(victim, rng)
	if c < 0:
		lines.append("%s no tenía campeones: sin estertor." % victim.display_name)
		return lines
	lines.append("Estertor de %s: %s (%s)." % [victim.display_name, NAMES[c], Rules.class_label(c)])
	match c:
		Rules.ClassType.FUEGO:
			killer.lose_vitality(3)
			lines.append("  %s recibe 3 de daño." % killer.display_name)
		Rules.ClassType.ELECTRICO:
			for ch in killer.reserve:
				ch.duplicates = 0
			lines.append("  %s pierde las multiplicaciones de todos sus campeones." % killer.display_name)
		Rules.ClassType.TIERRA:
			if not killer.reserve.is_empty():
				var ch: Champion = killer.reserve[rng.randi_range(0, killer.reserve.size() - 1)]
				killer.remove_card(ch)
				lines.append("  %s pierde a %s (con sus duplicados)." % [killer.display_name, ch.data.display_name])
		Rules.ClassType.AIRE:
			killer.cannot_buy_from_dead = true
			lines.append("  %s no puede comprar de la reserva enemiga." % killer.display_name)
		Rules.ClassType.HIELO:
			killer.no_interest_rounds = 3
			lines.append("  %s no recibe intereses por 3 turnos." % killer.display_name)
		Rules.ClassType.MAL:
			victim.ghost = true
			lines.append("  %s sigue combatiendo como fantasma, sin fases de preparación." % victim.display_name)
		Rules.ClassType.BIEN:
			victim.eliminated = false
			victim.vitality = 5
			for ch in victim.cards_of_class(Rules.ClassType.BIEN):
				victim.remove_card(ch)
			lines.append("  %s resucita con 5 de vida y pierde sus ángeles." % victim.display_name)
		Rules.ClassType.SALVAJE:
			killer.poisoned = true
			lines.append("  %s está envenenado: pierde 1 de vida extra al perder combates." % killer.display_name)
		Rules.ClassType.ROBOT:
			killer.eter /= 2
			lines.append("  %s pierde la mitad de su Éter (queda %d)." % [killer.display_name, killer.eter])
		Rules.ClassType.MAGO:
			killer.interest_override = 2
			lines.append("  El interés de %s produce solo 2." % killer.display_name)
		Rules.ClassType.PROTECTOR:
			killer.sell_value_override = 1
			lines.append("  Vender campeones solo da 1 de Éter a %s." % killer.display_name)
		Rules.ClassType.ASESINO:
			var usable := killer.usable_cards()
			if not usable.is_empty():
				usable.sort_custom(func(a: Champion, b: Champion) -> bool: return a.data.cost > b.data.cost)
				killer.kidnapped = usable[0]
				lines.append("  %s queda secuestrado; rescate: %d de Éter." % [usable[0].data.display_name, Rules.RANSOM_COST])
	return lines
