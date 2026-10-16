class_name Board3D
extends Node3D
## Tablero de batalla en 3D: 6 filas × 5 columnas de casillas clicables.
## El lado 0 (y = 0..2) es el del jugador y queda cerca de la cámara.
## `tile_clicked(pos)` da la posición de cuadrícula (Vector2i(x, y)).

signal tile_clicked(pos: Vector2i)

const TILE := 1.1

var tiles: Dictionary = {} # Vector2i → MeshInstance3D
var pieces: Dictionary = {} # Champion → ChampionPiece
var highlighted: Array[Vector2i] = []


func _ready() -> void:
	for y in 2 * Rules.BOARD_ROWS:
		for x in Rules.BOARD_COLS:
			_make_tile(Vector2i(x, y))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)
	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.06, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.5, 0.6)
	env.ambient_light_energy = 0.8
	ambient.environment = env
	add_child(ambient)
	# Separador entre los dos tableros.
	var bar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(Rules.BOARD_COLS * TILE + 0.3, 0.05, 0.08)
	bar.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.8, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.8, 0.3) * 0.5
	bar.material_override = mat
	bar.position = Vector3(world_x(2), 0.03, (world_z(2) + world_z(3)) / 2.0)
	add_child(bar)


## La cámara mira hacia +Z, así que +X queda a la izquierda en pantalla;
## se invierte para que la columna 0 se vea a la izquierda.
static func world_x(x: int) -> float:
	return -x * TILE


static func world_z(y: int) -> float:
	return y * TILE


static func world_pos(pos: Vector2i) -> Vector3:
	return Vector3(world_x(pos.x), 0, world_z(pos.y))


func _make_tile(pos: Vector2i) -> void:
	var body := StaticBody3D.new()
	body.position = world_pos(pos)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TILE, 0.2, TILE)
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(TILE - 0.08, 0.1, TILE - 0.08)
	mesh.mesh = bm
	mesh.material_override = _tile_material(pos, false)
	body.add_child(mesh)
	body.input_event.connect(func(_cam: Node, event: InputEvent, _p: Vector3, _n: Vector3, _i: int) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tile_clicked.emit(pos))
	add_child(body)
	tiles[pos] = mesh


func _tile_material(pos: Vector2i, highlight: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var side := Board.side_of(pos)
	var front := Board.row_of(pos) == 1
	var base := Color(0.16, 0.22, 0.36) if side == 0 else Color(0.36, 0.16, 0.18)
	if front:
		base = base.lightened(0.15)
	if highlight:
		base = Color(0.3, 0.7, 0.4)
		mat.emission_enabled = true
		mat.emission = base * 0.5
	mat.albedo_color = base
	return mat


func highlight_tiles(positions: Array[Vector2i]) -> void:
	for pos in highlighted:
		tiles[pos].material_override = _tile_material(pos, false)
	highlighted = positions.duplicate()
	for pos in highlighted:
		tiles[pos].material_override = _tile_material(pos, true)


func clear_pieces() -> void:
	for ch in pieces:
		pieces[ch].queue_free()
	pieces.clear()


## Sincroniza las fichas con un diccionario { Vector2i(x, y) grid : Champion }.
func sync(cells: Dictionary, animate := true) -> void:
	var keep := {}
	for pos in cells:
		var ch: Champion = cells[pos]
		keep[ch] = true
		var target := world_pos(pos)
		if pieces.has(ch):
			var piece: ChampionPiece = pieces[ch]
			piece.refresh()
			if animate and piece.position.distance_to(target) > 0.01:
				var tw := create_tween()
				tw.tween_property(piece, "position", target, 0.35).set_trans(Tween.TRANS_SINE)
			elif not animate:
				piece.position = target
		else:
			var piece := ChampionPiece.new()
			piece.position = target
			add_child(piece)
			piece.setup(ch, ch.side if ch.side >= 0 else Board.side_of(pos))
			pieces[ch] = piece
	for ch in pieces.keys():
		if not keep.has(ch):
			var piece: ChampionPiece = pieces[ch]
			pieces.erase(ch)
			if animate:
				var tw := create_tween()
				tw.tween_property(piece, "scale", Vector3(0.05, 0.05, 0.05), 0.4)
				tw.tween_callback(piece.queue_free)
			else:
				piece.queue_free()


## Convierte una alineación { Vector2i(col, fila): Champion } del lado `side` a celdas de cuadrícula.
static func lineup_to_cells(lineup: Dictionary, side: int) -> Dictionary:
	var cells := {}
	for key in lineup:
		var ch: Champion = lineup[key]
		ch.side = side
		cells[Board.pos_from(side, key.y, key.x)] = ch
	return cells
