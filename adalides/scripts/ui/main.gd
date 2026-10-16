extends Node3D
## Partida v2 en 3D: tú contra cinco IA. El tablero y las cartas del draft y
## del mercado viven en la escena 3D; las fases se controlan desde una capa 2D.

const NAMES: PackedStringArray = ["Tú", "Bruno", "Carla", "Dani", "Eva", "Fito"]
const AUTO_ROUND_SECONDS := 2.0

var game: Game
var board3d: Board3D
var table: DraftTable
var camera: Camera3D

# UI general
var ui: CanvasLayer
var seed_spin: SpinBox
var standings: RichTextLabel
var log_label: RichTextLabel
var phase_title: Label
var hint: Label
var hud: RichTextLabel
var panels: Dictionary = {}
# Draft y mercado (cartas sobre la mesa)
var selected_card: ChampionData = null
var table_busy: bool = false
var card_detail: VBoxContainer
var take_button: Button
var skip_button: Button
var buy_button: Button
var market_detail: VBoxContainer
# Habilidades
var skills_panel: PanelContainer
var skills_box: VBoxContainer
# Mercado
var upgrade_buttons: Dictionary = {}
var refresh_button: Button
var sell_button: Button
var cuartel_box: HFlowContainer
var selected_cuartel: Champion = null
# Alineación
var lineup_box: HFlowContainer
var lineup: Dictionary = {}
var lineup_info: Label
var pending_card: Champion = null
# Batalla
var battle_title: Label
var battle_status: Label
var pause_button: Button
var dice_box: HBoxContainer
var powers_box: HFlowContainer
var manual_box: VBoxContainer
var assignment: Dictionary = {}
var selected_die: int = -1
var used_dice: Array[int] = []
var battle_paused: bool = false
var _auto_token: int = 0


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
	table = DraftTable.new()
	table.deck_clicked.connect(_on_deck_clicked)
	table.card_clicked.connect(_on_table_card_clicked)
	table.visible = false
	add_child(table)
	camera = Camera3D.new()
	var center := Vector3(Board3D.world_x(2), 0, (Board3D.world_z(0) + Board3D.world_z(5)) / 2.0)
	camera.fov = 50
	camera.h_offset = -0.35
	add_child(camera)
	camera.look_at_from_position(center + Vector3(0, 9.2, -5.4), center + Vector3(0, 0, 0.2), Vector3.UP)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.theme = GameTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# Panel izquierdo: título, clasificación y registro.
	var left := PanelContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 8
	left.offset_right = 340
	left.offset_top = 8
	left.offset_bottom = -8
	root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	lv.add_child(GameTheme.title("Adalides del demiurgo", 24))
	var controls := HBoxContainer.new()
	lv.add_child(controls)
	var seed_label := Label.new()
	seed_label.text = "Semilla"
	controls.add_child(seed_label)
	seed_spin = SpinBox.new()
	seed_spin.max_value = 999999
	seed_spin.custom_minimum_size.x = 100
	controls.add_child(seed_spin)
	var new_button := Button.new()
	new_button.text = "Partida nueva"
	new_button.pressed.connect(_new_game)
	controls.add_child(new_button)
	lv.add_child(GameTheme.heading("Adalides"))
	standings = RichTextLabel.new()
	standings.bbcode_enabled = true
	standings.fit_content = true
	standings.scroll_active = false
	standings.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	lv.add_child(standings)
	lv.add_child(GameTheme.heading("Crónica"))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	lv.add_child(log_label)

	# Cabecera: fase, ayuda y HUD del jugador.
	var head := PanelContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_left = 352
	head.offset_right = -468
	head.offset_top = 8
	head.offset_bottom = 118
	root.add_child(head)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	head.add_child(hv)
	var hrow := HBoxContainer.new()
	hv.add_child(hrow)
	phase_title = GameTheme.title("", 20)
	phase_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(phase_title)
	var skills_button := Button.new()
	skills_button.text = "Habilidades"
	skills_button.pressed.connect(_toggle_skills)
	hrow.add_child(skills_button)
	hud = RichTextLabel.new()
	hud.bbcode_enabled = true
	hud.fit_content = true
	hud.scroll_active = false
	hud.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hud.add_theme_font_size_override("normal_font_size", 15)
	hud.add_theme_font_override("normal_font", GameTheme.bold_font)
	hv.add_child(hud)
	hint = _label("")
	hint.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	hint.add_theme_font_size_override("font_size", 13)
	hv.add_child(hint)

	# Panel derecho: controles de la fase.
	var right := PanelContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -460
	right.offset_right = -8
	right.offset_top = 8
	right.offset_bottom = -8
	root.add_child(right)
	panels[Game.State.DRAFT] = _build_draft_panel()
	panels[Game.State.MARKET] = _build_market_panel()
	panels[Game.State.LINEUP] = _build_lineup_panel()
	panels[Game.State.BATTLE] = _build_battle_panel()
	panels[Game.State.CYCLE_END] = _build_cycle_end_panel()
	panels[Game.State.OVER] = _build_over_panel()
	for p in panels.values():
		right.add_child(p)

	# Consulta de habilidades: cubre el tablero.
	skills_panel = PanelContainer.new()
	skills_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	skills_panel.offset_left = 352
	skills_panel.offset_right = -468
	skills_panel.offset_top = 126
	skills_panel.offset_bottom = -8
	skills_panel.visible = false
	root.add_child(skills_panel)
	var sv := VBoxContainer.new()
	skills_panel.add_child(sv)
	var srow := HBoxContainer.new()
	sv.add_child(srow)
	var stitle := GameTheme.title("Habilidades y lo que tienes", 18)
	stitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(stitle)
	var close := Button.new()
	close.text = "Cerrar"
	close.pressed.connect(_toggle_skills)
	srow.add_child(close)
	skills_box = VBoxContainer.new()
	skills_box.add_theme_constant_override("separation", 6)
	var ssc := _scroll(skills_box)
	ssc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(ssc)


