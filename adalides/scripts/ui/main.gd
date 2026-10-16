extends Node3D
## Partida v2 en 3D: tú contra cinco IA. El tablero y las cartas del draft y
## del mercado viven en la escena 3D; las fases se controlan desde una capa 2D.
## Los asaltos se resuelven solos y se animan evento a evento.

const NAMES: PackedStringArray = ["Tú", "Bruno", "Carla", "Dani", "Eva", "Fito"]
const AUTO_ROUND_SECONDS := 2.0
const MARKET_SECONDS := 60
const LINEUP_SECONDS := 30
const DRAG_THRESHOLD := 8.0
const HAND_SCALE := 0.68

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
var right_panel: PanelContainer
# Celebraciones y efectos 2D
var fx_layer: Control
var banner: Label
var banner_particles: CPUParticles2D
var flash_rect: ColorRect
var tier_label_top: Label
var tier_label_bottom: Label
# Draft y mercado (cartas sobre la mesa)
var selected_card: ChampionData = null
var table_busy: bool = false
var card_detail: VBoxContainer
var take_button: Button
var skip_button: Button
var buy_button: Button
var market_detail: VBoxContainer
var phase_left: float = 0.0
var phase_total: float = 1.0
var phase_bars: Dictionary = {} # State → ProgressBar
var phase_labels: Dictionary = {} # State → Label
var log_panel: PanelContainer
var log_toggle: Button
var hand_panel: Control
var hand_box: HBoxContainer
# Habilidades
var skills_panel: PanelContainer
var skills_box: VBoxContainer
# Mercado
var upgrade_buttons: Dictionary = {}
var refresh_button: Button
var sell_button: Button
var selected_cuartel: Champion = null
# Alineación
var lineup: Dictionary = {}
var lineup_info: Label
var pending_card: Champion = null
# Arrastrar y soltar
var drag: Dictionary = {}
var drag_origin := Vector2.ZERO
var drag_active: bool = false
var drag_preview: PanelContainer
var drag_preview_label: Label
var drag_preview_icon: TextureRect
# Batalla
var battle_title: Label
var battle_status: Label
var pause_button: Button
var step_button: Button
var battle_paused: bool = false
var battle_playing: bool = false
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
	board3d.tile_clicked.connect(_on_tile_pressed)
	table = DraftTable.new()
	table.deck_clicked.connect(_on_deck_clicked)
	table.card_clicked.connect(_on_table_card_pressed)
	table.visible = false
	add_child(table)
	camera = Camera3D.new()
	var center := Vector3(Board3D.world_x(2), 0, (Board3D.world_z(0) + Board3D.world_z(5)) / 2.0)
	camera.fov = 50
	camera.h_offset = -0.35
	camera.v_offset = -0.75 # El tablero sube para dejar sitio a la mano de cartas.
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

	# Panel izquierdo: título y clasificación (compacto). La crónica va aparte y se pliega.
	var left := PanelContainer.new()
	left.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 8
	left.offset_right = 340
	left.offset_top = 8
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
	log_toggle = Button.new()
	log_toggle.text = "Crónica ▸"
	log_toggle.pressed.connect(_toggle_log)
	lv.add_child(log_toggle)
	log_panel = PanelContainer.new()
	log_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	log_panel.offset_left = 8
	log_panel.offset_right = 340
	log_panel.offset_top = 268
	log_panel.offset_bottom = -8
	log_panel.visible = false
	root.add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	log_panel.add_child(log_label)

	# Cabecera: fase, HUD y ayuda.
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
	right_panel = PanelContainer.new()
	right_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	right_panel.offset_left = -460
	right_panel.offset_right = -8
	right_panel.offset_top = 8
	right_panel.offset_bottom = -8
	root.add_child(right_panel)
	panels[Game.State.DRAFT] = _build_draft_panel()
	panels[Game.State.MARKET] = _build_market_panel()
	panels[Game.State.LINEUP] = _build_lineup_panel()
	panels[Game.State.BATTLE] = _build_battle_panel()
	panels[Game.State.CYCLE_END] = _build_cycle_end_panel()
	panels[Game.State.OVER] = _build_over_panel()
	for p in panels.values():
		right_panel.add_child(p)

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
	sv.add_child(_scroll(skills_box))

	# Capa de efectos 2D: destello, carteles de tier, celebraciones y arrastre.
	fx_layer = Control.new()
	fx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fx_layer)
	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_rect.color = Color(1, 1, 1, 0)
	fx_layer.add_child(flash_rect)
	tier_label_top = _tier_label(Control.PRESET_CENTER_TOP, 150)
	tier_label_bottom = _tier_label(Control.PRESET_CENTER_BOTTOM, -60)
	banner = GameTheme.title("", 54)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.pivot_offset = Vector2.ZERO
	banner.visible = false
	banner.add_theme_constant_override("outline_size", 14)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	fx_layer.add_child(banner)
	banner_particles = CPUParticles2D.new()
	banner_particles.emitting = false
	banner_particles.one_shot = true
	banner_particles.amount = 160
	banner_particles.lifetime = 2.2
	banner_particles.explosiveness = 0.9
	banner_particles.direction = Vector2(0, -1)
	banner_particles.spread = 80
	banner_particles.initial_velocity_min = 250
	banner_particles.initial_velocity_max = 650
	banner_particles.gravity = Vector2(0, 500)
	banner_particles.scale_amount_min = 3
	banner_particles.scale_amount_max = 7
	banner_particles.color = GameTheme.GOLD
	fx_layer.add_child(banner_particles)
	drag_preview = PanelContainer.new()
	drag_preview.visible = false
	drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dp := HBoxContainer.new()
	dp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_preview.add_child(dp)
	drag_preview_icon = TextureRect.new()
	drag_preview_icon.custom_minimum_size = Vector2(32, 32)
	drag_preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	drag_preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	drag_preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dp.add_child(drag_preview_icon)
	drag_preview_label = Label.new()
	drag_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dp.add_child(drag_preview_label)
	fx_layer.add_child(drag_preview)

	# Mano: las cartas del cuartel en la parte baja; se agrandan al pasar el ratón.
	hand_panel = Control.new()
	hand_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hand_panel.offset_left = 352
	hand_panel.offset_right = -468
	hand_panel.offset_top = -190
	hand_panel.offset_bottom = -6
	hand_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_panel.visible = false
	root.add_child(hand_panel)
	hand_box = HBoxContainer.new()
	hand_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.add_theme_constant_override("separation", -40)
	hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_panel.add_child(hand_box)


