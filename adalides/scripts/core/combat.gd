class_name Combat
extends RefCounted
## Simula un combate completo entre dos adalides siguiendo README: "Combate".
## Las decisiones (qué DA emparejar con qué DP, a quién atacar, hacia dónde mover)
## las toma una IA simple; la lógica está separada para poder sustituirla por
## la elección del jugador más adelante.

const PHASE_NAMES := {
	Rules.Phase.MOVIMIENTO: "Movimiento",
	Rules.Phase.OFENSIVA: "Ofensiva",
	Rules.Phase.DEFENSIVA: "Defensiva",
	Rules.Phase.ESPECIAL: "Especial",
}

var sides: Array[Battlefield] = []
var rng: RandomNumberGenerator
var log: PackedStringArray = []
var round_no: int = 0


func _init(a: Battlefield, b: Battlefield, p_rng: RandomNumberGenerator = null) -> void:
	sides = [a, b]
	rng = p_rng if p_rng != null else RandomNumberGenerator.new()


## Ejecuta el combate y devuelve { winner: Adalid|null, loser, rounds, damage, tie }.
func run() -> Dictionary:
	_log("=== Combate: %s vs %s ===" % [sides[0].owner.display_name, sides[1].owner.display_name])
	_start_of_combat()
	while round_no < Rules.MAX_ROUNDS and not _someone_wiped():
		round_no += 1
		_play_round()
	return _finish()


# ---------------------------------------------------------------- asaltos

func _start_of_combat() -> void:
	for s in sides:
		# Asesino (3): todos los asesinos comienzan en sigilo.
		if s.synergy(Rules.ClassType.ASESINO) >= 3:
			for ch in s.alive():
				if ch.data.has_class(Rules.ClassType.ASESINO):
					ch.stealth = true
		# Ángel (3)/(5): el adalid gana vida al comenzar la batalla.
		var angel := s.synergy(Rules.ClassType.BIEN)
		if angel >= 5:
			s.owner.gain_vitality(2)
		elif angel >= 3:
			s.owner.gain_vitality(1)
		if angel > 0:
			_log("%s gana vida por sinergia Ángel (%d)." % [s.owner.display_name, angel])


func _play_round() -> void:
	_log("--- Asalto %d ---" % round_no)
	for s in sides:
		for ch in s.alive():
			ch.reset_round_flags()

	var actions: Array[Dictionary] = []
	for i in 2:
		actions.append_array(_declare_actions(i))

	# Las defensivas se marcan antes de resolver daño: en la mesa todas las
	# acciones se revelan a la vez, así que un BLOCK/ESQ protege en este asalto.
	_resolve_phase(actions, Rules.Phase.MOVIMIENTO)
	_resolve_phase(actions, Rules.Phase.DEFENSIVA)
	_resolve_phase(actions, Rules.Phase.OFENSIVA)
	_resolve_phase(actions, Rules.Phase.ESPECIAL)

	for s in sides:
		for ch in s.remove_dead():
			_log("%s cae en combate." % ch.data.display_name)
	for s in sides:
		_log("%s: %s" % [s.owner.display_name, " | ".join(s.describe())])


