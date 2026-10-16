class_name DraftTable
extends Node3D
## Mesa del draft: un mazo clicable y las cartas repartidas sobre el tablero.

signal deck_clicked
signal card_clicked(card: ChampionData)

const COLS := 6
const SPACING_X := 0.82
const SPACING_Z := 1.25
const HOVER_Y := 0.9

var deck_node: Node3D
var cards: Dictionary = {} # ChampionData → Card3D
var dealt: bool = false
var deck_pos := Vector3(-1.9, 0.0, -0.7)


func _ready() -> void:
	deck_node = Node3D.new()
	deck_node.position = deck_pos
	add_child(deck_node)
	for i in 6:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(Card3D.W, 0.03, Card3D.H)
		m.mesh = b
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.12, 0.1, 0.2) if i < 5 else Color(0.2, 0.17, 0.3)
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.65, 0.2) * 0.12
		m.material_override = mat
		m.position = Vector3(0.01 * i, 0.03 * i, -0.01 * i)
		deck_node.add_child(m)
	var label := Label3D.new()
	label.text = "Mazo del demiurgo\n(pulsa para repartir)"
	label.font_size = 40
	label.pixel_size = 0.0035
	label.outline_size = 10
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0.75, 0)
	label.name = "DeckLabel"
	deck_node.add_child(label)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(Card3D.W + 0.2, 0.4, Card3D.H + 0.2)
	shape.shape = cs
	body.add_child(shape)
	body.position.y = 0.1
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
	var z := 2.9 + ((rows - 1) / 2.0 - row) * SPACING_Z
	return Vector3(x, HOVER_Y, z)


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
		add_child(c)
		c.pressed.connect(func() -> void: card_clicked.emit(card))
		cards[card] = c
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
	if not cards.has(card):
		return
	var c: Card3D = cards[card]
	cards.erase(card)
	var target := Vector3(c.position.x, 2.5, -2.5) if by_human else Vector3(c.position.x, 2.2, 7.5)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "position", target, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "scale", Vector3(0.2, 0.2, 0.2), 0.45)
	tw.chain().tween_callback(c.queue_free)
	await tw.finished


func select(card: ChampionData) -> void:
	for other in cards:
		cards[other].set_selected(other == card)


func dim_unavailable(available: Callable) -> void:
	for card in cards:
		cards[card].set_dim(not available.call(card))


func clear() -> void:
	for card in cards:
		cards[card].queue_free()
	cards.clear()
	dealt = false