func _toggle_log() -> void:
	log_panel.visible = not log_panel.visible
	log_toggle.text = "Crónica ▾" if log_panel.visible else "Crónica ▸"


## Barra y etiqueta de tiempo de una fase, al principio de su panel.
func _phase_timer_row(state: int, box: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	box.add_child(row)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 1
	bar.value = 1
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = GameTheme.GOLD
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.09, 0.14)
	bg.border_color = GameTheme.GOLD_DIM
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	row.add_child(bar)
	var l := GameTheme.heading("⏱ 0 s")
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size.x = 64
	row.add_child(l)
	phase_bars[state] = bar
	phase_labels[state] = l


func _start_phase_timer(seconds: float) -> void:
	phase_total = seconds
	phase_left = seconds
	_update_phase_timer()


func _update_phase_timer() -> void:
	var st := game.state
	if not phase_bars.has(st):
		return
	var bar: ProgressBar = phase_bars[st]
	bar.value = clampf(phase_left / phase_total, 0.0, 1.0)
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill")
	fill.bg_color = Color(1, 0.4, 0.3) if phase_left <= 10 else GameTheme.GOLD
	var l: Label = phase_labels[st]
	l.text = "⏱ %d s" % ceili(phase_left)


func _process(delta: float) -> void:
	if game == null or not phase_bars.has(game.state) or phase_left <= 0.0:
		return
	phase_left -= delta
	_update_phase_timer()
	if phase_left <= 0.0:
		phase_left = 0.0
		if game.state == Game.State.MARKET:
			_finish_market()
		elif game.state == Game.State.LINEUP:
			_on_lineup_done(true)


