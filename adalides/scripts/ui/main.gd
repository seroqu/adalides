extends Node3D
## Partida v2 en 3D: tú contra cinco IA. El tablero y las cartas del draft y
## del mercado viven en la escena 3D; las fases se controlan desde una capa 2D.
## Los asaltos se resuelven solos y se animan evento a evento.

const NAMES: PackedStringArray = ["Tú", "Bruno", "Carla", "Dani", "Eva", "Fito"]
const AUTO_ROUND_SECONDS := 2.0
const MARKET_SECONDS := 60
const LINEUP_SECONDS := 30
const DRAG_THRESHOLD := 8.0
const HAND_SCALE := 0.85
const HAND_CARD_W := 170.0

const HELP_TEXT := """[b]Objetivo.[/b] Eres un adalid con 30 de vida. Cada ciclo armas un ejército de campeones y lo enfrentas al de otro adalid en una batalla automática de 4 asaltos. Pierdes vida al perder batallas; el último en pie es el nuevo demiurgo.

[b]Draft (solo el primer ciclo).[/b] Pulsa el mazo para repartir; cada adalid toma 2 cartas por turnos.

[b]Mercado (60 s).[/b] Compra campeones con Éter (◆), refresca el mercado por 2 ◆, vende cartas de tu mano por la mitad de su coste y sube tus tres pistas: tamaño del cuartel, campeones en batalla y dados. Cada mejora cuesta 5 ◆ más que la anterior de su pista. Los héroes (★) necesitan un hueco H del cuartel.

[b]Copias.[/b] La segunda copia de una carta da +1/+1; la tercera y la cuarta activan su poder mejorado (AFI 1 y AFI 2).

[b]Alineación (30 s).[/b] Arrastra las cartas de tu mano a tu lado del tablero (hasta el tope de tu pista). La fila junto a la línea dorada es el frente: alcance 1 salvo Arquero (3) y Mago (2).

[b]Batalla.[/b] Cada asalto los campeones avanzan un paso, atacan al rival más cercano y usan sus poderes. Lanzas tantos dados de tres caras (−, neutra, +) como marque tu pista de Dados; el motor los reparte entre los poderes. Tres, seis o nueve campeones del mismo elemento (o dos, cuatro o seis del mismo arquetipo) en batalla activan sus tiers.

[b]Éter por ciclo.[/b] 10, más 3 por cada 10 ahorrados, más el bono de racha (victorias o derrotas seguidas). Pulsa «Habilidades» para ver qué tiers tienes a mano y «Adalides» para la tabla."""

var game: Game
var board3d: Board3D
var table: DraftTable
var camera: Camera3D
var cam_tw: Tween

var ui: CanvasLayer
var root: Control
var seed_edit: LineEdit
var standings: RichTextLabel
var standings_panel: PanelContainer
var log_label: RichTextLabel
var phase_title: Label
var hint: Label
var hud: RichTextLabel
var panels: Dictionary = {}
var top_bar: PanelContainer
var side: VBoxContainer
var right_panel: Control # Zona donde se sueltan las cartas de la mesa (el panel lateral).
var fx_layer: Control
var banner: Label
var banner_particles: CPUParticles2D
var flash_rect: ColorRect
var tier_label_top: Label
var tier_label_bottom: Label

var selected_card: ChampionData = null
var table_busy: bool = false
var card_detail: VBoxContainer
var take_button: Button
var skip_button: Button
var buy_button: Button
var market_detail: VBoxContainer
var phase_left: float = 0.0
var phase_total: float = 1.0
var phase_bar: ProgressBar
var phase_time: Label
var timer_row: HBoxContainer
var log_panel: PanelContainer
var hand_panel: Control
var hand_box: HBoxContainer
var skills_panel: PanelContainer
var skills_box: VBoxContainer
var help_panel: PanelContainer
var menu_panel: Control
var menu_box: VBoxContainer
var menu_title: Label
var in_main_menu: bool = true
var paused_menu: bool = false

var upgrade_buttons: Dictionary = {}
var upgrade_pips: Dictionary = {}
var shop_eter: Label
var refresh_button: Button
var sell_button: Button
var selected_cuartel: Champion = null

var lineup: Dictionary = {}
var lineup_info: Label
var pending_card: Champion = null

var drag: Dictionary = {}
var drag_origin := Vector2.ZERO
var drag_active: bool = false
var drag_preview: PanelContainer
var drag_preview_label: Label
var drag_preview_icon: TextureRect

var battle_title: Label
var battle_status: Label
var pause_button: Button
var step_button: Button
var battle_paused: bool = false
var battle_playing: bool = false
var _auto_token: int = 0
var _last_hit: Dictionary = {} # Dirección, elemento y color del último ataque animado.


func _ready() -> void:
	_build_world()
	_build_ui()
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--screenshots":
		_screenshot_tour(args[1])
	else:
		_show_main_menu()


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
	camera.fov = 50
	camera.h_offset = 0.55 # El panel lateral derecho ocupa sitio: el tablero se centra en lo que queda.
	camera.v_offset = -0.75 # El tablero sube para dejar sitio a la mano de cartas.
	add_child(camera)
	_camera_view(View.BOARD, false)


