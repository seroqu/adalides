class_name Game
extends RefCounted
## Una partida completa: rondas de preparación, emparejamiento por 2D10,
## combates, eliminación y estertores. Las decisiones de compra y alineación
## las toma una IA simple (sustituible por la elección del jugador).

var adalids: Array[Adalid] = []
var deck: Deck
var round_no: int = 0
var rng := RandomNumberGenerator.new()
var log: PackedStringArray = []
var last_combats: Array[Combat] = []


func _init(names: PackedStringArray, seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	for n in names:
		adalids.append(Adalid.new(n))
	deck = Deck.new(rng)


func alive_adalids() -> Array[Adalid]:
	var out: Array[Adalid] = []
	for a in adalids:
		if not a.is_eliminated():
			out.append(a)
	return out


func is_over() -> bool:
	return alive_adalids().size() <= 1


func winner() -> Adalid:
	var alive := alive_adalids()
	return alive[0] if alive.size() == 1 else null


# ---------------------------------------------------------------- ronda

## Juega una ronda completa. Devuelve false si la partida ya terminó.
func play_round() -> bool:
	if is_over():
		return false
	round_no += 1
	log.clear()
	last_combats.clear()
	log.append("##### Ronda %d #####" % round_no)
	for a in alive_adalids():
		if a.ghost:
			continue # Fantasma: sin fases de preparación.
		prepare(a)
	var pairs := matchmaking()
	for pair in pairs:
		if pair.size() == 1:
			log.append("%s queda sin rival esta ronda." % pair[0].display_name)
			continue
		_fight(pair[0], pair[1])
	for a in adalids:
		log.append(a.summary())
	if is_over() and winner() != null:
		log.append("¡%s es el nuevo demiurgo!" % winner().display_name)
	return true


## Fase de preparación de un adalid: cobrar, tienda, subir de nivel.
func prepare(a: Adalid) -> void:
	var income := Economy.apply_round_income(a)
	log.append("%s cobra %d de Éter (tiene %d)." % [a.display_name, income, a.eter])
	# Demonio (5): la tienda tiene una carta más.
	var shop_size := Rules.SHOP_SIZE + (1 if Synergy.tier(a.reserve, Rules.ClassType.MAL) >= 5 else 0)
	var shop := deck.draw(shop_size)
	var bought := ai_shop(a, shop)
	for card in bought:
		shop.erase(card)
	deck.put_back(shop)
	if not bought.is_empty():
		var names: PackedStringArray = []
		for card in bought:
			names.append(card.display_name)
		log.append("  Compra: %s." % ", ".join(names))
	# IA: sube de nivel si le sobra Éter tras comprar.
	if a.can_level_up() and a.eter >= Rules.LEVEL_UP_COST + 5 and a.reserve.size() >= 3 * a.level:
		a.level_up()
		log.append("  %s sube a nivel %d." % [a.display_name, a.level])
	# Rescate de un campeón secuestrado si sobra Éter.
	if a.kidnapped != null and a.eter >= Rules.RANSOM_COST + 10:
		a.pay(Rules.RANSOM_COST)
		log.append("  %s paga el rescate de %s." % [a.display_name, a.kidnapped.data.display_name])
		a.kidnapped = null


## IA de compra: prioriza cartas de las clases que ya tiene y las más baratas.
func ai_shop(a: Adalid, shop: Array[ChampionData]) -> Array[ChampionData]:
	var counts := Synergy.count_by_class(a.reserve)
	var ranked := shop.duplicate()
	ranked.sort_custom(func(x: ChampionData, y: ChampionData) -> bool:
		return _card_score(x, counts) > _card_score(y, counts))
	var bought: Array[ChampionData] = []
	for card in ranked:
		if _can_use_eventually(a, card) and a.buy(card):
			bought.append(card)
	return bought


func _card_score(card: ChampionData, counts: Dictionary) -> float:
	var score := 0.0
	for c in card.classes:
		score += counts.get(c, 0)
	return score + (card.attack + card.defense) / float(maxi(card.cost, 1))


## No compra elementales/héroes que no podrá colocar a corto plazo.
func _can_use_eventually(a: Adalid, card: ChampionData) -> bool:
	match card.tier:
		Rules.Tier.ELEMENTAL:
			return a.level >= 2 or a.reserve.size() >= 4
		Rules.Tier.HEROE, Rules.Tier.LEGENDARIO:
			return a.level >= 3
	return true


# ---------------------------------------------------------------- emparejamiento

## Cada adalid lanza 2D10; se enfrentan los dos mayores, luego el tercero y
## cuarto, etc. Si alguien queda sin pareja, descansa.
func matchmaking() -> Array[Array]:
	var rolls: Array[Dictionary] = []
	for a in alive_adalids():
		var r := rng.randi_range(1, 10) + rng.randi_range(1, 10)
		rolls.append({ "adalid": a, "roll": r, "tie": rng.randf() })
		log.append("%s lanza 2D10: %d." % [a.display_name, r])
	rolls.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return x["roll"] > y["roll"] if x["roll"] != y["roll"] else x["tie"] > y["tie"])
	var pairs: Array[Array] = []
	var i := 0
	while i < rolls.size():
		if i + 1 < rolls.size():
			pairs.append([rolls[i]["adalid"], rolls[i + 1]["adalid"]])
		else:
			pairs.append([rolls[i]["adalid"]])
		i += 2
	return pairs


