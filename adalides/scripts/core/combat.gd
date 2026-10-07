class_name Combat
extends RefCounted
## Simula un combate completo entre dos adalides siguiendo README: "Combate".
## Las decisiones (qué DA emparejar con qué DP, a quién atacar, hacia dónde mover)
## las toma una IA simple; la lógica está separada para poder sustituirla por
## la elección del jugador más adelante.

var sides: Array[Battlefield] = []
var rng: RandomNumberGenerator
var log: PackedStringArray = []
var round_no: int = 0
var fire_fumbles: Array[int] = [0, 0] # Pifias de DF acumuladas por lado (Fuego).


func _init(a: Battlefield, b: Battlefield, p_rng: RandomNumberGenerator = null) -> void:
	sides = [a, b]
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()


## Ejecuta el combate y devuelve { winner: Adalid|null, loser, rounds, damage, tie }.
func run() -> Dictionary:
	log_line("=== Combate: %s vs %s ===" % [sides[0].owner.display_name, sides[1].owner.display_name])
	_start_of_combat()
	while round_no < Rules.MAX_ROUNDS and not _someone_wiped():
		round_no += 1
		_play_round()
	return _finish()


func log_line(line: String) -> void:
	log.append(line)


func enemy_of(side: int) -> Battlefield:
	return sides[1 - side]


# ---------------------------------------------------------------- inicio

func _start_of_combat() -> void:
	for i in 2:
		var s := sides[i]
		var owner := s.owner.display_name
		var asesino := s.synergy(Rules.ClassType.ASESINO)
		var protector := s.synergy(Rules.ClassType.PROTECTOR)
		for ch in s.alive():
			if ch.data.has_class(Rules.ClassType.ASESINO) and asesino >= 3:
				ch.stealth = true # Asesino (3): todos comienzan en sigilo.
			if ch.data.has_class(Rules.ClassType.ASESINO) and asesino >= 5:
				ch.extra_attack += 2 # Asesino (5): +2 de daño.
			if ch.data.has_class(Rules.ClassType.PROTECTOR) and protector >= 5:
				ch.extra_defense += 5 # Protector (5): +5 de vida.
				ch.defense_left += 5
			if Abilities.starts_in_stealth(ch):
				ch.stealth = true
				ch.permanent_stealth = true
		# Ángel (3)/(5): el adalid gana vida al comenzar la batalla.
		var angel := s.synergy(Rules.ClassType.BIEN)
		if angel >= 5:
			s.owner.gain_vitality(2)
		elif angel >= 3:
			s.owner.gain_vitality(1)
		if angel > 0:
			log_line("%s gana vida por sinergia Ángel (%d)." % [owner, angel])
		# Aire (5)/(7): al comenzar, lanza un DP enemigo y exilia a quien esté ahí.
		if s.synergy(Rules.ClassType.AIRE) >= 5:
			var exiled := enemy_of(i).champion_at(Dice.roll(rng) - 1)
			if exiled != null and exiled.alive:
				exiled.take_damage(exiled.defense_left)
				log_line("El viento de %s exilia a %s de la batalla." % [owner, exiled.data.display_name])
		var active := s.synergies.keys()
		if not active.is_empty():
			var parts: PackedStringArray = []
			for c in active:
				parts.append("%s (%d)" % [Rules.class_label(c), s.synergies[c]])
			log_line("Sinergias de %s: %s" % [owner, ", ".join(parts)])
	for s in sides:
		s.remove_dead()


# ---------------------------------------------------------------- asaltos

func _play_round() -> void:
	log_line("--- Asalto %d ---" % round_no)
	for i in 2:
		for ch in sides[i].alive():
			ch.reset_round_flags()
			if ch.frozen_turns > 0:
				ch.frozen_turns -= 1
				if ch.frozen_turns == 0:
					ch.frozen = false
		_electric_charges(i)

	var actions: Array[Dictionary] = []
	for i in 2:
		actions.append_array(_declare_actions(i))

	# Las defensivas se marcan antes de resolver daño: en la mesa todas las
	# acciones se revelan a la vez, así que un BLOCK/ESQ protege en este asalto.
	_resolve_phase(actions, Rules.Phase.MOVIMIENTO)
	_resolve_phase(actions, Rules.Phase.DEFENSIVA)
	_resolve_phase(actions, Rules.Phase.OFENSIVA)
	_resolve_phase(actions, Rules.Phase.ESPECIAL)

	_bury_dead()
	for s in sides:
		log_line("%s: %s" % [s.owner.display_name, " | ".join(s.describe())])


