extends Control
## Partida v2 jugable: tú contra la IA. Draft → mercado (tablero personal) →
## alineación 3×5 → batallas en el tablero 6×5 asignando dados a poderes.
## La interfaz se construye en código.

const NAMES: PackedStringArray = ["Tú", "Bruno", "Carla", "Dani", "Eva", "Fito"]
const ELEMENT_COLORS := {
	Rules.Element.FUEGO: Color(1.0, 0.45, 0.3), Rules.Element.TRUENO: Color(1.0, 0.9, 0.3),
	Rules.Element.TIERRA: Color(0.75, 0.55, 0.3), Rules.Element.AIRE: Color(0.8, 0.9, 1.0),
	Rules.Element.HIELO: Color(0.5, 0.8, 1.0),
}

var game: Game
var seed_spin: SpinBox
var standings: Label
var log_label: RichTextLabel
var phase_title: Label
var panels: Dictionary = {}

# Draft
var draft_box: HFlowContainer
var draft_info: Label
# Mercado / tablero personal
var personal: Label
var market_box: HFlowContainer
var cuartel_list: ItemList
var upgrade_buttons: Dictionary = {}
var refresh_button: Button
var sell_button: Button
# Alineación
var lineup_source: ItemList
var lineup_cells: Dictionary = {} # Vector2i(col, row) → Button
var lineup: Dictionary = {} # Vector2i(col, row) → Champion
var lineup_info: Label
var pending_card: Champion = null
# Batalla
var battle_title: Label
var grid_cells: Dictionary = {} # Vector2i(x, y) → Button
var dice_box: HBoxContainer
var powers_box: VBoxContainer
var assignment: Dictionary = {} # Champion → Rules.Die
var selected_die: int = -1 # índice en dice[0]
var used_dice: Array[int] = []
var assign_label: Label


func _ready() -> void:
	_build_ui()
	_new_game()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--screenshots":
		_screenshot_tour(args[1])


# ---------------------------------------------------------------- construcción

func _build_ui() -> void:
	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 400
	root.add_child(left)
	var title := Label.new()
	title.text = "Adalides del demiurgo"
	title.add_theme_font_size_override("font_size", 22)
	left.add_child(title)
	var controls := HBoxContainer.new()
	left.add_child(controls)
	var seed_label := Label.new()
	seed_label.text = "Semilla"
	controls.add_child(seed_label)
	seed_spin = SpinBox.new()
	seed_spin.max_value = 999999
	seed_spin.custom_minimum_size.x = 120
	controls.add_child(seed_spin)
	var new_button := Button.new()
	new_button.text = "Partida nueva"
	new_button.pressed.connect(_new_game)
	controls.add_child(new_button)
	standings = Label.new()
	left.add_child(standings)
	left.add_child(_label("Registro"))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	left.add_child(log_label)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	root.add_child(right)
	phase_title = Label.new()
	phase_title.add_theme_font_size_override("font_size", 20)
	right.add_child(phase_title)
	panels[Game.State.DRAFT] = _build_draft_panel()
	panels[Game.State.MARKET] = _build_market_panel()
	panels[Game.State.LINEUP] = _build_lineup_panel()
	panels[Game.State.BATTLE] = _build_battle_panel()
	panels[Game.State.CYCLE_END] = _build_cycle_end_panel()
	panels[Game.State.OVER] = _build_over_panel()
	for p in panels.values():
		p.size_flags_vertical = Control.SIZE_EXPAND_FILL
		right.add_child(p)


func _build_draft_panel() -> Control:
	var box := VBoxContainer.new()
	draft_info = _label("")
	box.add_child(draft_info)
	draft_box = HFlowContainer.new()
	draft_box.add_theme_constant_override("h_separation", 6)
	draft_box.add_theme_constant_override("v_separation", 6)
	box.add_child(draft_box)
	return box


