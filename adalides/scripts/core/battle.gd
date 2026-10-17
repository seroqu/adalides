class_name Battle
extends RefCounted
## Una batalla v2: 4 asaltos con fases HI → M → HR → A → H → HF. Los campeones
## se mueven y atacan solos según las prioridades del PDF; los dados del adalid
## activan los poderes de sus campeones. La asignación de dados la hace una IA
## (`auto_assign`) o el jugador (`commit_round` con su asignación).

const E := Rules.Element
const A := Rules.Archetype
const D := Rules.Die
const P := Rules.Phase

var board: Board
var rng: RandomNumberGenerator
var log: PackedStringArray = []
var round_no: int = 0
var max_rounds: int = Rules.ROUNDS_PER_BATTLE # 0 = hasta que un bando se quede sin campeones.
var squad_size: Array[int] = [0, 0] # Campeones con los que empezó cada lado.
var battle_number: int = 1 # Batallas realizadas hasta ahora (incluida esta).
var adalids: Array[Adalid] = []
var elem_tiers: Array[Dictionary] = [{}, {}]
var arch_tiers: Array[Dictionary] = [{}, {}]
var dice: Array = [[], []] # Caras de d3 (−1/0/+1) lanzadas este asalto por lado.
## Eventos del asalto en curso, para animarlos: { "type": ..., ... }.
var events: Array[Dictionary] = []
var eter_produced: Array[int] = [0, 0]
var faith_dice: Array = [[], []] # Pacto de fe: campeones con dado de fe.
var started := false
var finished := false
var result: Dictionary = {}
## Efectos para que Game los aplique fuera de la batalla (Tatuko, Venganza).
var aftermath: Array[Dictionary] = []


## `lineups[i]` = Dictionary { Vector2i(col, row 1..3) : Champion } del lado i.
func _init(a: Adalid, b: Adalid, lineups: Array, p_rng: RandomNumberGenerator, p_battle_number := 1) -> void:
	adalids = [a, b]
	rng = p_rng
	battle_number = p_battle_number
	board = Board.new(a, b)
	for side in 2:
		var lineup: Dictionary = lineups[side]
		squad_size[side] = lineup.size()
		for key in lineup:
			var ch: Champion = lineup[key]
			ch.reset_for_battle()
			board.place(ch, Board.pos_from(side, key.y, key.x))
		var mine := board.champions(side)
		elem_tiers[side] = Tiers.elements(mine)
		arch_tiers[side] = Tiers.archetypes(mine)


func log_line(line: String) -> void:
	log.append(line)


func ev(data: Dictionary) -> void:
	events.append(data)


func etier(side: int, e: int) -> int:
	return elem_tiers[side].get(e, 0)


func atier(side: int, a: int) -> int:
	return arch_tiers[side].get(a, 0)


## Valor escalonado por tier: Tiers.scaled(tier, [a, b, c]).
func esc(side: int, e: int, values: Array) -> int:
	return Tiers.scaled(etier(side, e), values)


func asc(side: int, a: int, values: Array) -> int:
	return Tiers.scaled(atier(side, a), values)


# ---------------------------------------------------------------- flujo

func run() -> Dictionary:
	start()
	while begin_round():
		commit_round([auto_assign(0), auto_assign(1)])
	return finish()


func start() -> void:
	if started:
		return
	started = true
	log_line("=== Batalla %d: %s vs %s ===" % [battle_number, adalids[0].display_name, adalids[1].display_name])
	for side in 2:
		var t := Tiers.describe(board.champions(side))
		if t != "":
			log_line("Tiers de %s: %s" % [adalids[side].display_name, t])
		_start_effects(side)


func _start_effects(side: int) -> void:
	var mine := board.champions(side)
	# Arquero: Disparo certero +(1/2/4) de ataque.
	var certero := asc(side, A.ARQUERO, [1, 2, 4])
	# Defensor: Unidad defensiva +(0/1/2) de vida por defensor alrededor.
	var unidad := asc(side, A.DEFENSOR, [0, 1, 2])
	for ch in mine:
		if ch.data.has_archetype(A.ARQUERO):
			ch.attack_bonus += certero
		if ch.data.has_archetype(A.DEFENSOR) and unidad > 0:
			var pos := board.pos_of(ch)
			var around := 0
			for other in board.within(pos, 2, side):
				if other != ch and other.data.has_archetype(A.DEFENSOR) and maxi(absi(board.pos_of(other).x - pos.x), absi(board.pos_of(other).y - pos.y)) == 1:
					around += 1
			ch.max_hp_bonus += unidad * around
			ch.hp += unidad * around
		# Asesino (2): sigilo.
		if ch.data.has_archetype(A.ASESINO) and atier(side, A.ASESINO) >= 1:
			ch.stealth = true
	# Asesino (0): Marcado para morir: saltan hacia la víctima más cercana a la casilla opuesta.
	for ch in mine:
		if ch.data.has_archetype(A.ASESINO):
			_assassin_jump(ch)
	# Ángel: Pacto de fe: asigna (1/2/3) dados de fe.
	var fe := asc(side, A.ANGEL, [1, 2, 3])
	if fe > 0:
		var sorted := mine.duplicate()
		sorted.sort_custom(func(x: Champion, y: Champion) -> bool: return x.max_hp() > y.max_hp())
		faith_dice[side] = sorted.slice(0, fe)


