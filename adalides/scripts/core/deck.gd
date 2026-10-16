class_name Deck
extends RefCounted
## El mazo del demiurgo. SUPUESTO: 4 copias de cada carta base y 1 de cada héroe.

const BASE_COPIES := 4
const HERO_COPIES := 1

var cards: Array[ChampionData] = []
var rng: RandomNumberGenerator


func _init(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	for card in Catalog.all():
		for _i in (HERO_COPIES if card.hero else BASE_COPIES):
			cards.append(card)
	shuffle()


func shuffle() -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp


func size() -> int:
	return cards.size()


func draw(count: int, allow_heroes := true) -> Array[ChampionData]:
	var out: Array[ChampionData] = []
	var skipped: Array[ChampionData] = []
	while out.size() < count and not cards.is_empty():
		var card: ChampionData = cards.pop_back()
		if card.hero and not allow_heroes:
			skipped.append(card)
		else:
			out.append(card)
	put_back(skipped)
	return out


func put_back(returned: Array[ChampionData]) -> void:
	for card in returned:
		cards.insert(rng.randi_range(0, cards.size()), card)


func take_top(count: int) -> Array[ChampionData]:
	return draw(count)