enum View { BOARD, DRAFT, MARKET }


## Vista de la cámara: sobre el tablero de batalla o, en draft y mercado, cerca de las cartas.
func _camera_view(view: View, animate := true) -> void:
	var center := Vector3(Board3D.world_x(2), 0, (Board3D.world_z(0) + Board3D.world_z(5)) / 2.0)
	var from: Vector3
	var at: Vector3
	var v_off := -0.75
	if view == View.DRAFT:
		from = Vector3(-1.3, 7.6, -4.3)
		at = Vector3(-1.3, 0.0, 1.0)
		v_off = -0.3
	elif view == View.MARKET:
		from = Vector3(-1.1, 6.0, -2.9)
		at = Vector3(-1.1, 0.0, 1.6)
		v_off = -0.55
	else:
		from = center + Vector3(0, 9.2, -5.4)
		at = center + Vector3(0, 0, 0.2)
	var t := Transform3D(Basis(), from).looking_at(at, Vector3.UP)
	if cam_tw != null and cam_tw.is_valid():
		cam_tw.kill()
	if animate:
		cam_tw = create_tween()
		cam_tw.set_parallel(true)
		cam_tw.tween_property(camera, "transform", t, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cam_tw.tween_property(camera, "v_offset", v_off, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		camera.transform = t
		camera.v_offset = v_off


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.process_mode = Node.PROCESS_MODE_ALWAYS # Los menús funcionan con el juego en pausa.
	add_child(ui)
	root = Control.new()
	root.theme = GameTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# Barra superior: tus recursos, la fase con su tiempo y los accesos.
	top_bar = PanelContainer.new()
	top_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_left = 12
	top_bar.offset_right = -12
	top_bar.offset_top = 10
	var ts := GameTheme.panel_style()
	ts.content_margin_top = 6
	ts.content_margin_bottom = 6
	ts.content_margin_left = 16
	ts.content_margin_right = 10
	top_bar.add_theme_stylebox_override("panel", ts)
	root.add_child(top_bar)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 14)
	top_bar.add_child(trow)
	hud = RichTextLabel.new()
	hud.bbcode_enabled = true
	hud.fit_content = true
	hud.scroll_active = false
	hud.autowrap_mode = TextServer.AUTOWRAP_OFF
	hud.custom_minimum_size.x = 250
	hud.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	hud.add_theme_font_size_override("normal_font_size", 22)
	hud.add_theme_font_override("normal_font", GameTheme.bold_font)
	trow.add_child(hud)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 2)
	trow.add_child(center)
	phase_title = GameTheme.title("", 21)
	phase_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(phase_title)
	timer_row = HBoxContainer.new()
	timer_row.add_theme_constant_override("separation", 8)
	center.add_child(timer_row)
	var spacer_l := Control.new()
	spacer_l.custom_minimum_size.x = 60
	timer_row.add_child(spacer_l)
	phase_bar = ProgressBar.new()
	phase_bar.min_value = 0
	phase_bar.max_value = 1
	phase_bar.value = 1
	phase_bar.show_percentage = false
	phase_bar.custom_minimum_size = Vector2(0, 8)
	phase_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phase_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := StyleBoxFlat.new()
	fill.bg_color = GameTheme.GOLD
	fill.set_corner_radius_all(4)
	phase_bar.add_theme_stylebox_override("fill", fill)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.09, 0.14)
	bg.border_color = GameTheme.GOLD_DIM
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	phase_bar.add_theme_stylebox_override("background", bg)
	timer_row.add_child(phase_bar)
	phase_time = GameTheme.heading("0 s", 14)
	phase_time.custom_minimum_size.x = 60
	phase_time.autowrap_mode = TextServer.AUTOWRAP_OFF
	timer_row.add_child(phase_time)
	hint = _label("")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	hint.add_theme_font_size_override("font_size", 13)
	center.add_child(hint)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	tools.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	trow.add_child(tools)
	tools.add_child(_tool_button("Adalides", func() -> void: _toggle_overlay(standings_panel)))
	tools.add_child(_tool_button("Habilidades", _toggle_skills))
	tools.add_child(_tool_button("Crónica", func() -> void: _toggle_overlay(log_panel)))
	var menu_b := _tool_button("☰", _toggle_pause_menu)
	menu_b.add_theme_font_size_override("font_size", 18)
	tools.add_child(menu_b)

	# Columna lateral: solo los controles de la fase actual, sin marco vacío.
	side = VBoxContainer.new()
	side.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	side.offset_left = -344
	side.offset_right = -12
	side.offset_top = 92
	side.add_theme_constant_override("separation", 8)
	root.add_child(side)
	right_panel = side
	panels[Game.State.DRAFT] = _build_draft_panel()
	panels[Game.State.MARKET] = _build_market_panel()
	panels[Game.State.LINEUP] = _build_lineup_panel()
	panels[Game.State.BATTLE] = _build_battle_panel()
	for st in [Game.State.DRAFT, Game.State.MARKET, Game.State.LINEUP, Game.State.BATTLE]:
		side.add_child(panels[st])
	panels[Game.State.CYCLE_END] = _build_cycle_end_panel()
	panels[Game.State.OVER] = _build_over_panel()
	for st in [Game.State.CYCLE_END, Game.State.OVER]:
		root.add_child(panels[st])

	# Tablas desplegables: adalides, crónica, habilidades y cómo se juega.
	standings_panel = _overlay(Vector2(520, 0), true)
	var sv := VBoxContainer.new()
	standings_panel.add_child(sv)
	sv.add_child(_overlay_header("Adalides", standings_panel))
	standings = RichTextLabel.new()
	standings.bbcode_enabled = true
	standings.fit_content = true
	standings.scroll_active = false
	standings.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	standings.add_theme_font_size_override("normal_font_size", 15)
	sv.add_child(standings)
	log_panel = _overlay(Vector2(560, 520), false)
	var lv := VBoxContainer.new()
	log_panel.add_child(lv)
	lv.add_child(_overlay_header("Crónica", log_panel))
	log_label = RichTextLabel.new()
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.scroll_following = true
	lv.add_child(log_label)
	skills_panel = _overlay(Vector2(900, 600), false)
	var skv := VBoxContainer.new()
	skills_panel.add_child(skv)
	skv.add_child(_overlay_header("Habilidades y lo que tienes", skills_panel))
	skills_box = VBoxContainer.new()
	skills_box.add_theme_constant_override("separation", 6)
	skv.add_child(_scroll(skills_box))
	help_panel = _overlay(Vector2(760, 600), false)
	var hv := VBoxContainer.new()
	help_panel.add_child(hv)
	hv.add_child(_overlay_header("Cómo se juega", help_panel))
	var help := RichTextLabel.new()
	help.bbcode_enabled = true
	help.size_flags_vertical = Control.SIZE_EXPAND_FILL
	help.add_theme_font_size_override("normal_font_size", 15)
	help.add_theme_font_size_override("bold_font_size", 15)
	help.add_theme_font_override("bold_font", GameTheme.bold_font)
	help.text = HELP_TEXT
	hv.add_child(help)

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
	hand_panel.offset_left = 12
	hand_panel.offset_right = -356
	hand_panel.offset_top = -250
	hand_panel.offset_bottom = -6
	hand_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_panel.visible = false
	root.add_child(hand_panel)
	hand_box = HBoxContainer.new()
	hand_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_box.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_box.add_theme_constant_override("separation", -34)
	hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_panel.add_child(hand_box)

	# Menú: pantalla inicial y pausa.
	menu_panel = Control.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_panel.visible = false
	root.add_child(menu_panel)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.01, 0.05, 0.6)
	menu_panel.add_child(veil)
	var mp := PanelContainer.new()
	mp.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mp.grow_vertical = Control.GROW_DIRECTION_BOTH
	var ms := GameTheme.panel_style()
	ms.set_content_margin_all(28)
	ms.bg_color = Color(0.05, 0.04, 0.09, 0.96)
	ms.border_color = GameTheme.GOLD
	mp.add_theme_stylebox_override("panel", ms)
	menu_panel.add_child(mp)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	menu_box.custom_minimum_size.x = 440
	mp.add_child(menu_box)
	menu_title = GameTheme.title("Adalides del demiurgo", 36)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	menu_box.add_child(menu_title)
	var sub := _label("Autobatallas de arquetipos y elementos")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	sub.name = "Subtitle"
	menu_box.add_child(sub)
	menu_box.add_child(_menu_button("Jugar", _start_game, true, "Play"))
	menu_box.add_child(_menu_button("Reanudar", _toggle_pause_menu, true, "Resume"))
	menu_box.add_child(_menu_button("Partida nueva", func() -> void:
		_toggle_pause_menu()
		_start_game(), false, "New"))
	menu_box.add_child(_menu_button("Cómo se juega", func() -> void: _toggle_overlay(help_panel), false, "Help"))
	menu_box.add_child(_menu_button("Menú principal", _show_main_menu, false, "Main"))
	menu_box.add_child(_menu_button("Salir", func() -> void: get_tree().quit(), false, "Quit"))
	var seed_row := HBoxContainer.new()
	seed_row.name = "Seed"
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_row.add_theme_constant_override("separation", 8)
	menu_box.add_child(seed_row)
	var seed_label := _label("Semilla")
	seed_label.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	seed_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seed_row.add_child(seed_label)
	seed_edit = LineEdit.new()
	seed_edit.text = "0"
	seed_edit.placeholder_text = "número"
	seed_edit.custom_minimum_size.x = 120
	seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_row.add_child(seed_edit)