## Eléctrico (3)/(5)/(7): antes del asalto, lanza DA y pone cargas por acierto.
func _electric_charges(side: int) -> void:
	var board := sides[side]
	var t := board.synergy(Rules.ClassType.ELECTRICO)
	if t == 0:
		return
	var count := 2 if t == 3 else (3 if t == 5 else 5)
	var electrics: Array[Champion] = []
	for ch in board.alive():
		if ch.data.has_class(Rules.ClassType.ELECTRICO):
			electrics.append(ch)
	if electrics.is_empty():
		return
	for r in Dice.roll_many(rng, count):
		if Dice.is_hit(r):
			var best: Champion = electrics[0]
			for ch in electrics:
				if ch.attack() > best.attack():
					best = ch
			best.charges += 1
			best.defense_left += 1
			log_line("  Carga +1/+1 en %s." % best.data.display_name)
		elif Dice.classify(r) == Dice.Result.PIFIA:
			for ch in electrics:
				if ch.charges > 0:
					ch.charges -= 1
					log_line("  Pifia: %s pierde una carga." % ch.data.display_name)
					break


## Lanza DA y DP del lado `side` y devuelve las acciones emparejadas.
func _declare_actions(side: int) -> Array[Dictionary]:
	var board := sides[side]
	var enemy := enemy_of(side)
	var dice_count := Rules.BASE_ACTION_DICE + _mago_bonus(board)
	if enemy.synergy(Rules.ClassType.ROBOT) >= 5:
		dice_count = maxi(dice_count - 1, 1) # Robot (5): el enemigo juega con un DA menos.
	var da := Dice.roll_many(rng, dice_count)
	# Robot (3): puede volver a lanzar los dados de asalto. IA: si ninguno acierta.
	if board.synergy(Rules.ClassType.ROBOT) >= 3 and enemy.synergy(Rules.ClassType.ROBOT) < 5 \
			and Dice.count_hits(da) == 0:
		da = Dice.roll_many(rng, dice_count)
		log_line("%s vuelve a lanzar sus DA (Robot)." % board.owner.display_name)
	var dp := Dice.roll_many(rng, dice_count)
	da.sort()
	da.reverse() # Usamos primero los DA más altos.
	log_line("%s lanza DA %s y DP %s" % [board.owner.display_name, da, dp])

	var actions: Array[Dictionary] = []
	for p in dp:
		var slot := p - 1
		var ch := board.champion_at(slot)
		if ch == null or not ch.alive:
			continue
		if ch.frozen and ch.frozen_turns == 0:
			ch.frozen = false # Gastar un DP en esa posición descongela.
			log_line("  %s se descongela." % ch.data.display_name)
			continue
		if ch.frozen:
			continue
		if da.is_empty():
			break
		var value: int = da.pop_front()
		# Protector (3)/(5): los DA usados en protectores suben 1 o 2 (máx. 6).
		if ch.data.has_class(Rules.ClassType.PROTECTOR):
			var prot := board.synergy(Rules.ClassType.PROTECTOR)
			if prot >= 5:
				value = mini(value + 2, Rules.DICE_SIDES)
			elif prot >= 3:
				value = mini(value + 1, Rules.DICE_SIDES)
		var names: PackedStringArray = []
		for kw in ch.data.keywords_for(value):
			actions.append({ "side": side, "champion": ch, "slot": slot, "keyword": kw, "roll": value })
			names.append(Rules.keyword_label(kw))
		log_line("  DP %d + DA %d → %s: %s" % [p, value, ch.data.display_name,
			"sin acción" if names.is_empty() else " + ".join(names)])
	return actions


func _mago_bonus(board: Battlefield) -> int:
	# Mago (3): un DA más; Mago (5): otro más. SUPUESTO: acumulativo.
	var t := board.synergy(Rules.ClassType.MAGO)
	if t >= 5:
		return 2
	if t >= 3:
		return 1
	return 0