func _scroll(child: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(child)
	return sc


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


func _detail_box(parent: VBoxContainer) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box


func _build_draft_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(GameTheme.heading("Draft inicial"))
	box.add_child(_label("Pulsa el mazo para repartir. Luego pulsa una carta de la mesa para verla y «Tomar carta» para quedártela. Cada adalid toma 2."))
	card_detail = _detail_box(box)
	var row := HBoxContainer.new()
	box.add_child(row)
	take_button = Button.new()
	take_button.text = "Tomar carta"
	take_button.disabled = true
	take_button.pressed.connect(_on_take_card)
	GameTheme.primary_button(take_button)
	row.add_child(take_button)
	skip_button = Button.new()
	skip_button.text = "Pasar"
	skip_button.visible = false
	skip_button.pressed.connect(_on_skip_draft)
	row.add_child(skip_button)
	return box


func _build_market_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(GameTheme.heading("Tablero personal"))
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
	box.add_child(GameTheme.heading("Mercado — las cartas están sobre la mesa"))
	market_detail = _detail_box(box)
	market_detail.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var mrow := HBoxContainer.new()
	box.add_child(mrow)
	buy_button = Button.new()
	buy_button.text = "Comprar"
	buy_button.disabled = true
	buy_button.pressed.connect(_on_buy_card)
	GameTheme.primary_button(buy_button)
	mrow.add_child(buy_button)
	refresh_button = Button.new()
	refresh_button.text = "Refrescar (%d ◆)" % Rules.MARKET_REFRESH_COST
	refresh_button.pressed.connect(_on_refresh_market)
	mrow.add_child(refresh_button)
	box.add_child(GameTheme.heading("Cuartel"))
	cuartel_box = HFlowContainer.new()
	cuartel_box.add_theme_constant_override("h_separation", 6)
	cuartel_box.add_theme_constant_override("v_separation", 6)
	box.add_child(_scroll(cuartel_box))
	var brow := HBoxContainer.new()
	box.add_child(brow)
	sell_button = Button.new()
	sell_button.text = "Vender seleccionada"
	sell_button.pressed.connect(_on_sell)
	brow.add_child(sell_button)
	var done := Button.new()
	done.text = "Terminar compras →"
	GameTheme.primary_button(done)
	done.pressed.connect(func() -> void:
		if table_busy:
			return
		game.finish_market()
		_enter_state())
	brow.add_child(done)
	return box


func _build_lineup_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(GameTheme.heading("Alineación"))
	box.add_child(_label("Pulsa una carta del cuartel y luego una casilla de tu lado (azul). La fila junto a la línea dorada es el frente. Pulsa una ficha colocada para quitarla."))
	lineup_info = _label("")
	box.add_child(lineup_info)
	lineup_box = HFlowContainer.new()
	lineup_box.add_theme_constant_override("h_separation", 6)
	lineup_box.add_theme_constant_override("v_separation", 6)
	box.add_child(_scroll(lineup_box))
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var auto := Button.new()
	auto.text = "Automática"
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
	GameTheme.primary_button(go)
	go.pressed.connect(_on_lineup_done)
	buttons.add_child(go)
	return box


func _build_battle_panel() -> Control:
	var box := VBoxContainer.new()
	battle_title = GameTheme.heading("")
	box.add_child(battle_title)
	battle_status = _label("")
	box.add_child(battle_status)
	var row := HBoxContainer.new()
	box.add_child(row)
	pause_button = Button.new()
	pause_button.text = "⏸ Detener asalto"
	GameTheme.primary_button(pause_button)
	pause_button.pressed.connect(_toggle_pause)
	row.add_child(pause_button)
	manual_box = VBoxContainer.new()
	manual_box.add_theme_constant_override("separation", 6)
	manual_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(manual_box)
	manual_box.add_child(_label("Elige un dado y luego el campeón cuyo poder quieres activar. Sin dado, el campeón ataca."))
	var drow := HFlowContainer.new()
	drow.add_theme_constant_override("h_separation", 6)
	manual_box.add_child(drow)
	dice_box = HBoxContainer.new()
	dice_box.add_theme_constant_override("separation", 6)
	drow.add_child(dice_box)
	var undo := Button.new()
	undo.text = "Deshacer"
	undo.pressed.connect(func() -> void:
		_reset_assignment()
		_refresh_battle())
	drow.add_child(undo)
	var auto := Button.new()
	auto.text = "Asignar solo"
	auto.pressed.connect(func() -> void:
		_reset_assignment()
		var auto_assigned: Dictionary = game.current_battle.auto_assign(0)
		for ch in auto_assigned:
			_assign(ch, auto_assigned[ch])
		_refresh_battle())
	drow.add_child(auto)
	var resolve := Button.new()
	resolve.text = "Resolver asalto →"
	GameTheme.primary_button(resolve)
	resolve.pressed.connect(_on_resolve)
	drow.add_child(resolve)
	powers_box = HFlowContainer.new()
	powers_box.add_theme_constant_override("h_separation", 6)
	powers_box.add_theme_constant_override("v_separation", 6)
	manual_box.add_child(_scroll(powers_box))
	return box


func _build_cycle_end_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(GameTheme.heading("Fin del ciclo"))
	box.add_child(_label("Revisa la crónica y continúa."))
	var next := Button.new()
	next.text = "Siguiente ciclo →"
	GameTheme.primary_button(next)
	next.pressed.connect(_next_cycle)
	box.add_child(next)
	return box


func _build_over_panel() -> Control:
	var box := VBoxContainer.new()
	var l := GameTheme.title("", 22)
	l.name = "Result"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(l)
	return box


# ---------------------------------------------------------------- habilidades

func _toggle_skills() -> void:
	skills_panel.visible = not skills_panel.visible
	if skills_panel.visible:
		_refresh_skills()


func _refresh_skills() -> void:
	for c in skills_box.get_children():
		c.queue_free()
	var in_battle: Array[Champion] = []
	if game.current_battle != null:
		in_battle = game.current_battle.board.champions(0)
	elif game.state == Game.State.LINEUP:
		in_battle.assign(lineup.values())
	else:
		in_battle.assign(Game.auto_lineup(game.human).values())
	var cu_e := Tiers.count_elements(game.human.cuartel)
	var ba_e := Tiers.count_elements(in_battle)
	var cu_a := Tiers.count_archetypes(game.human.cuartel)
	var ba_a := Tiers.count_archetypes(in_battle)
	skills_box.add_child(GameTheme.heading("Elementos — tiers con 3 / 6 / 9 campeones en batalla"))
	for e in Catalog.ELEM_ORDER:
		_add_skill_row(Icons.element(e), Icons.ELEMENT_COLORS[e], Rules.element_label(e),
			cu_e.get(e, 0), ba_e.get(e, 0), Rules.ELEMENT_TIERS, TierTexts.ELEMENTS[e])
	skills_box.add_child(GameTheme.heading("Arquetipos — tiers con 2 / 4 / 6 campeones en batalla"))
	for a in Catalog.ARCH_ORDER:
		_add_skill_row(Icons.archetype(a), Color.WHITE, Rules.archetype_label(a),
			cu_a.get(a, 0), ba_a.get(a, 0), Rules.ARCHETYPE_TIERS, TierTexts.ARCHETYPES[a])


func _add_skill_row(icon: Texture2D, color: Color, name: String, in_cuartel: int, in_battle: int,
		thresholds: Array[int], text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var tr := TextureRect.new()
	tr.texture = icon
	tr.modulate = color
	tr.custom_minimum_size = Vector2(40, 40)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tr)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var tier := Rules.tier_index(in_battle, thresholds)
	var marks: PackedStringArray = []
	for i in thresholds.size():
		marks.append(("[%d]" if i < tier else " %d ") % thresholds[i])
	var head := Label.new()
	head.text = "%s — cuartel %d · en batalla %d · tier %s" % [name, in_cuartel, in_battle, "".join(marks)]
	head.autowrap_mode = TextServer.AUTOWRAP_WORD
	head.add_theme_font_override("font", GameTheme.bold_font)
	head.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7) if tier > 0 else (GameTheme.TEXT if in_cuartel > 0 else GameTheme.TEXT_DIM))
	v.add_child(head)
	var body := _label(text)
	body.add_theme_font_size_override("font_size", 13)
	v.add_child(body)
	skills_box.add_child(row)


