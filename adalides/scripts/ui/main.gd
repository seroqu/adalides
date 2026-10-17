class_name MainScene
extends Node3D
## Partida v2 en 3D: tú contra cinco IA. El tablero y las cartas del draft y
## del mercado viven en la escena 3D; las fases se controlan desde una capa 2D.
## Los asaltos se resuelven solos y se animan evento a evento.

const AI_NAMES: PackedStringArray = ["Kaelum de las Brasas", "Ysolda la Gélida", "Tharok Piedrafirme", "Selenia del Céfiro", "Vargo Truenante"]
const MODE_NAMES: PackedStringArray = ["Principiante", "Amateur", "Profesional"]
const MODE_TEXT: PackedStringArray = [
	"Los rivales eligen al azar y gastan con cautela. Para aprender sin prisa.",
	"Los rivales buscan combos y mejoran su tablero. La partida tal como está pensada.",
	"Los rivales refrescan el mercado, invierten pronto y no fallan un combo.",
]
const AUTO_ROUND_SECONDS := 2.0
const MARKET_SECONDS := 60
const LINEUP_SECONDS := 30
const DRAG_THRESHOLD := 8.0
const HAND_HOVER_SCALE := 1.3
const HAND_HOVER_RAISE := 70.0

var game: Game
var board3d: Board3D
var table: DraftTable
var camera: Camera3D
var cam_tw: Tween

var ui: CanvasLayer
var root: Control
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
var selected_card3d: Card3D = null # La carta física elegida (puede haber copias iguales en la mesa).
var table_busy: bool = false
var card_detail: VBoxContainer
var detail_panel: PanelContainer # Detalle de la carta seleccionada (abajo a la izquierda).
var detail_box: VBoxContainer
var tiers_panel: PanelContainer # Tiers activos en alineación y batalla (izquierda).
var tiers_box: VBoxContainer
var tool_buttons: Array[Button] = [] # Adalides, Habilidades, Crónica (se bloquean en el tutorial).
var drop_zone: PanelContainer
var drop_label: Label
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
var hand_box: Control
var skills_panel: PanelContainer
var skills_box: VBoxContainer
var help_panel: PanelContainer
var menu_panel: Control
var menu_box: VBoxContainer
var menu_title: Label
var in_main_menu: bool = true
var tutorial: Tutorial = null
var setup_mode: int = 1 # Game.Difficulty
var setup_players: int = 4
var setup_rounds: int = Rules.ROUNDS_PER_BATTLE # 0 = hasta el final.
var rounds_text: Label
var setup_box: VBoxContainer
var mode_text: Label
var lineup_go_button: Button
var lineup_auto_button: Button
var lineup_clear_button: Button
var market_done_button: Button
var next_cycle_button: Button
var paused_menu: bool = false

var upgrade_buttons: Dictionary = {}
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
var battle_round_label: Label
var battle_pips: HBoxContainer
var battle_names: Array[Label] = []
var battle_lives: Array[Label] = []
var battle_bars: Array[ProgressBar] = []
var battle_hp: Array[Label] = []
var _banner_tween: Tween
var battle_alive: Array[Label] = []
var hand_empty_label: Label
var deny_label: Label # Aviso rojo de acción no permitida.
var video_layer: Control
var video_player: VideoStreamPlayer
var video_title: Label
var _video_token: int = 0
var _video_on_done: Callable
var _deny_tween: Tween
var market_reason: Label # Por qué no se puede comprar/vender la selección.
var upgrade_chips: Dictionary = {} # Track → HBoxContainer con los pasos de la pista.
var upgrade_desc: Dictionary = {} # Track → Label con lo actual y lo siguiente.
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
	elif args.size() >= 2 and args[0] == "--tutorial":
		_tutorial_tour(args[1])
	elif args.size() >= 2 and args[0] == "--victory":
		_victory_tour(args[1])
	elif args.size() >= 2 and args[0] == "--intro":
		_intro_tour(args[1])
	else:
		_play_intro_video()


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
	ChampionPiece.warm_up.call_deferred(board3d)


enum View { BOARD, DRAFT, MARKET, LINEUP }


