class_name Champion
extends RefCounted
## Un campeón en juego: carta + estado (vida actual, congelado, sigilo, duplicados).

var data: ChampionData
var duplicates: int = 0 # Copias adicionales (README: "Duplicar cartas").
var defense_left: int
var frozen: bool = false
var stealth: bool = false
var alive: bool = true
## Modificadores de daño recibido este asalto (los rellenan las acciones defensivas).
var dodging: bool = false
var blocked_by: Champion = null


func _init(p_data: ChampionData, p_duplicates := 0) -> void:
	data = p_data
	duplicates = p_duplicates
	defense_left = max_defense()


func bonus() -> int:
	return duplicates * Rules.DUPLICATE_BONUS.get(data.tier, 0)


func attack() -> int:
	var atk := data.attack + bonus()
	if stealth and data.has_class(Rules.ClassType.ASESINO):
		atk *= 2 # Los asesinos hacen el doble de daño al salir de sigilo.
	return atk


func max_defense() -> int:
	return data.defense + bonus()


func take_damage(amount: int) -> int:
	if amount <= 0 or not alive:
		return 0
	var dealt: int = mini(amount, defense_left)
	defense_left -= dealt
	if defense_left <= 0:
		alive = false
	return dealt


func heal(amount: int) -> void:
	defense_left = mini(defense_left + amount, max_defense())
	if defense_left > 0:
		alive = true


func can_act() -> bool:
	return alive and not frozen


func reset_round_flags() -> void:
	dodging = false
	blocked_by = null


func label() -> String:
	var tags: PackedStringArray = []
	if frozen:
		tags.append("congelado")
	if stealth:
		tags.append("sigilo")
	if not alive:
		tags.append("muerto")
	var suffix := "" if tags.is_empty() else " (" + ", ".join(tags) + ")"
	return "%s %d/%d%s" % [data.display_name, defense_left, max_defense(), suffix]