# ---------------------------------------------------------------- flujo

func _new_game() -> void:
	_auto_token += 1
	game = Game.new(NAMES, int(seed_spin.value))
	game.set_human(0)
	board3d.clear_pieces()
	table.clear()
	table.visible = false
	_next_cycle()


func _next_cycle() -> void:
	game.begin_cycle()
	_enter_state()


func _enter_state() -> void:
	board3d.highlight_tiles([])
	selected_card = null
	if game.state != Game.State.DRAFT and game.state != Game.State.MARKET:
		table.clear()
		table.visible = false
	match game.state:
		Game.State.DRAFT:
			table.set_deck_label("Mazo del demiurgo\n(pulsa para repartir)")
			board3d.clear_pieces()
			_refresh_draft()
		Game.State.MARKET:
			board3d.clear_pieces()
			_refresh_market()
			_deal_market()
		Game.State.LINEUP:
			lineup = Game.auto_lineup(game.human)
			pending_card = null
			_refresh_lineup()
		Game.State.BATTLE:
			battle_paused = false
			_reset_assignment()
			_refresh_battle()
			_schedule_auto_round()
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


func _preview_cuartel() -> void:
	board3d.sync(Board3D.lineup_to_cells(Game.auto_lineup(game.human), 0), false)


# ---------------------------------------------------------------- mesa: draft

