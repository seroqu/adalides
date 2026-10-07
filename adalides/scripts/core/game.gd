class_name Game
extends RefCounted
## Estado de una partida y utilidades para montar combates de prueba.

var adalids: Array[Adalid] = []
var round_no: int = 0
var rng := RandomNumberGenerator.new()


func _init(names: PackedStringArray, seed_value: int = 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	for n in names:
		adalids.append(Adalid.new(n))


func alive_adalids() -> Array[Adalid]:
	var out: Array[Adalid] = []
	for a in adalids:
		if not a.is_eliminated():
			out.append(a)
	return out


## Fase de preparación: cada adalid cobra su Éter de ronda.
func start_round() -> void:
	round_no += 1
	for a in alive_adalids():
		Economy.apply_round_income(a)


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
