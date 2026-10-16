class_name Champion
extends RefCounted
## Un campeón del cuartel: carta + copias (duplicado / AFI) + estado de batalla.

var data: ChampionData
var copies: int = 1 # 1..4. 2 = duplicado (+1/+1), 3 = AFI 1, 4 = AFI 2.

# --- Estado de batalla (se reinicia con reset_for_battle) ---
var hp: int
var max_hp_bonus: int = 0
var attack_bonus: int = 0 # Permanente durante la batalla (Garras ígneas, Energizar, Marchitar...).
var frozen: int = 0 # Contadores de hielo; en la fase de movimiento se gasta uno y no actúa.
var stealth: bool = false
var cursed: bool = false
var buried: bool = false
var alive: bool = true
var died_this_round: bool = false
var killer: Champion = null
var side: int = -1

# --- Estado de un asalto ---
var die: int = -1 # Rules.Die asignado este asalto (-1: sin dado → ataque normal).
var acted: bool = false
var next_attack_bonus: int = 0
var dodge_basic: bool = false # Viento arrebatado.
var dodge_powers: bool = false # Camuflaje.
var immune: bool = false # Congelación profunda.
var can_move_and_attack: bool = false # Agilidad trémula.
var retribution: int = 0 # Aura de retribución: alcance.
var peace: int = 0 # Aura de paz: alcance.
var incoming_bonus: int = 0 # Enemigo a la vista.
var target: Champion = null


func _init(p_data: ChampionData, p_copies := 1) -> void:
	data = p_data
	copies = p_copies
	reset_for_battle()


func afi() -> int:
	return Rules.AFI_BY_COPIES.get(mini(copies, Rules.MAX_COPIES), 0)


func duplicated() -> bool:
	return copies >= 2


## Índice (0..3) para leer los valores (1 copia / 2 copias / AFI 1 / AFI 2) de un poder.
func power_level() -> int:
	return clampi(copies - 1, 0, 3)


func power_value(default := 0) -> int:
	var values: Array = data.power.get("values", [])
	if values.is_empty():
		return default
	return values[mini(power_level(), values.size() - 1)]


func base_attack() -> int:
	return data.attack + (Rules.DUPLICATE_BONUS if duplicated() else 0) + afi()


func base_defense() -> int:
	return data.defense + (Rules.DUPLICATE_BONUS if duplicated() else 0) + afi()


func attack() -> int:
	return maxi(base_attack() + attack_bonus + next_attack_bonus, 0)


func max_hp() -> int:
	return base_defense() + max_hp_bonus


func reset_for_battle() -> void:
	max_hp_bonus = 0
	attack_bonus = 0
	frozen = 0
	stealth = false
	cursed = false
	buried = false
	alive = true
	killer = null
	hp = max_hp()
	reset_for_round()


func reset_for_round() -> void:
	die = -1
	acted = false
	died_this_round = false
	next_attack_bonus = 0
	dodge_basic = false
	dodge_powers = false
	immune = false
	can_move_and_attack = false
	retribution = 0
	peace = 0
	incoming_bonus = 0
	target = null


func take_damage(amount: int, source: Champion = null) -> int:
	if amount <= 0 or not alive or immune:
		return 0
	var dealt: int = mini(amount, hp)
	hp -= dealt
	if hp <= 0:
		alive = false
		died_this_round = true
		killer = source
	return dealt


func heal(amount: int) -> int:
	if not alive or amount <= 0:
		return 0
	var before := hp
	hp = mini(hp + amount, max_hp())
	return hp - before


func revive(with_hp: int) -> void:
	alive = true
	buried = false
	hp = clampi(with_hp, 1, max_hp())


func can_act() -> bool:
	return alive and frozen == 0 and not buried


func is_targetable() -> bool:
	return alive and not stealth and not buried


func label() -> String:
	var tags: PackedStringArray = []
	if frozen > 0:
		tags.append("congelado")
	if stealth:
		tags.append("sigilo")
	if cursed:
		tags.append("maldito")
	if buried:
		tags.append("sepultado")
	if not alive:
		tags.append("muerto")
	var suffix := "" if tags.is_empty() else " (" + ", ".join(tags) + ")"
	var cp := "" if copies == 1 else " x%d" % copies
	return "%s%s %d/%d%s" % [data.display_name, cp, hp, max_hp(), suffix]