func _refresh_draft() -> void:
	table.visible = true
	var my_turn := game.draft_current() == game.human
	if not table.dealt:
		hint.text = "Pulsa el mazo para repartir %d cartas." % game.draft_pool.size()
	elif table_busy:
		hint.text = "Repartiendo..."
	elif my_turn:
		hint.text = "Te toca: pulsa una carta de la mesa y luego «Tomar carta»."
	else:
		hint.text = "Eligen los demás adalides..."
	_show_detail(card_detail, selected_card)
	var fits := false
	for card in game.draft_pool:
		if game.human.can_add(card):
			fits = true
			break
	take_button.disabled = not (my_turn and table.dealt and not table_busy and selected_card != null
		and game.human.can_add(selected_card))
	skip_button.visible = my_turn and table.dealt and not table_busy and not fits
	if table.dealt:
		table.dim_unavailable(func(card: ChampionData) -> bool: return game.human.can_add(card))
	_refresh()


func _show_detail(box: VBoxContainer, card: ChampionData) -> void:
	for c in box.get_children():
		c.queue_free()
	if card == null:
		return
	var cv := CardView.new()
	var note := ""
	if not game.human.can_add(card):
		note = "no cabe en tu cuartel"
	elif game.state == Game.State.MARKET and not game.human.can_pay(card.cost):
		note = "no tienes Éter suficiente"
	cv.setup(card, null, note)
	cv.custom_minimum_size.x = 200
	box.add_child(cv)
	var power := _label("%s: %s" % [card.power.get("name", ""), card.power.get("text", "")])
	power.add_theme_font_size_override("font_size", 13)
	box.add_child(power)