func _tier_label(preset: int, y: float) -> Label:
	var l := GameTheme.title("", 30)
	l.set_anchors_and_offsets_preset(preset)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.offset_top += y
	l.offset_bottom += y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.visible = false
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	fx_layer.add_child(l)
	return l


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


func _build_draft_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_child(GameTheme.heading("Draft inicial"))
	box.add_child(_label("Pulsa el mazo para repartir. Pulsa una carta de la mesa para verla y «Tomar carta», o arrástrala hasta este panel. Cada adalid toma 2."))
	card_detail = VBoxContainer.new()
	card_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(card_detail)
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
	_phase_timer_row(Game.State.MARKET, box)
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
	box.add_child(GameTheme.heading("Mercado"))
	box.add_child(_label("Pulsa una carta de la mesa y «Comprar», o arrástrala hasta este panel. Tu mano (abajo) es tu cuartel."))
	refresh_button = Button.new()
	refresh_button.text = "⟳ Refrescar el mercado (%d ◆)" % Rules.MARKET_REFRESH_COST
	refresh_button.custom_minimum_size = Vector2(0, 46)
	refresh_button.add_theme_font_size_override("font_size", 17)
	refresh_button.pressed.connect(_on_refresh_market)
	box.add_child(refresh_button)
	market_detail = VBoxContainer.new()
	market_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(market_detail)
	buy_button = Button.new()
	buy_button.text = "Comprar"
	buy_button.disabled = true
	buy_button.custom_minimum_size = Vector2(0, 40)
	buy_button.pressed.connect(_on_buy_card)
	GameTheme.primary_button(buy_button)
	box.add_child(buy_button)
	var brow := HBoxContainer.new()
	box.add_child(brow)
	sell_button = Button.new()
	sell_button.text = "Vender de la mano"
	sell_button.pressed.connect(_on_sell)
	brow.add_child(sell_button)
	var done := Button.new()
	done.text = "Terminar compras →"
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameTheme.primary_button(done)
	done.pressed.connect(_finish_market)
	brow.add_child(done)
	return box


func _build_lineup_panel() -> Control:
	var box := VBoxContainer.new()
	_phase_timer_row(Game.State.LINEUP, box)
	box.add_child(GameTheme.heading("Alineación"))
	box.add_child(_label("Arrastra una carta de tu mano (abajo) a una casilla de tu lado, o púlsala y luego pulsa la casilla. Arrastra una ficha para moverla; suéltala fuera para quitarla. La fila junto a la línea dorada es el frente. Si se acaba el tiempo, la alineación actual (o la automática) va a la batalla."))
	lineup_info = _label("")
	box.add_child(lineup_info)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
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
	go.pressed.connect(func() -> void: _on_lineup_done(false))
	buttons.add_child(go)
	return box


