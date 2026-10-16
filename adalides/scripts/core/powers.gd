class_name Powers
extends RefCounted
## Poderes de personaje (PDF: "Poderes de personaje"). Cada uno recibe la
## batalla y el campeón que lo usa; el nivel (copias/AFI) sale del campeón.
## Los que aún no están implementados se registran y no hacen nada.

const E := Rules.Element
const A := Rules.Archetype

## Poderes que ya hacen algo. Los demás solo se registran; la IA no gasta dados en ellos.
const IMPLEMENTED: Array[StringName] = [
	&"angel_fuego", &"angel_aire", &"angel_trueno", &"angel_tierra",
	&"demonio_fuego", &"demonio_trueno", &"demonio_tierra",
	&"arquero_fuego", &"arquero_hielo", &"arquero_trueno", &"arquero_tierra",
	&"mago_fuego", &"mago_hielo", &"mago_trueno", &"mago_tierra",
	&"defensor_aire", &"defensor_fuego", &"defensor_hielo", &"defensor_trueno",
	&"pirata_fuego", &"pirata_trueno", &"pirata_aire",
	&"muerto_fuego", &"muerto_hielo", &"muerto_trueno",
	&"asesino_fuego", &"asesino_hielo", &"asesino_tierra",
	&"robot_fuego", &"robot_hielo", &"robot_trueno", &"robot_aire",
	&"salvaje_fuego", &"salvaje_hielo", &"salvaje_aire", &"salvaje_tierra",
	&"pirata_muerto", &"salvaje_asesino",
]


static func is_implemented(id: StringName) -> bool:
	return IMPLEMENTED.has(id)