func _tool_button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_pressed)
	return b


func _menu_button(text: String, on_pressed: Callable, primary: bool, name_id: String) -> Button:
	var b := Button.new()
	b.name = name_id
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(on_pressed)
	if primary:
		GameTheme.primary_button(b)
		b.add_theme_font_size_override("font_size", 19)
	return b


## Panel centrado que se muestra y oculta con un botón (tabla, crónica, habilidades…).
func _overlay(min_size: Vector2, shrink: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -min_size.x / 2.0
	p.offset_right = min_size.x / 2.0
	p.offset_top = -min_size.y / 2.0
	p.offset_bottom = min_size.y / 2.0
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	if shrink:
		p.custom_minimum_size = min_size
	p.visible = false
	var s := GameTheme.panel_style()
	s.bg_color = Color(0.05, 0.04, 0.09, 0.97)
	s.set_content_margin_all(16)
	p.add_theme_stylebox_override("panel", s)
	root.add_child(p)
	return p


func _overlay_header(text: String, panel: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	var t := GameTheme.title(text, 19)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func() -> void: panel.visible = false)
	row.add_child(close)
	return row


func _toggle_overlay(panel: Control) -> void:
	var show := not panel.visible
	for p in [standings_panel, log_panel, skills_panel, help_panel]:
		p.visible = false
	panel.visible = show
	if show and panel == skills_panel and game != null:
		_refresh_skills()


# ---------------------------------------------------------------- menú

func _show_main_menu() -> void:
	get_tree().paused = false
	paused_menu = false
	in_main_menu = true
	_auto_token += 1
	battle_playing = false
	game = null
	table.clear()
	table.visible = false
	hand_panel.visible = false
	top_bar.visible = false
	side.visible = false
	for p in [standings_panel, log_panel, skills_panel, help_panel]:
		p.visible = false
	for st in panels:
		panels[st].visible = false
	_decorate_board()
	_camera_view(View.BOARD, false)
	_set_menu_mode(true)
	menu_panel.visible = true


## Un tablero de muestra con campeones en reposo detrás del menú principal.
func _decorate_board() -> void:
	board3d.clear_pieces()
	board3d.set_mat_visible(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pool := Catalog.base_cards()
	var cells := {}
	for i in 5:
		var a := Champion.new(pool[rng.randi_range(0, pool.size() - 1)])
		a.side = 0
		cells[Board.pos_from(0, 1 if i % 2 == 0 else 2, i)] = a
		var b := Champion.new(pool[rng.randi_range(0, pool.size() - 1)])
		b.side = 1
		cells[Board.pos_from(1, 1 if i % 2 == 1 else 2, i)] = b
	board3d.sync(cells, false)


func _set_menu_mode(main: bool) -> void:
	menu_title.text = "Adalides del demiurgo" if main else "Pausa"
	menu_box.get_node("Subtitle").visible = main
	menu_box.get_node("Play").visible = main
	menu_box.get_node("Seed").visible = main
	menu_box.get_node("Resume").visible = not main
	menu_box.get_node("New").visible = not main
	menu_box.get_node("Main").visible = not main


func _start_game() -> void:
	in_main_menu = false
	menu_panel.visible = false
	top_bar.visible = true
	side.visible = true
	_new_game()


func _toggle_pause_menu() -> void:
	if in_main_menu:
		return
	paused_menu = not paused_menu
	get_tree().paused = paused_menu
	_set_menu_mode(false)
	menu_panel.visible = paused_menu
	if not paused_menu:
		help_panel.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if help_panel.visible or skills_panel.visible or log_panel.visible or standings_panel.visible:
			for p in [standings_panel, log_panel, skills_panel, help_panel]:
				p.visible = false
		else:
			_toggle_pause_menu()


# ---------------------------------------------------------------- tiempo de fase

func _start_phase_timer(seconds: float) -> void:
	phase_total = seconds
	phase_left = seconds
	_update_phase_timer()


func _update_phase_timer() -> void:
	timer_row.visible = game != null and game.state in [Game.State.MARKET, Game.State.LINEUP]
	if not timer_row.visible:
		return
	phase_bar.value = clampf(phase_left / phase_total, 0.0, 1.0)
	var fill: StyleBoxFlat = phase_bar.get_theme_stylebox("fill")
	fill.bg_color = Color(1, 0.4, 0.3) if phase_left <= 10 else GameTheme.GOLD
	phase_time.text = "%d s" % ceili(phase_left)


func _process(delta: float) -> void:
	if game == null or phase_left <= 0.0 or game.state not in [Game.State.MARKET, Game.State.LINEUP]:
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


## Bloque con marco para la columna lateral.
func _block() -> PanelContainer:
	var p := PanelContainer.new()
	var s := GameTheme.panel_style()
	s.set_content_margin_all(12)
	p.add_theme_stylebox_override("panel", s)
	return p


func _build_draft_panel() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var block := _block()
	box.add_child(block)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 8)
	block.add_child(bv)
	bv.add_child(GameTheme.heading("Draft inicial · cada adalid toma 2", 15))
	var tip := _label("Pulsa una carta o arrástrala hasta aquí.")
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	bv.add_child(tip)
	card_detail = VBoxContainer.new()
	bv.add_child(card_detail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bv.add_child(row)
	take_button = Button.new()
	take_button.text = "Tomar carta"
	take_button.disabled = true
	take_button.custom_minimum_size = Vector2(0, 44)
	take_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	box.add_theme_constant_override("separation", 8)
	# Cabecera: nombre de la tienda y Éter en grande.
	var head := PanelContainer.new()
	var hs := GameTheme.panel_style()
	hs.bg_color = Color(0.16, 0.11, 0.06, 0.95)
	hs.border_color = GameTheme.GOLD
	hs.set_content_margin_all(10)
	head.add_theme_stylebox_override("panel", hs)
	box.add_child(head)
	var hrow := HBoxContainer.new()
	head.add_child(hrow)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(hv)
	hv.add_child(GameTheme.title("Mercado del Demiurgo", 18))
	var sub := _label("Compra, mejora o vende antes de que acabe el tiempo.")
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	hv.add_child(sub)
	shop_eter = GameTheme.title("◆ 0", 30)
	shop_eter.add_theme_color_override("font_color", Color(0.62, 0.8, 1.0))
	hrow.add_child(shop_eter)
	# Mejoras del tablero personal: una fila por pista.
	var ub := _block()
	box.add_child(ub)
	var uv := VBoxContainer.new()
	uv.add_theme_constant_override("separation", 4)
	ub.add_child(uv)
	uv.add_child(GameTheme.heading("Mejoras", 14))
	var icons := { Adalid.Track.CUARTEL: "⌂", Adalid.Track.BATTLE: "⚔", Adalid.Track.DICE: "⚅" }
	var names := { Adalid.Track.CUARTEL: "Cuartel", Adalid.Track.BATTLE: "En batalla", Adalid.Track.DICE: "Dados" }
	for track in [Adalid.Track.CUARTEL, Adalid.Track.BATTLE, Adalid.Track.DICE]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		uv.add_child(row)
		var tv := VBoxContainer.new()
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 0)
		row.add_child(tv)
		tv.add_child(GameTheme.heading("%s %s" % [icons[track], names[track]], 13))
		var pips := Label.new()
		pips.add_theme_font_size_override("font_size", 12)
		pips.add_theme_color_override("font_color", GameTheme.GOLD)
		tv.add_child(pips)
		upgrade_pips[track] = pips
		var b := Button.new()
		b.custom_minimum_size = Vector2(118, 36)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void:
			game.human_upgrade(track)
			_refresh_market())
		row.add_child(b)
		upgrade_buttons[track] = b
	# Carta elegida y acciones.
	var cb := _block()
	box.add_child(cb)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cb.add_child(cv)
	market_detail = VBoxContainer.new()
	cv.add_child(market_detail)
	var arow := HBoxContainer.new()
	arow.add_theme_constant_override("separation", 6)
	cv.add_child(arow)
	buy_button = Button.new()
	buy_button.text = "Comprar"
	buy_button.disabled = true
	buy_button.custom_minimum_size = Vector2(0, 44)
	buy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_button.add_theme_font_size_override("font_size", 16)
	buy_button.pressed.connect(_on_buy_card)
	GameTheme.primary_button(buy_button)
	arow.add_child(buy_button)
	refresh_button = Button.new()
	refresh_button.text = "⟳ %d ◆" % Rules.MARKET_REFRESH_COST
	refresh_button.tooltip_text = "Refrescar el mercado"
	refresh_button.custom_minimum_size = Vector2(0, 44)
	refresh_button.add_theme_font_size_override("font_size", 15)
	refresh_button.pressed.connect(_on_refresh_market)
	arow.add_child(refresh_button)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	cv.add_child(brow)
	sell_button = Button.new()
	sell_button.text = "Vender"
	sell_button.pressed.connect(_on_sell)
	brow.add_child(sell_button)
	var done := Button.new()
	done.text = "Listo, a alinear →"
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameTheme.primary_button(done)
	done.pressed.connect(_finish_market)
	brow.add_child(done)
	return box


