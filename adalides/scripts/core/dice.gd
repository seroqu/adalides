class_name Dice
extends RefCounted
## Dados de poder (dos d3: −/neutra/+), d6 auxiliar y d20.


static func roll(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, Rules.DICE_SIDES)


static func roll_d20(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, 20)


static func roll_many(rng: RandomNumberGenerator, count: int) -> Array[int]:
	var rolls: Array[int] = []
	for _i in count:
		rolls.append(roll(rng))
	return rolls


## Una cara de d3: −1, 0 o +1.
static func roll_d3(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(-1, 1)


## Tirada de poder: dos d3 sumados → Rules.Die.
static func roll_die(rng: RandomNumberGenerator) -> Rules.Die:
	return classify_sum(roll_d3(rng) + roll_d3(rng))


static func roll_dice(rng: RandomNumberGenerator, count: int) -> Array:
	var out: Array = []
	for _i in count:
		out.append(roll_die(rng))
	return out


static func classify_sum(total: int) -> Rules.Die:
	match clampi(total, -2, 2):
		-2: return Rules.Die.PIFIA
		-1: return Rules.Die.FALLO
		0: return Rules.Die.NEUTRO
		1: return Rules.Die.ACIERTO
	return Rules.Die.CRITICO


## Compatibilidad con tiradas de d6 (1 = --, 2-3 = -, 4-5 = +, 6 = ++).
static func classify(value: int) -> Rules.Die:
	if value <= 1:
		return Rules.Die.PIFIA
	if value <= 3:
		return Rules.Die.FALLO
	if value <= 5:
		return Rules.Die.ACIERTO
	return Rules.Die.CRITICO


static func is_hit(value: int) -> bool:
	return value >= 4


static func die_is_hit(d: Rules.Die) -> bool:
	return d >= Rules.Die.ACIERTO


## Hackeo (Robot 6): empeora un rango: ++ → +, + → ○, ○ → -, - → --.
static func worsen(d: Rules.Die) -> Rules.Die:
	return maxi(d - 1, Rules.Die.PIFIA) as Rules.Die


## true si el resultado está entre los que exige un poder, p. ej. [Die.ACIERTO, Die.CRITICO].
static func meets(d: Rules.Die, required: Array) -> bool:
	return required.is_empty() or required.has(d)


## Casilla 1..15 a la que apunta un d20 (SUPUESTO: 16-20 no señalan nada).
static func d20_to_cell(roll: int) -> int:
	return roll if roll <= Rules.BOARD_ROWS * Rules.BOARD_COLS else -1