static func world_z_mid() -> float:
	return (Board3D.world_z(0) + Board3D.world_z(2)) / 2.0 - 0.2


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
	elif view == View.LINEUP:
		from = center + Vector3(0, 7.2, -6.0)
		at = Vector3(center.x, 0, world_z_mid())
		v_off = -0.6
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
	for pair in [["Adalides", func() -> void: _toggle_overlay(standings_panel)], ["Habilidades", _toggle_skills], ["Crónica", func() -> void: _toggle_overlay(log_panel)]]:
		var tb := _tool_button(pair[0], pair[1])
		tools.add_child(tb)
		tool_buttons.append(tb)
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
	help_panel = _overlay(Vector2(1040, 660), false)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 10)
	help_panel.add_child(hv)
	hv.add_child(_overlay_header("Cómo se juega", help_panel))
	hv.add_child(HelpPage.build())

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
	# Vídeo de victoria a pantalla completa (se salta con clic o Esc).
	video_layer = Control.new()
	video_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_layer.visible = false
	video_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	video_layer.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_skip_victory_video())
	root.add_child(video_layer)
	var black := ColorRect.new()
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_layer.add_child(black)
	video_player = VideoStreamPlayer.new()
	video_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video_player.expand = true
	video_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_layer.add_child(video_player)
	video_title = GameTheme.title("¡ERES EL NUEVO DEMIURGO!", 56)
	video_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	video_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	video_title.grow_vertical = Control.GROW_DIRECTION_BEGIN
	video_title.offset_top = -200
	video_title.offset_bottom = -110
	video_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	video_title.add_theme_color_override("font_outline_color", Color(0.25, 0.15, 0.02, 0.95))
	video_title.add_theme_constant_override("outline_size", 14)
	video_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_title.visible = false
	video_layer.add_child(video_title)
	var skip := _label("Clic o Esc para saltar")
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skip.offset_left = -220
	skip.offset_top = -40
	skip.offset_right = -16
	skip.offset_bottom = -14
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	skip.add_theme_font_size_override("font_size", 13)
	skip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video_layer.add_child(skip)
	deny_label = Label.new()
	deny_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	deny_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	deny_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	deny_label.offset_top = -300
	deny_label.offset_bottom = -270
	deny_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deny_label.add_theme_font_override("font", GameTheme.bold_font)
	deny_label.add_theme_font_size_override("font_size", 20)
	deny_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	deny_label.add_theme_color_override("font_outline_color", Color(0.15, 0, 0, 0.95))
	deny_label.add_theme_constant_override("outline_size", 8)
	deny_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deny_label.visible = false
	fx_layer.add_child(deny_label)
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
	hand_panel.offset_top = -262
	hand_panel.offset_bottom = -14
	hand_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_panel.visible = false
	root.add_child(hand_panel)
	hand_box = Control.new()
	hand_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hand_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_panel.add_child(hand_box)
	hand_panel.resized.connect(_layout_hand)
	# Detalle de la carta seleccionada: abajo a la izquierda, con botón para deseleccionar.
	detail_panel = PanelContainer.new()
	detail_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	detail_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	detail_panel.offset_left = 12
	detail_panel.offset_bottom = -14
	detail_panel.offset_right = 318
	detail_panel.custom_minimum_size.x = 306
	detail_panel.visible = false
	detail_panel.add_theme_stylebox_override("panel", GameTheme.panel_style())
	root.add_child(detail_panel)
	detail_box = VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 6)
	detail_panel.add_child(detail_box)
	# Tiers activos: izquierda, en alineación y batalla.
	tiers_panel = PanelContainer.new()
	tiers_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	tiers_panel.offset_left = 12
	tiers_panel.offset_top = 96
	tiers_panel.offset_right = 300
	tiers_panel.custom_minimum_size.x = 288
	tiers_panel.visible = false
	tiers_panel.add_theme_stylebox_override("panel", GameTheme.panel_style())
	root.add_child(tiers_panel)
	tiers_box = VBoxContainer.new()
	tiers_box.add_theme_constant_override("separation", 5)
	tiers_panel.add_child(tiers_box)
	hand_empty_label = _label("")
	hand_empty_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hand_empty_label.offset_top = -72
	hand_empty_label.offset_bottom = -12
	hand_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hand_empty_label.add_theme_font_size_override("font_size", 14)
	hand_empty_label.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	hand_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_empty_label.visible = false
	hand_panel.add_child(hand_empty_label)

	# Menú: pantalla inicial y pausa.
	menu_panel = Control.new()
	menu_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_panel.visible = false
	root.add_child(menu_panel)
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.02, 0.01, 0.05, 0.6)
	menu_panel.add_child(veil)
	# Viñeta: oscuridad que cierra los bordes (solo en el menú principal).
	var vignette := TextureRect.new()
	vignette.name = "Vignette"
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vt := GradientTexture2D.new()
	vt.fill = GradientTexture2D.FILL_RADIAL
	vt.fill_from = Vector2(0.5, 0.5)
	vt.fill_to = Vector2(0.5, 0.0)
	vt.width = 256
	vt.height = 256
	var vg := Fx.ramp([[0, Color(0.03, 0.01, 0.06, 0.0)], [0.55, Color(0.03, 0.01, 0.06, 0.35)], [1, Color(0.01, 0.0, 0.02, 0.97)]])
	vt.gradient = vg
	vignette.texture = vt
	menu_panel.add_child(vignette)
	# Brasas y motas violetas que suben lentamente.
	var embers := CPUParticles2D.new()
	embers.name = "Embers"
	embers.amount = 90
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(900, 60)
	embers.direction = Vector2(0, -1)
	embers.spread = 25
	embers.initial_velocity_min = 25
	embers.initial_velocity_max = 70
	embers.gravity = Vector2(0, -8)
	embers.scale_amount_min = 0.03
	embers.scale_amount_max = 0.09
	embers.texture = Fx.tex("circle_05")
	var eg := Fx.ramp([[0, Color(0.9, 0.6, 0.3, 0.0)], [0.2, Color(0.9, 0.55, 0.25, 0.9)], [0.7, Color(0.6, 0.3, 0.7, 0.7)], [1, Color(0.4, 0.2, 0.6, 0.0)]])
	embers.color_ramp = eg
	menu_panel.add_child(embers)
	menu_panel.resized.connect(func() -> void: embers.position = Vector2(menu_panel.size.x / 2.0, menu_panel.size.y + 40))
	var mp := PanelContainer.new()
	mp.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	mp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mp.grow_vertical = Control.GROW_DIRECTION_BOTH
	var ms := GameTheme.panel_style()
	ms.set_content_margin_all(28)
	ms.bg_color = Color(0.04, 0.03, 0.07, 0.9)
	ms.border_color = GameTheme.GOLD_DIM
	ms.shadow_size = 40
	ms.shadow_color = Color(0, 0, 0, 0.8)
	mp.add_theme_stylebox_override("panel", ms)
	menu_panel.add_child(mp)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 10)
	menu_box.custom_minimum_size.x = 440
	mp.add_child(menu_box)
	var emblem := DemiurgeEye.new()
	emblem.name = "Emblem"
	emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	menu_box.add_child(emblem)
	menu_title = GameTheme.title("Adalides del demiurgo", 34)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	menu_title.add_theme_constant_override("outline_size", 10)
	menu_title.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0.4, 0.9))
	menu_title.add_theme_constant_override("shadow_offset_x", 0)
	menu_title.add_theme_constant_override("shadow_offset_y", 4)
	menu_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	menu_box.add_child(menu_title)
	var glow_tw := create_tween().set_loops()
	glow_tw.tween_property(menu_title, "modulate", Color(1.0, 0.95, 0.85), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_tw.tween_property(menu_title, "modulate", Color(0.78, 0.7, 0.62), 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	menu_box.add_child(_menu_button("Jugar", func() -> void: _show_setup(true), true, "Play"))
	menu_box.add_child(_menu_button("Tutorial", _start_tutorial, false, "Tutorial"))
	menu_box.add_child(_menu_button("Reanudar", _toggle_pause_menu, true, "Resume"))
	menu_box.add_child(_menu_button("Partida nueva", func() -> void:
		_toggle_pause_menu()
		_start_game(), false, "New"))
	menu_box.add_child(_menu_button("Cómo se juega", func() -> void: _toggle_overlay(help_panel), false, "Help"))
	menu_box.add_child(_menu_button("Menú principal", _show_main_menu, false, "Main"))
	menu_box.add_child(_menu_button("Salir", func() -> void: get_tree().quit(), false, "Quit"))
	# Configuración de la partida: modo, número de adalides y semilla.
	setup_box = VBoxContainer.new()
	setup_box.name = "Setup"
	setup_box.add_theme_constant_override("separation", 8)
	setup_box.visible = false
	menu_box.add_child(setup_box)
	setup_box.add_child(GameTheme.heading("Modo", 14))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 6)
	setup_box.add_child(mode_row)
	var mode_group := ButtonGroup.new()
	for i in MODE_NAMES.size():
		var b := Button.new()
		b.text = MODE_NAMES[i]
		b.toggle_mode = true
		b.button_group = mode_group
		b.button_pressed = i == setup_mode
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 38
		b.add_theme_stylebox_override("pressed", GameTheme.button_style(Color(0.32, 0.24, 0.08), GameTheme.GOLD))
		b.pressed.connect(func() -> void:
			setup_mode = i
			mode_text.text = MODE_TEXT[i])
		mode_row.add_child(b)
	mode_text = _label(MODE_TEXT[setup_mode])
	mode_text.add_theme_font_size_override("font_size", 13)
	mode_text.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	mode_text.custom_minimum_size.y = 40
	setup_box.add_child(mode_text)
	setup_box.add_child(GameTheme.heading("Adalides", 14))
	var players_row := HBoxContainer.new()
	players_row.add_theme_constant_override("separation", 6)
	setup_box.add_child(players_row)
	var players_group := ButtonGroup.new()
	for n in [4, 6]: # Con 4 o 6 nadie descansa: la tabla de batallas los empareja a todos.
		var b := Button.new()
		b.text = "%d jugadores" % n
		b.toggle_mode = true
		b.button_group = players_group
		b.button_pressed = n == setup_players
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 38
		b.add_theme_stylebox_override("pressed", GameTheme.button_style(Color(0.32, 0.24, 0.08), GameTheme.GOLD))
		b.pressed.connect(func() -> void: setup_players = n)
		players_row.add_child(b)
	setup_box.add_child(GameTheme.heading("Asaltos por batalla", 14))
	var rounds_row := HBoxContainer.new()
	rounds_row.add_theme_constant_override("separation", 6)
	setup_box.add_child(rounds_row)
	var rounds_group := ButtonGroup.new()
	for r in Rules.ROUND_OPTIONS:
		var rounds: int = r
		var b := Button.new()
		b.text = str(rounds) if rounds > 0 else "Hasta el final"
		b.toggle_mode = true
		b.button_group = rounds_group
		b.button_pressed = rounds == setup_rounds
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size.y = 38
		b.add_theme_stylebox_override("pressed", GameTheme.button_style(Color(0.32, 0.24, 0.08), GameTheme.GOLD))
		b.pressed.connect(func() -> void:
			setup_rounds = rounds
			rounds_text.text = _rounds_description(rounds))
		rounds_row.add_child(b)
	rounds_text = _label(_rounds_description(setup_rounds))
	rounds_text.add_theme_font_size_override("font_size", 13)
	rounds_text.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	rounds_text.custom_minimum_size.y = 40
	setup_box.add_child(rounds_text)
	var start := _menu_button("¡Empezar!", _start_game, true, "Start")
	setup_box.add_child(start)
	var back := _menu_button("Volver", func() -> void: _show_setup(false), false, "Back")
	back.custom_minimum_size.y = 36
	setup_box.add_child(back)
	# Los paneles desplegables van por encima de la mano y del menú (la guía se abre desde la pausa).
	for p in [standings_panel, log_panel, skills_panel, help_panel]:
		root.move_child(p, root.get_child_count() - 1)


func _rounds_description(rounds: int) -> String:
	if rounds == 0:
		return "La batalla sigue hasta que un bando se queda sin campeones (como mucho %d asaltos)." % Rules.SUDDEN_DEATH_CAP
	return "Cada batalla dura %d asaltos; gana quien tenga más campeones en pie." % rounds


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
	_end_tutorial()
	game = null
	table.clear()
	table.visible = false
	hand_panel.visible = false
	detail_panel.visible = false
	tiers_panel.visible = false
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
	board3d.set_enemy_side_visible(true)
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
	menu_box.get_node("Emblem").visible = main
	menu_panel.get_node("Vignette").visible = main
	menu_panel.get_node("Embers").emitting = main
	menu_panel.get_node("Embers").visible = main
	(menu_panel.get_node("Veil") as ColorRect).color = Color(0.02, 0.01, 0.05, 0.75 if main else 0.6)
	menu_box.get_node("Play").visible = main
	menu_box.get_node("Tutorial").visible = main
	menu_box.get_node("Help").visible = true
	menu_box.get_node("Quit").visible = true
	setup_box.visible = false
	menu_box.get_node("Resume").visible = not main
	menu_box.get_node("New").visible = not main
	menu_box.get_node("Main").visible = not main


## Muestra u oculta la configuración de partida dentro del menú principal.
func _show_setup(on: bool) -> void:
	setup_box.visible = on
	for id in ["Play", "Tutorial", "Help", "Quit"]:
		menu_box.get_node(id).visible = not on


func _start_game() -> void:
	in_main_menu = false
	menu_panel.visible = false
	top_bar.visible = true
	side.visible = true
	_end_tutorial()
	_new_game(setup_players, setup_mode, false, setup_rounds)


## Partida corta y guiada: tú contra un rival, vida y Éter reducidos, semilla fija.
func _start_tutorial() -> void:
	in_main_menu = false
	menu_panel.visible = false
	top_bar.visible = true
	side.visible = true
	_end_tutorial()
	_new_game(2, Game.Difficulty.PRINCIPIANTE, true)
	tutorial = Tutorial.new()
	add_child(tutorial)
	tutorial.setup(self)


func _end_tutorial() -> void:
	if tutorial != null:
		tutorial.close()
		tutorial = null


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
	if video_layer != null and video_layer.visible and event.is_action_pressed("ui_cancel"):
		_skip_victory_video()
		get_viewport().set_input_as_handled()
		return
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
	timer_row.visible = game != null and tutorial == null and game.state in [Game.State.MARKET, Game.State.LINEUP]
	if not timer_row.visible:
		return
	phase_bar.value = clampf(phase_left / phase_total, 0.0, 1.0)
	var fill: StyleBoxFlat = phase_bar.get_theme_stylebox("fill")
	fill.bg_color = Color(1, 0.4, 0.3) if phase_left <= 10 else GameTheme.GOLD
	phase_time.text = "%d s" % ceili(phase_left)


func _process(delta: float) -> void:
	if game == null or tutorial != null or phase_left <= 0.0 or game.state not in [Game.State.MARKET, Game.State.LINEUP]:
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
	drop_zone = PanelContainer.new()
	drop_zone.custom_minimum_size = Vector2(0, 150)
	_style_drop_zone(false)
	bv.add_child(drop_zone)
	var dz := VBoxContainer.new()
	dz.alignment = BoxContainer.ALIGNMENT_CENTER
	drop_zone.add_child(dz)
	var icon := Label.new()
	icon.text = "⤓"
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon.add_theme_font_size_override("font_size", 40)
	icon.add_theme_color_override("font_color", GameTheme.GOLD)
	dz.add_child(icon)
	drop_label = _label("Arrastra aquí la carta que quieras")
	drop_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	drop_label.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	dz.add_child(drop_label)
	card_detail = VBoxContainer.new()
	bv.add_child(card_detail)
	skip_button = Button.new()
	skip_button.text = "Ninguna cabe: pasar"
	skip_button.visible = false
	skip_button.pressed.connect(_on_skip_draft)
	bv.add_child(skip_button)
	return box


func _style_drop_zone(active: bool) -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.25, 0.45, 0.3, 0.5) if active else Color(0.1, 0.09, 0.15, 0.6)
	st.border_color = Color(0.45, 1.0, 0.55) if active else GameTheme.GOLD_DIM
	st.set_border_width_all(2)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(10)
	drop_zone.add_theme_stylebox_override("panel", st)


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
	var eter_row := HBoxContainer.new()
	eter_row.add_theme_constant_override("separation", 6)
	eter_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hrow.add_child(eter_row)
	eter_row.add_child(_eter_icon(30))
	shop_eter = GameTheme.title("0", 30)
	shop_eter.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
	eter_row.add_child(shop_eter)
	# Mejoras del tablero personal: una fila por pista.
	var ub := _block()
	box.add_child(ub)
	var uv := VBoxContainer.new()
	uv.add_theme_constant_override("separation", 4)
	ub.add_child(uv)
	uv.add_child(GameTheme.heading("Mejoras", 14))
	uv.add_theme_constant_override("separation", 8)
	var icons := { Adalid.Track.CUARTEL: "⌂", Adalid.Track.BATTLE: "⚔", Adalid.Track.DICE: "⚅" }
	var names := { Adalid.Track.CUARTEL: "Cuartel", Adalid.Track.BATTLE: "En batalla", Adalid.Track.DICE: "Dados" }
	for track in [Adalid.Track.CUARTEL, Adalid.Track.BATTLE, Adalid.Track.DICE]:
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 3)
		uv.add_child(tv)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		tv.add_child(row)
		var head_label := GameTheme.heading("%s %s" % [icons[track], names[track]], 13)
		head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(head_label)
		var b := Button.new()
		b.custom_minimum_size = Vector2(126, 34)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.expand_icon = true
		b.pressed.connect(func() -> void:
			if not _tut_can("upgrade_battle" if track == Adalid.Track.BATTLE else "upgrade_other"):
				return
			game.human_upgrade(track)
			_refresh_market())
		row.add_child(b)
		upgrade_buttons[track] = b
		# Pasos de la pista: lo conseguido, lo actual (dorado) y el siguiente (marcado).
		var chips := HBoxContainer.new()
		chips.add_theme_constant_override("separation", 4)
		tv.add_child(chips)
		upgrade_chips[track] = chips
		var desc := _label("")
		desc.add_theme_font_size_override("font_size", 12)
		desc.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
		tv.add_child(desc)
		upgrade_desc[track] = desc
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
	buy_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	buy_button.expand_icon = true
	buy_button.pressed.connect(_on_buy_card)
	GameTheme.primary_button(buy_button)
	arow.add_child(buy_button)
	refresh_button = Button.new()
	refresh_button.text = "⟳ %d" % Rules.MARKET_REFRESH_COST
	refresh_button.icon = Icons.eter()
	refresh_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	refresh_button.expand_icon = true
	refresh_button.tooltip_text = "Refrescar el mercado (cuesta %d de Éter)" % Rules.MARKET_REFRESH_COST
	refresh_button.custom_minimum_size = Vector2(0, 44)
	refresh_button.add_theme_font_size_override("font_size", 15)
	refresh_button.pressed.connect(_on_refresh_market)
	arow.add_child(refresh_button)
	market_reason = _label("")
	market_reason.add_theme_font_size_override("font_size", 12)
	market_reason.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))
	market_reason.visible = false
	cv.add_child(market_reason)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	cv.add_child(brow)
	sell_button = Button.new()
	sell_button.text = "Vender"
	sell_button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sell_button.expand_icon = true
	sell_button.pressed.connect(_on_sell)
	brow.add_child(sell_button)
	var done := Button.new()
	market_done_button = done
	done.text = "Listo, a alinear →"
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	GameTheme.primary_button(done)
	done.pressed.connect(_finish_market)
	brow.add_child(done)
	return box


