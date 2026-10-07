class_name Dice
extends RefCounted
## Tiradas de d6 y su clasificación (pifia / fallo / acierto / crítico).

enum Result { PIFIA, FALLO, ACIERTO, CRITICO }


static func roll(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(1, Rules.DICE_SIDES)


static func roll_many(rng: RandomNumberGenerator, count: int) -> Array[int]:
	var rolls: Array[int] = []
	for _i in count:
		rolls.append(roll(rng))
	return rolls


static func classify(value: int) -> Result:
	if value <= Rules.PIFIA:
		return Result.PIFIA
	if value >= Rules.CRITICO:
		return Result.CRITICO
	if value >= Rules.ACIERTO_MIN:
		return Result.ACIERTO
	return Result.FALLO


## Un crítico también cuenta como acierto.
static func is_hit(value: int) -> bool:
	return value >= Rules.ACIERTO_MIN


static func count_hits(rolls: Array[int]) -> int:
	var hits := 0
	for r in rolls:
		if is_hit(r):
			hits += 1
	return hits
