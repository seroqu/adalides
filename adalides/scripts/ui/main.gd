extends Node3D
## Partida v2 en 3D: el tablero de batalla es una escena 3D (Board3D) y las
## fases se controlan desde una capa 2D (CanvasLayer). Tú contra cinco IA.

const NAMES: PackedStringArray = ["Tú", "Bruno", "Carla", "Dani", "Eva", "Fito"]

var game: Game
var board3d: Board3D
var camera: Camera3D

# UI
var ui: CanvasLayer
var seed_spin: SpinBox
var standings: Label
var log_label: RichTextLabel
var phase_title: Label
var hint: Label
var panels: Dictionary = {}
# Draft / mercado
var draft_box: HFlowContainer
var personal: Label
var market_box: HFlowContainer
var cuartel_box: HFlowContainer
var upgrade_buttons: Dictionary = {}
var refresh_button: Button
var sell_button: Button
var selected_cuartel: Champion = null
# Alineación
var lineup_box: HFlowContainer
var lineup: Dictionary = {} # Vector2i(col, fila) → Champion
var lineup_info: Label
var pending_card: Champion = null
# Batalla
var battle_title: Label
var dice_box: HBoxContainer
var powers_box: HFlowContainer
var assignment: Dictionary = {}
var selected_die: int = -1
var used_dice: Array[int] = []
var assign_label: Label


func _ready() -> void:
	_build_world()
	_build_ui()
	_new_game()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--screenshots":
		_screenshot_tour(args[1])


# ---------------------------------------------------------------- mundo 3D

func _build_world() -> void:
	board3d = Board3D.new()
	add_child(board3d)
	board3d.tile_clicked.connect(_on_tile_clicked)
	camera = Camera3D.new()
	var center := Vector3(Board3D.world_x(2), 0, (Board3D.world_z(0) + Board3D.world_z(5)) / 2.0)
	camera.fov = 50
	camera.h_offset = -0.45 # Centra el tablero entre los dos paneles.
	add_child(camera)
	camera.look_at_from_position(center + Vector3(0, 9.2, -5.4), center + Vector3(0, 0, 0.2), Vector3.UP)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# Panel izquierdo: clasificación y registro.
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _panel_style())
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_right = 380
	left.offset_left = 8
	left.offset_top = 8
	left.offset_bottom = -8
	root.add_child(left)
	var lv := VBoxContainer.new()
	left.add_child(lv)
	var title := Label.new()
	title.text = "Adalides del demiurgo"
	title.add_theme_font_size_override("font_size", 22)
	lv.add_child(title)
	var controls := HBoxContainer.new()
	lv.add_child(controls)
	var seed_label := Label.new()
	seed_label.text = "Semilla"
	controls.add_child(seed_label)
	seed_spin = SpinBox.new()
	seed_spin.max_value = 999999
	seed_spin.custom_minimum_size.x = 110
	controls.add_child(seed_spin)
	var new_button := Button.new()
	new_button.text = "Partida nueva"
	new_button.pressed.connect(_new_game)
	controls.add_child(new_button)
	standings = Label.new()
	standings.autowrap_mode = TextServer.AUTOWRAP_WORD
	lv.add_child(standings)
	lv.add_child(_label("Registro"))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	lv.add_child(log_label)

	# Cabecera de fase.
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", _panel_style())
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 396
	head.offset_right = -468
	head.offset_top = 8
	head.offset_bottom = 90
	root.add_child(head)
	var hv := VBoxContainer.new()
	head.add_child(hv)
	phase_title = Label.new()
	phase_title.add_theme_font_size_override("font_size", 20)
	hv.add_child(phase_title)
	hint = _label("")
	hv.add_child(hint)

	# Panel derecho: controles de la fase.
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _panel_style())
	bottom.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	bottom.offset_left = -460
	bottom.offset_right = -8
	bottom.offset_top = 8
	bottom.offset_bottom = -8
	root.add_child(bottom)
	panels[Game.State.DRAFT] = _build_draft_panel()
	panels[Game.State.MARKET] = _build_market_panel()
	panels[Game.State.LINEUP] = _build_lineup_panel()
	panels[Game.State.BATTLE] = _build_battle_panel()
	panels[Game.State.CYCLE_END] = _build_cycle_end_panel()
	panels[Game.State.OVER] = _build_over_panel()
	for p in panels.values():
		bottom.add_child(p)


func _panel_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.05, 0.08, 0.86)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(10)
	return s