# ---------------------------------------------------------------- combate

func _fight(a: Adalid, b: Adalid) -> void:
	var board_a := Roster.build_board(a, Roster.auto_pick(a))
	var board_b := Roster.build_board(b, Roster.auto_pick(b))
	var combat := Combat.new(board_a, board_b, rng)
	var result := combat.run()
	last_combats.append(combat)
	log.append_array(combat.log)
	_purge_annihilated(a)
	_purge_annihilated(b)
	for pair in [[a, b], [b, a]]:
		var victim: Adalid = pair[0]
		var other: Adalid = pair[1]
		if victim.vitality <= 0 and not victim.eliminated and not victim.ghost:
			_eliminate(victim, other if result["winner"] == other else null)


func _purge_annihilated(a: Adalid) -> void:
	for ch in a.reserve.duplicate():
		if ch.annihilated:
			a.remove_card(ch)
			deck.put_back([ch.data])


## Eliminación: estertor para el asesino y compra de la reserva del muerto.
func _eliminate(victim: Adalid, killer: Adalid) -> void:
	victim.eliminated = true
	log.append("%s se desintegra en Éter." % victim.display_name)
	if killer == null:
		_return_reserve(victim)
		return
	log.append_array(DeathRattle.apply(killer, victim, rng))
	if victim.eliminated and not victim.ghost:
		if not killer.cannot_buy_from_dead:
			var cards := victim.reserve.duplicate()
			cards.sort_custom(func(x: Champion, y: Champion) -> bool: return x.data.cost > y.data.cost)
			for ch in cards:
				if killer.buy(ch.data):
					victim.remove_card(ch)
					log.append("  %s compra a %s de la reserva de %s." % [killer.display_name, ch.data.display_name, victim.display_name])
		_return_reserve(victim)


func _return_reserve(victim: Adalid) -> void:
	var returned: Array[ChampionData] = []
	for ch in victim.reserve:
		returned.append(ch.data)
	victim.reserve.clear()
	deck.put_back(returned)


# ---------------------------------------------------------------- utilidades de prueba

## Monta un mapa aleatorio con `count` cartas comunes del catálogo.
func random_board(adalid: Adalid, count: int = Rules.BOARD_SIZE, pool: Array[ChampionData] = []) -> Battlefield:
	var board := Battlefield.new(adalid)
	var cards := pool if not pool.is_empty() else Catalog.by_tier(Rules.Tier.COMUN)
	for i in mini(count, Rules.BOARD_SIZE):
		var card := cards[rng.randi_range(0, cards.size() - 1)]
		board.place(Champion.new(card), i)
	return board


## Mapa con cartas concretas por id (null deja la casilla vacía).
static func board_from_ids(adalid: Adalid, ids: Array) -> Battlefield:
	var board := Battlefield.new(adalid)
	for i in mini(ids.size(), Rules.BOARD_SIZE):
		if ids[i] != null:
			board.place(Champion.new(Catalog.by_id(ids[i])), i)
	return board


## Combate entre dos adalides con mapas aleatorios. Devuelve el Combat ya resuelto.
func quick_combat(a: Adalid, b: Adalid) -> Combat:
	var combat := Combat.new(random_board(a), random_board(b), rng)
	combat.run()
	return combat
