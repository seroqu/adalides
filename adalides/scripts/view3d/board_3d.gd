class_name Board3D
extends Node3D
## Tablero de batalla en 3D: 6 filas × 5 columnas de casillas clicables.
## El lado 0 (y = 0..2) es el del jugador y queda cerca de la cámara.
## `tile_clicked(pos)` da la posición de cuadrícula (Vector2i(x, y)).

signal tile_clicked(pos: Vector2i)

const TILE := 1.1

var tiles: Dictionary = {} # Vector2i → MeshInstance3D
var bodies: Dictionary = {} # StaticBody3D → Vector2i (para el raycast del arrastre)
var pieces: Dictionary = {} # Champion → ChampionPiece
var highlighted: Array[Vector2i] = []
var tiles_root: Node3D # Las casillas y la línea central (se ocultan en el mercado).
var deco: Node3D
var _sigils: Array[Node3D] = []
var _flames: Array[OmniLight3D] = []
var _time: float = 0.0
var _side_roots: Array[Node3D] = [] # Casillas de cada lado, para mostrar solo el tuyo.


func _ready() -> void:
	tiles_root = Node3D.new()
	add_child(tiles_root)
	for side in 2:
		var r := Node3D.new()
		tiles_root.add_child(r)
		_side_roots.append(r)
	for y in 2 * Rules.BOARD_ROWS:
		for x in Rules.BOARD_COLS:
			_make_tile(Vector2i(x, y))
	_build_deco()
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, 30, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)
	var ambient := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.04, 0.03, 0.09)
	sky_mat.sky_horizon_color = Color(0.22, 0.1, 0.3)
	sky_mat.ground_bottom_color = Color(0.03, 0.02, 0.05)
	sky_mat.ground_horizon_color = Color(0.2, 0.08, 0.25)
	sky_mat.sun_angle_max = 10
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.65)
	env.ambient_light_energy = 1.2
	# Luz de relleno desde la cámara para que los modelos no queden a contraluz.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-35, 180, 0)
	fill.light_energy = 0.6
	fill.light_color = Color(0.9, 0.9, 1.0)
	add_child(fill)
	env.glow_enabled = true
	env.glow_intensity = 0.4
	env.glow_bloom = 0.1
	ambient.environment = env
	add_child(ambient)
	# Mesa bajo el tablero.
	var table := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(Rules.BOARD_COLS * TILE + 5.6, 0.2, 2 * Rules.BOARD_ROWS * TILE + 3.2)
	table.mesh = tm
	var tmat := ShaderMaterial.new()
	tmat.shader = preload("res://assets/shaders/table.gdshader")
	table.material_override = tmat
	table.position = Vector3(world_x(2), -0.16, (world_z(0) + world_z(5)) / 2.0)
	add_child(table)
	var rim := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(Rules.BOARD_COLS * TILE + 0.5, 0.06, 2 * Rules.BOARD_ROWS * TILE + 0.5)
	rim.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(0.5, 0.4, 0.18)
	rmat.metallic = 0.6
	rmat.roughness = 0.4
	rim.material_override = rmat
	rim.position = Vector3(world_x(2), -0.06, (world_z(0) + world_z(5)) / 2.0)
	add_child(rim)
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
	tiles_root.add_child(bar)


## La cámara mira hacia +Z, así que +X queda a la izquierda en pantalla;
## se invierte para que la columna 0 se vea a la izquierda.
static func world_x(x: int) -> float:
	return -x * TILE


static func world_z(y: int) -> float:
	return y * TILE


static func world_pos(pos: Vector2i) -> Vector3:
	return Vector3(world_x(pos.x), 0, world_z(pos.y))


static var _tile_shader: Shader = preload("res://assets/shaders/tile.gdshader")


func _make_tile(pos: Vector2i) -> void:
	var body := StaticBody3D.new()
	body.position = world_pos(pos)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(TILE, 0.2, TILE)
	shape.shape = box
	body.add_child(shape)
	# Base oscura y, encima, la cara con el shader.
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(TILE - 0.06, 0.1, TILE - 0.06)
	base.mesh = bm
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.05, 0.05, 0.08)
	bmat.roughness = 0.8
	base.material_override = bmat
	body.add_child(base)
	var mesh := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(TILE - 0.06, TILE - 0.06)
	mesh.mesh = pm
	mesh.position.y = 0.051
	mesh.material_override = _tile_material(pos)
	body.add_child(mesh)
	body.input_event.connect(func(_cam: Node, event: InputEvent, _p: Vector3, _n: Vector3, _i: int) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tile_clicked.emit(pos))
	_side_roots[Board.side_of(pos)].add_child(body)
	tiles[pos] = mesh
	bodies[body] = pos


func _tile_material(pos: Vector2i) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _tile_shader
	var side := Board.side_of(pos)
	var front := Board.row_of(pos) == 1
	var base := Color(0.14, 0.2, 0.36) if side == 0 else Color(0.36, 0.13, 0.16)
	if front:
		base = base.lightened(0.18)
	mat.set_shader_parameter("base_color", base)
	mat.set_shader_parameter("edge_color", Color(0.35, 0.6, 1.0) if side == 0 else Color(1.0, 0.4, 0.4))
	mat.set_shader_parameter("seed", float(pos.x * 7 + pos.y * 13) * 0.37)
	return mat


func _set_tile_param(pos: Vector2i, param: String, value: float) -> void:
	if tiles.has(pos):
		(tiles[pos].material_override as ShaderMaterial).set_shader_parameter(param, value)


func highlight_tiles(positions: Array[Vector2i]) -> void:
	for pos in highlighted:
		_set_tile_param(pos, "highlight", 0.0)
	highlighted = positions.duplicate()
	for pos in highlighted:
		_set_tile_param(pos, "highlight", 1.0)


