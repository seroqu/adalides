class_name DraftTable
extends Node3D
## Mesa del draft: un mazo clicable y las cartas repartidas sobre el tablero.

signal deck_clicked
signal card_clicked(card3d: Card3D)
signal card_released(card3d: Card3D, screen_pos: Vector2)

const COLS := 6
const SPACING_X := 1.22
const SPACING_Z := 1.8
const HOVER_Y := 0.9

const PLAQUE_PX := 0.0036 # Unidades por píxel de la placa del mazo (512 px ≈ 1.85 u).

var deck_node: Node3D
var _plaque: Node3D
var _count_label: Label3D
var _hint_label: Label3D
var _last_count: int = -1
var deco: Node3D # Decorado del draft: sello, braseros, motas.
var _sigils: Array[Node3D] = []
var _flames: Array[OmniLight3D] = []
var _time: float = 0.0
var cards: Array[Card3D] = [] # Una misma carta puede estar repetida (copias del mazo).
var dealt: bool = false
var deck_pos := Vector3(2.2, 0.0, 1.0)


func _ready() -> void:
	_build_deco()
	deck_node = Node3D.new()
	deck_node.position = deck_pos
	add_child(deck_node)
	for i in 8:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(Card3D.W, 0.03, Card3D.H)
		m.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.09, 0.16)
		mat.roughness = 0.7
		m.material_override = mat
		m.position = Vector3(0.008 * i, 0.03 * i, -0.008 * i)
		deck_node.add_child(m)
	# Dorso ilustrado sobre la carta superior del mazo.
	var top := Card3D.back_sprite()
	top.rotation_degrees = Vector3(-90, 0, 0)
	top.position = Vector3(0.008 * 7, 0.03 * 7 + 0.017, -0.008 * 7)
	deck_node.add_child(top)
	_build_plaque()
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(Card3D.W + 0.2, 0.5, Card3D.H + 0.2)
	shape.shape = cs
	body.add_child(shape)
	body.position.y = 0.15
	body.input_event.connect(func(_c: Node, event: InputEvent, _p: Vector3, _n: Vector3, _i: int) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			deck_clicked.emit())
	deck_node.add_child(body)


## Placa sobre el mazo: título, número de cartas grande y una pista opcional.
func _build_plaque() -> void:
	_plaque = Node3D.new()
	_plaque.name = "DeckPlaque"
	_plaque.position = Vector3(0.3, 1.95, 0.0)
	deck_node.add_child(_plaque)
	var glow := Sprite3D.new()
	glow.texture = Fx.tex("circle_05")
	glow.modulate = Color(1.0, 0.8, 0.4, 0.28)
	glow.pixel_size = 0.009
	glow.scale = Vector3(1.15, 0.6, 1.0)
	glow.position.z = -0.02
	glow.no_depth_test = true
	glow.render_priority = 6
	_plaque.add_child(glow)
	var plate := Sprite3D.new()
	plate.texture = Icons.deck_plaque()
	plate.pixel_size = PLAQUE_PX
	plate.no_depth_test = true
	plate.render_priority = 7
	plate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_plaque.add_child(plate)
	_plaque.add_child(_plaque_label("MAZO DEL DEMIURGO", 22, GameTheme.GOLD, GameTheme.title_font, _plaque_pos(300, 44)))
	_count_label = _plaque_label("0", 78, Color.WHITE, GameTheme.title_font, _plaque_pos(250, 128), HORIZONTAL_ALIGNMENT_RIGHT)
	_plaque.add_child(_count_label)
	var word := _plaque_label("cartas", 30, GameTheme.TEXT_DIM, GameTheme.bold_font, _plaque_pos(262, 138), HORIZONTAL_ALIGNMENT_LEFT)
	_plaque.add_child(word)
	_hint_label = _plaque_label("", 20, Color(0.95, 0.82, 0.5), GameTheme.body_font, _plaque_pos(300, 186))
	_plaque.add_child(_hint_label)


func _plaque_pos(px: float, py: float) -> Vector3:
	return Vector3((px - 256.0) * PLAQUE_PX, (112.0 - py) * PLAQUE_PX, 0.01)


