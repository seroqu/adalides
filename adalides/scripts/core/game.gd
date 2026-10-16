class_name Game
extends RefCounted
## Una partida v2: ciclos de draft → mercado/mejoras → alineación → batallas
## según la tabla. Máquina de estados con un jugador humano opcional; sin
## humano, `play_cycle()` lo hace todo con la IA.

enum State { IDLE, DRAFT, MARKET, LINEUP, BATTLE, CYCLE_END, OVER }

var adalids: Array[Adalid] = []
var deck: Deck
var cycle: int = 0
var rng := RandomNumberGenerator.new()
var log: PackedStringArray = []
var last_battles: Array[Battle] = []
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
	log.append("##### Ciclo %d #####" % cycle)
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
	_run_draft()
	return true


## Ejecuta picks de IA hasta que toque al humano o se acabe el draft.
func _run_draft() -> void:
	while not draft_order.is_empty():
		var a: Adalid = draft_order[0]
		if a == human:
			return
		draft_order.pop_front()
		var card := ai_pick(a, draft_pool)
		if card != null:
			draft_pool.erase(card)
			a.add_card(card)
			log.append("%s toma %s en el draft." % [a.display_name, card.display_name])
	deck.put_back(draft_pool)
	draft_pool.clear()
	_begin_market()


func human_draft_pick(card: ChampionData) -> bool:
	if state != State.DRAFT or draft_order.is_empty() or draft_order[0] != human or not draft_pool.has(card):
		return false
	if not human.can_add(card):
		return false
	draft_order.pop_front()
	draft_pool.erase(card)
	human.add_card(card)
	log.append("%s toma %s en el draft." % [human.display_name, card.display_name])
	_run_draft()
	return true


func _begin_market() -> void:
	for a in alive_adalids():
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


func _draw_market(a: Adalid) -> Array[ChampionData]:
	return deck.draw(Rules.MARKET_SIZE, a.hero_slots() > a.hero_count())


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
			current_battle = Battle.new(human, opp, [human_lineup, auto_lineup(opp)], rng, cycle)
			current_battle.start()
			current_battle.begin_round()
			state = State.BATTLE
			return state
		var battle := Battle.new(a, b, [auto_lineup(a), auto_lineup(b)], rng, cycle)
		battle.run()
		_after_battle(battle)
	_end_cycle()
	return state


## Resuelve el asalto en curso con la asignación { Champion: Rules.Die } del humano.
func commit_human_dice(assignment: Dictionary) -> void:
	if state != State.BATTLE or current_battle == null:
		return
	current_battle.commit_round([assignment, current_battle.auto_assign(1)])
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

## Puntúa una carta para un adalid: sinergia con lo que ya tiene y valor por coste.
static func card_score(a: Adalid, card: ChampionData) -> float:
	var elems := Tiers.count_elements(a.cuartel)
	var archs := Tiers.count_archetypes(a.cuartel)
	var score := 0.0
	if card.element >= 0:
		score += elems.get(card.element, 0)
	for arch in card.archetypes():
		score += archs.get(arch, 0)
	var owned := a.find_card(card.id)
	if owned != null:
		score += 2.0 # Duplicar da +1/+1 y mejora el poder.
	return score + (card.attack + card.defense) / float(maxi(card.cost, 1))


func ai_pick(a: Adalid, pool: Array[ChampionData]) -> ChampionData:
	var best: ChampionData = null
	var best_score := -1.0
	for card in pool:
		if not a.can_add(card):
			continue
		var s := card_score(a, card)
		if s > best_score:
			best = card
			best_score = s
	return best


func ai_market(a: Adalid) -> void:
	# Mejoras: si sobra Éter, alterna cuartel → batalla → dados.
	var tracks: Array = [Adalid.Track.BATTLE, Adalid.Track.CUARTEL, Adalid.Track.DICE]
	for _i in 3:
		for track in tracks:
			if a.can_upgrade(track) and a.eter >= a.upgrade_cost(track) + 6:
				a.upgrade(track)
				log.append("  %s mejora %s." % [a.display_name, Adalid.track_label(track)])
	var offer := _draw_market(a)
	var bought: PackedStringArray = []
	var ranked := offer.duplicate()
	ranked.sort_custom(func(x: ChampionData, y: ChampionData) -> bool: return card_score(a, x) > card_score(a, y))
	for card in ranked:
		if a.buy(card):
			offer.erase(card)
			bought.append(card.display_name)
	deck.put_back(offer)
	if not bought.is_empty():
		log.append("  %s compra: %s." % [a.display_name, ", ".join(bought)])


## Alineación automática: los más fuertes, cuerpo a cuerpo delante y los de alcance detrás.
static func auto_lineup(a: Adalid) -> Dictionary:
	var chosen := a.cuartel.duplicate()
	chosen.sort_custom(func(x: Champion, y: Champion) -> bool: return x.attack() + x.max_hp() > y.attack() + y.max_hp())
	chosen = chosen.slice(0, a.battle_size())
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