func _build_battle_panel() -> Control:
	var box := VBoxContainer.new()
	battle_title = GameTheme.heading("")
	box.add_child(battle_title)
	battle_status = _label("")
	box.add_child(battle_status)
	box.add_child(_label("Cada asalto lanzas tantos dados de tres caras (−, neutra, +) como marque tu pista de Dados; el motor los reparte entre los poderes: un + activa un poder de +, dos + hacen un ++. Observa el tablero: movimientos, daño y poderes se animan."))
	var row := HBoxContainer.new()
	box.add_child(row)
	pause_button = Button.new()
	pause_button.text = "⏸ Detener"
	GameTheme.primary_button(pause_button)
	pause_button.pressed.connect(_toggle_pause)
	row.add_child(pause_button)
	step_button = Button.new()
	step_button.text = "Siguiente asalto ▶"
	step_button.visible = false
	step_button.pressed.connect(_step_round)
	row.add_child(step_button)
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
	battle_playing = false
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
	drag.clear()
	drag_preview.visible = false
	phase_left = 0.0
	hand_panel.visible = game.state in [Game.State.MARKET, Game.State.LINEUP]
	if game.state != Game.State.DRAFT and game.state != Game.State.MARKET:
		table.clear()
		table.visible = false
	board3d.set_mat_visible(game.state not in [Game.State.DRAFT, Game.State.MARKET])
	match game.state:
		Game.State.DRAFT:
			board3d.clear_pieces()
			_update_deck_label("(pulsa para repartir)")
			_refresh_draft()
		Game.State.MARKET:
			board3d.clear_pieces()
			_start_phase_timer(MARKET_SECONDS)
			_refresh_market()
			_deal_market()
		Game.State.LINEUP:
			lineup = Game.auto_lineup(game.human)
			pending_card = null
			_start_phase_timer(LINEUP_SECONDS)
			_refresh_lineup()
		Game.State.BATTLE:
			battle_paused = false
			_refresh_battle()
			_start_battle_loop()
		Game.State.CYCLE_END:
			if not game.last_battles.is_empty():
				board3d.sync(game.last_battles[-1].board.cells, false)
		Game.State.OVER:
			var res: Label = panels[Game.State.OVER].get_node("Result")
			var w := game.winner()
			if game.demiurge_wins:
				res.text = "Los últimos adalides cayeron a la vez: gana el Demiurgo."
				_celebrate("El Demiurgo se queda con todo", GameTheme.TEXT_DIM, false)
			elif w == game.human:
				res.text = "¡Eres el nuevo demiurgo!"
				_celebrate("¡ERES EL NUEVO DEMIURGO!", GameTheme.GOLD, true)
			else:
				res.text = "Has sido eliminado. Gana %s." % (w.display_name if w != null else "nadie")
				_celebrate("Gana %s" % (w.display_name if w != null else "nadie"), Color(0.9, 0.5, 0.5), false)
	_refresh()


func _update_deck_label(extra := "") -> void:
	table.set_deck_label("Mazo del demiurgo · %d cartas%s" % [game.deck.size(), ("\n" + extra) if extra != "" else ""])


# ---------------------------------------------------------------- mesa: draft

func _refresh_draft() -> void:
	table.visible = true
	var my_turn := game.draft_current() == game.human
	if not table.dealt:
		hint.text = "Pulsa el mazo para repartir %d cartas." % game.draft_pool.size()
	elif table_busy:
		hint.text = "Repartiendo..."
	elif my_turn:
		hint.text = "Te toca: pulsa una carta y «Tomar carta», o arrástrala al panel de la derecha."
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
		note = "no cabe en tu cuartel" if not card.hero else "necesitas un hueco de héroe (H)"
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
	_update_deck_label()
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


func _on_table_card_pressed(card: ChampionData) -> void:
	if table_busy:
		return
	selected_card = card
	table.select(card)
	if game.state == Game.State.DRAFT:
		_refresh_draft()
		if game.draft_current() == game.human and game.human.can_add(card):
			_begin_drag({ "kind": "table_card", "card": card }, Icons.archetype(card.archetype), card.display_name)
	elif game.state == Game.State.MARKET:
		_refresh_market()
		if game.human.can_add(card) and game.human.can_pay(card.cost):
			_begin_drag({ "kind": "table_card", "card": card }, Icons.archetype(card.archetype), card.display_name)


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
	_update_deck_label()
	table_busy = true
	_refresh_market()
	await table.deal(game.market)
	table_busy = false
	_refresh_market()


func _refresh_market() -> void:
	var h := game.human
	hint.text = "Compra con el tiempo que marca la barra; al acabarse pasas a la alineación."
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
	if not h.cuartel.has(selected_cuartel):
		selected_cuartel = null
	_refresh_hand()
	sell_button.disabled = selected_cuartel == null
	sell_button.text = "Vender de la mano" if selected_cuartel == null else "Vender %s (%d ◆)" % [selected_cuartel.data.display_name, h.sell_value(selected_cuartel)]
	_update_deck_label()
	_refresh()


