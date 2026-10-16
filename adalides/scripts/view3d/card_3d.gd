class_name Card3D
extends Node3D
## Carta 3D para el draft: una placa con el dorso y, en la cara, icono de
## arquetipo, icono de elemento, nombre y stats. Clicable. Se reparte boca
## abajo y se voltea con `flip()`.

signal pressed
signal released(screen_pos: Vector2)

const W := 0.74
const H := 1.04

var card: ChampionData
var face_up: bool = false
var _plate: MeshInstance3D
var _face: Node3D
var _back: MeshInstance3D
var _glow: MeshInstance3D


func setup(p_card: ChampionData) -> void:
	card = p_card
	var color := Icons.color_of(card)
	_plate = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(W, 0.03, H)
	_plate.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.3)
	_plate.material_override = mat
	add_child(_plate)
	# Dorso: placa oscura con borde dorado, pegada debajo.
	_back = MeshInstance3D.new()
	var bb := BoxMesh.new()
	bb.size = Vector3(W - 0.08, 0.01, H - 0.08)
	_back.mesh = bb
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.12, 0.1, 0.2)
	bmat.emission_enabled = true
	bmat.emission = Color(0.8, 0.65, 0.2) * 0.15
	_back.material_override = bmat
	_back.position.y = -0.02
	add_child(_back)
	# Cara: contenido plano sobre la placa.
	_face = Node3D.new()
	_face.position.y = 0.02
	add_child(_face)
	var arch := Sprite3D.new()
	arch.texture = Icons.archetype(card.archetype)
	arch.pixel_size = 0.0034
	arch.rotation_degrees = Vector3(-90, 180, 0)
	arch.position = Vector3(0, 0, -0.14)
	arch.shaded = false
	arch.modulate = Color(0.06, 0.05, 0.1)
	_face.add_child(arch)
	if card.second_archetype >= 0:
		var arch2 := Sprite3D.new()
		arch2.texture = Icons.archetype(card.second_archetype)
		arch2.pixel_size = 0.0022
		arch2.rotation_degrees = Vector3(-90, 180, 0)
		arch2.position = Vector3(0.22, 0, -0.36)
		arch2.shaded = false
		_face.add_child(arch2)
	if card.element >= 0:
		var elem := Sprite3D.new()
		elem.texture = Icons.element(card.element)
		elem.modulate = Color(0.06, 0.05, 0.1)
		elem.pixel_size = 0.0018
		elem.rotation_degrees = Vector3(-90, 180, 0)
		elem.position = Vector3(-0.24, 0, -0.38)
		elem.shaded = false
		_face.add_child(elem)
	var name_label := Label3D.new()
	name_label.text = card.display_name.replace(" de ", "\nde ")
	name_label.font_size = 44
	name_label.pixel_size = 0.0032
	name_label.outline_size = 12
	name_label.outline_modulate = Color(0, 0, 0, 0.9)
	name_label.rotation_degrees = Vector3(-90, 180, 0)
	name_label.position = Vector3(0, 0, 0.22)
	_face.add_child(name_label)
	var stats := Label3D.new()
	stats.text = "⚔%d ♥%d ◆%d" % [card.attack, card.defense, card.cost]
	stats.font_size = 38
	stats.pixel_size = 0.0032
	stats.outline_size = 12
	stats.outline_modulate = Color(0, 0, 0, 0.9)
	stats.modulate = Color(1, 0.95, 0.7)
	stats.rotation_degrees = Vector3(-90, 180, 0)
	stats.position = Vector3(0, 0, 0.42)
	_face.add_child(stats)
	_face.visible = false
	# Brillo de selección.
	_glow = MeshInstance3D.new()
	var gb := BoxMesh.new()
	gb.size = Vector3(W + 0.1, 0.01, H + 0.1)
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


var _hover_tw: Tween


func _hover(on: bool) -> void:
	if not face_up:
		return
	if _hover_tw != null and _hover_tw.is_valid():
		_hover_tw.kill()
	_hover_tw = create_tween()
	_hover_tw.tween_property(self, "scale", Vector3.ONE * (1.15 if on else 1.0), 0.12).set_trans(Tween.TRANS_SINE)


func set_selected(v: bool) -> void:
	_glow.visible = v


func is_selected() -> bool:
	return _glow.visible


func set_dim(v: bool) -> void:
	var mat: StandardMaterial3D = _plate.material_override
	mat.albedo_color = Icons.color_of(card).darkened(0.75 if v else 0.3)


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
