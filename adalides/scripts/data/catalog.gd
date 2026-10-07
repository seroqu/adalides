class_name Catalog
extends RefCounted
## Catálogo de cartas. Los elementales, héroes y legendarios salen del README.
## Las cartas comunes son RELLENO (placeholder) para poder probar combates:
## las 200 cartas reales aún no están documentadas.

const C := Rules.ClassType
const T := Rules.Tier
const R := Rules.Reach
const K := Rules.Keyword

static var _cache: Array[ChampionData] = []


static func all() -> Array[ChampionData]:
	if _cache.is_empty():
		_cache.append_array(_commons())
		_cache.append_array(_elementals())
		_cache.append_array(_heroes())
		_cache.append_array(_legendaries())
	return _cache


static func by_id(id: StringName) -> ChampionData:
	for c in all():
		if c.id == id:
			return c
	return null


static func by_tier(tier: Rules.Tier) -> Array[ChampionData]:
	var out: Array[ChampionData] = []
	for c in all():
		if c.tier == tier:
			out.append(c)
	return out


static func by_class(cls: int) -> Array[ChampionData]:
	var out: Array[ChampionData] = []
	for c in all():
		if c.has_class(cls):
			out.append(c)
	return out


static func _a(p_min: int, p_max: int, kws: Array[int]) -> Dictionary:
	return ChampionData.action(p_min, p_max, kws)


# ---------------------------------------------------------------- comunes (relleno)

static func _commons() -> Array[ChampionData]:
	var melee: Array[Dictionary] = [_a(4, 6, [K.ATK]), _a(1, 3, [K.MOV])]
	var ranged: Array[Dictionary] = [_a(5, 6, [K.ATK]), _a(3, 4, [K.MOV]), _a(1, 2, [K.PRO])]
	var guard: Array[Dictionary] = [_a(5, 6, [K.ATK]), _a(3, 4, [K.BLOCK]), _a(1, 2, [K.MOV])]
	var trick: Array[Dictionary] = [_a(5, 6, [K.ATK]), _a(3, 4, [K.CONG]), _a(1, 2, [K.MOV])]
	var evasive: Array[Dictionary] = [_a(5, 6, [K.ATK]), _a(3, 4, [K.ESQ]), _a(1, 2, [K.MOV])]
	var healer: Array[Dictionary] = [_a(5, 6, [K.ATK]), _a(3, 4, [K.CUR]), _a(1, 2, [K.MOV])]
	var out: Array[ChampionData] = []
	out.append(ChampionData.make("salamandra", "Salamandra", [C.FUEGO], T.COMUN, 2, 2, 3, R.CUERPO_A_CUERPO, melee, "", true))
	out.append(ChampionData.make("chispa", "Chispa", [C.ELECTRICO], T.COMUN, 2, 2, 2, R.RANGO, ranged, "", true))
	out.append(ChampionData.make("golem", "Gólem", [C.TIERRA], T.COMUN, 3, 1, 5, R.CUERPO_A_CUERPO, guard, "", true))
	out.append(ChampionData.make("silfo", "Silfo", [C.AIRE], T.COMUN, 2, 2, 2, R.EMBOSCADOR, evasive, "", true))
	out.append(ChampionData.make("escarcha", "Escarcha", [C.HIELO], T.COMUN, 2, 1, 3, R.RANGO, trick, "", true))
	out.append(ChampionData.make("lobo", "Lobo", [C.SALVAJE], T.COMUN, 2, 3, 2, R.CUERPO_A_CUERPO, melee, "", true))
	out.append(ChampionData.make("dron", "Dron", [C.ROBOT], T.COMUN, 2, 1, 3, R.RANGO, ranged, "", true))
	out.append(ChampionData.make("diablillo", "Diablillo", [C.MAL], T.COMUN, 2, 3, 1, R.EMBOSCADOR, melee, "", true))
	out.append(ChampionData.make("querubin", "Querubín", [C.BIEN], T.COMUN, 2, 1, 3, R.RANGO, healer, "", true))
	out.append(ChampionData.make("escudero", "Escudero", [C.PROTECTOR], T.COMUN, 2, 1, 4, R.CUERPO_A_CUERPO, guard, "", true))
	out.append(ChampionData.make("sombra", "Sombra", [C.ASESINO], T.COMUN, 3, 3, 2, R.EMBOSCADOR, melee, "", true))
	out.append(ChampionData.make("aprendiz", "Aprendiz", [C.MAGO], T.COMUN, 2, 2, 2, R.RANGO, ranged, "", true))
	return out