## La mano: cartas del cuartel abajo, pequeñas; la que tiene el ratón encima se agranda.
func _refresh_hand() -> void:
	for c in hand_box.get_children():
		c.queue_free()
	var h := game.human
	for ch in h.cuartel:
		var cv := CardView.new()
		var extra := ""
		if game.state == Game.State.MARKET:
			extra = "vender por %d ◆" % h.sell_value(ch)
		elif game.state == Game.State.LINEUP:
			extra = "en el tablero ✔" if lineup.values().has(ch) else "en la mano"
		cv.setup(ch.data, ch, extra)
		cv.selected = ch == selected_cuartel or ch == pending_card
		cv.size_flags_vertical = Control.SIZE_SHRINK_END
		cv.scale = Vector2(HAND_SCALE, HAND_SCALE)
		# El pivote va en el borde inferior central para que la carta crezca hacia arriba.
		cv.resized.connect(func() -> void: cv.pivot_offset = Vector2(cv.size.x / 2.0, cv.size.y))
		cv.hovered.connect(_on_hand_hover)
		cv.unhovered.connect(_on_hand_unhover)
		cv.pressed.connect(func() -> void:
			if game.state == Game.State.MARKET:
				selected_cuartel = ch
				_refresh_market()
			elif game.state == Game.State.LINEUP:
				pending_card = null if pending_card == ch else ch
				_refresh_lineup()
				if pending_card != null:
					_begin_drag({ "kind": "cuartel_card", "champion": ch }, Icons.archetype(ch.data.archetype), ch.data.display_name))
		hand_box.add_child(cv)


func _on_hand_hover(cv: CardView) -> void:
	cv.z_index = 10
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(cv, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cv, "position:y", cv.position.y - 24, 0.12)


func _on_hand_unhover(cv: CardView) -> void:
	cv.z_index = 0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(cv, "scale", Vector2(HAND_SCALE, HAND_SCALE), 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cv, "position:y", cv.position.y + 24, 0.12)


func _finish_market() -> void:
	if game.state != Game.State.MARKET:
		return
	phase_left = 0.0
	if table_busy:
		await get_tree().create_timer(0.6).timeout
	game.finish_market()
	_enter_state()


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

func _on_tile_pressed(pos: Vector2i) -> void:
	if game.state != Game.State.LINEUP or Board.side_of(pos) != 0:
		return
	var key := Vector2i(pos.x, Board.row_of(pos))
	if pending_card != null:
		_place_in_lineup(pending_card, key)
		pending_card = null
		_refresh_lineup()
	elif lineup.has(key):
		var ch: Champion = lineup[key]
		_begin_drag({ "kind": "piece", "champion": ch, "from": key }, Icons.archetype(ch.data.archetype), ch.data.display_name)


func _place_in_lineup(ch: Champion, key: Vector2i) -> void:
	for k in lineup.keys():
		if lineup[k] == ch:
			lineup.erase(k)
	var other: Champion = lineup.get(key, null)
	lineup[key] = ch
	if other != null and other != ch:
		# Intercambio: el que estaba va a la casilla libre más cercana o se queda fuera.
		for row in range(1, Rules.BOARD_ROWS + 1):
			for col in Rules.BOARD_COLS:
				var k := Vector2i(col, row)
				if not lineup.has(k):
					lineup[k] = other
					return


func _refresh_lineup() -> void:
	hint.text = "Coloca hasta %d campeones en tu lado del tablero." % game.human.battle_size()
	_refresh_hand()
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


func _on_lineup_done(by_timeout: bool) -> void:
	if game.state != Game.State.LINEUP:
		return
	var errors := game.set_lineup(lineup)
	if not errors.is_empty():
		if by_timeout:
			game.set_lineup(Game.auto_lineup(game.human))
		else:
			lineup_info.text = "\n".join(errors)
			return
	_enter_state()