static func use(b: Battle, ch: Champion) -> void:
	var name: String = ch.data.power.get("name", "?")
	var side := ch.side
	var enemy := 1 - side
	var pos := b.board.pos_of(ch)
	var v := ch.power_value()
	var afi := ch.afi()
	b.log_line("  %s usa %s." % [ch.data.display_name, name])
	b.ev({ "type": "power", "ch": ch, "name": name, "element": ch.data.element, "archetype": ch.data.archetype })
	match String(ch.data.id):
		# --- Ángel ---
		"angel_fuego":
			ch.retribution = v
		"angel_aire":
			ch.peace = v
		"angel_trueno":
			for _i in v:
				var row := (Dice.roll(b.rng) - 1) % Board.ROWS + 1 # SUPUESTO: el dado señala la fila.
				for ally in b.board.in_row(row, side):
					var healed := ally.heal(1 + afi)
					if healed > 0:
						b.ev({ "type": "heal", "ch": ally, "amount": healed, "hp": ally.hp })
				b.log_line("    Curación relámpago en la fila %d." % row)
		"angel_tierra":
			var revived := 0
			for dead in b.board.champions(side, false):
				if revived >= v:
					break
				if not dead.alive and dead.died_this_round and Board.distance(pos, b.board.pos_of(dead)) <= 2:
					dead.revive(1 + afi)
					b.ev({ "type": "heal", "ch": dead, "amount": dead.hp, "hp": dead.hp })
					revived += 1
					b.log_line("    %s resucita con %d." % [dead.data.display_name, 1 + afi])
		# --- Demonio ---
		"demonio_fuego":
			b.adalids[side].gain_life(afi)
			for victim in _nearest_enemies(b, pos, enemy, v):
				victim.cursed = true
				b.log_line("    %s queda maldito." % victim.data.display_name)
			ch.take_damage(ch.hp, ch)
			b.log_line("    %s se inmola." % ch.data.display_name)
		"demonio_trueno":
			var harvested := 0
			for _i in v:
				var col := (Dice.roll(b.rng) - 1) % Board.COLS
				for victim in b.board.in_column(col, enemy):
					if victim.cursed:
						victim.take_damage(victim.hp, ch)
						harvested += 1
						b.log_line("    Cosecha oscura se lleva a %s." % victim.data.display_name)
			if harvested > 0 and afi > 0:
				b.adalids[enemy].lose_life(afi)
		"demonio_tierra":
			ch.buried = true
			ch.alive = false
			for victim in b.board.within(pos, v, enemy):
				victim.buried = true
				victim.alive = false
				b.log_line("    %s queda sepultado." % victim.data.display_name)
			for victim in _nearest_enemies(b, pos, enemy, afi):
				victim.cursed = true
		# --- Arquero ---
		"arquero_fuego":
			ch.next_attack_bonus += v + afi
		"arquero_hielo":
			var target := b._choose_target(ch)
			if target != null:
				for victim in b.board.within(b.board.pos_of(target), v, enemy):
					victim.frozen += 1
					b.ev({ "type": "freeze", "ch": victim })
					b.deal_damage(ch, victim, 1 + afi, "hiela a", true)
		"arquero_trueno":
			for _i in v:
				var col := (Dice.roll(b.rng) - 1) % Board.COLS
				for victim in b.board.in_column(col, enemy):
					b.deal_damage(ch, victim, ch.base_attack(), "acribilla a", true)
		"arquero_tierra":
			ch.dodge_powers = true
		# --- Mago ---
		"mago_fuego":
			var target := b._choose_target(ch)
			if target != null:
				b.deal_damage(ch, target, (2 + afi) * ch.attack(), "lanza una bola de fuego a", true)
		"mago_hielo":
			for ally in b.board.within(pos, afi, side):
				ally.immune = true
		"mago_trueno":
			var best: Champion = null
			for ally in b.board.champions(side):
				if best == null or ally.hp > best.hp:
					best = ally
			if best != null:
				best.attack_bonus += v + afi
				b.log_line("    %s gana %d de ataque." % [best.data.display_name, v + afi])
		"mago_tierra":
			for victim in b.board.within(pos, 1, enemy):
				victim.die = -1
				b.log_line("    %s pierde sus habilidades." % victim.data.display_name)
		# --- Defensor (pasivas: solo marcan el estado) ---
		"defensor_aire":
			ch.dodge_basic = true
		"defensor_fuego", "defensor_hielo", "defensor_trueno":
			pass # Se resuelven al recibir ataques (Battle.basic_attack / _after_hit).
		# --- Pirata ---
		"pirata_fuego":
			ch.next_attack_bonus += v
		"pirata_trueno":
			var stolen: int = mini(v + afi, b.adalids[enemy].eter)
			b.adalids[enemy].add_eter(-stolen)
			b.adalids[side].add_eter(stolen)
			b.log_line("    Roba %d de Éter." % stolen)
		"pirata_aire":
			var target := b._choose_target(ch)
			if target != null:
				target.incoming_bonus += v
		# --- Muerto ---
		"muerto_fuego":
			var target := b._choose_target(ch)
			if target != null and Board.distance(pos, b.board.pos_of(target)) <= ch.data.reach():
				var left: int = maxi(v - afi, 0)
				if target.hp > left:
					b.deal_damage(ch, target, target.hp - left, "funde a", true)
		"muerto_hielo":
			for victim in b.board.within(pos, v, enemy):
				if not victim.acted:
					victim.acted = true
					victim.die = -1
					b.log_line("    %s pierde el turno por el miedo." % victim.data.display_name)
		"muerto_trueno":
			for victim in b.board.champions(enemy):
				var cap: int = v * victim.attack()
				if victim.hp > cap:
					b.deal_damage(ch, victim, victim.hp - cap, "drena a", true)
		# --- Asesino ---
		"asesino_fuego", "asesino_hielo":
			var target := b._choose_target(ch)
			if target == null:
				return
			ch.acted = false # Hace su ataque y además el corte.
			b.basic_attack(ch, target)
			ch.acted = true
			var dir := b.board.pos_of(target) - pos
			dir = Vector2i(signi(dir.x), signi(dir.y)) if (dir.x == 0 or dir.y == 0) else Vector2i(0, signi(dir.y))
			var cell := b.board.pos_of(target)
			for _i in v:
				cell += dir
				var victim := b.board.at(cell)
				if victim != null and victim.side == enemy and victim.alive:
					if ch.data.element == E.FUEGO:
						b.deal_damage(ch, victim, ch.attack(), "corta a", true)
					else:
						victim.frozen += 1
						b.ev({ "type": "freeze", "ch": victim })
						b.log_line("    %s queda congelado." % victim.data.display_name)
		"asesino_tierra":
			for ally in b.board.within(pos, v, side):
				ally.stealth = true
			b.log_line("    Sus aliados cercanos entran en sigilo.")
		# --- Robot ---
		"robot_fuego":
			var wounded := 0
			for victim in b.board.within(pos, v, enemy):
				if b.deal_damage(ch, victim, 1 + afi, "escalda a", true) > 0:
					wounded += 1
			if wounded > 0:
				b._produce(side, wounded, ch)
		"robot_hielo":
			var frozen := 0
			for victim in b.board.within(pos, v):
				if victim != ch:
					victim.frozen += 1
					b.ev({ "type": "freeze", "ch": victim })
					frozen += 1
			if frozen > 0:
				b._produce(side, frozen, ch)
		"robot_trueno", "robot_aire":
			pass # Pasivas: producen al recibir daño / al esquivar.
		# --- Salvaje ---
		"salvaje_fuego":
			ch.attack_bonus += 1 + afi
		"salvaje_hielo":
			var target := b._choose_target(ch)
			if target != null:
				for victim in b.board.within(b.board.pos_of(target), v, enemy):
					if victim.frozen > 0:
						victim.frozen = 0
						b.deal_damage(ch, victim, v + afi, "quiebra a", true)
		"salvaje_aire":
			ch.can_move_and_attack = true
		"salvaje_tierra":
			pass # Se consulta en Battle._spike_bonus.
		# --- Héroes ---
		"pirata_muerto":
			pass # Se resuelve al final de la batalla.
		"salvaje_asesino":
			for victim in b.board.champions(enemy):
				if victim.is_targetable():
					b.deal_damage(ch, victim, ch.attack(), "despedaza a", true)
			ch.take_damage(ch.hp, ch)
			b.log_line("    %s muere tras el frenesí." % ch.data.display_name)
		_:
			b.log_line("    (%s aún no está implementado)" % name)


static func _nearest_enemies(b: Battle, pos: Vector2i, enemy: int, count: int) -> Array[Champion]:
	var list := b.board.champions(enemy)
	list.sort_custom(func(x: Champion, y: Champion) -> bool:
		return Board.distance(pos, b.board.pos_of(x)) < Board.distance(pos, b.board.pos_of(y)))
	var out: Array[Champion] = []
	out.assign(list.slice(0, count))
	return out
