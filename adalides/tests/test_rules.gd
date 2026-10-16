extends SceneTree
## Pruebas de las reglas v2. Ejecutar con:
##   godot --headless --path adalides -s tests/test_rules.gd

var _failures := 0
var _passes := 0


func _init() -> void:
	test_dice()
	test_catalog()
	test_adalid_board()
	test_cuartel()
	test_board()
	test_schedule()
	test_battle_basics()
	test_battle_deterministic()
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
	check(Dice.classify_sum(-2) == Rules.Die.PIFIA, "dos caras − es pifia (--)")
	check(Dice.classify_sum(-1) == Rules.Die.FALLO, "una − y una neutra es fallo (-)")
	check(Dice.classify_sum(0) == Rules.Die.NEUTRO, "suma 0 es neutro")
	check(Dice.classify_sum(1) == Rules.Die.ACIERTO, "una + y una neutra es acierto (+)")
	check(Dice.classify_sum(2) == Rules.Die.CRITICO, "dos caras + es crítico (++)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var seen := {}
	for d in Dice.roll_dice(rng, 300):
		seen[d] = true
		check(d >= Rules.Die.PIFIA and d <= Rules.Die.CRITICO, "resultado válido")
	check(seen.size() == 5, "con 300 tiradas salen los cinco resultados")
	check(Dice.worsen(Rules.Die.CRITICO) == Rules.Die.ACIERTO and Dice.worsen(Rules.Die.ACIERTO) == Rules.Die.NEUTRO
		and Dice.worsen(Rules.Die.PIFIA) == Rules.Die.PIFIA, "Hackeo empeora un rango")
	check(not Dice.meets(Rules.Die.NEUTRO, [Rules.Die.ACIERTO, Rules.Die.CRITICO]) and Dice.meets(Rules.Die.NEUTRO, []), "el neutro solo activa poderes sin requisito")
	check(Dice.meets(Rules.Die.ACIERTO, [Rules.Die.ACIERTO, Rules.Die.CRITICO]), "+ cumple un requisito de +/++")
	check(not Dice.meets(Rules.Die.FALLO, [Rules.Die.CRITICO]), "- no cumple ++")
	check(Dice.d20_to_cell(15) == 15 and Dice.d20_to_cell(16) == -1, "d20 señala casillas 1..15")


func test_catalog() -> void:
	check(Catalog.all().size() == 55, "50 base + 5 héroes")
	var pirata := Catalog.by_id("pirata_fuego")
	check(pirata.attack == 2 and pirata.defense == 7 and pirata.cost == 3, "Pirata de fuego 2/6 +1 de vida, cuesta 3")
	var asesino := Catalog.by_id("asesino_hielo")
	check(asesino.attack == 6 and asesino.defense == 4, "Asesino de hielo 5/2 → +1 ataque, +2 vida")
	var arquero := Catalog.by_id("arquero_fuego")
	check(arquero.attack == 1 and arquero.defense == 3 and arquero.reach() == 3, "Arquero de fuego 1/2 +1 vida, alcance 3")
	check(Catalog.by_id("mago_aire").reach() == 2 and Catalog.by_id("robot_tierra").reach() == 1, "alcance de mago 2, resto 1")
	var hero := Catalog.by_id("angel_arquero")
	check(hero.hero and hero.cost == 10 and hero.reach() == 3 and hero.has_archetype(Rules.Archetype.ARQUERO), "héroe de 10 con dos arquetipos")
	var with_power := 0
	for c in Catalog.all():
		if c.has_power():
			with_power += 1
	check(with_power == 55, "todas las cartas tienen poder (hay %d)" % with_power)
	check(Catalog.by_id("mago_fuego").power_requirement() == [Rules.Die.ACIERTO, Rules.Die.CRITICO], "Bola de fuego requiere + o ++")


func test_adalid_board() -> void:
	var a := Adalid.new("A")
	check(a.life == 30 and a.eter == 30, "empieza con 30 de vida y 30 de Éter")
	check(a.cuartel_capacity() == 8 and a.battle_size() == 3 and a.dice_count() == 1 and a.hero_slots() == 0, "pistas iniciales 8 / 3 / 1")
	check(a.upgrade_cost(Adalid.Track.CUARTEL) == 5, "primera mejora cuesta 5")
	check(a.upgrade(Adalid.Track.CUARTEL) and a.eter == 25 and a.cuartel_capacity() == 11, "cuartel 8 → 11")
	check(a.upgrade_cost(Adalid.Track.CUARTEL) == 10, "segunda mejora cuesta 10")
	check(a.upgrade(Adalid.Track.CUARTEL) and a.cuartel_capacity() == 14, "cuartel 11 → 14")
	check(a.upgrade_cost(Adalid.Track.CUARTEL) == 15 and a.upgrade(Adalid.Track.CUARTEL), "tercera cuesta 15 y desbloquea H")
	check(a.hero_slots() == 1 and a.cuartel_capacity() == 14, "H da un hueco de héroe sin cambiar la capacidad")
	check(a.eter == 0 and not a.upgrade(Adalid.Track.BATTLE), "sin Éter no se mejora")
	a.eter = 30
	check(a.interest() == 9, "interés 3 por cada 10 ahorrados")
	a.eter = 7
	check(a.interest() == 0 and a.cycle_income() == 10, "sin 10 ahorrados no hay interés")
	a.record_result(true)
	a.record_result(true)
	check(a.streak == 2 and a.streak_is_win and a.streak_bonus() == 10, "racha de 2 victorias da 10")
	a.record_result(false)
	check(a.streak == 1 and not a.streak_is_win, "perder tras ganar reinicia la racha")
	a.record_result(false)
	check(a.streak == 2 and a.streak_bonus() == 10, "la racha de derrotas también cuenta")


func test_cuartel() -> void:
	var a := Adalid.new("A")
	a.eter = 100
	var lobo := Catalog.by_id("salvaje_fuego")
	for i in 4:
		check(a.buy(lobo), "compra copia %d" % (i + 1))
	var ch := a.find_card("salvaje_fuego")
	check(ch.copies == 4 and ch.afi() == 2, "4 copias → AFI 2")
	check(ch.base_attack() == lobo.attack + 1 + 2 and ch.base_defense() == lobo.defense + 1 + 2, "duplicado +1/+1 y AFI +2/+2")
	check(not a.buy(lobo), "no hay quinta copia")
	check(a.base_count() == 4, "las copias cuentan para el cuartel")
	for i in 4:
		a.add_card(Catalog.by_id("robot_aire"))
	check(a.base_count() == 8 and not a.can_add(Catalog.by_id("mago_aire")), "cuartel lleno con 8")
	var hero := Catalog.by_id("robot_caballero")
	check(not a.can_add(hero), "sin hueco H no caben héroes")
	a.upgrades[Adalid.Track.CUARTEL] = 3
	check(a.can_add(hero) and a.buy(hero) and a.hero_count() == 1, "con H se compra un héroe")
	check(not a.can_add(Catalog.by_id("pirata_muerto")), "solo un héroe por hueco")
	var value := a.sell(ch)
	check(value == 1 and ch.copies == 3, "vender quita una copia y da la mitad del coste")


func test_board() -> void:
	check(Board.pos_from(0, 1, 2) == Vector2i(2, 2), "lado 0, fila 1 (frente) → y = 2")
	check(Board.pos_from(1, 1, 2) == Vector2i(2, 3), "lado 1, fila 1 (frente) → y = 3")
	check(Board.pos_from(0, 3, 0) == Vector2i(0, 0) and Board.pos_from(1, 3, 4) == Vector2i(4, 5), "las filas 3 son los bordes")
	check(Board.row_of(Vector2i(2, 2)) == 1 and Board.row_of(Vector2i(2, 5)) == 3, "fila desde el frente")
	check(Board.distance(Board.pos_from(0, 1, 2), Board.pos_from(1, 1, 2)) == 1, "los frentes se tocan")
	check(Board.opposite(Vector2i(1, 0)) == Vector2i(1, 5), "casilla opuesta = espejo")
	check(Board.cell_index(Board.pos_from(0, 2, 3)) == 9 and Board.pos_from_cell(1, 9) == Board.pos_from(1, 2, 3), "casillas 1..15")
	var a := Adalid.new("A")
	var b := Adalid.new("B")
	var board := Board.new(a, b)
	var ch := Champion.new(Catalog.by_id("robot_fuego"))
	board.place(ch, Board.pos_from(0, 1, 0))
	check(ch.side == 0 and board.pos_of(ch) == Vector2i(0, 2), "colocar fija el lado")
	check(board.move(ch, Vector2i(0, 3)) and not board.move(ch, Vector2i(9, 9)), "mover a casilla libre, no fuera")
	check(board.alive_count(0) == 1 and board.alive_count(1) == 0, "conteo por lado")


func test_schedule() -> void:
	for n in [4, 6, 5, 3]:
		var table := Schedule.table_for(n)
		for column in table:
			var seen := {}
			for pair in column:
				check(not seen.has(pair[0]) and not seen.has(pair[1]), "%d jugadores: nadie pelea dos veces por columna" % n)
				seen[pair[0]] = true
				seen[pair[1]] = true
		var meetings := {}
		for column in table:
			for pair in column:
				var key := [mini(pair[0], pair[1]), maxi(pair[0], pair[1])]
				meetings[key] = meetings.get(key, 0) + 1
		check(meetings.size() == n * (n - 1) / 2, "%d jugadores: todos contra todos" % n)
	var adalids: Array[Adalid] = []
	for i in 6:
		adalids.append(Adalid.new("P%d" % i))
	adalids[1].eliminated = true
	adalids[2].eliminated = true
	var pairs := Schedule.pairs_for(1, adalids)
	check(pairs.size() == 2 and pairs[1].size() == 2, "con dos eliminados los sueltos se emparejan")


func test_battle_basics() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a := Adalid.new("A")
	var b := Adalid.new("B")
	var tank := Champion.new(Catalog.by_id("defensor_tierra"))
	var weak := Champion.new(Catalog.by_id("arquero_fuego"))
	var battle := Battle.new(a, b, [{ Vector2i(2, 1): tank }, { Vector2i(2, 1): weak }], rng, 1)
	var result := battle.run()
	check(result["winner"] == a, "un defensor 1/10 gana a un arquero 1/3 (dura %d asaltos)" % result["rounds"])
	var kinds := {}
	for e in battle.events:
		kinds[e["type"]] = true
	check(kinds.has("attack") and kinds.has("damage"), "la batalla registra eventos de ataque y daño")
	check(b.life == 29 and a.life == 30, "la batalla 1 quita 1 de vida al perdedor")
	check(b.streak == 1 and not b.streak_is_win and a.streak_is_win, "se registra la racha")
	# Empate: ambos pierden.
	var c := Adalid.new("C")
	var d := Adalid.new("D")
	var t1 := Champion.new(Catalog.by_id("defensor_tierra"))
	var t2 := Champion.new(Catalog.by_id("defensor_tierra"))
	var b2 := Battle.new(c, d, [{ Vector2i(0, 3): t1 }, { Vector2i(4, 3): t2 }], rng, 3)
	var r2 := b2.run()
	check(r2["tie"] and c.life == 27 and d.life == 27, "empate en la batalla 3: ambos pierden 3")
	# Ventaja de campeones: +1 por cada uno después del primero.
	var e := Adalid.new("E")
	var f := Adalid.new("F")
	var lineup_e := {}
	for i in 3:
		lineup_e[Vector2i(i, 1)] = Champion.new(Catalog.by_id("defensor_tierra"))
	var b3 := Battle.new(e, f, [lineup_e, { Vector2i(2, 1): Champion.new(Catalog.by_id("mago_aire")) }], rng, 2)
	var r3 := b3.run()
	check(r3["winner"] == e and f.life == 30 - (2 + 2), "batalla 2 con 3 de ventaja: pierde 2 + 2")


func test_battle_deterministic() -> void:
	var g1 := Game.new(["A", "B", "C", "D"], 11)
	var g2 := Game.new(["A", "B", "C", "D"], 11)
	g1.play_cycle()
	g2.play_cycle()
	check(g1.log == g2.log, "misma semilla, mismo ciclo")
	check(g1.last_battles.size() == 2, "4 jugadores: 2 batallas por ciclo")


func test_full_game() -> void:
	var g := Game.new(["A", "B", "C", "D", "E", "F"], 123)
	var cycles := 0
	while g.play_cycle() and cycles < 300:
		cycles += 1
	check(g.is_over(), "la partida termina")
	check(g.winner() != null or g.demiurge_wins, "hay demiurgo")
	check(cycles > 2, "dura más de dos ciclos (%d)" % cycles)
	for a in g.adalids:
		check(a.base_count() <= a.cuartel_capacity(), "%s no supera su cuartel" % a.display_name)
		check(a.hero_count() <= a.hero_slots(), "%s no supera sus héroes" % a.display_name)


func test_human_flow() -> void:
	var g := Game.new(["Yo", "B", "C", "D"], 77)
	g.set_human(0)
	var cycles := 0
	var rounds := 0
	while g.begin_cycle() and cycles < 300:
		cycles += 1
		if cycles == 1:
			check(g.human.eter == Rules.STARTING_ETER, "el primer ciclo no se cobra")
		while g.state == Game.State.DRAFT:
			if g.draft_current() != g.human:
				var step := g.draft_step()
				check(step.is_empty() or step.has("adalid"), "la IA elige paso a paso")
				continue
			check(not g.draft_pool.is_empty(), "hay cartas en el draft")
			var pick: ChampionData = null
			for card in g.draft_pool:
				if g.human.can_add(card):
					pick = card
					break
			if pick == null:
				g.human_draft_skip()
			else:
				check(g.human_draft_pick(pick), "el humano toma una carta")
		if g.state == Game.State.MARKET:
			check(g.market.size() == Rules.MARKET_SIZE, "el mercado tiene 4 cartas")
			var before := g.human.eter
			if g.human_refresh_market():
				check(g.human.eter == before - 2, "refrescar cuesta 2")
			if g.human.can_upgrade(Adalid.Track.BATTLE) and g.human.eter >= g.human.upgrade_cost(Adalid.Track.BATTLE) + 5:
				g.human_upgrade(Adalid.Track.BATTLE)
			for card in g.market.duplicate():
				g.human_buy(card)
			g.finish_market()
			check(g.state == Game.State.LINEUP, "tras el mercado toca alinear")
			var bad := Game.auto_lineup(g.human)
			bad[Vector2i(9, 9)] = Champion.new(Catalog.by_id("mago_aire"))
			check(not g.set_lineup(bad).is_empty(), "una alineación inválida se rechaza")
			check(g.set_lineup(Game.auto_lineup(g.human)).is_empty(), "la automática vale")
		while g.state == Game.State.BATTLE:
			rounds += 1
			check(g.current_battle.events.is_empty() or g.current_battle.round_no > 1, "los eventos se limpian al empezar el asalto")
			g.auto_round()
			check(rounds < 5000, "la batalla humana no se queda en bucle")
		check(g.state == Game.State.CYCLE_END or g.state == Game.State.OVER, "el ciclo termina en un estado conocido")
	check(g.is_over(), "la partida con humano termina")
	check(rounds > 0, "el humano combatió")