func _assassin_jump(ch: Champion) -> void:
	var from := board.pos_of(ch)
	var victim := _nearest_enemy_to(Board.opposite(from), 1 - ch.side)
	if victim == null:
		return
	var vpos := board.pos_of(victim)
	var best := Vector2i(-1, -1)
	var best_d := 999
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var cand: Vector2i = vpos + d
		if board.is_free(cand) and Board.distance(cand, from) < best_d:
			best = cand
			best_d = Board.distance(cand, from)
	if best.x >= 0:
		board.move(ch, best)
		log_line("%s salta junto a %s." % [ch.data.display_name, victim.data.display_name])


func _nearest_enemy_to(pos: Vector2i, enemy_side: int) -> Champion:
	var best: Champion = null
	var best_d := 999
	for ch in board.champions(enemy_side):
		if not ch.is_targetable():
			continue
		var d := Board.distance(pos, board.pos_of(ch))
		if d < best_d:
			best = ch
			best_d = d
	return best


## Lanza los dados de ambos lados. Devuelve false si la batalla terminó.
func begin_round() -> bool:
	if not started:
		start()
	if is_finished():
		return false
	round_no += 1
	events.clear()
	log_line("--- Asalto %d ---" % round_no)
	for side in 2:
		for ch in board.champions(side):
			ch.reset_for_round()
		var rolled: Array = []
		for f in Dice.roll_faces(rng, adalids[side].dice_count()):
			var face: int = f
			if atier(1 - side, A.ROBOT) >= 3:
				face = maxi(face - 1, -1) # Hackeo del rival: cada cara empeora un paso.
			rolled.append(face)
		dice[side] = rolled
		var labels: PackedStringArray = []
		for f in rolled:
			labels.append(Dice.face_label(f))
		log_line("%s lanza %d dados: %s" % [adalids[side].display_name, rolled.size(), " ".join(labels)])
	return true


## Reparte las caras lanzadas entre los campeones con poder. Devuelve { Champion: Rules.Die }.
func auto_assign(side: int) -> Dictionary:
	var candidates: Array[Champion] = []
	for ch in board.champions(side):
		if not ch.can_act() or not ch.data.has_power() or not Powers.is_implemented(ch.data.id):
			continue
		if ch.data.id == &"salvaje_asesino" and not is_last_round():
			continue # Frenesí solo sirve en el último asalto.
		candidates.append(ch)
	return plan_assignment(dice[side], candidates)


## Con las caras disponibles, activa el mayor número de poderes, empezando por
## los campeones más fuertes y gastando lo mínimo en cada uno.
static func plan_assignment(faces: Array, champions: Array[Champion]) -> Dictionary:
	var pool := { -1: 0, 0: 0, 1: 0 }
	for f in faces:
		pool[f] = pool.get(f, 0) + 1
	var sorted := champions.duplicate()
	sorted.sort_custom(func(x: Champion, y: Champion) -> bool: return x.attack() + x.max_hp() > y.attack() + y.max_hp())
	var assigned := {}
	for ch in sorted:
		var options: Array = ch.data.power_requirement()
		if options.is_empty():
			options = [Rules.Die.NEUTRO, Rules.Die.ACIERTO, Rules.Die.FALLO, Rules.Die.CRITICO, Rules.Die.PIFIA]
		# Opciones de más barata a más cara (un dado antes que dos).
		var ranked := options.duplicate()
		ranked.sort_custom(func(a: int, b: int) -> bool: return _die_cost(a) < _die_cost(b))
		for d in ranked:
			var need := Dice.faces_for(d)
			var ok := true
			for face in need:
				if pool.get(face, 0) < need[face]:
					ok = false
			if ok:
				for face in need:
					pool[face] -= need[face]
				assigned[ch] = d
				break
	return assigned


static func _die_cost(d: int) -> int:
	var total := 0
	for face in Dice.faces_for(d).values():
		total += face
	return total