# ---------------------------------------------------------------- arrastrar y soltar

func _begin_drag(data: Dictionary, icon: Texture2D, text: String) -> void:
	drag = data
	drag_active = false
	drag_origin = get_viewport().get_mouse_position()
	drag_preview_icon.texture = icon
	drag_preview_label.text = text
	drag_preview.visible = false


func _input(event: InputEvent) -> void:
	if drag.is_empty():
		return
	if event is InputEventMouseMotion:
		var pos: Vector2 = event.position
		if not drag_active and pos.distance_to(drag_origin) > DRAG_THRESHOLD:
			drag_active = true
			drag_preview.visible = true
		if drag_active:
			drag_preview.position = pos + Vector2(14, 14)
			if drag["kind"] == "table_card":
				right_panel.modulate = Color(1.2, 1.15, 1.0) if right_panel.get_global_rect().has_point(pos) else Color.WHITE
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_end_drag(event.position)


func _end_drag(pos: Vector2) -> void:
	var data := drag
	var active := drag_active
	drag = {}
	drag_active = false
	drag_preview.visible = false
	right_panel.modulate = Color.WHITE
	match data.get("kind", ""):
		"cuartel_card":
			if not active:
				return # Fue un clic: queda seleccionada para colocar con otro clic.
			var tile := _tile_under_mouse(pos)
			if tile.x >= 0 and Board.side_of(tile) == 0:
				_place_in_lineup(data["champion"], Vector2i(tile.x, Board.row_of(tile)))
				pending_card = null
			_refresh_lineup()
		"piece":
			var tile := _tile_under_mouse(pos)
			var ch: Champion = data["champion"]
			if tile.x >= 0 and Board.side_of(tile) == 0:
				_place_in_lineup(ch, Vector2i(tile.x, Board.row_of(tile)))
			else:
				for k in lineup.keys():
					if lineup[k] == ch:
						lineup.erase(k)
			_refresh_lineup()
		"table_card":
			if active and right_panel.get_global_rect().has_point(pos):
				selected_card = data["card"]
				if game.state == Game.State.DRAFT:
					_on_take_card()
				elif game.state == Game.State.MARKET:
					_on_buy_card()


