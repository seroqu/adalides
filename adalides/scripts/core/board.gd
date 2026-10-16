class_name Board
extends RefCounted
## Los dos tableros de batalla (3 filas × 5 columnas cada uno) unidos en una
## cuadrícula de 6 × 5. El lado 0 ocupa y = 0..2 (su fila 1, el frente, es y = 2);
## el lado 1 ocupa y = 3..5 (su frente es y = 3). SUPUESTO: las filas 1 se enfrentan.
## Distancia = pasos ortogonales (Manhattan). "Casilla opuesta" = espejo en el otro lado.

const ROWS := Rules.BOARD_ROWS
const COLS := Rules.BOARD_COLS

var cells: Dictionary = {} # Vector2i(x, y) → Champion
var owners: Array[Adalid] = []


func _init(a: Adalid, b: Adalid) -> void:
	owners = [a, b]


# ---------------------------------------------------------------- coordenadas

## Posición en la cuadrícula a partir de lado, fila (1 = frente) y columna (0..4).
static func pos_from(side: int, row: int, col: int) -> Vector2i:
	var y := (ROWS - row) if side == 0 else (ROWS - 1 + row)
	return Vector2i(col, y)


static func side_of(pos: Vector2i) -> int:
	return 0 if pos.y < ROWS else 1


## Fila 1..3 desde el frente.
static func row_of(pos: Vector2i) -> int:
	return (ROWS - pos.y) if pos.y < ROWS else (pos.y - ROWS + 1)


static func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < COLS and pos.y >= 0 and pos.y < 2 * ROWS


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func is_diagonal(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) == 1 and absi(a.y - b.y) == 1


## Espejo en el lado contrario (misma fila desde el frente, misma columna).
static func opposite(pos: Vector2i) -> Vector2i:
	return Vector2i(pos.x, 2 * ROWS - 1 - pos.y)


## Casilla 1..15 de un lado (orden: fila 1 de izquierda a derecha, luego fila 2...).
static func cell_index(pos: Vector2i) -> int:
	return (row_of(pos) - 1) * COLS + pos.x + 1


static func pos_from_cell(side: int, index: int) -> Vector2i:
	var i := index - 1
	return pos_from(side, i / COLS + 1, i % COLS)


## "Hacia atrás" para un lado: alejarse del frente.
static func backward(side: int) -> Vector2i:
	return Vector2i(0, -1) if side == 0 else Vector2i(0, 1)


# ---------------------------------------------------------------- contenido

func place(ch: Champion, pos: Vector2i) -> void:
	cells[pos] = ch
	ch.side = side_of(pos)


func remove(ch: Champion) -> void:
	var pos := pos_of(ch)
	if pos.x >= 0:
		cells.erase(pos)


func at(pos: Vector2i) -> Champion:
	return cells.get(pos, null)


func is_free(pos: Vector2i) -> bool:
	return in_bounds(pos) and not cells.has(pos)


func pos_of(ch: Champion) -> Vector2i:
	for pos in cells:
		if cells[pos] == ch:
			return pos
	return Vector2i(-1, -1)


func move(ch: Champion, to: Vector2i) -> bool:
	if not is_free(to):
		return false
	cells.erase(pos_of(ch))
	cells[to] = ch
	return true


func champions(side: int, only_alive := true) -> Array[Champion]:
	var out: Array[Champion] = []
	for pos in cells:
		var ch: Champion = cells[pos]
		if ch.side == side and (ch.alive or not only_alive):
			out.append(ch)
	return out


func alive_count(side: int) -> int:
	return champions(side).size()


func within(pos: Vector2i, dist: int, side := -1) -> Array[Champion]:
	var out: Array[Champion] = []
	for other in cells:
		if distance(pos, other) <= dist and (side < 0 or cells[other].side == side) and cells[other].alive:
			out.append(cells[other])
	return out


func in_column(x: int, side: int) -> Array[Champion]:
	var out: Array[Champion] = []
	for pos in cells:
		if pos.x == x and cells[pos].side == side and cells[pos].alive:
			out.append(cells[pos])
	return out


func in_row(row: int, side: int) -> Array[Champion]:
	var out: Array[Champion] = []
	for pos in cells:
		if cells[pos].side == side and row_of(pos) == row and cells[pos].alive:
			out.append(cells[pos])
	return out


## Retira a los muertos no sepultados y los devuelve.
func clear_dead() -> Array[Champion]:
	var removed: Array[Champion] = []
	for pos in cells.keys():
		var ch: Champion = cells[pos]
		if not ch.alive and not ch.buried:
			removed.append(ch)
			cells.erase(pos)
	return removed


func describe(side: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	for row in range(1, ROWS + 1):
		var parts: PackedStringArray = []
		for col in COLS:
			var ch := at(pos_from(side, row, col))
			parts.append("·" if ch == null else ch.label())
		lines.append("F%d: %s" % [row, " | ".join(parts)])
	return lines