## Resuelve el asalto. Sin argumento, los dados se asignan solos en ambos lados.
func commit_round(assign_by_side: Array = []) -> void:
	for side in 2:
		var assigned: Dictionary = assign_by_side[side] if assign_by_side.size() > side else auto_assign(side)
		for ch in assigned:
			var d: int = assigned[ch]
			if not (ch is Champion) or ch.side != side or not ch.alive:
				continue
			ch.die = d
			log_line("  %s: %s saca %s para %s." % [adalids[side].display_name, ch.data.display_name,
				Rules.die_label(d), ch.data.power.get("name", "?")])
	_phase_tier_hi()
	_phase_powers(P.HI)
	_phase_move()
	_phase_powers(P.HR)
	_phase_attack()
	_phase_powers(P.H)
	_phase_powers(P.HF)
	_phase_tier_hf()
	_end_of_round()


func is_finished() -> bool:
	return finished or round_no >= round_limit() or board.alive_count(0) == 0 or board.alive_count(1) == 0


## Último asalto posible (con «hasta el final» hay un tope de seguridad).
func round_limit() -> int:
	return max_rounds if max_rounds > 0 else Rules.SUDDEN_DEATH_CAP


## ¿Es el asalto final? Sin límite, cuenta como final a partir del cuarto.
func is_last_round() -> bool:
	return round_no >= (max_rounds if max_rounds > 0 else Rules.ROUNDS_PER_BATTLE)


# ---------------------------------------------------------------- poderes

func _power_active(ch: Champion) -> bool:
	return ch.die >= 0 and ch.data.has_power() and Dice.meets(ch.die, ch.data.power_requirement())


func _phase_powers(phase: int) -> void:
	for side in 2:
		for ch in board.champions(side):
			if not ch.can_act() or not _power_active(ch) or ch.data.power_phase() != phase:
				continue
			if not ch.data.power_is_passive():
				ch.acted = true # Un poder activo cuenta como la acción del asalto.
			Powers.use(self, ch)


# ---------------------------------------------------------------- movimiento

func _phase_move() -> void:
	var movers: Array[Champion] = []
	for side in 2:
		movers.append_array(board.champions(side))
	movers.sort_custom(func(x: Champion, y: Champion) -> bool: return x.hp > y.hp)
	for ch in movers:
		if not ch.alive or ch.buried:
			continue
		if ch.frozen > 0:
			ch.frozen -= 1
			log_line("  %s está congelado y no actúa." % ch.data.display_name)
			ch.acted = true
			continue
		if ch.acted and not ch.can_move_and_attack:
			continue
		var target := _choose_target(ch)
		ch.target = target
		if target == null:
			continue
		var steps := Rules.BASE_MOVE + asc(ch.side, A.SALVAJE, [1, 2, 4]) if ch.data.has_archetype(A.SALVAJE) else Rules.BASE_MOVE
		var moved := 0
		while moved < steps and Board.distance(board.pos_of(ch), board.pos_of(target)) > ch.data.reach():
			var from := board.pos_of(ch)
			var step := _step_toward(from, board.pos_of(target))
			if step.x < 0 or not board.move(ch, step):
				break
			ev({ "type": "move", "ch": ch, "from": from, "to": step })
			moved += 1
		if moved > 0:
			var p := board.pos_of(ch)
			log_line("  %s avanza %d hacia %s (F%d C%d)." % [ch.data.display_name, moved, target.data.display_name, Board.row_of(p), p.x + 1])


## Objetivo: el enemigo más cercano; a igual distancia, misma columna (adelante/atrás)
## antes que los lados, y la derecha antes que la izquierda.
func _choose_target(ch: Champion) -> Champion:
	var from := board.pos_of(ch)
	var best: Champion = null
	var best_key := []
	for other in board.champions(1 - ch.side):
		if not other.is_targetable():
			continue
		var p := board.pos_of(other)
		var key := [Board.distance(from, p), 0 if p.x == from.x else 1, -p.x]
		if best == null or key < best_key:
			best = other
			best_key = key
	return best


## Un paso ortogonal: primero por el eje de mayor distancia; vertical antes que horizontal.
func _step_toward(from: Vector2i, to: Vector2i) -> Vector2i:
	var dx := to.x - from.x
	var dy := to.y - from.y
	var options: Array[Vector2i] = []
	var vertical := Vector2i(0, signi(dy)) if dy != 0 else Vector2i.ZERO
	var horizontal := Vector2i(signi(dx), 0) if dx != 0 else Vector2i.ZERO
	if absi(dy) >= absi(dx):
		options = [vertical, horizontal]
	else:
		options = [horizontal, vertical]
	for o in options:
		if o != Vector2i.ZERO and board.is_free(from + o):
			return from + o
	return Vector2i(-1, -1)


# ---------------------------------------------------------------- ataque