## Icono del cristal de Éter para filas de la interfaz.
func _eter_icon(size: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = Icons.eter()
	tr.custom_minimum_size = Vector2(size, size)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return tr


## Qué da un paso de una pista, en palabras.
func _track_step_text(track: int, value: Variant) -> String:
	if value is String:
		return "un hueco de héroe"
	var n := int(value)
	match track:
		Adalid.Track.CUARTEL:
			return "%d cartas en el cuartel" % n
		Adalid.Track.BATTLE:
			return "%d campeones en batalla" % n
	return ("%d dado por asalto" if n == 1 else "%d dados por asalto") % n


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
	lineup_auto_button = auto
	auto.text = "Auto"
	auto.pressed.connect(func() -> void:
		if not _tut_can("lineup_auto"):
			return
		lineup = Game.auto_lineup(game.human)
		_refresh_lineup())
	buttons.add_child(auto)
	var clear := Button.new()
	lineup_clear_button = clear
	clear.text = "Vaciar"
	clear.pressed.connect(func() -> void:
		if not _tut_can("lineup_clear"):
			return
		lineup.clear()
		_refresh_lineup())
	buttons.add_child(clear)
	var go := Button.new()
	lineup_go_button = go
	go.text = "¡A la batalla! →"
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	go.custom_minimum_size = Vector2(0, 44)
	GameTheme.primary_button(go)
	go.pressed.connect(func() -> void:
		if _tut_can("lineup_go"):
			_on_lineup_done(false))
	buttons.add_child(go)
	return block


func _build_battle_panel() -> Control:
	var block := _block()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	block.add_child(box)
	battle_title = GameTheme.heading("")
	box.add_child(battle_title)
	# Asaltos: una gema por asalto, la actual encendida.
	var rounds_row := HBoxContainer.new()
	rounds_row.add_theme_constant_override("separation", 8)
	box.add_child(rounds_row)
	battle_pips = HBoxContainer.new()
	battle_pips.add_theme_constant_override("separation", 5)
	battle_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rounds_row.add_child(battle_pips)
	battle_round_label = _label("")
	battle_round_label.add_theme_font_size_override("font_size", 13)
	battle_round_label.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	battle_round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rounds_row.add_child(battle_round_label)
	# Los dos adalides frente a frente: nombre, vida con barra y campeones en pie.
	var versus := VBoxContainer.new()
	versus.add_theme_constant_override("separation", 6)
	box.add_child(versus)
	for side in 2:
		if side == 1:
			var vs := _label("contra")
			vs.add_theme_font_override("font", GameTheme.title_font)
			vs.add_theme_font_size_override("font_size", 12)
			vs.add_theme_color_override("font_color", GameTheme.GOLD_DIM)
			vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			versus.add_child(vs)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 3)
		versus.add_child(col)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		col.add_child(head)
		var name_label := Label.new()
		name_label.add_theme_font_override("font", GameTheme.bold_font)
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0) if side == 0 else Color(1.0, 0.6, 0.55))
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		head.add_child(name_label)
		battle_names.append(name_label)
		var life := Label.new()
		life.add_theme_font_override("font", GameTheme.bold_font)
		life.add_theme_font_size_override("font_size", 17)
		life.add_theme_color_override("font_color", Color(0.5, 0.88, 0.5))
		life.tooltip_text = "Vida del adalid"
		head.add_child(life)
		battle_lives.append(life)
		# Vida total de los campeones que están peleando.
		var hp_row := HBoxContainer.new()
		hp_row.add_theme_constant_override("separation", 8)
		col.add_child(hp_row)
		var alive := Label.new()
		alive.add_theme_font_size_override("font_size", 13)
		alive.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
		alive.custom_minimum_size.x = 48
		hp_row.add_child(alive)
		battle_alive.append(alive)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size.y = 12
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.min_value = 0
		bar.tooltip_text = "Vida que les queda entre todos los campeones en batalla"
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.03, 0.02, 0.06, 0.9)
		bg.border_color = GameTheme.GOLD_DIM
		bg.set_border_width_all(1)
		bg.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("background", bg)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.35, 0.6, 0.95) if side == 0 else Color(0.9, 0.35, 0.32)
		fill.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("fill", fill)
		hp_row.add_child(bar)
		battle_bars.append(bar)
		var hp := Label.new()
		hp.add_theme_font_override("font", GameTheme.bold_font)
		hp.add_theme_font_size_override("font_size", 13)
		hp.add_theme_color_override("font_color", GameTheme.TEXT)
		hp.custom_minimum_size.x = 54
		hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hp_row.add_child(hp)
		battle_hp.append(hp)
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
	p.custom_minimum_size.x = 700
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
	var headline := _label("")
	headline.name = "Headline"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_override("font", GameTheme.bold_font)
	headline.add_theme_font_size_override("font_size", 16)
	box.add_child(headline)
	box.add_child(_standings_box())
	var next := Button.new()
	next_cycle_button = next
	next.text = "Siguiente ciclo →"
	next.custom_minimum_size = Vector2(0, 46)
	GameTheme.primary_button(next)
	next.pressed.connect(func() -> void:
		if _tut_can("next_cycle"):
			_next_cycle())
	box.add_child(next)
	return p


## Contenedor de la clasificación (se rellena con `_fill_standings`).
func _standings_box() -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 4)
	return rows


## Clasificación del ciclo: puesto, nombre, barra de vida con lo perdido o ganado este ciclo,
## Éter, racha y resultado de su batalla. Tu fila va resaltada.
func _fill_standings(rows: VBoxContainer) -> void:
	for c in rows.get_children():
		c.queue_free()
	var order: Array[Adalid] = []
	order.assign(game.adalids)
	order.sort_custom(func(a: Adalid, b: Adalid) -> bool:
		if a.eliminated != b.eliminated:
			return not a.eliminated
		return a.life > b.life or (a.life == b.life and a.eter > b.eter))
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	rows.add_child(header)
	for col in [["", 26], ["Adalid", 0], ["Vida", 150], ["", 58], ["Éter", 50], ["Racha", 50], ["Ciclo", 40]]:
		var l := Label.new()
		l.text = col[0]
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", GameTheme.GOLD_DIM)
		if col[1] == 0:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			l.custom_minimum_size.x = col[1]
		header.add_child(l)
	var rank := 0
	for a in order:
		rank += 1
		var row := PanelContainer.new()
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.2, 0.16, 0.07, 0.9) if a == game.human else Color(0.1, 0.08, 0.15, 0.6)
		s.border_color = GameTheme.GOLD if a == game.human else Color(0, 0, 0, 0)
		s.set_border_width_all(1)
		s.set_corner_radius_all(6)
		s.content_margin_left = 8
		s.content_margin_right = 8
		s.content_margin_top = 5
		s.content_margin_bottom = 5
		row.add_theme_stylebox_override("panel", s)
		rows.add_child(row)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var dim := a.eliminated
		var rank_label := Label.new()
		rank_label.text = "%d." % rank
		rank_label.custom_minimum_size.x = 26
		rank_label.add_theme_font_override("font", GameTheme.bold_font)
		rank_label.add_theme_color_override("font_color", GameTheme.GOLD if rank == 1 and not dim else GameTheme.TEXT_DIM)
		h.add_child(rank_label)
		var name_label := Label.new()
		name_label.text = ("Tú" if a == game.human else a.display_name) + (" ✝" if dim else "")
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.custom_minimum_size.x = 190
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.add_theme_font_override("font", GameTheme.bold_font)
		name_label.add_theme_font_size_override("font_size", 15)
		name_label.add_theme_color_override("font_color", Color(0.45, 0.42, 0.4) if dim else (GameTheme.GOLD if a == game.human else GameTheme.TEXT))
		h.add_child(name_label)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(150, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.min_value = 0
		bar.max_value = maxi(game.start_life, a.life)
		bar.value = a.life
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.03, 0.02, 0.06, 0.9)
		bg.border_color = GameTheme.GOLD_DIM
		bg.set_border_width_all(1)
		bg.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("background", bg)
		var fill := StyleBoxFlat.new()
		var ratio := float(a.life) / float(bar.max_value)
		fill.bg_color = Color(0.4, 0.78, 0.42) if ratio > 0.5 else (Color(0.9, 0.65, 0.3) if ratio > 0.25 else Color(0.9, 0.35, 0.3))
		fill.set_corner_radius_all(5)
		bar.add_theme_stylebox_override("fill", fill)
		h.add_child(bar)
		var life_label := Label.new()
		var delta: int = a.life - int(game.life_before.get(a, a.life))
		life_label.text = "♥ %d" % a.life + ((" −%d" % -delta) if delta < 0 else (" +%d" % delta if delta > 0 else ""))
		life_label.custom_minimum_size.x = 58
		life_label.add_theme_font_override("font", GameTheme.bold_font)
		life_label.add_theme_font_size_override("font_size", 13)
		life_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4) if delta < 0 else (Color(0.5, 0.88, 0.5) if delta > 0 else GameTheme.TEXT))
		h.add_child(life_label)
		var eter_row := HBoxContainer.new()
		eter_row.add_theme_constant_override("separation", 3)
		eter_row.custom_minimum_size.x = 56
		eter_row.add_child(_eter_icon(16))
		var eter_label := Label.new()
		eter_label.text = "%d" % a.eter
		eter_label.add_theme_color_override("font_color", Color(0.75, 0.88, 1.0))
		eter_row.add_child(eter_label)
		h.add_child(eter_row)
		var streak_label := Label.new()
		streak_label.text = ("%s %d" % ["▲" if a.streak_is_win else "▼", a.streak]) if a.streak > 0 else "—"
		streak_label.custom_minimum_size.x = 50
		streak_label.add_theme_color_override("font_color", GameTheme.GOLD if a.streak_is_win and a.streak > 0 else (Color(0.95, 0.5, 0.45) if a.streak > 0 else GameTheme.TEXT_DIM))
		h.add_child(streak_label)
		var chip := Label.new()
		var res := _cycle_result(a)
		chip.text = res
		chip.custom_minimum_size.x = 40
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.add_theme_font_override("font", GameTheme.bold_font)
		chip.add_theme_color_override("font_color", Color(0.5, 0.88, 0.5) if res == "V" else (Color(0.95, 0.45, 0.4) if res == "D" else GameTheme.TEXT_DIM))
		h.add_child(chip)


## «V», «D», «=» o «—» según la batalla de este ciclo de un adalid.
func _cycle_result(a: Adalid) -> String:
	for b in game.last_battles:
		if not b.adalids.has(a):
			continue
		if b.result.get("tie", false):
			return "="
		return "V" if b.result.get("winner") == a else "D"
	return "—"


## Frase sobre tu batalla de este ciclo.
func _cycle_headline() -> String:
	for b in game.last_battles:
		if not b.adalids.has(game.human):
			continue
		var opp: Adalid = b.adalids[1] if b.adalids[0] == game.human else b.adalids[0]
		var side := b.adalids.find(game.human)
		var lost: int = b.result.get("damage", [0, 0])[side]
		if b.result.get("tie", false):
			return "Empate con %s: ambos perdéis vida (−%d)." % [opp.display_name, lost]
		if b.result.get("winner") == game.human:
			return "Venciste a %s y no pierdes vida." % opp.display_name
		return "%s te venció: pierdes %d de vida." % [opp.display_name, lost]
	return "Este ciclo descansaste."


