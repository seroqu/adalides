class_name Icons
extends RefCounted
## Iconos y colores de elementos y arquetipos.

const ELEMENT_COLORS := {
	Rules.Element.FUEGO: Color(1.0, 0.42, 0.25), Rules.Element.TRUENO: Color(1.0, 0.88, 0.25),
	Rules.Element.TIERRA: Color(0.72, 0.52, 0.3), Rules.Element.AIRE: Color(0.78, 0.9, 1.0),
	Rules.Element.HIELO: Color(0.45, 0.78, 1.0),
}
const HERO_COLOR := Color(0.85, 0.7, 1.0)
const ELEMENT_FILES := {
	Rules.Element.FUEGO: "fuego", Rules.Element.TRUENO: "trueno", Rules.Element.TIERRA: "tierra",
	Rules.Element.AIRE: "aire", Rules.Element.HIELO: "hielo",
}
const ARCHETYPE_FILES := {
	Rules.Archetype.ROBOT: "robot", Rules.Archetype.SALVAJE: "salvaje", Rules.Archetype.ANGEL: "angel",
	Rules.Archetype.DEMONIO: "demonio", Rules.Archetype.MAGO: "mago", Rules.Archetype.ARQUERO: "arquero",
	Rules.Archetype.DEFENSOR: "defensor", Rules.Archetype.ASESINO: "asesino", Rules.Archetype.PIRATA: "pirata",
	Rules.Archetype.MUERTO: "muerto",
}

static var _cache := {}


static func element(e: int) -> Texture2D:
	return _load("res://assets/icons/element_%s.svg" % ELEMENT_FILES.get(e, "fuego"))


static func archetype(a: int) -> Texture2D:
	return _load("res://assets/icons/archetype_%s.svg" % ARCHETYPE_FILES.get(a, "robot"))


static func color_of(card: ChampionData) -> Color:
	return HERO_COLOR if card.hero else ELEMENT_COLORS.get(card.element, Color.WHITE)


static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]