func _build_lineup_panel() -> Control:
	var block := _block()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	block.add_child(box)
	box.add_child(GameTheme.heading("Alineación"))
	var tip := _label("Arrastra las cartas de tu mano a tu lado del tablero. La fila junto a la línea dorada es el frente.")
	tip.add_theme_font_size_override("font_size", 13)
	tip.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	box.add_child(tip)
	lineup_info = _label("")
	box.add_child(lineup_info)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	box.add_child(buttons)
	var auto := Button.new()
	auto.text = "Auto"
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
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.custom_minimum_size = Vector2(0, 44)
	GameTheme.primary_button(go)
	go.pressed.connect(func() -> void: _on_lineup_done(false))
	buttons.add_child(go)
	return block


func _build_battle_panel() -> Control:
	var block := _block()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	block.add_child(box)
	battle_title = GameTheme.heading("")
	box.add_child(battle_title)
	battle_status = _label("")
	battle_status.add_theme_font_size_override("font_size", 13)
	battle_status.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	box.add_child(battle_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	box.add_child(row)
	pause_button = Button.new()
	pause_button.text = "⏸ Detener"
	pause_button.custom_minimum_size = Vector2(0, 44)
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameTheme.primary_button(pause_button)
	pause_button.pressed.connect(_toggle_pause)
	row.add_child(pause_button)
	step_button = Button.new()
	step_button.text = "Asalto ▶"
	step_button.custom_minimum_size = Vector2(0, 44)
	step_button.visible = false
	step_button.pressed.connect(_step_round)
	row.add_child(step_button)
	block.tooltip_text = "Cada asalto lanzas tantos dados de tres caras (−, neutra, +) como marque tu pista de Dados; el motor los reparte entre los poderes."
	return block


## Fin de ciclo: tabla de adalides centrada y el botón para seguir.
func _build_cycle_end_panel() -> Control:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size.x = 520
	var s := GameTheme.panel_style()
	s.bg_color = Color(0.05, 0.04, 0.09, 0.97)
	s.border_color = GameTheme.GOLD
	s.set_content_margin_all(20)
	p.add_theme_stylebox_override("panel", s)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	var t := GameTheme.title("Fin del ciclo", 24)
	t.name = "Title"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var table_label := RichTextLabel.new()
	table_label.name = "Table"
	table_label.bbcode_enabled = true
	table_label.fit_content = true
	table_label.scroll_active = false
	table_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	table_label.add_theme_font_size_override("normal_font_size", 15)
	box.add_child(table_label)
	var next := Button.new()
	next.text = "Siguiente ciclo →"
	next.custom_minimum_size = Vector2(0, 46)
	GameTheme.primary_button(next)
	next.pressed.connect(_next_cycle)
	box.add_child(next)
	return p


func _build_over_panel() -> Control:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size.x = 520
	var s := GameTheme.panel_style()
	s.bg_color = Color(0.05, 0.04, 0.09, 0.97)
	s.border_color = GameTheme.GOLD
	s.set_content_margin_all(20)
	p.add_theme_stylebox_override("panel", s)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)
	var l := GameTheme.title("", 24)
	l.name = "Result"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(l)
	var table_label := RichTextLabel.new()
	table_label.name = "Table"
	table_label.bbcode_enabled = true
	table_label.fit_content = true
	table_label.scroll_active = false
	table_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	table_label.add_theme_font_size_override("normal_font_size", 15)
	box.add_child(table_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var again := Button.new()
	again.text = "Otra partida"
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.custom_minimum_size = Vector2(0, 46)
	GameTheme.primary_button(again)
	again.pressed.connect(_start_game)
	row.add_child(again)
	var menu := Button.new()
	menu.text = "Menú principal"
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.pressed.connect(_show_main_menu)
	row.add_child(menu)
	return p


# ---------------------------------------------------------------- habilidades

func _toggle_skills() -> void:
	_toggle_overlay(skills_panel)


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
	game = Game.new(NAMES, int(seed_edit.text) if seed_edit.text.is_valid_int() else hash(seed_edit.text))
	game.set_human(0)
	board3d.clear_pieces()
	table.clear()
	table.visible = false
	for st in panels:
		panels[st].visible = false
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
	var at_table := game.state in [Game.State.DRAFT, Game.State.MARKET]
	board3d.set_mat_visible(not at_table)
	if game.state == Game.State.DRAFT:
		_camera_view(View.DRAFT, true)
	elif game.state == Game.State.MARKET:
		_camera_view(View.MARKET, true)
	else:
		_camera_view(View.BOARD, true)
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
			(panels[Game.State.CYCLE_END].find_child("Title", true, false) as Label).text = "Fin del ciclo %d" % game.cycle
		Game.State.OVER:
			var res: Label = panels[Game.State.OVER].find_child("Result", true, false)
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
		hint.text = "Te toca elegir."
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
	cv.custom_minimum_size.x = 240
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
	hint.text = "Elige una carta de la mesa o de tu mano."
	shop_eter.text = "◆ %d" % h.eter
	for track in upgrade_buttons:
		var b: Button = upgrade_buttons[track]
		var track_values: Array = [Rules.CUARTEL_TRACK, Rules.BATTLE_TRACK, Rules.DICE_TRACK][track]
		var done_n: int = h.upgrades[track]
		var marks: PackedStringArray = []
		for i in track_values.size():
			marks.append(("[%s]" if i == done_n else " %s ") % str(track_values[i]))
		upgrade_pips[track].text = "".join(marks)
		if h.can_upgrade(track):
			b.text = "Subir a %s · %d ◆" % [str(track_values[done_n + 1]), h.upgrade_cost(track)]
			b.disabled = not h.can_pay(h.upgrade_cost(track))
		else:
			b.text = "Al máximo"
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
	sell_button.text = "Vender" if selected_cuartel == null else "Vender (+%d ◆)" % h.sell_value(selected_cuartel)
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
		cv.custom_minimum_size.x = HAND_CARD_W
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
	var n := h.cuartel.size()
	if n > 1:
		var visible_w := HAND_CARD_W * HAND_SCALE
		var pitch := minf(visible_w + 10.0, (hand_panel.size.x - visible_w) / float(n - 1))
		hand_box.add_theme_constant_override("separation", int(pitch - HAND_CARD_W))


## La carta crece desde su borde inferior (pivote abajo); nunca se mueve su
## posición, así un hover/unhover desparejado no la desplaza.
func _on_hand_hover(cv: CardView) -> void:
	if not is_instance_valid(cv):
		return
	cv.z_index = 10
	var tw := create_tween()
	tw.tween_property(cv, "scale", Vector2(1.12, 1.12), 0.12).set_trans(Tween.TRANS_SINE)


func _on_hand_unhover(cv: CardView) -> void:
	if not is_instance_valid(cv):
		return
	cv.z_index = 0
	var tw := create_tween()
	tw.tween_property(cv, "scale", Vector2(HAND_SCALE, HAND_SCALE), 0.12).set_trans(Tween.TRANS_SINE)


func _finish_market() -> void:
	if game.state != Game.State.MARKET:
		return
	phase_left = 0.0
	if table_busy:
		await get_tree().create_timer(0.6, false).timeout
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
			await get_tree().create_timer(0.25, false).timeout
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
	_last_hit = {}
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
					var color := Icons.color_of(ch.data)
					var dir := (target_piece.position - piece.position).normalized()
					_last_hit = { "dir": dir, "element": ch.data.element, "color": color }
					if ch.data.reach() == 1:
						Fx.dust_puff(board3d, piece.position, dir)
						var lunge := piece.lunge(target_piece.position)
						await get_tree().create_timer(0.11, false).timeout
						Fx.slash(board3d, target_piece.position + Vector3(0, 0.6, 0), color, -35.0 if dir.x <= 0 else 35.0)
						Fx.impact(board3d, target_piece.position, color, ch.data.element, dir, 0.8)
						_camera_shake(0.05)
						await lunge.finished
					else:
						piece.play_clip("attack")
						await Fx.projectile(board3d, piece.position, target_piece.position, color, ch.data.element, ch.data.reach() >= 3)
						Fx.impact(board3d, target_piece.position, color, ch.data.element, dir, 1.0)
						_camera_shake(0.03)
			"damage":
				if piece != null:
					piece.show_hp(e["hp"])
					if e["amount"] > 0:
						piece.flash(Color.WHITE)
						piece.shake()
						Fx.float_text(board3d, piece.position, "-%d" % e["amount"], Color(1, 0.35, 0.3), 56 + mini(e["amount"], 6) * 6)
						if e["power"] or _last_hit.is_empty():
							Fx.impact(board3d, piece.position, Color(1, 0.6, 0.2), -1, Vector3.UP, 0.7)
						else:
							Fx.burst(board3d, piece.position + Vector3(0, 0.6, 0), Color(1, 0.3, 0.2), 8, 0.05)
					else:
						Fx.float_text(board3d, piece.position, "0", Color(0.7, 0.7, 0.7), 40)
					await get_tree().create_timer(0.22, false).timeout
			"heal":
				if piece != null:
					piece.show_hp(e["hp"])
					Fx.float_text(board3d, piece.position, "+%d" % e["amount"], Color(0.5, 1, 0.5))
					Fx.burst(board3d, piece.position + Vector3(0, 0.5, 0), Color(0.5, 1, 0.5), 16, 0.05)
					await get_tree().create_timer(0.2, false).timeout
			"power":
				if piece != null:
					var color: Color = Icons.ELEMENT_COLORS.get(e.get("element", -1), GameTheme.GOLD)
					Fx.ring(board3d, piece.position, color, 1.0)
					Fx.burst(board3d, piece.position + Vector3(0, 0.6, 0), color, 36, 0.07)
					Fx.float_text(board3d, piece.position + Vector3(0, 0.4, 0), e["name"], Color(1, 0.9, 0.6), 48)
					await get_tree().create_timer(0.45, false).timeout
			"tier":
				var color: Color = Icons.ELEMENT_COLORS.get(e.get("element", -1), GameTheme.GOLD)
				var side: int = e["side"]
				var center := Vector3(Board3D.world_x(2), 0, Board3D.world_z(1) if side == 0 else Board3D.world_z(4))
				Fx.ring(board3d, center, color, 3.0)
				if piece != null:
					Fx.burst(board3d, piece.position + Vector3(0, 0.6, 0), color, 30, 0.07)
				_tier_banner(side, e["name"], color)
				_screen_flash(color)
				await get_tree().create_timer(0.6, false).timeout
			"dodge":
				if piece != null:
					Fx.float_text(board3d, piece.position, "¡esquiva!", Color(0.7, 0.95, 1), 44)
					await get_tree().create_timer(0.18, false).timeout
			"freeze":
				if piece != null:
					piece.refresh()
					piece.flash(Color(0.6, 0.85, 1))
					Fx.float_text(board3d, piece.position, "❄ congelado", Color(0.6, 0.85, 1), 44)
					await get_tree().create_timer(0.18, false).timeout
			"curse":
				if piece != null:
					piece.refresh()
					Fx.float_text(board3d, piece.position, "☠ maldito", Color(0.8, 0.5, 1), 44)
					await get_tree().create_timer(0.18, false).timeout
			"death":
				if piece != null:
					piece.play_clip("death")
					Fx.burst(board3d, piece.position + Vector3(0, 0.4, 0), Color(0.5, 0.5, 0.55), 30, 0.08)
					Fx.float_text(board3d, piece.position, "✖", Color(0.9, 0.9, 0.9), 60)
					await get_tree().create_timer(0.7 if piece.has_model() else 0.25, false).timeout
	board3d.sync(battle.board.cells, true)
	_refresh()


## Sacudida breve de la cámara al impactar un golpe.
func _camera_shake(amp: float) -> void:
	var base_h := camera.h_offset
	var base_v := camera.v_offset
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var k := (1.0 - t) * amp
		camera.h_offset = base_h + sin(t * 50.0) * k
		camera.v_offset = base_v + cos(t * 43.0) * k * 0.6, 0.0, 1.0, 0.25)
	tw.tween_callback(func() -> void:
		camera.h_offset = base_h
		camera.v_offset = base_v)


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
	hint.text = "Anillo azul: los tuyos · rojo: el rival."
	battle_title.text = "Batalla contra %s — asalto %d de %d" % [battle.adalids[1].display_name, battle.round_no, Rules.ROUNDS_PER_BATTLE]
	battle_status.text = "Detenida. Pulsa «Siguiente asalto» para avanzar." if battle_paused else "Automática: un asalto cada %d s." % int(AUTO_ROUND_SECONDS)
	pause_button.text = "▶ Reanudar" if battle_paused else "⏸ Detener"
	step_button.visible = battle_paused
	if not battle_playing:
		board3d.sync(battle.board.cells, true)
	_refresh()