func _phase_attack() -> void:
	for side in 2:
		for ch in board.champions(side):
			if not ch.can_act() or (ch.acted and not ch.can_move_and_attack):
				continue
			var target := ch.target if ch.target != null and ch.target.is_targetable() else _choose_target(ch)
			if target == null:
				continue
			if Board.distance(board.pos_of(ch), board.pos_of(target)) > ch.data.reach():
				continue
			basic_attack(ch, target)
			ch.acted = true


## Ataque básico con todas las pasivas de tier.
func basic_attack(attacker: Champion, target: Champion) -> void:
	var side := attacker.side
	var enemy := 1 - side
	var name := attacker.data.display_name
	# Aura de retribución: ángeles enemigos cerca del atacante.
	for angel in board.champions(enemy):
		if angel.retribution > 0 and Board.distance(board.pos_of(angel), board.pos_of(attacker)) <= angel.retribution:
			attacker.take_damage(1 + angel.afi(), angel)
			log_line("  Retribución: %s recibe %d." % [name, 1 + angel.afi()])
	if target.dodge_basic:
		log_line("  %s ataca a %s, que se lo quita de encima con el viento." % [name, target.data.display_name])
		ev({ "type": "dodge", "ch": target })
		return
	# Céfiro: los aire esquivan según el dado.
	if target.data.element == E.AIRE and etier(enemy, E.AIRE) > 0:
		var need: Array = [[D.CRITICO], [D.CRITICO, D.ACIERTO], [D.CRITICO, D.ACIERTO, D.FALLO]][etier(enemy, E.AIRE) - 1]
		if need.has(Dice.roll_die(rng)):
			log_line("  %s ataca a %s, pero el aire lo esquiva (Céfiro)." % [name, target.data.display_name])
			ev({ "type": "dodge", "ch": target })
			_on_dodge(enemy)
			return
	ev({ "type": "attack", "ch": attacker, "target": target })
	var left_stealth := attacker.stealth
	if left_stealth:
		attacker.stealth = false
		var sombras := asc(side, A.ASESINO, [1, 2, 0])
		attacker.next_attack_bonus += attacker.attack() if atier(side, A.ASESINO) >= 3 else sombras
	var damage := attacker.attack() + target.incoming_bonus
	# A los puntos vitales: el arquero duplica su daño básico.
	if attacker.data.has_archetype(A.ARQUERO) and atier(side, A.ARQUERO) > 0:
		var need: Array = [[D.CRITICO], [D.CRITICO], [D.CRITICO, D.ACIERTO]][atier(side, A.ARQUERO) - 1]
		if need.has(Dice.roll_die(rng)):
			damage += attacker.base_attack()
			log_line("  ¡A los puntos vitales! %s duplica su daño." % name)
	var dealt := deal_damage(attacker, target, damage, "ataca")
	attacker.next_attack_bonus = 0
	# Roca afilada: atacar cuerpo a cuerpo a un tierra lastima.
	if target.data.element == E.TIERRA and etier(enemy, E.TIERRA) > 0 and attacker.data.reach() == 1:
		var spikes := esc(enemy, E.TIERRA, [0, 1, 2]) + target.incoming_bonus * 0
		spikes += _spike_bonus(enemy)
		if spikes > 0:
			attacker.take_damage(spikes, target)
			log_line("  Roca afilada: %s recibe %d." % [name, spikes])
	# Electrocutar / Armadura de escarcha (defensores con pasiva activa).
	if target.die >= 0 and target.data.id == Catalog.id_for(A.DEFENSOR, E.TRUENO) and _power_active(target):
		attacker.take_damage(1 + target.afi(), target)
		for ally in board.within(board.pos_of(attacker), 1, side):
			if ally != attacker:
				ally.take_damage(1 + target.afi(), target)
		log_line("  Electrocutar: %s y sus adyacentes reciben %d." % [name, 1 + target.afi()])
	if target.die >= 0 and target.data.id == Catalog.id_for(A.DEFENSOR, E.HIELO) and _power_active(target):
		attacker.frozen += 1
		log_line("  Armadura de escarcha congela a %s." % name)
	if dealt > 0:
		_after_hit(attacker, target, dealt)
	# Garras felinas (Salvaje 6): golpea también a los objetivos diagonales.
	if attacker.data.has_archetype(A.SALVAJE) and atier(side, A.SALVAJE) >= 3:
		var ap := board.pos_of(attacker)
		for other in board.champions(enemy):
			if other != target and other.is_targetable() and Board.is_diagonal(ap, board.pos_of(other)):
				deal_damage(attacker, other, attacker.attack(), "zarpa en diagonal a")
	# Capa negra: al matar, puede volver al sigilo.
	if left_stealth and not target.alive and attacker.data.has_archetype(A.ASESINO) and atier(side, A.ASESINO) > 0:
		var need: Array = [[D.CRITICO], [D.CRITICO, D.ACIERTO], [D.CRITICO, D.ACIERTO, D.FALLO]][atier(side, A.ASESINO) - 1]
		if need.has(Dice.roll_die(rng)):
			attacker.stealth = true
			log_line("  %s vuelve a las sombras (Capa negra)." % name)