func _resolve_phase(actions: Array[Dictionary], phase: Rules.Phase) -> void:
	var mine: Array[Dictionary] = []
	for a in actions:
		if Rules.KEYWORD_PHASE[a["keyword"]] == phase and a["champion"].alive:
			mine.append(a)
	if mine.is_empty():
		return
	if phase == Rules.Phase.MOVIMIENTO:
		_resolve_moves(mine)
		return
	for a in mine:
		if not a["champion"].alive:
			continue
		match a["keyword"]:
			Rules.Keyword.BLOCK: _do_block(a)
			Rules.Keyword.ESQ: _do_dodge(a)
			Rules.Keyword.ATK: do_attack(a)
			Rules.Keyword.ANIQUILA: _do_annihilate(a)
			Rules.Keyword.CONG: _do_freeze(a)
			Rules.Keyword.PRO: _do_produce(a)
			Rules.Keyword.CUR: _do_heal(a)
			Rules.Keyword.SPEC: Abilities.spec(self, a)


# ---------------------------------------------------------------- movimiento

## Todos los movimientos son simultáneos; si dos chocan, ninguno se hace.
func _resolve_moves(moves: Array[Dictionary]) -> void:
	var planned: Array[Dictionary] = []
	for a in moves:
		var board: Battlefield = sides[a["side"]]
		var from: int = board.index_of(a["champion"])
		if from < 0:
			continue
		var to := _choose_move_target(board, from)
		if to < 0:
			continue
		planned.append({ "board": board, "from": from, "to": to, "champion": a["champion"] })

	var touched := {}
	for m in planned:
		for key in [[m["board"], m["from"]], [m["board"], m["to"]]]:
			touched[key] = touched.get(key, 0) + 1
	for m in planned:
		var board: Battlefield = m["board"]
		if touched[[board, m["from"]]] > 1 or touched[[board, m["to"]]] > 1:
			log_line("  %s no se mueve: conflicto de movimiento." % m["champion"].data.display_name)
			continue
		var other: Champion = board.champion_at(m["to"])
		if other != null and other.frozen:
			log_line("  %s no se mueve: aliado congelado." % m["champion"].data.display_name)
			continue
		board.slots[m["to"]] = m["champion"]
		board.slots[m["from"]] = other
		log_line("  %s se mueve de %d a %d%s." % [m["champion"].data.display_name, m["from"] + 1, m["to"] + 1,
			"" if other == null else " (intercambia con %s)" % other.data.display_name])


## IA: prefiere una casilla vacía adyacente; si no hay, intercambia con un aliado.
func _choose_move_target(board: Battlefield, from: int) -> int:
	var options := board.adjacent_own(from)
	for i in options:
		if board.champion_at(i) == null:
			return i
	if options.is_empty():
		return -1
	return options[rng.randi_range(0, options.size() - 1)]


# ---------------------------------------------------------------- defensa

func _do_block(a: Dictionary) -> void:
	var board: Battlefield = sides[a["side"]]
	var blocker: Champion = a["champion"]
	var from := board.index_of(blocker)
	var protected: Champion = null
	for i in board.adjacent_own(from):
		var ally := board.champion_at(i)
		if ally != null and ally.alive and (protected == null or ally.defense_left < protected.defense_left):
			protected = ally
	if protected == null:
		log_line("  %s bloquea, pero no tiene aliados adyacentes." % blocker.data.display_name)
		return
	protected.blocked_by = blocker
	log_line("  %s bloquea por %s." % [blocker.data.display_name, protected.data.display_name])


func _do_dodge(a: Dictionary) -> void:
	a["champion"].dodging = true
	log_line("  %s esquiva este asalto." % a["champion"].data.display_name)


# ---------------------------------------------------------------- ofensiva

func do_attack(a: Dictionary) -> void:
	var attacker: Champion = a["champion"]
	var board: Battlefield = sides[a["side"]]
	var enemy: Battlefield = enemy_of(a["side"])
	var target := choose_target(attacker, board, enemy, attacker.data.reach)
	if target == null:
		log_line("  %s ataca al vacío." % attacker.data.display_name)
		return
	var damage := attacker.attack()
	var left_stealth := attacker.stealth and not attacker.permanent_stealth
	if left_stealth:
		attacker.stealth = false
	deal_damage(attacker, board, target, enemy, damage, "ataca")
	# Asesino (5): al salir de sigilo, lanza un DA; acierto → vuelve a sigilo.
	if left_stealth and board.synergy(Rules.ClassType.ASESINO) >= 5 and Dice.is_hit(Dice.roll(rng)):
		attacker.stealth = true
		log_line("  %s vuelve a las sombras." % attacker.data.display_name)
	# Hielo (5): un hielo que ataca a un congelado con ataque directo lo mata.
	if target.alive and target.frozen and attacker.data.has_class(Rules.ClassType.HIELO) \
			and board.synergy(Rules.ClassType.HIELO) >= 5:
		target.take_damage(target.defense_left, attacker)
		log_line("  %s destroza a %s, que estaba congelado." % [attacker.data.display_name, target.data.display_name])
	_fire_dice(attacker, board, target, enemy)