func _tile_under_mouse(pos: Vector2) -> Vector2i:
	var from := camera.project_ray_origin(pos)
	var to := from + camera.project_ray_normal(pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector2i(-1, -1)
	return board3d.bodies.get(hit["collider"], Vector2i(-1, -1))


# ---------------------------------------------------------------- batalla

func _start_battle_loop() -> void:
	_auto_token += 1
	_battle_loop(_auto_token)


func _battle_loop(token: int) -> void:
	while token == _auto_token and game.state == Game.State.BATTLE and game.current_battle != null and not battle_paused:
		await _play_round()
		if token != _auto_token or game.state != Game.State.BATTLE or battle_paused:
			return
		var left := AUTO_ROUND_SECONDS
		while left > 0.0 and token == _auto_token and not battle_paused and game.state == Game.State.BATTLE:
			battle_status.text = "Siguiente asalto en %.1f s." % left
			await get_tree().create_timer(0.25).timeout
			left -= 0.25


func _toggle_pause() -> void:
	battle_paused = not battle_paused
	if battle_paused:
		_auto_token += 1
	else:
		_start_battle_loop()
	_refresh_battle()


func _step_round() -> void:
	if battle_playing or game.state != Game.State.BATTLE:
		return
	await _play_round()


## Resuelve un asalto y lo anima evento a evento.
func _play_round() -> void:
	if battle_playing or game.current_battle == null:
		return
	battle_playing = true
	var battle := game.current_battle
	battle.commit_round()
	var evs := battle.events.duplicate()
	_refresh()
	await _animate_events(battle, evs)
	var finished := not battle.begin_round()
	battle_playing = false
	if finished:
		game.advance()
		_announce_battle(battle)
		_enter_state()
	else:
		_refresh_battle()


func _announce_battle(battle: Battle) -> void:
	var r := battle.result
	if r.get("tie", false):
		_celebrate("Empate", GameTheme.TEXT_DIM, false)
	elif r.get("winner") == game.human:
		_celebrate("¡VICTORIA!", GameTheme.GOLD, true)
	else:
		_celebrate("Derrota", Color(0.95, 0.45, 0.4), false)


func _animate_events(battle: Battle, evs: Array) -> void:
	for e in evs:
		if game.current_battle != battle:
			return
		var ch: Champion = e.get("ch", null)
		var piece: ChampionPiece = board3d.piece_of(ch) if ch != null else null
		match e["type"]:
			"move":
				if piece != null:
					var tw := create_tween()
					tw.tween_property(piece, "position", Board3D.world_pos(e["to"]), 0.28).set_trans(Tween.TRANS_SINE)
					await tw.finished
			"attack":
				var target_piece: ChampionPiece = board3d.piece_of(e["target"])
				if piece != null and target_piece != null:
					if ch.data.reach() == 1:
						await piece.lunge(target_piece.position).finished
					else:
						Fx.beam(board3d, piece.position, target_piece.position, Icons.color_of(ch.data))
						await get_tree().create_timer(0.2).timeout
			"damage":
				if piece != null:
					piece.show_hp(e["hp"])
					if e["amount"] > 0:
						piece.flash(Color.WHITE)
						piece.shake()
						Fx.float_text(board3d, piece.position, "-%d" % e["amount"], Color(1, 0.35, 0.3))
						Fx.burst(board3d, piece.position + Vector3(0, 0.5, 0), Color(1, 0.3, 0.2) if not e["power"] else Color(1, 0.6, 0.2), 14, 0.05)
					else:
						Fx.float_text(board3d, piece.position, "0", Color(0.7, 0.7, 0.7), 40)
					await get_tree().create_timer(0.22).timeout
			"heal":
				if piece != null:
					piece.show_hp(e["hp"])
					Fx.float_text(board3d, piece.position, "+%d" % e["amount"], Color(0.5, 1, 0.5))
					Fx.burst(board3d, piece.position + Vector3(0, 0.5, 0), Color(0.5, 1, 0.5), 16, 0.05)
					await get_tree().create_timer(0.2).timeout
			"power":
				if piece != null:
					var color: Color = Icons.ELEMENT_COLORS.get(e.get("element", -1), GameTheme.GOLD)
					Fx.ring(board3d, piece.position, color, 1.0)
					Fx.burst(board3d, piece.position + Vector3(0, 0.6, 0), color, 36, 0.07)
					Fx.float_text(board3d, piece.position + Vector3(0, 0.4, 0), e["name"], Color(1, 0.9, 0.6), 48)
					await get_tree().create_timer(0.45).timeout
			"tier":
				var color: Color = Icons.ELEMENT_COLORS.get(e.get("element", -1), GameTheme.GOLD)
				var side: int = e["side"]
				var center := Vector3(Board3D.world_x(2), 0, Board3D.world_z(1) if side == 0 else Board3D.world_z(4))
				Fx.ring(board3d, center, color, 3.0)
				if piece != null:
					Fx.burst(board3d, piece.position + Vector3(0, 0.6, 0), color, 30, 0.07)
				_tier_banner(side, e["name"], color)
				_screen_flash(color)
				await get_tree().create_timer(0.6).timeout
			"dodge":
				if piece != null:
					Fx.float_text(board3d, piece.position, "¡esquiva!", Color(0.7, 0.95, 1), 44)
					await get_tree().create_timer(0.18).timeout
			"freeze":
				if piece != null:
					piece.refresh()
					piece.flash(Color(0.6, 0.85, 1))
					Fx.float_text(board3d, piece.position, "❄ congelado", Color(0.6, 0.85, 1), 44)
					await get_tree().create_timer(0.18).timeout
			"curse":
				if piece != null:
					piece.refresh()
					Fx.float_text(board3d, piece.position, "☠ maldito", Color(0.8, 0.5, 1), 44)
					await get_tree().create_timer(0.18).timeout
			"death":
				if piece != null:
					Fx.burst(board3d, piece.position + Vector3(0, 0.4, 0), Color(0.5, 0.5, 0.55), 30, 0.08)
					Fx.float_text(board3d, piece.position, "✖", Color(0.9, 0.9, 0.9), 60)
					await get_tree().create_timer(0.25).timeout
	board3d.sync(battle.board.cells, true)
	_refresh()


func _tier_banner(side: int, text: String, color: Color) -> void:
	var l := tier_label_bottom if side == 0 else tier_label_top
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.visible = true
	l.modulate = Color(1, 1, 1, 0)
	l.scale = Vector2(0.6, 0.6)
	l.pivot_offset = l.size / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.tween_property(l, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(0.7)
	tw.chain().tween_property(l, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(func() -> void: l.visible = false)


func _screen_flash(color: Color) -> void:
	flash_rect.color = Color(color.r, color.g, color.b, 0.22)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.45)


## Cartel grande con partículas: victoria/derrota de una batalla y fin de la partida.
func _celebrate(text: String, color: Color, big: bool) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.modulate = Color(1, 1, 1, 0)
	banner.scale = Vector2(0.4, 0.4)
	await get_tree().process_frame
	banner.pivot_offset = banner.size / 2.0
	banner.position = (fx_layer.size - banner.size) / 2.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(2.2 if big else 1.4)
	tw.chain().tween_property(banner, "modulate:a", 0.0, 0.5)
	tw.chain().tween_callback(func() -> void: banner.visible = false)
	if big:
		banner_particles.position = fx_layer.size / 2.0 + Vector2(0, 60)
		banner_particles.color = color
		banner_particles.restart()
		banner_particles.emitting = true
		_screen_flash(color)


func _refresh_battle() -> void:
	var battle := game.current_battle
	if battle == null:
		return
	hint.text = "Fichas con anillo rojo: rival. Detén la batalla para verla asalto a asalto."
	battle_title.text = "Batalla contra %s — asalto %d de %d" % [battle.adalids[1].display_name, battle.round_no, Rules.ROUNDS_PER_BATTLE]
	battle_status.text = "Detenida. Pulsa «Siguiente asalto» para avanzar." if battle_paused else "Automática: un asalto cada %d s." % int(AUTO_ROUND_SECONDS)
	pause_button.text = "▶ Reanudar" if battle_paused else "⏸ Detener"
	step_button.visible = battle_paused
	if not battle_playing:
		board3d.sync(battle.board.cells, true)
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
				selected_card = pick
				table.select(pick)
				_refresh_draft()
				await _on_take_card()
		while table_busy:
			await get_tree().process_frame
	while table_busy:
		await get_tree().process_frame
	if game.state == Game.State.MARKET and not game.market.is_empty():
		selected_card = game.market[0]
		table.select(selected_card)
		_refresh_market()
	await _snap(dir.path_join("2_mercado.png"))
	_toggle_skills()
	await _snap(dir.path_join("2_habilidades.png"))
	_toggle_skills()
	if game.state == Game.State.MARKET:
		await _on_buy_card()
		_finish_market()
		pending_card = game.human.cuartel[0]
		_refresh_lineup()
		await _snap(dir.path_join("3_alineacion.png"))
		pending_card = null
		_on_lineup_done(false)
	if game.state == Game.State.BATTLE:
		_toggle_pause()
		await _snap(dir.path_join("4_batalla.png"))
		_step_round()
		await get_tree().create_timer(0.9).timeout
		await _snap(dir.path_join("5_batalla_animando.png"))
		while battle_playing:
			await get_tree().process_frame
		await _snap(dir.path_join("6_batalla_resuelta.png"))
		_toggle_pause()
		while game.state == Game.State.BATTLE:
			await get_tree().process_frame
		await get_tree().create_timer(0.6).timeout
		await _snap(dir.path_join("7_resultado.png"))
	get_tree().quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