func _spike_bonus(side: int) -> int:
	var bonus := 0
	for ch in board.champions(side):
		if ch.data.id == Catalog.id_for(A.SALVAJE, E.TIERRA) and _power_active(ch):
			bonus += 1 + ch.afi()
	return bonus


## Daño de un golpe (básico o de poder) con reducciones, bloqueo y reacciones.
func deal_damage(source: Champion, target: Champion, amount: int, verb: String, is_power := false) -> int:
	if not target.alive or amount <= 0:
		return 0
	var tside := target.side
	if is_power and target.dodge_powers:
		log_line("  %s %s a %s, pero está camuflado." % [source.data.display_name, verb, target.data.display_name])
		return 0
	# Piel pétrea: los tierra reducen el daño en (1/2/4).
	if target.data.element == E.TIERRA:
		amount -= esc(tside, E.TIERRA, [1, 2, 4])
	# Aura de paz: ángeles aliados cerca del objetivo.
	for angel in board.champions(tside):
		if angel.peace > 0 and Board.distance(board.pos_of(angel), board.pos_of(target)) <= angel.peace:
			amount -= 1 + angel.afi()
			break
	amount = maxi(amount, 0)
	# Bloqueo: un defensor adyacente recibe el daño de los aliados no defensores.
	var receiver := target
	if atier(tside, A.DEFENSOR) > 0 and not target.data.has_archetype(A.DEFENSOR):
		for ally in board.within(board.pos_of(target), 1, tside):
			if ally != target and ally.data.has_archetype(A.DEFENSOR) and ally.alive:
				receiver = ally
				break
	var dealt := receiver.take_damage(amount, source)
	ev({ "type": "damage", "ch": receiver, "amount": dealt, "hp": receiver.hp, "power": is_power })
	log_line("  %s %s %s: %d de daño%s." % [source.data.display_name, verb, receiver.data.display_name, dealt,
		"" if receiver == target else " (bloquea por %s)" % target.data.display_name])
	if dealt > 0 and receiver.die >= 0 and receiver.data.id == Catalog.id_for(A.ROBOT, E.TRUENO) and _power_active(receiver):
		_produce(tside, (1 + receiver.afi()) * dealt, receiver)
	if not receiver.alive:
		_on_kill(source, receiver)
	return dealt


## Reacciones a un golpe básico que hizo daño: Quemadura, Venas heladas, Quebrar, Cauterizar.
func _after_hit(attacker: Champion, target: Champion, dealt: int) -> void:
	var side := attacker.side
	var enemy := 1 - side
	# Quemadura: los fuego salpican (mitad/mitad/total) a distancia (1/2/3); Piel ígnea protege a los fuego.
	if attacker.data.element == E.FUEGO and etier(side, E.FUEGO) > 0 and target.alive or (attacker.data.element == E.FUEGO and etier(side, E.FUEGO) > 0):
		var radius := esc(side, E.FUEGO, [1, 2, 3])
		var splash := attacker.base_attack() if etier(side, E.FUEGO) >= 3 else attacker.base_attack() / 2
		if splash > 0:
			for other in board.within(board.pos_of(target), radius):
				if other != target and other != attacker and other.data.element != E.FUEGO and other.alive:
					deal_damage(attacker, other, splash, "quema a", true)
	# Venas heladas / Quebrar.
	if attacker.data.element == E.HIELO and etier(side, E.HIELO) > 0 and target.alive:
		if target.frozen > 0:
			var hp := target.hp
			target.take_damage(target.hp, attacker)
			ev({ "type": "damage", "ch": target, "amount": hp, "hp": 0, "power": true })
			ev({ "type": "tier", "side": side, "name": "Quebrar", "element": E.HIELO })
			log_line("  Quebrar: %s se resquebraja." % target.data.display_name)
			_on_kill(attacker, target)
		else:
			var need: Array = [[D.CRITICO], [D.CRITICO, D.ACIERTO], [D.CRITICO, D.ACIERTO, D.FALLO]][etier(side, E.HIELO) - 1]
			if need.has(Dice.roll_die(rng)):
				target.frozen += 1
				ev({ "type": "freeze", "ch": target })
				log_line("  Venas heladas congela a %s." % target.data.display_name)
	# Cauterizar: la vida máxima del enemigo baja a lo que le queda.
	if attacker.data.id == Catalog.id_for(A.DEFENSOR, E.FUEGO) and _power_active(attacker) and target.alive:
		target.max_hp_bonus -= target.max_hp() - target.hp
		log_line("  Cauterizar: la vida máxima de %s queda en %d." % [target.data.display_name, target.max_hp()])


