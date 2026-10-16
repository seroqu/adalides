class_name Card3D
extends Node3D
## Carta 3D del draft y del mercado: una placa con dorso ilustrado y, en la
## cara, marco del color del elemento, nombre, retrato (icono del arquetipo),
## elemento, coste, poder y ataque/vida. Clicable. Se reparte boca abajo y se
## voltea con `flip()`.

signal pressed
signal released(screen_pos: Vector2)

const W := 1.1
const H := 1.55
const TEX_W := 512.0 # Tamaño de las texturas card_frame / card_back.
const PX := W / TEX_W # Unidades por píxel de textura.
const TEXT_PX := 0.0021 # Unidades por píxel de los Label3D.

var card: ChampionData
var face_up: bool = false
var _plate: MeshInstance3D
var _face: Node3D
var _frame: Sprite3D
var _glow: MeshInstance3D
var _hover_tw: Tween
var _select_tw: Tween
var home := Vector3.ZERO # Sitio en la mesa al que vuelve si se suelta fuera.
var home_rot := Vector3.ZERO
var dragging: bool = false
var selected: bool = false


## Convierte coordenadas de la textura (0..512, 0..720) a posición local sobre la cara.
static func tex_pos(px: float, py: float) -> Vector3:
	return Vector3((TEX_W / 2.0 - px) * PX, 0, (360.0 - py) * PX)


static func flat_sprite(tex: Texture2D, pixel_size: float, pos: Vector3, priority: int) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = tex
	s.pixel_size = pixel_size
	s.rotation_degrees = Vector3(-90, 180, 0)
	s.position = pos
	s.shaded = false
	s.render_priority = priority
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return s


static func flat_label(text: String, size: int, color: Color, pos: Vector3, priority: int, width := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = TEXT_PX
	l.outline_size = int(size * 0.22)
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.modulate = color
	l.rotation_degrees = Vector3(-90, 180, 0)
	l.position = pos
	l.render_priority = priority
	l.font = GameTheme.bold_font
	if width > 0.0:
		l.width = width
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l


## Dorso ilustrado mirando hacia -Y (se usa también en el mazo).
static func back_sprite() -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = Icons.card_back()
	s.pixel_size = PX
	s.rotation_degrees = Vector3(90, 0, 0)
	s.shaded = false
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return s


func setup(p_card: ChampionData) -> void:
	card = p_card
	var color := Icons.color_of(card)
	_plate = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(W, 0.03, H)
	_plate.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.09, 0.08, 0.13)
	mat.roughness = 0.6
	_plate.material_override = mat
	add_child(_plate)
	var back := back_sprite()
	back.position.y = -0.016
	add_child(back)
	# Cara: marco teñido del color del elemento y contenido plano encima.
	_face = Node3D.new()
	_face.position.y = 0.016
	add_child(_face)
	_frame = flat_sprite(Icons.card_frame(), PX, Vector3.ZERO, 0)
	_frame.modulate = color
	_face.add_child(_frame)
	# Nombre en la banda superior.
	var name_label := flat_label(card.display_name, 46, Color.WHITE, tex_pos(256, 78), 3, 430)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face.add_child(name_label)
	# Retrato: icono grande del arquetipo (y el segundo, en los héroes).
	var arch := flat_sprite(Icons.archetype(card.archetype), 0.0023, tex_pos(256, 305) + Vector3(0, 0.002, 0), 2)
	arch.modulate = color.lightened(0.15)
	_face.add_child(arch)
	if card.second_archetype >= 0:
		arch.position = tex_pos(200, 305) + Vector3(0, 0.002, 0)
		arch.pixel_size = 0.0018
		var arch2 := flat_sprite(Icons.archetype(card.second_archetype), 0.0018, tex_pos(330, 305) + Vector3(0, 0.002, 0), 2)
		arch2.modulate = color.lightened(0.15)
		_face.add_child(arch2)
	# Elemento (abajo a la izquierda del retrato) y coste (abajo a la derecha).
	if card.element >= 0:
		var elem := flat_sprite(Icons.element(card.element), 0.00095, tex_pos(100, 418) + Vector3(0, 0.004, 0), 4)
		elem.modulate = Color.WHITE
		_face.add_child(elem)
	else:
		_face.add_child(flat_label("★ Héroe", 30, Icons.HERO_COLOR, tex_pos(118, 420), 4))
	_face.add_child(flat_label("◆ %d" % card.cost, 40, Color(0.62, 0.8, 1.0), tex_pos(408, 420), 4))
	# Banda inferior: poder y ataque / vida.
	var power := flat_label(String(card.power.get("name", "")), 30, Color(1.0, 0.88, 0.6), tex_pos(256, 616), 3, 420)
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face.add_child(power)
	_face.add_child(flat_label("⚔ %d" % card.attack, 44, Color(1, 0.55, 0.45), tex_pos(118, 664), 3))
	_face.add_child(flat_label("♥ %d" % card.defense, 44, Color(0.55, 0.9, 0.55), tex_pos(394, 664), 3))
	_face.visible = false
	# Brillo de selección.
	_glow = MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(W + 0.12, 0.01, H + 0.12)
	_glow.mesh = gb
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.4, 1.0, 0.5)
	gmat.emission_enabled = true
	gmat.emission = Color(0.4, 1.0, 0.5)
	_glow.material_override = gmat
	_glow.position.y = -0.03
	_glow.visible = false
	add_child(_glow)
	# Clic.
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(W, 0.12, H)
	shape.shape = cs
	body.add_child(shape)
	body.input_event.connect(func(_c: Node, event: InputEvent, _p: Vector3, _n: Vector3, _i: int) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pressed.emit()
			else:
				released.emit(event.position))
	body.mouse_entered.connect(func() -> void: _hover(true))
	body.mouse_exited.connect(func() -> void: _hover(false))
	add_child(body)
	rotation_degrees.z = 180 # Boca abajo.


