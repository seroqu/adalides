class_name Abilities
extends RefCounted
## Habilidades SPEC y pasivas de cartas concretas (README: "Señores elementales",
## "Héroes", "Legendarios"). Cada función recibe el combate para poder tirar
## dados, hacer daño y escribir en el registro.


## Resuelve una acción SPEC según la carta y el resultado del DA.
static func spec(combat: Combat, a: Dictionary) -> void:
	var ch: Champion = a["champion"]
	var side: int = a["side"]
	var board: Battlefield = combat.sides[side]
	var enemy: Battlefield = combat.sides[1 - side]
	var roll: int = a["roll"]
	match String(ch.data.id):
		"plasma":
			var target := combat.choose_target(ch, board, enemy, Rules.Reach.RANGO)
			if target != null:
				combat.direct_damage(ch, target, 5, "Plasma")
			for other in enemy.alive():
				if other != target:
					combat.direct_damage(ch, other, 1, "Plasma (área)")
		"lava":
			for i in Rules.BOARD_SIZE:
				var other := enemy.champion_at(i)
				if other != null and other.alive:
					combat.direct_damage(ch, other, (i + 1) - 2, "Lava")
		"tormenta":
			for p in Dice.roll_many(combat.rng, 3):
				var other := enemy.champion_at(p - 1)
				if other != null and other.alive:
					combat.direct_damage(ch, other, ch.attack(), "Tormenta")
					other.frozen = true
			combat.log_line("  Tormenta congela lo alcanzado.")
		"senores_aire":
			if roll >= 6:
				var lords := 0
				for own in board.alive():
					if own.data.tier == Rules.Tier.ELEMENTAL:
						lords += 1
				for other in enemy.alive():
					combat.direct_damage(ch, other, lords * lords, "Señores del aire")
			else:
				combat.do_attack(a) # 3: mueve un enemigo y ataca (SUPUESTO: solo ataca).
		"demonio_electrico":
			var from := board.index_of(ch)
			var victim: Champion = null
			for i in board.adjacent_own(from):
				var ally := board.champion_at(i)
				if ally != null and ally.alive and (victim == null or ally.attack() > victim.attack()):
					victim = ally
			if victim == null:
				combat.log_line("  Demonio eléctrico no tiene aliados adyacentes que explotar.")
				return
			var blast := victim.attack()
			var target := combat.choose_target(ch, board, enemy, Rules.Reach.RANGO)
			var vi := board.index_of(victim)
			victim.take_damage(victim.defense_left, ch)
			combat.log_line("  Demonio eléctrico hace explotar a %s." % victim.data.display_name)
			if target != null:
				combat.direct_damage(ch, target, blast, "Explosión")
			for i in board.adjacent_own(vi):
				var ally := board.champion_at(i)
				if ally != null and ally.alive and ally != ch:
					combat.direct_damage(ch, ally, blast / 2, "Explosión (aliado)")
		"demonio_arena":
			var stolen := 0
			for p in Dice.roll_many(combat.rng, 5):
				var other := enemy.champion_at(p - 1)
				if other != null and other.alive:
					var half := ceili(other.defense_left / 2.0)
					stolen += combat.direct_damage(ch, other, half, "Demonio de arena")
			ch.extra_defense += stolen
			ch.defense_left += stolen
			combat.log_line("  Demonio de arena roba %d de vida." % stolen)
		"mago_plasma":
			if roll >= 3:
				var blast := ch.attack()
				ch.take_damage(ch.defense_left, ch)
				combat.log_line("  Mago de plasma explota.")
				for s in combat.sides:
					for other in s.alive():
						if not other.data.has_class(Rules.ClassType.MAGO):
							combat.direct_damage(ch, other, blast, "Explosión de plasma")
			else:
				ch.doubled = true
				combat.log_line("  Mago de plasma duplica su daño.")
		"mago_tormenta":
			if roll >= 4:
				for other in enemy.alive():
					combat.direct_damage(ch, other, 2, "Mago de tormenta")
					other.frozen = true
				combat.log_line("  Mago de tormenta congela a todos los enemigos.")
			else:
				combat.log_line("  Mago de tormenta: desviar daño (no implementado).")
		"androide_glacial":
			var target := combat.choose_target(ch, board, enemy, Rules.Reach.RANGO)
			if target == null:
				return
			if roll >= 5:
				var x: int = mini(board.owner.eter, target.defense_left)
				if board.owner.pay(x):
					combat.direct_damage(ch, target, x, "Androide glacial (%d Éter)" % x)
			else:
				var turns: int = mini(board.owner.eter, 2)
				if turns > 0 and board.owner.pay(turns):
					target.frozen = true
					target.frozen_turns = turns
					combat.log_line("  Androide glacial paga %d y congela %d turnos a %s." % [turns, turns, target.data.display_name])
		"androide_huracan":
			if roll >= 4:
				board.owner.eter *= 2
				combat.log_line("  Androide del huracán duplica el Éter de %s (%d)." % [board.owner.display_name, board.owner.eter])
			else:
				var x: int = mini(board.owner.eter - board.owner.eter % 5, 10)
				if x > 0 and board.owner.pay(x):
					for other in enemy.alive():
						combat.direct_damage(ch, other, x / 5, "Androide del huracán (%d Éter)" % x)
		_:
			combat.log_line("  %s: SPEC sin implementar." % ch.data.display_name)


## Reducción fija de daño por pasivas de carta (gigantes: 2 menos).
static func damage_reduction(target: Champion) -> int:
	match String(target.data.id):
		"gigante_hielo", "gigante_infernal":
			return 2
	return 0


## true si la carta esquiva por su propia pasiva (6 en un d6).
static func passive_dodge(target: Champion, rng: RandomNumberGenerator) -> bool:
	match String(target.data.id):
		"cazador_viento", "senores_aire":
			return Dice.roll(rng) == 6
	return false


static func on_damaged(combat: Combat, target: Champion, attacker: Champion) -> void:
	if attacker == null or attacker == target:
		return
	match String(target.data.id):
		"gigante_hielo":
			attacker.frozen = true
			combat.log_line("  Gigante de hielo congela a %s." % attacker.data.display_name)
		"gigante_infernal":
			attacker.take_damage(2, target)
			combat.log_line("  Gigante infernal devuelve 2 de daño a %s." % attacker.data.display_name)


static func on_death(combat: Combat, dead: Champion, board: Battlefield, enemy: Battlefield) -> void:
	match String(dead.data.id):
		"glacial":
			for p in Dice.roll_many(combat.rng, 2):
				var other := enemy.champion_at(p - 1)
				if other != null and other.alive:
					other.take_damage(other.defense_left, dead)
					combat.log_line("  Glacial muere y arrastra a %s." % other.data.display_name)


static func on_combat_end(combat: Combat, board: Battlefield) -> void:
	for ch in board.alive():
		if ch.data.id == &"arcangel":
			board.owner.gain_vitality(2)
			combat.log_line("  Arcángel sigue vivo: %s gana 2 de salud." % board.owner.display_name)


static func starts_in_stealth(ch: Champion) -> bool:
	return ch.data.id == &"cazador_viento"