func _on_dodge(side: int) -> void:
	for ch in board.champions(side):
		if ch.data.id == Catalog.id_for(A.ROBOT, E.AIRE) and _power_active(ch):
			_produce(side, 1 + ch.afi(), ch)


func _produce(side: int, amount: int, by: Champion) -> void:
	if by.data.has_archetype(A.ROBOT):
		amount += asc(side, A.ROBOT, [1, 2, 5]) # Optimización.
	eter_produced[side] += amount
	log_line("  %s produce %d de Éter." % [by.data.display_name, amount])


func _on_kill(killer: Champion, victim: Champion) -> void:
	if killer == null or killer == victim:
		return
	var vside := victim.side
	# Maldición: matar a un demonio maldice.
	if victim.data.has_archetype(A.DEMONIO) and atier(vside, A.DEMONIO) > 0:
		killer.cursed = true
		ev({ "type": "curse", "ch": killer })
		log_line("  %s queda maldito por matar a %s." % [killer.data.display_name, victim.data.display_name])
	# Tatuko: el pirata que mata lanza un dado.
	if killer.data.has_archetype(A.PIRATA) and atier(killer.side, A.PIRATA) > 0:
		var t := atier(killer.side, A.PIRATA)
		var adalid := adalids[killer.side]
		ev({ "type": "tier", "side": killer.side, "name": "Tatuko", "archetype": A.PIRATA })
		match Dice.roll_die(rng):
			D.PIFIA:
				adalid.lose_life(Tiers.scaled(t, [2, 1, 0]))
				log_line("  Tatuko: disparo en el pie, %s pierde %d de vida." % [adalid.display_name, Tiers.scaled(t, [2, 1, 0])])
			D.FALLO:
				adalid.gain_life(Tiers.scaled(t, [0, 1, 2]))
				log_line("  Tatuko: ¡más ron! %s recupera %d." % [adalid.display_name, Tiers.scaled(t, [0, 1, 2])])
			D.ACIERTO:
				_produce(killer.side, Tiers.scaled(t, [1, 2, 3]), killer)
			D.CRITICO:
				aftermath.append({ "type": "draw", "adalid": adalid, "count": Tiers.scaled(t, [1, 2, 4]) })
				log_line("  Tatuko: la X marca el lugar, %s roba %d cartas." % [adalid.display_name, Tiers.scaled(t, [1, 2, 4])])


# ---------------------------------------------------------------- tiers por fase

func _phase_tier_hi() -> void:
	for side in 2:
		var enemy := 1 - side
		# Maldición: los malditos lanzan un dado al inicio del asalto.
		for ch in board.champions(side):
			if ch.cursed and atier(enemy, A.DEMONIO) > 0:
				var need: Array = [[D.CRITICO], [D.CRITICO, D.ACIERTO], [D.CRITICO, D.ACIERTO, D.FALLO]][atier(enemy, A.DEMONIO) - 1]
				if need.has(Dice.roll_die(rng)):
					var hp := ch.hp
					ch.take_damage(ch.hp)
					ev({ "type": "tier", "side": enemy, "name": "Maldición", "archetype": A.DEMONIO })
					ev({ "type": "damage", "ch": ch, "amount": hp, "hp": 0, "power": true })
					log_line("  La maldición consume a %s." % ch.data.display_name)
		# Herejía: (1/2/3) d20; los enemigos en esas casillas pierden sus habilidades este asalto.
		var herejia := asc(side, A.DEMONIO, [1, 2, 3])
		for _i in herejia:
			var cell := Dice.d20_to_cell(Dice.roll_d20(rng))
			if cell < 0:
				continue
			var victim := board.at(Board.pos_from_cell(enemy, cell))
			if victim != null and victim.alive and victim.die >= 0:
				victim.die = -1
				ev({ "type": "tier", "side": side, "name": "Herejía", "archetype": A.DEMONIO, "ch": victim })
				log_line("  Herejía silencia a %s." % victim.data.display_name)
		# Magia desatada: (1/2/4) d20; los aliados ahí usan su poder como si el dado fuera (-/+/++).
		var magia := asc(side, A.MAGO, [1, 2, 4])
		var forced: Array = [D.FALLO, D.ACIERTO, D.CRITICO]
		for _i in magia:
			var cell := Dice.d20_to_cell(Dice.roll_d20(rng))
			if cell < 0:
				continue
			var ally := board.at(Board.pos_from_cell(side, cell))
			if ally != null and ally.alive and ally.data.has_power():
				ally.die = forced[atier(side, A.MAGO) - 1]
				ev({ "type": "tier", "side": side, "name": "Magia desatada", "archetype": A.MAGO, "ch": ally })
				log_line("  Magia desatada: %s actúa con %s." % [ally.data.display_name, Rules.die_label(ally.die)])
		# Tifón: (1/2/4) d20; los enemigos ahí son arrastrados (1/2/3) hacia atrás.
		var tifon := esc(side, E.AIRE, [1, 2, 4])
		for _i in tifon:
			var cell := Dice.d20_to_cell(Dice.roll_d20(rng))
			if cell < 0:
				continue
			var victim := board.at(Board.pos_from_cell(enemy, cell))
			if victim != null and victim.alive:
				ev({ "type": "tier", "side": side, "name": "Tifón", "element": E.AIRE, "ch": victim })
				_push(victim, Board.backward(enemy), esc(side, E.AIRE, [1, 2, 3]), esc(side, E.AIRE, [1, 2, 3]))