var hovered := Vector2i(-1, -1)


## Casilla bajo el cursor durante un arrastre (dorada); (-1, -1) la quita.
func hover_tile(pos: Vector2i) -> void:
	if pos == hovered:
		return
	if hovered.x >= 0:
		_set_tile_param(hovered, "hover", 0.0)
	hovered = pos
	if hovered.x >= 0:
		_set_tile_param(hovered, "hover", 1.0)


func set_mat_visible(v: bool) -> void:
	tiles_root.visible = v
	deco.visible = v


## En la alineación solo se muestra tu mitad del campo.
func set_enemy_side_visible(v: bool) -> void:
	_side_roots[1].visible = v


func _process(delta: float) -> void:
	if not deco.visible:
		return
	_time += delta
	Deco.animate(_sigils, _flames, _time, delta)


func _build_deco() -> void:
	deco = Node3D.new()
	add_child(deco)
	var cx := world_x(2)
	var cz := (world_z(0) + world_z(5)) / 2.0
	# Sello bajo todo el campo y sellos de cada bando fuera de la cuadrícula.
	_sigils.append(Deco.sigil(deco, Vector3(cx, -0.055, cz), 10.5, Color(0.85, 0.7, 0.32, 0.4)))
	_sigils.append(Deco.sigil(deco, Vector3(cx + 4.4, 0.0, world_z(1)), 1.6, Color(0.4, 0.65, 1.0, 0.7)))
	_sigils.append(Deco.sigil(deco, Vector3(cx - 4.4, 0.0, world_z(1)), 1.6, Color(0.4, 0.65, 1.0, 0.7)))
	_sigils.append(Deco.sigil(deco, Vector3(cx + 4.4, 0.0, world_z(4)), 1.6, Color(1.0, 0.45, 0.4, 0.7)))
	_sigils.append(Deco.sigil(deco, Vector3(cx - 4.4, 0.0, world_z(4)), 1.6, Color(1.0, 0.45, 0.4, 0.7)))
	# Braseros en las cuatro esquinas de la mesa.
	for dx in [-4.6, 4.6]:
		for dz in [-1.0, 1.0]:
			_flames.append(Deco.brazier(deco, Vector3(cx + dx, 0, cz + dz * 4.3)))
	Deco.motes(deco, Vector3(cx, 1.0, cz), Vector3(3.5, 0.6, 4.0), Color(1, 0.9, 0.6), 60)
	# Franjas de luz en los bordes de cada mitad.
	for side in 2:
		var strip := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(Rules.BOARD_COLS * TILE + 0.3, 0.04, 0.1)
		strip.mesh = bm
		var c := Color(0.35, 0.6, 1.0) if side == 0 else Color(1.0, 0.4, 0.4)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.emission_enabled = true
		mat.emission = c * 0.8
		strip.material_override = mat
		strip.position = Vector3(cx, 0.02, world_z(0) - 0.65 if side == 0 else world_z(5) + 0.65)
		deco.add_child(strip)


func piece_of(ch: Champion) -> ChampionPiece:
	return pieces.get(ch, null)


func clear_pieces() -> void:
	for ch in pieces:
		pieces[ch].queue_free()
	pieces.clear()


## Sincroniza las fichas con un diccionario { Vector2i(x, y) grid : Champion }.
## `facing_camera`: las fichas miran al jugador (alineación). `keep`: las que
## sobran se ocultan en vez de borrarse (así recolocar no vuelve a cargar modelos).
func sync(cells: Dictionary, animate := true, facing_camera := false, keep := false) -> void:
	var present := {}
	for pos in cells:
		var ch: Champion = cells[pos]
		present[ch] = true
		var target := world_pos(pos)
		if pieces.has(ch):
			var piece: ChampionPiece = pieces[ch]
			piece.refresh()
			var was_hidden := not piece.visible
			piece.visible = true
			if animate and not was_hidden and piece.position.distance_to(target) > 0.01:
				var tw := create_tween()
				tw.tween_property(piece, "position", target, 0.35).set_trans(Tween.TRANS_SINE)
			elif not animate or was_hidden:
				piece.position = target
				if was_hidden:
					piece.spawn_in()
			piece.set_facing_camera(facing_camera, animate)
		else:
			var piece := ChampionPiece.new()
			piece.position = target
			add_child(piece)
			piece.setup(ch, ch.side if ch.side >= 0 else Board.side_of(pos))
			piece.set_facing_camera(facing_camera, false)
			if animate:
				piece.spawn_in()
			pieces[ch] = piece
	for ch in pieces.keys():
		if not present.has(ch):
			var piece: ChampionPiece = pieces[ch]
			if keep:
				piece.visible = false
				continue
			pieces.erase(ch)
			if animate:
				var tw := create_tween()
				tw.tween_property(piece, "scale", Vector3(0.05, 0.05, 0.05), 0.4)
				tw.tween_callback(piece.queue_free)
			else:
				piece.queue_free()


## Quita las fichas ocultas que dejó `sync(..., keep = true)`.
func drop_hidden() -> void:
	for ch in pieces.keys():
		var piece: ChampionPiece = pieces[ch]
		if not piece.visible:
			pieces.erase(ch)
			piece.queue_free()


## Convierte una alineación { Vector2i(col, fila): Champion } del lado `side` a celdas de cuadrícula.
static func lineup_to_cells(lineup: Dictionary, side: int) -> Dictionary:
	var cells := {}
	for key in lineup:
		var ch: Champion = lineup[key]
		ch.side = side
		cells[Board.pos_from(side, key.y, key.x)] = ch
	return cells