func _hover(on: bool) -> void:
	if not face_up or dragging or selected:
		return
	if _hover_tw != null and _hover_tw.is_valid():
		_hover_tw.kill()
	_hover_tw = create_tween()
	_hover_tw.tween_property(self, "scale", Vector3.ONE * (1.12 if on else 1.0), 0.12).set_trans(Tween.TRANS_SINE)


## Seleccionada: se eleva, crece y flota con un brillo que late.
func set_selected(v: bool) -> void:
	if v == selected:
		return
	selected = v
	_glow.visible = v
	if _select_tw != null and _select_tw.is_valid():
		_select_tw.kill()
	if _hover_tw != null and _hover_tw.is_valid():
		_hover_tw.kill()
	if dragging:
		return
	_select_tw = create_tween()
	if v:
		_select_tw.set_parallel(true)
		_select_tw.tween_property(self, "scale", Vector3.ONE * 1.18, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_select_tw.tween_property(self, "position:y", home.y + 0.35, 0.18).set_trans(Tween.TRANS_SINE)
		_select_tw.tween_property(self, "rotation_degrees:z", 0.0, 0.18)
		_select_tw.chain().tween_callback(_float_loop)
	else:
		_select_tw.set_parallel(true)
		_select_tw.tween_property(self, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_SINE)
		_select_tw.tween_property(self, "position", home, 0.2).set_trans(Tween.TRANS_SINE)
		_select_tw.tween_property(self, "rotation_degrees", home_rot, 0.2).set_trans(Tween.TRANS_SINE)


func _float_loop() -> void:
	if not selected or dragging:
		return
	_select_tw = create_tween()
	_select_tw.set_loops()
	_select_tw.set_parallel(true)
	_select_tw.tween_property(self, "position:y", home.y + 0.5, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_select_tw.tween_property(self, "rotation_degrees:y", 4.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_select_tw.tween_property(_glow, "scale", Vector3(1.08, 1, 1.06), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_select_tw.chain().tween_property(self, "position:y", home.y + 0.35, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_select_tw.parallel().tween_property(self, "rotation_degrees:y", -4.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_select_tw.parallel().tween_property(_glow, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func is_selected() -> bool:
	return selected


## Empieza a seguir al ratón: se endereza, crece y pierde su inclinación.
func begin_drag() -> void:
	dragging = true
	for tw in [_select_tw, _hover_tw]:
		if tw != null and tw.is_valid():
			tw.kill()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 1.25, 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "rotation_degrees", Vector3(-50, 0, 0), 0.15).set_trans(Tween.TRANS_SINE)


## Sitúa la carta bajo el cursor (punto del plano de arrastre), con un leve balanceo.
func follow(point: Vector3) -> void:
	var delta := point - position
	position = position.lerp(point, 0.55)
	rotation_degrees.z = clampf(-delta.x * 25.0, -18.0, 18.0)
	rotation_degrees.x = -50.0 + clampf(delta.z * 20.0, -12.0, 12.0)


## Vuelve volando a su sitio en la mesa.
func return_home() -> void:
	dragging = false
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "position", home, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "rotation_degrees", home_rot, 0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_SINE)
	if selected:
		tw.chain().tween_callback(func() -> void:
			selected = false
			set_selected(true))


func set_dim(v: bool) -> void:
	var color := Icons.color_of(card)
	_frame.modulate = color.darkened(0.6) if v else color
	var mat: StandardMaterial3D = _plate.material_override
	mat.albedo_color = Color(0.04, 0.04, 0.06) if v else Color(0.09, 0.08, 0.13)
	for c in _face.get_children():
		if c is Sprite3D and c != _frame:
			(c as Sprite3D).modulate.a = 0.45 if v else 1.0
		elif c is Label3D:
			(c as Label3D).modulate.a = 0.45 if v else 1.0


## Voltea la carta (boca arriba) con una pequeña elevación.
func flip(duration := 0.35) -> Tween:
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "rotation_degrees:z", 0.0, duration)
	tw.tween_property(self, "position:y", position.y + 0.4, duration / 2).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_property(self, "position:y", position.y, duration / 2).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func() -> void: face_up = true)
	# La cara se muestra a mitad del giro.
	get_tree().create_timer(duration / 2).timeout.connect(func() -> void: _face.visible = true)
	return tw
