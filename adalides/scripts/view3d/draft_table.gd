class_name DraftTable
extends Node3D
## Mesa del draft: un mazo clicable y las cartas repartidas sobre el tablero.

signal deck_clicked
signal card_clicked(card: ChampionData)
signal card_released(card: ChampionData, screen_pos: Vector2)

const COLS := 6
const SPACING_X := 1.22
const SPACING_Z := 1.8
const HOVER_Y := 0.9

var deck_node: Node3D
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
	var label := Label3D.new()
	label.text = "Mazo del demiurgo\n(pulsa para repartir)"
	label.font_size = 40
	label.pixel_size = 0.0035
	label.outline_size = 10
	label.font = GameTheme.bold_font
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.45, 1.45, 0)
	label.name = "DeckLabel"
	deck_node.add_child(label)
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


func set_deck_label(text: String) -> void:
	(deck_node.get_node("DeckLabel") as Label3D).text = text


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
		c.pressed.connect(func() -> void: card_clicked.emit(card))
		c.released.connect(func(screen_pos: Vector2) -> void: card_released.emit(card, screen_pos))
		cards.append(c)
		var target := slot_position(i, pool.size())
		var tw := create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(c, "position", target, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_callback(c.flip.bind(0.35))
		last = tw
		i += 1
	if last != null:
		await last.finished
		await get_tree().create_timer(0.4).timeout


## La carta vuela hacia el fondo (la toma una IA) o hacia la cámara (la tomas tú).
func take(card: ChampionData, by_human: bool) -> void:
	var c := find_card(card)
	if c == null:
		return
	cards.erase(c)
	var target := Vector3(c.position.x, 2.5, -3.5) if by_human else Vector3(c.position.x, 2.2, 7.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "scale", Vector3(0.2, 0.2, 0.2), 0.45)
	tw.chain().tween_callback(c.queue_free)
	await tw.finished


## Primera carta 3D de la mesa con esos datos (prefiere la seleccionada).
func find_card(card: ChampionData) -> Card3D:
	var found: Card3D = null
	for c in cards:
		if c.card == card:
			if c.is_selected():
				return c
			if found == null:
				found = c
	return found


func select(card: ChampionData) -> void:
	var first := true
	for c in cards:
		var sel := c.card == card and first
		if sel:
			first = false
		c.set_selected(sel)


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
	for i in _sigils.size():
		_sigils[i].rotation.y += delta * (0.25 if i % 2 == 0 else -0.18)
	for i in _flames.size():
		_flames[i].light_energy = 1.6 + sin(_time * 9.0 + i * 1.7) * 0.35 + sin(_time * 23.0 + i) * 0.15


static func _sigil_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/icons/rune_ring.svg")
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _sigil(pos: Vector3, size: float, color: Color) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	m.mesh = q
	m.rotation_degrees.x = -90
	m.material_override = _sigil_material(color)
	pivot.add_child(m)
	deco.add_child(pivot)
	_sigils.append(pivot)
	return pivot


func _brazier(pos: Vector3) -> void:
	var base := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.3
	cyl.height = 0.9
	base.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_color = Color(0.2, 0.16, 0.12)
	bm.metallic = 0.5
	bm.roughness = 0.5
	base.material_override = bm
	base.position = pos + Vector3(0, 0.45, 0)
	deco.add_child(base)
	var bowl := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.42
	bc.bottom_radius = 0.2
	bc.height = 0.28
	bowl.mesh = bc
	var bwm := StandardMaterial3D.new()
	bwm.albedo_color = Color(0.55, 0.42, 0.18)
	bwm.metallic = 0.7
	bwm.roughness = 0.35
	bowl.material_override = bwm
	bowl.position = pos + Vector3(0, 1.0, 0)
	deco.add_child(bowl)
	var fire := CPUParticles3D.new()
	fire.position = pos + Vector3(0, 1.1, 0)
	fire.amount = 36
	fire.lifetime = 0.9
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.2
	fire.direction = Vector3.UP
	fire.spread = 12
	fire.initial_velocity_min = 1.2
	fire.initial_velocity_max = 2.2
	fire.gravity = Vector3(0, 1.5, 0)
	fire.scale_amount_min = 0.12
	fire.scale_amount_max = 0.3
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1))
	sc.add_point(Vector2(1, 0))
	fire.scale_amount_curve = sc
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1, 0.6, 0.2)
	fm.emission_enabled = true
	fm.emission = Color(1, 0.5, 0.1)
	fm.emission_energy_multiplier = 2.5
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = fm
	fire.mesh = mesh
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.95, 0.6, 1))
	ramp.add_point(0.4, Color(1, 0.5, 0.1, 0.9))
	ramp.set_color(1, Color(0.6, 0.1, 0.05, 0))
	fire.color_ramp = ramp
	deco.add_child(fire)
	fire.emitting = true
	var light := OmniLight3D.new()
	light.position = pos + Vector3(0, 1.6, 0)
	light.light_color = Color(1, 0.7, 0.35)
	light.light_energy = 1.6
	light.omni_range = 6.0
	light.shadow_enabled = false
	deco.add_child(light)
	_flames.append(light)


func _build_deco() -> void:
	deco = Node3D.new()
	add_child(deco)
	# Sello arcano bajo las cartas y dos sellos menores a los lados.
	_sigil(Vector3(-1.85, 0.02, 1.0), 7.2, Color(0.85, 0.7, 0.32, 0.55))
	_sigil(Vector3(2.75, 0.03, -1.3), 2.0, Color(0.6, 0.75, 1.0, 0.7))
	_sigil(Vector3(-6.4, 0.03, -1.3), 2.0, Color(0.6, 0.75, 1.0, 0.7))
	_brazier(Vector3(3.5, 0, 3.6))
	_brazier(Vector3(-7.2, 0, 3.6))
	# Motas de luz que flotan sobre la mesa.
	var motes := CPUParticles3D.new()
	motes.position = Vector3(-1.85, 1.0, 1.0)
	motes.amount = 90
	motes.lifetime = 6.0
	motes.preprocess = 6.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(5.5, 0.6, 3.5)
	motes.direction = Vector3.UP
	motes.spread = 60
	motes.initial_velocity_min = 0.08
	motes.initial_velocity_max = 0.25
	motes.gravity = Vector3(0, 0.03, 0)
	motes.scale_amount_min = 0.025
	motes.scale_amount_max = 0.06
	var mm := SphereMesh.new()
	mm.radius = 0.5
	mm.height = 1.0
	mm.radial_segments = 6
	mm.rings = 3
	var mmat := StandardMaterial3D.new()
	mmat.albedo_color = Color(1, 0.9, 0.6)
	mmat.emission_enabled = true
	mmat.emission = Color(1, 0.85, 0.5)
	mmat.emission_energy_multiplier = 2.0
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.material = mmat
	motes.mesh = mm
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	ramp.set_color(1, Color(1, 1, 1, 0))
	motes.color_ramp = ramp
	deco.add_child(motes)
	motes.emitting = true