func _plaque_label(text: String, size: int, color: Color, font: Font, pos: Vector3, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size * 2 # Doble resolución: letra nítida como en las cartas.
	l.pixel_size = PLAQUE_PX / 2.0
	l.modulate = color
	l.outline_size = int(size * 0.35)
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.horizontal_alignment = align
	l.position = pos
	l.no_depth_test = true
	l.render_priority = 8
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return l


## Actualiza el número de cartas (con un latido si cambia) y la pista bajo él.
func set_deck_count(count: int, hint := "") -> void:
	_hint_label.text = hint
	_hint_label.visible = hint != ""
	if count == _last_count:
		return
	var changed := _last_count >= 0
	_last_count = count
	_count_label.text = str(count)
	if not changed:
		return
	var tw := create_tween()
	tw.tween_property(_count_label, "scale", Vector3.ONE * 1.35, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_count_label, "modulate", GameTheme.GOLD, 0.12)
	tw.tween_property(_count_label, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_count_label, "modulate", Color.WHITE, 0.45)


func slot_position(index: int, total: int) -> Vector3:
	var cols: int = mini(COLS, total)
	var rows := ceili(total / float(cols))
	var col := index % cols
	var row := index / cols
	var x := -(1.85 + (col - (cols - 1) / 2.0) * SPACING_X)
	var depth := (rows - 1) / 2.0 - row # Las filas del fondo quedan más altas para no taparse.
	return Vector3(x, HOVER_Y + depth * 0.4, 1.0 + depth * SPACING_Z)


## Reparte las cartas desde el mazo, una a una, y las voltea. Devuelve al terminar.
func deal(pool: Array[ChampionData]) -> void:
	clear()
	dealt = true
	var i := 0
	var last: Tween = null
	for card in pool:
		var c := Card3D.new()
		c.setup(card)
		c.position = deck_pos + Vector3(0, 0.3, 0)
		c.rotation_degrees.x = -28 # Inclinada hacia la cámara.
		c.home = slot_position(i, pool.size())
		c.home_rot = Vector3(-28, 0, 0)
		add_child(c)
		c.pressed.connect(func() -> void: card_clicked.emit(c))
		c.released.connect(func(screen_pos: Vector2) -> void: card_released.emit(c, screen_pos))
		cards.append(c)
		var target := slot_position(i, pool.size())
		var tw := create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(c, "position", target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(c.flip.bind(0.35))
		last = tw
		i += 1
	# Se espera por tiempo, no por el tween: si la mesa se vacía a mitad del
	# reparto (fin del mercado), el tween muere y un await sobre él no volvería.
	if last != null:
		await get_tree().create_timer(0.08 * pool.size() + 0.3 + 0.35 + 0.4, false).timeout


## La carta vuela hacia el fondo (la toma una IA) o hacia la cámara (la tomas tú).
## Si se indica `which`, se lleva exactamente esa carta física; si no, una copia
## cualquiera de esos datos (sin robar la que tengas seleccionada, si hay otra).
func take(card: ChampionData, by_human: bool, which: Card3D = null) -> void:
	var c := which if which != null and is_instance_valid(which) and cards.has(which) else find_card(card, not by_human)
	if c == null:
		return
	cards.erase(c)
	c.dragging = false
	var target := Vector3(c.position.x, 2.5, -3.5) if by_human else Vector3(c.position.x, 2.2, 7.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "scale", Vector3(0.2, 0.2, 0.2), 0.45)
	tw.chain().tween_callback(c.queue_free)
	await tw.finished


## Una carta 3D de la mesa con esos datos: la seleccionada si la hay (o, con
## `avoid_selected`, cualquier otra copia antes que la seleccionada).
func find_card(card: ChampionData, avoid_selected := false) -> Card3D:
	var selected_one: Card3D = null
	var other: Card3D = null
	for c in cards:
		if c.card == card:
			if c.is_selected():
				selected_one = c
			elif other == null:
				other = c
	if avoid_selected:
		return other if other != null else selected_one
	return selected_one if selected_one != null else other


## Selecciona exactamente esa carta física (null = ninguna).
func select(which: Card3D) -> void:
	for c in cards:
		c.set_selected(c == which)


func dim_unavailable(available: Callable) -> void:
	for c in cards:
		c.set_dim(not available.call(c.card))


func clear() -> void:
	for c in cards:
		c.queue_free()
	cards.clear()
	dealt = false


# ---------------------------------------------------------------- decorado

func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	Deco.animate(_sigils, _flames, _time, delta)
	# La placa mira siempre a la cámara y flota con suavidad.
	var cam := get_viewport().get_camera_3d()
	if cam != null and _plaque != null:
		_plaque.global_transform.basis = cam.global_transform.basis
		_plaque.position.y = 1.95 + sin(_time * 1.3) * 0.03


func _build_deco() -> void:
	deco = Node3D.new()
	add_child(deco)
	# Sello arcano bajo las cartas y dos sellos menores a los lados.
	_sigils.append(Deco.sigil(deco, Vector3(-1.85, 0.02, 1.0), 7.2, Color(0.85, 0.7, 0.32, 0.55)))
	_sigils.append(Deco.sigil(deco, Vector3(2.75, 0.03, -1.3), 2.0, Color(0.6, 0.75, 1.0, 0.7)))
	_sigils.append(Deco.sigil(deco, Vector3(-6.4, 0.03, -1.3), 2.0, Color(0.6, 0.75, 1.0, 0.7)))
	_flames.append(Deco.brazier(deco, Vector3(3.5, 0, 3.6)))
	_flames.append(Deco.brazier(deco, Vector3(-7.2, 0, 3.6)))
	Deco.motes(deco, Vector3(-1.85, 1.0, 1.0), Vector3(5.5, 0.6, 3.5), Color(1, 0.9, 0.6))
