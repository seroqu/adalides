class_name Economy
extends RefCounted
## Reglas de Éter (README: "Economía de Éter"). Funciones puras para poder probarlas.


## Éter que recibe un adalid al inicio de una ronda de preparación.
static func round_income(adalid: Adalid) -> int:
	return Rules.ROUND_INCOME + interest(adalid) + streak_bonus(adalid)


## SUPUESTO: "3 interés" se interpreta como 3 de Éter si se tiene Éter ahorrado.
## Cristalizar lo anula 3 turnos; Encantamiento lo baja a 2.
static func interest(adalid: Adalid) -> int:
	if adalid.eter <= 0 or adalid.no_interest_rounds > 0:
		return 0
	if adalid.interest_override >= 0:
		return adalid.interest_override
	return Rules.INTEREST


## "En racha 2 por racha": 2 de Éter por cada victoria consecutiva.
static func streak_bonus(adalid: Adalid) -> int:
	return Rules.STREAK_BONUS * adalid.streak


static func apply_round_income(adalid: Adalid) -> int:
	var income := round_income(adalid)
	adalid.add_eter(income)
	if adalid.no_interest_rounds > 0:
		adalid.no_interest_rounds -= 1
	return income


static func reward_winner(adalid: Adalid) -> void:
	adalid.add_eter(Rules.WIN_REWARD)
	adalid.streak += 1


static func punish_loser(adalid: Adalid, damage: int) -> void:
	adalid.streak = 0
	adalid.lose_vitality(damage)