func _on_deck_clicked() -> void:
	if game.state != Game.State.DRAFT or table.dealt or table_busy:
		return
	table_busy = true
	table.set_deck_label("Mazo del demiurgo")
	_refresh_draft()
	await table.deal(game.draft_pool)
	table_busy = false
	_draft_continue()


func _draft_continue() -> void:
	table_busy = true
	while game.state == Game.State.DRAFT and game.draft_current() != game.human:
		var step := game.draft_step()
		if step.has("card") and step["card"] != null:
			hint.text = "%s toma %s." % [step["adalid"].display_name, step["card"].display_name]
			_refresh()
			await table.take(step["card"], false)
	table_busy = false
	if game.state == Game.State.DRAFT:
		_refresh_draft()
	else:
		_enter_state()


func _on_table_card_clicked(card: ChampionData) -> void:
	if table_busy:
		return
	selected_card = card
	table.select(card)
	if game.state == Game.State.DRAFT:
		_refresh_draft()
	elif game.state == Game.State.MARKET:
		_refresh_market()


func _on_take_card() -> void:
	if selected_card == null or not game.human_draft_pick(selected_card):
		return
	var card := selected_card
	selected_card = null
	table_busy = true
	_refresh_draft()
	await table.take(card, true)
	_draft_continue()


func _on_skip_draft() -> void:
	if game.human_draft_skip():
		_draft_continue()


# ---------------------------------------------------------------- mesa: mercado

func _deal_market() -> void:
	table.visible = true
	table.set_deck_label("Mazo del demiurgo")
	table_busy = true
	_refresh_market()
	await table.deal(game.market)
	table_busy = false
	_refresh_market()


