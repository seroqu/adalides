class_name Adalid
extends RefCounted
## Un jugador: tablero personal (vida, Éter, racha, pistas de mejora) y cuartel.

enum Track { CUARTEL, BATTLE, DICE }
const TRACK_LABELS := { Track.CUARTEL: "el cuartel", Track.BATTLE: "los campeones en batalla", Track.DICE: "los dados" }


static func track_label(track: int) -> String:
	return TRACK_LABELS.get(track, "?")

var display_name: String
var life: int = Rules.STARTING_LIFE
var eter: int = Rules.STARTING_ETER
var streak: int = 0 # Victorias o derrotas seguidas.
var streak_is_win: bool = true
var eliminated: bool = false
var battles_played: int = 0
## Mejoras hechas en cada pista (índice en CUARTEL_TRACK / BATTLE_TRACK / DICE_TRACK).
var upgrades := { Track.CUARTEL: 0, Track.BATTLE: 0, Track.DICE: 0 }
var cuartel: Array[Champion] = [] # Una entrada por carta distinta; `copies` cuenta las repetidas.
var is_ai: bool = true


func _init(p_name: String) -> void:
	display_name = p_name


# ---------------------------------------------------------------- pistas

## Capacidad del cuartel (cartas base, contando copias).
func cuartel_capacity() -> int:
	var cap := 0
	for i in upgrades[Track.CUARTEL] + 1:
		if Rules.CUARTEL_TRACK[i] is int:
			cap = Rules.CUARTEL_TRACK[i]
	return cap


## Huecos de héroe desbloqueados (casillas "H" alcanzadas).
func hero_slots() -> int:
	var slots := 0
	for i in upgrades[Track.CUARTEL] + 1:
		if Rules.CUARTEL_TRACK[i] is String:
			slots += 1
	return slots


func battle_size() -> int:
	return Rules.BATTLE_TRACK[upgrades[Track.BATTLE]]


func dice_count() -> int:
	return Rules.DICE_TRACK[upgrades[Track.DICE]]


func track_length(track: Track) -> int:
	match track:
		Track.CUARTEL: return Rules.CUARTEL_TRACK.size()
		Track.BATTLE: return Rules.BATTLE_TRACK.size()
		_: return Rules.DICE_TRACK.size()


func can_upgrade(track: Track) -> bool:
	return upgrades[track] < track_length(track) - 1


func upgrade_cost(track: Track) -> int:
	return Rules.upgrade_cost(upgrades[track])


func upgrade(track: Track) -> bool:
	if not can_upgrade(track) or not pay(upgrade_cost(track)):
		return false
	upgrades[track] += 1
	return true


## Venganza pirata (sabotaje): baja un marcador del enemigo.
func downgrade(track: Track) -> bool:
	if upgrades[track] <= 0:
		return false
	upgrades[track] -= 1
	return true


# ---------------------------------------------------------------- vida y Éter

func is_eliminated() -> bool:
	return eliminated


func lose_life(amount: int) -> void:
	life = maxi(life - amount, 0)


func gain_life(amount: int) -> void:
	life += amount


func add_eter(amount: int) -> void:
	eter = maxi(eter + amount, 0)


func can_pay(amount: int) -> bool:
	return eter >= amount


func pay(amount: int) -> bool:
	if not can_pay(amount):
		return false
	eter -= amount
	return true


func interest() -> int:
	return Rules.INTEREST * (eter / Rules.INTEREST_PER)


func streak_bonus() -> int:
	return Rules.STREAK_TRACK[mini(streak, Rules.STREAK_TRACK.size() - 1)]


## Ingreso de un ciclo: 10 + interés + bono de racha.
func cycle_income() -> int:
	return Rules.CYCLE_INCOME + interest() + streak_bonus()


func record_result(won: bool) -> void:
	battles_played += 1
	if streak > 0 and streak_is_win == won:
		streak += 1
	else:
		streak = 1
		streak_is_win = won


# ---------------------------------------------------------------- cuartel

func find_card(id: StringName) -> Champion:
	for ch in cuartel:
		if ch.data.id == id:
			return ch
	return null


func base_count() -> int:
	var n := 0
	for ch in cuartel:
		if not ch.data.hero:
			n += ch.copies
	return n


func hero_count() -> int:
	var n := 0
	for ch in cuartel:
		if ch.data.hero:
			n += 1
	return n


## ¿Cabe una copia más de esta carta?
func can_add(card: ChampionData) -> bool:
	var owned := find_card(card.id)
	if owned != null and owned.copies >= Rules.MAX_COPIES:
		return false
	if card.hero:
		return owned != null or hero_count() < hero_slots()
	return base_count() < cuartel_capacity()


func add_card(card: ChampionData) -> Champion:
	var owned := find_card(card.id)
	if owned != null:
		owned.copies += 1
		return owned
	var ch := Champion.new(card)
	cuartel.append(ch)
	return ch


func buy(card: ChampionData) -> bool:
	if not can_add(card) or not can_pay(card.cost):
		return false
	pay(card.cost)
	add_card(card)
	return true


## SUPUESTO: vender devuelve la mitad del coste (mínimo 1) por copia.
func sell_value(ch: Champion) -> int:
	return maxi(ch.data.cost / 2, 1)


func sell(ch: Champion) -> int:
	var value := sell_value(ch)
	if ch.copies > 1:
		ch.copies -= 1
	else:
		cuartel.erase(ch)
	add_eter(value)
	return value


func remove_card(ch: Champion) -> void:
	cuartel.erase(ch)


func summary() -> String:
	var state := " [eliminado]" if eliminated else ""
	var racha := "" if streak == 0 else " (racha %s %d)" % ["V" if streak_is_win else "D", streak]
	return "%s%s — vida %d, Éter %d%s, cuartel %d/%d, batalla %d, dados %d" % [
		display_name, state, life, eter, racha, base_count(), cuartel_capacity(), battle_size(), dice_count()]