func _scroll(child: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(child)
	return sc


func _build_draft_panel() -> Control:
	var box := VBoxContainer.new()
	draft_box = HFlowContainer.new()
	draft_box.add_theme_constant_override("h_separation", 6)
	draft_box.add_theme_constant_override("v_separation", 6)
	box.add_child(_scroll(draft_box))
	return box


func _build_market_panel() -> Control:
	var box := VBoxContainer.new()
	personal = Label.new()
	box.add_child(personal)
	personal.autowrap_mode = TextServer.AUTOWRAP_WORD
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	box.add_child(row)
	for track in [Adalid.Track.CUARTEL, Adalid.Track.BATTLE, Adalid.Track.DICE]:
		var b := Button.new()
		b.pressed.connect(func() -> void:
			game.human_upgrade(track)
			_refresh_market())
		row.add_child(b)
		upgrade_buttons[track] = b
	refresh_button = Button.new()
	refresh_button.text = "Refrescar mercado (%d)" % Rules.MARKET_REFRESH_COST
	refresh_button.pressed.connect(func() -> void:
		game.human_refresh_market()
		_refresh_market())
	row.add_child(refresh_button)
	sell_button = Button.new()
	sell_button.text = "Vender seleccionada"
	sell_button.pressed.connect(_on_sell)
	row.add_child(sell_button)
	var done := Button.new()
	done.text = "Terminar compras →"
	done.pressed.connect(func() -> void:
		game.finish_market()
		_enter_state())
	row.add_child(done)
	box.add_child(_label("Mercado"))
	market_box = HFlowContainer.new()
	market_box.add_theme_constant_override("h_separation", 6)
	market_box.add_theme_constant_override("v_separation", 6)
	box.add_child(market_box)
	box.add_child(_label("Cuartel (pulsa para seleccionar)"))
	cuartel_box = HFlowContainer.new()
	cuartel_box.add_theme_constant_override("h_separation", 6)
	cuartel_box.add_theme_constant_override("v_separation", 6)
	box.add_child(_scroll(cuartel_box))
	return box


func _build_lineup_panel() -> Control:
	var box := VBoxContainer.new()
	lineup_info = _label("")
	box.add_child(lineup_info)
	lineup_box = HFlowContainer.new()
	lineup_box.add_theme_constant_override("h_separation", 6)
	lineup_box.add_theme_constant_override("v_separation", 6)
	box.add_child(_scroll(lineup_box))
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var auto := Button.new()
	auto.text = "Alinear automáticamente"
	auto.pressed.connect(func() -> void:
		lineup = Game.auto_lineup(game.human)
		_refresh_lineup())
	buttons.add_child(auto)
	var clear := Button.new()
	clear.text = "Vaciar"
	clear.pressed.connect(func() -> void:
		lineup.clear()
		_refresh_lineup())
	buttons.add_child(clear)
	var go := Button.new()
	go.text = "¡A la batalla! →"
	go.pressed.connect(_on_lineup_done)
	buttons.add_child(go)
	return box


func _build_battle_panel() -> Control:
	var box := VBoxContainer.new()
	battle_title = Label.new()
	box.add_child(battle_title)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	box.add_child(row)
	row.add_child(_label("Tus dados:"))
	dice_box = HBoxContainer.new()
	dice_box.add_theme_constant_override("separation", 6)
	row.add_child(dice_box)
	var undo := Button.new()
	undo.text = "Deshacer"
	undo.pressed.connect(func() -> void:
		_reset_assignment()
		_refresh_battle())
	row.add_child(undo)
	var auto := Button.new()
	auto.text = "Asignar automáticamente"
	auto.pressed.connect(func() -> void:
		_reset_assignment()
		var auto_assigned: Dictionary = game.current_battle.auto_assign(0)
		for ch in auto_assigned:
			_assign(ch, auto_assigned[ch])
		_refresh_battle())
	row.add_child(auto)
	var resolve := Button.new()
	resolve.text = "Resolver asalto →"
	resolve.pressed.connect(_on_resolve)
	row.add_child(resolve)
	assign_label = _label("")
	box.add_child(assign_label)
	powers_box = HFlowContainer.new()
	powers_box.add_theme_constant_override("h_separation", 6)
	powers_box.add_theme_constant_override("v_separation", 6)
	box.add_child(_scroll(powers_box))
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
	board3d.clear_pieces()
	_next_cycle()


func _next_cycle() -> void:
	game.begin_cycle()
	_enter_state()


func _enter_state() -> void:
	board3d.highlight_tiles([])
	match game.state:
		Game.State.DRAFT:
			_refresh_draft()
			_preview_cuartel()
		Game.State.MARKET:
			_refresh_market()
			_preview_cuartel()
		Game.State.LINEUP:
			lineup = Game.auto_lineup(game.human)
			pending_card = null
			_refresh_lineup()
		Game.State.BATTLE:
			_reset_assignment()
			_refresh_battle()
		Game.State.CYCLE_END:
			if not game.last_battles.is_empty():
				board3d.sync(game.last_battles[-1].board.cells, false)
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


## Mientras no hay batalla, el tablero muestra tu alineación prevista.
func _preview_cuartel() -> void:
	board3d.sync(Board3D.lineup_to_cells(Game.auto_lineup(game.human), 0), false)


# ---------------------------------------------------------------- draft

func _refresh_draft() -> void:
	for c in draft_box.get_children():
		c.queue_free()
	var my_turn := not game.draft_order.is_empty() and game.draft_order[0] == game.human
	hint.text = "Draft: cada adalid toma %d cartas por turnos. %s" % [Rules.DRAFT_PICKS,
		"Te toca: pulsa una carta." if my_turn else "Esperando..."]
	for card in game.draft_pool:
		var cv := CardView.new()
		cv.setup(card)
		cv.disabled = not my_turn or not game.human.can_add(card)
		cv.pressed.connect(func() -> void:
			game.human_draft_pick(card)
			_enter_state())
		draft_box.add_child(cv)


# ---------------------------------------------------------------- mercado

func _refresh_market() -> void:
	var h := game.human
	hint.text = "Compra cartas, vende, mejora tu tablero personal y pulsa «Terminar compras»."
	personal.text = "Vida %d · Éter %d · Racha %s · Interés próximo %d · Cuartel %d/%d · Héroes %d/%d · En batalla %d · Dados %d" % [
		h.life, h.eter, ("%s%d" % ["V" if h.streak_is_win else "D", h.streak]) if h.streak > 0 else "—",
		h.interest(), h.base_count(), h.cuartel_capacity(), h.hero_count(), h.hero_slots(), h.battle_size(), h.dice_count()]
	var names := { Adalid.Track.CUARTEL: "Cuartel", Adalid.Track.BATTLE: "En batalla", Adalid.Track.DICE: "Dados" }
	for track in upgrade_buttons:
		var b: Button = upgrade_buttons[track]
		if h.can_upgrade(track):
			var next = [Rules.CUARTEL_TRACK, Rules.BATTLE_TRACK, Rules.DICE_TRACK][track][h.upgrades[track] + 1]
			b.text = "%s → %s (%d)" % [names[track], str(next), h.upgrade_cost(track)]
			b.disabled = not h.can_pay(h.upgrade_cost(track))
		else:
			b.text = "%s máx." % names[track]
			b.disabled = true
	for c in market_box.get_children():
		c.queue_free()
	for card in game.market:
		var cv := CardView.new()
		cv.setup(card)
		cv.disabled = not (h.can_pay(card.cost) and h.can_add(card))
		cv.pressed.connect(func() -> void:
			game.human_buy(card)
			_refresh_market())
		market_box.add_child(cv)
	refresh_button.disabled = not h.can_pay(Rules.MARKET_REFRESH_COST)
	for c in cuartel_box.get_children():
		c.queue_free()
	if not h.cuartel.has(selected_cuartel):
		selected_cuartel = null
	for ch in h.cuartel:
		var cv := CardView.new()
		cv.setup(ch.data, ch, "vender por %d" % h.sell_value(ch))
		cv.selected = ch == selected_cuartel
		cv.pressed.connect(func() -> void:
			selected_cuartel = ch
			_refresh_market())
		cuartel_box.add_child(cv)
	sell_button.disabled = selected_cuartel == null
	_preview_cuartel()
	_refresh()


func _on_sell() -> void:
	if selected_cuartel == null:
		return
	game.human_sell(selected_cuartel)
	selected_cuartel = null
	_refresh_market()


# ---------------------------------------------------------------- alineación

func _on_tile_clicked(pos: Vector2i) -> void:
	if game.state != Game.State.LINEUP or Board.side_of(pos) != 0:
		return
	var key := Vector2i(pos.x, Board.row_of(pos))
	if lineup.has(key) and pending_card == null:
		lineup.erase(key)
	elif pending_card != null:
		for k in lineup.keys():
			if lineup[k] == pending_card:
				lineup.erase(k)
		lineup[key] = pending_card
		pending_card = null
	_refresh_lineup()


func _refresh_lineup() -> void:
	hint.text = "Alineación: pulsa una carta del cuartel y luego una casilla de tu lado (azul). La fila junto a la línea dorada es el frente. Pulsa una ficha colocada para quitarla."
	for c in lineup_box.get_children():
		c.queue_free()
	for ch in game.human.cuartel:
		var cv := CardView.new()
		cv.setup(ch.data, ch, "en el tablero ✔" if lineup.values().has(ch) else "")
		cv.selected = ch == pending_card
		cv.pressed.connect(func() -> void:
			pending_card = null if pending_card == ch else ch
			_refresh_lineup())
		lineup_box.add_child(cv)
	board3d.sync(Board3D.lineup_to_cells(lineup, 0), false)
	var free: Array[Vector2i] = []
	if pending_card != null:
		for row in range(1, Rules.BOARD_ROWS + 1):
			for col in Rules.BOARD_COLS:
				if not lineup.has(Vector2i(col, row)):
					free.append(Board.pos_from(0, row, col))
	board3d.highlight_tiles(free)
	var chosen: Array[Champion] = []
	chosen.assign(lineup.values())
	var errors := Game.validate_lineup(game.human, lineup)
	var tiers := Tiers.describe(chosen)
	lineup_info.text = "%d/%d en batalla · Tiers: %s %s" % [lineup.size(), game.human.battle_size(),
		tiers if tiers != "" else "ninguno", ("· " + " ".join(errors)) if not errors.is_empty() else ""]
	_refresh()


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
	selected_die = -1 if selected_die == i else i
	_refresh_battle()


func _on_power_pressed(ch: Champion) -> void:
	if selected_die < 0:
		return
	used_dice.append(selected_die)
	assignment[ch] = game.current_battle.dice[0][selected_die]
	selected_die = -1
	_refresh_battle()


func _on_resolve() -> void:
	game.commit_human_dice(assignment)
	if game.current_battle != null:
		_reset_assignment()
		_refresh_battle()
	else:
		_enter_state()


func _refresh_battle() -> void:
	var battle := game.current_battle
	if battle == null:
		return
	hint.text = "Batalla: elige un dado y luego el poder que quieres activar. Sin dado, el campeón ataca. Las fichas rojas son del rival."
	battle_title.text = "Contra %s — asalto %d de %d" % [battle.adalids[1].display_name, battle.round_no, Rules.ROUNDS_PER_BATTLE]
	board3d.sync(battle.board.cells, true)
	for c in dice_box.get_children():
		c.queue_free()
	var dice: Array = battle.dice[0]
	for i in dice.size():
		var b := Button.new()
		b.text = Rules.die_label(dice[i])
		b.custom_minimum_size = Vector2(52, 36)
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
		var req: Array = ch.data.power_requirement()
		var parts: PackedStringArray = []
		for r in req:
			parts.append(Rules.die_label(r))
		var extra := "%s · %s" % ["cualquier dado" if req.is_empty() else " o ".join(parts),
			"pasivo" if ch.data.power_is_passive() else "activo"]
		if assignment.has(ch):
			extra += " · ← %s" % Rules.die_label(assignment[ch])
		elif not Powers.is_implemented(ch.data.id):
			extra += " · sin efecto aún"
		var cv := CardView.new()
		cv.setup(ch.data, ch, extra)
		cv.selected = assignment.has(ch)
		cv.disabled = selected_die < 0 or assignment.has(ch) or not ch.can_act() \
			or not Dice.meets(dice[selected_die] if selected_die >= 0 else -1, req)
		cv.pressed.connect(_on_power_pressed.bind(ch))
		powers_box.add_child(cv)
	assign_label.text = "Asignados %d de %d dados." % [assignment.size(), dice.size()]
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
	if game.state in [Game.State.CYCLE_END, Game.State.OVER]:
		hint.text = ""
	var lines: PackedStringArray = []
	for a in game.adalids:
		lines.append(("► " if a == game.human else "   ") + a.summary())
	standings.text = "\n".join(lines)
	var text := "\n".join(game.log)
	if game.current_battle != null:
		text += "\n" + "\n".join(game.current_battle.log)
	log_label.text = text


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
		_enter_state()
		pending_card = game.human.cuartel[0]
		_refresh_lineup()
		await _snap(dir.path_join("3_alineacion.png"))
		pending_card = null
		_on_lineup_done()
	if game.state == Game.State.BATTLE:
		await _snap(dir.path_join("4_batalla.png"))
		if not game.current_battle.dice[0].is_empty():
			_on_die_pressed(0)
			await _snap(dir.path_join("5_batalla_dado.png"))
		_on_resolve()
		await get_tree().create_timer(0.5).timeout
		await _snap(dir.path_join("6_batalla_resuelta.png"))
	get_tree().quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