## Empuja `steps` casillas; si choca con otro o con el borde, ambos reciben `crash` daño verdadero.
func _push(victim: Champion, dir: Vector2i, steps: int, crash: int) -> void:
	for _i in steps:
		var from := board.pos_of(victim)
		var next := from + dir
		if not Board.in_bounds(next):
			victim.take_damage(crash)
			ev({ "type": "damage", "ch": victim, "amount": crash, "hp": victim.hp, "power": true })
			log_line("  %s choca contra el borde: %d de daño." % [victim.data.display_name, crash])
			return
		var other := board.at(next)
		if other != null:
			victim.take_damage(crash)
			other.take_damage(crash)
			ev({ "type": "damage", "ch": victim, "amount": crash, "hp": victim.hp, "power": true })
			ev({ "type": "damage", "ch": other, "amount": crash, "hp": other.hp, "power": true })
			log_line("  %s choca con %s: %d de daño a ambos." % [victim.data.display_name, other.data.display_name, crash])
			return
		board.move(victim, next)
		ev({ "type": "move", "ch": victim, "from": from, "to": next })
	log_line("  %s es arrastrado %d casillas." % [victim.data.display_name, steps])


func _phase_tier_hf() -> void:
	for side in 2:
		var enemy := 1 - side
		# Tormenta (Trueno): (1/2/4) dados; (1/2/4) de daño a los enemigos de esa columna. Trueno con 6.
		var tormenta := esc(side, E.TRUENO, [1, 2, 4])
		var caster := _any_of(side, E.TRUENO)
		if caster != null and tormenta > 0:
			ev({ "type": "tier", "side": side, "name": "Tormenta", "element": E.TRUENO })
		for _i in (tormenta if caster != null else 0):
			var col := rng.randi_range(0, Board.COLS - 1) # SUPUESTO: un d6 señala la columna.
			for victim in board.in_column(col, enemy):
				deal_damage(caster, victim, esc(side, E.TRUENO, [1, 2, 4]), "electrocuta a", true)
			# Trueno: con un crítico en el dado de tormenta, cae el enemigo con más vida máxima.
			if Dice.roll_die(rng) == D.CRITICO:
				var big := _strongest(enemy)
				if big != null:
					var hp := big.hp
					big.take_damage(big.hp, caster)
					ev({ "type": "tier", "side": side, "name": "¡Trueno!", "element": E.TRUENO, "ch": big })
					ev({ "type": "damage", "ch": big, "amount": hp, "hp": 0, "power": true })
					log_line("  ¡Trueno! %s cae fulminado." % big.data.display_name)
		# Luz renovadora: cura (1/2/4) a todos los aliados heridos.
		var luz := asc(side, A.ANGEL, [1, 2, 4])
		if luz > 0:
			ev({ "type": "tier", "side": side, "name": "Luz renovadora", "archetype": A.ANGEL })
			for ch in board.champions(side):
				if ch.hp < ch.max_hp():
					var healed := ch.heal(luz)
					ev({ "type": "heal", "ch": ch, "amount": healed, "hp": ch.hp })
			log_line("  Luz renovadora cura %d a los heridos de %s." % [luz, adalids[side].display_name])
		# Resurrección: (4/2/1) dados; si todos aciertan, vuelven los muertos de este asalto.
		var res := asc(side, A.ANGEL, [4, 2, 1])
		if res > 0 and Dice.roll_dice(rng, res).all(func(d: Rules.Die) -> bool: return Dice.die_is_hit(d)):
			for ch in board.champions(side, false):
				if not ch.alive and ch.died_this_round:
					ch.revive(ch.max_hp())
					ev({ "type": "tier", "side": side, "name": "Resurrección", "archetype": A.ANGEL, "ch": ch })
					ev({ "type": "heal", "ch": ch, "amount": ch.hp, "hp": ch.hp })
					log_line("  Resurrección: %s vuelve." % ch.data.display_name)
		# Marchitar: los vivos enemigos pierden (1/2/2) de ataque.
		var marchitar := asc(side, A.MUERTO, [1, 2, 2])
		if marchitar > 0:
			ev({ "type": "tier", "side": side, "name": "Marchitar", "archetype": A.MUERTO })
			for ch in board.champions(enemy):
				if not ch.data.has_archetype(A.MUERTO):
					ch.attack_bonus -= marchitar
			log_line("  Marchitar: los vivos de %s pierden %d de ataque." % [adalids[enemy].display_name, marchitar])