func _build_market_panel() -> Control:
	var box := VBoxContainer.new()
	personal = Label.new()
	box.add_child(personal)
	var tracks := HBoxContainer.new()
	tracks.add_theme_constant_override("separation", 8)
	box.add_child(tracks)
	for track in [Adalid.Track.CUARTEL, Adalid.Track.BATTLE, Adalid.Track.DICE]:
		var b := Button.new()
		b.pressed.connect(func() -> void:
			game.human_upgrade(track)
			_refresh_market()
			_refresh())
		tracks.add_child(b)
		upgrade_buttons[track] = b
	box.add_child(_label("Mercado — pulsa una carta para comprarla"))
	market_box = HFlowContainer.new()
	market_box.add_theme_constant_override("h_separation", 6)
	box.add_child(market_box)
	var mrow := HBoxContainer.new()
	box.add_child(mrow)
	refresh_button = Button.new()
	refresh_button.text = "Refrescar mercado (%d Éter)" % Rules.MARKET_REFRESH_COST
	refresh_button.pressed.connect(func() -> void:
		game.human_refresh_market()
		_refresh_market()
		_refresh())
	mrow.add_child(refresh_button)
	box.add_child(_label("Cuartel"))
	cuartel_list = ItemList.new()
	cuartel_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(cuartel_list)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	sell_button = Button.new()
	sell_button.text = "Vender seleccionada"
	sell_button.pressed.connect(_on_sell)
	buttons.add_child(sell_button)
	var done := Button.new()
	done.text = "Terminar compras →"
	done.pressed.connect(func() -> void:
		game.finish_market()
		_start_lineup())
	buttons.add_child(done)
	return box


func _build_lineup_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_label("Alineación — elige una carta del cuartel y pulsa una casilla. La fila 1 es el frente. Pulsa una casilla ocupada para vaciarla."))
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(h)
	lineup_source = ItemList.new()
	lineup_source.custom_minimum_size.x = 280
	lineup_source.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lineup_source.item_selected.connect(func(i: int) -> void:
		var usable := game.human.cuartel
		pending_card = usable[i] if i < usable.size() else null)
	h.add_child(lineup_source)
	var grid := GridContainer.new()
	grid.columns = Rules.BOARD_COLS + 1
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(grid)
	for row in range(1, Rules.BOARD_ROWS + 1):
		var rl := Label.new()
		rl.text = "F%d%s" % [row, " ▲" if row == 1 else ""]
		rl.tooltip_text = "Fila %d%s" % [row, " (frente)" if row == 1 else ""]
		grid.add_child(rl)
		for col in Rules.BOARD_COLS:
			var b := Button.new()
			b.custom_minimum_size = Vector2(90, 52)
			b.clip_text = true
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var key := Vector2i(col, row)
			b.pressed.connect(_on_lineup_cell.bind(key))
			grid.add_child(b)
			lineup_cells[key] = b
	lineup_info = _label("")
	box.add_child(lineup_info)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var auto := Button.new()
	auto.text = "Alinear automáticamente"
	auto.pressed.connect(func() -> void:
		lineup = Game.auto_lineup(game.human)
		_refresh_lineup())
	buttons.add_child(auto)
	var go := Button.new()
	go.text = "¡A la batalla! →"
	go.pressed.connect(_on_lineup_done)
	buttons.add_child(go)
	return box


func _build_battle_panel() -> Control:
	var box := VBoxContainer.new()
	battle_title = Label.new()
	box.add_child(battle_title)
	var grid := GridContainer.new()
	grid.columns = Rules.BOARD_COLS + 1
	box.add_child(grid)
	# Arriba el rival (lado 1: y = 5..3), abajo tú (lado 0: y = 2..0).
	for y in range(2 * Rules.BOARD_ROWS - 1, -1, -1):
		var side := Board.side_of(Vector2i(0, y))
		var rl := Label.new()
		rl.text = "%s F%d" % ["Rival" if side == 1 else "Tú", Board.row_of(Vector2i(0, y))]
		grid.add_child(rl)
		for x in Rules.BOARD_COLS:
			var b := Button.new()
			b.custom_minimum_size = Vector2(96, 44)
			b.clip_text = true
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.disabled = true
			grid.add_child(b)
			grid_cells[Vector2i(x, y)] = b
	box.add_child(_label("Tus dados — elige uno y luego el campeón cuyo poder quieres activar"))
	dice_box = HBoxContainer.new()
	dice_box.add_theme_constant_override("separation", 6)
	box.add_child(dice_box)
	powers_box = VBoxContainer.new()
	box.add_child(powers_box)
	assign_label = _label("")
	box.add_child(assign_label)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var undo := Button.new()
	undo.text = "Deshacer asignaciones"
	undo.pressed.connect(func() -> void:
		_reset_assignment()
		_refresh_battle())
	buttons.add_child(undo)
	var auto := Button.new()
	auto.text = "Asignar automáticamente"
	auto.pressed.connect(func() -> void:
		_reset_assignment()
		var auto_assigned: Dictionary = game.current_battle.auto_assign(0)
		for ch in auto_assigned:
			_assign(ch, auto_assigned[ch])
		_refresh_battle())
	buttons.add_child(auto)
	var resolve := Button.new()
	resolve.text = "Resolver asalto →"
	resolve.pressed.connect(_on_resolve)
	buttons.add_child(resolve)
	return box