## Fuego (3)/(5)/(7): tras hacer daño, lanza DF igual al ataque.
func _fire_dice(attacker: Champion, board: Battlefield, target: Champion, enemy: Battlefield) -> void:
	var t := board.synergy(Rules.ClassType.FUEGO)
	if t == 0 or not attacker.data.has_class(Rules.ClassType.FUEGO):
		return
	var side := sides.find(board)
	for r in Dice.roll_many(rng, attacker.attack()):
		var res := Dice.classify(r)
		if res == Dice.Result.CRITICO:
			enemy.owner.lose_vitality(1)
			log_line("  Crítico de fuego: %s pierde 1 de vitalidad." % enemy.owner.display_name)
		elif res == Dice.Result.PIFIA:
			fire_fumbles[side] += 1
			if fire_fumbles[side] >= 2:
				fire_fumbles[side] = 0
				board.owner.lose_vitality(1)
				log_line("  Dos pifias de fuego: %s pierde 1 de vitalidad." % board.owner.display_name)
		elif t >= 5 and res == Dice.Result.ACIERTO:
			var ti := enemy.index_of(target)
			for i in enemy.adjacent_enemy(ti) if t >= 7 else [ti - 1, ti + 1]:
				var other := enemy.champion_at(i)
				if other != null and other.alive and other != target:
					direct_damage(attacker, other, 1, "Fuego (área)")


func _do_annihilate(a: Dictionary) -> void:
	var attacker: Champion = a["champion"]
	var board: Battlefield = sides[a["side"]]
	var enemy: Battlefield = enemy_of(a["side"])
	var target := choose_target(attacker, board, enemy, attacker.data.reach)
	if target == null:
		return
	# No puede ser bloqueado ni esquivado: va a la baraja del demiurgo.
	target.take_damage(target.defense_left, attacker)
	target.annihilated = true
	log_line("  %s ANIQUILA a %s." % [attacker.data.display_name, target.data.display_name])
	if attacker.data.id == &"senor_demonio":
		attacker.take_damage(attacker.defense_left, attacker)
		attacker.annihilated = true
		log_line("  El Señor demonio se lleva a su víctima al infierno y se descarta.")


## Objetivo según alcance (README: ATK). IA: el enemigo con menos vida.
func choose_target(attacker: Champion, board: Battlefield, enemy: Battlefield, reach: Rules.Reach) -> Champion:
	var from := board.index_of(attacker)
	var candidates: Array[int] = []
	match reach:
		Rules.Reach.CUERPO_A_CUERPO:
			candidates = enemy.adjacent_enemy(from)
		Rules.Reach.EMBOSCADOR:
			candidates = [enemy.opposite(from)]
		Rules.Reach.RANGO:
			for i in Rules.BOARD_SIZE:
				candidates.append(i)
	var best: Champion = null
	for i in candidates:
		var ch := enemy.champion_at(i)
		if ch != null and ch.alive and (best == null or ch.defense_left < best.defense_left):
			best = ch
	return best


## Daño que no se puede bloquear, esquivar ni reducir (habilidades, área, venganza).
func direct_damage(source: Champion, target: Champion, amount: int, label: String) -> int:
	if amount <= 0 or not target.alive:
		return 0
	var dealt := target.take_damage(amount, source)
	log_line("  %s: %d de daño a %s." % [label, dealt, target.data.display_name])
	return dealt


