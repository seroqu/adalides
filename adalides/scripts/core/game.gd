class_name Game
extends RefCounted
## Una partida v2: ciclos de draft → mercado/mejoras → alineación → batallas
## según la tabla. Máquina de estados con un jugador humano opcional; sin
## humano, `play_cycle()` lo hace todo con la IA.

enum State { IDLE, DRAFT, MARKET, LINEUP, BATTLE, CYCLE_END, OVER }
## Nivel de la IA: cuánto ruido mete en sus decisiones y cuánto arriesga.
enum Difficulty { PRINCIPIANTE, AMATEUR, PROFESIONAL }

var difficulty: Difficulty = Difficulty.AMATEUR
var rounds_per_battle: int = Rules.ROUNDS_PER_BATTLE # 0 = hasta que un bando caiga.
var ai_handicap: bool = false # Tutorial: el rival del humano alinea un campeón menos, y los más flojos.
var start_life: int = Rules.STARTING_LIFE

var adalids: Array[Adalid] = []
var deck: Deck
var cycle: int = 0
var rng := RandomNumberGenerator.new()
var log: PackedStringArray = []
var last_battles: Array[Battle] = []
var life_before: Dictionary = {} # Adalid → vida al empezar el ciclo (para el resumen).
var demiurge_wins: bool = false

# --- humano ---
var human: Adalid = null
var state: State = State.IDLE
var draft_pool: Array[ChampionData] = []
var draft_order: Array[Adalid] = [] # Turnos pendientes (serpiente).
var market: Array[ChampionData] = []
var human_lineup: Dictionary = {} # Vector2i(col, row) → Champion
var current_battle: Battle = null
var _pairs_queue: Array = []


