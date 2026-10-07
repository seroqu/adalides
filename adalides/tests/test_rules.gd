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
	test_reserve_and_shop()
	test_deck()
	test_roster()
	test_death_rattle()
	test_full_game()
	test_human_flow()
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
	a.no_interest_rounds = 1
	check(Economy.interest(a) == 0, "Cristalizar anula el interés")
	a.no_interest_rounds = 0
	a.interest_override = 2
	check(Economy.interest(a) == 2, "Encantamiento baja el interés a 2")
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
	combat.deal_damage(atk, board_a, ward, board_b, 20, "ataca")
	check(not guard.alive, "el bloqueador muere")
	check(not ward.alive, "el exceso mata al protegido")


func test_reserve_and_shop() -> void:
	var a := Adalid.new("A")
	a.eter = 100
	a.buy(Catalog.by_id("lobo"))
	a.buy(Catalog.by_id("lobo"))
	check(a.reserve.size() == 1 and a.reserve[0].duplicates == 1, "comprar dos veces la misma carta la duplica")
	check(a.reserve[0].attack() == 4, "lobo duplicado: 3 + 1 de ataque")
	a.buy(Catalog.by_id("arcangel"))
	a.buy(Catalog.by_id("arcangel"))
	check(a.find_card("arcangel").duplicates == 0 and a.reserve.size() == 3, "los legendarios no se duplican")
	var value := a.sell(a.find_card("lobo"))
	check(value == 1 and a.reserve.size() == 2, "vender devuelve la mitad del coste (mín. 1)")
	a.sell_value_override = 1
	check(a.sell_value(a.reserve[0]) == 1, "Deshonor: vender da 1")
	a.eter = 9
	check(not a.level_up(), "no sube de nivel sin Éter")
	a.eter = 10
	check(a.level_up() and a.level == 2 and a.eter == 0, "subir de nivel cuesta 10")


func test_deck() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var deck := Deck.new(rng)
	check(deck.size() == 12 * 14 + 5 * 4 + 9 + 2, "el mazo tiene 199 cartas")
	var hand := deck.draw(4)
	check(hand.size() == 4 and deck.size() == 195, "robar saca cartas del mazo")
	deck.put_back(hand)
	check(deck.size() == 199, "devolver las reintegra")


func test_roster() -> void:
	var a := Adalid.new("A")
	a.eter = 1000
	for id in ["salamandra", "lobo", "golem", "plasma", "lava"]:
		a.buy(Catalog.by_id(id))
	var chosen: Array[Champion] = []
	chosen.assign(a.reserve)
	var errors := Roster.validate(a, chosen)
	check(errors.size() == 3, "nivel 1: dos elementales dan 3 errores (nivel x2 y límite), tiene %d" % errors.size())
	a.level = 2
	errors = Roster.validate(a, chosen)
	check(errors.size() == 1, "nivel 2: solo un elemental permitido")
	a.level = 3
	check(Roster.validate(a, chosen).is_empty(), "nivel 3 con Fuego (3): plasma y lava válidos")
	var pick := Roster.auto_pick(a)
	check(pick.size() == 5 and Roster.validate(a, pick).is_empty(), "la IA alinea las 5 cartas")
	a.buy(Catalog.by_id("demonio_electrico"))
	var with_hero: Array[Champion] = []
	with_hero.assign(a.reserve)
	check(not Roster.validate(a, with_hero).is_empty(), "un héroe necesita sinergia (5)")
	a.kidnapped = a.find_card("lobo")
	check(not a.usable_cards().has(a.kidnapped), "el secuestrado no se puede usar")


func test_death_rattle() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var killer := Adalid.new("K")
	var victim := Adalid.new("V")
	victim.add_card(Catalog.by_id("salamandra"))
	victim.add_card(Catalog.by_id("plasma"))
	check(DeathRattle.dominant_class(victim, rng) == Rules.ClassType.FUEGO, "clase dominante: Fuego")
	DeathRattle.apply(killer, victim, rng)
	check(killer.vitality == Rules.STARTING_VITALITY - 3, "Venganza ígnea quita 3")
	var robot_victim := Adalid.new("R")
	robot_victim.add_card(Catalog.by_id("dron"))
	killer.eter = 20
	DeathRattle.apply(killer, robot_victim, rng)
	check(killer.eter == 10, "Hackeo quita la mitad del Éter")
	var angel_victim := Adalid.new("B")
	angel_victim.add_card(Catalog.by_id("querubin"))
	angel_victim.eliminated = true
	DeathRattle.apply(killer, angel_victim, rng)
	check(not angel_victim.eliminated and angel_victim.vitality == 5 and angel_victim.reserve.is_empty(),
		"Resurrección revive con 5 y sin ángeles")


func test_full_game() -> void:
	var g := Game.new(["A", "B", "C", "D", "E", "F"], 123)
	var rounds := 0
	while g.play_round() and rounds < 200:
		rounds += 1
	check(g.is_over(), "la partida termina")
	check(g.winner() != null, "hay un demiurgo")
	check(rounds > 1, "dura más de una ronda")
	for a in g.adalids:
		for ch in a.reserve:
			check(not ch.annihilated, "no quedan aniquilados en las reservas")
	var g2 := Game.new(["A", "B", "C", "D", "E", "F"], 123)
	g2.play_round()
	var g3 := Game.new(["A", "B", "C", "D", "E", "F"], 123)
	g3.play_round()
	check(g2.log == g3.log, "misma semilla, misma ronda")


func test_human_flow() -> void:
	# Un humano que compra, alinea y empareja a mano debe poder jugar hasta el final.
	var g := Game.new(["Yo", "B", "C", "D", "E", "F"], 77)
	g.set_human(0)
	var rounds := 0
	var combats := 0
	while g.begin_round() and rounds < 200:
		rounds += 1
		if g.state == Game.State.SHOPPING:
			check(not g.shop.is_empty(), "la tienda del humano tiene cartas")
			var before := g.human.eter
			var card: ChampionData = g.shop[0]
			if g.human.can_pay(card.cost):
				check(g.human_buy(card) and g.human.eter == before - card.cost, "comprar a mano descuenta el coste")
			g.finish_shopping()
			check(g.state == Game.State.LINEUP, "tras comprar toca alinear")
			var bad: Array[Champion] = []
			for ch in g.human.reserve:
				bad.append(ch)
			for _i in 7 - bad.size():
				bad.append(Champion.new(Catalog.by_id("arcangel")))
			check(not g.set_lineup(bad).is_empty(), "siete cartas o un legendario en nivel 1 se rechazan")
			check(g.set_lineup(Roster.auto_pick(g.human)).is_empty(), "una alineación válida arranca los combates")
		while g.state == Game.State.COMBAT:
			combats += 1
			var combat := g.current_combat
			check(combat.round_no >= 1, "el combate humano empieza con dados lanzados")
			g.commit_human_pairs(combat.auto_pairs(0))
			check(combats < 2000, "el combate humano no se queda en bucle")
		check(g.state == Game.State.ROUND_END or g.state == Game.State.OVER, "la ronda termina en un estado conocido")
	check(g.is_over(), "la partida con humano termina")
	check(combats > 0, "el humano combatió")
