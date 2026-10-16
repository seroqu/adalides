class_name Catalog
extends RefCounted
## Catálogo v2: 50 campeones base (10 arquetipos × 5 elementos) y 5 héroes.
## Fuente: PDF, "Tabla de arquetipos y poder inicial", "Tabla de precios",
## tabla de héroes y "Poderes de personaje". Las anotaciones del PDF
## ("todos están más 2 de vida, menos arqueros, magos y piratas solo más uno,
## y asesinos +1 de ataque") ya están aplicadas.

const E := Rules.Element
const A := Rules.Archetype
const P := Rules.Phase
const D := Rules.Die

## Orden de columnas de las tablas del PDF.
const ARCH_ORDER: Array[int] = [A.ROBOT, A.SALVAJE, A.ANGEL, A.DEMONIO, A.MAGO, A.ARQUERO, A.DEFENSOR, A.ASESINO, A.PIRATA, A.MUERTO]
const ELEM_ORDER: Array[int] = [E.FUEGO, E.TRUENO, E.TIERRA, E.AIRE, E.HIELO]

## [ataque, defensa] por elemento (fila) y arquetipo (columna), tal cual el PDF.
const STATS := {
	E.FUEGO: [[2, 2], [2, 4], [2, 4], [3, 4], [2, 2], [1, 2], [1, 4], [2, 1], [2, 6], [2, 4]],
	E.TRUENO: [[2, 6], [2, 2], [1, 6], [2, 4], [2, 2], [2, 4], [1, 4], [3, 2], [1, 4], [1, 4]],
	E.TIERRA: [[2, 4], [2, 2], [1, 4], [1, 4], [1, 2], [2, 2], [1, 8], [3, 2], [1, 6], [2, 6]],
	E.AIRE: [[1, 4], [3, 4], [2, 6], [2, 4], [1, 2], [2, 2], [1, 6], [2, 1], [1, 6], [1, 4]],
	E.HIELO: [[2, 4], [2, 4], [1, 4], [1, 4], [2, 4], [1, 2], [1, 6], [5, 2], [1, 4], [2, 4]],
}
const PRICES := {
	E.FUEGO: [1, 2, 2, 3, 2, 1, 1, 1, 3, 2],
	E.TRUENO: [3, 1, 2, 2, 2, 3, 1, 2, 1, 1],
	E.TIERRA: [2, 1, 1, 1, 1, 2, 3, 2, 2, 3],
	E.AIRE: [1, 3, 3, 2, 1, 2, 2, 1, 2, 1],
	E.HIELO: [2, 2, 1, 1, 3, 1, 2, 3, 1, 2],
}
## Anotaciones del PDF.
const LIFE_BONUS_DEFAULT := 2
const LIFE_BONUS_SMALL := { A.ARQUERO: 1, A.MAGO: 1, A.PIRATA: 1 }
const ATTACK_BONUS := { A.ASESINO: 1 }

static var _cache: Array[ChampionData] = []


static func all() -> Array[ChampionData]:
	if _cache.is_empty():
		for e in ELEM_ORDER:
			for i in ARCH_ORDER.size():
				_cache.append(_base(ARCH_ORDER[i], e, i))
		_cache.append_array(_heroes())
	return _cache


static func by_id(id: StringName) -> ChampionData:
	for c in all():
		if c.id == id:
			return c
	return null


static func base_cards() -> Array[ChampionData]:
	var out: Array[ChampionData] = []
	for c in all():
		if not c.hero:
			out.append(c)
	return out


static func heroes() -> Array[ChampionData]:
	var out: Array[ChampionData] = []
	for c in all():
		if c.hero:
			out.append(c)
	return out


static func id_for(arch: int, elem: int) -> StringName:
	return StringName("%s_%s" % [Rules.archetype_label(arch).to_lower().replace("á", "a"),
		Rules.element_label(elem).to_lower()])


static func _base(arch: int, elem: int, col: int) -> ChampionData:
	var st: Array = STATS[elem][col]
	var atk: int = st[0] + ATTACK_BONUS.get(arch, 0)
	var def: int = st[1] + LIFE_BONUS_SMALL.get(arch, LIFE_BONUS_DEFAULT)
	var name := "%s de %s" % [Rules.archetype_label(arch), Rules.element_label(elem).to_lower()]
	return ChampionData.make(id_for(arch, elem), name, arch, elem, PRICES[elem][col], atk, def,
		POWERS.get([arch, elem], {}))


