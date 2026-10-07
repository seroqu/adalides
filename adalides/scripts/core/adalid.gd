class_name Adalid
extends RefCounted
## Un jugador: vitalidad, Éter, racha, nivel, reserva y efectos de estertores.

var display_name: String
var vitality: int = Rules.STARTING_VITALITY
var eter: int = Rules.STARTING_ETER
var streak: int = 0
var level: int = 1
var reserve: Array[Champion] = []
var eliminated: bool = false

# --- Efectos de estertores (README: "Muerte de un adalid y estertores") ---
var no_interest_rounds: int = 0 # Cristalizar
var interest_override: int = -1 # Encantamiento: el interés produce solo 2
var sell_value_override: int = -1 # Deshonor: vender da 1
var poisoned: bool = false # Veneno
var cannot_buy_from_dead: bool = false # Vientos en contra
var ghost: bool = false # Fantasma
var kidnapped: Champion = null # Secuestro


func _init(p_name: String) -> void:
	display_name = p_name


func is_eliminated() -> bool:
	return eliminated


func lose_vitality(amount: int) -> void:
	vitality = maxi(vitality - amount, 0)


func gain_vitality(amount: int) -> void:
	vitality += amount


func add_eter(amount: int) -> void:
	eter += amount


func can_pay(amount: int) -> bool:
	return eter >= amount


func pay(amount: int) -> bool:
	if not can_pay(amount):
		return false
	eter -= amount
	return true


## Mete una carta en la reserva; si ya se tiene, se duplica (+1/+1, +3/+3, +5/+5).
func add_card(card: ChampionData) -> Champion:
	var owned := find_card(card.id)
	if owned != null and Rules.DUPLICATE_BONUS.get(card.tier, 0) > 0:
		owned.duplicates += 1
		return owned
	var ch := Champion.new(card)
	reserve.append(ch)
	return ch


func buy(card: ChampionData) -> bool:
	if not pay(card.cost):
		return false
	add_card(card)
	return true


func sell_value(ch: Champion) -> int:
	if sell_value_override >= 0:
		return sell_value_override
	return maxi(ch.data.cost / Rules.SELL_DIVISOR, 1)


func sell(ch: Champion) -> int:
	var value := sell_value(ch)
	remove_card(ch)
	add_eter(value)
	return value


func remove_card(ch: Champion) -> void:
	reserve.erase(ch)
	if kidnapped == ch:
		kidnapped = null


func find_card(id: StringName) -> Champion:
	for ch in reserve:
		if ch.data.id == id:
			return ch
	return null


func cards_of_class(c: int) -> Array[Champion]:
	var out: Array[Champion] = []
	for ch in reserve:
		if ch.data.has_class(c):
			out.append(ch)
	return out


## Cartas que se pueden colocar en el mapa (no aniquiladas ni secuestradas).
func usable_cards() -> Array[Champion]:
	var out: Array[Champion] = []
	for ch in reserve:
		if not ch.annihilated and ch != kidnapped:
			out.append(ch)
	return out


func can_level_up() -> bool:
	return level < Rules.MAX_LEVEL and can_pay(Rules.LEVEL_UP_COST)


func level_up() -> bool:
	if not can_level_up():
		return false
	pay(Rules.LEVEL_UP_COST)
	level += 1
	return true


func summary() -> String:
	var state := " [eliminado]" if eliminated else (" [fantasma]" if ghost else "")
	return "%s%s — vida %d, Éter %d, racha %d, nivel %d, reserva %d" % [
		display_name, state, vitality, eter, streak, level, reserve.size()]