func _build_cycle_end_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(_label("Ciclo terminado. Revisa el registro y continúa."))
	var next := Button.new()
	next.text = "Siguiente ciclo →"
	next.pressed.connect(_next_cycle)
	box.add_child(next)
	return box


func _build_over_panel() -> Control:
	var box := VBoxContainer.new()
	var l := Label.new()
	l.name = "Result"
	l.add_theme_font_size_override("font_size", 24)
	box.add_child(l)
	return box


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


# ---------------------------------------------------------------- flujo

func _new_game() -> void:
	game = Game.new(NAMES, int(seed_spin.value))
	game.set_human(0)
	_next_cycle()


func _next_cycle() -> void:
	if not game.begin_cycle():
		_enter_state()
		return
	_enter_state()


func _enter_state() -> void:
	match game.state:
		Game.State.DRAFT:
			_refresh_draft()
		Game.State.MARKET:
			_refresh_market()
		Game.State.LINEUP:
			_start_lineup()
		Game.State.BATTLE:
			_reset_assignment()
			_refresh_battle()
		Game.State.OVER:
			var res: Label = panels[Game.State.OVER].get_node("Result")
			var w := game.winner()
			if game.demiurge_wins:
				res.text = "Los últimos adalides cayeron a la vez: gana el Demiurgo."
			elif w == game.human:
				res.text = "¡Eres el nuevo demiurgo!"
			else:
				res.text = "Has sido eliminado. Gana %s." % (w.display_name if w != null else "nadie")
	_refresh()


# ---------------------------------------------------------------- draft

func _refresh_draft() -> void:
	for c in draft_box.get_children():
		c.queue_free()
	var my_turn := not game.draft_order.is_empty() and game.draft_order[0] == game.human
	draft_info.text = "Draft: cada adalid toma %d cartas por turnos. %s" % [Rules.DRAFT_PICKS,
		"Te toca elegir." if my_turn else "Esperando..."]
	for card in game.draft_pool:
		var b := _card_button(card)
		b.disabled = not my_turn or not game.human.can_add(card)
		b.pressed.connect(func() -> void:
			game.human_draft_pick(card)
			_enter_state())
		draft_box.add_child(b)


# ---------------------------------------------------------------- mercado

func _refresh_market() -> void:
	var h := game.human
	personal.text = "Vida %d · Éter %d · Racha %s · Interés próximo ciclo %d · Cuartel %d/%d (héroes %d/%d) · En batalla %d · Dados %d" % [
		h.life, h.eter, ("%s%d" % ["V" if h.streak_is_win else "D", h.streak]) if h.streak > 0 else "—",
		h.interest(), h.base_count(), h.cuartel_capacity(), h.hero_count(), h.hero_slots(), h.battle_size(), h.dice_count()]
	var names := { Adalid.Track.CUARTEL: "Cuartel", Adalid.Track.BATTLE: "Campeones en batalla", Adalid.Track.DICE: "Dados" }
	for track in upgrade_buttons:
		var b: Button = upgrade_buttons[track]
		if h.can_upgrade(track):
			var next = [Rules.CUARTEL_TRACK, Rules.BATTLE_TRACK, Rules.DICE_TRACK][track][h.upgrades[track] + 1]
			b.text = "%s → %s (%d Éter)" % [names[track], str(next), h.upgrade_cost(track)]
			b.disabled = not h.can_pay(h.upgrade_cost(track))
		else:
			b.text = "%s al máximo" % names[track]
			b.disabled = true
	for c in market_box.get_children():
		c.queue_free()
	for card in game.market:
		var b := _card_button(card)
		b.disabled = not (h.can_pay(card.cost) and h.can_add(card))
		b.pressed.connect(func() -> void:
			game.human_buy(card)
			_refresh_market()
			_refresh())
		market_box.add_child(b)
	refresh_button.disabled = not h.can_pay(Rules.MARKET_REFRESH_COST)
	cuartel_list.clear()
	for ch in h.cuartel:
		cuartel_list.add_item("%s — vender por %d" % [_champion_text(ch), h.sell_value(ch)])