## Acción no permitida: aviso rojo que tiembla, destello y la razón en la pista.
func _deny(reason: String) -> void:
	hint.text = reason
	if _deny_tween != null and _deny_tween.is_valid():
		_deny_tween.kill()
	deny_label.text = "✖ " + reason
	deny_label.visible = true
	deny_label.modulate = Color(1, 1, 1, 1)
	deny_label.scale = Vector2.ONE
	deny_label.pivot_offset = deny_label.size / 2.0
	var base := deny_label.position
	var tw := create_tween()
	_deny_tween = tw
	tw.tween_property(deny_label, "scale", Vector2.ONE * 1.12, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(deny_label, "scale", Vector2.ONE, 0.12)
	for i in 4:
		tw.tween_property(deny_label, "position:x", base.x + (8.0 if i % 2 == 0 else -8.0), 0.04)
	tw.tween_property(deny_label, "position:x", base.x, 0.04)
	tw.tween_interval(1.6)
	tw.tween_property(deny_label, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: deny_label.visible = false)
	_screen_flash(Color(0.45, 0.05, 0.05, 0.35))


## Razón por la que una carta no se puede comprar ahora ("" si se puede).
func _buy_block_reason(card: ChampionData) -> String:
	var h := game.human
	if card == null:
		return ""
	if not h.can_add(card):
		var owned := h.find_card(card.id)
		if owned != null and owned.copies >= Rules.MAX_COPIES:
			return "Ya tienes las %d copias de %s." % [Rules.MAX_COPIES, card.display_name]
		if card.hero:
			return "Sin hueco de héroe: sube la pista Cuartel hasta una «H»."
		return "Cuartel lleno (%d/%d): vende una carta o mejora el cuartel." % [h.base_count(), h.cuartel_capacity()]
	if not h.can_pay(card.cost):
		return "Te faltan %d de Éter para %s." % [card.cost - h.eter, card.display_name]
	return ""


## Reproduce el vídeo de victoria a pantalla completa; al acabar (o al saltarlo) celebra y muestra el panel.
func _play_victory_video() -> void:
	if not ResourceLoader.exists("res://assets/video/victoria.ogv"):
		_celebrate("¡ERES EL NUEVO DEMIURGO!", GameTheme.GOLD, true)
		return
	var panel: Control = panels[Game.State.OVER]
	await get_tree().process_frame
	panel.visible = false
	_play_fullscreen_video(load("res://assets/video/victoria.ogv"), "¡ERES EL NUEVO DEMIURGO!", 7.6, func() -> void:
		if game != null and game.state == Game.State.OVER:
			panel.visible = true
			_pop_in(panel)
			_celebrate("¡ERES EL NUEVO DEMIURGO!", GameTheme.GOLD, true))


## Intro al arrancar: el vídeo de presentación y luego el menú. Solo una vez por ejecución.
func _play_intro_video() -> void:
	if not ResourceLoader.exists("res://assets/video/intro.ogv"):
		_show_main_menu()
		return
	var stream: VideoStream = load("res://assets/video/intro.ogv")
	_play_fullscreen_video(stream, "Adalides del demiurgo", -1.2, _show_main_menu)


## Vídeo a pantalla completa con fundidos. `title_at` es el segundo en que entra el título
## (negativo: segundos antes del final). Clic o Esc lo saltan; `on_done` se llama al terminar.
func _play_fullscreen_video(stream: VideoStream, title_text: String, title_at: float, on_done: Callable) -> void:
	_video_token += 1
	var token := _video_token
	_video_on_done = on_done
	video_player.stream = stream
	video_title.text = title_text
	video_title.visible = false
	video_layer.visible = true
	video_layer.modulate = Color(1, 1, 1, 0)
	video_player.play()
	create_tween().tween_property(video_layer, "modulate:a", 1.0, 0.6)
	var length: float = video_player.get_stream_length()
	var at: float = title_at if title_at >= 0.0 else maxf(length + title_at, 0.5)
	if length <= 0.0 and title_at < 0.0:
		at = 8.0
	await get_tree().create_timer(at, false).timeout
	if token != _video_token:
		return
	video_title.visible = true
	video_title.modulate = Color(1, 1, 1, 0)
	video_title.pivot_offset = video_title.size / 2.0
	video_title.scale = Vector2(0.6, 0.6)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(video_title, "modulate:a", 1.0, 0.4)
	tw.tween_property(video_title, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	while video_player.is_playing() and token == _video_token:
		await get_tree().process_frame
	if token != _video_token:
		return
	await get_tree().create_timer(1.0, false).timeout
	if token != _video_token:
		return
	_finish_video()


func _skip_victory_video() -> void:
	if not video_layer.visible:
		return
	_video_token += 1
	_finish_video()


func _finish_video() -> void:
	var done := _video_on_done
	_video_on_done = Callable()
	var tw := create_tween()
	tw.tween_property(video_layer, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func() -> void:
		video_player.stop()
		video_layer.visible = false
		if done.is_valid():
			done.call())


## Entrada animada de un panel centrado.
func _pop_in(panel: Control) -> void:
	panel.pivot_offset = panel.size / 2.0
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale = Vector2(0.88, 0.88)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(panel, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build_over_panel() -> Control:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size.x = 700
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
	box.add_child(_standings_box())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var again := Button.new()
	again.text = "Otra partida"
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	again.custom_minimum_size = Vector2(0, 46)
	GameTheme.primary_button(again)
	again.pressed.connect(func() -> void:
		if tutorial != null:
			_show_main_menu()
		else:
			_start_game())
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

func _new_game(players: int = 6, difficulty: int = Game.Difficulty.AMATEUR, is_tutorial: bool = false, rounds: int = Rules.ROUNDS_PER_BATTLE) -> void:
	_auto_token += 1
	battle_playing = false
	var names: PackedStringArray = ["Tú"]
	for i in players - 1:
		names.append(AI_NAMES[i % AI_NAMES.size()])
	# Las partidas normales usan una semilla aleatoria; solo el tutorial es fijo.
	game = Game.new(names, Tutorial.SEED if is_tutorial else 0)
	game.difficulty = difficulty as Game.Difficulty
	game.rounds_per_battle = rounds
	if is_tutorial:
		game.set_start(Tutorial.LIFE, Tutorial.ETER)
		game.ai_handicap = true
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
	hand_panel.visible = game.state in [Game.State.DRAFT, Game.State.MARKET, Game.State.LINEUP]
	detail_panel.visible = false
	tiers_panel.visible = game.state in [Game.State.LINEUP, Game.State.BATTLE]
	if game.state != Game.State.DRAFT and game.state != Game.State.MARKET:
		table.clear()
		table.visible = false
	var at_table := game.state in [Game.State.DRAFT, Game.State.MARKET]
	board3d.set_mat_visible(not at_table)
	board3d.set_enemy_side_visible(game.state != Game.State.LINEUP)
	if game.state == Game.State.DRAFT:
		_camera_view(View.DRAFT, true)
	elif game.state == Game.State.MARKET:
		_camera_view(View.MARKET, true)
	elif game.state == Game.State.LINEUP:
		_camera_view(View.LINEUP, true)
	else:
		_camera_view(View.BOARD, true)
	match game.state:
		Game.State.DRAFT:
			board3d.clear_pieces()
			_update_deck_label("Pulsa el mazo para repartir")
			_refresh_draft()
		Game.State.MARKET:
			if tutorial != null and game.cycle == 1:
				# El tutorial pelea antes de comprar: el primer mercado se salta sin mostrarlo.
				game.finish_market()
				_enter_state()
				return
			board3d.clear_pieces()
			_start_phase_timer(MARKET_SECONDS)
			_refresh_market()
			_deal_market()
		Game.State.LINEUP:
			# En el primer ciclo del tutorial se coloca a mano, para aprender.
			lineup = {} if tutorial != null and game.cycle == 1 else Game.auto_lineup(game.human)
			pending_card = null
			_start_phase_timer(LINEUP_SECONDS)
			_refresh_hand()
			_refresh_lineup()
		Game.State.BATTLE:
			battle_paused = false
			board3d.drop_hidden()
			_battle_intro()
		Game.State.CYCLE_END:
			if not game.last_battles.is_empty():
				board3d.sync(game.last_battles[-1].board.cells, false)
			(panels[Game.State.CYCLE_END].find_child("Title", true, false) as Label).text = "Fin del ciclo %d" % game.cycle
			var headline: Label = panels[Game.State.CYCLE_END].find_child("Headline", true, false)
			headline.text = _cycle_headline()
			var mine := _cycle_result(game.human)
			headline.add_theme_color_override("font_color", Color(0.5, 0.88, 0.5) if mine == "V" else (Color(0.95, 0.45, 0.4) if mine == "D" else GameTheme.TEXT_DIM))
			_fill_standings(panels[Game.State.CYCLE_END].find_child("Rows", true, false))
		Game.State.OVER:
			var res: Label = panels[Game.State.OVER].find_child("Result", true, false)
			_fill_standings(panels[Game.State.OVER].find_child("Rows", true, false))
			var w := game.winner()
			if game.demiurge_wins:
				res.text = "Los últimos adalides cayeron a la vez: gana el Demiurgo."
				_celebrate("El Demiurgo se queda con todo", GameTheme.TEXT_DIM, false)
			elif w == game.human:
				res.text = "¡Eres el nuevo demiurgo!"
				_play_victory_video()
			else:
				res.text = "Has sido eliminado. Gana %s." % (w.display_name if w != null else "nadie")
				_celebrate("Gana %s" % (w.display_name if w != null else "nadie"), Color(0.9, 0.5, 0.5), false)
	_refresh()
	if game.state in [Game.State.CYCLE_END, Game.State.OVER]:
		_pop_in(panels[game.state])


func _update_deck_label(hint := "") -> void:
	table.set_deck_count(game.deck.size(), hint)


# ---------------------------------------------------------------- mesa: draft

func _refresh_draft() -> void:
	table.visible = true
	var my_turn := game.draft_current() == game.human
	if not table.dealt:
		hint.text = "Pulsa el mazo para repartir %d cartas." % game.draft_pool.size()
	elif table_busy:
		hint.text = "Repartiendo..."
	elif my_turn:
		hint.text = "Te toca: arrastra una carta de la mesa a tu lado."
	else:
		hint.text = "Eligen los demás adalides..."
	_show_detail(card_detail, selected_card)
	var fits := false
	for card in game.draft_pool:
		if game.human.can_add(card):
			fits = true
			break
	drop_label.text = "Arrastra aquí la carta que quieras" if my_turn else "Esperando a los demás adalides…"
	drop_zone.modulate = Color.WHITE if my_turn and table.dealt else Color(0.7, 0.7, 0.7)
	skip_button.visible = my_turn and table.dealt and not table_busy and not fits
	_refresh_hand()
	if table.dealt:
		table.dim_unavailable(func(card: ChampionData) -> bool: return game.human.can_add(card) and _tutorial_allows(card))
	_refresh()


func _show_detail(_box: VBoxContainer, card: ChampionData) -> void:
	_show_card_detail(card)


## Detalle de la carta seleccionada abajo a la izquierda: carta, poder y con qué combina.
func _show_card_detail(card: ChampionData) -> void:
	for c in detail_box.get_children():
		c.queue_free()
	var was_visible := detail_panel.visible
	detail_panel.visible = card != null and game != null and game.state in [Game.State.DRAFT, Game.State.MARKET]
	if detail_panel.visible != was_visible:
		_layout_hand()
	if not detail_panel.visible:
		return
	var head := HBoxContainer.new()
	detail_box.add_child(head)
	var title := GameTheme.heading(card.display_name, 15)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.tooltip_text = "Quitar la selección"
	close.custom_minimum_size = Vector2(30, 28)
	close.pressed.connect(_deselect_card)
	head.add_child(close)
	var cv := CardView.new()
	var note := ""
	if not game.human.can_add(card):
		note = "no cabe en tu cuartel" if not card.hero else "necesitas un hueco de héroe (H)"
	elif game.state == Game.State.MARKET and not game.human.can_pay(card.cost):
		note = "no tienes Éter suficiente"
	cv.setup(card, null, note)
	cv.custom_minimum_size.x = 270
	detail_box.add_child(cv)
	var power := _label("%s: %s" % [card.power.get("name", ""), card.power.get("text", "")])
	power.add_theme_font_size_override("font_size", 12)
	detail_box.add_child(power)
	# Combos: qué tiers acerca o activa y con qué cartas tuyas combina.
	var combos := _combo_lines(card)
	if not combos.is_empty():
		var ch := GameTheme.heading("Combos", 13)
		detail_box.add_child(ch)
		for line in combos:
			var l := RichTextLabel.new()
			l.bbcode_enabled = true
			l.fit_content = true
			l.scroll_active = false
			l.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
			l.add_theme_font_size_override("normal_font_size", 12)
			l.text = line
			detail_box.add_child(l)


func _deselect_card() -> void:
	selected_card = null
	selected_card3d = null
	table.select(null)
	if game.state == Game.State.MARKET:
		_refresh_market()
	elif game.state == Game.State.DRAFT:
		_refresh_draft()


## Líneas BBCode con los combos de una carta respecto a tu cuartel.
func _combo_lines(card: ChampionData) -> PackedStringArray:
	var out: PackedStringArray = []
	var h := game.human
	var elems := Tiers.count_elements(h.cuartel)
	var archs := Tiers.count_archetypes(h.cuartel)
	var owned := h.find_card(card.id)
	if owned != null:
		out.append("[color=#f0d080]Copia %d de %s[/color]: +1/+1 y poder mejorado%s." % [owned.copies + 1, card.display_name, " (AFI %d)" % Rules.AFI_BY_COPIES.get(owned.copies + 1, 0) if Rules.AFI_BY_COPIES.get(owned.copies + 1, 0) > 0 else ""])
	if card.element >= 0:
		var n: int = elems.get(card.element, 0)
		out.append(_combo_line(Rules.element_label(card.element), Icons.ELEMENT_COLORS[card.element].to_html(false), n, Rules.ELEMENT_TIERS, TierTexts.ELEMENTS[card.element]))
	for arch in card.archetypes():
		var n: int = archs.get(arch, 0)
		out.append(_combo_line(Rules.archetype_label(arch), "e8e4dc", n, Rules.ARCHETYPE_TIERS, TierTexts.ARCHETYPES[arch]))
	var mates: PackedStringArray = []
	for ch in h.cuartel:
		if ch.data.id == card.id:
			continue
		var same_e := card.element >= 0 and ch.data.element == card.element
		var same_a := false
		for a in card.archetypes():
			if ch.data.archetypes().has(a):
				same_a = true
		if same_e or same_a:
			mates.append("%s (%s)" % [ch.data.display_name, ch.data.power.get("name", "")])
	if not mates.is_empty():
		out.append("[color=#aaa]Combina con:[/color] " + ", ".join(mates))
	return out


func _combo_line(name: String, color: String, n: int, thresholds: Array[int], text: String) -> String:
	var after := n + 1
	var tier_now := Rules.tier_index(n, thresholds)
	var tier_after := Rules.tier_index(after, thresholds)
	var head := "[color=#%s]%s[/color] %d → %d" % [color, name, n, after]
	if tier_after > tier_now:
		return "%s  [color=#7ee07e]✔ activa el tier %d[/color]: %s" % [head, tier_after, _first_sentence(text)]
	var next_th := -1
	for t in thresholds:
		if after < t:
			next_th = t
			break
	if next_th > 0:
		return "%s  (tier con %d; faltan %d)" % [head, next_th, next_th - after]
	return "%s  (tier máximo)" % head


func _first_sentence(text: String) -> String:
	var i := text.find(". ")
	return text if i < 0 else text.substr(0, i + 1)


## Panel de tiers activos (izquierda): los tuyos y, en batalla, los del rival.
func _refresh_tiers_panel(mine: Array[Champion], theirs: Array[Champion] = [], rival_name := "") -> void:
	for c in tiers_box.get_children():
		c.queue_free()
	tiers_panel.visible = game != null and game.state in [Game.State.LINEUP, Game.State.BATTLE]
	if not tiers_panel.visible:
		return
	tiers_box.add_child(GameTheme.heading("Tus tiers en batalla", 14))
	_tier_rows(mine, true)
	if not theirs.is_empty():
		var sep := HSeparator.new()
		tiers_box.add_child(sep)
		tiers_box.add_child(GameTheme.heading("Tiers de %s" % rival_name, 13))
		_tier_rows(theirs, false)


func _tier_rows(group: Array[Champion], verbose: bool) -> void:
	var el := Tiers.count_elements(group)
	var ar := Tiers.count_archetypes(group)
	var any := false
	for e in Catalog.ELEM_ORDER:
		if el.get(e, 0) > 0:
			any = true
			_tier_row(Icons.element(e), Icons.ELEMENT_COLORS[e], Rules.element_label(e), el[e], Rules.ELEMENT_TIERS, TierTexts.ELEMENTS[e], verbose)
	for a in Catalog.ARCH_ORDER:
		if ar.get(a, 0) > 0:
			any = true
			_tier_row(Icons.archetype(a), Color.WHITE, Rules.archetype_label(a), ar[a], Rules.ARCHETYPE_TIERS, TierTexts.ARCHETYPES[a], verbose)
	if not any:
		var l := _label("Sin campeones colocados.")
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
		tiers_box.add_child(l)


func _tier_row(icon: Texture2D, color: Color, name: String, n: int, thresholds: Array[int], text: String, verbose: bool) -> void:
	var tier := Rules.tier_index(n, thresholds)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	tiers_box.add_child(row)
	var tr := TextureRect.new()
	tr.texture = icon
	tr.modulate = color if tier > 0 else color.darkened(0.45)
	tr.custom_minimum_size = Vector2(22, 22)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tr)
	var l := Label.new()
	l.text = "%s ×%d" % [name, n]
	l.add_theme_font_override("font", GameTheme.bold_font)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", GameTheme.GOLD if tier > 0 else GameTheme.TEXT_DIM)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var chip := Label.new()
	var next_th := -1
	for t in thresholds:
		if n < t:
			next_th = t
			break
	chip.text = ("Tier %d ✔" % tier) if tier > 0 else ("faltan %d" % (next_th - n) if next_th > 0 else "")
	chip.add_theme_font_size_override("font_size", 12)
	chip.add_theme_color_override("font_color", Color(0.5, 0.88, 0.5) if tier > 0 else GameTheme.TEXT_DIM)
	row.add_child(chip)
	if verbose and tier > 0:
		var d := _label(_first_sentence(text))
		d.add_theme_font_size_override("font_size", 11)
		d.add_theme_color_override("font_color", GameTheme.TEXT)
		tiers_box.add_child(d)


func _tutorial_allows(card: ChampionData) -> bool:
	return tutorial == null or tutorial.allows(card)


## En el tutorial solo se permiten las acciones del paso actual.
func _tut_can(action: String) -> bool:
	return tutorial == null or tutorial.can(action)


## Deshabilita los botones de las acciones que el paso del tutorial no permite.
func _tut_apply_locks() -> void:
	if tutorial == null:
		return
	# Botones cuyo estado natural ya calculó _refresh_market: solo se añaden bloqueos.
	buy_button.disabled = buy_button.disabled or not _tut_can("buy")
	refresh_button.disabled = refresh_button.disabled or not _tut_can("refresh")
	sell_button.disabled = sell_button.disabled or not _tut_can("sell")
	for track in upgrade_buttons:
		var b: Button = upgrade_buttons[track]
		b.disabled = b.disabled or not _tut_can("upgrade_battle" if track == Adalid.Track.BATTLE else "upgrade_other")
	market_done_button.disabled = not _tut_can("market_done")
	lineup_auto_button.disabled = not _tut_can("lineup_auto")
	lineup_clear_button.disabled = not _tut_can("lineup_clear")
	lineup_go_button.disabled = not _tut_can("lineup_go")
	pause_button.disabled = not _tut_can("battle_pause")
	step_button.disabled = not _tut_can("battle_step")
	next_cycle_button.disabled = not _tut_can("next_cycle")
	for tb in tool_buttons:
		tb.disabled = not _tut_can("panels")
		tb.tooltip_text = "" if not tb.disabled else "En el tutorial estos paneles se abren al final."


func _on_deck_clicked() -> void:
	if game.state != Game.State.DRAFT or table.dealt or table_busy:
		return
	if not _tut_can("deal"):
		_deny("Ahora no toca repartir: sigue el paso del tutorial.")
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


func _on_table_card_pressed(c3d: Card3D) -> void:
	if table_busy:
		return
	var card := c3d.card
	if selected_card == card and selected_card3d == c3d and game.state == Game.State.MARKET and _buy_block_reason(card) != "":
		_deselect_card() # Segundo clic en una carta que no se puede comprar: se quita la selección.
		return
	selected_card = card
	selected_card3d = c3d
	table.select(c3d)
	if game.state == Game.State.DRAFT:
		_refresh_draft()
		if game.draft_current() != game.human:
			_deny("Espera tu turno: ahora elige %s." % game.draft_current().display_name)
		elif not game.human.can_add(card):
			_deny("No cabe en tu cuartel.")
		elif not _tutorial_allows(card):
			_deny("En el tutorial toma la carta que se indica.")
		elif not _tut_can("take"):
			_deny("Ahora no toca tomar cartas.")
		else:
			_begin_drag({ "kind": "table_card", "card": card, "card3d": c3d }, Icons.archetype(card.archetype), card.display_name)
	elif game.state == Game.State.MARKET:
		_refresh_market()
		var block := _buy_block_reason(card)
		if block != "":
			_deny(block)
		elif not _tut_can("buy"):
			_deny("Ahora no toca comprar: sigue el paso del tutorial.")
		else:
			_begin_drag({ "kind": "table_card", "card": card, "card3d": c3d }, Icons.archetype(card.archetype), card.display_name)


func _on_take_card() -> void:
	if selected_card == null or not _tutorial_allows(selected_card) or not _tut_can("take") or not game.human_draft_pick(selected_card):
		return
	var card := selected_card
	var c3d := selected_card3d
	selected_card = null
	selected_card3d = null
	table_busy = true
	_refresh_draft()
	await table.take(card, true, c3d)
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
	if game.state == Game.State.MARKET:
		_refresh_market()


func _refresh_market() -> void:
	var h := game.human
	hint.text = "Elige una carta de la mesa o de tu mano."
	shop_eter.text = "%d" % h.eter
	for track in upgrade_buttons:
		var b: Button = upgrade_buttons[track]
		var track_values: Array = [Rules.CUARTEL_TRACK, Rules.BATTLE_TRACK, Rules.DICE_TRACK][track]
		var done_n: int = h.upgrades[track]
		var chips: HBoxContainer = upgrade_chips[track]
		for c in chips.get_children():
			c.queue_free()
		for i in track_values.size():
			chips.add_child(_track_chip(str(track_values[i]), i, done_n))
		var desc: Label = upgrade_desc[track]
		if h.can_upgrade(track):
			var cost := h.upgrade_cost(track)
			b.text = "Mejorar · %d" % cost
			b.icon = Icons.eter()
			b.disabled = not h.can_pay(cost)
			var next_text := _track_step_text(track, track_values[done_n + 1])
			desc.text = "Ahora %s → siguiente: %s." % [_track_step_text(track, track_values[done_n]), next_text]
			if b.disabled:
				desc.text += "  Te faltan %d de Éter." % (cost - h.eter)
				desc.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5))
			else:
				desc.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
			b.tooltip_text = "Sube la pista a %s por %d de Éter." % [next_text, cost]
		else:
			b.text = "Al máximo"
			b.icon = null
			b.disabled = true
			desc.text = "Pista completa: %s." % _track_step_text(track, track_values[done_n])
			desc.add_theme_color_override("font_color", GameTheme.TEXT_DIM)
	_show_detail(market_detail, selected_card if game.market.has(selected_card) else null)
	var block := _buy_block_reason(selected_card) if selected_card != null and game.market.has(selected_card) else ""
	buy_button.disabled = table_busy or selected_card == null or not game.market.has(selected_card) or block != ""
	buy_button.text = "Elige una carta de la mesa" if selected_card == null else "Comprar · %d" % selected_card.cost
	buy_button.icon = null if selected_card == null else Icons.eter()
	market_reason.text = block
	market_reason.visible = block != ""
	refresh_button.disabled = table_busy or not h.can_pay(Rules.MARKET_REFRESH_COST)
	refresh_button.tooltip_text = "Refrescar el mercado (cuesta %d de Éter)" % Rules.MARKET_REFRESH_COST + ("" if h.can_pay(Rules.MARKET_REFRESH_COST) else " · te faltan %d" % (Rules.MARKET_REFRESH_COST - h.eter))
	if table.dealt:
		table.dim_unavailable(func(card: ChampionData) -> bool: return h.can_add(card) and h.can_pay(card.cost))
	if not h.cuartel.has(selected_cuartel):
		selected_cuartel = null
	_refresh_hand()
	sell_button.disabled = selected_cuartel == null
	sell_button.text = "Vender" if selected_cuartel == null else "Vender · +%d" % h.sell_value(selected_cuartel)
	sell_button.icon = null if selected_cuartel == null else Icons.eter()
	sell_button.tooltip_text = "Pulsa una carta de tu mano para venderla por la mitad de su coste." if selected_cuartel == null else ""
	_update_deck_label()
	_refresh()