func deal_damage(attacker: Champion, board: Battlefield, target: Champion, enemy: Battlefield,
		damage: int, verb: String) -> void:
	# ESQ
	if target.dodging:
		log_line("  %s %s a %s, pero este esquiva." % [attacker.data.display_name, verb, target.data.display_name])
		return
	# Aire (3)/(5)/(7) y pasivas de carta: tirada para esquivar.
	if (target.data.has_class(Rules.ClassType.AIRE) and _air_dodges(enemy)) \
			or Abilities.passive_dodge(target, rng):
		log_line("  %s %s a %s, pero el aire esquiva." % [attacker.data.display_name, verb, target.data.display_name])
		# Aire (7): cada crítico en DR contraataca. SUPUESTO: una tirada.
		if enemy.synergy(Rules.ClassType.AIRE) >= 7 and Dice.roll(rng) == Rules.CRITICO:
			direct_damage(target, attacker, target.attack(), "Contraataque de aire")
		return
	# Salvaje (3)/(5): un DS puede potenciar o atenuar el daño.
	damage += _wild_bonus(attacker, board, 1) - _wild_bonus(target, enemy, 1)
	# Tierra (5)/(7): reducción de daño. Pasivas de carta (gigantes): 2 menos.
	var tierra := enemy.synergy(Rules.ClassType.TIERRA)
	if tierra >= 7:
		damage -= 3
	elif tierra >= 5:
		damage -= 1
	damage = maxi(damage - Abilities.damage_reduction(target), 0)
	# BLOCK: el bloqueador recibe el daño; el exceso pasa al protegido.
	var receiver := target
	if target.blocked_by != null and target.blocked_by.alive:
		receiver = target.blocked_by
		var prot := enemy.synergy(Rules.ClassType.PROTECTOR)
		if prot >= 3 and receiver.data.has_class(Rules.ClassType.PROTECTOR):
			direct_damage(receiver, attacker, receiver.attack(), "Represalia de %s" % receiver.data.display_name)
		if prot >= 5 and receiver.data.has_class(Rules.ClassType.PROTECTOR):
			damage = 0 # Protector (5): el bloqueador no recibe el daño.
	var dealt := receiver.take_damage(damage, attacker)
	var overflow := damage - dealt
	log_line("  %s %s a %s: %d de daño%s." % [attacker.data.display_name, verb, receiver.data.display_name, dealt,
		"" if receiver == target else " (bloqueando por %s)" % target.data.display_name])
	if receiver != target and not receiver.alive and overflow > 0:
		target.take_damage(overflow, attacker)
		log_line("  El exceso (%d) pasa a %s." % [overflow, target.data.display_name])
	if dealt > 0:
		Abilities.on_damaged(self, receiver, attacker)
	# Hielo (3): al recibir daño, lanza 1 DA; si acierta, congela al agresor.
	if dealt > 0 and receiver.data.has_class(Rules.ClassType.HIELO) and enemy.synergy(Rules.ClassType.HIELO) >= 3:
		if Dice.is_hit(Dice.roll(rng)):
			attacker.frozen = true
			log_line("  %s queda congelado por el hielo." % attacker.data.display_name)


func _wild_bonus(ch: Champion, board: Battlefield, _unused: int) -> int:
	var t := board.synergy(Rules.ClassType.SALVAJE)
	if t == 0 or not ch.data.has_class(Rules.ClassType.SALVAJE):
		return 0
	if Dice.is_hit(Dice.roll(rng)):
		return 2 if t >= 5 else 1
	return 0


func _air_dodges(board: Battlefield) -> bool:
	var t := board.synergy(Rules.ClassType.AIRE)
	if t >= 7:
		return Dice.count_hits(Dice.roll_many(rng, 2)) >= 1
	if t >= 5:
		return Dice.count_hits(Dice.roll_many(rng, 1)) >= 1
	if t >= 3:
		return Dice.count_hits(Dice.roll_many(rng, 2)) >= 2
	return false


# ---------------------------------------------------------------- especiales

func _do_freeze(a: Dictionary) -> void:
	var attacker: Champion = a["champion"]
	var target := choose_target(attacker, sides[a["side"]], enemy_of(a["side"]), attacker.data.reach)
	if target == null:
		return
	target.frozen = true
	log_line("  %s congela a %s." % [attacker.data.display_name, target.data.display_name])


func _do_produce(a: Dictionary) -> void:
	# SUPUESTO: PRO sin cantidad produce 1 de Éter. Robot (3) x2, Robot (5) x3.
	var board: Battlefield = sides[a["side"]]
	var amount := 1
	var robot := board.synergy(Rules.ClassType.ROBOT)
	if robot >= 5:
		amount *= 3
	elif robot >= 3:
		amount *= 2
	board.owner.add_eter(amount)
	log_line("  %s produce %d de Éter." % [a["champion"].data.display_name, amount])


func _do_heal(a: Dictionary) -> void:
	# SUPUESTO: CUR sin valor cura 1. IA: cura al aliado más herido.
	var board: Battlefield = sides[a["side"]]
	var target: Champion = null
	for ch in board.alive():
		if ch.defense_left < ch.max_defense() and (target == null or ch.defense_left < target.defense_left):
			target = ch
	if target == null:
		return
	target.heal(1)
	log_line("  %s cura 1 a %s." % [a["champion"].data.display_name, target.data.display_name])