func _on_sell() -> void:
	var sel := cuartel_list.get_selected_items()
	if sel.is_empty():
		return
	game.human_sell(game.human.cuartel[sel[0]])
	_refresh_market()
	_refresh()


# ---------------------------------------------------------------- alineación

func _start_lineup() -> void:
	lineup = Game.auto_lineup(game.human)
	pending_card = null
	_refresh_lineup()
	_refresh()


func _on_lineup_cell(key: Vector2i) -> void:
	if lineup.has(key):
		lineup.erase(key)
	elif pending_card != null:
		for k in lineup.keys():
			if lineup[k] == pending_card:
				lineup.erase(k)
		lineup[key] = pending_card
		pending_card = null
	_refresh_lineup()


func _refresh_lineup() -> void:
	lineup_source.clear()
	for ch in game.human.cuartel:
		lineup_source.add_item(_champion_text(ch) + ("  ✔" if lineup.values().has(ch) else ""))
	for key in lineup_cells:
		var b: Button = lineup_cells[key]
		var ch: Champion = lineup.get(key, null)
		b.text = "—" if ch == null else "%s\n%d/%d" % [ch.data.display_name, ch.attack(), ch.max_hp()]
	var chosen: Array[Champion] = []
	chosen.assign(lineup.values())
	var errors := Game.validate_lineup(game.human, lineup)
	var tiers := Tiers.describe(chosen)
	lineup_info.text = "%d/%d en batalla. Tiers: %s\n%s" % [lineup.size(), game.human.battle_size(),
		tiers if tiers != "" else "ninguno", "\n".join(errors)]


func _on_lineup_done() -> void:
	var errors := game.set_lineup(lineup)
	if not errors.is_empty():
		lineup_info.text = "\n".join(errors)
		return
	_enter_state()


# ---------------------------------------------------------------- batalla

func _reset_assignment() -> void:
	assignment.clear()
	used_dice.clear()
	selected_die = -1


func _assign(ch: Champion, d: int) -> void:
	var dice: Array = game.current_battle.dice[0]
	for i in dice.size():
		if dice[i] == d and not used_dice.has(i):
			used_dice.append(i)
			assignment[ch] = d
			return


func _on_die_pressed(i: int) -> void:
	selected_die = i
	_refresh_battle()


func _on_power_pressed(ch: Champion) -> void:
	if selected_die < 0:
		return
	var d: int = game.current_battle.dice[0][selected_die]
	used_dice.append(selected_die)
	assignment[ch] = d
	selected_die = -1
	_refresh_battle()


func _on_resolve() -> void:
	game.commit_human_dice(assignment)
	_enter_state()


func _refresh_battle() -> void:
	var battle := game.current_battle
	if battle == null:
		return
	var foe := battle.adalids[1]
	battle_title.text = "Batalla contra %s — asalto %d de %d" % [foe.display_name, battle.round_no, Rules.ROUNDS_PER_BATTLE]
	for pos in grid_cells:
		var b: Button = grid_cells[pos]
		var ch := battle.board.at(pos)
		if ch == null:
			b.text = ""
			b.modulate = Color(1, 1, 1, 0.6)
		else:
			var tags: PackedStringArray = []
			if ch.frozen > 0:
				tags.append("❄")
			if ch.stealth:
				tags.append("👤")
			if ch.cursed:
				tags.append("☠")
			b.text = "%s%s\n%d/%d %s" % ["" if ch.side == 0 else "[R] ", ch.data.display_name, ch.hp, ch.max_hp(), " ".join(tags)]
			b.modulate = ELEMENT_COLORS.get(ch.data.element, Color.WHITE) if ch.side == 0 else Color(0.65, 0.65, 0.75)
	for c in dice_box.get_children():
		c.queue_free()
	var dice: Array = battle.dice[0]
	for i in dice.size():
		var b := Button.new()
		b.text = Rules.die_label(dice[i])
		b.custom_minimum_size = Vector2(56, 40)
		b.toggle_mode = true
		b.button_pressed = selected_die == i
		b.disabled = used_dice.has(i)
		b.pressed.connect(_on_die_pressed.bind(i))
		dice_box.add_child(b)
	for c in powers_box.get_children():
		c.queue_free()
	for ch in battle.board.champions(0):
		if not ch.data.has_power():
			continue
		var b := Button.new()
		var req: Array = ch.data.power_requirement()
		var req_text := "cualquier dado"
		if not req.is_empty():
			var parts: PackedStringArray = []
			for r in req:
				parts.append(Rules.die_label(r))
			req_text = "necesita " + " o ".join(parts)
		var kind := "pasivo, además ataca" if ch.data.power_is_passive() else "activo, sustituye el ataque"
		var state := ""
		if assignment.has(ch):
			state = " ← %s" % Rules.die_label(assignment[ch])
		elif not Powers.is_implemented(ch.data.id):
			state = " (aún sin efecto)"
		b.text = "%s: %s (%s; %s)%s" % [ch.data.display_name, ch.data.power.get("name", "?"), req_text, kind, state]
		b.tooltip_text = ch.data.power.get("text", "")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = selected_die < 0 or assignment.has(ch) or not ch.can_act() \
			or not Dice.meets(dice[selected_die] if selected_die >= 0 else -1, req)
		b.pressed.connect(_on_power_pressed.bind(ch))
		powers_box.add_child(b)
	assign_label.text = "Sin dado, cada campeón ataca normalmente. Asignados: %d de %d." % [assignment.size(), dice.size()]
	_refresh()