# ---------------------------------------------------------------- refresco general

func _refresh() -> void:
	if game == null:
		return
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
	_update_phase_timer()
	var h := game.human
	var racha := ""
	if h.streak > 0:
		racha = "   [color=#f0d080]%s %d[/color]" % ["▲" if h.streak_is_win else "▼", h.streak]
	hud.text = "[color=#7ee07e]♥ %d[/color]   [color=#9ecbff]◆ %d[/color]%s" % [h.life, h.eter, racha]
	hud.tooltip_text = "Vida %d · Éter %d · Racha %s · Cuartel %d/%d · Héroes %d/%d · En batalla %d · Dados %d" % [
		h.life, h.eter, ("%s %d (+%d ◆)" % ["victorias" if h.streak_is_win else "derrotas", h.streak, h.streak_bonus()]) if h.streak > 0 else "—",
		h.base_count(), h.cuartel_capacity(), h.hero_count(), h.hero_slots(), h.battle_size(), h.dice_count()]
	var lines: PackedStringArray = ["[table=6][cell padding=6,2,6,2][b]Adalid[/b][/cell][cell padding=6,2,6,2][b]♥[/b][/cell][cell padding=6,2,6,2][b]◆[/b][/cell][cell padding=6,2,6,2][b]Cuartel[/b][/cell][cell padding=6,2,6,2][b]Batalla[/b][/cell][cell padding=6,2,6,2][b]Dados[/b][/cell]"]
	for a in game.adalids:
		var color := "#f0d080" if a == game.human else ("#777777" if a.eliminated else "#e8e4dc")
		lines.append("[cell padding=6,2,6,2][color=%s]%s%s[/color][/cell][cell padding=6,2,6,2][color=#7ee07e]%d[/color][/cell][cell padding=6,2,6,2][color=#9ecbff]%d[/color][/cell][cell padding=6,2,6,2]%d/%d[/cell][cell padding=6,2,6,2]%d[/cell][cell padding=6,2,6,2]%d[/cell]" % [
			color, "► " if a == game.human else "", a.display_name, a.life, a.eter, a.base_count(), a.cuartel_capacity(), a.battle_size(), a.dice_count()])
	lines.append("[/table]")
	standings.text = "\n".join(lines)
	for st in [Game.State.CYCLE_END, Game.State.OVER]:
		(panels[st].find_child("Table", true, false) as RichTextLabel).text = standings.text
	var text := "\n".join(game.log)
	if game.current_battle != null:
		text += "\n" + "\n".join(game.current_battle.log)
	log_label.text = text