## Paso de una pista de mejora: hecho (tenue), actual (dorado) o siguiente (marcado con borde claro).
func _track_chip(text: String, index: int, current: int) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.set_corner_radius_all(5)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", GameTheme.bold_font)
	l.add_theme_font_size_override("font_size", 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if index == current:
		s.bg_color = GameTheme.GOLD
		s.border_color = Color(1, 0.95, 0.75)
		s.set_border_width_all(1)
		l.add_theme_color_override("font_color", Color(0.12, 0.08, 0.02))
		p.tooltip_text = "Tu nivel actual"
	elif index == current + 1:
		s.bg_color = Color(0.2, 0.16, 0.08)
		s.border_color = Color(1, 0.9, 0.6)
		s.set_border_width_all(1)
		l.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
		l.text = "▸ " + text
		p.tooltip_text = "Siguiente mejora"
	elif index < current:
		s.bg_color = Color(0.16, 0.13, 0.08)
		s.border_color = GameTheme.GOLD_DIM
		s.set_border_width_all(1)
		l.add_theme_color_override("font_color", GameTheme.GOLD_DIM)
	else:
		s.bg_color = Color(0.08, 0.07, 0.11)
		s.border_color = Color(0.25, 0.22, 0.2)
		s.set_border_width_all(1)
		l.add_theme_color_override("font_color", Color(0.5, 0.47, 0.45))
	p.add_theme_stylebox_override("panel", s)
	p.add_child(l)
	return p


## La mano: cartas del cuartel abajo, pequeñas; la que tiene el ratón encima se agranda.
func _refresh_hand() -> void:
	for c in hand_box.get_children():
		c.queue_free()
	var h := game.human
	for ch in h.cuartel:
		if game.state == Game.State.LINEUP and lineup.values().has(ch):
			continue # Las cartas colocadas viven en el tablero, no en la mano.
		var cv := HandCard.new()
		var extra := ""
		if game.state == Game.State.DRAFT:
			extra = "en tu cuartel"
		elif game.state == Game.State.MARKET:
			extra = "vender por %d de Éter" % h.sell_value(ch)
		elif game.state == Game.State.LINEUP:
			extra = "arrastra al tablero"
		cv.setup(ch.data, ch, extra)
		cv.selected = ch == selected_cuartel or ch == pending_card
		cv.hovered.connect(_on_hand_hover)
		cv.unhovered.connect(_on_hand_unhover)
		cv.pressed.connect(func() -> void:
			if game.state == Game.State.MARKET:
				if not _tut_can("sell"):
					_deny("Ahora no toca vender: sigue el paso del tutorial.")
					return
				selected_cuartel = ch
				_refresh_market()
			elif game.state == Game.State.LINEUP:
				if not _tut_can("lineup_drag"):
					_deny("Ahora no toca colocar: sigue el paso del tutorial.")
					return
				if lineup.size() >= game.human.battle_size() and not lineup.values().has(ch):
					_deny("Ya tienes %d en batalla, el máximo de tu pista. Quita uno del tablero para cambiarlo." % lineup.size())
					return
				pending_card = null if pending_card == ch else ch
				_refresh_lineup()
				if pending_card != null:
					_begin_drag({ "kind": "cuartel_card", "champion": ch }, Icons.archetype(ch.data.archetype), ch.data.display_name))
		hand_box.add_child(cv)
		if game.state == Game.State.LINEUP:
			cv.modulate.a = 0.0
			create_tween().tween_property(cv, "modulate:a", 1.0, 0.2)
	_layout_hand()
	_update_hand_empty()


## Abanico: las cartas se reparten en arco, inclinadas hacia los lados y solapadas si no caben.
func _layout_hand() -> void:
	var cards: Array[HandCard] = []
	for c in hand_box.get_children():
		if c is HandCard and not c.is_queued_for_deletion():
			cards.append(c)
	var n := cards.size()
	if n == 0:
		return
	var left := 320.0 if detail_panel != null and detail_panel.visible else 0.0
	var panel_w := hand_panel.size.x - left
	var pitch := minf(HandCard.W + 12.0, (panel_w - HandCard.W - 40.0) / float(maxi(n - 1, 1)))
	var mid := (n - 1) / 2.0
	var base_y := hand_panel.size.y - HandCard.H - 6.0
	for i in n:
		var c := cards[i]
		var off := i - mid
		var pos := Vector2(left + panel_w / 2.0 + off * pitch - HandCard.W / 2.0, base_y + off * off * 4.0)
		var rot := clampf(off * 3.5, -14.0, 14.0)
		c.base_position = pos
		c.base_rotation = rot
		c.z_index = i
		if c.get_meta("hovered", false):
			continue
		c.position = pos
		c.rotation_degrees = rot
		c.scale = Vector2.ONE


## En la alineación la mano solo se reconstruye si cambia qué cartas quedan fuera del tablero.
func _mark_hand() -> void:
	var expected := 0
	for ch in game.human.cuartel:
		if not lineup.values().has(ch):
			expected += 1
	if hand_box.get_child_count() != expected:
		_refresh_hand()
		return
	for cv in hand_box.get_children():
		var c := cv as HandCard
		if c == null or c.champion == null or lineup.values().has(c.champion):
			_refresh_hand()
			return
		c.selected = c.champion == pending_card
	_update_hand_empty()


## Aviso en la zona de la mano cuando todos los campeones están colocados.
func _update_hand_empty() -> void:
	if hand_empty_label == null:
		return
	var empty := hand_box.get_child_count() == 0
	hand_empty_label.visible = empty and game != null and game.state == Game.State.LINEUP
	if hand_empty_label.visible:
		hand_empty_label.text = "Todos tus campeones están en el tablero.\nArrastra una ficha fuera para devolverla a la mano."


## Al pasar el ratón la carta se endereza, sube y crece por encima de las demás;
## al salir vuelve a su pose del abanico. Nunca se desplaza su pose base.
func _on_hand_hover(cv: HandCard) -> void:
	if not is_instance_valid(cv):
		return
	cv.set_meta("hovered", true)
	cv.z_index = 50
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(cv, "scale", Vector2.ONE * HAND_HOVER_SCALE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(cv, "rotation_degrees", 0.0, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cv, "position", cv.base_position + Vector2(0, -HAND_HOVER_RAISE), 0.14).set_trans(Tween.TRANS_SINE)


func _on_hand_unhover(cv: HandCard) -> void:
	if not is_instance_valid(cv):
		return
	cv.set_meta("hovered", false)
	cv.z_index = hand_box.get_children().find(cv)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(cv, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cv, "rotation_degrees", cv.base_rotation, 0.14).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cv, "position", cv.base_position, 0.14).set_trans(Tween.TRANS_SINE)


func _finish_market() -> void:
	if game.state != Game.State.MARKET or not _tut_can("market_done"):
		return
	phase_left = 0.0
	if table_busy:
		await get_tree().create_timer(0.6, false).timeout
	game.finish_market()
	_enter_state()


func _on_buy_card() -> void:
	if selected_card == null or table_busy or not _tut_can("buy") or not game.human_buy(selected_card):
		return
	var card := selected_card
	var c3d := selected_card3d
	selected_card = null
	selected_card3d = null
	table_busy = true
	_refresh_market()
	await table.take(card, true, c3d)
	table_busy = false
	_refresh_market()


func _on_refresh_market() -> void:
	if table_busy or not _tut_can("refresh") or not game.human_refresh_market():
		return
	selected_card = null
	_deal_market()


func _on_sell() -> void:
	if selected_cuartel == null or not _tut_can("sell"):
		return
	game.human_sell(selected_cuartel)
	selected_cuartel = null
	_refresh_market()


# ---------------------------------------------------------------- alineación

func _on_tile_pressed(pos: Vector2i) -> void:
	if game.state != Game.State.LINEUP or Board.side_of(pos) != 0 or not _tut_can("lineup_drag"):
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
	var already := lineup.values().has(ch)
	var occupied := lineup.has(key)
	if not already and not occupied and lineup.size() >= game.human.battle_size():
		_deny("Solo puedes alinear %d campeones (pista «En batalla»). Quita uno para colocar otro." % game.human.battle_size())
		return
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
	_mark_hand()
	board3d.sync(Board3D.lineup_to_cells(lineup, 0), false, true, true)
	var free: Array[Vector2i] = []
	var full := lineup.size() >= game.human.battle_size()
	if pending_card != null and (not full or lineup.values().has(pending_card)):
		for row in range(1, Rules.BOARD_ROWS + 1):
			for col in Rules.BOARD_COLS:
				if not lineup.has(Vector2i(col, row)):
					free.append(Board.pos_from(0, row, col))
	board3d.highlight_tiles(free)
	var chosen: Array[Champion] = []
	chosen.assign(lineup.values())
	_refresh_tiers_panel(chosen)
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
			_deny(errors[0])
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
			drag_preview.visible = drag["kind"] != "table_card"
			if drag["kind"] == "table_card" and drag.get("card3d") != null:
				(drag["card3d"] as Card3D).begin_drag()
		if drag_active:
			drag_preview.position = pos + Vector2(14, 14)
			if drag["kind"] in ["cuartel_card", "piece"]:
				var tile := _tile_under_mouse(pos)
				board3d.hover_tile(tile if tile.x >= 0 and Board.side_of(tile) == 0 else Vector2i(-1, -1))
				if drag["kind"] == "piece":
					var piece := board3d.piece_of(drag["champion"])
					if piece != null:
						var from := camera.project_ray_origin(pos)
						var hit = Plane(Vector3.UP, 0.9).intersects_ray(from, camera.project_ray_normal(pos))
						if hit != null:
							piece.position = piece.position.lerp(hit, 0.5)
			if drag["kind"] == "table_card":
				var over := _over_drop_zone(pos)
				right_panel.modulate = Color(1.2, 1.15, 1.0) if over else Color.WHITE
				if drop_zone != null and game.state == Game.State.DRAFT:
					_style_drop_zone(over)
				var c3d: Card3D = drag.get("card3d")
				if c3d != null and is_instance_valid(c3d):
					var from := camera.project_ray_origin(pos)
					var hit = Plane(Vector3.UP, 1.9).intersects_ray(from, camera.project_ray_normal(pos))
					if hit != null:
						c3d.follow(hit)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_end_drag(event.position)


func _end_drag(pos: Vector2) -> void:
	var data := drag
	var active := drag_active
	drag = {}
	drag_active = false
	drag_preview.visible = false
	right_panel.modulate = Color.WHITE
	board3d.hover_tile(Vector2i(-1, -1))
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
			elif active:
				for k in lineup.keys():
					if lineup[k] == ch:
						lineup.erase(k)
			_refresh_lineup()
			var moved := board3d.piece_of(ch)
			if moved != null and moved.visible:
				moved.spawn_in()
		"table_card":
			if drop_zone != null and game.state == Game.State.DRAFT:
				_style_drop_zone(false)
			var c3d: Card3D = data.get("card3d")
			if active and _over_drop_zone(pos):
				selected_card = data["card"]
				if c3d != null and is_instance_valid(c3d):
					c3d.dragging = false
					selected_card3d = c3d
				if game.state == Game.State.DRAFT:
					_on_take_card()
				elif game.state == Game.State.MARKET:
					_on_buy_card()
			elif c3d != null and is_instance_valid(c3d) and active:
				c3d.return_home()


## Zona donde soltar una carta de la mesa: el panel lateral o la mano.
func _over_drop_zone(pos: Vector2) -> bool:
	return right_panel.get_global_rect().has_point(pos) or hand_panel.get_global_rect().has_point(pos)


func _tile_under_mouse(pos: Vector2) -> Vector2i:
	var from := camera.project_ray_origin(pos)
	var to := from + camera.project_ray_normal(pos) * 100.0
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector2i(-1, -1)
	return board3d.bodies.get(hit["collider"], Vector2i(-1, -1))


# ---------------------------------------------------------------- batalla

## Arranque de la batalla: aparece el rival, cartel, tus campeones se giran y empieza.
func _battle_intro() -> void:
	var battle := game.current_battle
	if battle == null:
		_refresh_battle()
		_start_battle_loop()
		return
	battle_playing = true
	_refresh_battle()
	board3d.sync(battle.board.cells, true, true)
	await get_tree().create_timer(0.7, false).timeout
	_celebrate("Batalla contra %s" % battle.adalids[1].display_name, GameTheme.GOLD, false)
	await get_tree().create_timer(0.8, false).timeout
	for ch in board3d.pieces:
		var piece: ChampionPiece = board3d.pieces[ch]
		piece.set_facing_camera(false, true)
		Fx.dust_puff(board3d, piece.position, Vector3.FORWARD)
	await get_tree().create_timer(0.6, false).timeout
	_celebrate("¡A luchar!", Color(1, 0.5, 0.4), true)
	await get_tree().create_timer(2.6, false).timeout
	battle_playing = false
	if game.state == Game.State.BATTLE and game.current_battle == battle:
		if tutorial != null and tutorial.pause_first_battle():
			battle_paused = true
			_auto_token += 1
			_refresh_battle()
		else:
			_start_battle_loop()


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
	if not _tut_can("battle_pause"):
		return
	battle_paused = not battle_paused
	if battle_paused:
		_auto_token += 1
	else:
		_start_battle_loop()
	_refresh_battle()


func _step_round() -> void:
	if battle_playing or game.state != Game.State.BATTLE or not _tut_can("battle_step"):
		return
	await _play_round()


## Resuelve un asalto y lo anima evento a evento.
func _play_round() -> void:
	if battle_playing or game.current_battle == null:
		return
	battle_playing = true
	var battle := game.current_battle
	_celebrate("Asalto %d" % battle.round_no, GameTheme.GOLD, false, 0.3)
	await get_tree().create_timer(0.55, false).timeout
	if game.current_battle != battle or game.state != Game.State.BATTLE:
		battle_playing = false
		return
	battle.commit_round()
	var evs := battle.events.duplicate()
	_refresh()
	for ch in board3d.pieces:
		(board3d.pieces[ch] as ChampionPiece).set_spent(false) # Nuevo asalto: todos recuperan el color.
	await _animate_events(battle, evs)
	var finished := not battle.begin_round()
	battle_playing = false
	if finished:
		var g := game
		game.advance()
		_refresh_battle_hud(battle)
		battle_status.text = "Batalla terminada."
		_announce_battle(battle)
		var st := game.state
		await get_tree().create_timer(3.4, false).timeout # La celebración termina antes del resumen.
		if game != g or game.state != st:
			return
		_enter_state()
	else:
		_refresh_battle()


func _announce_battle(battle: Battle) -> void:
	var r := battle.result
	if tutorial != null:
		print("TUTORIAL ciclo %d: %s" % [game.cycle, "victoria" if r.get("winner") == game.human else ("empate" if r.get("tie", false) else "derrota")])
	var winner: Adalid = r.get("winner", null)
	if winner != null:
		for ch in board3d.pieces:
			if ch.side == (0 if winner == battle.adalids[0] else 1):
				(board3d.pieces[ch] as ChampionPiece).cheer()
	var center := Vector3(Board3D.world_x(2), 0, (Board3D.world_z(0) + Board3D.world_z(5)) / 2.0)
	if r.get("tie", false):
		_celebrate("Empate", GameTheme.TEXT_DIM, false)
	elif r.get("winner") == game.human:
		_camera_shake(0.05)
		Fx.victory(board3d, center, GameTheme.GOLD)
		for ch in board3d.pieces:
			var p: ChampionPiece = board3d.pieces[ch]
			if ch.side == 0 and p.visible:
				Fx.pillar(board3d, p.position, GameTheme.GOLD, 3.0, 0.9, 1.4)
				Fx.glyph_floor(board3d, p.position, GameTheme.GOLD, 1.5, 1.6)
		_celebrate("¡VICTORIA!", GameTheme.GOLD, true)
	else:
		Fx.defeat(board3d, Vector3(Board3D.world_x(2), 0, Board3D.world_z(1)))
		_screen_flash(Color(0.3, 0.02, 0.05))
		_celebrate("Derrota", Color(0.95, 0.45, 0.4), false)


func _animate_events(battle: Battle, evs: Array) -> void:
	_last_hit = {}
	for e in evs:
		if game.current_battle != battle:
			return
		var ch: Champion = e.get("ch", null)
		var piece: ChampionPiece = board3d.piece_of(ch) if ch != null else null
		if e["type"] in ["damage", "heal", "death"]:
			_refresh_battle_hp(battle)
		match e["type"]:
			"move":
				if piece != null:
					await piece.hop_to(Board3D.world_pos(e["to"])).finished
			"attack":
				if piece != null:
					piece.set_spent(true) # Ya atacó este asalto.
				var target_piece: ChampionPiece = board3d.piece_of(e["target"])
				if piece != null and target_piece != null:
					var color := Icons.color_of(ch.data)
					var dir := (target_piece.position - piece.position).normalized()
					_last_hit = { "dir": dir, "element": ch.data.element, "color": color }
					# Apuntar: el atacante se gira hacia su objetivo, se dibuja la línea
					# de ataque y la mira bajo la víctima; una pausa breve para leerlo.
					var side_color := Color(0.4, 0.7, 1.0) if ch.side == 0 else Color(1.0, 0.45, 0.4)
					piece.face_towards(target_piece.position, 0.18)
					Fx.attack_line(board3d, piece.position, target_piece.position, side_color, 0.55 if ch.data.reach() == 1 else 0.8)
					Fx.target_marker(board3d, target_piece.position, side_color, 1.0)
					await get_tree().create_timer(0.32, false).timeout
					if ch.data.reach() == 1:
						Fx.dust_puff(board3d, piece.position, dir)
						var lunge := piece.lunge(target_piece.position)
						await get_tree().create_timer(0.34, false).timeout
						Fx.slash(board3d, target_piece.position + Vector3(0, 0.6, 0), color, -35.0 if dir.x <= 0 else 35.0)
						Fx.impact(board3d, target_piece.position, color, ch.data.element, dir, 0.8)
						_camera_shake(0.05)
						await lunge.finished
					else:
						piece.play_clip("attack")
						await get_tree().create_timer(0.3, false).timeout
						await Fx.projectile(board3d, piece.position, target_piece.position, color, ch.data.element, ch.data.reach() >= 3)
						Fx.impact(board3d, target_piece.position, color, ch.data.element, dir, 1.0)
						_camera_shake(0.03)
					piece.face_default(0.35)
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
					var green := Color(0.5, 1, 0.55)
					Fx.pillar(board3d, piece.position, green, 2.0, 0.7, 0.8)
					Fx.swirl(board3d, piece.position, green, -1, 26, 0.8)
					Fx.glyph_floor(board3d, piece.position, green, 1.2, 0.8)
					piece.tint(Color(0.3, 0.7, 0.35), 0.9)
					Fx.float_text(board3d, piece.position, "+%d" % e["amount"], green)
					await get_tree().create_timer(0.35, false).timeout
			"power":
				if piece != null:
					piece.set_spent(true)
				if piece != null:
					var elem: int = e.get("element", -1)
					var color: Color = Icons.ELEMENT_COLORS.get(elem, GameTheme.GOLD)
					var icon: Texture2D = Icons.element(elem) if elem >= 0 else Icons.archetype(e.get("archetype", 0))
					piece.pulse()
					piece.tint(color, 1.0)
					Fx.glyph_floor(board3d, piece.position, color, 1.7, 1.0)
					Fx.pillar(board3d, piece.position, color, 2.6, 0.9, 0.9)
					Fx.swirl(board3d, piece.position, color, elem, 40, 0.9)
					Fx.icon_rise(board3d, piece.position, icon, color, 0.0022, 1.2, 1.0)
					Fx.float_text(board3d, piece.position + Vector3(0, 1.0, 0), e["name"], Color(1, 0.92, 0.65), 54)
					_camera_shake(0.015)
					await get_tree().create_timer(0.55, false).timeout
			"tier":
				var elem: int = e.get("element", -1)
				var arch: int = e.get("archetype", -1)
				var color: Color = Icons.ELEMENT_COLORS.get(elem, GameTheme.GOLD)
				var icon: Texture2D = Icons.element(elem) if elem >= 0 else Icons.archetype(arch if arch >= 0 else 0)
				var side: int = e["side"]
				var center := Vector3(Board3D.world_x(2), 0, Board3D.world_z(1) if side == 0 else Board3D.world_z(4))
				Fx.shockwave(board3d, center, color, 4.5, 0.8)
				Fx.glyph_floor(board3d, center, color, 6.0, 1.4)
				Fx.icon_rise(board3d, center, icon, color, 0.0045, 1.8, 1.4)
				if elem >= 0:
					Fx.rain(board3d, center, Vector3(2.8, 0.1, 1.6), color, elem, 90)
				# Cada campeón del bando que forma parte del tier se ilumina.
				var i := 0
				for ch2 in board3d.pieces:
					var p2: ChampionPiece = board3d.pieces[ch2]
					if ch2.side != side or not p2.visible:
						continue
					var member: bool = (elem >= 0 and ch2.data.element == elem) or (arch >= 0 and ch2.data.has_archetype(arch))
					if member:
						Fx.pillar(board3d, p2.position, color, 2.2, 0.7, 1.0)
						p2.tint(color, 1.2)
						p2.pulse(1.15)
						i += 1
				if piece != null:
					Fx.impact(board3d, piece.position, color, elem, Vector3.UP, 1.0)
				_tier_banner(side, e["name"], color)
				_screen_flash(color)
				_camera_shake(0.05)
				await get_tree().create_timer(0.9, false).timeout
			"dodge":
				if piece != null:
					var cyan := Color(0.7, 0.95, 1)
					Fx.afterimage(board3d, piece.position, cyan)
					piece.sidestep()
					Fx.float_text(board3d, piece.position, "¡esquiva!", cyan, 44)
					await get_tree().create_timer(0.3, false).timeout
			"freeze":
				if piece != null:
					piece.refresh()
					piece.tint(Color(0.45, 0.75, 1.0), 2.0)
					piece.flash(Color(0.6, 0.85, 1))
					Fx.frost(board3d, piece.position)
					Fx.float_text(board3d, piece.position, "❄ congelado", Color(0.6, 0.85, 1), 44)
					await get_tree().create_timer(0.35, false).timeout
			"curse":
				if piece != null:
					piece.refresh()
					piece.tint(Color(0.5, 0.15, 0.7), 2.0)
					Fx.curse(board3d, piece.position)
					Fx.float_text(board3d, piece.position, "☠ maldito", Color(0.8, 0.5, 1), 44)
					await get_tree().create_timer(0.35, false).timeout
			"death":
				if piece != null:
					var is_mine := ch.side == 0
					piece.play_clip("death")
					piece.tint(Color(0.1, 0.08, 0.12), 1.4)
					_camera_shake(0.06)
					Fx.death(board3d, piece.position, Icons.color_of(ch.data), is_mine)
					if is_mine:
						_screen_flash(Color(0.4, 0.05, 0.1))
					await get_tree().create_timer(1.0 if piece.has_model() else 0.4, false).timeout
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
func _celebrate(text: String, color: Color, big: bool, hold := 1.4) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.visible = true
	banner.modulate = Color(1, 1, 1, 0)
	banner.scale = Vector2(0.4, 0.4)
	await get_tree().process_frame
	banner.pivot_offset = banner.size / 2.0
	banner.position = (fx_layer.size - banner.size) / 2.0
	banner.add_theme_color_override("font_outline_color", Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.95) if big else Color(0, 0, 0, 0.9))
	var tw := create_tween()
	_banner_tween = tw
	tw.set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(banner, "scale", Vector2.ONE * (1.25 if big else 1.0), 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if big:
		tw.chain().tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
		for i in 3:
			tw.chain().tween_property(banner, "scale", Vector2.ONE * 1.06, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.chain().tween_property(banner, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		tw.chain().tween_interval(hold)
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
	_refresh_battle_hud(battle)
	battle_status.text = "Detenida. Pulsa «Siguiente asalto» para avanzar." if battle_paused else "Automática: un asalto cada %d s." % int(AUTO_ROUND_SECONDS)
	pause_button.text = "▶ Reanudar" if battle_paused else "⏸ Detener"
	step_button.visible = battle_paused
	if not battle_playing:
		board3d.sync(battle.board.cells, true)
	_refresh()


## Gemas de asalto, vida de los dos adalides y campeones en pie.
func _refresh_battle_hud(battle: Battle) -> void:
	battle_title.text = "Batalla contra %s" % battle.adalids[1].display_name
	var limit := battle.max_rounds
	var current := maxi(battle.round_no, 1)
	var shown := limit if limit > 0 else maxi(current, Rules.ROUNDS_PER_BATTLE)
	for c in battle_pips.get_children():
		c.queue_free()
	for i in shown:
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(14, 14)
		pip.pivot_offset = Vector2(7, 7)
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(7)
		var played := i + 1 < current or battle.finished
		var now := i + 1 == current and not battle.finished
		if now:
			s.bg_color = Color(1.0, 0.85, 0.45)
			s.border_color = Color(1.0, 0.95, 0.75)
			s.set_border_width_all(2)
			s.shadow_color = Color(1.0, 0.75, 0.3, 0.6)
			s.shadow_size = 5
		elif played:
			s.bg_color = GameTheme.GOLD
			s.border_color = GameTheme.GOLD_DIM
			s.set_border_width_all(1)
		else:
			s.bg_color = Color(0.1, 0.08, 0.15)
			s.border_color = GameTheme.GOLD_DIM
			s.set_border_width_all(1)
		pip.add_theme_stylebox_override("panel", s)
		battle_pips.add_child(pip)
		if now:
			var tw := pip.create_tween().set_loops() # Ligado a la gema: muere con ella.
			tw.tween_property(pip, "scale", Vector2.ONE * 1.25, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(pip, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if battle.finished:
		battle_round_label.text = "Terminada en %d asaltos" % battle.round_no
	elif limit > 0:
		battle_round_label.text = "Asalto %d de %d" % [current, limit]
	else:
		battle_round_label.text = "Asalto %d · hasta el final" % current
	for side in 2:
		var a := battle.adalids[side]
		battle_names[side].text = ("Tú" if a == game.human else a.display_name)
	_refresh_battle_hp(battle)
	_refresh_tiers_panel(battle.board.champions(0), battle.board.champions(1), battle.adalids[1].display_name)


## Vida de los adalides (número) y vida total de sus campeones (barra). Se llama tras cada golpe.
func _refresh_battle_hp(battle: Battle) -> void:
	for side in 2:
		var a := battle.adalids[side]
		battle_lives[side].text = "♥ %d" % a.life
		var alive := battle.board.alive_count(side)
		battle_alive[side].text = "⚔ %d/%d" % [alive, battle.squad_size[side]]
		var hp := battle.squad_hp(side)
		var hp_max := maxi(battle.squad_hp_max[side], 1)
		battle_hp[side].text = "%d/%d" % [hp, hp_max]
		var bar := battle_bars[side]
		bar.max_value = hp_max
		if bar.value != hp:
			var tw := create_tween()
			tw.tween_property(bar, "value", float(hp), 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- refresco general

func _refresh() -> void:
	if game == null:
		return
	for st in panels:
		panels[st].visible = st == game.state
	_tut_apply_locks()
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
	hud.text = "[color=#7ee07e]♥ %d[/color]   %s [color=#9ecbff]%d[/color]%s" % [h.life, Icons.eter_bb(22), h.eter, racha]
	hud.tooltip_text = "Vida %d · Éter %d · Racha %s · Cuartel %d/%d · Héroes %d/%d · En batalla %d · Dados %d" % [
		h.life, h.eter, ("%s %d (+%d de Éter)" % ["victorias" if h.streak_is_win else "derrotas", h.streak, h.streak_bonus()]) if h.streak > 0 else "—",
		h.base_count(), h.cuartel_capacity(), h.hero_count(), h.hero_slots(), h.battle_size(), h.dice_count()]
	var lines: PackedStringArray = ["[table=6][cell padding=6,2,6,2][b]Adalid[/b][/cell][cell padding=6,2,6,2][b]♥[/b][/cell][cell padding=6,2,6,2][b]Éter[/b][/cell][cell padding=6,2,6,2][b]Cuartel[/b][/cell][cell padding=6,2,6,2][b]Batalla[/b][/cell][cell padding=6,2,6,2][b]Dados[/b][/cell]"]
	for a in game.adalids:
		var color := "#f0d080" if a == game.human else ("#777777" if a.eliminated else "#e8e4dc")
		lines.append("[cell padding=6,2,6,2][color=%s]%s%s[/color][/cell][cell padding=6,2,6,2][color=#7ee07e]%d[/color][/cell][cell padding=6,2,6,2][color=#9ecbff]%d[/color][/cell][cell padding=6,2,6,2]%d/%d[/cell][cell padding=6,2,6,2]%d[/cell][cell padding=6,2,6,2]%d[/cell]" % [
			color, "► " if a == game.human else "", a.display_name, a.life, a.eter, a.base_count(), a.cuartel_capacity(), a.battle_size(), a.dice_count()])
	lines.append("[/table]")
	standings.text = "\n".join(lines)
	var text := "\n".join(game.log)
	if game.current_battle != null:
		text += "\n" + "\n".join(game.current_battle.log)
	log_label.text = text


# ---------------------------------------------------------------- capturas

func _screenshot_tour(dir: String) -> void:
	_show_main_menu()
	await get_tree().create_timer(1.2, false).timeout
	await _snap(dir.path_join("0_menu.png"))
	_show_setup(true)
	await _snap(dir.path_join("0_menu_setup.png"))
	_show_setup(false)
	_start_game()
	await get_tree().create_timer(0.8, false).timeout
	await _snap(dir.path_join("1_draft_mazo.png"))
	await _on_deck_clicked()
	while table_busy:
		await get_tree().process_frame
	await _snap(dir.path_join("1_draft.png"))
	if game.draft_current() == game.human and not game.draft_pool.is_empty():
		var demo: ChampionData = game.draft_pool[7 % game.draft_pool.size()]
		var c3d := table.find_card(demo)
		selected_card = demo
		selected_card3d = c3d
		table.select(c3d)
		_refresh_draft()
		await get_tree().create_timer(0.6, false).timeout
		await _snap(dir.path_join("1_draft_seleccion.png"))
		c3d.begin_drag()
		for i in 12:
			c3d.follow(Vector3(-3.0 + i * 0.1, 1.9, 1.2 - i * 0.25))
			await get_tree().process_frame
		_style_drop_zone(true)
		await _snap(dir.path_join("1_draft_arrastre.png"))
		_style_drop_zone(false)
		c3d.return_home()
		await get_tree().create_timer(0.4, false).timeout
		selected_card = null
		table.select(null)
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
				selected_card3d = table.find_card(pick)
				table.select(selected_card3d)
				_refresh_draft()
				await _on_take_card()
		while table_busy:
			await get_tree().process_frame
	while table_busy:
		await get_tree().process_frame
	if game.state == Game.State.MARKET and not game.market.is_empty():
		selected_card = game.market[0]
		selected_card3d = table.find_card(selected_card)
		table.select(selected_card3d)
		_refresh_market()
	await _snap(dir.path_join("2_mercado.png"))
	_toggle_overlay(skills_panel)
	await _snap(dir.path_join("2_habilidades.png"))
	_toggle_overlay(skills_panel)
	_toggle_pause_menu()
	await _snap(dir.path_join("2_pausa.png"))
	_toggle_pause_menu()
	_toggle_overlay(help_panel)
	await _snap(dir.path_join("2_guia.png"))
	(help_panel.find_child("*", true, false) as Control).get_child(1).set("scroll_vertical", 700)
	await _snap(dir.path_join("2_guia_b.png"))
	_toggle_overlay(help_panel)
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
		for i in 10:
			await get_tree().create_timer(0.3, false).timeout
			await _snap(dir.path_join("4_intro_%02d.png" % i))
		while battle_playing:
			await get_tree().process_frame
		await _snap(dir.path_join("4_batalla.png"))
		# Demo de efectos: eventos simulados sobre fichas reales (no cambian el estado).
		var battle := game.current_battle
		var mine: Array[Champion] = battle.board.champions(0)
		var theirs: Array[Champion] = battle.board.champions(1)
		if not mine.is_empty() and not theirs.is_empty():
			var demo_evs: Array = [
				{ "type": "power", "ch": mine[0], "name": "Poder de prueba", "element": mine[0].data.element, "archetype": mine[0].data.archetype },
				{ "type": "tier", "side": 0, "name": "Tier de prueba", "element": mine[0].data.element if mine[0].data.element >= 0 else Rules.Element.FUEGO },
				{ "type": "heal", "ch": mine[0], "amount": 2, "hp": mine[0].hp },
				{ "type": "freeze", "ch": theirs[0] },
				{ "type": "curse", "ch": theirs[-1] },
				{ "type": "dodge", "ch": mine[-1] },
				{ "type": "death", "ch": theirs[0] },
			]
			var k := 0
			for de in demo_evs:
				battle_playing = true
				var one: Array = [de]
				_animate_events.call_deferred(battle, one)
				for j in 3:
					await get_tree().create_timer(0.18, false).timeout
					await _snap(dir.path_join("4_fx_%s_%d.png" % [de["type"], j]))
				await get_tree().create_timer(0.6, false).timeout
				battle_playing = false
				k += 1
			# Demo de victoria.
			var center := Vector3(Board3D.world_x(2), 0, (Board3D.world_z(0) + Board3D.world_z(5)) / 2.0)
			Fx.victory(board3d, center, GameTheme.GOLD)
			for ch in board3d.pieces:
				var pz: ChampionPiece = board3d.pieces[ch]
				if ch.side == 0 and pz.visible:
					Fx.pillar(board3d, pz.position, GameTheme.GOLD, 3.0, 0.9, 1.4)
					pz.cheer()
			_celebrate("¡VICTORIA!", GameTheme.GOLD, true)
			for j in 4:
				await get_tree().create_timer(0.25, false).timeout
				await _snap(dir.path_join("4_fx_victoria_%d.png" % j))
			await get_tree().create_timer(2.0, false).timeout
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
		var waited := 0.0
		while not panels[Game.State.CYCLE_END].visible and waited < 8.0:
			waited += get_process_delta_time()
			await get_tree().process_frame
		await get_tree().create_timer(0.8, false).timeout
		await _snap(dir.path_join("8_fin_ciclo.png"))
	get_tree().quit()


## Reproduce la intro y captura dos momentos y el menú.
func _intro_tour(dir: String) -> void:
	_play_intro_video()
	await get_tree().create_timer(2.5, false).timeout
	await _snap(dir.path_join("i1_intro.png"))
	var length: float = video_player.get_stream_length()
	if length <= 0.0:
		length = 5.0
	await get_tree().create_timer(maxf(length - 3.2, 0.5), false).timeout
	await _snap(dir.path_join("i2_titulo.png"))
	while video_layer.visible:
		await get_tree().process_frame
	await get_tree().create_timer(0.8, false).timeout
	await _snap(dir.path_join("i3_menu.png"))
	get_tree().quit()


## Muestra el vídeo de victoria y captura tres momentos.
func _victory_tour(dir: String) -> void:
	_show_main_menu()
	await get_tree().create_timer(0.6, false).timeout
	await _snap(dir.path_join("v0_menu.png"))
	_start_game()
	await get_tree().create_timer(0.8, false).timeout
	for a in game.adalids:
		if a != game.human:
			a.life = 0
			a.eliminated = true
	game.state = Game.State.OVER
	_enter_state()
	for t in [2.0, 3.5, 3.0]:
		await get_tree().create_timer(t, false).timeout
		await _snap(dir.path_join("v%d_video.png" % int(t * 10)))
	await get_tree().create_timer(3.0, false).timeout
	await _snap(dir.path_join("v9_final.png"))
	get_tree().quit()


## Recorre el tutorial haciendo lo que pide cada paso y captura cada uno.
func _tutorial_tour(dir: String) -> void:
	_show_main_menu()
	await get_tree().create_timer(0.6, false).timeout
	_start_tutorial()
	var t := tutorial
	var snap_i := 0
	var last_step := -1
	var guard := 0
	while t != null and not t.finished and guard < 400:
		guard += 1
		await get_tree().create_timer(0.25, false).timeout
		if t.index != last_step:
			last_step = t.index
			await get_tree().create_timer(0.5, false).timeout
			snap_i += 1
			await _snap(dir.path_join("t%02d_paso%02d.png" % [snap_i, t.index + 1]))
			print("TUTORIAL paso %d: %s" % [t.index + 1, t.body.text.left(60).replace("\n", " ")])
		if table_busy or battle_playing:
			continue
		match t.index:
			0:
				if not table.dealt:
					_on_deck_clicked()
			1, 2:
				if t.allowed_card != null and game.draft_current() == game.human:
					selected_card = t.allowed_card
					selected_card3d = table.find_card(t.allowed_card)
					table.select(selected_card3d)
					_on_take_card()
			3:
				if game.state == Game.State.LINEUP:
					if lineup.size() < game.human.cuartel.size():
						var col := 1
						for ch in game.human.cuartel:
							_place_in_lineup(ch, Vector2i(col, 1))
							col += 1
						_refresh_lineup()
						await get_tree().create_timer(0.5, false).timeout
						snap_i += 1
						await _snap(dir.path_join("t%02d_paso04_colocado.png" % snap_i))
					else:
						_on_lineup_done(false)
			4, 5, 6:
				if game.state == Game.State.BATTLE and battle_paused:
					_step_round()
			7:
				if game.state == Game.State.CYCLE_END:
					_next_cycle()
			8:
				if game.state == Game.State.MARKET and not game.market.is_empty():
					for card in game.market:
						if game.human.can_pay(card.cost) and game.human.can_add(card):
							selected_card = card
							selected_card3d = table.find_card(card)
							table.select(selected_card3d)
							_on_buy_card()
							break
			9:
				if game.state == Game.State.MARKET:
					game.human_upgrade(Adalid.Track.BATTLE)
					_refresh_market()
			10:
				if game.state == Game.State.MARKET:
					_finish_market()
			11:
				if game.state == Game.State.LINEUP:
					_on_lineup_done(false)
			12:
				t._on_next()
	print("TUTORIAL terminado: finished=%s, pasos capturados=%d, guard=%d" % [str(t != null and t.finished), snap_i, guard])
	await get_tree().create_timer(0.5, false).timeout
	await _snap(dir.path_join("t_fin_menu.png"))
	get_tree().quit()


func _snap(path: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