# ---------------------------------------------------------------- refresco general

func _refresh() -> void:
	for st in panels:
		panels[st].visible = st == game.state
	phase_title.text = {
		Game.State.DRAFT: "Ciclo %d — Draft" % game.cycle,
		Game.State.MARKET: "Ciclo %d — Mercado y tablero personal" % game.cycle,
		Game.State.LINEUP: "Ciclo %d — Alineación" % game.cycle,
		Game.State.BATTLE: "Ciclo %d — Batalla" % game.cycle,
		Game.State.CYCLE_END: "Ciclo %d — Fin de ciclo" % game.cycle,
		Game.State.OVER: "Partida terminada",
	}.get(game.state, "")
	var lines: PackedStringArray = []
	for a in game.adalids:
		lines.append(("► " if a == game.human else "   ") + a.summary())
	standings.text = "\n".join(lines)
	var text := "\n".join(game.log)
	if game.current_battle != null:
		text += "\n" + "\n".join(game.current_battle.log)
	log_label.text = text


func _card_button(card: ChampionData) -> Button:
	var b := Button.new()
	var kind := "Héroe" if card.hero else Rules.element_label(card.element)
	var arch := Rules.archetype_label(card.archetype)
	if card.second_archetype >= 0:
		arch += "+" + Rules.archetype_label(card.second_archetype)
	b.text = "%s\n%s · %s\n%d/%d · %d Éter\n%s" % [card.display_name, arch, kind, card.attack, card.defense, card.cost,
		card.power.get("name", "")]
	b.tooltip_text = card.power.get("text", "")
	b.custom_minimum_size = Vector2(170, 90)
	if card.element >= 0:
		b.modulate = ELEMENT_COLORS[card.element]
	return b


func _champion_text(ch: Champion) -> String:
	var kind := "Héroe" if ch.data.hero else Rules.element_label(ch.data.element)
	var cp := "" if ch.copies == 1 else " x%d%s" % [ch.copies, " AFI %d" % ch.afi() if ch.afi() > 0 else ""]
	return "%s%s [%s %s] %d/%d" % [ch.data.display_name, cp, Rules.archetype_label(ch.data.archetype), kind, ch.attack(), ch.max_hp()]


# ---------------------------------------------------------------- capturas

func _screenshot_tour(dir: String) -> void:
	await _snap(dir.path_join("1_draft.png"))
	while game.state == Game.State.DRAFT:
		var picked := false
		for card in game.draft_pool:
			if game.human.can_add(card):
				game.human_draft_pick(card)
				picked = true
				break
		if not picked:
			game.draft_order.pop_front()
			game._run_draft()
		_enter_state()
	await _snap(dir.path_join("2_mercado.png"))
	if game.state == Game.State.MARKET:
		if not game.market.is_empty():
			game.human_buy(game.market[0])
		game.finish_market()
		_start_lineup()
		await _snap(dir.path_join("3_alineacion.png"))
		_on_lineup_done()
	if game.state == Game.State.BATTLE:
		await _snap(dir.path_join("4_batalla.png"))
		if not game.current_battle.dice[0].is_empty():
			_on_die_pressed(0)
			await _snap(dir.path_join("5_batalla_dado.png"))
		_on_resolve()
		await _snap(dir.path_join("6_batalla_resuelta.png"))
	get_tree().quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