func _init(names: PackedStringArray, seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	for n in names:
		adalids.append(Adalid.new(n))
	deck = Deck.new(rng)


func set_human(index: int) -> void:
	human = adalids[index]
	human.is_ai = false


## Vida y Éter iniciales distintos de los de las reglas (tutorial).
func set_start(life: int, eter: int) -> void:
	start_life = life
	for a in adalids:
		a.life = life
		a.eter = eter


## Ruido aleatorio que se suma a la puntuación de una carta según la dificultad.
func _ai_noise() -> float:
	match difficulty:
		Difficulty.PRINCIPIANTE:
			return rng.randf() * 12.0
		Difficulty.AMATEUR:
			return rng.randf() * 3.0
	return 0.0


func alive_adalids() -> Array[Adalid]:
	var out: Array[Adalid] = []
	for a in adalids:
		if not a.eliminated:
			out.append(a)
	return out


func is_over() -> bool:
	return demiurge_wins or alive_adalids().size() <= 1


func winner() -> Adalid:
	var alive := alive_adalids()
	return alive[0] if alive.size() == 1 and not demiurge_wins else null


func human_in_play() -> bool:
	return human != null and not human.eliminated


# ---------------------------------------------------------------- ciclo (IA)

func play_cycle() -> bool:
	if not begin_cycle():
		return false
	advance()
	return true


# ---------------------------------------------------------------- ciclo paso a paso

## Draft: se muestran 3 × jugadores cartas (sin héroes); cada uno toma 2 en serpiente.
func begin_cycle() -> bool:
	if is_over():
		state = State.OVER
		return false
	cycle += 1
	log.clear()
	last_battles.clear()
	life_before.clear()
	for a in adalids:
		life_before[a] = a.life
	log.append("##### Ciclo %d #####" % cycle)
	if cycle > 1:
		_begin_market() # El draft solo se hace en el primer ciclo.
		return true
	var players := alive_adalids()
	draft_pool = deck.draw(Rules.DRAFT_CARDS_PER_PLAYER * players.size(), false)
	# Orden de serpiente: SUPUESTO, empieza quien tiene menos vida.
	var order := players.duplicate()
	order.sort_custom(func(x: Adalid, y: Adalid) -> bool: return x.life < y.life)
	draft_order = []
	for pick in Rules.DRAFT_PICKS:
		var round_order := order.duplicate()
		if pick % 2 == 1:
			round_order.reverse()
		draft_order.append_array(round_order)
	state = State.DRAFT
	if not human_in_play():
		_run_draft()
	return true


## A quién le toca elegir en el draft (null si terminó).
func draft_current() -> Adalid:
	return null if draft_order.is_empty() else draft_order[0]


## Un paso del draft: si le toca a una IA, elige y devuelve { adalid, card };
## si le toca al humano devuelve { "human": true }; si terminó, cierra el draft
## y devuelve {}.
func draft_step() -> Dictionary:
	if state != State.DRAFT:
		return {}
	if draft_order.is_empty():
		_finish_draft()
		return {}
	var a: Adalid = draft_order[0]
	if a == human:
		return { "human": true }
	draft_order.pop_front()
	var card := ai_pick(a, draft_pool)
	if card != null:
		draft_pool.erase(card)
		a.add_card(card)
		log.append("%s toma %s en el draft." % [a.display_name, card.display_name])
	return { "adalid": a, "card": card }


## Ejecuta picks de IA hasta que toque al humano o se acabe el draft.
func _run_draft() -> void:
	while state == State.DRAFT:
		var step := draft_step()
		if step.is_empty() or step.has("human"):
			return


func _finish_draft() -> void:
	deck.put_back(draft_pool)
	draft_pool.clear()
	_begin_market()


func human_draft_pick(card: ChampionData) -> bool:
	if state != State.DRAFT or draft_current() != human or not draft_pool.has(card):
		return false
	if not human.can_add(card):
		return false
	draft_order.pop_front()
	draft_pool.erase(card)
	human.add_card(card)
	log.append("%s toma %s en el draft." % [human.display_name, card.display_name])
	return true


## El humano pasa su turno de draft (no le cabe ninguna carta).
func human_draft_skip() -> bool:
	if state != State.DRAFT or draft_current() != human:
		return false
	draft_order.pop_front()
	log.append("%s no toma carta en el draft." % human.display_name)
	return true


func _begin_market() -> void:
	for a in alive_adalids():
		if cycle == 1:
			log.append("%s empieza con %d de Éter (el primer ciclo no se cobra)." % [a.display_name, a.eter])
		else:
			var interest := a.interest()
			var income := a.cycle_income()
			a.add_eter(income)
			log.append("%s cobra %d (10 + %d interés + %d racha), tiene %d." % [
				a.display_name, income, interest, a.streak_bonus(), a.eter])
		if a == human:
			market = _draw_market(a)
		else:
			ai_market(a)
	if human_in_play():
		state = State.MARKET
	else:
		_begin_battles()


## El mercado muestra héroes aunque no quepan (el autor quiere verlos).
func _draw_market(_a: Adalid) -> Array[ChampionData]:
	return deck.draw(Rules.MARKET_SIZE, true)


# --- acciones del humano en el mercado ---

func human_buy(card: ChampionData) -> bool:
	if state != State.MARKET or not market.has(card) or not human.buy(card):
		return false
	market.erase(card)
	log.append("%s compra %s." % [human.display_name, card.display_name])
	return true


func human_refresh_market() -> bool:
	if state != State.MARKET or not human.pay(Rules.MARKET_REFRESH_COST):
		return false
	deck.put_back(market)
	market = _draw_market(human)
	return true


func human_sell(ch: Champion) -> int:
	if state != State.MARKET or not human.cuartel.has(ch):
		return 0
	var value := human.sell(ch)
	deck.put_back([ch.data])
	log.append("%s vende %s por %d." % [human.display_name, ch.data.display_name, value])
	return value


func human_upgrade(track: Adalid.Track) -> bool:
	if state != State.MARKET or not human.upgrade(track):
		return false
	log.append("%s mejora %s." % [human.display_name, Adalid.track_label(track)])
	return true


func finish_market() -> void:
	if state != State.MARKET:
		return
	deck.put_back(market)
	market.clear()
	state = State.LINEUP


## Alineación del humano: Dictionary { Vector2i(col 0..4, row 1..3): Champion }.
func set_lineup(lineup: Dictionary) -> PackedStringArray:
	if state != State.LINEUP:
		return ["No es el momento de alinear."]
	var errors := validate_lineup(human, lineup)
	if not errors.is_empty():
		return errors
	human_lineup = lineup.duplicate()
	_begin_battles()
	return errors


static func validate_lineup(a: Adalid, lineup: Dictionary) -> PackedStringArray:
	var errors: PackedStringArray = []
	if lineup.size() > a.battle_size():
		errors.append("Solo puedes alinear %d campeones." % a.battle_size())
	var seen := []
	for key in lineup:
		if key.x < 0 or key.x >= Rules.BOARD_COLS or key.y < 1 or key.y > Rules.BOARD_ROWS:
			errors.append("Casilla fuera del tablero: %s" % key)
		var ch: Champion = lineup[key]
		if not a.cuartel.has(ch):
			errors.append("%s no está en tu cuartel." % ch.data.display_name)
		if seen.has(ch):
			errors.append("%s está dos veces." % ch.data.display_name)
		seen.append(ch)
	return errors


# ---------------------------------------------------------------- batallas

func _begin_battles() -> void:
	_pairs_queue = Schedule.pairs_for(cycle, adalids)
	state = State.BATTLE
	advance()


## Avanza todo lo que no necesite al humano.
func advance() -> State:
	if state in [State.DRAFT, State.MARKET, State.LINEUP]:
		return state
	if current_battle != null and current_battle.is_finished():
		current_battle.finish()
		_after_battle(current_battle)
		current_battle = null
	while not _pairs_queue.is_empty():
		var pair: Array = _pairs_queue.pop_front()
		if pair.size() == 1:
			log.append("%s descansa este ciclo." % pair[0].display_name)
			continue
		var a: Adalid = pair[0]
		var b: Adalid = pair[1]
		if human_in_play() and (a == human or b == human):
			var opp: Adalid = b if a == human else a
			var opp_lineup := auto_lineup(opp)
			if ai_handicap:
				opp_lineup = _weakest_lineup(opp, maxi(human_lineup.size() - 1, 1))
			current_battle = _make_battle(human, opp, [human_lineup, opp_lineup])
			current_battle.start()
			current_battle.begin_round()
			state = State.BATTLE
			return state
		var battle := _make_battle(a, b, [auto_lineup(a), auto_lineup(b)])
		battle.run()
		_after_battle(battle)
	_end_cycle()
	return state


## Elige qué campeones van a batalla buscando combos: parte del más fuerte y añade cada vez
## el que más suma entre sus números y los tiers de elemento/arquetipo que completa o acerca.
static func pick_squad(a: Adalid) -> Array[Champion]:
	var pool := a.cuartel.duplicate()
	var chosen: Array[Champion] = []
	while chosen.size() < a.battle_size() and not pool.is_empty():
		var elems := Tiers.count_elements(chosen)
		var archs := Tiers.count_archetypes(chosen)
		var best: Champion = null
		var best_score := -INF
		for ch in pool:
			var score := float(ch.attack() + ch.max_hp())
			if ch.data.element >= 0:
				var n: int = elems.get(ch.data.element, 0)
				score += n * 1.5
				if Rules.tier_index(n + 1, Rules.ELEMENT_TIERS) > Rules.tier_index(n, Rules.ELEMENT_TIERS):
					score += 6.0
			for arch in ch.data.archetypes():
				var n: int = archs.get(arch, 0)
				score += n * 1.5
				if Rules.tier_index(n + 1, Rules.ARCHETYPE_TIERS) > Rules.tier_index(n, Rules.ARCHETYPE_TIERS):
					score += 6.0
			if score > best_score:
				best = ch
				best_score = score
		chosen.append(best)
		pool.erase(best)
	return chosen


## Alineación con los `n` campeones más flojos de un adalid (desventaja del tutorial).
static func _weakest_lineup(a: Adalid, n: int) -> Dictionary:
	var chosen := a.cuartel.duplicate()
	chosen.sort_custom(func(x: Champion, y: Champion) -> bool: return x.attack() + x.max_hp() < y.attack() + y.max_hp())
	var tmp := Adalid.new(a.display_name)
	tmp.cuartel.assign(chosen.slice(0, mini(n, a.battle_size())))
	tmp.upgrades = a.upgrades.duplicate()
	return auto_lineup(tmp)


func _make_battle(a: Adalid, b: Adalid, lineups: Array) -> Battle:
	var battle := Battle.new(a, b, lineups, rng, cycle)
	battle.max_rounds = rounds_per_battle
	return battle


## Resuelve el asalto en curso con la asignación { Champion: Rules.Die } del humano.
func commit_human_dice(assignment: Dictionary) -> void:
	if state != State.BATTLE or current_battle == null:
		return
	current_battle.commit_round([assignment, current_battle.auto_assign(1)])
	if not current_battle.begin_round():
		advance()


## Resuelve el asalto en curso con los dados asignados internamente.
func auto_round() -> void:
	if state != State.BATTLE or current_battle == null:
		return
	current_battle.commit_round()
	if not current_battle.begin_round():
		advance()


func _after_battle(battle: Battle) -> void:
	last_battles.append(battle)
	log.append_array(battle.log)
	for effect in battle.aftermath:
		match effect["type"]:
			"draw":
				var a: Adalid = effect["adalid"]
				for card in deck.draw(effect["count"], false):
					if a.can_add(card):
						a.add_card(card)
					else:
						deck.put_back([card])
			"sabotage":
				var victim: Adalid = effect["adalid"]
				for track in [Adalid.Track.CUARTEL, Adalid.Track.BATTLE, Adalid.Track.DICE]:
					if victim.downgrade(track):
						break
			"steal_card":
				var from: Adalid = effect["from"]
				var to: Adalid = effect["to"]
				if not from.cuartel.is_empty():
					var ch: Champion = from.cuartel[rng.randi_range(0, from.cuartel.size() - 1)]
					from.remove_card(ch)
					if to.can_add(ch.data):
						to.add_card(ch.data)
	var both_dead := battle.adalids[0].life <= 0 and battle.adalids[1].life <= 0
	for a in battle.adalids:
		if a.life <= 0 and not a.eliminated:
			a.eliminated = true
			log.append("%s se desintegra en Éter." % a.display_name)
			for ch in a.cuartel:
				deck.put_back([ch.data])
			a.cuartel.clear()
	if both_dead and alive_adalids().is_empty():
		demiurge_wins = true


func _end_cycle() -> void:
	for a in adalids:
		log.append(a.summary())
	if is_over():
		state = State.OVER
		if demiurge_wins:
			log.append("Los dos últimos adalides cayeron a la vez: gana el Demiurgo.")
		elif winner() != null:
			log.append("¡%s es el nuevo demiurgo!" % winner().display_name)
	else:
		state = State.CYCLE_END


# ---------------------------------------------------------------- IA

## Puntúa una carta para un adalid: busca combos. Premia el elemento y el
## arquetipo que más tiene, alcanzar el siguiente tier, duplicar y el valor por coste.
static func card_score(a: Adalid, card: ChampionData) -> float:
	var elems := Tiers.count_elements(a.cuartel)
	var archs := Tiers.count_archetypes(a.cuartel)
	var best_elem := _argmax(elems)
	var best_arch := _argmax(archs)
	var score := 0.0
	if card.element >= 0:
		var n: int = elems.get(card.element, 0)
		score += n * 1.5
		if card.element == best_elem:
			score += 3.0
		if Rules.tier_index(n + 1, Rules.ELEMENT_TIERS) > Rules.tier_index(n, Rules.ELEMENT_TIERS):
			score += 5.0 # Completa un tier elemental.
	for arch in card.archetypes():
		var n: int = archs.get(arch, 0)
		score += n * 1.5
		if arch == best_arch:
			score += 3.0
		if Rules.tier_index(n + 1, Rules.ARCHETYPE_TIERS) > Rules.tier_index(n, Rules.ARCHETYPE_TIERS):
			score += 5.0 # Completa un tier de arquetipo.
	var owned := a.find_card(card.id)
	if owned != null:
		score += 2.5 + owned.copies # Duplicar da +1/+1, poder mejorado y AFI.
	if card.hero:
		score += 4.0
	return score + (card.attack + card.defense) / float(maxi(card.cost, 1))


static func _argmax(counts: Dictionary) -> int:
	var best := -1
	var best_n := 0
	for k in counts:
		if counts[k] > best_n:
			best = k
			best_n = counts[k]
	return best


func ai_pick(a: Adalid, pool: Array[ChampionData]) -> ChampionData:
	var best: ChampionData = null
	var best_score := -1.0
	for card in pool:
		if not a.can_add(card):
			continue
		var s := card_score(a, card) + _ai_noise()
		if s > best_score:
			best = card
			best_score = s
	return best


func ai_market(a: Adalid) -> void:
	# Mejoras: si sobra Éter, alterna batalla → cuartel → dados. El principiante
	# guarda más margen y el profesional invierte antes.
	var tracks: Array = [Adalid.Track.BATTLE, Adalid.Track.CUARTEL, Adalid.Track.DICE]
	var margin := 6
	match difficulty:
		Difficulty.PRINCIPIANTE: margin = 14
		Difficulty.PROFESIONAL: margin = 3
	for _i in 3:
		for track in tracks:
			if a.can_upgrade(track) and a.eter >= a.upgrade_cost(track) + margin:
				a.upgrade(track)
				log.append("  %s mejora %s." % [a.display_name, Adalid.track_label(track)])
	var offer := _draw_market(a)
	var bought: PackedStringArray = []
	var scores := {}
	for card in offer:
		scores[card] = card_score(a, card) + _ai_noise()
	# El profesional refresca una vez si la oferta es floja.
	if difficulty == Difficulty.PROFESIONAL and a.can_pay(Rules.MARKET_REFRESH_COST + 3):
		var best := 0.0
		for card in offer:
			best = maxf(best, scores[card])
		if best < 9.0:
			a.pay(Rules.MARKET_REFRESH_COST)
			deck.put_back(offer)
			offer = _draw_market(a)
			scores.clear()
			for card in offer:
				scores[card] = card_score(a, card)
			log.append("  %s refresca el mercado." % a.display_name)
	var ranked := offer.duplicate()
	ranked.sort_custom(func(x: ChampionData, y: ChampionData) -> bool: return scores[x] > scores[y])
	var max_buys := 1 if difficulty == Difficulty.PRINCIPIANTE else 99
	for card in ranked:
		if bought.size() >= max_buys:
			break
		if a.buy(card):
			offer.erase(card)
			bought.append(card.display_name)
	deck.put_back(offer)
	if not bought.is_empty():
		log.append("  %s compra: %s." % [a.display_name, ", ".join(bought)])


## Alineación automática: los más fuertes, cuerpo a cuerpo delante y los de alcance detrás.
static func auto_lineup(a: Adalid) -> Dictionary:
	var chosen := pick_squad(a)
	var lineup := {}
	var front_cols: Array = [2, 1, 3, 0, 4]
	var used := {}
	for ch in chosen:
		var row := 1 if ch.data.reach() == 1 else (3 if ch.data.reach() >= 3 else 2)
		var placed := false
		for r in [row, 2, 1, 3]:
			for col in front_cols:
				var key := Vector2i(col, r)
				if not used.has(key):
					used[key] = true
					lineup[key] = ch
					placed = true
					break
			if placed:
				break
	return lineup