# ---------------------------------------------------------------- señores elementales (README)

static func _elementals() -> Array[ChampionData]:
	var out: Array[ChampionData] = []
	out.append(ChampionData.make("plasma", "Plasma", [C.FUEGO, C.ELECTRICO], T.ELEMENTAL, 7, 5, 6, R.RANGO,
		[_a(6, 6, [K.SPEC]), _a(3, 5, [K.MOV, K.ATK]), _a(1, 2, [K.MOV])],
		"6: hace 5 de daño a un enemigo y 1 a todos los otros."))
	out.append(ChampionData.make("lava", "Lava", [C.FUEGO, C.TIERRA], T.ELEMENTAL, 9, 4, 8, R.CUERPO_A_CUERPO,
		[_a(6, 6, [K.SPEC]), _a(4, 5, [K.MOV, K.ATK]), _a(1, 3, [K.BLOCK])],
		"6: hace un daño igual al valor de la casilla de cada carta enemiga, -2."))
	out.append(ChampionData.make("glacial", "Glacial", [C.HIELO, C.TIERRA], T.ELEMENTAL, 10, 3, 10, R.CUERPO_A_CUERPO,
		[_a(1, 6, [K.BLOCK])],
		"Bloquea todos los turnos. Al morir lanza 2 DP enemigos y mata lo que haya ahí."))
	out.append(ChampionData.make("tormenta", "Tormenta", [C.HIELO, C.ELECTRICO], T.ELEMENTAL, 9, 4, 6, R.RANGO,
		[_a(6, 6, [K.SPEC]), _a(3, 5, [K.ATK]), _a(1, 2, [K.MOV])],
		"6: lanza 3 dados de ubicación enemiga, daña y congela lo que haya ahí."))
	out.append(ChampionData.make("senores_aire", "Señores del aire", [C.AIRE], T.ELEMENTAL, 10, 1, 6, R.RANGO,
		[_a(6, 6, [K.SPEC]), _a(4, 5, [K.ATK, K.MOV]), _a(3, 3, [K.SPEC]), _a(1, 2, [K.MOV])],
		"Esquivan con 6 en un d6. Su daño es el cuadrado de señores elementales en mano. 6: daño a todos. 3: mueve un enemigo y ataca."))
	return out


# ---------------------------------------------------------------- héroes (README)

