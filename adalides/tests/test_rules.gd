extends SceneTree
## Pruebas de las reglas. Ejecutar con:
##   godot --headless --path adalides -s tests/test_rules.gd

var _failures := 0
var _passes := 0


func _init() -> void:
	test_dice()
	test_economy()
	test_synergy()
	test_champion()
	test_catalog()
	test_combat_deterministic()
	test_combat_wipe()
	test_block_overflow()
	print("\n%d pruebas correctas, %d fallos" % [_passes, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if cond:
		_passes += 1
	else:
		_failures += 1
		push_error("FALLO: " + msg)
		print("FALLO: " + msg)


func test_dice() -> void:
	check(Dice.classify(1) == Dice.Result.PIFIA, "1 es pifia")
	check(Dice.classify(3) == Dice.Result.FALLO, "3 es fallo")
	check(Dice.classify(4) == Dice.Result.ACIERTO, "4 es acierto")
	check(Dice.classify(6) == Dice.Result.CRITICO, "6 es crítico")
	check(Dice.is_hit(6), "el crítico también es acierto")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for r in Dice.roll_many(rng, 50):
		check(r >= 1 and r <= 6, "tirada dentro de 1..6")


func test_economy() -> void:
	var a := Adalid.new("A")
	check(a.eter == 20, "Éter inicial 20")
	check(a.vitality == Rules.STARTING_VITALITY, "vitalidad inicial")
	check(Economy.round_income(a) == 10 + 3, "ronda: 10 + 3 de interés")
	a.streak = 2
	check(Economy.round_income(a) == 10 + 3 + 4, "ronda con racha 2: +4")
	Economy.reward_winner(a)
	check(a.eter == 27 and a.streak == 3, "ganar da 7 y sube la racha")
	Economy.punish_loser(a, 5)
	check(a.streak == 0 and a.vitality == Rules.STARTING_VITALITY - 5, "perder resetea racha y quita vida")
	check(a.buy(Catalog.by_id("golem")) and a.eter == 24, "comprar descuenta el coste")
	a.eter = 0
	check(not a.buy(Catalog.by_id("golem")), "no se puede comprar sin Éter")


func test_synergy() -> void:
	check(Synergy.tier_for_count(2) == 0, "2 no activa sinergia")
	check(Synergy.tier_for_count(3) == 3, "3 activa nivel 3")
	check(Synergy.tier_for_count(6) == 5, "6 activa nivel 5")
	check(Synergy.tier_for_count(9) == 7, "9 activa nivel 7")
	var cards: Array = [Catalog.by_id("plasma"), Catalog.by_id("lava"), Catalog.by_id("salamandra")]
	var active := Synergy.active(cards)
	check(active.get(Rules.ClassType.FUEGO, 0) == 3, "plasma + lava + salamandra = Fuego (3)")
	check(not active.has(Rules.ClassType.TIERRA), "una sola tierra no activa")


func test_champion() -> void:
	var ch := Champion.new(Catalog.by_id("lava"), 1)
	check(ch.attack() == 4 + 3 and ch.max_defense() == 8 + 3, "duplicar un elemental da +3/+3")
	var hero := Champion.new(Catalog.by_id("arcangel"), 1)
	check(hero.attack() == 20, "los legendarios no suben de nivel")
	check(ch.take_damage(5) == 5 and ch.alive, "recibe daño y sigue vivo")
	check(ch.take_damage(100) == 6 and not ch.alive, "no se inflige más daño que la vida restante")
	ch.heal(3)
	check(ch.alive and ch.defense_left == 3, "curar en el mismo asalto lo devuelve a la vida")
	var sombra := Champion.new(Catalog.by_id("sombra"))
	sombra.stealth = true
	check(sombra.attack() == 6, "asesino en sigilo hace el doble de daño")
	check(Catalog.by_id("senor_demonio").keywords_for(5) == [Rules.Keyword.ANIQUILA], "señor demonio 4-6 aniquila")
	check(Catalog.by_id("senor_demonio").keywords_for(2) == [Rules.Keyword.MOV], "señor demonio 1-3 mueve")


func test_catalog() -> void:
	var ids := {}
	for c in Catalog.all():
		check(not ids.has(c.id), "id duplicado: %s" % c.id)
		ids[c.id] = true
		check(not c.classes.is_empty(), "%s tiene clase" % c.id)
		var covered := {}
		for row in c.actions:
			for v in range(row["min"], row["max"] + 1):
				check(not covered.has(v), "%s: el valor %d está en dos filas" % [c.id, v])
				covered[v] = true
		for v in range(1, 7):
			check(covered.has(v), "%s: ningún resultado para el DA %d" % [c.id, v])
	check(Catalog.by_tier(Rules.Tier.COMUN).size() == 12, "12 comunes de relleno")
	check(Catalog.by_tier(Rules.Tier.ELEMENTAL).size() == 5, "5 señores elementales")
	check(Catalog.by_tier(Rules.Tier.HEROE).size() == 9, "9 héroes")
	check(Catalog.by_tier(Rules.Tier.LEGENDARIO).size() == 2, "2 legendarios")


func test_combat_deterministic() -> void:
	var g1 := Game.new(["Ana", "Bruno"], 42)
	var g2 := Game.new(["Ana", "Bruno"], 42)
	var c1 := g1.quick_combat(g1.adalids[0], g1.adalids[1])
	var c2 := g2.quick_combat(g2.adalids[0], g2.adalids[1])
	check(c1.log == c2.log, "con la misma semilla el combate es idéntico")
	check(c1.round_no >= 1 and c1.round_no <= Rules.MAX_ROUNDS, "dura entre 1 y 4 asaltos")


func test_combat_wipe() -> void:
	var a := Adalid.new("Fuerte")
	var b := Adalid.new("Débil")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var board_a := Game.board_from_ids(a, ["arcangel", "arcangel", "arcangel", "arcangel", "arcangel", "arcangel"])
	var board_b := Game.board_from_ids(b, ["diablillo", null, null, null, null, null])
	var combat := Combat.new(board_a, board_b, rng)
	var result := combat.run()
	check(result["winner"] == a, "seis arcángeles ganan a un diablillo")
	check(b.vitality < Rules.STARTING_VITALITY, "el perdedor pierde vitalidad")
	check(result["damage"] == board_a.strength() - board_b.strength() + 1, "daño = diferencia de fuerza + 1")
	check(a.eter == 20 + 7 and a.streak == 1, "el ganador cobra 7 y racha 1")


func test_block_overflow() -> void:
	# Un bloqueador que muere pasa el exceso al protegido.
	var atk := Champion.new(Catalog.by_id("arcangel"))
	var guard := Champion.new(Catalog.by_id("escudero"))
	var ward := Champion.new(Catalog.by_id("chispa"))
	var a := Adalid.new("A")
	var b := Adalid.new("B")
	var board_a := Battlefield.new(a)
	board_a.place(atk, 0)
	var board_b := Battlefield.new(b)
	board_b.place(ward, 0)
	board_b.place(guard, 1)
	ward.blocked_by = guard
	var combat := Combat.new(board_a, board_b)
	combat._deal_damage(atk, board_a, ward, board_b, 20, "ataca")
	check(not guard.alive, "el bloqueador muere")
	check(not ward.alive, "el exceso mata al protegido")
