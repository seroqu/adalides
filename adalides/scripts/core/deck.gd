class_name Deck
extends RefCounted
## La baraja del demiurgo: todas las cartas disponibles para la tienda.

var cards: Array[ChampionData] = []
var rng: RandomNumberGenerator


func _init(p_rng: RandomNumberGenerator, catalog: Array[ChampionData] = []) -> void:
	rng = p_rng
	var source := catalog if not catalog.is_empty() else Catalog.all()
	for card in source:
		for _i in Rules.DECK_COPIES.get(card.tier, 1):
			cards.append(card)
	shuffle()


func shuffle() -> void:
	# Fisher-Yates con el RNG de la partida para que sea reproducible.
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


func size() -> int:
	return cards.size()


func draw(count: int) -> Array[ChampionData]:
	var out: Array[ChampionData] = []
	for _i in mini(count, cards.size()):
		out.append(cards.pop_back())
	return out


func put_back(returned: Array[ChampionData]) -> void:
	for card in returned:
		cards.insert(rng.randi_range(0, cards.size()), card)