func _refresh_market() -> void:
	var h := game.human
	hint.text = "Pulsa una carta de la mesa y «Comprar». Mejora tu tablero y termina cuando quieras."
	var names := { Adalid.Track.CUARTEL: "Cuartel", Adalid.Track.BATTLE: "En batalla", Adalid.Track.DICE: "Dados" }
	for track in upgrade_buttons:
		var b: Button = upgrade_buttons[track]
		if h.can_upgrade(track):
			var next = [Rules.CUARTEL_TRACK, Rules.BATTLE_TRACK, Rules.DICE_TRACK][track][h.upgrades[track] + 1]
			b.text = "%s → %s (%d ◆)" % [names[track], str(next), h.upgrade_cost(track)]
			b.disabled = not h.can_pay(h.upgrade_cost(track))
		else:
			b.text = "%s máx." % names[track]
			b.disabled = true
	_show_detail(market_detail, selected_card if game.market.has(selected_card) else null)
	buy_button.disabled = table_busy or selected_card == null or not game.market.has(selected_card) \
		or not (h.can_pay(selected_card.cost) and h.can_add(selected_card))
	buy_button.text = "Comprar" if selected_card == null else "Comprar (%d ◆)" % selected_card.cost
	refresh_button.disabled = table_busy or not h.can_pay(Rules.MARKET_REFRESH_COST)
	if table.dealt:
		table.dim_unavailable(func(card: ChampionData) -> bool: return h.can_add(card) and h.can_pay(card.cost))
	for c in cuartel_box.get_children():
		c.queue_free()
	if not h.cuartel.has(selected_cuartel):
		selected_cuartel = null
	for ch in h.cuartel:
		var cv := CardView.new()
		cv.setup(ch.data, ch, "vender por %d ◆" % h.sell_value(ch))
		cv.selected = ch == selected_cuartel
		cv.pressed.connect(func() -> void:
			selected_cuartel = ch
			_refresh_market())
		cuartel_box.add_child(cv)
	sell_button.disabled = selected_cuartel == null
	_refresh()


func _on_buy_card() -> void:
	if selected_card == null or table_busy or not game.human_buy(selected_card):
		return
	var card := selected_card
	selected_card = null
	table_busy = true
	_refresh_market()
	await table.take(card, true)
	table_busy = false
	_refresh_market()


func _on_refresh_market() -> void:
	if table_busy or not game.human_refresh_market():
		return
	selected_card = null
	_deal_market()


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
	hint.text = "Coloca hasta %d campeones en tu lado del tablero." % game.human.battle_size()
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


## Los asaltos se resuelven solos cada AUTO_ROUND_SECONDS salvo que el jugador los detenga.
func _schedule_auto_round() -> void:
	_auto_token += 1
	var token := _auto_token
	var battle := game.current_battle
	await get_tree().create_timer(AUTO_ROUND_SECONDS).timeout
	if token != _auto_token or battle_paused or game.state != Game.State.BATTLE or game.current_battle != battle:
		return
	_reset_assignment()
	var auto_assigned: Dictionary = game.current_battle.auto_assign(0)
	for ch in auto_assigned:
		_assign(ch, auto_assigned[ch])
	_commit_round()


func _toggle_pause() -> void:
	battle_paused = not battle_paused
	if not battle_paused:
		_schedule_auto_round()
	else:
		_auto_token += 1
	_refresh_battle()


func _on_resolve() -> void:
	_commit_round()


func _commit_round() -> void:
	game.commit_human_dice(assignment)
	if game.current_battle != null:
		_reset_assignment()
		_refresh_battle()
		if not battle_paused:
			_schedule_auto_round()
	else:
		_enter_state()


func _refresh_battle() -> void:
	var battle := game.current_battle
	if battle == null:
		return
	hint.text = "Las fichas con anillo rojo son del rival. Detén el asalto para asignar tú los dados."
	battle_title.text = "Batalla contra %s — asalto %d de %d" % [battle.adalids[1].display_name, battle.round_no, Rules.ROUNDS_PER_BATTLE]
	battle_status.text = ("Detenido: asigna los dados y pulsa «Resolver asalto»." if battle_paused
		else "Automático: el siguiente asalto se resuelve en %d s." % int(AUTO_ROUND_SECONDS))
	pause_button.text = "▶ Reanudar automático" if battle_paused else "⏸ Detener asalto"
	manual_box.visible = battle_paused
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
	_refresh()