# ---------------------------------------------------------------- muertes

## Retira a los muertos y dispara lo que ocurre al morir (sinergias y cartas).
func _bury_dead() -> void:
	var any := true
	while any:
		any = false
		for i in 2:
			var board := sides[i]
			var enemy := enemy_of(i)
			for ch in board.remove_dead():
				any = true
				log_line("%s cae en combate." % ch.data.display_name)
				Abilities.on_death(self, ch, board, enemy)
				_demon_death(ch, board, enemy)
				_angel_vengeance(ch, board, enemy)


## Demonio (5): al salir del combate, lanza un DP y hace su daño al enemigo ahí.
func _demon_death(dead: Champion, board: Battlefield, enemy: Battlefield) -> void:
	if not dead.data.has_class(Rules.ClassType.MAL) or board.synergy(Rules.ClassType.MAL) < 5:
		return
	var other := enemy.champion_at(Dice.roll(rng) - 1)
	if other != null and other.alive:
		direct_damage(dead, other, dead.attack(), "Último aliento de %s" % dead.data.display_name)


## Ángel (3)/(5): al morir un ángel, lanza tantos DD como ángeles; cada acierto
## es un daño directo de venganza a quien lo mató.
func _angel_vengeance(dead: Champion, board: Battlefield, enemy: Battlefield) -> void:
	var t := board.synergy(Rules.ClassType.BIEN)
	if not dead.data.has_class(Rules.ClassType.BIEN) or t < 3:
		return
	var angels := 1
	for ch in board.alive():
		if ch.data.has_class(Rules.ClassType.BIEN):
			angels += 1
	var hits := 0
	for r in Dice.roll_many(rng, angels):
		if Dice.is_hit(r):
			hits += 1
		if t >= 5 and r == Rules.CRITICO:
			board.owner.gain_vitality(1)
	if hits == 0:
		return
	if dead.killer != null and dead.killer.alive and dead.killer != dead:
		direct_damage(dead, dead.killer, hits, "Venganza angelical")
		if not dead.killer.alive and t >= 5 and board.owner.vitality > 2:
			board.owner.lose_vitality(2)
			dead.annihilated = false
			dead.reset_for_combat()
			var slot := board.slots.find(null)
			if slot >= 0:
				board.place(dead, slot)
				log_line("  %s revive pagando 2 de vida." % dead.data.display_name)
	else:
		enemy.owner.lose_vitality(hits)
		log_line("  Venganza angelical: %s pierde %d de vitalidad." % [enemy.owner.display_name, hits])


# ---------------------------------------------------------------- final

func _someone_wiped() -> bool:
	return sides[0].alive_count() == 0 or sides[1].alive_count() == 0


func _finish() -> Dictionary:
	var a := sides[0]
	var b := sides[1]
	var result := { "rounds": round_no, "winner": null, "loser": null, "damage": 0, "tie": false }
	for s in sides:
		Abilities.on_combat_end(self, s)
		for ch in s.slots:
			if ch != null:
				ch.reset_round_flags() # Rompe las referencias cruzadas entre campeones.
				ch.killer = null
	if a.alive_count() == b.alive_count():
		result["tie"] = true
		for s in sides:
			s.owner.streak = 0
			s.owner.lose_vitality(Rules.TIE_VITALITY_LOSS)
		log_line("Empate: ambos pierden la racha y %d de vida." % Rules.TIE_VITALITY_LOSS)
		return result
	var winner := a if a.alive_count() > b.alive_count() else b
	var loser := b if winner == a else a
	var damage := maxi(winner.strength() - loser.strength(), 0) + 1
	# Tierra (3)/(7): al perder, el adalid recibe 1 o 2 menos de daño.
	var tierra := loser.synergy(Rules.ClassType.TIERRA)
	if tierra >= 7:
		damage = maxi(damage - 2, 0)
	elif tierra >= 3:
		damage = maxi(damage - 1, 0)
	if loser.owner.poisoned:
		damage += 1 # Veneno: 1 de vida adicional al perder.
	Economy.reward_winner(winner.owner)
	Economy.punish_loser(loser.owner, damage)
	result["winner"] = winner.owner
	result["loser"] = loser.owner
	result["damage"] = damage
	log_line("Gana %s. %s pierde %d de vitalidad (queda %d). %s recibe %d de Éter." % [
		winner.owner.display_name, loser.owner.display_name, damage, loser.owner.vitality,
		winner.owner.display_name, Rules.WIN_REWARD])
	return result