## Lanza DA y DP del lado `side` y devuelve las acciones emparejadas.
func _declare_actions(side: int) -> Array[Dictionary]:
	var board := sides[side]
	var dice_count := Rules.BASE_ACTION_DICE + _mago_bonus(board)
	var da := Dice.roll_many(rng, dice_count)
	var dp := Dice.roll_many(rng, dice_count)
	da.sort()
	da.reverse() # Usamos primero los DA más altos.
	_log("%s lanza DA %s y DP %s" % [board.owner.display_name, da, dp])

	var actions: Array[Dictionary] = []
	for p in dp:
		var slot := p - 1
		var ch := board.champion_at(slot)
		if ch == null or not ch.alive:
			continue
		if ch.frozen:
			ch.frozen = false # Gastar un DP en esa posición descongela.
			_log("%s se descongela." % ch.data.display_name)
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
		for kw in ch.data.keywords_for(value):
			actions.append({ "side": side, "champion": ch, "slot": slot, "keyword": kw, "roll": value })
		var names: PackedStringArray = []
		for kw in ch.data.keywords_for(value):
			names.append(Rules.keyword_label(kw))
		_log("  DP %d + DA %d → %s: %s" % [p, value, ch.data.display_name,
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
		match a["keyword"]:
			Rules.Keyword.BLOCK: _do_block(a)
			Rules.Keyword.ESQ: _do_dodge(a)
			Rules.Keyword.ATK: _do_attack(a)
			Rules.Keyword.ANIQUILA: _do_annihilate(a)
			Rules.Keyword.CONG: _do_freeze(a)
			Rules.Keyword.PRO: _do_produce(a)
			Rules.Keyword.CUR: _do_heal(a)
			Rules.Keyword.SPEC: _log("  %s: SPEC (habilidad del cuadernillo, no implementada)." % a["champion"].data.display_name)


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
			_log("  %s no se mueve: conflicto de movimiento." % m["champion"].data.display_name)
			continue
		var other: Champion = board.champion_at(m["to"])
		if other != null and other.frozen:
			_log("  %s no se mueve: aliado congelado." % m["champion"].data.display_name)
			continue
		board.slots[m["to"]] = m["champion"]
		board.slots[m["from"]] = other
		_log("  %s se mueve de %d a %d%s." % [m["champion"].data.display_name, m["from"] + 1, m["to"] + 1,
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
		_log("  %s bloquea, pero no tiene aliados adyacentes." % blocker.data.display_name)
		return
	protected.blocked_by = blocker
	_log("  %s bloquea por %s." % [blocker.data.display_name, protected.data.display_name])


func _do_dodge(a: Dictionary) -> void:
	a["champion"].dodging = true
	_log("  %s esquiva este asalto." % a["champion"].data.display_name)


# ---------------------------------------------------------------- ofensiva

func _do_attack(a: Dictionary) -> void:
	var attacker: Champion = a["champion"]
	var board: Battlefield = sides[a["side"]]
	var enemy: Battlefield = sides[1 - a["side"]]
	var target := _choose_target(attacker, board, enemy)
	if target == null:
		_log("  %s ataca al vacío." % attacker.data.display_name)
		return
	var damage := attacker.attack()
	if attacker.stealth:
		attacker.stealth = false
	_deal_damage(attacker, board, target, enemy, damage, "ataca")


func _do_annihilate(a: Dictionary) -> void:
	var attacker: Champion = a["champion"]
	var board: Battlefield = sides[a["side"]]
	var enemy: Battlefield = sides[1 - a["side"]]
	var target := _choose_target(attacker, board, enemy)
	if target == null:
		return
	# No puede ser bloqueado ni esquivado: va a la baraja del demiurgo.
	target.defense_left = 0
	target.alive = false
	_log("  %s ANIQUILA a %s." % [attacker.data.display_name, target.data.display_name])


## Objetivo según alcance (README: ATK). IA: el enemigo con menos vida.
func _choose_target(attacker: Champion, board: Battlefield, enemy: Battlefield) -> Champion:
	var from := board.index_of(attacker)
	var candidates: Array[int] = []
	match attacker.data.range:
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


func _deal_damage(attacker: Champion, board: Battlefield, target: Champion, enemy: Battlefield,
		damage: int, verb: String) -> void:
	# ESQ
	if target.dodging:
		_log("  %s %s a %s, pero este esquiva." % [attacker.data.display_name, verb, target.data.display_name])
		return
	# Aire (3)/(5)/(7): tirada para esquivar.
	if target.data.has_class(Rules.ClassType.AIRE) and _air_dodges(enemy):
		_log("  %s %s a %s, pero el aire esquiva." % [attacker.data.display_name, verb, target.data.display_name])
		return
	# Tierra (5)/(7): reducción de daño.
	var tierra := enemy.synergy(Rules.ClassType.TIERRA)
	if tierra >= 7:
		damage = maxi(damage - 3, 0)
	elif tierra >= 5:
		damage = maxi(damage - 1, 0)
	# BLOCK: el bloqueador recibe el daño; el exceso pasa al protegido.
	var receiver := target
	if target.blocked_by != null and target.blocked_by.alive:
		receiver = target.blocked_by
		var prot := enemy.synergy(Rules.ClassType.PROTECTOR)
		if prot >= 5 and receiver.data.has_class(Rules.ClassType.PROTECTOR):
			damage = 0 # Protector (5): el bloqueador no recibe el daño.
		if prot >= 3 and receiver.data.has_class(Rules.ClassType.PROTECTOR):
			attacker.take_damage(receiver.attack()) # Protector (3): devuelve su daño.
	var dealt := receiver.take_damage(damage)
	var overflow := damage - dealt
	_log("  %s %s a %s: %d de daño%s." % [attacker.data.display_name, verb, receiver.data.display_name, dealt,
		"" if receiver == target else " (bloqueando por %s)" % target.data.display_name])
	if receiver != target and not receiver.alive and overflow > 0:
		target.take_damage(overflow)
		_log("  El exceso (%d) pasa a %s." % [overflow, target.data.display_name])
	# Hielo (3): al recibir daño, lanza 1 DA; si acierta, congela al agresor.
	if target.data.has_class(Rules.ClassType.HIELO) and enemy.synergy(Rules.ClassType.HIELO) >= 3:
		if Dice.is_hit(Dice.roll(rng)):
			attacker.frozen = true
			_log("  %s queda congelado por el hielo." % attacker.data.display_name)


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
	var target := _choose_target(attacker, sides[a["side"]], sides[1 - a["side"]])
	if target == null:
		return
	target.frozen = true
	_log("  %s congela a %s." % [attacker.data.display_name, target.data.display_name])


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
	_log("  %s produce %d de Éter." % [a["champion"].data.display_name, amount])


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
	_log("  %s cura 1 a %s." % [a["champion"].data.display_name, target.data.display_name])


# ---------------------------------------------------------------- final

func _someone_wiped() -> bool:
	return sides[0].alive_count() == 0 or sides[1].alive_count() == 0


func _finish() -> Dictionary:
	var a := sides[0]
	var b := sides[1]
	var result := { "rounds": round_no, "winner": null, "loser": null, "damage": 0, "tie": false }
	if a.alive_count() == b.alive_count():
		result["tie"] = true
		for s in sides:
			s.owner.streak = 0
			s.owner.lose_vitality(Rules.TIE_VITALITY_LOSS)
		_log("Empate: ambos pierden la racha y %d de vida." % Rules.TIE_VITALITY_LOSS)
		return result
	var winner := a if a.alive_count() > b.alive_count() else b
	var loser := b if winner == a else a
	var damage := maxi(winner.strength() - loser.strength(), 0) + 1
	Economy.reward_winner(winner.owner)
	Economy.punish_loser(loser.owner, damage)
	result["winner"] = winner.owner
	result["loser"] = loser.owner
	result["damage"] = damage
	_log("Gana %s. %s pierde %d de vitalidad (queda %d). %s recibe %d de Éter." % [
		winner.owner.display_name, loser.owner.display_name, damage, loser.owner.vitality,
		winner.owner.display_name, Rules.WIN_REWARD])
	return result


func _log(line: String) -> void:
	log.append(line)