func _any_of(side: int, element: int) -> Champion:
	for ch in board.champions(side):
		if ch.data.element == element:
			return ch
	return board.champions(side)[0] if board.alive_count(side) > 0 else null


func _strongest(side: int) -> Champion:
	var best: Champion = null
	for ch in board.champions(side):
		if best == null or ch.max_hp() > best.max_hp() or (ch.max_hp() == best.max_hp() and ch.attack() > best.attack()):
			best = ch
	return best


func _end_of_round() -> void:
	for ch in board.clear_dead():
		ev({ "type": "death", "ch": ch })
		log_line("%s cae." % ch.data.display_name)
	for side in 2:
		log_line("%s: %s" % [adalids[side].display_name, " / ".join(board.describe(side))])


# ---------------------------------------------------------------- final

func finish() -> Dictionary:
	if finished:
		return result
	finished = true
	var a := adalids[0]
	var b := adalids[1]
	# Pacto de fe: lanza los dados de los supervivientes y cura al adalid por cada +.
	for side in 2:
		var heals := 0
		for ch in faith_dice[side]:
			if ch.alive and Dice.die_is_hit(Dice.roll_die(rng)):
				heals += 1
		if heals > 0:
			adalids[side].gain_life(heals)
			log_line("Pacto de fe: %s recupera %d de vida." % [adalids[side].display_name, heals])
		# Oro maldito.
		for ch in board.champions(side):
			if ch.data.id == &"pirata_muerto":
				adalids[1 - side].lose_life(1 + ch.afi())
				adalids[side].gain_life(1 + ch.afi())
				log_line("Oro maldito: %s roba %d de vida." % [adalids[side].display_name, 1 + ch.afi()])
		if eter_produced[side] > 0:
			adalids[side].add_eter(eter_produced[side])
			log_line("%s gana %d de Éter producido en batalla." % [adalids[side].display_name, eter_produced[side]])
	var na := board.alive_count(0)
	var nb := board.alive_count(1)
	result = { "rounds": round_no, "winner": null, "loser": null, "tie": na == nb, "damage": [0, 0] }
	if na == nb:
		# Empate: los dos perdieron.
		for side in 2:
			var loss := _life_loss(side, 0)
			adalids[side].lose_life(loss)
			adalids[side].record_result(false)
			result["damage"][side] = loss
		log_line("Empate: ambos pierden %d y %d de vida." % [result["damage"][0], result["damage"][1]])
		return result
	var w := 0 if na > nb else 1
	var l := 1 - w
	var advantage := absi(na - nb)
	var loss := _life_loss(l, advantage)
	adalids[l].lose_life(loss)
	adalids[l].record_result(false)
	adalids[w].record_result(true)
	result["winner"] = adalids[w]
	result["loser"] = adalids[l]
	result["damage"][l] = loss
	log_line("Gana %s con %d campeones de ventaja. %s pierde %d de vida (queda %d)." % [
		adalids[w].display_name, advantage, adalids[l].display_name, loss, adalids[l].life])
	# Venganza pirata del perdedor.
	if atier(l, A.PIRATA) >= 3:
		match Dice.roll_die(rng):
			D.FALLO:
				aftermath.append({ "type": "sabotage", "adalid": adalids[w] })
				log_line("  Venganza: sabotaje al tablero de %s." % adalids[w].display_name)
			D.ACIERTO:
				var stolen := mini(10, adalids[w].eter)
				adalids[w].add_eter(-stolen)
				adalids[l].add_eter(stolen)
				log_line("  Venganza: saqueo de %d de Éter." % stolen)
			D.CRITICO:
				aftermath.append({ "type": "steal_card", "from": adalids[w], "to": adalids[l] })
				log_line("  Venganza: oleada de cañones, roba una carta del cuartel.")
			_:
				log_line("  Venganza: viento en contra, no sucede nada.")
	return result


## Vida que pierde el perdedor: batallas realizadas + 1 por campeón de ventaja
## (sin contar el primero), menos Protocolo de protección (1/2/4).
func _life_loss(side: int, advantage: int) -> int:
	var loss := battle_number + maxi(advantage - 1, 0)
	loss -= asc(side, A.ROBOT, [1, 2, 4])
	return maxi(loss, 0)