# ---------------------------------------------------------------- capturas

func _screenshot_tour(dir: String) -> void:
	_show_main_menu()
	await _snap(dir.path_join("0_menu.png"))
	_start_game()
	await get_tree().create_timer(0.8, false).timeout
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
	_toggle_overlay(skills_panel)
	await _snap(dir.path_join("2_habilidades.png"))
	_toggle_overlay(skills_panel)
	_toggle_pause_menu()
	await _snap(dir.path_join("2_pausa.png"))
	_toggle_pause_menu()
	if game.state == Game.State.MARKET:
		await _on_buy_card()
		_finish_market()
		await get_tree().create_timer(0.8, false).timeout
		pending_card = game.human.cuartel[0]
		_refresh_lineup()
		await _snap(dir.path_join("3_alineacion.png"))
		pending_card = null
		_on_lineup_done(false)
	if game.state == Game.State.BATTLE:
		_toggle_pause()
		await _snap(dir.path_join("4_batalla.png"))
		_step_round()
		for i in 14:
			await get_tree().create_timer(0.12, false).timeout
			await _snap(dir.path_join("5_batalla_animando_%02d.png" % i))
		while battle_playing:
			await get_tree().process_frame
		await _snap(dir.path_join("6_batalla_resuelta.png"))
		_toggle_pause()
		while game.state == Game.State.BATTLE:
			await get_tree().process_frame
		await get_tree().create_timer(0.6, false).timeout
		await _snap(dir.path_join("7_resultado.png"))
		await get_tree().create_timer(2.4, false).timeout
		await _snap(dir.path_join("8_fin_ciclo.png"))
	get_tree().quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