# ---------------------------------------------------------------- refresco general

func _refresh() -> void:
	for st in panels:
		panels[st].visible = st == game.state
	phase_title.text = {
		Game.State.DRAFT: "Ciclo %d · Draft" % game.cycle,
		Game.State.MARKET: "Ciclo %d · Mercado" % game.cycle,
		Game.State.LINEUP: "Ciclo %d · Alineación" % game.cycle,
		Game.State.BATTLE: "Ciclo %d · Batalla" % game.cycle,
		Game.State.CYCLE_END: "Ciclo %d · Fin de ciclo" % game.cycle,
		Game.State.OVER: "Partida terminada",
	}.get(game.state, "")
	if game.state in [Game.State.CYCLE_END, Game.State.OVER]:
		hint.text = ""
	var h := game.human
	var racha := "—"
	if h.streak > 0:
		racha = "%s %d (+%d ◆)" % ["victorias" if h.streak_is_win else "derrotas", h.streak, h.streak_bonus()]
	hud.text = "[color=#7ee07e]♥ %d[/color]   [color=#9ecbff]◆ %d[/color]   [color=#f0d080]Racha %s[/color]   Cuartel %d/%d · Héroes %d/%d · En batalla %d · Dados %d" % [
		h.life, h.eter, racha, h.base_count(), h.cuartel_capacity(), h.hero_count(), h.hero_slots(), h.battle_size(), h.dice_count()]
	var lines: PackedStringArray = []
	for a in game.adalids:
		var color := "#f0d080" if a == game.human else ("#777777" if a.eliminated else "#e8e4dc")
		lines.append("[color=%s]%s%s[/color]  [color=#7ee07e]♥%d[/color] [color=#9ecbff]◆%d[/color]  cuartel %d/%d · batalla %d · dados %d" % [
			color, "► " if a == game.human else "", a.display_name, a.life, a.eter, a.base_count(), a.cuartel_capacity(), a.battle_size(), a.dice_count()])
	standings.text = "\n".join(lines)
	var text := "\n".join(game.log)
	if game.current_battle != null:
		text += "\n" + "\n".join(game.current_battle.log)
	log_label.text = text


# ---------------------------------------------------------------- capturas

func _screenshot_tour(dir: String) -> void:
	await _snap(dir.path_join("1_draft_mazo.png"))
	await _on_deck_clicked()
	while table_busy:
		await get_tree().process_frame
	await _snap(dir.path_join("1_draft.png"))
	while game.state == Game.State.DRAFT:
		if game.draft_current() == game.human:
			var pick: ChampionData = null
			for card in game.draft_pool:
				if game.human.can_add(card):
					pick = card
					break
			if pick == null:
				await _on_skip_draft()
			else:
				_on_table_card_clicked(pick)
				await _on_take_card()
		while table_busy:
			await get_tree().process_frame
	while table_busy:
		await get_tree().process_frame
	if game.state == Game.State.MARKET and not game.market.is_empty():
		_on_table_card_clicked(game.market[0])
	await _snap(dir.path_join("2_mercado.png"))
	_toggle_skills()
	await _snap(dir.path_join("2_habilidades.png"))
	_toggle_skills()
	if game.state == Game.State.MARKET:
		await _on_buy_card()
		game.finish_market()
		_enter_state()
		pending_card = game.human.cuartel[0]
		_refresh_lineup()
		await _snap(dir.path_join("3_alineacion.png"))
		pending_card = null
		_on_lineup_done()
	if game.state == Game.State.BATTLE:
		await _snap(dir.path_join("4_batalla_auto.png"))
		_toggle_pause()
		if not game.current_battle.dice[0].is_empty():
			_on_die_pressed(0)
		await _snap(dir.path_join("5_batalla_detenida.png"))
		_on_resolve()
		await get_tree().create_timer(0.5).timeout
		await _snap(dir.path_join("6_batalla_resuelta.png"))
	get_tree().quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
