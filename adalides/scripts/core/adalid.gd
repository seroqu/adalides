class_name Adalid
extends RefCounted
## Un jugador: vitalidad, Éter, racha, nivel y reserva de cartas.

var display_name: String
var vitality: int = Rules.STARTING_VITALITY
var eter: int = Rules.STARTING_ETER
var streak: int = 0
var level: int = 1
var reserve: Array[ChampionData] = []


func _init(p_name: String) -> void:
	display_name = p_name


func is_eliminated() -> bool:
	return vitality <= 0


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


func buy(card: ChampionData) -> bool:
	if not pay(card.cost):
		return false
	reserve.append(card)
	return true


func summary() -> String:
	return "%s — vida %d, Éter %d, racha %d, nivel %d, reserva %d" % [
		display_name, vitality, eter, streak, level, reserve.size()]