static func _heroes() -> Array[ChampionData]:
	var out: Array[ChampionData] = []
	out.append(ChampionData.make("demonio_electrico", "Demonio eléctrico", [C.MAL, C.ELECTRICO, C.FUEGO], T.HEROE, 12, 6, 8, R.CUERPO_A_CUERPO,
		[_a(3, 6, [K.SPEC]), _a(1, 2, [K.MOV, K.ATK])],
		"3-6: hace explotar a un aliado adyacente: todo su daño al enemigo y la mitad a los aliados."))
	out.append(ChampionData.make("demonio_arena", "Demonio de arena", [C.MAL, C.TIERRA, C.FUEGO], T.HEROE, 12, 5, 10, R.CUERPO_A_CUERPO,
		[_a(3, 6, [K.SPEC]), _a(1, 2, [K.BLOCK])],
		"3-6: tira 5 dados de ubicación enemiga, roba la mitad de esa vida y la añade al demonio."))
	out.append(ChampionData.make("mago_plasma", "Mago de plasma", [C.ELECTRICO, C.FUEGO, C.MAL], T.HEROE, 12, 6, 6, R.RANGO,
		[_a(3, 6, [K.SPEC]), _a(1, 2, [K.SPEC])],
		"3-6: explota y hace daño a todos los no magos. 1-2: duplica su daño."))
	out.append(ChampionData.make("mago_tormenta", "Mago de tormenta", [C.ELECTRICO, C.HIELO, C.MAL], T.HEROE, 12, 5, 7, R.RANGO,
		[_a(4, 6, [K.SPEC]), _a(2, 3, [K.SPEC]), _a(1, 1, [K.MOV, K.ATK])],
		"4-6: congela a todos los enemigos y les hace 2 daños. 2-3: desvía el daño de un enemigo en la dirección elegida."))
	out.append(ChampionData.make("gigante_hielo", "Gigante de hielo", [C.TIERRA, C.PROTECTOR, C.HIELO], T.HEROE, 12, 5, 12, R.CUERPO_A_CUERPO,
		[_a(6, 6, [K.BLOCK]), _a(1, 5, [K.MOV, K.ATK])],
		"Recibe siempre 2 menos de daño. Al recibir daño congela al atacante."))
	out.append(ChampionData.make("gigante_infernal", "Gigante infernal", [C.TIERRA, C.PROTECTOR, C.FUEGO], T.HEROE, 12, 6, 12, R.CUERPO_A_CUERPO,
		[_a(6, 6, [K.BLOCK]), _a(1, 5, [K.MOV, K.ATK])],
		"Recibe siempre 2 menos de daño. Al recibir daño hace 2 de daño al atacante."))
	out.append(ChampionData.make("androide_glacial", "Androide glacial", [C.HIELO, C.ROBOT, C.TIERRA], T.HEROE, 12, 4, 9, R.RANGO,
		[_a(5, 6, [K.SPEC]), _a(1, 4, [K.SPEC])],
		"5-6: paga X Éter para hacer X de daño a un enemigo. 1-4: paga X Éter para congelar X turnos a un enemigo."))
	out.append(ChampionData.make("androide_huracan", "Androide del huracán", [C.HIELO, C.ROBOT, C.ELECTRICO], T.HEROE, 12, 4, 8, R.RANGO,
		[_a(4, 6, [K.SPEC]), _a(1, 3, [K.SPEC])],
		"4-6: duplica tu Éter. 1-3: paga X Éter para hacer X/5 daños a todos los enemigos."))
	out.append(ChampionData.make("cazador_viento", "Cazador del viento", [C.ASESINO, C.AIRE], T.HEROE, 12, 6, 6, R.EMBOSCADOR,
		[_a(1, 6, [K.MOV, K.ATK])],
		"Nunca sale de sigilo. Esquiva con 6 en un DA (incluso daño de área) y al esquivar mueve y ataca. Siglas originales: C V A."))
	return out


# ---------------------------------------------------------------- legendarios (README)

static func _legendaries() -> Array[ChampionData]:
	var out: Array[ChampionData] = []
	out.append(ChampionData.make("arcangel", "Arcángel", [C.BIEN], T.LEGENDARIO, 20, 20, 20, R.CUERPO_A_CUERPO,
		[_a(1, 6, [K.MOV, K.ATK])],
		"Cuenta como Bien y como cualquier otra clase. Si sigue vivo al final del combate, +2 de salud. No sube de nivel."))
	out.append(ChampionData.make("senor_demonio", "Señor demonio", [C.MAL], T.LEGENDARIO, 20, 10, 10, R.CUERPO_A_CUERPO,
		[_a(4, 6, [K.ANIQUILA]), _a(1, 3, [K.MOV])],
		"4-6: ANIQUILA; se lleva la carta atacada al infierno y ambos se descartan. No sube de nivel."))
	return out
