class_name Schedule
extends RefCounted
## Tabla de batallas (PDF): cada columna es un ciclo; cada jugador pelea una vez.
## Para 4 y 6 jugadores se usan las tablas del PDF; para otros, un round-robin.

const TABLE_4 := [
	[[0, 1], [2, 3]],
	[[0, 2], [1, 3]],
	[[0, 3], [1, 2]],
]
const TABLE_6 := [
	[[0, 1], [2, 3], [4, 5]],
	[[0, 2], [1, 4], [3, 5]],
	[[0, 3], [1, 5], [2, 4]],
	[[0, 4], [1, 3], [2, 5]],
	[[0, 5], [1, 2], [3, 4]],
]


static func table_for(players: int) -> Array:
	match players:
		4: return TABLE_4
		6: return TABLE_6
	return _round_robin(players)


## Círculo de Berger: n (o n+1 con descanso) jugadores, n-1 columnas.
static func _round_robin(players: int) -> Array:
	var ids: Array = range(players)
	if players % 2 == 1:
		ids.append(-1) # descanso
	var n := ids.size()
	var table: Array = []
	for _round in n - 1:
		var column: Array = []
		for i in n / 2:
			var a: int = ids[i]
			var b: int = ids[n - 1 - i]
			if a >= 0 and b >= 0:
				column.append([a, b])
		table.append(column)
		var last = ids.pop_back()
		ids.insert(1, last)
	return table


## Parejas del ciclo `cycle` (1-based) filtrando eliminados. Los que quedan sin
## rival (por eliminaciones) se emparejan entre sí; SUPUESTO.
static func pairs_for(cycle: int, adalids: Array[Adalid]) -> Array:
	var table := table_for(adalids.size())
	var column: Array = table[(cycle - 1) % table.size()]
	var pairs: Array = []
	var loose: Array[Adalid] = []
	for pair in column:
		var a: Adalid = adalids[pair[0]]
		var b: Adalid = adalids[pair[1]]
		if a.eliminated and b.eliminated:
			continue
		if a.eliminated:
			loose.append(b)
		elif b.eliminated:
			loose.append(a)
		else:
			pairs.append([a, b])
	while loose.size() >= 2:
		pairs.append([loose.pop_front(), loose.pop_front()])
	for a in loose:
		pairs.append([a])
	return pairs