static func _heroes() -> Array[ChampionData]:
	var out: Array[ChampionData] = []
	out.append(_hero("robot_caballero", "Robot caballero", A.ROBOT, A.DEFENSOR, 3, 8))
	out.append(_hero("salvaje_asesino", "Salvaje asesino", A.SALVAJE, A.ASESINO, 7, 4))
	out.append(_hero("angel_arquero", "Ángel arquero", A.ANGEL, A.ARQUERO, 4, 5))
	out.append(_hero("demonio_mago", "Demonio mago", A.DEMONIO, A.MAGO, 3, 6))
	out.append(_hero("pirata_muerto", "Pirata muerto", A.PIRATA, A.MUERTO, 4, 7))
	return out


static func _hero(id: String, name: String, a1: int, a2: int, atk: int, def: int) -> ChampionData:
	var c := ChampionData.make_hero(id, name, a1, a2, atk, def)
	c.power = HERO_POWERS.get(id, {})
	return c


static func _p(name: String, phase: int, passive: bool, req: Array, values: Array, text: String) -> Dictionary:
	return { "name": name, "phase": phase, "passive": passive, "req": req, "values": values, "text": text }


## Poderes de personaje. `values` = (1 copia / 2 copias / AFI 1 / AFI 2) cuando el
## PDF da cuatro valores. `req` vacío = cualquier resultado activa el poder.
const POWERS := {
	# --- Ángel ---
	[A.ANGEL, E.FUEGO]: { "name": "Aura de retribución", "phase": P.HI, "passive": false, "req": [], "values": [0, 1, 2, 3],
		"text": "Durante este asalto, cuando un enemigo a distancia (0/1/2/3) del campeón realiza un ataque básico, recibe 1+AFI de daño." },
	[A.ANGEL, E.HIELO]: { "name": "Aura estoica", "phase": P.HI, "passive": false, "req": [], "values": [0, 1, 2, 3],
		"text": "Durante este asalto, los aliados a distancia (0/1/2/3) tienen (0/0/1/2) movimientos menos y no pueden ser afectados por efectos de control." },
	[A.ANGEL, E.TRUENO]: { "name": "Curación relámpago", "phase": P.HF, "passive": true, "req": [], "values": [0, 1, 2, 3],
		"text": "Lanza (0/1/2/3) dados; los aliados en esas filas reciben 1+AFI de curación." },
	[A.ANGEL, E.AIRE]: { "name": "Aura de paz", "phase": P.HI, "passive": false, "req": [], "values": [0, 1, 2, 3],
		"text": "Durante este asalto, cuando un aliado a distancia (0/1/2/3) recibe daño directo, este se reduce en 1+AFI." },
	[A.ANGEL, E.TIERRA]: { "name": "Aura de resurrección", "phase": P.HF, "passive": false, "req": [], "values": [0, 0, 1, 2],
		"text": "Resucita a los (0/0/1/2) aliados muertos con más vida base durante este asalto a distancia máxima 2, con 1+AFI de vida." },
	# --- Demonio ---
	[A.DEMONIO, E.FUEGO]: { "name": "Inmolación infernal", "phase": P.HF, "passive": true, "req": [], "values": [0, 1, 2, 3],
		"text": "El demonio se suicida dando 0+AFI de vida a su adalid y maldiciendo a los (0/1/2/3) enemigos más cercanos." },
	[A.DEMONIO, E.HIELO]: { "name": "Abjuración herética", "phase": P.HI, "passive": true, "req": [D.CRITICO], "values": [],
		"text": "Congela a los afectados por Herejía y usa sus 1+AFI poderes robados este turno." },
	[A.DEMONIO, E.TRUENO]: { "name": "Cosecha oscura", "phase": P.HF, "passive": false, "req": [], "values": [0, 1, 2, 3],
		"text": "Lanza (0/1/2/3) dados; los enemigos malditos en esas columnas mueren. Si cosechas al menos 1, inflige AFI al adalid enemigo." },
	[A.DEMONIO, E.AIRE]: { "name": "Hedor profano", "phase": P.HF, "passive": false, "req": [D.CRITICO], "values": [],
		"text": "Inflige 1+AFI de daño a los enemigos que se muevan durante el siguiente asalto." },
	[A.DEMONIO, E.TIERRA]: { "name": "Sepultar", "phase": P.HF, "passive": false, "req": [], "values": [0, 0, 1, 2],
		"text": "Se entierra junto con los enemigos a (0/0/1/2) de distancia y maldice a los AFI enemigos más cercanos no sepultados." },
	# --- Arquero ---
	[A.ARQUERO, E.FUEGO]: { "name": "Disparo de fuego", "phase": P.HI, "passive": true, "req": [], "values": [0, 0, 1, 2],
		"text": "El siguiente ataque del arquero obtiene (0/0/1/2)+AFI de daño." },
	[A.ARQUERO, E.HIELO]: { "name": "Disparo de hielo", "phase": P.H, "passive": false, "req": [], "values": [0, 0, 1, 2],
		"text": "Congela a su objetivo y a todos los enemigos en un rango de (0/0/1/2), haciéndoles además 1+AFI de daño." },
	[A.ARQUERO, E.TRUENO]: { "name": "Tormenta de flechas", "phase": P.H, "passive": false, "req": [], "values": [0, 1, 2, 3],
		"text": "Tira (0/1/2/3) dados; hace su daño de ataque base a todos los enemigos en esas columnas." },
	[A.ARQUERO, E.AIRE]: { "name": "Disparos de viento", "phase": P.HI, "passive": true, "req": [], "values": [],
		"text": "El siguiente golpe empuja 1+AFI hacia atrás a su objetivo y aplica daño de Céfiro." },
	[A.ARQUERO, E.TIERRA]: { "name": "Camuflaje", "phase": P.HI, "passive": true, "req": [D.CRITICO], "values": [],
		"text": "Por este turno esquiva todo el daño de poderes de campeón." },
	# --- Mago ---
	[A.MAGO, E.FUEGO]: { "name": "Bola de fuego", "phase": P.H, "passive": false, "req": [D.ACIERTO, D.CRITICO], "values": [],
		"text": "Golpea a su enemigo con 2+AFI veces su poder de ataque." },
	[A.MAGO, E.HIELO]: { "name": "Congelación profunda", "phase": P.HI, "passive": true, "req": [D.FALLO, D.PIFIA], "values": [],
		"text": "Hace inmunes a todo daño a sus aliados a distancia 0+AFI, incluido él mismo." },
	[A.MAGO, E.TRUENO]: { "name": "Energizar", "phase": P.H, "passive": false, "req": [], "values": [0, 1, 2, 3],
		"text": "Aumenta el poder de ataque del aliado con más vida en (0/1/2/3)+AFI." },
	[A.MAGO, E.AIRE]: { "name": "Distancia", "phase": P.H, "passive": false, "req": [], "values": [0, 1, 2, 3],
		"text": "Empuja (0/1/2/3) espacios a los que estén a 1 de distancia y aplica daño de Céfiro." },
	[A.MAGO, E.TIERRA]: { "name": "Arenas movedizas", "phase": P.HI, "passive": false, "req": [D.ACIERTO, D.CRITICO], "values": [],
		"text": "Anula las habilidades de los enemigos a 1 de distancia." },
	# --- Defensor ---
	[A.DEFENSOR, E.FUEGO]: { "name": "Cauterizar", "phase": P.A, "passive": true, "req": [D.CRITICO], "values": [],
		"text": "Sus ataques ponen la vida máxima del enemigo en el valor que queda tras el ataque." },
	[A.DEFENSOR, E.HIELO]: { "name": "Armadura de escarcha", "phase": P.HI, "passive": true, "req": [D.CRITICO], "values": [],
		"text": "Los enemigos que lo ataquen con ataques normales este asalto quedan congelados." },
	[A.DEFENSOR, E.TRUENO]: { "name": "Electrocutar", "phase": P.HI, "passive": true, "req": [D.ACIERTO, D.CRITICO], "values": [],
		"text": "Los enemigos que lo ataquen reciben 1+AFI de daño y se lo hacen a sus aliados adyacentes." },
	[A.DEFENSOR, E.AIRE]: { "name": "Viento arrebatado", "phase": P.HI, "passive": true, "req": [D.FALLO], "values": [],
		"text": "Evita todos los ataques básicos durante este asalto." },
	[A.DEFENSOR, E.TIERRA]: { "name": "Escudo reflectivo", "phase": P.HI, "passive": false, "req": [D.CRITICO], "values": [],
		"text": "Lanza un dado por cada hechizo que pudiera afectarlo este turno; con ++ lo refleja." },
	# --- Pirata ---
	[A.PIRATA, E.FUEGO]: { "name": "Pistolazo", "phase": P.HI, "passive": true, "req": [], "values": [0, 1, 2, 3],
		"text": "El siguiente ataque está potenciado en (0/1/2/3) y rebota a 1+AFI enemigos cercanos." },
	[A.PIRATA, E.HIELO]: { "name": "Agarre de kraken", "phase": P.H, "passive": false, "req": [D.CRITICO], "values": [0, 0, 1, 2],
		"text": "Atrae hacia sí a los (0/0/1/2) enemigos más lejanos y los congela." },
	[A.PIRATA, E.TRUENO]: { "name": "Saquear el tesoro", "phase": P.HF, "passive": false, "req": [], "values": [0, 1, 2, 3],
		"text": "Roba (0/1/2/3)+AFI de Éter al enemigo." },
	[A.PIRATA, E.AIRE]: { "name": "Enemigo a la vista", "phase": P.H, "passive": false, "req": [], "values": [0, 1, 2, 3],
		"text": "Aumenta en (0/1/2/3) el daño que va a recibir un enemigo de cualquier fuente." },
	[A.PIRATA, E.TIERRA]: { "name": "Tengo un jarrón", "phase": P.HI, "passive": false, "req": [D.CRITICO], "values": [],
		"text": "Este asalto, cualquiera que contribuya a matar al pirata muere con él." },
	# --- Muerto ---
	[A.MUERTO, E.FUEGO]: { "name": "Fundir", "phase": P.H, "passive": false, "req": [], "values": [4, 3, 2, 1],
		"text": "Deja a su objetivo con (4/3/2/1)-AFI de vida." },
	[A.MUERTO, E.HIELO]: { "name": "Frío fantasmal", "phase": P.H, "passive": false, "req": [], "values": [0, 0, 1, 2],
		"text": "Asusta a los enemigos a distancia (0/0/1/2): pierden el turno si no han realizado su habilidad." },
	[A.MUERTO, E.TRUENO]: { "name": "Drenar energía", "phase": P.HF, "passive": false, "req": [D.CRITICO], "values": [0, 1, 2, 3],
		"text": "Iguala la vida de los enemigos a (0/1/2/3) veces su ataque." },
	[A.MUERTO, E.AIRE]: { "name": "Aire vital", "phase": P.HF, "passive": true, "req": [D.CRITICO], "values": [],
		"text": "Si mata a alguien este turno, lo revive como muerto viviente que ataca a su propio equipo." },
	[A.MUERTO, E.TIERRA]: { "name": "Tierra maldita", "phase": P.HF, "passive": true, "req": [D.CRITICO], "values": [0, 0, 1, 2],
		"text": "Si muere este turno se queda tirado; los enemigos a (0/0/1/2) reciben 1+AFI de daño al final del turno." },
	# --- Asesino ---
	[A.ASESINO, E.FUEGO]: { "name": "Corte de fuego", "phase": P.H, "passive": false, "req": [], "values": [0, 0, 1, 2],
		"text": "Su daño se extiende en la dirección del enemigo (0/0/1/2) casillas." },
	[A.ASESINO, E.HIELO]: { "name": "Corte helado", "phase": P.H, "passive": false, "req": [], "values": [0, 0, 1, 2],
		"text": "Además de su daño, congela a todos los enemigos a (0/0/1/2) de distancia en la dirección del enemigo." },
	[A.ASESINO, E.TRUENO]: { "name": "Golpe rebotante", "phase": P.H, "passive": false, "req": [D.CRITICO], "values": [],
		"text": "Cada vez que mate a alguien este turno salta a su nuevo objetivo y lo golpea." },
	[A.ASESINO, E.AIRE]: { "name": "Golpe fantasma", "phase": P.HI, "passive": false, "req": [], "values": [],
		"text": "Cambia el objetivo de su objetivo por el del aliado más lejano." },
	[A.ASESINO, E.TIERRA]: { "name": "Capa de sombras", "phase": P.HI, "passive": false, "req": [], "values": [0, 1, 2, 3],
		"text": "Pone en sigilo a los aliados a (0/1/2/3) de distancia." },
	# --- Robot ---
	[A.ROBOT, E.FUEGO]: { "name": "Caldero a presión", "phase": P.HF, "passive": false, "req": [], "values": [0, 0, 1, 2],
		"text": "Hace 1+AFI a los enemigos a (0/0/1/2) de distancia; por cada enemigo herido produce 1 de Éter." },
	[A.ROBOT, E.HIELO]: { "name": "Cero absoluto", "phase": P.H, "passive": false, "req": [], "values": [0, 0, 1, 2],
		"text": "Congela a todos los personajes a (0/0/1/2) de distancia; por cada congelado produce 1 de Éter." },
	[A.ROBOT, E.TRUENO]: { "name": "Energía renovable", "phase": P.HI, "passive": true, "req": [D.CRITICO], "values": [],
		"text": "Por cada 1 de daño que reciba este asalto produce 1+AFI de Éter." },
	[A.ROBOT, E.AIRE]: { "name": "Energía eólica", "phase": P.HI, "passive": true, "req": [D.CRITICO], "values": [],
		"text": "Cada vez que alguien esquive este asalto produce 1+AFI de Éter." },
	[A.ROBOT, E.TIERRA]: { "name": "Excavadora", "phase": P.HF, "passive": false, "req": [], "values": [0, 1, 2, 3],
		"text": "Hace un túnel a la posición contraria llevando a los aliados a (0/1/2/3); daña AFI a los enemigos a (0/0/0/1); por cada daño produce 1 de Éter." },
	# --- Salvaje ---
	[A.SALVAJE, E.FUEGO]: { "name": "Garras ígneas", "phase": P.HI, "passive": false, "req": [D.CRITICO], "values": [],
		"text": "Aumenta su daño en 1+AFI por el resto del combate." },
	[A.SALVAJE, E.HIELO]: { "name": "Quebrar", "phase": P.HF, "passive": false, "req": [], "values": [1, 2, 3, 4],
		"text": "Hace (1/2/3/4)+AFI de daño a los enemigos congelados a (0/0/1/2) de su objetivo y los descongela." },
	[A.SALVAJE, E.TRUENO]: { "name": "Saltos continuos", "phase": P.H, "passive": true, "req": [], "values": [],
		"text": "Al atacar lanza su dado; si supera la calidad del dado asignado salta al enemigo más lejano y lo golpea (++ siempre cumple)." },
	[A.SALVAJE, E.AIRE]: { "name": "Agilidad trémula", "phase": P.M, "passive": true, "req": [D.ACIERTO, D.CRITICO], "values": [],
		"text": "Este turno puede moverse y atacar." },
	[A.SALVAJE, E.TIERRA]: { "name": "Espinas afiladas", "phase": P.HI, "passive": false, "req": [D.PIFIA, D.FALLO], "values": [],
		"text": "Aumenta el efecto de Roca afilada en 1+AFI por este asalto." },
}

const HERO_POWERS := {
	"angel_arquero": { "name": "Aura de puntería divina", "phase": P.HI, "passive": true, "req": [D.PIFIA], "values": [],
		"text": "Durante este asalto los efectos de daño también curan a los aliados y los de curación también dañan a los enemigos." },
	"demonio_mago": { "name": "Atracción letal", "phase": P.H, "passive": false, "req": [D.PIFIA], "values": [],
		"text": "Atrae a su posición a los 1+AFI enemigos más lejanos y los maldice." },
	"robot_caballero": { "name": "Matriz de protección", "phase": P.HI, "passive": false, "req": [D.PIFIA], "values": [],
		"text": "Anula todos los poderes usados por campeones a una distancia de 1+AFI." },
	"pirata_muerto": { "name": "Oro maldito", "phase": P.HF, "passive": true, "req": [], "values": [],
		"text": "Si no muere durante el combate, al final le quita 1+AFI de vida al adalid enemigo y se la da al suyo." },
	"salvaje_asesino": { "name": "Frenesí", "phase": P.HF, "passive": false, "req": [D.PIFIA], "values": [],
		"text": "Solo en el último asalto: ataca a todos los enemigos y luego muere." },
}
