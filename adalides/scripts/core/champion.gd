class_name Champion
extends RefCounted
## Un campeón de la reserva de un adalid: carta + copias + estado de combate.

var data: ChampionData
var duplicates: int = 0 # Copias adicionales (README: "Duplicar cartas").
var charges: int = 0 # Contadores de carga eléctrica (+1/+1 cada uno).
var annihilated: bool = false # Volvió a la baraja del demiurgo.

# --- Estado que se reinicia en cada combate ---
var defense_left: int
var frozen: bool = false
var frozen_turns: int = 0 # >0: se descongela solo al pasar los turnos.
var stealth: bool = false
var permanent_stealth: bool = false
var alive: bool = true
var doubled: bool = false # Mago de plasma 1-2: duplica su daño.
var extra_attack: int = 0 # Bonos de sinergia fijados al empezar el combate.
var extra_defense: int = 0
var dodging: bool = false
var blocked_by: Champion = null
var killer: Champion = null


func _init(p_data: ChampionData, p_duplicates := 0) -> void:
	data = p_data
	duplicates = p_duplicates
	reset_for_combat()


func reset_for_combat() -> void:
	frozen = false
	frozen_turns = 0
	stealth = false
	permanent_stealth = false
	alive = not annihilated
	doubled = false
	extra_attack = 0
	extra_defense = 0
	killer = null
	reset_round_flags()
	defense_left = max_defense()


func bonus() -> int:
	return duplicates * Rules.DUPLICATE_BONUS.get(data.tier, 0)


func attack() -> int:
	var atk := data.attack + bonus() + charges + extra_attack
	if stealth and data.has_class(Rules.ClassType.ASESINO):
		atk *= 2 # Los asesinos hacen el doble de daño al salir de sigilo.
	if doubled:
		atk *= 2
	return atk


func max_defense() -> int:
	return data.defense + bonus() + charges + extra_defense


func take_damage(amount: int, source: Champion = null) -> int:
	if amount <= 0 or not alive:
		return 0
	var dealt: int = mini(amount, defense_left)
	defense_left -= dealt
	if defense_left <= 0:
		alive = false
		killer = source
	return dealt


func heal(amount: int) -> void:
	if annihilated:
		return
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
	var copies := "" if duplicates == 0 else " x%d" % (duplicates + 1)
	return "%s%s %d/%d%s" % [data.display_name, copies, defense_left, max_defense(), suffix]
